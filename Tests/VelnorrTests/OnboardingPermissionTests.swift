import XCTest

@testable import Velnorr

final class OnboardingPermissionTests: XCTestCase {

  func testPackagedOnboardingDoesNotReuseDevelopmentCompletion() throws {
    let suiteName = "VelnorrTests.Onboarding.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(
      UserDefaults(suiteName: suiteName)
    )

    defer {
      defaults.removePersistentDomain(
        forName: suiteName
      )
    }

    defaults.set(
      "1.0.0",
      forKey: AppSettings.onboardingCompletedVersion
    )

    XCTAssertTrue(
      AppSettings.shouldShowOnboarding(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        isPackagedApplication: true
      )
    )

    XCTAssertFalse(
      AppSettings.shouldShowOnboarding(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        isPackagedApplication: false
      )
    )
  }

  func testPackagedOnboardingCompletionIsVersionAware() throws {
    let suiteName = "VelnorrTests.Onboarding.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(
      UserDefaults(suiteName: suiteName)
    )

    defer {
      defaults.removePersistentDomain(
        forName: suiteName
      )
    }

    AppSettings.markOnboardingCompleted(
      userDefaults: defaults,
      currentVersion: "1.0.0",
      isPackagedApplication: true
    )

    XCTAssertFalse(
      AppSettings.shouldShowOnboarding(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        isPackagedApplication: true
      )
    )

    XCTAssertTrue(
      AppSettings.shouldShowOnboarding(
        userDefaults: defaults,
        currentVersion: "1.0.2",
        isPackagedApplication: true
      )
    )
  }

  func testPollingDoesNotRunOutsidePermissionsPage() {
    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .welcome,
        accessibilityGranted: false,
        deviceControlGranted: false
      )
    )

    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .indicators,
        accessibilityGranted: false,
        deviceControlGranted: false
      )
    )
  }

  func testPollingRunsWhenAccessibilityIsMissing() {
    XCTAssertTrue(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: false,
        deviceControlGranted: true
      )
    )
  }

  func testPollingRunsWhenDeviceControlIsMissing() {
    XCTAssertTrue(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: true,
        deviceControlGranted: false
      )
    )
  }

  func testPollingRunsWhenBothPermissionsAreMissing() {
    XCTAssertTrue(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: false,
        deviceControlGranted: false
      )
    )
  }

  func testPollingStopsWhenBothPermissionsAreGranted() {
    XCTAssertFalse(
      OnboardingPermissionPolicy.shouldPoll(
        page: .permissions,
        accessibilityGranted: true,
        deviceControlGranted: true
      )
    )
  }
}