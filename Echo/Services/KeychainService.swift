import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    // MARK: - Save
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load
    func load(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.decodingError
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status)
        }
    }

    // MARK: - Delete
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Clear All
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.serviceName,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Error
enum KeychainError: LocalizedError {
    case encodingError
    case decodingError
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        }
    }
}

// MARK: - Token Storage Extension
extension KeychainService {
    func saveTokenResponse(_ response: TraktTokenResponse) throws {
        try save(response.accessToken, forKey: Constants.Keychain.accessTokenKey)
        try save(response.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
        try save(
            String(response.expirationDate.timeIntervalSince1970),
            forKey: Constants.Keychain.expiresAtKey)
    }

    func loadTokenResponse() throws -> (accessToken: String, refreshToken: String, expiresAt: Date)?
    {
        guard let accessToken = try load(key: Constants.Keychain.accessTokenKey),
            let refreshToken = try load(key: Constants.Keychain.refreshTokenKey),
            let expiresAtString = try load(key: Constants.Keychain.expiresAtKey),
            let expiresAtInterval = TimeInterval(expiresAtString)
        else {
            return nil
        }

        let expiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        return (accessToken, refreshToken, expiresAt)
    }

    func clearTokens() throws {
        try delete(key: Constants.Keychain.accessTokenKey)
        try delete(key: Constants.Keychain.refreshTokenKey)
        try delete(key: Constants.Keychain.expiresAtKey)
    }
}
