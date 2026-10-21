import Foundation

/// Where tokens live between launches. The app uses the Keychain (shared with
/// the share extension through the access group); tests use memory.
public protocol TokenStore: Sendable {
    func load() throws -> TokenSet?
    func save(_ tokens: TokenSet) throws
    func clear() throws
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: TokenSet?

    public init(_ tokens: TokenSet? = nil) { self.tokens = tokens }
    public func load() throws -> TokenSet? { lock.withLock { tokens } }
    public func save(_ tokens: TokenSet) throws { lock.withLock { self.tokens = tokens } }
    public func clear() throws { lock.withLock { tokens = nil } }
}

/// Hands out a bearer token for API calls: the stored one while fresh, else a
/// refreshed one. If refresh fails the tokens are dropped and the caller must
/// sign in again; the local request queue is not touched here.
public actor AuthSession {
    private let client: OIDCClient
    private let store: TokenStore
    private let now: @Sendable () -> Date

    public init(client: OIDCClient, store: TokenStore,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.store = store
        self.now = now
    }

    public var isSignedIn: Bool { ((try? store.load()) ?? nil) != nil }

    public func signedIn(with tokens: TokenSet) throws { try store.save(tokens) }

    public func signOut() throws { try store.clear() }

    public func bearerToken() async throws -> String {
        guard let tokens = try store.load() else { throw AuthError.notSignedIn }
        if tokens.isFresh(at: now()) { return tokens.idToken }
        do {
            let renewed = try await client.refresh(tokens)
            try store.save(renewed)
            return renewed.idToken
        } catch {
            try? store.clear()
            throw AuthError.notSignedIn
        }
    }
}
