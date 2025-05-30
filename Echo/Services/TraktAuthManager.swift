import AuthenticationServices
import UIKit

final class TraktAuthManager: NSObject {
    static let shared = TraktAuthManager()

    private var authSession: ASWebAuthenticationSession?
    private var currentPKCE: PKCEParameters?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods
    var isAuthenticated: Bool {
        guard let tokenData = try? KeychainService.shared.loadTokenResponse() else {
            return false
        }
        return tokenData.expiresAt > Date()
    }

    var currentAccessToken: String? {
        try? KeychainService.shared.load(key: Constants.Keychain.accessTokenKey)
    }

    func authenticate(from viewController: UIViewController) async throws {
        let pkce = PKCEParameters()
        currentPKCE = pkce

        var components = URLComponents(string: "\(Constants.Trakt.authURL)/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Constants.Trakt.clientID),
            URLQueryItem(name: "redirect_uri", value: Constants.Trakt.redirectURI),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod),
        ]

        guard let authURL = components.url else {
            throw TraktAuthError(
                code: "invalid_url", description: "Failed to build authorization URL")
        }

        print("Auth URL: \(authURL)")

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "echo-trakt"
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(
                        throwing: TraktAuthError(
                            code: "internal_error", description: "Auth manager deallocated"))
                    return
                }

                if let error = error {
                    if (error as NSError).code
                        == ASWebAuthenticationSessionError.canceledLogin.rawValue
                    {
                        continuation.resume(
                            throwing: TraktAuthError(
                                code: "user_cancelled", description: "User cancelled authentication"
                            ))
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                    let code = self.extractCode(from: callbackURL)
                else {
                    continuation.resume(
                        throwing: TraktAuthError(
                            code: "invalid_callback",
                            description: "Failed to extract authorization code"))
                    return
                }

                Task {
                    do {
                        try await self.exchangeCodeForToken(code: code)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session
            session.start()
        }
    }

    func refreshTokenIfNeeded() async throws {
        guard let tokenData = try? KeychainService.shared.loadTokenResponse() else {
            throw TraktAuthError(code: "no_token", description: "No stored token found")
        }

        // Check if token needs refresh (refresh if expires in less than 5 minutes)
        let shouldRefresh = tokenData.expiresAt.timeIntervalSinceNow < 300

        if shouldRefresh {
            try await refreshToken(tokenData.refreshToken)
        }
    }

    func logout() throws {
        try KeychainService.shared.clearTokens()
    }

    // MARK: - Private Methods
    private func extractCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCodeForToken(code: String) async throws {
        guard let pkce = currentPKCE else {
            throw TraktAuthError(code: "missing_pkce", description: "PKCE parameters not found")
        }

        let url = URL(string: "\(Constants.Trakt.workerURL)/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "code": code,
            "redirect_uri": Constants.Trakt.redirectURI,
            "code_verifier": pkce.codeVerifier,
        ]

        print("Token exchange request to Worker")

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktAuthError(code: "invalid_response", description: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw TraktAuthError(code: "token_exchange_failed", description: errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(TraktTokenResponse.self, from: data)
        try KeychainService.shared.saveTokenResponse(tokenResponse)

        currentPKCE = nil
    }

    private func refreshToken(_ refreshToken: String) async throws {
        let url = URL(string: "\(Constants.Trakt.workerURL)/oauth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "redirect_uri": Constants.Trakt.redirectURI,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktAuthError(code: "invalid_response", description: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            // If refresh fails, clear tokens and require re-authentication
            try KeychainService.shared.clearTokens()
            let errorMessage = String(data: data, encoding: .utf8) ?? "Token refresh failed"
            throw TraktAuthError(code: "refresh_failed", description: errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(TraktTokenResponse.self, from: data)
        try KeychainService.shared.saveTokenResponse(tokenResponse)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension TraktAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Ensure UI API calls happen on the main thread
        if Thread.isMainThread {
            return getPresentationAnchor()
        } else {
            return DispatchQueue.main.sync {
                return getPresentationAnchor()
            }
        }
    }

    private func getPresentationAnchor() -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else {
            fatalError("No window found")
        }
        return window
    }
}
