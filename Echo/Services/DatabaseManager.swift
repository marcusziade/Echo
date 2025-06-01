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

        // Migration v3: Create movies table
        migrator.registerMigration("v3") { db in
            try db.create(table: "movies") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("trakt_id", .integer).notNull().unique()
                t.column("title", .text).notNull()
                t.column("year", .integer)
                t.column("overview", .text)
                t.column("runtime", .integer)
                t.column("released", .datetime)
                t.column("certification", .text)
                t.column("tagline", .text)
                t.column("watched_at", .datetime)
                t.column("updated_at", .datetime)
            }

            // Create indexes for common queries
            try db.create(index: "idx_movies_trakt_id", on: "movies", columns: ["trakt_id"])
            try db.create(index: "idx_movies_watched_at", on: "movies", columns: ["watched_at"])
            try db.create(index: "idx_movies_released", on: "movies", columns: ["released"])
        }
        
        // Migration v4: Add image fields to shows and movies
        migrator.registerMigration("v4") { db in
            // Add image fields to shows
            try db.alter(table: "shows") { t in
                t.add(column: "poster_url", .text)
                t.add(column: "backdrop_url", .text)
                t.add(column: "tmdb_id", .integer)
            }
            
            // Add image fields to movies
            try db.alter(table: "movies") { t in
                t.add(column: "poster_url", .text)
                t.add(column: "backdrop_url", .text)
                t.add(column: "tmdb_id", .integer)
            }
            
            // Create indexes for TMDB IDs
            try db.create(index: "idx_shows_tmdb_id", on: "shows", columns: ["tmdb_id"])
            try db.create(index: "idx_movies_tmdb_id", on: "movies", columns: ["tmdb_id"])
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

                // Test movies
                print("\n📽️ Testing Movies...")
                try testMovies(in: db)

                // Test watched progress
                print("\n📊 Testing Watched Progress...")
                try testWatchedProgress(in: db)

                // Clean up test data
                _ = try Show.deleteAll(db)
                _ = try Movie.deleteAll(db)
                print("✅ Test data cleaned up")
            }
        } catch {
            print("❌ Model test failed: \(error)")
        }
    }

    // MARK: - Movie Tests
    private func testMovies(in db: Database) throws {
        // Create test movies
        let movie1 = Movie(
            traktId: 120,
            title: "The Lord of the Rings: The Fellowship of the Ring",
            year: 2001,
            overview:
                "A meek Hobbit from the Shire and eight companions set out on a journey to destroy the powerful One Ring and save Middle-earth from the Dark Lord Sauron.",
            runtime: 178,
            released: Date(timeIntervalSince1970: 1_008_115_200),  // 2001-12-19
            certification: "PG-13",
            tagline: "One Ring To Rule Them All",
            watchedAt: Date()  // Marked as watched
        )

        let movie2 = Movie(
            traktId: 121,
            title: "The Lord of the Rings: The Two Towers",
            year: 2002,
            overview:
                "While Frodo and Sam edge closer to Mordor with the help of the shifty Gollum, the divided fellowship makes a stand against Sauron's new ally, Saruman, and his hordes of Isengard.",
            runtime: 179,
            released: Date(timeIntervalSince1970: 1_040_169_600),  // 2002-12-18
            certification: "PG-13",
            tagline: "A New Power Is Rising",
            watchedAt: nil  // Not watched yet
        )

        try movie1.insert(db)
        try movie2.insert(db)
        print("✅ Movies saved")

        // Test finding movie by Trakt ID
        if let foundMovie = try Movie.findByTraktId(120, in: db) {
            print("✅ Found movie by Trakt ID: \(foundMovie.title)")
        }

        // Test watched movies
        let watchedMovies = try Movie.watched().fetchAll(db)
        print("✅ Watched movies: \(watchedMovies.count)")
        for movie in watchedMovies {
            print("  - \(movie.title) (\(movie.year ?? 0))")
        }

        // Test unwatched movies
        let unwatchedMovies = try Movie.unwatched().fetchAll(db)
        print("✅ Unwatched movies: \(unwatchedMovies.count)")
        for movie in unwatchedMovies {
            print("  - \(movie.title) (\(movie.year ?? 0))")
        }

        // Test marking as watched/unwatched
        if var movie = try Movie.findByTraktId(121, in: db) {
            movie.markAsWatched()
            try movie.update(db)
            print("✅ Marked '\(movie.title)' as watched")

            movie.markAsUnwatched()
            try movie.update(db)
            print("✅ Marked '\(movie.title)' as unwatched")
        }
    }

    // MARK: - Watched Progress Tests
    private func testWatchedProgress(in db: Database) throws {
        // Create a test show with episodes
        var show = Show(
            traktId: 60625,
            title: "Rick and Morty",
            year: 2013,
            overview:
                "An animated series that follows the exploits of a super scientist and his not-so-bright grandson.",
            runtime: 22,
            status: "returning series",
            network: "Adult Swim",
            updatedAt: Date()
        )

        try show.insert(db)
        show.id = db.lastInsertedRowID

        guard let showId = show.id else { return }

        // Create episodes for season 1
        let season1Episodes = [
            ("Pilot", 1, Date(timeIntervalSince1970: 1_386_547_200)),  // 2013-12-02
            ("Lawnmower Dog", 2, Date(timeIntervalSince1970: 1_387_152_000)),  // 2013-12-09
            ("Anatomy Park", 3, Date(timeIntervalSince1970: 1_387_756_800)),  // 2013-12-16
            ("M. Night Shaym-Aliens!", 4, Date(timeIntervalSince1970: 1_389_571_200)),  // 2014-01-13
            ("Meeseeks and Destroy", 5, Date(timeIntervalSince1970: 1_390_176_000)),  // 2014-01-20
        ]

        var episodeId = 1000
        for (title, number, airedAt) in season1Episodes {
            let episode = Episode(
                showId: showId,
                traktId: episodeId,
                season: 1,
                number: number,
                title: title,
                runtime: 22,
                airedAt: airedAt,
                watchedAt: nil
            )
            try episode.insert(db)
            episodeId += 1
        }

        print("✅ Created show with \(season1Episodes.count) episodes")

        // Test initial progress (nothing watched)
        if let progress = try WatchedProgress.calculateForShow(showId: showId, in: db) {
            print("\n📊 Initial Progress:")
            print("  - Total episodes: \(progress.totalItems)")
            print("  - Watched: \(progress.watchedItems)")
            print("  - Progress: \(String(format: "%.1f", progress.progressPercentage))%")
            print("  - Completed: \(progress.isCompleted)")
            if let next = progress.nextItemToWatch {
                print(
                    "  - Next to watch: S\(next.season ?? 0)E\(next.episode ?? 0) - \(next.title ?? "Unknown")"
                )
            }
        }

        // Mark first 3 episodes as watched
        try Episode.markAsWatched(showId: showId, upToSeason: 1, episode: 3, in: db)
        print("\n✅ Marked episodes 1-3 as watched")

        // Check progress after watching
        if let progress = try WatchedProgress.calculateForShow(showId: showId, in: db) {
            print("\n📊 Progress after watching:")
            print("  - Watched: \(progress.watchedItems)/\(progress.totalItems)")
            print("  - Progress: \(String(format: "%.1f", progress.progressPercentage))%")
            print("  - Remaining: \(progress.remainingItems) episodes")
            if let next = progress.nextItemToWatch {
                print(
                    "  - Next to watch: S\(next.season ?? 0)E\(next.episode ?? 0) - \(next.title ?? "Unknown")"
                )
            }
        }

        // Test marking entire season as watched
        try Episode.markSeasonAsWatched(showId: showId, season: 1, in: db)
        print("\n✅ Marked entire season 1 as watched")

        if let progress = try WatchedProgress.calculateForShow(showId: showId, in: db) {
            print("\n📊 Final Progress:")
            print("  - Watched: \(progress.watchedItems)/\(progress.totalItems)")
            print("  - Progress: \(String(format: "%.1f", progress.progressPercentage))%")
            print("  - Completed: \(progress.isCompleted)")
        }

        // Test progress for all shows
        let allProgress = try WatchedProgress.calculateForAllShows(in: db)
        print("\n📊 Progress for all shows: \(allProgress.count) shows tracked")
    }
}
