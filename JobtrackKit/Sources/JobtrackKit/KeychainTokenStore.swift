import Foundation
import Security

/// Tokens in the Keychain under a shared access group, so the share extension
/// uses the app's session. `accessGroup` is nil in unsigned builds/tests.
public struct KeychainTokenStore: TokenStore {
    private let service = "com.scshafe.jobtrack.tokens"
    private let accessGroup: String?

    public init(accessGroup: String? = nil) { self.accessGroup = accessGroup }

    private var query: [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    public func load() throws -> TokenSet? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw AuthError.badResponse }
        return try JSONDecoder().decode(TokenSet.self, from: data)
    }

    public func save(_ tokens: TokenSet) throws {
        try clear()
        var q = query
        q[kSecValueData as String] = try JSONEncoder().encode(tokens)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw AuthError.badResponse }
    }

    public func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AuthError.badResponse }
    }
}
