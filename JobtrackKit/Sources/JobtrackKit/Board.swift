import Foundation

/// The board as the app shows it: cards grouped into the fixed columns.
public struct Board: Equatable, Sendable {
    public var cards: [BoardCard]

    public init(cards: [BoardCard] = []) { self.cards = cards }

    public func cards(in column: Column) -> [BoardCard] {
        cards.filter { $0.column == column }
    }

    public func count(in column: Column) -> Int {
        cards.reduce(0) { $0 + ($1.column == column ? 1 : 0) }
    }
}
