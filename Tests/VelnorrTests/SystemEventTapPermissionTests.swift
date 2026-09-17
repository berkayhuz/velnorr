import XCTest

@testable import Velnorr

final class SystemEventTapPermissionTests: XCTestCase {
  func testPermissionRequiresAccessibilityAndListenEventAccess() {
    XCTAssertTrue(
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
        listenEventsGranted: true
      ).isGranted
    )

    XCTAssertFalse(
      SystemEventTapPermissionStatus(
        accessibilityGranted: false,
        listenEventsGranted: true
      ).isGranted
    )
    XCTAssertFalse(
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
        listenEventsGranted: false
      ).isGranted
    )
    XCTAssertFalse(
      SystemEventTapPermissionStatus(
        accessibilityGranted: false,
        listenEventsGranted: false
      ).isGranted
    )
  }
}
