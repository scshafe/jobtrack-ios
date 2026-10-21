import Foundation

/// What the app asks jobtrack to do. The app never writes the store: it files
/// one of these and shows the card pending until jobtrack applies it.
public enum RequestKind: String, Codable, Sendable {
    case move, pursue, dismiss, approve, capture
}

/// A request as filed. `clientRequestID` is the idempotency key (**pending**
/// jobtrack's confirmation, docs/design.md decision 4).
public struct JobRequest: Hashable, Codable, Sendable {
    public var clientRequestID: UUID
    public var kind: RequestKind
    public var cardID: String?
    public var payload: [String: String]

    public init(
        clientRequestID: UUID = UUID(), kind: RequestKind,
        cardID: String? = nil, payload: [String: String] = [:]
    ) {
        self.clientRequestID = clientRequestID
        self.kind = kind
        self.cardID = cardID
        self.payload = payload
    }

    public static func move(_ card: BoardCard, to column: Column) -> JobRequest {
        JobRequest(kind: .move, cardID: card.id, payload: ["to": column.rawValue])
    }

    public static func capture(url: URL) -> JobRequest {
        JobRequest(kind: .capture, payload: ["url": url.absoluteString])
    }
}

/// Where a request is. `queued` is local only (not yet accepted by the API).
public struct RequestStatus: Hashable, Codable, Sendable {
    public enum State: String, Codable, Sendable {
        case queued, pending, applied, refused
    }

    public var state: State
    /// jobtrack's reason when `state` is `.refused`.
    public var reason: String?

    public init(state: State, reason: String? = nil) {
        self.state = state
        self.reason = reason
    }

    /// Shown with a pending badge: not yet applied, not refused.
    public var isInFlight: Bool { state == .queued || state == .pending }
}
