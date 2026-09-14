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
  private static var didRequestAccessibility = false
  private static var didRequestListenEvents = false

  static var isGranted: Bool {
    AXIsProcessTrusted() && CGPreflightListenEventAccess()
  }

  @discardableResult
  static func requestIfNeeded() -> Bool {
    let accessibilityGranted = AXIsProcessTrusted()
    if !accessibilityGranted && !didRequestAccessibility {
      didRequestAccessibility = true
      // Keep the key local instead of reading the SDK's mutable CFString
      // global from Swift's concurrency checking context.
      let promptKey = "AXTrustedCheckOptionPrompt"
      _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    let listenGranted = CGPreflightListenEventAccess()
    if !listenGranted && !didRequestListenEvents {
      didRequestListenEvents = true
      _ = CGRequestListenEventAccess()
    }

    return accessibilityGranted && listenGranted
  }
}
