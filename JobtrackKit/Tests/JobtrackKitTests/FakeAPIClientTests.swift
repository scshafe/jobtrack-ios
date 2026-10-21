import XCTest
@testable import JobtrackKit

final class FakeAPIClientTests: XCTestCase {
    struct Down: Error {}

    func testMoveMarksCardPendingAndKeepsItInPlace() async throws {
        let api = FakeAPIClient()
        let card = Fixtures.cards[0]
        let status = try await api.file(.move(card, to: .pursuing))
        XCTAssertEqual(status.state, .pending)
        let after = try await api.board().cards.first { $0.id == card.id }
        XCTAssertEqual(after?.column, .found)
        XCTAssertEqual(after?.request?.state, .pending)
    }

    func testFailureThrowsAndFilesNothing() async throws {
        let api = FakeAPIClient()
        await api.setFailure(Down())
        do {
            _ = try await api.file(.move(Fixtures.cards[0], to: .pursuing))
            XCTFail("expected a throw")
        } catch {}
        let filed = await api.filed
        XCTAssertTrue(filed.isEmpty)
    }

    func testRequestsCarryDistinctIdempotencyKeys() {
        let c = Fixtures.cards[0]
        XCTAssertNotEqual(JobRequest.move(c, to: .pursuing).clientRequestID,
                          JobRequest.move(c, to: .pursuing).clientRequestID)
        let r = JobRequest.capture(url: URL(string: "https://example.com/job/1")!)
        XCTAssertEqual(r.kind, .capture)
        XCTAssertEqual(r.payload["url"], "https://example.com/job/1")
    }
}
