import Foundation
import GRDB

/// Movie model with essential fields
struct Movie: Codable {
    var id: Int64?
    let traktId: Int
    let title: String
    let year: Int?
    let overview: String?
    let runtime: Int?  // in minutes
    let released: Date?
    let certification: String?
    let tagline: String?
    var watchedAt: Date?
    let updatedAt: Date?
    let posterUrl: String?
    let backdropUrl: String?
    let tmdbId: Int?

    enum Columns: String, ColumnExpression {
        case id
        case traktId = "trakt_id"
        case title
        case year
        case overview
        case runtime
        case released
        case certification
        case tagline
        case watchedAt = "watched_at"
        case updatedAt = "updated_at"
        case posterUrl = "poster_url"
        case backdropUrl = "backdrop_url"
        case tmdbId = "tmdb_id"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case traktId = "trakt_id"
        case title
        case year
        case overview
        case runtime
        case released
        case certification
        case tagline
        case watchedAt = "watched_at"
        case updatedAt = "updated_at"
        case posterUrl = "poster_url"
        case backdropUrl = "backdrop_url"
        case tmdbId = "tmdb_id"
    }

    init(
        id: Int64? = nil, traktId: Int, title: String, year: Int? = nil,
        overview: String? = nil, runtime: Int? = nil, released: Date? = nil,
        certification: String? = nil, tagline: String? = nil,
        watchedAt: Date? = nil, updatedAt: Date? = nil, posterUrl: String? = nil,
        backdropUrl: String? = nil, tmdbId: Int? = nil
    ) {
        self.id = id
        self.traktId = traktId
        self.title = title
        self.year = year
        self.overview = overview
        self.runtime = runtime
        self.released = released
        self.certification = certification
        self.tagline = tagline
        self.watchedAt = watchedAt
        self.updatedAt = updatedAt
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
        self.tmdbId = tmdbId
    }
}

// MARK: - GRDB Protocols
extension Movie: FetchableRecord, PersistableRecord {
    static let databaseTableName = "movies"

    // Tell GRDB which columns to encode
    func encode(to container: inout PersistenceContainer) {
        // Only encode id if it exists (for updates)
        if let id = id {
            container["id"] = id
        }
        container["trakt_id"] = traktId
        container["title"] = title
        container["year"] = year
        container["overview"] = overview
        container["runtime"] = runtime
        container["released"] = released
        container["certification"] = certification
        container["tagline"] = tagline
        container["watched_at"] = watchedAt
        container["updated_at"] = updatedAt
        container["poster_url"] = posterUrl
        container["backdrop_url"] = backdropUrl
        container["tmdb_id"] = tmdbId
    }

    // Tell GRDB that id is auto-generated
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Queries
extension Movie {
    /// Find a movie by its Trakt ID
    static func findByTraktId(_ traktId: Int, in db: Database) throws -> Movie? {
        try Movie.filter(Columns.traktId == traktId).fetchOne(db)
    }

    /// Fetch all movies ordered by title
    static func orderedByTitle() -> QueryInterfaceRequest<Movie> {
        Movie.order(Columns.title)
    }

    /// Fetch all movies ordered by release date (newest first)
    static func orderedByReleaseDate() -> QueryInterfaceRequest<Movie> {
        Movie
            .order(Columns.released.desc)
            .order(Columns.title)
    }

    /// Fetch all watched movies
    static func watched() -> QueryInterfaceRequest<Movie> {
        Movie
            .filter(Columns.watchedAt != nil)
            .order(Columns.watchedAt.desc)
    }

    /// Fetch all unwatched movies
    static func unwatched() -> QueryInterfaceRequest<Movie> {
        Movie
            .filter(Columns.watchedAt == nil)
            .order(Columns.title)
    }

    /// Mark movie as watched
    mutating func markAsWatched(at date: Date = Date()) {
        watchedAt = date
    }

    /// Mark movie as unwatched
    mutating func markAsUnwatched() {
        watchedAt = nil
    }
}

