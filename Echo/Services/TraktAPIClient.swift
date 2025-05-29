import Foundation

final class TraktAPIClient {
    static let shared = TraktAPIClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.API.timeoutInterval
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "trakt-api-version": Constants.Trakt.apiVersion,
            "trakt-api-key": Constants.Trakt.apiKey,
        ]

        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Request Building
    private func buildRequest(
        for endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> URLRequest {
        // Ensure we have a valid token
        try await TraktAuthManager.shared.refreshTokenIfNeeded()

        guard let accessToken = TraktAuthManager.shared.currentAccessToken else {
            throw TraktAPIError.notAuthenticated
        }

        guard let url = URL(string: "\(Constants.Trakt.baseURL)\(endpoint)") else {
            throw TraktAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return request
    }

    // MARK: - Generic Request Method
    func request<T: Decodable>(
        _ type: T.Type,
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        var bodyData: Data?
        if let body = body {
            bodyData = try JSONEncoder().encode(body)
        }

        let request = try await buildRequest(
            for: endpoint,
            method: method,
            body: bodyData
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktAPIError.invalidResponse
        }

        // Handle rate limiting
        if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
            let limit = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit")
        {
            print("Rate Limit: \(remaining)/\(limit)")
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        case 401:
            throw TraktAPIError.unauthorized

        case 429:
            throw TraktAPIError.rateLimitExceeded

        default:
            throw TraktAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Convenience Methods
    func get<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        try await request(type, endpoint: endpoint)
    }

    func post<T: Decodable, B: Encodable>(_ type: T.Type, endpoint: String, body: B) async throws
        -> T
    {
        try await request(type, endpoint: endpoint, method: "POST", body: body)
    }

    func post(endpoint: String, body: Encodable) async throws {
        _ = try await request(EmptyResponse.self, endpoint: endpoint, method: "POST", body: body)
    }

    func delete(endpoint: String) async throws {
        _ = try await request(EmptyResponse.self, endpoint: endpoint, method: "DELETE")
    }
}

// MARK: - API Errors
enum TraktAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        }
    }
}

// MARK: - Empty Response
private struct EmptyResponse: Decodable {}
