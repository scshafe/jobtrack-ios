import XCTest
@testable import JobtrackKit

/// Replies from a script, recording what was sent. Synthetic issuer.
final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var token: (Int, String)
    private(set) var sent: [URLRequest] = []

    init(token: (Int, String)) { self.token = token }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { sent.append(request) }
        let path = request.url!.path
        let (code, body): (Int, String) = path.hasSuffix("openid-configuration")
            ? (200, #"{"authorization_endpoint":"https://id.example.test/authorize","token_endpoint":"https://id.example.test/token"}"#)
            : lock.withLock { token }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    func setToken(_ token: (Int, String)) { lock.withLock { self.token = token } }
    var tokenRequests: [URLRequest] { lock.withLock { sent.filter { $0.httpMethod == "POST" } } }
}

final class AuthTests: XCTestCase {
    let config = OIDCConfig(
        issuer: URL(string: "https://id.example.test")!,
        clientID: "test-client", redirectURI: "com.example.test:/cb")
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testPKCEChallengeMatchesRFC7636Vector() {
        // RFC 7636 appendix B.
        XCTAssertEqual(
            PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertNotEqual(PKCE.randomVerifier(), PKCE.randomVerifier())
    }

    func testAuthorizationURLCarriesPKCEAndState() async throws {
        let client = OIDCClient(config: config, transport: ScriptedTransport(token: (200, "{}")))
        let req = try await client.authorizationRequest(pkce: PKCE(verifier: "v"), state: "s1")
        let items = URLComponents(url: req.url, resolvingAgainstBaseURL: false)!.queryItems!
        func v(_ n: String) -> String? { items.first { $0.name == n }?.value }
        XCTAssertEqual(req.url.host, "id.example.test")
        XCTAssertEqual(v("response_type"), "code")
        XCTAssertEqual(v("code_challenge_method"), "S256")
        XCTAssertEqual(v("code_challenge"), PKCE.challenge(for: "v"))
        XCTAssertEqual(v("state"), "s1")
        XCTAssertEqual(v("client_id"), "test-client")
    }

    func testCompleteChecksStateAndExchangesCode() async throws {
        let transport = ScriptedTransport(token: (200, #"{"id_token":"id1","refresh_token":"r1","expires_in":600}"#))
        let t0 = self.t0
        let client = OIDCClient(config: config, transport: transport, now: { t0 })
        let req = try await client.authorizationRequest(pkce: PKCE(verifier: "v"), state: "s1")

        do {
            _ = try await client.complete(req, callback: URL(string: "com.example.test:/cb?code=c&state=other")!)
            XCTFail("expected a state mismatch")
        } catch { XCTAssertEqual(error as? AuthError, .stateMismatch) }

        let tokens = try await client.complete(req, callback: URL(string: "com.example.test:/cb?code=c&state=s1")!)
        XCTAssertEqual(tokens, TokenSet(idToken: "id1", refreshToken: "r1", expiresAt: t0.addingTimeInterval(600)))
        let body = String(data: transport.tokenRequests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("code_verifier=v"))
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertFalse(body.contains("client_secret"))
    }

    func testProviderErrorInCallback() async throws {
        let client = OIDCClient(config: config, transport: ScriptedTransport(token: (200, "{}")))
        let req = try await client.authorizationRequest()
        do {
            _ = try await client.complete(req, callback: URL(string: "com.example.test:/cb?error=access_denied")!)
            XCTFail("expected an error")
        } catch { XCTAssertEqual(error as? AuthError, .serverError("access_denied")) }
    }

    func testSessionUsesFreshTokenWithoutRefreshing() async throws {
        let transport = ScriptedTransport(token: (400, "{}"))
        let t0 = self.t0
        let store = InMemoryTokenStore(TokenSet(idToken: "fresh", refreshToken: "r", expiresAt: t0.addingTimeInterval(3600)))
        let session = AuthSession(client: OIDCClient(config: config, transport: transport), store: store, now: { t0 })
        let bearer = try await session.bearerToken()
        XCTAssertEqual(bearer, "fresh")
        XCTAssertTrue(transport.tokenRequests.isEmpty)
    }

    func testSessionRefreshesExpiredTokenAndKeepsRefreshToken() async throws {
        let transport = ScriptedTransport(token: (200, #"{"id_token":"new","expires_in":600}"#))
        let t0 = self.t0
        let store = InMemoryTokenStore(TokenSet(idToken: "old", refreshToken: "r", expiresAt: t0.addingTimeInterval(-10)))
        let client = OIDCClient(config: config, transport: transport, now: { t0 })
        let session = AuthSession(client: client, store: store, now: { t0 })
        let bearer = try await session.bearerToken()
        XCTAssertEqual(bearer, "new")
        XCTAssertEqual(try store.load()?.refreshToken, "r")
    }

    func testFailedRefreshSignsOut() async throws {
        let transport = ScriptedTransport(token: (400, #"{"error":"invalid_grant"}"#))
        let t0 = self.t0
        let store = InMemoryTokenStore(TokenSet(idToken: "old", refreshToken: "r", expiresAt: t0.addingTimeInterval(-10)))
        let session = AuthSession(client: OIDCClient(config: config, transport: transport, now: { t0 }), store: store, now: { t0 })
        do {
            _ = try await session.bearerToken()
            XCTFail("expected sign-in required")
        } catch { XCTAssertEqual(error as? AuthError, .notSignedIn) }
        XCTAssertNil(try store.load())
        let signedIn = await session.isSignedIn
        XCTAssertFalse(signedIn)
    }

    func testSignedOutHasNoToken() async {
        let session = AuthSession(client: OIDCClient(config: config, transport: ScriptedTransport(token: (200, "{}"))),
                                  store: InMemoryTokenStore())
        do {
            _ = try await session.bearerToken()
            XCTFail("expected notSignedIn")
        } catch { XCTAssertEqual(error as? AuthError, .notSignedIn) }
    }
}
