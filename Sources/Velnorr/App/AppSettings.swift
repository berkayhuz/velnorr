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
  static let capsLockHUD = "capsLockHUD"
  static let capsLockDisplayDuration = "capsLockDisplayDuration"

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
  ]
}

struct AppSettingsSnapshot: Equatable {
  let launchAtLogin: Bool
  let showInFullscreen: Bool
  let showOnExternalDisplays: Bool
  let externalDisplayMode: VelnorrDisplayMode
  let language: AppLanguage

  init(userDefaults: UserDefaults = .standard) {
    launchAtLogin = userDefaults.object(forKey: AppSettings.launchAtLogin) as? Bool ?? true
    showInFullscreen =
      userDefaults.object(forKey: AppSettings.showInFullscreen) as? Bool ?? true
    showOnExternalDisplays =
      userDefaults.object(forKey: "showOnExternalDisplays") as? Bool ?? true

    let displayMode = userDefaults.string(forKey: AppSettings.externalDisplayMode)
    externalDisplayMode = VelnorrDisplayMode(rawValue: displayMode ?? "") ?? .pill
    language = AppLanguage(rawValue: userDefaults.string(forKey: AppSettings.language) ?? "") ?? .system
  }
}
