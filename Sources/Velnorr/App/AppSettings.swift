import Foundation

enum AppSettings {
  static let launchAtLogin = "launchAtLogin"
  static let expandOnHover = "expandOnHover"
  static let showInFullscreen = "showInFullscreen"
  static let externalDisplayMode = "externalDisplayMode"
  static let horizontalOffset = "hudHorizontalOffset"
  static let verticalOffset = "hudVerticalOffset"
  static let language = "appLanguage"
  static let onboardingCompleted = "onboardingCompleted"
  static let onboardingCompletedVersion = "onboardingCompletedVersion"
  static let packagedOnboardingCompletedVersion = "packagedOnboardingCompletedVersion"
  static let capsLockHUD = "capsLockHUD"
  static let capsLockDisplayDuration = "capsLockDisplayDuration"
  static let capsLockHUDSize = "capsLockHUDSize"
  static let lockScreenRightIcon = "lockScreenRightIcon"
  static let lockScreenRightIconColor = "lockScreenRightIconColor"
  static let gesturesEnabled = "gesturesEnabled"
  static let closeGestureEnabled = "closeGestureEnabled"
  static let gestureSensitivity = "gestureSensitivity"
  static let enableHaptics = "enableHaptics"
  static let mirrorShape = "mirrorShape"
  static let notchHeightMode = "notchHeightMode"
  static let nonNotchHeightMode = "nonNotchHeightMode"
  static let notchHeight = "notchHeight"
  static let nonNotchHeight = "nonNotchHeight"
  static let calendarShowEvents = "calendarShowEvents"
  static let calendarShowReminders = "calendarShowReminders"
  static let calendarShowCompletedReminders = "calendarShowCompletedReminders"
  static let shelfShowQuickShare = "shelfShowQuickShare"
  static let shelfMaximumItems = "shelfMaximumItems"

  static let defaultLockScreenRightIcon = "face.smiling"
  static let defaultLockScreenRightIconColor = "white"

  static func shouldShowOnboarding(
    userDefaults: UserDefaults = .standard,
    currentVersion: String,
    isPackagedApplication: Bool
  ) -> Bool {
    let key = onboardingCompletionKey(isPackagedApplication: isPackagedApplication)
    return userDefaults.string(forKey: key) != currentVersion
  }

  static func markOnboardingCompleted(
    userDefaults: UserDefaults = .standard,
    currentVersion: String,
    isPackagedApplication: Bool
  ) {
    let key = onboardingCompletionKey(isPackagedApplication: isPackagedApplication)
    userDefaults.set(currentVersion, forKey: key)
  }

  private static func onboardingCompletionKey(isPackagedApplication: Bool) -> String {
    isPackagedApplication ? packagedOnboardingCompletedVersion : onboardingCompletedVersion
  }

  @MainActor static let defaults: [String: Any] = [
    launchAtLogin: true,
    expandOnHover: true,
    showInFullscreen: true,
    externalDisplayMode: VelnorrDisplayMode.pill.rawValue,
    horizontalOffset: 0.0,
    verticalOffset: 0.0,
    language: AppLanguage.system.rawValue,
    capsLockHUD: true,
    capsLockDisplayDuration: 1.6,
    capsLockHUDSize: 38.0,
    lockScreenRightIcon: defaultLockScreenRightIcon,
    lockScreenRightIconColor: defaultLockScreenRightIconColor,
    gesturesEnabled: true,
    closeGestureEnabled: true,
    gestureSensitivity: 120.0,
    enableHaptics: true,
    mirrorShape: VelnorrMirrorShape.roundedRectangle.rawValue,
    notchHeightMode: VelnorrNotchHeightMode.system.rawValue,
    nonNotchHeightMode: VelnorrNotchHeightMode.menuBar.rawValue,
    notchHeight: 32.0,
    nonNotchHeight: 32.0,
    calendarShowEvents: true,
    calendarShowReminders: true,
    calendarShowCompletedReminders: true,
    shelfShowQuickShare: true,
    shelfMaximumItems: 32,
  ]
}

struct AppSettingsSnapshot: Equatable {
  let launchAtLogin: Bool
  let showInFullscreen: Bool
  let showOnExternalDisplays: Bool
  let externalDisplayMode: VelnorrDisplayMode
  let language: AppLanguage
  let notchHeightMode: VelnorrNotchHeightMode
  let nonNotchHeightMode: VelnorrNotchHeightMode
  let notchHeight: CGFloat
  let nonNotchHeight: CGFloat

  init(userDefaults: UserDefaults = .standard) {
    launchAtLogin = userDefaults.object(forKey: AppSettings.launchAtLogin) as? Bool ?? true
    showInFullscreen =
      userDefaults.object(forKey: AppSettings.showInFullscreen) as? Bool ?? true
    showOnExternalDisplays =
      userDefaults.object(forKey: "showOnExternalDisplays") as? Bool ?? true

    let displayMode = userDefaults.string(forKey: AppSettings.externalDisplayMode)
    externalDisplayMode = VelnorrDisplayMode(rawValue: displayMode ?? "") ?? .pill
    language = AppLanguage(rawValue: userDefaults.string(forKey: AppSettings.language) ?? "") ?? .system

    let notchMode = userDefaults.string(forKey: AppSettings.notchHeightMode)
    notchHeightMode = VelnorrNotchHeightMode(rawValue: notchMode ?? "") ?? .system
    let nonNotchMode = userDefaults.string(forKey: AppSettings.nonNotchHeightMode)
    nonNotchHeightMode = VelnorrNotchHeightMode(rawValue: nonNotchMode ?? "") ?? .menuBar
    notchHeight = Self.clampedHeight(
      userDefaults.double(forKey: AppSettings.notchHeight),
      fallback: 32
    )
    nonNotchHeight = Self.clampedHeight(
      userDefaults.double(forKey: AppSettings.nonNotchHeight),
      fallback: 32
    )
  }

  var notchHeightConfiguration: VelnorrNotchHeightConfiguration {
    VelnorrNotchHeightConfiguration(
      notchMode: notchHeightMode,
      nonNotchMode: nonNotchHeightMode,
      notchHeight: notchHeight,
      nonNotchHeight: nonNotchHeight
    )
  }

  private static func clampedHeight(_ value: Double, fallback: CGFloat) -> CGFloat {
    let value = value > 0 ? CGFloat(value) : fallback
    return min(64, max(16, value))
  }
}
