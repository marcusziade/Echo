import Foundation

final class TraktService {
    static let shared = TraktService()

    private let apiClient = TraktAPIClient.shared

    private init() {}

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
        let endpoint = "/shows/\(id)?extended=full"
        return try await apiClient.get(TraktShow.self, endpoint: endpoint)
    }

    /// Get all seasons for a show
    func getSeasons(showId: String) async throws -> [TraktSeason] {
        let endpoint = "/shows/\(showId)/seasons?extended=full"
        return try await apiClient.get([TraktSeason].self, endpoint: endpoint)
    }

    /// Get all episodes for a season
    func getEpisodes(showId: String, season: Int) async throws -> [TraktEpisode] {
        let endpoint = "/shows/\(showId)/seasons/\(season)?extended=full"
        let seasonData = try await apiClient.get(TraktSeason.self, endpoint: endpoint)
        return seasonData.episodes ?? []
    }

    // MARK: - Progress

    /// Get watched progress for a show
    func getShowProgress(showId: String) async throws -> TraktWatchedProgress {
        let endpoint = "/shows/\(showId)/progress/watched"
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
        endpoint += "?limit=\(limit)"

        return try await apiClient.get([TraktHistoryItem].self, endpoint: endpoint)
    }

    // MARK: - Watchlist

    /// Get user's watchlist
    func getWatchlist(type: WatchlistType? = nil) async throws -> [TraktSearchResult] {
        var endpoint = "/sync/watchlist"
        if let type = type {
            endpoint += "/\(type.rawValue)"
        }

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
