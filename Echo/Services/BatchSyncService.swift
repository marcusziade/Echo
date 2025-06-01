import Foundation
import GRDB

/// Service for batch synchronization operations
final class BatchSyncService {
    static let shared = BatchSyncService()

    private let traktService = TraktService.shared
    private let databaseManager = DatabaseManager.shared

    private init() {}

    // MARK: - Batch Show Operations

    /// Sync multiple shows with their episodes
    /// - Parameters:
    ///   - showIds: Array of show database IDs to sync
    ///   - progress: Progress callback (called after each show)
    /// - Returns: Results of the batch operation
    @discardableResult
    func syncMultipleShows(
        showIds: [Int64],
        progress: ((BatchSyncProgress) -> Void)? = nil
    ) async throws -> BatchSyncResult {
        return try await syncMultipleShowsConcurrently(
            showIds: showIds,
            maxConcurrency: ProcessInfo.processInfo.activeProcessorCount,
            progress: progress
        )
    }
    
    /// Sync multiple shows concurrently with limited concurrency
    /// - Parameters:
    ///   - showIds: Array of show database IDs to sync
    ///   - maxConcurrency: Maximum number of concurrent operations (defaults to processor count)
    ///   - progress: Progress callback (called after each show)
    /// - Returns: Results of the batch operation
    @discardableResult
    func syncMultipleShowsConcurrently(
        showIds: [Int64],
        maxConcurrency: Int = ProcessInfo.processInfo.activeProcessorCount,
        progress: ((BatchSyncProgress) -> Void)? = nil
    ) async throws -> BatchSyncResult {
        
        let semaphore = AsyncSemaphore(value: maxConcurrency)
        let progressLock = NSLock()
        var completedCount = 0
        var successCount = 0
        var failedShows: [(showId: Int64, error: Error)] = []
        var totalEpisodesSynced = 0
        
        // Create concurrent tasks for all shows
        await withTaskGroup(of: SyncShowResult.self) { group in
            for showId in showIds {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    do {
                        let syncedEpisodes = try await self.syncShowWithEpisodes(showId: showId) { phase in
                            // Thread-safe progress reporting
                            progressLock.lock()
                            progress?(
                                BatchSyncProgress(
                                    current: completedCount,
                                    total: showIds.count,
                                    currentShowId: showId,
                                    phase: phase
                                ))
                            progressLock.unlock()
                        }
                        
                        return SyncShowResult.success(showId: showId, episodeCount: syncedEpisodes)
                    } catch {
                        return SyncShowResult.failure(showId: showId, error: error)
                    }
                }
            }
            
            // Collect results as they complete
            for await result in group {
                progressLock.lock()
                
                switch result {
                case .success(let showId, let episodeCount):
                    successCount += 1
                    totalEpisodesSynced += episodeCount
                    
                case .failure(let showId, let error):
                    failedShows.append((showId: showId, error: error))
                    print("❌ Failed to sync show \(showId): \(error)")
                }
                
                completedCount += 1
                
                // Report overall progress
                progress?(
                    BatchSyncProgress(
                        current: completedCount,
                        total: showIds.count,
                        currentShowId: -1,
                        phase: .completed
                    ))
                
                progressLock.unlock()
            }
        }
        
        return BatchSyncResult(
            totalShows: showIds.count,
            successCount: successCount,
            failedShows: failedShows,
            totalEpisodesSynced: totalEpisodesSynced
        )
    }

    /// Sync all shows in the database
    func syncAllShows(
        progress: ((BatchSyncProgress) -> Void)? = nil
    ) async throws -> BatchSyncResult {

        guard let reader = databaseManager.reader else {
            throw BatchSyncError.databaseNotInitialized
        }

        // Get all show IDs
        let showIds = try await reader.read { db in
            try Show.fetchAll(db).compactMap { $0.id }
        }

        return try await syncMultipleShows(showIds: showIds, progress: progress)
    }

    // MARK: - Batch Episode Operations

    /// Mark multiple episodes as watched in a single transaction
    func markEpisodesAsWatched(
        episodeIds: [Int64],
        watchedAt: Date = Date()
    ) async throws -> Int {

        guard let writer = databaseManager.writer else {
            throw BatchSyncError.databaseNotInitialized
        }

        return try await writer.write { db in
            var updatedCount = 0

            for episodeId in episodeIds {
                if var episode = try Episode.fetchOne(db, key: episodeId) {
                    episode.watchedAt = watchedAt
                    try episode.update(db)
                    updatedCount += 1
                }
            }

            return updatedCount
        }
    }

    /// Sync watched status for multiple shows with Trakt
    func syncWatchedStatus(
        for showIds: [Int64],
        progress: ((BatchSyncProgress) -> Void)? = nil
    ) async throws -> BatchSyncResult {

        var successCount = 0
        var failedShows: [(showId: Int64, error: Error)] = []

        for (index, showId) in showIds.enumerated() {
            progress?(
                BatchSyncProgress(
                    current: index,
                    total: showIds.count,
                    currentShowId: showId,
                    phase: .syncingProgress
                ))

            do {
                try await SyncManager.shared.syncWatchedProgress(showId: showId)
                successCount += 1
            } catch {
                failedShows.append((showId: showId, error: error))
            }
        }

        return BatchSyncResult(
            totalShows: showIds.count,
            successCount: successCount,
            failedShows: failedShows,
            totalEpisodesSynced: 0
        )
    }

    // MARK: - Transaction Support

    /// Perform multiple database operations in a single transaction
    func performInTransaction<T>(
        _ operations: @escaping (Database) throws -> T
    ) async throws -> T {

        guard let writer = databaseManager.writer else {
            throw BatchSyncError.databaseNotInitialized
        }

        // writer.write already provides transaction semantics
        return try await writer.write { db in
            try operations(db)
        }
    }

    /// Import shows from search results in a batch
    func importSearchResults(
        _ searchResults: [TraktSearchResult]
    ) async throws -> BatchImportResult {

        guard let writer = databaseManager.writer else {
            throw BatchSyncError.databaseNotInitialized
        }

        let shows = searchResults.compactMap { $0.show }
        let movies = searchResults.compactMap { $0.movie }

        return try await writer.write { db in
            var importedShows = 0
            var importedMovies = 0
            var updatedShows = 0
            var updatedMovies = 0

            // Import shows
            for traktShow in shows {
                if let existingShow = try Show.findByTraktId(traktShow.ids.trakt, in: db) {
                    // Update existing show with new data from Trakt
                    var updatedShow = traktShow.toShow()
                    updatedShow.id = existingShow.id
                    // Preserve existing image URLs if Trakt doesn't have them
                    if updatedShow.posterUrl == nil {
                        updatedShow.posterUrl = existingShow.posterUrl
                    }
                    if updatedShow.backdropUrl == nil {
                        updatedShow.backdropUrl = existingShow.backdropUrl
                    }
                    try updatedShow.update(db)
                    updatedShows += 1
                } else {
                    let show = traktShow.toShow()
                    try show.insert(db)
                    importedShows += 1
                }
            }

            // Import movies
            for traktMovie in movies {
                var movie = traktMovie.toMovie()

                if let existingMovie = try Movie.findByTraktId(movie.traktId, in: db) {
                    movie.id = existingMovie.id
                    try movie.update(db)
                    updatedMovies += 1
                } else {
                    try movie.insert(db)
                    importedMovies += 1
                }
            }

            return BatchImportResult(
                importedShows: importedShows,
                importedMovies: importedMovies,
                updatedShows: updatedShows,
                updatedMovies: updatedMovies
            )
        }
    }

    // MARK: - Image Updates
    
    /// Update shows with missing images by re-fetching from Trakt with images
    func updateMissingImages(progress: ((Int, Int) -> Void)? = nil) async throws {
        guard let reader = databaseManager.reader,
              let writer = databaseManager.writer else {
            throw BatchSyncError.databaseNotInitialized
        }
        
        // Get shows without poster URLs
        let showsWithoutImages = try await reader.read { db in
            try Show
                .filter(Column("poster_url") == nil)
                .fetchAll(db)
        }
        
        print("🔍 Found \(showsWithoutImages.count) shows without poster URLs")
        
        var updatedCount = 0
        
        for (index, show) in showsWithoutImages.enumerated() {
            progress?(index + 1, showsWithoutImages.count)
            
            do {
                // Fetch show details from Trakt with images
                let traktShow = try await traktService.getShow(id: String(show.traktId))
                
                
                // Update show with image URLs from Trakt
                try await writer.write { db in
                    var updatedShow = traktShow.toShow()
                    updatedShow.id = show.id
                    try updatedShow.update(db)
                }
                
                if traktShow.images?.poster != nil {
                    updatedCount += 1
                }
            } catch {
                print("❌ Failed to fetch images for \(show.title): \(error)")
            }
        }
        
        print("✅ Updated images for \(updatedCount)/\(showsWithoutImages.count) shows")
    }

    // MARK: - Private Helpers

    private func syncShowWithEpisodes(
        showId: Int64,
        progressCallback: ((BatchSyncPhase) -> Void)?
    ) async throws -> Int {

        guard let reader = databaseManager.reader,
            let writer = databaseManager.writer
        else {
            throw BatchSyncError.databaseNotInitialized
        }

        // Get show from database
        let show = try await reader.read { db in
            try Show.fetchOne(db, key: showId)
        }

        guard let show = show else {
            throw BatchSyncError.showNotFound
        }

        progressCallback?(.fetchingSeasons)

        // Get all seasons
        let seasons = try await traktService.getSeasons(showId: String(show.traktId))

        var totalEpisodes = 0

        // Sync episodes for each season
        for season in seasons {
            guard season.number > 0 else { continue }  // Skip specials

            progressCallback?(.syncingEpisodes(season: season.number))

            let episodes = try await traktService.getEpisodes(
                showId: String(show.traktId),
                season: season.number
            )

            // Save episodes in a batch (writer.write already provides transaction)
            try await writer.write { db in
                for traktEpisode in episodes {
                    var episode = traktEpisode.toEpisode(showId: showId)

                    // Check if episode exists
                    if let existingEpisode =
                        try Episode
                        .filter(Column("trakt_id") == episode.traktId)
                        .fetchOne(db)
                    {
                        episode.id = existingEpisode.id
                        // Preserve watched status
                        if existingEpisode.watchedAt != nil {
                            episode.watchedAt = existingEpisode.watchedAt
                        }
                        try episode.update(db)
                    } else {
                        try episode.insert(db)
                    }
                }
            }

            totalEpisodes += episodes.count
        }

        progressCallback?(.syncingProgress)

        // Sync watched progress
        try await SyncManager.shared.syncWatchedProgress(showId: showId)

        return totalEpisodes
    }
}

// MARK: - Supporting Types

enum BatchSyncError: LocalizedError {
    case databaseNotInitialized
    case showNotFound
    case transactionFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database is not initialized"
        case .showNotFound:
            return "Show not found in database"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        }
    }
}

struct BatchSyncProgress {
    let current: Int
    let total: Int
    let currentShowId: Int64
    let phase: BatchSyncPhase

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total) * 100
    }
}

enum BatchSyncPhase {
    case starting
    case fetchingSeasons
    case syncingEpisodes(season: Int)
    case syncingProgress
    case completed

    var description: String {
        switch self {
        case .starting:
            return "Starting sync..."
        case .fetchingSeasons:
            return "Fetching seasons..."
        case .syncingEpisodes(let season):
            return "Syncing season \(season)..."
        case .syncingProgress:
            return "Syncing watched progress..."
        case .completed:
            return "Completed"
        }
    }
}

struct BatchSyncResult {
    let totalShows: Int
    let successCount: Int
    let failedShows: [(showId: Int64, error: Error)]
    let totalEpisodesSynced: Int

    var failureCount: Int {
        return failedShows.count
    }

    var successRate: Double {
        guard totalShows > 0 else { return 0 }
        return Double(successCount) / Double(totalShows) * 100
    }
}

struct BatchImportResult {
    let importedShows: Int
    let importedMovies: Int
    let updatedShows: Int
    let updatedMovies: Int

    var totalImported: Int {
        return importedShows + importedMovies
    }

    var totalUpdated: Int {
        return updatedShows + updatedMovies
    }

    var totalProcessed: Int {
        return totalImported + totalUpdated
    }
}

// MARK: - Helper Types for Concurrent Sync

struct AsyncSemaphore {
    private let semaphore: DispatchSemaphore
    
    init(value: Int) {
        semaphore = DispatchSemaphore(value: value)
    }
    
    func wait() async {
        await withCheckedContinuation { continuation in
            Task.detached {
                semaphore.wait()
                continuation.resume()
            }
        }
    }
    
    func signal() {
        semaphore.signal()
    }
}

enum SyncShowResult {
    case success(showId: Int64, episodeCount: Int)
    case failure(showId: Int64, error: Error)
}
