import AppKit
import SwiftUI

final class VelnorrLockScreenWindow: NSPanel {
  private let widgetSize = NSSize(width: 440, height: 190)

  init(screen: NSScreen, runtime: VelnorrRuntime) {
    let visibleFrame = screen.visibleFrame
    let frame = CGRect(
      x: screen.frame.midX - widgetSize.width / 2,
      y: visibleFrame.minY + visibleFrame.height * 0.26,
      width: widgetSize.width,
      height: widgetSize.height
    )

    super.init(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    // AppKit defaults this to false, which prevents the panel from being
    // displayed by loginwindow after the session is locked.
    canBecomeVisibleWithoutLogin = true
    // The lock-screen widget must remain above the system lock surface while
    // its SwiftUI view limits interaction to media controls.
    level = VelnorrWindowLevel.lockScreen
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    hidesOnDeactivate = false
    isFloatingPanel = true
    becomesKeyOnlyIfNeeded = true
    isReleasedWhenClosed = false
    acceptsMouseMovedEvents = true
    ignoresMouseEvents = true

    let hostingView = NSHostingView(
      rootView: LockedMusicWidgetView(
        runtime: runtime,
        onTrackAvailabilityChange: { [weak self] hasTrack in
          self?.updateTrackAvailability(hasTrack)
        }
      )
    )
    hostingView.sizingOptions = []
    if #available(macOS 13.3, *) {
      hostingView.safeAreaRegions = []
    }
    hostingView.frame = CGRect(origin: .zero, size: frame.size)
    hostingView.autoresizingMask = [.width, .height]
    contentView = hostingView
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func close() {
    contentView = nil
    super.close()
  }

  private func updateTrackAvailability(_ hasTrack: Bool) {
    ignoresMouseEvents = !hasTrack
    alphaValue = hasTrack ? 1 : 0
    if hasTrack {
      orderFrontRegardless()
    }
  }
}
