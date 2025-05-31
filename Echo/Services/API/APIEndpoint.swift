import Foundation

protocol APIEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var parameters: [String: Any]? { get }
    var body: Data? { get }
}

extension APIEndpoint {
    var baseURL: String {
        return Constants.Trakt.baseURL
    }

    var headers: [String: String]? {
        return nil
    }

    var parameters: [String: Any]? {
        return nil
    }

    var body: Data? {
        return nil
    }

    var url: URL? {
        var components = URLComponents(string: baseURL + path)

        if let parameters = parameters, method == .get {
            components?.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }

        return components?.url
    }
}
