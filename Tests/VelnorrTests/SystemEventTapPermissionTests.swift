import CoreGraphics
import XCTest

@testable import Velnorr

final class SystemEventTapPermissionTests: XCTestCase {
  func testActiveTapCanBeAttemptedThroughEitherAuthorizationPath() {
    XCTAssertTrue(
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
        listenEventsGranted: true
      ).canAttemptActiveTap
    )

    XCTAssertTrue(
      SystemEventTapPermissionStatus(
        accessibilityGranted: false,
        listenEventsGranted: true
      ).canAttemptActiveTap
    )
    XCTAssertTrue(
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
        listenEventsGranted: false
      ).canAttemptActiveTap
    )
    XCTAssertFalse(
      SystemEventTapPermissionStatus(
        accessibilityGranted: false,
        listenEventsGranted: false
      ).canAttemptActiveTap
    )
  }

  func testEventTapDisableNotificationsRequireReenable() {
    XCTAssertTrue(SystemEventTapLifecycle.wasDisabled(.tapDisabledByTimeout))
    XCTAssertTrue(SystemEventTapLifecycle.wasDisabled(.tapDisabledByUserInput))
    XCTAssertFalse(SystemEventTapLifecycle.wasDisabled(.flagsChanged))
    XCTAssertFalse(SystemEventTapLifecycle.wasDisabled(.keyDown))
  }
}
