import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {}

    // MARK: - Setup
    func setup() throws {
        let databaseURL = try getDatabaseURL()

        // Create database queue
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        // Run migrations
        try migrator.migrate(dbQueue!)

        print("✅ Database setup complete at: \(databaseURL.path)")
    }

    // MARK: - Database Access
    var reader: DatabaseReader? {
        return dbQueue
    }

    var writer: DatabaseWriter? {
        return dbQueue
    }

    // MARK: - Private Helpers
    private func getDatabaseURL() throws -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first!

        let documentsURL = URL(fileURLWithPath: documentsPath)
        let databaseURL = documentsURL.appendingPathComponent("echo.db")

        return databaseURL
    }

    // MARK: - Migrations
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Migration v1: Create shows table (enhanced)
        migrator.registerMigration("v1") { db in
            try db.create(table: "shows") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("trakt_id", .integer).notNull().unique()
                t.column("title", .text).notNull()
                t.column("year", .integer)
                t.column("overview", .text)
                t.column("runtime", .integer)
                t.column("status", .text)
                t.column("network", .text)
                t.column("updated_at", .datetime)
            }

            // Create index on trakt_id for faster lookups
            try db.create(index: "idx_shows_trakt_id", on: "shows", columns: ["trakt_id"])
        }

        // Migration v2: Create episodes table
        migrator.registerMigration("v2") { db in
            try db.create(table: "episodes") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("show_id", .integer)
                    .notNull()
                    .references("shows", onDelete: .cascade)
                t.column("trakt_id", .integer).notNull().unique()
                t.column("season", .integer).notNull()
                t.column("number", .integer).notNull()
                t.column("title", .text)
                t.column("overview", .text)
                t.column("runtime", .integer)
                t.column("aired_at", .datetime)
                t.column("watched_at", .datetime)
            }

            // Create indexes for common queries
            try db.create(index: "idx_episodes_show_id", on: "episodes", columns: ["show_id"])
            try db.create(index: "idx_episodes_trakt_id", on: "episodes", columns: ["trakt_id"])
            try db.create(
                index: "idx_episodes_show_season_number",
                on: "episodes",
                columns: ["show_id", "season", "number"],
                unique: true
            )
        }

        return migrator
    }

    // MARK: - Test Helpers
    func testModels() {
        do {
            try dbQueue?.write { db in
                // Create a test show
                var show = Show(
                    traktId: 1390,
                    title: "Breaking Bad",
                    year: 2008,
                    overview:
                        "A high school chemistry teacher diagnosed with cancer starts making meth.",
                    runtime: 45,
                    status: "ended",
                    network: "AMC",
                    updatedAt: Date()
                )

                try show.insert(db)

                // Get the last inserted row ID
                show.id = db.lastInsertedRowID

                print("✅ Show saved with ID: \(show.id ?? 0)")

                // Make sure we have a valid show ID
                guard let showId = show.id, showId > 0 else {
                    print("❌ Failed to get show ID after insert")
                    return
                }

                // Create some episodes
                let episode1 = Episode(
                    showId: showId,
                    traktId: 73640,
                    season: 1,
                    number: 1,
                    title: "Pilot",
                    overview: "Walter White, a struggling high school chemistry teacher...",
                    runtime: 58,
                    airedAt: Date(timeIntervalSince1970: 1_200_880_800),  // 2008-01-20
                    watchedAt: nil
                )

                let episode2 = Episode(
                    showId: showId,
                    traktId: 73641,
                    season: 1,
                    number: 2,
                    title: "Cat's in the Bag...",
                    overview: "Walt and Jesse attempt to tie up loose ends...",
                    runtime: 48,
                    airedAt: Date(timeIntervalSince1970: 1_201_485_600),  // 2008-01-27
                    watchedAt: Date()  // Marked as watched
                )

                try episode1.insert(db)
                try episode2.insert(db)
                print("✅ Episodes saved")

                // Test fetching show with episodes
                if let fetchedShow = try Show.fetchOne(db, key: showId) {
                    let episodes = try fetchedShow.episodes.fetchAll(db)
                    print("✅ Fetched show '\(fetchedShow.title)' with \(episodes.count) episodes")

                    for episode in episodes {
                        let watchedStatus = episode.watchedAt != nil ? "watched" : "unwatched"
                        print(
                            "  - S\(episode.season)E\(episode.number): \(episode.title ?? "Untitled") [\(watchedStatus)]"
                        )
                    }
                }

                // Test finding episode
                if let foundEpisode = try Episode.find(showId: showId, season: 1, number: 1, in: db)
                {
                    print("✅ Found episode by season/number: \(foundEpisode.title ?? "Untitled")")
                }

                // Test unwatched episodes query
                let unwatchedCount = try Episode.unwatched().fetchCount(db)
                print("✅ Unwatched episodes: \(unwatchedCount)")

                // Clean up test data
                _ = try Show.deleteAll(db)
                print("✅ Test data cleaned up")
            }
        } catch {
            print("❌ Model test failed: \(error)")
        }
    }
}
