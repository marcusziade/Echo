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

            outputTextView.topAnchor.constraint(
                equalTo: testDatabaseButton.bottomAnchor, constant: 20),
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
    }

    // MARK: - Actions
    @objc private func testSearch() {
        appendOutput("🔍 Testing Search API...\n")

        Task {
            do {
                // Test search for Breaking Bad
                let results = try await TraktService.shared.searchShows(
                    query: "Breaking Bad", limit: 3)

                await MainActor.run {
                    appendOutput("✅ Search successful! Found \(results.count) shows\n\n")

                    for (index, show) in results.enumerated() {
                        appendOutput("Show \(index + 1):\n")
                        appendOutput("  Title: \(show.title)\n")
                        appendOutput("  Year: \(show.year ?? 0)\n")
                        appendOutput("  Trakt ID: \(show.ids.trakt)\n")
                        appendOutput("  Network: \(show.network ?? "N/A")\n")
                        appendOutput("  Status: \(show.status ?? "N/A")\n")
                        appendOutput("  Overview: \(show.overview?.prefix(100) ?? "N/A")...\n\n")
                    }

                    // Save first result to database
                    if let firstShow = results.first {
                        saveShowToDatabase(firstShow)
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

    private func saveShowToDatabase(_ traktShow: TraktShow) {
        appendOutput("\n💾 Saving show to database...\n")

        do {
            try DatabaseManager.shared.writer?.write { db in
                var show = traktShow.toShow()

                // Check if show already exists
                if let existingShow = try Show.findByTraktId(traktShow.ids.trakt, in: db) {
                    appendOutput("ℹ️ Show already exists with ID: \(existingShow.id ?? 0)\n")
                } else {
                    try show.insert(db)
                    appendOutput("✅ Show saved with ID: \(show.id ?? 0)\n")
                }
            }
        } catch {
            appendOutput("❌ Database save error: \(error.localizedDescription)\n")
        }
    }
}
