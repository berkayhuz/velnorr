import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class VelnorrWindow: NSWindow, NSDraggingDestination {
  private enum MousePollingRate {
    case idle
    case nearby
    case media

    var interval: TimeInterval {
      switch self {
      // This timer exists only when Accessibility prevents the global mouse
      // monitor from being installed. Keep the no-pointer path inexpensive;
      // local events take over immediately when the pointer approaches.
      case .idle: VelnorrMousePolicy.fallbackIdlePollingInterval
      case .nearby: VelnorrMousePolicy.fallbackNearbyPollingInterval
      case .media: VelnorrMousePolicy.fallbackMediaPollingInterval
      }
    }

    var tolerance: TimeInterval {
      switch self {
      case .idle: 0.1
      case .nearby: 0.025
      case .media: 0.06
      }
    }
  }

  private var velnorrHitPath: CGPath = CGMutablePath()
  private var mouseMonitors: [Any] = []
  private var shelfDragMonitors: [Any] = []
  private var hasGlobalMouseMonitor = false
  private var mouseTrackingTimer: Timer?
  private var mousePollingRate: MousePollingRate?
  private var pointerInsideVelnorr = false
  private var isMediaInteractive = false
  private var isLevelBarInteractive = false
  private var isCapsLockInteractive = false
  private var isScreenLocked = false
  private var isShelfDragTargeted = false
  private var shelfDragStartChangeCount = -1
  private var isContentDragging = false
  private var velnorrLayoutRect = CGRect.zero
  private var pillInteractionPath: CGPath?
  private let displayMode: VelnorrDisplayMode
  private let displayID: CGDirectDisplayID
  private let runtime: VelnorrRuntime

  init(
    screen: NSScreen,
    configuredMode: VelnorrDisplayMode,
    isFloating: Bool = false,
    heightConfiguration: VelnorrNotchHeightConfiguration = .default,
    runtime: VelnorrRuntime
  ) {
    self.runtime = runtime
    let metrics = NotchMetrics(
      screen: screen,
      configuredMode: configuredMode,
      heightConfiguration: heightConfiguration
    )
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
        height: metrics.collapsedHeight
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
        onLevelBarInteractionChange: { [weak self] interacting in
          guard let self else { return }
          self.isLevelBarInteractive = interacting
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
    registerForDraggedTypes([.fileURL, .URL, .string])
    installMousePassthroughMonitoring()
    installShelfDragMonitoring()
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
    if event.type == .leftMouseDown,
      VelnorrMousePolicy.shouldToggleCenter(
        displayMode: displayMode,
        isExpanded: isMediaInteractive,
        isLevelBarInteracting: isLevelBarInteractive,
        location: location,
        frameSize: frame.size
      )
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
    for panel in VelnorrUtilityPanel.allCases where panel != .media {
      let item = NSMenuItem(
        title: language.localized(panel.titleKey),
        action: #selector(requestUtilityPanel(_:)),
        keyEquivalent: ""
      )
      item.image = NSImage(systemSymbolName: panel.symbolName, accessibilityDescription: nil)
      item.representedObject = panel.rawValue
      item.target = self
      menu.addItem(item)
    }

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

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard !isScreenLocked, !dragProviders(from: sender.draggingPasteboard).isEmpty else {
      return []
    }
    if !isShelfDragTargeted {
      isShelfDragTargeted = true
      NotificationCenter.default.post(
        name: .velnorrOpenUtilityPanel,
        object: nil,
        userInfo: ["panel": VelnorrUtilityPanel.shelf.rawValue, "displayID": displayID]
      )
    }
    return .copy
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    isShelfDragTargeted ? .copy : draggingEntered(sender)
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    isShelfDragTargeted = false
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let providers = dragProviders(from: sender.draggingPasteboard)
    isShelfDragTargeted = false
    guard !providers.isEmpty else { return false }
    runtime.shelf.acceptDrop(providers)
    return true
  }

  private func installShelfDragMonitoring() {
    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: .leftMouseDown,
      handler: { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.beginShelfDrag()
        }
      }
    ) {
      shelfDragMonitors.append(monitor)
    }

    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: .leftMouseDragged,
      handler: { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.updateShelfDrag()
        }
      }
    ) {
      shelfDragMonitors.append(monitor)
    }

    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: .leftMouseUp,
      handler: { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.finishShelfDrag()
        }
      }
    ) {
      shelfDragMonitors.append(monitor)
    }
  }

  private func stopShelfDragMonitoring() {
    for monitor in shelfDragMonitors {
      NSEvent.removeMonitor(monitor)
    }
    shelfDragMonitors.removeAll()
    shelfDragStartChangeCount = -1
    isContentDragging = false
  }

  private func beginShelfDrag() {
    shelfDragStartChangeCount = NSPasteboard(name: .drag).changeCount
    isContentDragging = false
    isShelfDragTargeted = false
  }

  private func updateShelfDrag() {
    guard !isScreenLocked, shelfDragStartChangeCount >= 0 else { return }

    let pasteboard = NSPasteboard(name: .drag)
    guard pasteboard.changeCount != shelfDragStartChangeCount,
      hasSupportedDragContent(in: pasteboard)
    else { return }
    isContentDragging = true

    let screenPoint = NSEvent.mouseLocation
    let insideTarget = containsVelnorr(atScreenPoint: screenPoint)
      || (displayMode == .pill && containsPillInteractionRegion(atScreenPoint: screenPoint))
    if insideTarget, !isShelfDragTargeted {
      isShelfDragTargeted = true
      NotificationCenter.default.post(
        name: .velnorrOpenUtilityPanel,
        object: nil,
        userInfo: ["panel": VelnorrUtilityPanel.shelf.rawValue, "displayID": displayID]
      )
    } else if !insideTarget {
      isShelfDragTargeted = false
    }
  }

  private func finishShelfDrag() {
    defer {
      shelfDragStartChangeCount = -1
      isContentDragging = false
      isShelfDragTargeted = false
    }

    guard isContentDragging, isShelfDragTargeted else { return }
    let pasteboard = NSPasteboard(name: .drag)
    let providers = dragProviders(from: pasteboard)
    guard !providers.isEmpty else { return }
    runtime.shelf.acceptDrop(providers)
  }

  private func hasSupportedDragContent(in pasteboard: NSPasteboard) -> Bool {
    let supportedTypes: Set<NSPasteboard.PasteboardType> = [
      .fileURL,
      .URL,
      .string,
    ]
    return pasteboard.types?.contains(where: supportedTypes.contains) ?? false
  }

  @objc private func requestSettings(_ sender: Any?) {
    NotificationCenter.default.post(name: .velnorrOpenSettings, object: nil)
  }

  @objc private func requestUtilityPanel(_ sender: NSMenuItem) {
    guard let panel = sender.representedObject as? String else { return }
    NotificationCenter.default.post(
      name: .velnorrOpenUtilityPanel,
      object: nil,
      userInfo: ["panel": panel, "displayID": displayID]
    )
  }

  private func dragProviders(from pasteboard: NSPasteboard) -> [NSItemProvider] {
    var providers: [NSItemProvider] = []

    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [NSURL] {
      providers.append(contentsOf: urls.map { NSItemProvider(object: $0) })
    }

    if providers.isEmpty, let urlValue = pasteboard.string(forType: .URL),
      let url = URL(string: urlValue) {
      providers.append(
        NSItemProvider(
          item: url.absoluteString as NSString,
          typeIdentifier: UTType.url.identifier
        )
      )
    }

    if providers.isEmpty, let text = pasteboard.string(forType: .string) {
      providers.append(
        NSItemProvider(
          item: text as NSString,
          typeIdentifier: UTType.utf8PlainText.identifier
        )
      )
    }

    return providers
  }

  override func close() {
    isShelfDragTargeted = false
    stopShelfDragMonitoring()
    unregisterDraggedTypes()
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
    if isMediaInteractive || isLevelBarInteractive {
      // Keep tracking pointer exit during media or level-bar interaction when
      // the global monitor is unavailable (for example without Accessibility
      // access).
      desiredRate = .media
    } else {
      // The window is a fixed transparent canvas, so using its full frame
      // would keep fallback polling active over the utility's empty area.
      // Track proximity to the currently visible surface instead.
      let proximityFrame = visibleSurfaceFrame.insetBy(dx: -80, dy: -80)
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

  private var visibleSurfaceFrame: CGRect {
    let hitRect = CGRect(
      x: (NotchMetrics.canvasWidth - velnorrLayoutRect.width) / 2 + velnorrLayoutRect.minX,
      y: 0,
      width: velnorrLayoutRect.width,
      height: velnorrLayoutRect.height
    )
    return CGRect(
      x: frame.minX + hitRect.minX,
      y: frame.maxY - hitRect.maxY,
      width: hitRect.width,
      height: hitRect.height
    )
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
      isLevelBarInteracting: isLevelBarInteractive,
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
    if locked {
      shelfDragStartChangeCount = -1
      isContentDragging = false
      isShelfDragTargeted = false
      canBecomeVisibleWithoutLogin = true
      level = VelnorrWindowLevel.lockScreen
      stopMousePolling()
      ignoresMouseEvents = true
      updatePointerInsideState(false)
    } else {
      canBecomeVisibleWithoutLogin = false
      level = .statusBar
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
