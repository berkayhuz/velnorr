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

enum SystemBrightnessEvent: Sendable, Equatable {
  case increase
  case decrease
}

final class SystemBrightnessEventTap: @unchecked Sendable {
  private static let systemDefinedEventTypeRawValue: UInt32 = 14

  private static let auxControlSubtype: Int16 = 8

  // Some keyboards / newer macOS versions can expose
  // brightness through normal keyboard events.
  private static let brightnessUpKeyCode: Int64 = 144
  private static let brightnessDownKeyCode: Int64 = 145

  // Used to prevent handling the same physical key press twice
  // when the keyboard emits both NX_SYSDEFINED and normal key events.
  private static let auxTwinWindow: TimeInterval = 0.5
  private static let fallbackDelay: TimeInterval = 0.06

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: ((SystemBrightnessEvent) -> Void)?

  private var lastAuxTimestamp: TimeInterval = 0

  @discardableResult
  @MainActor
  func start(
    onEvent: @escaping (SystemBrightnessEvent) -> Void
  ) -> Bool {
    stop()

    guard SystemEventTapPermission.canAttemptActiveTap else { return false }

    handler = onEvent

    let mask =
      CGEventMask(
        1 << Self.systemDefinedEventTypeRawValue
      )
      | CGEventMask(
        1 << CGEventType.keyDown.rawValue
      )
      | CGEventMask(
        1 << CGEventType.keyUp.rawValue
      )

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: systemBrightnessEventTapCallback,
        userInfo: Unmanaged
          .passUnretained(self)
          .toOpaque()
      )
    else {
      handler = nil
      return false
    }

    self.tap = tap

    runLoopSource = CFMachPortCreateRunLoopSource(
      kCFAllocatorDefault,
      tap,
      0
    )

    if let runLoopSource {
      CFRunLoopAddSource(
        CFRunLoopGetMain(),
        runLoopSource,
        .commonModes
      )
    }

    CGEvent.tapEnable(
      tap: tap,
      enable: true
    )

    return true
  }

  func stop() {
    if let tap {
      CGEvent.tapEnable(
        tap: tap,
        enable: false
      )
    }

    if let runLoopSource {
      CFRunLoopRemoveSource(
        CFRunLoopGetMain(),
        runLoopSource,
        .commonModes
      )
    }

    tap = nil
    runLoopSource = nil
    handler = nil
  }

  fileprivate func handle(
    type: CGEventType,
    event: CGEvent
  ) -> Bool {

    // Event tap macOS tarafından kapatılırsa tekrar aç.
    if SystemEventTapLifecycle.wasDisabled(type) {
      if let tap {
        CGEvent.tapEnable(
          tap: tap,
          enable: true
        )
      }

      return false
    }

    // Newer keyboards can send brightness as normal key events.
    if type == .keyDown || type == .keyUp {
      return handleBrightnessKeyCode(
        type: type,
        event: event
      )
    }

    // Normal Apple media-key route.
    guard
      type.rawValue == Self.systemDefinedEventTypeRawValue,
      let systemEvent = NSEvent(cgEvent: event),
      systemEvent.subtype.rawValue
        == Self.auxControlSubtype,
      let parsed = Self.parse(
        Int64(systemEvent.data1)
      )
    else {
      return false
    }

    lastAuxTimestamp =
      ProcessInfo.processInfo.systemUptime

    // Sadece keyDown parlaklığı değiştirir.
    if parsed.isDown {
      handler?(parsed.event)
    }

    // keyDown + keyUp ikisini de consume et.
    return true
  }

  static func parse(
    _ data1: Int64
  ) -> (
    event: SystemBrightnessEvent,
    isDown: Bool
  )? {
    let keyCode =
      (data1 >> 16) & 0xFFFF

    let keyState =
      (data1 >> 8) & 0xFF

    // 0x0A = keyDown
    // 0x0B = keyUp
    guard
      keyState == 0x0A
        || keyState == 0x0B
    else {
      return nil
    }

    let brightnessEvent: SystemBrightnessEvent

    switch keyCode {
    case 2:
      brightnessEvent = .increase

    case 3:
      brightnessEvent = .decrease

    default:
      return nil
    }

    return (
      event: brightnessEvent,
      isDown: keyState == 0x0A
    )
  }

  private func handleBrightnessKeyCode(
    type: CGEventType,
    event: CGEvent
  ) -> Bool {

    let brightnessEvent: SystemBrightnessEvent

    switch event.getIntegerValueField(
      .keyboardEventKeycode
    ) {

    case Self.brightnessUpKeyCode:
      brightnessEvent = .increase

    case Self.brightnessDownKeyCode:
      brightnessEvent = .decrease

    default:
      return false
    }

    let now =
      ProcessInfo.processInfo.systemUptime

    // Bazı Apple klavyeleri aynı fiziksel tuş için hem
    // keycode hem NX_SYSDEFINED gönderebilir.
    //
    // AUX event az önce geldiyse bu normal key event
    // yalnızca consume edilir, ikinci defa parlaklık değiştirilmez.
    guard
      now - lastAuxTimestamp
        > Self.auxTwinWindow
    else {
      return true
    }

    // keyUp sadece consume edilir.
    guard type == .keyDown else {
      return true
    }

    // NX_SYSDEFINED event'in gelip gelmeyeceğini çok kısa bekle.
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.fallbackDelay
    ) { [weak self] in

      guard let self else {
        return
      }

      // Bu sırada AUX twin geldiyse işlem zaten orada yapıldı.
      guard self.lastAuxTimestamp < now else {
        return
      }

      self.handler?(brightnessEvent)
    }

    return true
  }

  deinit {
    stop()
  }
}

private func systemBrightnessEventTapCallback(
  _ proxy: CGEventTapProxy,
  _ type: CGEventType,
  _ event: CGEvent,
  _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

  guard let refcon else {
    return Unmanaged.passUnretained(event)
  }

  let eventTap =
    Unmanaged<SystemBrightnessEventTap>
      .fromOpaque(refcon)
      .takeUnretainedValue()

  if eventTap.handle(
    type: type,
    event: event
  ) {
    // Velnorr handled it.
    // Do not let macOS display its native brightness HUD.
    return nil
  }

  return Unmanaged.passUnretained(event)
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
