import Foundation
import GRDB

/// Model to track watched progress for shows and movies
struct WatchedProgress: Codable {
    let mediaType: MediaType
    let mediaId: Int64  // Show or Movie ID
    let totalItems: Int
    let watchedItems: Int
    let lastWatchedAt: Date?
    let nextItemToWatch: NextItem?

    enum MediaType: String, Codable, DatabaseValueConvertible {
        case show
        case movie
    }

    struct NextItem: Codable {
        let season: Int?
        let episode: Int?
        let title: String?
        let airedAt: Date?
    }

    var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(watchedItems) / Double(totalItems) * 100
    }

    var isCompleted: Bool {
        return watchedItems >= totalItems && totalItems > 0
    }

    var remainingItems: Int {
        return max(0, totalItems - watchedItems)
    }
}

// MARK: - Database Queries for Progress
extension WatchedProgress {

    /// Calculate watched progress for a show
    static func calculateForShow(showId: Int64, in db: Database) throws -> WatchedProgress? {
        // Get total aired episodes
        let totalEpisodes =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("aired_at") != nil)
            .filter(Column("aired_at") <= Date())
            .fetchCount(db)

        guard totalEpisodes > 0 else { return nil }

        // Get watched episodes
        let watchedEpisodes =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("watched_at") != nil)
            .fetchCount(db)

        // Get last watched episode
        let lastWatchedEpisode =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("watched_at") != nil)
            .order(Column("watched_at").desc)
            .fetchOne(db)

        // Get next episode to watch
        var nextItem: NextItem? = nil
        if let nextEpisode = try findNextEpisodeToWatch(showId: showId, in: db) {
            nextItem = NextItem(
                season: nextEpisode.season,
                episode: nextEpisode.number,
                title: nextEpisode.title,
                airedAt: nextEpisode.airedAt
            )
        }

        return WatchedProgress(
            mediaType: .show,
            mediaId: showId,
            totalItems: totalEpisodes,
            watchedItems: watchedEpisodes,
            lastWatchedAt: lastWatchedEpisode?.watchedAt,
            nextItemToWatch: nextItem
        )
    }

    /// Calculate watched progress for all shows
    static func calculateForAllShows(in db: Database) throws -> [WatchedProgress] {
        let shows = try Show.fetchAll(db)

        return try shows.compactMap { show in
            guard let showId = show.id else { return nil }
            return try calculateForShow(showId: showId, in: db)
        }
    }

    /// Find the next episode to watch for a show
    private static func findNextEpisodeToWatch(showId: Int64, in db: Database) throws -> Episode? {
        // Get all unwatched episodes that have aired
        let unwatchedEpisodes =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("watched_at") == nil)
            .filter(Column("aired_at") != nil)
            .filter(Column("aired_at") <= Date())
            .order(Column("season"), Column("number"))
            .fetchAll(db)

        // If no unwatched episodes, return nil
        guard !unwatchedEpisodes.isEmpty else { return nil }

        // Get the last watched episode
        let lastWatchedEpisode =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("watched_at") != nil)
            .order(Column("season").desc, Column("number").desc)
            .fetchOne(db)

        // If nothing watched yet, return the first episode
        guard let lastWatched = lastWatchedEpisode else {
            return unwatchedEpisodes.first
        }

        // Find the first unwatched episode after the last watched one
        for episode in unwatchedEpisodes {
            if episode.season > lastWatched.season
                || (episode.season == lastWatched.season && episode.number > lastWatched.number)
            {
                return episode
            }
        }

        // If no episodes after the last watched, return the first unwatched
        return unwatchedEpisodes.first
    }
}

// MARK: - Progress Tracking Methods
extension Show {
    /// Get watched progress for this show
    func getProgress(in db: Database) throws -> WatchedProgress? {
        guard let id = self.id else { return nil }
        return try WatchedProgress.calculateForShow(showId: id, in: db)
    }
}

// MARK: - Batch Progress Updates
extension Episode {
    /// Mark multiple episodes as watched
    static func markAsWatched(showId: Int64, upToSeason season: Int, episode: Int, in db: Database)
        throws
    {
        let episodes =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(
                (Column("season") < season)
                    || (Column("season") == season && Column("number") <= episode)
            )
            .fetchAll(db)

        let watchedDate = Date()

        for var episode in episodes {
            if episode.watchedAt == nil {
                episode.watchedAt = watchedDate
                try episode.update(db)
            }
        }
    }

    /// Mark an entire season as watched
    static func markSeasonAsWatched(showId: Int64, season: Int, in db: Database) throws {
        let episodes =
            try Episode
            .filter(Column("show_id") == showId)
            .filter(Column("season") == season)
            .fetchAll(db)

        let watchedDate = Date()

        for var episode in episodes {
            if episode.watchedAt == nil {
                episode.watchedAt = watchedDate
                try episode.update(db)
            }
        }
    }

    /// Mark all episodes of a show as watched
    static func markShowAsWatched(showId: Int64, in db: Database) throws {
        let episodes =
            try Episode
            .filter(Column("show_id") == showId)
            .fetchAll(db)

        let watchedDate = Date()

        for var episode in episodes {
            if episode.watchedAt == nil {
                episode.watchedAt = watchedDate
                try episode.update(db)
            }
        }
    }
}
