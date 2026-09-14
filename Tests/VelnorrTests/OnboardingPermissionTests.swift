import XCTest

@testable import Velnorr

final class OnboardingPermissionTests: XCTestCase {
  func testPollingOnlyRunsOnPermissionsPageWhilePermissionIsMissing() {
    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .welcome,
        accessibilityGranted: false,
        listenEventsGranted: false
      )
    )
    XCTAssertTrue(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: false,
        listenEventsGranted: true
      )
    )
    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: true,
        listenEventsGranted: true
      )
    )
    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .indicators,
        accessibilityGranted: false,
        listenEventsGranted: false
      )
    )
  }
}
