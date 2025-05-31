import Foundation

// MARK: - Search Response
struct TraktSearchResult: Codable {
    let type: String
    let score: Double?
    let show: TraktShow?
    let movie: TraktMovie?
}

// MARK: - Show Models
struct TraktShow: Codable {
    let ids: TraktIds
    let title: String
    let year: Int?
    let overview: String?
    let runtime: Int?
    let network: String?
    let status: String?
    let updatedAt: String?
    let airedEpisodes: Int?

    enum CodingKeys: String, CodingKey {
        case ids, title, year, overview, runtime, network, status
        case updatedAt = "updated_at"
        case airedEpisodes = "aired_episodes"
    }
}

struct TraktMovie: Codable {
    let ids: TraktIds
    let title: String
    let year: Int?
    let overview: String?
    let runtime: Int?
    let released: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case ids, title, year, overview, runtime, released
        case updatedAt = "updated_at"
    }
}

// MARK: - Episode Models
struct TraktEpisode: Codable {
    let ids: TraktIds
    let season: Int
    let number: Int
    let title: String?
    let overview: String?
    let runtime: Int?
    let firstAired: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case ids, season, number, title, overview, runtime
        case firstAired = "first_aired"
        case updatedAt = "updated_at"
    }
}

struct TraktSeason: Codable {
    let ids: TraktIds
    let number: Int
    let episodeCount: Int?
    let airedEpisodes: Int?
    let episodes: [TraktEpisode]?

    enum CodingKeys: String, CodingKey {
        case ids, number, episodes
        case episodeCount = "episode_count"
        case airedEpisodes = "aired_episodes"
    }
}

// MARK: - Common Models
struct TraktIds: Codable {
    let trakt: Int
    let slug: String?
    let imdb: String?
    let tmdb: Int?
    let tvdb: Int?
}

// MARK: - History/Progress Models
struct TraktWatchedProgress: Codable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: String?
    let resetAt: String?
    let seasons: [TraktSeasonProgress]?
    let hiddenSeasons: [TraktSeason]?
    let nextEpisode: TraktEpisode?
    let lastEpisode: TraktEpisode?

    enum CodingKeys: String, CodingKey {
        case aired, completed, seasons
        case lastWatchedAt = "last_watched_at"
        case resetAt = "reset_at"
        case hiddenSeasons = "hidden_seasons"
        case nextEpisode = "next_episode"
        case lastEpisode = "last_episode"
    }
}

struct TraktSeasonProgress: Codable {
    let number: Int
    let aired: Int
    let completed: Int
    let episodes: [TraktEpisodeProgress]?
}

struct TraktEpisodeProgress: Codable {
    let number: Int
    let completed: Bool
    let lastWatchedAt: String?

    enum CodingKeys: String, CodingKey {
        case number, completed
        case lastWatchedAt = "last_watched_at"
    }
}

// MARK: - Sync Models
struct TraktWatchedItem: Codable {
    let watchedAt: String
    let ids: TraktIds

    enum CodingKeys: String, CodingKey {
        case watchedAt = "watched_at"
        case ids
    }
}

struct TraktHistoryItem: Codable {
    let id: Int
    let watchedAt: String
    let action: String
    let type: String
    let episode: TraktEpisode?
    let show: TraktShow?

    enum CodingKeys: String, CodingKey {
        case id
        case watchedAt = "watched_at"
        case action, type, episode, show
    }
}

// MARK: - Sync Request Bodies
struct TraktSyncItems: Codable {
    let shows: [TraktSyncShow]?
    let movies: [TraktSyncMovie]?
    let episodes: [TraktSyncEpisode]?
}

struct TraktSyncShow: Codable {
    let ids: TraktIds
    let seasons: [TraktSyncSeason]?
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case ids, seasons
        case watchedAt = "watched_at"
    }
}

struct TraktSyncSeason: Codable {
    let number: Int
    let episodes: [TraktSyncEpisode]?
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case number, episodes
        case watchedAt = "watched_at"
    }
}

struct TraktSyncEpisode: Codable {
    let number: Int?
    let ids: TraktIds?
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case number, ids
        case watchedAt = "watched_at"
    }
}

struct TraktSyncMovie: Codable {
    let ids: TraktIds
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case ids
        case watchedAt = "watched_at"
    }
}

// MARK: - Conversion Extensions
extension TraktShow {
    /// Convert Trakt API show to local database model
    func toShow() -> Show {
        return Show(
            traktId: ids.trakt,
            title: title,
            year: year,
            overview: overview,
            runtime: runtime,
            status: status,
            network: network,
            updatedAt: updatedAt?.toDate()
        )
    }
}

extension TraktEpisode {
    /// Convert Trakt API episode to local database model
    func toEpisode(showId: Int64) -> Episode {
        return Episode(
            showId: showId,
            traktId: ids.trakt,
            season: season,
            number: number,
            title: title,
            overview: overview,
            runtime: runtime,
            airedAt: firstAired?.toDate()
        )
    }
}

// MARK: - Date String Extension
extension String {
    fileprivate func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: self)
    }
}
