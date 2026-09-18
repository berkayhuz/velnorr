@preconcurrency import ApplicationServices
import CoreGraphics

@MainActor
enum SystemEventTapPermission {

  static var status: SystemEventTapPermissionStatus {
    SystemEventTapPermissionStatus(
      accessibilityGranted: AXIsProcessTrusted(),
      listenEventsGranted: CGPreflightListenEventAccess()
    )
  }

  /// Velnorr `.defaultTap` ile aktif bir event tap kullanıyor.
  ///
  /// Accessibility aktif filtreleme için ana yetkidir.
  ///
  /// Input Monitoring bazı macOS / keyboard event yollarında
  /// ek dinleme erişimi sağlayabilir, ancak PostEvent burada
  /// bir ön koşul değildir.
  static var canAttemptActiveTap: Bool {
    status.accessibilityGranted
  }

  @discardableResult
  static func requestAccessibility() -> Bool {
    let options: CFDictionary = [
      "AXTrustedCheckOptionPrompt": true
    ] as CFDictionary

    return AXIsProcessTrustedWithOptions(options)
  }

  @discardableResult
  static func requestInputMonitoring() -> Bool {
    CGRequestListenEventAccess()
  }
}

struct SystemEventTapPermissionStatus {
  let accessibilityGranted: Bool
  let listenEventsGranted: Bool

  var canAttemptActiveTap: Bool {
    accessibilityGranted
  }
}

enum SystemEventTapLifecycle {
  static func wasDisabled(
    _ type: CGEventType
  ) -> Bool {
    type == .tapDisabledByTimeout
      || type == .tapDisabledByUserInput
  }
}