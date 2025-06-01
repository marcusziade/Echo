import Foundation
import GRDB

/// Enhanced Show model with essential fields
struct Show: Codable {
    var id: Int64?
    let traktId: Int
    let title: String
    let year: Int?
    let overview: String?
    let runtime: Int?  // in minutes
    let status: String?  // "returning series", "ended", etc.
    let network: String?
    let updatedAt: Date?
    var posterUrl: String?
    var backdropUrl: String?
    let tmdbId: Int?

    enum Columns: String, ColumnExpression {
        case id
        case traktId = "trakt_id"
        case title
        case year
        case overview
        case runtime
        case status
        case network
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
        case status
        case network
        case updatedAt = "updated_at"
        case posterUrl = "poster_url"
        case backdropUrl = "backdrop_url"
        case tmdbId = "tmdb_id"
    }

    init(
        id: Int64? = nil, traktId: Int, title: String, year: Int? = nil,
        overview: String? = nil, runtime: Int? = nil, status: String? = nil,
        network: String? = nil, updatedAt: Date? = nil, posterUrl: String? = nil,
        backdropUrl: String? = nil, tmdbId: Int? = nil
    ) {
        self.id = id
        self.traktId = traktId
        self.title = title
        self.year = year
        self.overview = overview
        self.runtime = runtime
        self.status = status
        self.network = network
        self.updatedAt = updatedAt
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
        self.tmdbId = tmdbId
    }
}

// MARK: - GRDB Protocols
extension Show: FetchableRecord, PersistableRecord {
    static let databaseTableName = "shows"

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
        container["status"] = status
        container["network"] = network
        container["updated_at"] = updatedAt
        container["poster_url"] = posterUrl
        container["backdrop_url"] = backdropUrl
        container["tmdb_id"] = tmdbId
    }

    // Tell GRDB that id is auto-generated
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Define the association to episodes
    static let episodes = hasMany(Episode.self)

    // Convenience method to fetch show with episodes
    var episodes: QueryInterfaceRequest<Episode> {
        request(for: Show.episodes)
    }
}

// MARK: - Queries
extension Show {
    /// Find a show by its Trakt ID
    static func findByTraktId(_ traktId: Int, in db: Database) throws -> Show? {
        try Show.filter(Columns.traktId == traktId).fetchOne(db)
    }

    /// Fetch all shows ordered by title
    static func orderedByTitle() -> QueryInterfaceRequest<Show> {
        Show.order(Columns.title)
    }
}
