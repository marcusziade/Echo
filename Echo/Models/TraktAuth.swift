// MARK: - Import CryptoKit
import CryptoKit
import Foundation

// MARK: - OAuth Token Response
struct TraktTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }

    var expirationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt + expiresIn))
    }

    var isExpired: Bool {
        expirationDate < Date()
    }
}

// MARK: - OAuth Error
struct TraktAuthError: Error, LocalizedError {
    let code: String
    let description: String?

    var errorDescription: String? {
        description ?? "Authentication failed with code: \(code)"
    }
}

// MARK: - PKCE (Proof Key for Code Exchange)
struct PKCEParameters {
    let codeVerifier: String
    let codeChallenge: String
    let codeChallengeMethod = "S256"

    init() {
        self.codeVerifier = PKCEParameters.generateCodeVerifier()
        self.codeChallenge = PKCEParameters.generateCodeChallenge(from: codeVerifier)
    }

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }

        let hash = SHA256.hash(data: data)

        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
