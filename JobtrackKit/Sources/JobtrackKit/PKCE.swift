import CryptoKit
import Foundation

/// PKCE (RFC 7636), method S256.
public struct PKCE: Equatable, Sendable {
    public let verifier: String
    public var challenge: String { PKCE.challenge(for: verifier) }

    public init(verifier: String = PKCE.randomVerifier()) { self.verifier = verifier }

    public static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
        return base64URL(Data(bytes))
    }

    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
