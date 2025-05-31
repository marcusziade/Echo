import Foundation
import GRDB

/// Episode model with essential fields
struct Episode: Codable {
    var id: Int64?
    let showId: Int64
    let traktId: Int
    let season: Int
    let number: Int
    let title: String?
    let overview: String?
    let runtime: Int?  // in minutes
    let airedAt: Date?
    var watchedAt: Date?

    enum Columns: String, ColumnExpression {
        case id
        case showId = "show_id"
        case traktId = "trakt_id"
        case season
        case number
        case title
        case overview
        case runtime
        case airedAt = "aired_at"
        case watchedAt = "watched_at"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case showId = "show_id"
        case traktId = "trakt_id"
        case season
        case number
        case title
        case overview
        case runtime
        case airedAt = "aired_at"
        case watchedAt = "watched_at"
    }

    init(
        id: Int64? = nil, showId: Int64, traktId: Int, season: Int, number: Int,
        title: String? = nil, overview: String? = nil, runtime: Int? = nil,
        airedAt: Date? = nil, watchedAt: Date? = nil
    ) {
        self.id = id
        self.showId = showId
        self.traktId = traktId
        self.season = season
        self.number = number
        self.title = title
        self.overview = overview
        self.runtime = runtime
        self.airedAt = airedAt
        self.watchedAt = watchedAt
    }
}

// MARK: - GRDB Protocols
extension Episode: FetchableRecord, PersistableRecord {
    static let databaseTableName = "episodes"

    // Tell GRDB which columns to encode
    func encode(to container: inout PersistenceContainer) {
        // Only encode id if it exists (for updates)
        if let id = id {
            container["id"] = id
        }
        container["show_id"] = showId
        container["trakt_id"] = traktId
        container["season"] = season
        container["number"] = number
        container["title"] = title
        container["overview"] = overview
        container["runtime"] = runtime
        container["aired_at"] = airedAt
        container["watched_at"] = watchedAt
    }

    // Tell GRDB that id is auto-generated
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Define the association to show
    static let show = belongsTo(Show.self)

    // Convenience method to fetch the show
    var show: QueryInterfaceRequest<Show> {
        request(for: Episode.show)
    }
}

// MARK: - Queries
extension Episode {
    /// Find an episode by show ID, season, and episode number
    static func find(showId: Int64, season: Int, number: Int, in db: Database) throws -> Episode? {
        try Episode
            .filter(Columns.showId == showId)
            .filter(Columns.season == season)
            .filter(Columns.number == number)
            .fetchOne(db)
    }

    /// Fetch all unwatched episodes ordered by air date
    static func unwatched() -> QueryInterfaceRequest<Episode> {
        Episode
            .filter(Columns.watchedAt == nil)
            .order(Columns.airedAt)
    }

    /// Mark episode as watched
    mutating func markAsWatched(at date: Date = Date()) {
        watchedAt = date
    }
}
