import Combine
import GRDB
import UIKit

/// Test view controller for verifying Trakt API integration
final class TraktTestViewController: UIViewController {

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var cancellables = Set<AnyCancellable>()

    private let testSearchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Search API", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let testTokenButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Token Info", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let testDatabaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Database", for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let testSyncButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Sync Manager", for: .normal)
        button.backgroundColor = .systemPurple
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let testObservationsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Database Observations", for: .normal)
        button.backgroundColor = .systemIndigo
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let testBatchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Batch Operations", for: .normal)
        button.backgroundColor = .systemTeal
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let outputTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
    }

    // MARK: - Setup
    private func setupUI() {
        title = "API Tests"
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(testSearchButton)
        contentView.addSubview(testTokenButton)
        contentView.addSubview(testDatabaseButton)
        contentView.addSubview(testSyncButton)
        contentView.addSubview(testObservationsButton)
        contentView.addSubview(testBatchButton)
        contentView.addSubview(outputTextView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearOutput)
        )
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            testSearchButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            testSearchButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testSearchButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testSearchButton.heightAnchor.constraint(equalToConstant: 44),

            testTokenButton.topAnchor.constraint(
                equalTo: testSearchButton.bottomAnchor, constant: 12),
            testTokenButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testTokenButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testTokenButton.heightAnchor.constraint(equalToConstant: 44),

            testDatabaseButton.topAnchor.constraint(
                equalTo: testTokenButton.bottomAnchor, constant: 12),
            testDatabaseButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testDatabaseButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testDatabaseButton.heightAnchor.constraint(equalToConstant: 44),

            testSyncButton.topAnchor.constraint(
                equalTo: testDatabaseButton.bottomAnchor, constant: 12),
            testSyncButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testSyncButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testSyncButton.heightAnchor.constraint(equalToConstant: 44),

            testObservationsButton.topAnchor.constraint(
                equalTo: testSyncButton.bottomAnchor, constant: 12),
            testObservationsButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testObservationsButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testObservationsButton.heightAnchor.constraint(equalToConstant: 44),

            testBatchButton.topAnchor.constraint(
                equalTo: testObservationsButton.bottomAnchor, constant: 12),
            testBatchButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            testBatchButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            testBatchButton.heightAnchor.constraint(equalToConstant: 44),

            outputTextView.topAnchor.constraint(
                equalTo: testBatchButton.bottomAnchor, constant: 20),
            outputTextView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            outputTextView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            outputTextView.heightAnchor.constraint(equalToConstant: 400),
            outputTextView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    private func setupActions() {
        testSearchButton.addTarget(self, action: #selector(testSearch), for: .touchUpInside)
        testTokenButton.addTarget(self, action: #selector(testToken), for: .touchUpInside)
        testDatabaseButton.addTarget(self, action: #selector(testDatabase), for: .touchUpInside)
        testSyncButton.addTarget(self, action: #selector(testSync), for: .touchUpInside)
        testObservationsButton.addTarget(
            self, action: #selector(testObservations), for: .touchUpInside)
        testBatchButton.addTarget(self, action: #selector(testBatchOperations), for: .touchUpInside)
    }

    // MARK: - Original Test Actions
    @objc private func testSearch() {
        appendOutput("🔍 Testing Search with Sync Manager...\n")

        Task {
            do {
                // Search and save shows using SyncManager
                let shows = try await SyncManager.shared.searchAndSaveShows(
                    query: "Breaking Bad",
                    limit: 3
                )

                await MainActor.run {
                    appendOutput("✅ Search and save successful! Found \(shows.count) shows\n\n")

                    for (index, show) in shows.enumerated() {
                        appendOutput("Show \(index + 1):\n")
                        appendOutput("  Title: \(show.title)\n")
                        appendOutput("  Year: \(show.year ?? 0)\n")
                        appendOutput("  Database ID: \(show.id ?? 0)\n")
                        appendOutput("  Trakt ID: \(show.traktId)\n")
                        appendOutput("  Network: \(show.network ?? "N/A")\n")
                        appendOutput("  Status: \(show.status ?? "N/A")\n\n")
                    }
                }

            } catch {
                await MainActor.run {
                    appendOutput("❌ Search failed: \(error.localizedDescription)\n")
                }
            }
        }
    }

    @objc private func testToken() {
        appendOutput("🔐 Testing Token Info...\n")

        do {
            if let tokenData = try KeychainService.shared.loadTokenResponse() {
                appendOutput("✅ Token found!\n")
                appendOutput("  Access Token: \(tokenData.accessToken.prefix(20))...\n")
                appendOutput("  Refresh Token: \(tokenData.refreshToken.prefix(20))...\n")
                appendOutput("  Expires At: \(tokenData.expiresAt)\n")

                let timeRemaining = tokenData.expiresAt.timeIntervalSinceNow
                if timeRemaining > 0 {
                    let hours = Int(timeRemaining) / 3600
                    let minutes = (Int(timeRemaining) % 3600) / 60
                    appendOutput("  ⏱️ Time remaining: \(hours)h \(minutes)m\n")
                } else {
                    appendOutput("  ⚠️ Token is expired!\n")
                }

                appendOutput("\n🔄 Testing refresh...\n")
                Task {
                    do {
                        try await TraktAuthManager.shared.refreshTokenIfNeeded()
                        await MainActor.run {
                            appendOutput("✅ Token refresh check completed\n")
                        }
                    } catch {
                        await MainActor.run {
                            appendOutput("❌ Token refresh failed: \(error.localizedDescription)\n")
                        }
                    }
                }

            } else {
                appendOutput("❌ No token found in keychain\n")
            }
        } catch {
            appendOutput("❌ Error reading token: \(error.localizedDescription)\n")
        }
    }

    @objc private func testDatabase() {
        appendOutput("💾 Testing Database...\n")

        do {
            guard let db = DatabaseManager.shared.reader else {
                appendOutput("❌ Database not initialized\n")
                return
            }

            try db.read { db in
                // Count shows
                let showCount = try Show.fetchCount(db)
                appendOutput("📺 Shows in database: \(showCount)\n")

                // Count episodes
                let episodeCount = try Episode.fetchCount(db)
                appendOutput("📼 Episodes in database: \(episodeCount)\n")

                // List all shows
                let shows = try Show.fetchAll(db)
                if !shows.isEmpty {
                    appendOutput("\nShows:\n")
                    for show in shows {
                        appendOutput(
                            "  - \(show.title) (ID: \(show.id ?? 0), Trakt: \(show.traktId))\n")
                    }
                }

                // Check for unwatched episodes
                let unwatchedCount = try Episode.unwatched().fetchCount(db)
                appendOutput("\n👀 Unwatched episodes: \(unwatchedCount)\n")
            }
        } catch {
            appendOutput("❌ Database error: \(error.localizedDescription)\n")
        }
    }

    @objc private func testSync() {
        appendOutput("🔄 Testing Complete Show Sync...\n")

        Task {
            do {
                // First, get a show from the database
                guard let db = DatabaseManager.shared.reader else {
                    await MainActor.run {
                        appendOutput("❌ Database not initialized\n")
                    }
                    return
                }

                let shows = try await db.read { db in
                    try Show.fetchAll(db)
                }

                guard let firstShow = shows.first else {
                    await MainActor.run {
                        appendOutput("❌ No shows in database. Run search first!\n")
                    }
                    return
                }

                await MainActor.run {
                    appendOutput("📺 Syncing: \(firstShow.title)\n")
                    appendOutput("   Show ID: \(firstShow.id ?? 0)\n")
                    appendOutput("   Trakt ID: \(firstShow.traktId)\n")
                    appendOutput("   This may take a moment...\n\n")
                }

                // Sync the complete show
                let syncedShow = try await SyncManager.shared.syncCompleteShow(
                    showId: firstShow.id!)

                // Get sync stats
                let stats = try await SyncManager.shared.getSyncStats(for: syncedShow.id!)

                await MainActor.run {
                    appendOutput("✅ Sync completed!\n")
                    appendOutput("\n📊 Sync Statistics:\n")
                    appendOutput("  Total Episodes: \(stats.totalEpisodes)\n")
                    appendOutput("  Aired Episodes: \(stats.airedEpisodes)\n")
                    appendOutput("  Watched Episodes: \(stats.watchedEpisodes)\n")
                    appendOutput("  Unwatched (Aired): \(stats.unwatchedAired)\n")
                    appendOutput(
                        "  Watched %: \(String(format: "%.1f", stats.watchedPercentage))%\n")
                }

                // Now sync watched progress
                await MainActor.run {
                    appendOutput("\n🔄 Syncing watched progress...\n")
                }

                try await SyncManager.shared.syncWatchedProgress(showId: syncedShow.id!)

                // Get updated stats
                let updatedStats = try await SyncManager.shared.getSyncStats(for: syncedShow.id!)

                await MainActor.run {
                    appendOutput("✅ Watched progress synced!\n")
                    appendOutput("\n📊 Updated Statistics:\n")
                    appendOutput("  Watched Episodes: \(updatedStats.watchedEpisodes)\n")
                    appendOutput(
                        "  Watched %: \(String(format: "%.1f", updatedStats.watchedPercentage))%\n")
                }

            } catch {
                await MainActor.run {
                    appendOutput("❌ Sync failed: \(error.localizedDescription)\n")
                }
            }
        }
    }

    // MARK: - New Test Actions

    @objc private func testObservations() {
        appendOutput("👀 Testing Database Observations...\n")

        // Cancel existing subscriptions
        cancellables.removeAll()

        // Check if database has data
        do {
            guard let db = DatabaseManager.shared.reader else {
                appendOutput("❌ Database not initialized\n")
                return
            }

            let showCount = try db.read { db in
                try Show.fetchCount(db)
            }

            if showCount == 0 {
                appendOutput(
                    "\n⚠️ Database is empty! Run 'Test Search API' first to add some shows.\n")
            }
        } catch {
            appendOutput("❌ Failed to check database: \(error)\n")
        }

        // Test 1: Observe shows
        appendOutput("\n1️⃣ Setting up show observation...\n")
        DatabaseObservationService.shared.observeShows()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.appendOutput("❌ Show observation failed: \(error)\n")
                    }
                },
                receiveValue: { shows in
                    self.appendOutput("📺 Shows updated: \(shows.count) shows\n")
                    for show in shows.prefix(3) {
                        self.appendOutput("  - \(show.title)\n")
                    }
                }
            )
            .store(in: &cancellables)

        // Test 2: Observe statistics
        appendOutput("\n2️⃣ Setting up statistics observation...\n")
        DatabaseObservationService.shared.observeStatistics()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { stats in
                    self.appendOutput("📊 Database Statistics:\n")
                    self.appendOutput("  Shows: \(stats.totalShows)\n")
                    self.appendOutput(
                        "  Episodes: \(stats.totalEpisodes) (Watched: \(stats.watchedEpisodes))\n")
                    self.appendOutput(
                        "  Movies: \(stats.totalMovies) (Watched: \(stats.watchedMovies))\n")
                    self.appendOutput(
                        "  Episode Progress: \(String(format: "%.1f", stats.episodeWatchedPercentage))%\n"
                    )
                }
            )
            .store(in: &cancellables)

        // Test 3: Observe Up Next
        appendOutput("\n3️⃣ Setting up Up Next observation...\n")
        DatabaseObservationService.shared.observeUpNextEpisodes()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { upNextItems in
                    self.appendOutput("🎬 Up Next: \(upNextItems.count) items\n")
                    for item in upNextItems.prefix(5) {
                        self.appendOutput(
                            "  - \(item.show.title) S\(item.nextEpisode.season)E\(item.nextEpisode.number)"
                        )
                        if let title = item.nextEpisode.title {
                            self.appendOutput(": \(title)")
                        }
                        self.appendOutput("\n")
                    }
                }
            )
            .store(in: &cancellables)

        appendOutput("\n✅ Observations set up! Make database changes to see updates.\n")
        appendOutput("💡 Try running other tests to see live updates!\n")
    }

    @objc private func testBatchOperations() {
        appendOutput("🔄 Testing Batch Operations...\n")

        Task {
            do {
                // Test 1: Import search results
                appendOutput("\n1️⃣ Testing batch import from search...\n")

                let searchResults = try await TraktService.shared.search(
                    query: "Game of Thrones",
                    limit: 5
                )

                let importResult = try await BatchSyncService.shared.importSearchResults(
                    searchResults)

                await MainActor.run {
                    appendOutput("✅ Batch Import Results:\n")
                    appendOutput("  New Shows: \(importResult.importedShows)\n")
                    appendOutput("  Updated Shows: \(importResult.updatedShows)\n")
                    appendOutput("  New Movies: \(importResult.importedMovies)\n")
                    appendOutput("  Updated Movies: \(importResult.updatedMovies)\n")
                    appendOutput("  Total Processed: \(importResult.totalProcessed)\n")
                }

                // Test 2: Batch sync multiple shows
                appendOutput("\n2️⃣ Testing batch sync of multiple shows...\n")

                guard let db = DatabaseManager.shared.reader else {
                    await MainActor.run {
                        appendOutput("❌ Database not initialized\n")
                    }
                    return
                }

                let showIds = try await db.read { db in
                    try Show.fetchAll(db).prefix(2).compactMap { $0.id }
                }

                if showIds.isEmpty {
                    await MainActor.run {
                        appendOutput("⚠️ No shows to sync. Skipping batch sync test.\n")
                        appendOutput("💡 Run 'Test Search API' first to add shows.\n")
                    }
                } else {
                    await MainActor.run {
                        appendOutput("🔄 Syncing \(showIds.count) shows...\n")
                    }

                    let batchResult = try await BatchSyncService.shared.syncMultipleShows(
                        showIds: showIds
                    ) { progress in
                        Task { @MainActor in
                            self.appendOutput(
                                "  Progress: \(progress.current)/\(progress.total) - \(progress.phase.description)\n"
                            )
                        }
                    }

                    await MainActor.run {
                        appendOutput("\n✅ Batch Sync Results:\n")
                        appendOutput(
                            "  Success: \(batchResult.successCount)/\(batchResult.totalShows)\n")
                        appendOutput("  Failed: \(batchResult.failureCount)\n")
                        appendOutput("  Episodes Synced: \(batchResult.totalEpisodesSynced)\n")
                        appendOutput(
                            "  Success Rate: \(String(format: "%.1f", batchResult.successRate))%\n")

                        if !batchResult.failedShows.isEmpty {
                            appendOutput("\n❌ Failed Shows:\n")
                            for (showId, error) in batchResult.failedShows {
                                appendOutput("  Show ID \(showId): \(error.localizedDescription)\n")
                            }
                        }
                    }
                }

                // Test 3: Transaction test
                appendOutput("\n3️⃣ Testing transaction support...\n")

                let transactionResult = try await BatchSyncService.shared.performInTransaction {
                    db in
                    // Count episodes before
                    let countBefore = try Episode.fetchCount(db)

                    // Create a test episode
                    let shows = try Show.fetchAll(db)
                    if let firstShow = shows.first, let showId = firstShow.id {
                        var testEpisode = Episode(
                            showId: showId,
                            traktId: 999999,
                            season: 99,
                            number: 99,
                            title: "Test Episode (Transaction Test)"
                        )
                        try testEpisode.insert(db)

                        // Count after insert
                        let countAfter = try Episode.fetchCount(db)

                        // Delete the test episode to clean up
                        _ = try Episode.filter(Column("trakt_id") == 999999).deleteAll(db)

                        return (before: countBefore, after: countAfter, created: true)
                    } else {
                        return (before: countBefore, after: countBefore, created: false)
                    }
                }

                await MainActor.run {
                    appendOutput("✅ Transaction completed:\n")
                    appendOutput("  Episodes before: \(transactionResult.before)\n")
                    appendOutput("  Episodes after insert: \(transactionResult.after)\n")
                    if transactionResult.created {
                        appendOutput("  Successfully created and cleaned up test episode!\n")
                    } else {
                        appendOutput("  No shows available for testing, but transaction worked!\n")
                    }
                }

            } catch {
                await MainActor.run {
                    appendOutput("❌ Batch operation failed: \(error.localizedDescription)\n")
                }
            }
        }
    }

    @objc private func clearOutput() {
        outputTextView.text = ""
        cancellables.removeAll()
    }

    // MARK: - Helpers
    private func appendOutput(_ text: String) {
        outputTextView.text += text

        // Auto-scroll to bottom
        if outputTextView.text.count > 0 {
            let bottom = NSMakeRange(outputTextView.text.count - 1, 1)
            outputTextView.scrollRangeToVisible(bottom)
        }
    }
}
