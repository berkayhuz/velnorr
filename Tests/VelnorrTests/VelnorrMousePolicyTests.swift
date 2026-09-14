import XCTest

@testable import Velnorr

final class VelnorrMousePolicyTests: XCTestCase {
  func testPointerNotificationTargetsOnlyItsDisplay() {
    XCTAssertTrue(
      VelnorrMousePolicy.acceptsPointerNotification(
        displayID: 42,
        targetDisplayID: 42
      )
    )
    XCTAssertFalse(
      VelnorrMousePolicy.acceptsPointerNotification(
        displayID: 42,
        targetDisplayID: 43
      )
    )
    XCTAssertFalse(
      VelnorrMousePolicy.acceptsPointerNotification(
        displayID: nil,
        targetDisplayID: 42
      )
    )
  }

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
