import ApplicationServices
import CoreGraphics

/// Checks whether macOS has exposed either supported authorization path for
/// creating a session event tap.
@MainActor
enum SystemEventTapPermission {
  static var canAttemptActiveTap: Bool {
    // Startup is automatic at login, so it must remain a status check only.
    // `CGEvent.tapCreate` remains the authoritative capability check because
    // either preflight can report a false negative across macOS versions.
    SystemEventTapPermissionStatus(
      accessibilityGranted: AXIsProcessTrusted(),
      listenEventsGranted: CGPreflightListenEventAccess()
    ).canAttemptActiveTap
  }
}

struct SystemEventTapPermissionStatus {
  let accessibilityGranted: Bool
  let listenEventsGranted: Bool

  var canAttemptActiveTap: Bool {
    accessibilityGranted || listenEventsGranted
  }
}

enum SystemEventTapLifecycle {
  static func wasDisabled(_ type: CGEventType) -> Bool {
    type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
  }
}
