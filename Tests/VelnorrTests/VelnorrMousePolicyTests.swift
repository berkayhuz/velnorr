import XCTest

@testable import Velnorr

final class VelnorrMousePolicyTests: XCTestCase {
  func testExpandedMediaNeverPassesMouseThrough() {
    XCTAssertFalse(
      VelnorrMousePolicy.ignoresMouseEvents(
        isMediaExpanded: true,
        pointerInsideShape: false
      )
    )
  }

  func testCompactVelnorrPassesMouseThroughOutsideShape() {
    XCTAssertTrue(
      VelnorrMousePolicy.ignoresMouseEvents(
        isMediaExpanded: false,
        pointerInsideShape: false
      )
    )
  }

  func testCompactVelnorrReceivesMouseInsideShape() {
    XCTAssertFalse(
      VelnorrMousePolicy.ignoresMouseEvents(
        isMediaExpanded: false,
        pointerInsideShape: true
      )
    )
  }
}
