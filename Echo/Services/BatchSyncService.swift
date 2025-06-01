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

        var successCount = 0
        var failedShows: [(showId: Int64, error: Error)] = []
        var totalEpisodesSynced = 0

        for (index, showId) in showIds.enumerated() {
            // Report progress
            progress?(
                BatchSyncProgress(
                    current: index,
                    total: showIds.count,
                    currentShowId: showId,
                    phase: .starting
                ))

            do {
                // Sync the show
                let syncedEpisodes = try await syncShowWithEpisodes(showId: showId) { phase in
                    progress?(
                        BatchSyncProgress(
                            current: index,
                            total: showIds.count,
                            currentShowId: showId,
                            phase: phase
                        ))
                }

                successCount += 1
                totalEpisodesSynced += syncedEpisodes

            } catch {
                failedShows.append((showId: showId, error: error))
                print("❌ Failed to sync show \(showId): \(error)")
            }

            // Report completion for this show
            progress?(
                BatchSyncProgress(
                    current: index + 1,
                    total: showIds.count,
                    currentShowId: showId,
                    phase: .completed
                ))
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
                var show = traktShow.toShow()

                if let existingShow = try Show.findByTraktId(show.traktId, in: db) {
                    show.id = existingShow.id
                    try show.update(db)
                    updatedShows += 1
                } else {
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
