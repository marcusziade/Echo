import UIKit

/// Test view controller for verifying Trakt API integration
final class TraktTestViewController: UIViewController {

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()

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

            outputTextView.topAnchor.constraint(
                equalTo: testSyncButton.bottomAnchor, constant: 20),
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
    }

    // MARK: - Actions
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
                let syncedShow = try await SyncManager.shared.syncCompleteShow(showId: firstShow.id!)

                // Get sync stats
                let stats = try await SyncManager.shared.getSyncStats(for: syncedShow.id!)

                await MainActor.run {
                    appendOutput("✅ Sync completed!\n")
                    appendOutput("\n📊 Sync Statistics:\n")
                    appendOutput("  Total Episodes: \(stats.totalEpisodes)\n")
                    appendOutput("  Aired Episodes: \(stats.airedEpisodes)\n")
                    appendOutput("  Watched Episodes: \(stats.watchedEpisodes)\n")
                    appendOutput("  Unwatched (Aired): \(stats.unwatchedAired)\n")
                    appendOutput("  Watched %: \(String(format: "%.1f", stats.watchedPercentage))%\n")
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
                    appendOutput("  Watched %: \(String(format: "%.1f", updatedStats.watchedPercentage))%\n")
                }

            } catch DecodingError.keyNotFound(let key, let context) {
                await MainActor.run {
                    appendOutput("❌ Decoding error - Missing key: \(key)\n")
                    appendOutput("   Context: \(context.debugDescription)\n")
                }
            } catch DecodingError.typeMismatch(let type, let context) {
                await MainActor.run {
                    appendOutput("❌ Decoding error - Type mismatch: \(type)\n")
                    appendOutput("   Context: \(context.debugDescription)\n")
                }
            } catch DecodingError.valueNotFound(let type, let context) {
                await MainActor.run {
                    appendOutput("❌ Decoding error - Value not found: \(type)\n")
                    appendOutput("   Context: \(context.debugDescription)\n")
                }
            } catch DecodingError.dataCorrupted(let context) {
                await MainActor.run {
                    appendOutput("❌ Decoding error - Data corrupted\n")
                    appendOutput("   Context: \(context.debugDescription)\n")
                }
            } catch {
                await MainActor.run {
                    appendOutput("❌ Sync failed: \(error.localizedDescription)\n")
                    appendOutput("   Error type: \(type(of: error))\n")
                    appendOutput("   Error details: \(error)\n")
                }
            }
        }
    }

    @objc private func clearOutput() {
        outputTextView.text = ""
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
