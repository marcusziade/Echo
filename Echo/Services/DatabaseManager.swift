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

        // Migration v1: Create shows table
        migrator.registerMigration("v1") { db in
            try db.create(table: "shows") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
            }
        }

        return migrator
    }

    // MARK: - Test Helper
    func testDatabaseSetup() {
        do {
            // Setup database
            try setup()

            // Test read
            try dbQueue?.read { db in
                // Check if shows table exists
                let tableExists = try db.tableExists("shows")
                print("✅ Shows table exists: \(tableExists)")

                // Get table info
                let columns = try db.columns(in: "shows")
                print("✅ Shows table columns:")
                for column in columns {
                    print("  - \(column.name): \(column.type)")
                }
            }

            // Test write with model (if you've created Show.swift)
            // Uncomment the following if you've added the Show model:
            /*
             try dbQueue?.write { db in
             // Create and save a test show
             var testShow = Show(title: "Breaking Bad")
             try testShow.save(db)

             // Fetch all shows
             let shows = try Show.fetchAll(db)
             print("✅ Model test successful. Shows count: \(shows.count)")
             print("✅ First show: \(shows.first?.title ?? "none")")

             // Clean up
             _ = try testShow.delete(db)
             }
             */

            // Test write with raw SQL
            try dbQueue?.write { db in
                // Insert a test show
                try db.execute(
                    sql: "INSERT INTO shows (title) VALUES (?)",
                    arguments: ["Test Show"]
                )

                // Query it back
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM shows")!
                print("✅ Test insert successful. Row count: \(count)")

                // Clean up test data
                try db.execute(sql: "DELETE FROM shows WHERE title = ?", arguments: ["Test Show"])
            }

        } catch {
            print("❌ Database test failed: \(error)")
        }
    }
}

// MARK: - Database Errors
enum DatabaseError: LocalizedError {
    case notInitialized
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}
