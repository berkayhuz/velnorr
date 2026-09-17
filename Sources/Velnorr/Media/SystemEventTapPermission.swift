import ApplicationServices
import CoreGraphics

/// Coordinates the two macOS permissions required by a session event tap.
///
/// Accessibility allows the app to install an event tap and Listen Event
/// access (shown as Input Monitoring in System Settings) allows it to receive
/// system-defined media-key events. They are separate permissions, so both
/// must be checked explicitly.
@MainActor
enum SystemEventTapPermission {
  static var isGranted: Bool {
    // Startup is automatic at login, so it must remain a status check only.
    // Permission UI is opened explicitly from onboarding instead.
    SystemEventTapPermissionStatus(
      accessibilityGranted: AXIsProcessTrusted(),
      listenEventsGranted: CGPreflightListenEventAccess()
    ).isGranted
  }
}

struct SystemEventTapPermissionStatus {
  let accessibilityGranted: Bool
  let listenEventsGranted: Bool

  var isGranted: Bool {
    accessibilityGranted && listenEventsGranted
  }
}
