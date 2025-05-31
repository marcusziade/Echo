import Foundation

struct APIConfiguration {
    let baseURL: String
    let apiVersion: String
    let apiKey: String
    let timeoutInterval: TimeInterval

    var defaultHeaders: [String: String] {
        return [
            "Content-Type": "application/json",
            "trakt-api-version": apiVersion,
            "trakt-api-key": apiKey,
        ]
    }

    // Singleton configuration
    static let `default` = APIConfiguration(
        baseURL: Constants.Trakt.baseURL,
        apiVersion: Constants.Trakt.apiVersion,
        apiKey: Constants.Trakt.apiKey,
        timeoutInterval: Constants.API.timeoutInterval
    )
}

extension APIConfiguration {
    func printConfiguration() {
        print("API Configuration:")
        print("- Base URL: \(baseURL)")
        print("- API Version: \(apiVersion)")
        print("- API Key: \(apiKey.prefix(10))...")
        print("- Timeout: \(timeoutInterval)s")
        print("- Default Headers: \(defaultHeaders)")
    }
}
