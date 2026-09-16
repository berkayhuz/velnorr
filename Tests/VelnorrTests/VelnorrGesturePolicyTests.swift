import XCTest

@testable import Velnorr

final class VelnorrGesturePolicyTests: XCTestCase {
  func testDownwardProgressClampsAndIgnoresOppositeMovement() {
    XCTAssertEqual(
      VelnorrGesturePolicy.progress(
        translation: 60,
        sensitivity: 120,
        direction: .down
      ),
      0.5,
      accuracy: 0.001
    )
    XCTAssertEqual(
      VelnorrGesturePolicy.progress(
        translation: 240,
        sensitivity: 120,
        direction: .down
      ),
      1,
      accuracy: 0.001
    )
    XCTAssertFalse(
      VelnorrGesturePolicy.shouldTrigger(
        translation: -240,
        sensitivity: 120,
        direction: .down
      )
    )
  }

  func testUpwardGestureUsesNegativeTranslation() {
    XCTAssertEqual(
      VelnorrGesturePolicy.progress(
        translation: -90,
        sensitivity: 120,
        direction: .up
      ),
      0.75,
      accuracy: 0.001
    )
    XCTAssertTrue(
      VelnorrGesturePolicy.shouldTrigger(
        translation: -120,
        sensitivity: 120,
        direction: .up
      )
    )
    XCTAssertFalse(
      VelnorrGesturePolicy.shouldTrigger(
        translation: 120,
        sensitivity: 120,
        direction: .up
      )
    )
  }

  func testInvalidSensitivityNeverTriggers() {
    XCTAssertEqual(
      VelnorrGesturePolicy.progress(
        translation: 500,
        sensitivity: 0,
        direction: .down
      ),
      0
    )
    XCTAssertFalse(
      VelnorrGesturePolicy.shouldTrigger(
        translation: 500,
        sensitivity: -1,
        direction: .down
      )
    )
  }
}
