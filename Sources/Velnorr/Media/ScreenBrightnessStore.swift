import AppKit
@preconcurrency import ApplicationServices
import Combine
import CoreGraphics
import Darwin
import Foundation

@MainActor
final class ScreenBrightnessStore: ObservableObject {
  @Published private(set) var brightness = 0.5
  @Published private(set) var isVisible = false
  @Published private(set) var eventSequence = 0
  private let eventTap = SystemBrightnessEventTap()
  private let displayController = DisplayBrightnessController()
  private var hideTask: Task<Void, Never>?
  private var eventTapRetryTask: Task<Void, Never>?
  private var brightnessObserver: NSObjectProtocol?
  private var isInteractionActive = false

  func start() {
    installBrightnessObserverIfNeeded()
    brightness = displayController.read() ?? brightness
    startEventTapWithRetry()
  }

  private func installBrightnessObserverIfNeeded() {
    guard brightnessObserver == nil else { return }
    brightnessObserver = NotificationCenter.default.addObserver(
      forName: .velnorrBrightnessChanged,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let value = notification.userInfo?["brightness"] as? Double else { return }
      Task { @MainActor [weak self] in
        self?.receive(brightness: value)
      }
    }
  }

  func stop() {
    eventTap.stop()
    eventTapRetryTask?.cancel()
    eventTapRetryTask = nil
    if let brightnessObserver {
      NotificationCenter.default.removeObserver(brightnessObserver)
      self.brightnessObserver = nil
    }
    hideTask?.cancel()
    hideTask = nil
    isVisible = false
    isInteractionActive = false
  }

  func showPreview() {
    brightness = 0.65
    show(brightness: brightness)
  }

  func setBrightnessFromHUD(_ value: Double) {
    brightness = min(1, max(0, value))
    displayController.write(brightness)
    NotificationCenter.default.post(
      name: .velnorrBrightnessChanged,
      object: nil,
      userInfo: ["brightness": brightness]
    )
    show(brightness: brightness)
  }

  func setInteractionActive(_ active: Bool) {
    guard active != isInteractionActive else { return }
    isInteractionActive = active

    if active {
      isVisible = true
      hideTask?.cancel()
      hideTask = nil
    } else {
      scheduleHide()
    }
  }

  private func apply(_ event: SystemBrightnessEvent) {
    setBrightnessFromHUD(
      brightness + (event == .increase ? 0.0625 : -0.0625)
    )
  }

  private func receive(brightness: Double) {
    self.brightness = min(1, max(0, brightness))
    show(brightness: self.brightness)
  }

  private func show(brightness: Double) {
    isVisible = true
    eventSequence += 1
    scheduleHide()
  }

  private func scheduleHide() {
    hideTask?.cancel()
    hideTask = nil
    guard !isInteractionActive else { return }

    let displayDuration = hudDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(displayDuration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private func startEventTapWithRetry() {
    eventTapRetryTask?.cancel()
    eventTapRetryTask = nil

    let install: @MainActor () -> Bool = { [weak self] in
      guard let self else { return false }
      return self.eventTap.start { [weak self] event in
        Task { @MainActor [weak self] in self?.apply(event) }
      }
    }

    guard !install() else { return }

    // Permissions can be granted in System Settings while Velnorr remains
    // running. Retry briefly so the user does not need to quit and relaunch.
    eventTapRetryTask = Task { @MainActor [weak self] in
      for _ in 0..<30 {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        guard let self else { return }
        if install() {
          self.eventTapRetryTask = nil
          return
        }
      }
      self?.eventTapRetryTask = nil
    }
  }

  private var hudDisplayDuration: Double {
    let value = UserDefaults.standard.double(forKey: "brightnessDisplayDuration")
    return value > 0 ? min(10, max(0.5, value)) : 1.6
  }
}

private enum SystemBrightnessEvent: Sendable { case increase, decrease }

private final class SystemBrightnessEventTap: @unchecked Sendable {
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: ((SystemBrightnessEvent) -> Void)?

  @discardableResult
  @MainActor
  func start(onEvent: @escaping (SystemBrightnessEvent) -> Void) -> Bool {
    stop()
    guard SystemEventTapPermission.canAttemptActiveTap else { return false }
    handler = onEvent
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: CGEventMask(1 << 14), callback: systemBrightnessEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else { return false }
    self.tap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  func stop() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    tap = nil
    runLoopSource = nil
    handler = nil
  }

  fileprivate func handle(_ event: SystemBrightnessEvent) { handler?(event) }
  fileprivate func reenableAfterSystemDisable() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
  }
  fileprivate static func parse(_ data1: Int64) -> SystemBrightnessEvent? {
    guard ((data1 >> 8) & 0xFF) == 0x0A else { return nil }
    switch (data1 >> 16) & 0xFFFF {
    case 2: return .increase
    case 3: return .decrease
    default: return nil
    }
  }
}

private func systemBrightnessEventTapCallback(
  _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
  _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<SystemBrightnessEventTap>.fromOpaque(refcon).takeUnretainedValue()
  if SystemEventTapLifecycle.wasDisabled(type) {
    tap.reenableAfterSystemDisable()
    return Unmanaged.passUnretained(event)
  }
  guard type.rawValue == 14, let systemEvent = NSEvent(cgEvent: event),
    let brightnessEvent = SystemBrightnessEventTap.parse(Int64(systemEvent.data1))
  else { return Unmanaged.passUnretained(event) }
  tap.handle(brightnessEvent)
  // Consume the event so macOS does not draw its native brightness HUD.
  return nil
}

/// DisplayServices is a private macOS API. It is used only to preserve the
/// actual brightness change after consuming the keyboard event above.
private final class DisplayBrightnessController {
  private typealias GetBrightness =
    @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
  private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
  private let handle: UnsafeMutableRawPointer?
  private let getBrightness: GetBrightness?
  private let setBrightness: SetBrightness?

  init() {
    handle = dlopen(
      "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
      RTLD_LAZY
    )
    getBrightness = handle.flatMap {
      unsafeBitCast(dlsym($0, "DisplayServicesGetBrightness"), to: GetBrightness?.self)
    }
    setBrightness = handle.flatMap {
      unsafeBitCast(dlsym($0, "DisplayServicesSetBrightness"), to: SetBrightness?.self)
    }
  }

  func read() -> Double? {
    guard let getBrightness else { return nil }
    var value: Float = 0.5
    guard getBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
    return Double(min(1, max(0, value)))
  }

  func write(_ value: Double) {
    _ = setBrightness?(CGMainDisplayID(), Float(min(1, max(0, value))))
  }

  deinit {
    if let handle { dlclose(handle) }
  }
}
