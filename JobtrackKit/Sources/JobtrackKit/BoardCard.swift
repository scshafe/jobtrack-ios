import Foundation

/// One card of the board read model. The shape is **pending** jobtrack's
/// docs/design-mobile-and-discovery.md; the server owns `column` and
/// `allowedMoves` (docs/design.md, decision 2) and the app renders them.
public struct BoardCard: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var company: String
    public var column: Column
    /// Columns this card may move to, as the server says.
    public var allowedMoves: [Column]
    /// The subset of `allowedMoves` that needs confirmation first.
    public var gatedMoves: [Column]
    /// The latest request filed for this card that has not yet been applied
    /// (or was refused).
    public var request: RequestStatus?

    public init(
        id: String, title: String, company: String, column: Column,
        allowedMoves: [Column] = [], gatedMoves: [Column] = [],
        request: RequestStatus? = nil
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.column = column
        self.allowedMoves = allowedMoves
        self.gatedMoves = gatedMoves
        self.request = request
    }

    public func isGated(_ target: Column) -> Bool { gatedMoves.contains(target) }
}
