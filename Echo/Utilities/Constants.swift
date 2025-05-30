import Foundation

enum Constants {
    enum Trakt {
        static let clientID = "e59933ae76b14a8d239ab415f7b14ec3f4229a875ebd19c79add76290e8fb6a7"

        static let redirectURI = "echo-trakt://auth"

        static let workerURL = "https://echo-trakt-worker.guitaripod.workers.dev"

        static let baseURL = "https://api.trakt.tv"
        static let authURL = "https://trakt.tv"

        static let apiVersion = "2"
        static let apiKey = clientID
    }

    enum Keychain {
        static let serviceName = "com.marcusziade.echo"
        static let accessTokenKey = "trakt_access_token"
        static let refreshTokenKey = "trakt_refresh_token"
        static let expiresAtKey = "trakt_expires_at"
    }

    enum API {
        static let timeoutInterval: TimeInterval = 30
        static let maxRetries = 3
    }
}

