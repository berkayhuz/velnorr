import AppKit
import SwiftUI

@MainActor
final class VelnorrLockScreenWindow: NSPanel {
  private var presentationState = VelnorrLockScreenPresentationState()
  private let presentationModel = LockedMusicWidgetPresentationModel()

  init(
    screen: NSScreen,
    runtime: VelnorrRuntime
  ) {
    let widgetFrame = VelnorrLockScreenLayout.widgetFrame(
      for: screen.frame
    )

    let animationPadding: CGFloat = 40

    let frame = widgetFrame.insetBy(
      dx: -animationPadding,
      dy: -animationPadding
    )

    super.init(
      contentRect: frame,
      styleMask: [
        .borderless,
        .nonactivatingPanel,
      ],
      backing: .buffered,
      defer: false
    )

    // MARK: - Window Configuration

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false

    // Allow loginwindow to display the panel while the session is locked.
    canBecomeVisibleWithoutLogin = true

    level = VelnorrWindowLevel.lockScreen

    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle,
    ]

    hidesOnDeactivate = false
    isFloatingPanel = true
    becomesKeyOnlyIfNeeded = true
    isReleasedWhenClosed = false
    acceptsMouseMovedEvents = true

    // Keep the panel hidden until loginwindow finishes its transition.
    alphaValue = 0
    ignoresMouseEvents = true

    // MARK: - SwiftUI Content

    let hostingView = NSHostingView(
      rootView: LockedMusicWidgetView(
        runtime: runtime,
        presentationModel: presentationModel,
        onTrackAvailabilityChange: { [weak self] hasTrack in
          self?.updateTrackAvailability(hasTrack)
        }
      )
    )

    hostingView.sizingOptions = []

    if #available(macOS 13.3, *) {
      hostingView.safeAreaRegions = []
    }

    hostingView.frame = CGRect(
      origin: .zero,
      size: frame.size
    )

    hostingView.autoresizingMask = [
      .width,
      .height,
    ]

    contentView = hostingView
  }

  // MARK: - Window Capabilities

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }

  // MARK: - Track Availability

  private func updateTrackAvailability(
    _ hasTrack: Bool
  ) {
    let shouldPresentBubble = presentationState.updateTrackAvailability(hasTrack)

    guard presentationState.isReady else {
      alphaValue = 0
      ignoresMouseEvents = true
      return
    }

    ignoresMouseEvents = !hasTrack
    alphaValue = hasTrack ? 1 : 0

    if hasTrack {
      orderFrontRegardless()
      displayIfNeeded()
    }

    if shouldPresentBubble {
      presentationModel.present()
    }
  }

  // MARK: - Lock Screen Presentation

  func presentAfterLockTransition() {
    let shouldPresentBubble = presentationState.markReady()

    guard presentationState.hasTrack else {
      alphaValue = 0
      ignoresMouseEvents = true
      return
    }

    ignoresMouseEvents = false
    alphaValue = 1
    orderFrontRegardless()
    displayIfNeeded()

    if shouldPresentBubble {
      presentationModel.present()
    }
  }

  // MARK: - Close

  override func close() {
    presentationState = VelnorrLockScreenPresentationState()

    contentView = nil

    super.close()
  }
}

struct VelnorrLockScreenPresentationState {
  private(set) var isReady = false
  private(set) var hasTrack = false
  private var hasPresentedBubble = false

  mutating func updateTrackAvailability(_ hasTrack: Bool) -> Bool {
    self.hasTrack = hasTrack
    return beginPresentationIfPossible()
  }

  mutating func markReady() -> Bool {
    isReady = true
    return beginPresentationIfPossible()
  }

  private mutating func beginPresentationIfPossible() -> Bool {
    guard isReady, hasTrack, !hasPresentedBubble else { return false }
    hasPresentedBubble = true
    return true
  }
}
