import Foundation

final class TraktService {
    static let shared = TraktService()

    private let apiClient = TraktAPIClient.shared

    private init() {}

    /// Get all shows the user has watched
    func getAllWatchedShows() async throws -> [TraktShow] {
        struct WatchedShow: Decodable {
            let plays: Int
            let lastWatchedAt: String?
            let lastUpdatedAt: String?
            let resetAt: String?
            let show: TraktShow

            enum CodingKeys: String, CodingKey {
                case plays
                case lastWatchedAt = "last_watched_at"
                case lastUpdatedAt = "last_updated_at"
                case resetAt = "reset_at"
                case show
            }
        }

        let endpoint = "/sync/watched/shows?extended=full,images"
        let watchedShows = try await apiClient.get([WatchedShow].self, endpoint: endpoint)

        return watchedShows.map { $0.show }
    }

    // MARK: - Search

    /// Search for shows and movies
    /// - Parameters:
    ///   - query: Search query
    ///   - type: Type of content to search (show, movie, or nil for all)
    ///   - limit: Maximum number of results (default 10)
    func search(query: String, type: SearchType? = nil, limit: Int = 10) async throws
        -> [TraktSearchResult]
    {
        var endpoint = "/search"
        if let type = type {
            endpoint += "/\(type.rawValue)"
        }

        endpoint +=
            "?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        endpoint += "&limit=\(limit)"
        endpoint += "&extended=full,images"

        return try await apiClient.get([TraktSearchResult].self, endpoint: endpoint)
    }

    /// Search specifically for shows
    func searchShows(query: String, limit: Int = 10) async throws -> [TraktShow] {
        let results = try await search(query: query, type: .show, limit: limit)
        return results.compactMap { $0.show }
    }

    // MARK: - Show Details

    /// Get detailed information about a show
    func getShow(id: String) async throws -> TraktShow {
        let endpoint = "/shows/\(id)?extended=full,images"
        return try await apiClient.get(TraktShow.self, endpoint: endpoint)
    }

    /// Get all seasons for a show
    func getSeasons(showId: String) async throws -> [TraktSeason] {
        let endpoint = "/shows/\(showId)/seasons?extended=full,images"
        return try await apiClient.get([TraktSeason].self, endpoint: endpoint)
    }

    /// Get all episodes for a season
    func getEpisodes(showId: String, season: Int) async throws -> [TraktEpisode] {
        let endpoint = "/shows/\(showId)/seasons/\(season)?extended=full,images"

        do {
            // The API returns an array of episodes directly, not a season object
            return try await apiClient.get([TraktEpisode].self, endpoint: endpoint)
        } catch {
            print("❌ Failed to get episodes for show \(showId) season \(season)")
            print("   Error: \(error)")
            throw error
        }
    }

    // MARK: - Progress

    /// Get watched progress for a show
    func getShowProgress(showId: String) async throws -> TraktWatchedProgress {
        let endpoint = "/shows/\(showId)/progress/watched?extended=full,images"
        return try await apiClient.get(TraktWatchedProgress.self, endpoint: endpoint)
    }

    // MARK: - History

    /// Mark episodes as watched
    func markAsWatched(episodes: [TraktSyncEpisode]) async throws {
        let body = TraktSyncItems(shows: nil, movies: nil, episodes: episodes)
        try await apiClient.post(endpoint: "/sync/history", body: body)
    }

    /// Remove episodes from watched history
    func removeFromHistory(episodes: [TraktSyncEpisode]) async throws {
        let body = TraktSyncItems(shows: nil, movies: nil, episodes: episodes)
        try await apiClient.post(endpoint: "/sync/history/remove", body: body)
    }

    /// Get watched history
    func getHistory(type: HistoryType? = nil, limit: Int = 20) async throws -> [TraktHistoryItem] {
        var endpoint = "/sync/history"
        if let type = type {
            endpoint += "/\(type.rawValue)"
        }
        endpoint += "?limit=\(limit)&extended=full,images"

        return try await apiClient.get([TraktHistoryItem].self, endpoint: endpoint)
    }

    // MARK: - Watchlist

    /// Get user's watchlist
    func getWatchlist(type: WatchlistType? = nil) async throws -> [TraktSearchResult] {
        var endpoint = "/sync/watchlist"
        if let type = type {
            endpoint += "/\(type.rawValue)"
        }
        endpoint += "?extended=full,images"

        return try await apiClient.get([TraktSearchResult].self, endpoint: endpoint)
    }

    /// Add items to watchlist
    func addToWatchlist(shows: [TraktShow]? = nil, movies: [TraktMovie]? = nil) async throws {
        let showItems = shows?.map { TraktSyncShow(ids: $0.ids, seasons: nil, watchedAt: nil) }
        let movieItems = movies?.map { TraktSyncMovie(ids: $0.ids, watchedAt: nil) }
        let body = TraktSyncItems(shows: showItems, movies: movieItems, episodes: nil)

        try await apiClient.post(endpoint: "/sync/watchlist", body: body)
    }

    /// Remove items from watchlist
    func removeFromWatchlist(shows: [TraktShow]? = nil, movies: [TraktMovie]? = nil) async throws {
        let showItems = shows?.map { TraktSyncShow(ids: $0.ids, seasons: nil, watchedAt: nil) }
        let movieItems = movies?.map { TraktSyncMovie(ids: $0.ids, watchedAt: nil) }
        let body = TraktSyncItems(shows: showItems, movies: movieItems, episodes: nil)

        try await apiClient.post(endpoint: "/sync/watchlist/remove", body: body)
    }
}

// MARK: - Supporting Types
extension TraktService {
    enum SearchType: String {
        case movie
        case show
        case episode
        case person
        case list
    }

    enum HistoryType: String {
        case movies
        case shows
        case episodes
    }

    enum WatchlistType: String {
        case movies
        case shows
        case episodes
    }
}

// MARK: - Test Helper
extension TraktService {
    func testSearch() async {
        print("\n🔍 Testing Trakt Search...")

        do {
            // Test searching for Breaking Bad
            let results = try await searchShows(query: "Breaking Bad", limit: 5)

            print("✅ Search successful! Found \(results.count) shows")

            for show in results {
                print("\n📺 Show: \(show.title)")
                print("   Year: \(show.year ?? 0)")
                print("   Trakt ID: \(show.ids.trakt)")
                print("   Overview: \(show.overview?.prefix(100) ?? "N/A")...")
            }

            // Test getting show details
            if let firstShow = results.first {
                print("\n📊 Getting details for '\(firstShow.title)'...")
                let details = try await getShow(id: String(firstShow.ids.trakt))
                print("✅ Network: \(details.network ?? "N/A")")
                print("✅ Status: \(details.status ?? "N/A")")
                print("✅ Runtime: \(details.runtime ?? 0) minutes")
                print("✅ Aired Episodes: \(details.airedEpisodes ?? 0)")
            }

        } catch {
            print("❌ Search test failed: \(error)")
        }
    }
}
