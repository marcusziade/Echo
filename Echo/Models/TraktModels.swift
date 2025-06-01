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
    let images: TraktImages?

    enum CodingKeys: String, CodingKey {
        case ids, title, year, overview, runtime, network, status, images
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
    let images: TraktImages?

    enum CodingKeys: String, CodingKey {
        case ids, title, year, overview, runtime, released, images
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

struct TraktImages: Codable {
    let fanart: TraktImageSet?
    let poster: TraktImageSet?
    let logo: TraktImageSet?
    let clearart: TraktImageSet?
    let banner: TraktImageSet?
    let thumb: TraktImageSet?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle fanart which can be either object or array
        self.fanart = TraktImages.decodeFlexibleImageSet(from: container, key: .fanart)
        self.poster = TraktImages.decodeFlexibleImageSet(from: container, key: .poster)
        self.logo = TraktImages.decodeFlexibleImageSet(from: container, key: .logo)
        self.clearart = TraktImages.decodeFlexibleImageSet(from: container, key: .clearart)
        self.banner = TraktImages.decodeFlexibleImageSet(from: container, key: .banner)
        self.thumb = TraktImages.decodeFlexibleImageSet(from: container, key: .thumb)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fanart, forKey: .fanart)
        try container.encodeIfPresent(poster, forKey: .poster)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(clearart, forKey: .clearart)
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(thumb, forKey: .thumb)
    }
    
    private static func decodeFlexibleImageSet(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> TraktImageSet? {
        // Try array of strings first (new Trakt API format)
        if let arrayValue = try? container.decode([String].self, forKey: key),
           let first = arrayValue.first {
            return TraktImageSet(full: first, medium: first, thumb: first)
        }
        
        // Try array of objects
        if let arrayValue = try? container.decode([TraktImageSetRaw].self, forKey: key),
           let first = arrayValue.first {
            return TraktImageSet(full: first.full, medium: first.medium, thumb: first.thumb)
        }
        
        // Try object
        if let objectValue = try? container.decode(TraktImageSetRaw.self, forKey: key) {
            return TraktImageSet(full: objectValue.full, medium: objectValue.medium, thumb: objectValue.thumb)
        }
        
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case fanart, poster, logo, clearart, banner, thumb
    }
}

private struct TraktImageSetRaw: Codable {
    let full: String?
    let medium: String?
    let thumb: String?
}

struct TraktImageSet: Codable {
    let full: String?
    let medium: String?
    let thumb: String?
    
    init(full: String?, medium: String?, thumb: String?) {
        self.full = full
        self.medium = medium
        self.thumb = thumb
    }
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
            updatedAt: updatedAt?.toDate(),
            posterUrl: images?.poster?.medium ?? images?.poster?.full,
            backdropUrl: images?.fanart?.medium ?? images?.fanart?.full,
            tmdbId: ids.tmdb
        )
    }
}

extension TraktMovie {
    /// Convert Trakt API movie to local database model
    func toMovie() -> Movie {
        return Movie(
            traktId: ids.trakt,
            title: title,
            year: year,
            overview: overview,
            runtime: runtime,
            released: released?.toDate(),
            certification: nil,  // Not in TraktMovie model
            tagline: nil,  // Not in TraktMovie model
            updatedAt: updatedAt?.toDate(),
            posterUrl: images?.poster?.medium ?? images?.poster?.full,
            backdropUrl: images?.fanart?.medium ?? images?.fanart?.full,
            tmdbId: ids.tmdb
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
