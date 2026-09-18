import CoreGraphics
import XCTest

@testable import Velnorr

final class SystemEventTapPermissionTests: XCTestCase {

  func testActiveTapRequiresAccessibility() {
    XCTAssertTrue(
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
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
        listenEventsGranted: true
      ).canAttemptActiveTap
    )

    XCTAssertFalse(
      SystemEventTapPermissionStatus(
        accessibilityGranted: false,
        listenEventsGranted: false
      ).canAttemptActiveTap
    )
  }

  func testListenEventPermissionIsTrackedSeparately() {
    let granted = SystemEventTapPermissionStatus(
      accessibilityGranted: true,
      listenEventsGranted: true
    )

    XCTAssertTrue(granted.accessibilityGranted)
    XCTAssertTrue(granted.listenEventsGranted)

    let missingDeviceControl =
      SystemEventTapPermissionStatus(
        accessibilityGranted: true,
        listenEventsGranted: false
      )

    XCTAssertTrue(
      missingDeviceControl.accessibilityGranted
    )

    XCTAssertFalse(
      missingDeviceControl.listenEventsGranted
    )
  }

  func testEventTapDisableNotificationsRequireReenable() {
    XCTAssertTrue(
      SystemEventTapLifecycle.wasDisabled(
        .tapDisabledByTimeout
      )
    )

    XCTAssertTrue(
      SystemEventTapLifecycle.wasDisabled(
        .tapDisabledByUserInput
      )
    )

    XCTAssertFalse(
      SystemEventTapLifecycle.wasDisabled(
        .flagsChanged
      )
    )

    XCTAssertFalse(
      SystemEventTapLifecycle.wasDisabled(
        .keyDown
      )
    )
  }
}