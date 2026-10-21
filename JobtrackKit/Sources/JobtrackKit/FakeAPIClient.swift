import Foundation

/// An in-memory `APIClient` over synthetic cards, for tests, previews and the
/// app until the live API exists. A filed move marks its card pending and
/// leaves it in its column, as the real board would until jobtrack applies it.
public actor FakeAPIClient: APIClient {
    private var cards: [BoardCard]
    public private(set) var filed: [JobRequest] = []
    /// When set, `file` throws it (to test the not-sent path).
    public var failure: Error?

    public init(cards: [BoardCard] = Fixtures.cards) { self.cards = cards }

    public func setFailure(_ error: Error?) { failure = error }

    public func board() async throws -> Board { Board(cards: cards) }

    public func file(_ request: JobRequest) async throws -> RequestStatus {
        if let failure { throw failure }
        filed.append(request)
        let status = RequestStatus(state: .pending)
        if let id = request.cardID, let i = cards.firstIndex(where: { $0.id == id }) {
            cards[i].request = status
        }
        return status
    }
}

/// Synthetic data only: no real company, role or store content.
public enum Fixtures {
    public static let cards: [BoardCard] = [
        BoardCard(id: "c1", title: "Platform Engineer", company: "Example Co",
                  column: .found, allowedMoves: [.pursuing, .closed]),
        BoardCard(id: "c2", title: "Backend Developer", company: "Sample Labs",
                  column: .pursuing, allowedMoves: [.preparing, .closed]),
        BoardCard(id: "c3", title: "Staff Engineer", company: "Acme Test",
                  column: .preparing, allowedMoves: [.applied, .closed],
                  gatedMoves: [.applied]),
        BoardCard(id: "c4", title: "Site Reliability Engineer", company: "Placeholder Inc",
                  column: .applied, allowedMoves: [.interviewing, .closed]),
        BoardCard(id: "c5", title: "Data Engineer", company: "Demo Systems",
                  column: .interviewing, allowedMoves: [.offer, .closed]),
        BoardCard(id: "c6", title: "Software Engineer", company: "Fixture Works",
                  column: .offer, allowedMoves: [.closed], gatedMoves: [.closed],
                  request: RequestStatus(state: .refused, reason: "Synthetic refusal reason")),
    ]
}
