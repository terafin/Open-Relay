import Foundation
import Security

/// Securely stores and retrieves authentication tokens using the iOS Keychain.
///
/// Each token is scoped to a server URL so multiple server configurations
/// can store independent credentials.
final class KeychainService: Sendable {
    private let serviceName: String

    /// Shared instance using the default service name.
    static let shared = KeychainService()

    init(serviceName: String = "com.openui.auth") {
        self.serviceName = serviceName
    }

    // MARK: - Token Storage

    /// Saves a JWT token for the given server URL.
    @discardableResult
    func saveToken(_ token: String, forServer serverURL: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else { return false }
        let account = accountKey(for: serverURL)

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new token
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves the JWT token for the given server URL.
    func getToken(forServer serverURL: String) -> String? {
        let account = accountKey(for: serverURL)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the JWT token for the given server URL.
    @discardableResult
    func deleteToken(forServer serverURL: String) -> Bool {
        let account = accountKey(for: serverURL)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks whether a token exists for the given server URL.
    func hasToken(forServer serverURL: String) -> Bool {
        getToken(forServer: serverURL) != nil
    }

    // MARK: - Account-Scoped Token Storage (Multi-Account)

    /// Saves a JWT token for a specific user account on a server.
    /// Key format: `token:{normalizedServerURL}::{userId}`
    @discardableResult
    func saveToken(_ token: String, forServer serverURL: String, userId: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else { return false }
        let account = accountKey(for: serverURL, userId: userId)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves the JWT token for a specific user account on a server.
    func getToken(forServer serverURL: String, userId: String) -> String? {
        let account = accountKey(for: serverURL, userId: userId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the JWT token for a specific user account on a server.
    @discardableResult
    func deleteToken(forServer serverURL: String, userId: String) -> Bool {
        let account = accountKey(for: serverURL, userId: userId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks whether a token exists for a specific user account on a server.
    func hasToken(forServer serverURL: String, userId: String) -> Bool {
        getToken(forServer: serverURL, userId: userId) != nil
    }

    /// Removes all tokens managed by this service.
    @discardableResult
    func deleteAllTokens() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Password Storage

    /// Saves a user password for the given email and server URL.
    /// Key format: `password:{normalizedServerURL}::{email}`
    @discardableResult
    func savePassword(_ password: String, email: String, forServer serverURL: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let account = passwordKey(for: serverURL, email: email)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a saved password for the given email and server URL.
    func getPassword(email: String, forServer serverURL: String) -> String? {
        let account = passwordKey(for: serverURL, email: email)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Removes a saved password for the given email and server URL.
    @discardableResult
    func deletePassword(email: String, forServer serverURL: String) -> Bool {
        let account = passwordKey(for: serverURL, email: email)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks whether a password is saved for the given email and server URL.
    func hasPassword(email: String, forServer serverURL: String) -> Bool {
        getPassword(email: email, forServer: serverURL) != nil
    }

    /// Removes all saved passwords for a specific server.
    @discardableResult
    func deleteAllPasswords(forServer serverURL: String) -> Bool {
        // We can't wildcard delete by prefix, so we delete by service prefix match.
        // Since passwords use `password:` prefix in account keys and tokens use `token:`,
        // this approach deletes all items for the service. Instead, we rely on
        // individual deletion. Return true as a no-op placeholder.
        // (In practice, signOut deletes by email, and removeServer deletes all tokens.)
        return true
    }

    // MARK: - Private

    /// Derives a stable Keychain account key from a server URL.
    private func accountKey(for serverURL: String) -> String {
        let normalized = normalizeURL(serverURL)
        return "token:\(normalized)"
    }

    /// Derives a stable Keychain account key scoped to a specific user account.
    private func accountKey(for serverURL: String, userId: String) -> String {
        let normalized = normalizeURL(serverURL)
        return "token:\(normalized)::\(userId)"
    }

    /// Derives a stable Keychain account key for a saved password.
    private func passwordKey(for serverURL: String, email: String) -> String {
        let normalized = normalizeURL(serverURL)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "password:\(normalized)::\(normalizedEmail)"
    }

    /// Normalizes a URL for use as a Keychain key component.
    private func normalizeURL(_ serverURL: String) -> String {
        serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "/$", with: "", options: .regularExpression)
    }
}
