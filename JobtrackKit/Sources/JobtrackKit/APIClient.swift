import Foundation

/// The app's only way to reach jobtrack. The wire format is **pending**
/// jobtrack's design; only this protocol and its implementations change when
/// it lands. Reads the board, files requests, never writes the store.
public protocol APIClient: Sendable {
    func board() async throws -> Board
    /// Files a request. Returns the status jobtrack gives it (`pending` when
    /// accepted), or throws when it could not be sent.
    func file(_ request: JobRequest) async throws -> RequestStatus
}
