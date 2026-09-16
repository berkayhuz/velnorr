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

  func testActiveLevelBarNeverPassesMouseThroughDuringDrag() {
    XCTAssertFalse(
      VelnorrMousePolicy.ignoresMouseEvents(
        isMediaExpanded: false,
        isLevelBarInteracting: true,
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

  func testExpandedUtilityDoesNotTurnContentClicksIntoCenterToggle() {
    XCTAssertFalse(
      VelnorrMousePolicy.shouldToggleCenter(
        displayMode: .notch,
        isExpanded: true,
        isLevelBarInteracting: false,
        location: CGPoint(x: 200, y: 250),
        frameSize: CGSize(width: 420, height: 270)
      )
    )
  }

  func testCompactCenterClickRemainsAvailable() {
    XCTAssertTrue(
      VelnorrMousePolicy.shouldToggleCenter(
        displayMode: .notch,
        isExpanded: false,
        isLevelBarInteracting: false,
        location: CGPoint(x: 210, y: 265),
        frameSize: CGSize(width: 420, height: 270)
      )
    )
  }

  func testExpandedMediaAutoDismissesOnlyAfterPointerLeaves() {
    XCTAssertEqual(VelnorrMousePolicy.mediaAutoDismissDelay, 3)
    XCTAssertTrue(
      VelnorrMousePolicy.shouldAutoDismissMedia(
        isMediaExpanded: true,
        pointerInsideMedia: false
      )
    )
    XCTAssertFalse(
      VelnorrMousePolicy.shouldAutoDismissMedia(
        isMediaExpanded: true,
        pointerInsideMedia: true
      )
    )
    XCTAssertFalse(
      VelnorrMousePolicy.shouldAutoDismissMedia(
        isMediaExpanded: false,
        pointerInsideMedia: false
      )
    )
  }

  func testAccessibilityFallbackPollingUsesBoundedCadences() {
    XCTAssertEqual(VelnorrMousePolicy.fallbackIdlePollingInterval, 0.25, accuracy: 0.001)
    XCTAssertEqual(VelnorrMousePolicy.fallbackNearbyPollingInterval, 0.05, accuracy: 0.001)
    XCTAssertEqual(
      VelnorrMousePolicy.fallbackMediaPollingInterval,
      1.0 / 6.0,
      accuracy: 0.001
    )
  }
}
