import JobtrackKit
import Observation

/// Adapter between `APIClient` and the views. A move files a request and
/// reloads; the card stays in its column, pending, until jobtrack applies it.
@Observable @MainActor
final class BoardModel {
    private(set) var board = Board()
    private(set) var error: String?
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func load() async {
        do {
            board = try await api.board()
            error = nil
        } catch {
            self.error = "Could not load the board."
        }
    }

    func move(_ card: BoardCard, to column: Column) async {
        do {
            _ = try await api.file(.move(card, to: column))
            await load()
        } catch {
            self.error = "Could not send the request."
        }
    }
}
