import XCTest
@testable import JobtrackKit

final class BoardTests: XCTestCase {
    func testGroupsAndCountsByColumn() {
        let board = Board(cards: Fixtures.cards)
        XCTAssertEqual(board.count(in: .found), 1)
        XCTAssertEqual(board.count(in: .closed), 0)
        XCTAssertEqual(board.cards(in: .applied).map(\.id), ["c4"])
        XCTAssertEqual(Column.allCases.reduce(0) { $0 + board.count(in: $1) }, Fixtures.cards.count)
    }

    func testGatedMoveIsAmongAllowedMoves() {
        for card in Fixtures.cards {
            for gated in card.gatedMoves {
                XCTAssertTrue(card.allowedMoves.contains(gated), card.id)
            }
        }
        let c3 = Fixtures.cards[2]
        XCTAssertTrue(c3.isGated(.applied))
        XCTAssertFalse(c3.isGated(.closed))
    }

    func testCardDecodesFromJSON() throws {
        let json = """
        {"id":"x","title":"T","company":"C","column":"applied",
         "allowedMoves":["interviewing"],"gatedMoves":[],
         "request":{"state":"refused","reason":"no"}}
        """
        let card = try JSONDecoder().decode(BoardCard.self, from: Data(json.utf8))
        XCTAssertEqual(card.column, .applied)
        XCTAssertEqual(card.request, RequestStatus(state: .refused, reason: "no"))
        XCTAssertFalse(card.request!.isInFlight)
    }
}
