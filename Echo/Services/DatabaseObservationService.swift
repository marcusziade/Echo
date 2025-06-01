import Combine
import Foundation
import GRDB

/// Service for observing database changes
final class DatabaseObservationService {
    static let shared = DatabaseObservationService()

    private let databaseManager = DatabaseManager.shared

    private init() {}

    // MARK: - Show Observations

    /// Observe all shows
    func observeShows() -> AnyPublisher<[Show], Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db in
                try Show.orderedByTitle().fetchAll(db)
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }

    /// Observe a specific show with its episodes
    func observeShow(id: Int64) -> AnyPublisher<ShowWithEpisodes?, Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db -> ShowWithEpisodes? in
                guard let show = try Show.fetchOne(db, key: id) else { return nil }
                let episodes = try show.episodes.fetchAll(db)
                return ShowWithEpisodes(show: show, episodes: episodes)
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }

    // MARK: - Episode Observations

    /// Observe unwatched episodes for Up Next
    func observeUpNextEpisodes() -> AnyPublisher<[UpNextItem], Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db -> [UpNextItem] in
                // Get all shows with unwatched episodes
                let shows = try Show.fetchAll(db)

                var upNextItems: [UpNextItem] = []

                for show in shows {
                    guard let showId = show.id else { continue }

                    // Find next episode to watch inline
                    let unwatchedEpisodes =
                        try Episode
                        .filter(Column("show_id") == showId)
                        .filter(Column("watched_at") == nil)
                        .filter(Column("aired_at") != nil)
                        .filter(Column("aired_at") <= Date())
                        .order(Column("season"), Column("number"))
                        .fetchAll(db)

                    guard !unwatchedEpisodes.isEmpty else { continue }

                    let lastWatchedEpisode =
                        try Episode
                        .filter(Column("show_id") == showId)
                        .filter(Column("watched_at") != nil)
                        .order(Column("season").desc, Column("number").desc)
                        .fetchOne(db)

                    var nextEpisode: Episode?

                    if let lastWatched = lastWatchedEpisode {
                        // Find first unwatched after last watched
                        nextEpisode =
                            unwatchedEpisodes.first { episode in
                                episode.season > lastWatched.season
                                    || (episode.season == lastWatched.season
                                        && episode.number > lastWatched.number)
                            } ?? unwatchedEpisodes.first
                    } else {
                        // Nothing watched yet, return first episode
                        nextEpisode = unwatchedEpisodes.first
                    }

                    if let nextEpisode = nextEpisode {
                        let progress = try WatchedProgress.calculateForShow(showId: showId, in: db)

                        upNextItems.append(
                            UpNextItem(
                                show: show,
                                nextEpisode: nextEpisode,
                                progress: progress
                            ))
                    }
                }

                // Sort by air date
                return upNextItems.sorted { item1, item2 in
                    guard let date1 = item1.nextEpisode.airedAt,
                        let date2 = item2.nextEpisode.airedAt
                    else {
                        return false
                    }
                    return date1 < date2
                }
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }

    /// Observe watched progress for a show
    func observeProgress(showId: Int64) -> AnyPublisher<WatchedProgress?, Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db in
                try WatchedProgress.calculateForShow(showId: showId, in: db)
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }

    // MARK: - Movies Observations

    /// Observe all movies
    func observeMovies(watched: Bool? = nil) -> AnyPublisher<[Movie], Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db in
                if let watched = watched {
                    return try (watched ? Movie.watched() : Movie.unwatched()).fetchAll(db)
                } else {
                    return try Movie.orderedByTitle().fetchAll(db)
                }
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }

    // MARK: - Statistics Observations

    /// Observe overall statistics
    func observeStatistics() -> AnyPublisher<DatabaseStatistics, Error> {
        guard let reader = databaseManager.reader else {
            return Fail(error: DatabaseObservationError.databaseNotInitialized)
                .eraseToAnyPublisher()
        }

        let observation =
            ValueObservation
            .tracking { db in
                let totalShows = try Show.fetchCount(db)
                let totalEpisodes = try Episode.fetchCount(db)
                let watchedEpisodes =
                    try Episode
                    .filter(Column("watched_at") != nil)
                    .fetchCount(db)
                let totalMovies = try Movie.fetchCount(db)
                let watchedMovies = try Movie.watched().fetchCount(db)

                return DatabaseStatistics(
                    totalShows: totalShows,
                    totalEpisodes: totalEpisodes,
                    watchedEpisodes: watchedEpisodes,
                    totalMovies: totalMovies,
                    watchedMovies: watchedMovies
                )
            }

        return
            observation
            .publisher(in: reader, scheduling: .async(onQueue: .main))
            .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

enum DatabaseObservationError: LocalizedError {
    case databaseNotInitialized

    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database is not initialized"
        }
    }
}

struct ShowWithEpisodes {
    let show: Show
    let episodes: [Episode]
}

struct UpNextItem {
    let show: Show
    let nextEpisode: Episode
    let progress: WatchedProgress?

    var daysUntilAir: Int? {
        guard let airedAt = nextEpisode.airedAt else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: airedAt).day
        return days
    }

    var isAired: Bool {
        guard let airedAt = nextEpisode.airedAt else { return false }
        return airedAt <= Date()
    }
}

struct DatabaseStatistics {
    let totalShows: Int
    let totalEpisodes: Int
    let watchedEpisodes: Int
    let totalMovies: Int
    let watchedMovies: Int

    var episodeWatchedPercentage: Double {
        guard totalEpisodes > 0 else { return 0 }
        return Double(watchedEpisodes) / Double(totalEpisodes) * 100
    }

    var movieWatchedPercentage: Double {
        guard totalMovies > 0 else { return 0 }
        return Double(watchedMovies) / Double(totalMovies) * 100
    }
}
