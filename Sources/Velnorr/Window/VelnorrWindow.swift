import AppKit
import Foundation
import SwiftUI

final class VelnorrWindow: NSWindow {
  private enum MousePollingRate {
    case idle
    case nearby
    case media

    var interval: TimeInterval {
      switch self {
      case .idle: 1.0 / 10.0
      case .nearby: 1.0 / 30.0
      case .media: 1.0 / 4.0
      }
    }

    var tolerance: TimeInterval {
      switch self {
      case .idle: 0.08
      case .nearby: 0.01
      case .media: 0.05
      }
    }
  }

  private var velnorrHitPath: CGPath = CGMutablePath()
  private var mouseMonitors: [Any] = []
  private var hasGlobalMouseMonitor = false
  private var mouseTrackingTimer: Timer?
  private var mousePollingRate: MousePollingRate?
  private var pointerInsideVelnorr = false
  private var isMediaInteractive = false
  private var isCapsLockInteractive = false
  private var isScreenLocked = false
  private var velnorrLayoutRect = CGRect.zero
  private var pillInteractionPath: CGPath?
  private let displayMode: VelnorrDisplayMode
  private let displayID: CGDirectDisplayID

  init(
    screen: NSScreen,
    configuredMode: VelnorrDisplayMode,
    isFloating: Bool = false,
    runtime: VelnorrRuntime
  ) {
    let metrics = NotchMetrics(screen: screen, configuredMode: configuredMode)
    let horizontalOffset = UserDefaults.standard.double(forKey: AppSettings.horizontalOffset)
    let verticalOffset = UserDefaults.standard.double(forKey: AppSettings.verticalOffset)
    displayMode = metrics.displayMode
    displayID = metrics.displayID
    let floatingTopInset: CGFloat = isFloating ? 2 : 0
    let frame = CGRect(
      x: screen.frame.midX - metrics.windowWidth / 2 + horizontalOffset,
      y: screen.frame.maxY - metrics.windowHeight - floatingTopInset + verticalOffset,
      width: metrics.windowWidth,
      height: metrics.windowHeight
    )

    super.init(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    acceptsMouseMovedEvents = true
    ignoresMouseEvents = false
    isReleasedWhenClosed = false

    updateHitRegion(
      rect: CGRect(
        x: 0,
        y: 0,
        width: metrics.collapsedWidth(hasTrack: false),
        height: NotchMetrics.velnorrHeight
      ),
      radius: metrics.topRadius,
      bottomRadius: NotchMetrics.collapsedBottomRadius
    )

    let hostingView = PassthroughHostingView(
      rootView: VelnorrShellView(
        metrics: metrics,
        runtime: runtime,
        onLayoutChange: { [weak self] rect, radius, bottomRadius in
          self?.updateHitRegion(
            rect: rect,
            radius: radius,
            bottomRadius: bottomRadius
          )
        },
        onMediaExpandedChange: { [weak self] expanded in
          guard let self else { return }
          self.isMediaInteractive = expanded
          self.refreshMouseState()
        },
        onCapsLockVisibilityChange: { [weak self] visible in
          guard let self else { return }
          self.isCapsLockInteractive = visible
          self.refreshMouseState()
        },
        onScreenLockChange: { [weak self] locked in
          self?.updateScreenLock(locked)
        }
      )
    )
    // The window is driven by our explicit geometry callback, not by the
    // hosting view's intrinsic-size negotiation. Disabling the latter is
    // important on current macOS: SwiftUI otherwise asks AppKit to update
    // the window's content-size constraints from inside its own display
    // cycle, which can raise `_postWindowNeedsUpdateConstraints`.
    hostingView.sizingOptions = []
    // The velnorr owns its geometry and does not use the window's safe-area
    // insets. Opting out avoids safe-area corner invalidations whenever
    // this borderless window is repositioned.
    if #available(macOS 13.3, *) {
      hostingView.safeAreaRegions = []
    }
    hostingView.frame = CGRect(origin: .zero, size: frame.size)
    hostingView.autoresizingMask = [.width, .height]
    contentView = hostingView
    installMousePassthroughMonitoring()
    updateMousePassthrough()
    updateScreenLock(runtime.screenLock.isLocked)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  override func sendEvent(_ event: NSEvent) {
    guard !isScreenLocked else {
      super.sendEvent(event)
      return
    }
    let location = event.locationInWindow
    let centerHalfWidth: CGFloat = displayMode == .pill ? 24 : 60
    if event.type == .leftMouseDown,
      abs(location.x - frame.width / 2) <= centerHalfWidth,
      location.y >= frame.height - 45, location.y <= frame.height
    {
      NotificationCenter.default.post(
        name: .velnorrCenterTapped,
        object: nil,
        userInfo: ["displayID": displayID]
      )
    }
    super.sendEvent(event)
  }

  override func rightMouseDown(with event: NSEvent) {
    guard !isScreenLocked else { return }
    let language = AppLanguage.selected
    let menu = NSMenu(title: "Velnorr")
    menu.autoenablesItems = false

    let settingsItem = NSMenuItem(
      title: language.localized("Settings"),
      action: #selector(requestSettings(_:)),
      keyEquivalent: ","
    )
    settingsItem.image = NSImage(
      systemSymbolName: "gearshape",
      accessibilityDescription: language.localized("Settings")
    )
    settingsItem.keyEquivalentModifierMask = [.command]
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: language.localized("Quit Velnorr"),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = NSApp
    menu.addItem(quitItem)

    let screenPoint = convertPoint(toScreen: event.locationInWindow)
    menu.popUp(
      positioning: nil,
      at: screenPoint,
      in: nil
    )
  }

  @objc private func requestSettings(_ sender: Any?) {
    NotificationCenter.default.post(name: .velnorrOpenSettings, object: nil)
  }

  override func close() {
    stopMousePolling()
    for monitor in mouseMonitors {
      NSEvent.removeMonitor(monitor)
    }
    mouseMonitors.removeAll()
    // A closed borderless window can otherwise keep its SwiftUI transition
    // layer alive for one more display cycle, leaving a stray artwork tile
    // at the screen origin.
    contentView = nil
    super.close()
  }

  private func updateHitRegion(
    rect: CGRect,
    radius: CGFloat,
    bottomRadius: CGFloat
  ) {
    velnorrLayoutRect = rect
    let hitRect = CGRect(
      x: (NotchMetrics.canvasWidth - rect.width) / 2 + rect.minX,
      y: 0,
      width: rect.width,
      height: rect.height
    )

    velnorrHitPath = VelnorrShapePath.make(
      in: hitRect,
      topRadius: radius,
      bottomRadius: bottomRadius,
      isPill: displayMode == .pill
    )
    pillInteractionPath = displayMode == .pill
      ? CGPath(
        roundedRect: CGRect(
          x: (NotchMetrics.canvasWidth - NotchMetrics.nowPlayingWidth) / 2,
          y: 0,
          width: NotchMetrics.nowPlayingWidth,
          height: NotchMetrics.nowPlayingHeight
        ),
        cornerWidth: NotchMetrics.nowPlayingRadius,
        cornerHeight: NotchMetrics.nowPlayingRadius,
        transform: nil
      )
      : nil

    updateMousePassthrough()
  }

  private func installMousePassthroughMonitoring() {
    let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: events,
      handler: { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refreshMouseState()
        }
      }
    ) {
      mouseMonitors.append(monitor)
      hasGlobalMouseMonitor = true
    }

    if let monitor = NSEvent.addLocalMonitorForEvents(
      matching: events,
      handler: { [weak self] event in
        self?.refreshMouseState()
        return event
      }
    ) {
      mouseMonitors.append(monitor)
    }

    // Global mouse-moved monitors can be unavailable without Accessibility
    // permission. Poll only in that fallback case.
    updateMousePolling()
  }

  private func refreshMouseState() {
    let signpost = VelnorrPerformance.begin(.windowMouseRefresh)
    defer { VelnorrPerformance.end(.windowMouseRefresh, signpost) }

    updateMousePassthrough()
    updateMousePolling()
  }

  private func updateMousePolling() {
    guard !isScreenLocked else {
      stopMousePolling()
      return
    }

    guard !hasGlobalMouseMonitor else {
      stopMousePolling()
      return
    }

    let desiredRate: MousePollingRate
    if isMediaInteractive {
      // Expanded media must continue to observe pointer exit when the global
      // monitor is unavailable (for example without Accessibility access).
      desiredRate = .media
    } else {
      let proximityFrame = frame.insetBy(dx: -80, dy: -80)
      desiredRate = proximityFrame.contains(NSEvent.mouseLocation)
        ? .nearby
        : .idle
    }

    guard desiredRate != mousePollingRate || mouseTrackingTimer == nil else { return }

    stopMousePolling()

    let timer = Timer(
      timeInterval: desiredRate.interval,
      target: self,
      selector: #selector(mousePollingTimerDidFire(_:)),
      userInfo: nil,
      repeats: true
    )
    timer.tolerance = desiredRate.tolerance
    RunLoop.main.add(timer, forMode: .common)
    mouseTrackingTimer = timer
    mousePollingRate = desiredRate
  }

  private func stopMousePolling() {
    mouseTrackingTimer?.invalidate()
    mouseTrackingTimer = nil
    mousePollingRate = nil
  }

  @objc private func mousePollingTimerDidFire(_ timer: Timer) {
    refreshMouseState()
  }

  private func updateMousePassthrough() {
    guard !isScreenLocked else {
      ignoresMouseEvents = true
      updatePointerInsideState(false)
      stopMousePolling()
      return
    }

    let screenPoint = NSEvent.mouseLocation
    let insideSurface = containsVelnorr(atScreenPoint: screenPoint)
      || (displayMode == .pill && containsPillInteractionRegion(atScreenPoint: screenPoint))
    let insideCapsLock = isCapsLockInteractive
      && containsCapsLockInteractionRegion(atScreenPoint: screenPoint)
    let inside = insideSurface || insideCapsLock

    let shouldIgnoreMouseEvents = VelnorrMousePolicy.ignoresMouseEvents(
      isMediaExpanded: isMediaInteractive,
      pointerInsideShape: inside
    )
    if ignoresMouseEvents != shouldIgnoreMouseEvents {
      ignoresMouseEvents = shouldIgnoreMouseEvents
    }

    if isMediaInteractive {
      updatePointerInsideState(insideSurface)
      return
    }

    updatePointerInsideState(insideSurface)
  }

  private func updateScreenLock(_ locked: Bool) {
    isScreenLocked = locked
    level = locked ? .screenSaver : .statusBar
    if locked {
      stopMousePolling()
      ignoresMouseEvents = true
      updatePointerInsideState(false)
    } else {
      refreshMouseState()
    }
  }

  private func containsCapsLockInteractionRegion(atScreenPoint screenPoint: NSPoint) -> Bool {
    let diameter = CapsLockHUDMetrics.diameter(
      from: UserDefaults.standard.double(forKey: AppSettings.capsLockHUDSize)
    )
    let restingGap = CapsLockHUDMetrics.restingGap
    guard velnorrLayoutRect.maxY + restingGap + diameter <= frame.height else { return false }

    let windowPoint = convertPoint(fromScreen: screenPoint)
    let topLeftPoint = CGPoint(x: windowPoint.x, y: frame.height - windowPoint.y)
    let region = CGRect(
      x: (NotchMetrics.canvasWidth - diameter) / 2,
      y: velnorrLayoutRect.maxY + restingGap,
      width: diameter,
      height: diameter
    )
    return region.contains(topLeftPoint)
  }

  private func updatePointerInsideState(_ inside: Bool) {
    guard inside != pointerInsideVelnorr else { return }
    pointerInsideVelnorr = inside
    NotificationCenter.default.post(
      name: .velnorrPointerInsideChanged,
      object: nil,
      userInfo: ["inside": inside, "displayID": displayID]
    )
  }

  func containsVelnorr(atScreenPoint screenPoint: NSPoint) -> Bool {
    let windowPoint = convertPoint(fromScreen: screenPoint)
    return containsVelnorr(atWindowPoint: windowPoint)
  }

  private func containsVelnorr(atWindowPoint windowPoint: NSPoint) -> Bool {
    let topLeftPoint = CGPoint(x: windowPoint.x, y: frame.height - windowPoint.y)
    return velnorrHitPath.contains(topLeftPoint)
  }

  private func containsPillInteractionRegion(atScreenPoint screenPoint: NSPoint) -> Bool {
    guard let pillInteractionPath else { return false }
    let windowPoint = convertPoint(fromScreen: screenPoint)
    let topLeftPoint = CGPoint(x: windowPoint.x, y: frame.height - windowPoint.y)
    return pillInteractionPath.contains(topLeftPoint)
  }
}

final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

}
