import Foundation
import GRDB

/// Manages synchronization between Trakt API and local database
final class SyncManager {
    static let shared = SyncManager()

    private let traktService = TraktService.shared
    private let databaseManager = DatabaseManager.shared

    private init() {}

    // MARK: - Search and Save

    /// Search for shows and save results to database
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum number of results
    /// - Returns: Array of saved shows
    @discardableResult
    func searchAndSaveShows(query: String, limit: Int = 10) async throws -> [Show] {
        print("🔍 Searching for: \(query)")

        // Search via API
        let traktShows = try await traktService.searchShows(query: query, limit: limit)

        // Convert and save to database
        let shows = traktShows.map { $0.toShow() }

        guard let writer = databaseManager.writer else {
            throw SyncError.databaseNotInitialized
        }

        let savedShows = try await writer.write { db in
            var results: [Show] = []

            for var show in shows {
                // Check if show already exists
                if let existingShow = try Show.findByTraktId(show.traktId, in: db) {
                    // Update existing show
                    show.id = existingShow.id
                    try show.update(db)
                    print("✅ Updated show: \(show.title)")
                } else {
                    // Insert new show
                    try show.insert(db)
                    print("✅ Inserted new show: \(show.title)")
                }
                results.append(show)
            }

            return results
        }

        print("✅ Saved \(savedShows.count) shows to database")
        return savedShows
    }

    // MARK: - Show Sync

    /// Sync a complete show with all seasons and episodes
    /// - Parameter showId: The show's database ID
    /// - Returns: The synced show
    @discardableResult
    func syncCompleteShow(showId: Int64) async throws -> Show {
        guard let reader = databaseManager.reader,
              let writer = databaseManager.writer else {
            throw SyncError.databaseNotInitialized
        }

        // Get show from database
        let show = try await reader.read { db in
            try Show.fetchOne(db, key: showId)
        }

        guard let show = show else {
            throw SyncError.showNotFound
        }

        print("🔄 Syncing show: \(show.title)")

        // Get detailed show info from API
        let detailedShow = try await traktService.getShow(id: String(show.traktId))

        // Get all seasons
        let seasons = try await traktService.getSeasons(showId: String(show.traktId))

        // Sync all episodes
        var totalEpisodes = 0

        for season in seasons {
            // Skip specials (season 0) if desired
            guard season.number > 0 else { continue }

            print("  📺 Syncing season \(season.number)...")

            let episodes = try await traktService.getEpisodes(
                showId: String(show.traktId),
                season: season.number
            )

            // Save episodes to database
            let episodesToSave = episodes.map { $0.toEpisode(showId: showId) }

            try await writer.write { db in
                for var episode in episodesToSave {
                    // Check if episode already exists by Trakt ID
                    if let existingEpisode = try Episode
                        .filter(Column("trakt_id") == episode.traktId)
                        .fetchOne(db) {
                        // Update existing episode
                        episode.id = existingEpisode.id
                        // Preserve watched status if already set
                        if existingEpisode.watchedAt != nil && episode.watchedAt == nil {
                            episode.watchedAt = existingEpisode.watchedAt
                        }
                        try episode.update(db)
                    } else {
                        // Insert new episode
                        try episode.insert(db)
                    }
                }
            }

            totalEpisodes += episodes.count
        }

        // Update show with latest info
        var updatedShow = detailedShow.toShow()
        updatedShow.id = showId

        let finalShow = try await writer.write { db in
            try updatedShow.update(db)
            return updatedShow
        }

        print("✅ Synced \(totalEpisodes) episodes for \(show.title)")

        return finalShow
    }

    // MARK: - Watched Progress Sync

    /// Sync watched progress for a show
    /// - Parameter showId: The show's database ID
    func syncWatchedProgress(showId: Int64) async throws {
        guard let reader = databaseManager.reader,
              let writer = databaseManager.writer else {
            throw SyncError.databaseNotInitialized
        }

        // Get show from database
        let show = try await reader.read { db in
            try Show.fetchOne(db, key: showId)
        }

        guard let show = show else {
            throw SyncError.showNotFound
        }

        // Get watched progress from API
        let progress = try await traktService.getShowProgress(showId: String(show.traktId))

        // Update watched status in database
        try await writer.write { db in
            // Get all episodes for this show
            let episodes = try Episode
                .filter(Column("show_id") == showId)
                .order(Column("season"), Column("number"))
                .fetchAll(db)

            // Create a lookup dictionary for quick access
            var episodeDict: [String: Episode] = [:]
            for episode in episodes {
                let key = "\(episode.season)-\(episode.number)"
                episodeDict[key] = episode
            }

            // Update watched status based on progress
            for season in progress.seasons ?? [] {
                for episodeProgress in season.episodes ?? [] {
                    let key = "\(season.number)-\(episodeProgress.number)"

                    if var episode = episodeDict[key] {
                        if episodeProgress.completed {
                            // Parse watched date if available
                            if let watchedAtString = episodeProgress.lastWatchedAt {
                                episode.watchedAt = watchedAtString.toDate()
                            } else {
                                episode.watchedAt = Date()
                            }
                        } else {
                            episode.watchedAt = nil
                        }

                        try episode.update(db)
                    }
                }
            }
        }

        print("✅ Synced watched progress for \(show.title)")
    }

    // MARK: - Utility Methods

    /// Get sync statistics for a show
    func getSyncStats(for showId: Int64) async throws -> ShowSyncStats {
        guard let reader = databaseManager.reader else {
            throw SyncError.databaseNotInitialized
        }

        return try await reader.read { db in
            let totalEpisodes = try Episode
                .filter(Column("show_id") == showId)
                .fetchCount(db)

            let watchedEpisodes = try Episode
                .filter(Column("show_id") == showId)
                .filter(Column("watched_at") != nil)
                .fetchCount(db)

            let airedEpisodes = try Episode
                .filter(Column("show_id") == showId)
                .filter(Column("aired_at") != nil)
                .filter(Column("aired_at") <= Date())
                .fetchCount(db)

            return ShowSyncStats(
                totalEpisodes: totalEpisodes,
                watchedEpisodes: watchedEpisodes,
                airedEpisodes: airedEpisodes
            )
        }
    }
}

// MARK: - Supporting Types

enum SyncError: LocalizedError {
    case databaseNotInitialized
    case showNotFound
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database is not initialized"
        case .showNotFound:
            return "Show not found in database"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}

struct ShowSyncStats {
    let totalEpisodes: Int
    let watchedEpisodes: Int
    let airedEpisodes: Int

    var watchedPercentage: Double {
        guard airedEpisodes > 0 else { return 0 }
        return Double(watchedEpisodes) / Double(airedEpisodes) * 100
    }

    var unwatchedAired: Int {
        return airedEpisodes - watchedEpisodes
    }
}

// MARK: - Date Extension
private extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: self)
    }
}
