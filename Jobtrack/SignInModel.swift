import AuthenticationServices
import JobtrackKit
import Observation
import UIKit

/// Drives sign-in with `ASWebAuthenticationSession` against Pocket ID.
/// Issuer and client id come from build settings (project.local.yml), never
/// from git; with them unset the app says so instead of signing in.
@Observable @MainActor
final class SignInModel: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let redirectURI = "com.scshafe.jobtrack:/oauth/callback"

    private(set) var signedIn: Bool
    private(set) var message: String?
    let session: AuthSession?
    private let client: OIDCClient?
    private var web: ASWebAuthenticationSession?

    override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let store = KeychainTokenStore()
        if let issuer = (info["JobtrackIssuer"] as? String).flatMap(URL.init(string:)),
           issuer.host != nil,
           let clientID = info["JobtrackClientID"] as? String, !clientID.isEmpty {
            let client = OIDCClient(config: OIDCConfig(
                issuer: issuer, clientID: clientID, redirectURI: Self.redirectURI))
            self.client = client
            self.session = AuthSession(client: client, store: store)
        } else {
            self.client = nil
            self.session = nil
        }
        self.signedIn = ((try? store.load()) ?? nil) != nil
        super.init()
    }

    var isConfigured: Bool { client != nil }

    func signIn() async {
        guard let client, let session else {
            message = "Set JOBTRACK_ISSUER and JOBTRACK_CLIENT_ID in project.local.yml."
            return
        }
        do {
            let request = try await client.authorizationRequest()
            let callback = try await open(request.url)
            let tokens = try await client.complete(request, callback: callback)
            try await session.signedIn(with: tokens)
            signedIn = true
            message = nil
        } catch ASWebAuthenticationSessionError.canceledLogin {
            message = nil
        } catch {
            message = "Sign-in failed."
        }
    }

    func signOut() async {
        try? await session?.signOut()
        signedIn = false
    }

    private func open(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let web = ASWebAuthenticationSession(
                url: url, callbackURLScheme: "com.scshafe.jobtrack"
            ) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: error ?? AuthError.badCallback)
                }
            }
            web.presentationContextProvider = self
            self.web = web
            web.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
        }
    }
}
