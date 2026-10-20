import XCTest
@testable import JobtrackKit

final class ColumnTests: XCTestCase {
    func testColumnsAreTheFixedLifecycle() {
        XCTAssertEqual(
            Column.allCases.map(\.title),
            ["Found", "Pursuing", "Preparing", "Applied", "Interviewing", "Offer", "Closed"]
        )
    }
}
