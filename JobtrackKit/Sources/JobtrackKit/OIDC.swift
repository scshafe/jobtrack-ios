import Foundation

/// Where and as whom to sign in. Values come from build configuration, never
/// from git (the issuer is on the tailnet; docs/design.md "Sign-in").
public struct OIDCConfig: Equatable, Sendable {
    public var issuer: URL
    public var clientID: String
    public var redirectURI: String
    public var scopes: [String]

    public init(issuer: URL, clientID: String, redirectURI: String,
                scopes: [String] = ["openid", "profile", "email", "offline_access"]) {
        self.issuer = issuer
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

public struct TokenSet: Equatable, Codable, Sendable {
    public var idToken: String
    public var refreshToken: String?
    public var expiresAt: Date

    public init(idToken: String, refreshToken: String?, expiresAt: Date) {
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public func isFresh(at now: Date, leeway: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(now) > leeway
    }
}

public enum AuthError: Error, Equatable {
    case notSignedIn
    case badCallback
    case stateMismatch
    case serverError(String)
    case badResponse
}

/// The identity provider's endpoints (OIDC discovery).
struct Discovery: Decodable {
    let authorization_endpoint: URL
    let token_endpoint: URL
}

/// Raw HTTP, so `OIDCClient` is testable without a network.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.badResponse }
        return (data, http)
    }
}

/// One in-progress sign-in: the URL to open and what to check on return.
public struct AuthorizationRequest: Equatable, Sendable {
    public let url: URL
    public let state: String
    public let pkce: PKCE
}

/// Authorization code + PKCE as a public client (no secret).
public struct OIDCClient: Sendable {
    public let config: OIDCConfig
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date

    public init(config: OIDCConfig, transport: HTTPTransport = URLSessionTransport(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.transport = transport
        self.now = now
    }

    func discovery() async throws -> Discovery {
        let url = config.issuer.appendingPathComponent(".well-known/openid-configuration")
        let (data, response) = try await transport.send(URLRequest(url: url))
        guard response.statusCode == 200,
              let found = try? JSONDecoder().decode(Discovery.self, from: data)
        else { throw AuthError.badResponse }
        return found
    }

    public func authorizationRequest(
        pkce: PKCE = PKCE(), state: String = UUID().uuidString
    ) async throws -> AuthorizationRequest {
        let endpoint = try await discovery().authorization_endpoint
        var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        parts.queryItems = (parts.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return AuthorizationRequest(url: parts.url!, state: state, pkce: pkce)
    }

    /// Checks the redirect and trades its code for tokens.
    public func complete(_ request: AuthorizationRequest, callback: URL) async throws -> TokenSet {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") { throw AuthError.serverError(error) }
        guard let code = value("code") else { throw AuthError.badCallback }
        guard value("state") == request.state else { throw AuthError.stateMismatch }
        return try await token([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "code_verifier": request.pkce.verifier,
        ], keepingRefresh: nil)
    }

    public func refresh(_ tokens: TokenSet) async throws -> TokenSet {
        guard let refresh = tokens.refreshToken else { throw AuthError.notSignedIn }
        return try await token([
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": config.clientID,
        ], keepingRefresh: refresh)
    }

    private func token(_ form: [String: String], keepingRefresh: String?) async throws -> TokenSet {
        var request = URLRequest(url: try await discovery().token_endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = Data(form.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").utf8)
        let (data, response) = try await transport.send(request)
        struct Body: Decodable {
            let id_token: String?
            let refresh_token: String?
            let expires_in: Double?
            let error: String?
        }
        let body = try? JSONDecoder().decode(Body.self, from: data)
        guard response.statusCode == 200, let id = body?.id_token else {
            throw AuthError.serverError(body?.error ?? "http \(response.statusCode)")
        }
        return TokenSet(
            idToken: id,
            refreshToken: body?.refresh_token ?? keepingRefresh,
            expiresAt: now().addingTimeInterval(body?.expires_in ?? 300))
    }
}
