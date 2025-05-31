import Foundation

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let configuration: APIConfiguration

    private init(configuration: APIConfiguration = .default) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        sessionConfig.httpAdditionalHeaders = configuration.defaultHeaders

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Generic Request Method
    func request<T: Decodable>(
        _ type: T.Type,
        endpoint: APIEndpoint
    ) async throws -> T {
        guard let url = endpoint.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add endpoint-specific headers
        if let headers = endpoint.headers {
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add body for POST/PUT/PATCH
        if let body = endpoint.body {
            request.httpBody = body
        } else if let parameters = endpoint.parameters,
            endpoint.method != .get
        {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)

            case 401:
                throw APIError.unauthorized

            case 429:
                throw APIError.rateLimitExceeded

            default:
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

        } catch _ as DecodingError {
            throw APIError.decodingError
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Test Method
    func testRequest() async {
        print("Testing API Client...")

        // Create a test endpoint for httpbin.org
        struct TestEndpoint: APIEndpoint {
            var baseURL: String = "https://httpbin.org"
            var path: String = "/get"
            var method: HTTPMethod = .get
        }

        struct TestResponse: Decodable {
            let url: String
            let headers: [String: String]
        }

        do {
            let response = try await request(TestResponse.self, endpoint: TestEndpoint())
            print("✅ Test request successful!")
            print("URL: \(response.url)")
            print("Headers count: \(response.headers.count)")
        } catch {
            print("❌ Test request failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case httpError(statusCode: Int)
    case unauthorized
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
