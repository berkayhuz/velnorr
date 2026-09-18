import XCTest

@testable import Velnorr

final class OnboardingPermissionTests: XCTestCase {
  func testPackagedOnboardingDoesNotReuseDevelopmentCompletion() throws {
    let suiteName = "VelnorrTests.Onboarding.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("1.0.0", forKey: AppSettings.onboardingCompletedVersion)

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
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

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

  func testPollingOnlyRunsOnPermissionsPageWhileCorePermissionIsMissing() {
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
