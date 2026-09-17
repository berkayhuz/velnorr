import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class CapsLockStore: ObservableObject {
  @Published private(set) var isEnabled = false
  @Published private(set) var isVisible = false

  private let eventTap = CapsLockEventTap()
  private var hideTask: Task<Void, Never>?
  private var eventTapRetryTask: Task<Void, Never>?

  func start() {
    isEnabled = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    startEventTapWithRetry()
  }

  func stop() {
    eventTap.stop()
    eventTapRetryTask?.cancel()
    eventTapRetryTask = nil
    hideTask?.cancel()
    hideTask = nil
    isVisible = false
  }

  func showPreview() {
    show(enabled: !isEnabled)
  }

  private func show(enabled: Bool) {
    isEnabled = enabled
    isVisible = true
    hideTask?.cancel()
    let duration = hudDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(duration * 1_000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private var hudDisplayDuration: Double {
    let value = UserDefaults.standard.double(forKey: AppSettings.capsLockDisplayDuration)
    return value > 0 ? min(10, max(0.5, value)) : 1.6
  }

  private func startEventTapWithRetry() {
    eventTapRetryTask?.cancel()
    eventTapRetryTask = nil

    let install: @MainActor () -> Bool = { [weak self] in
      guard let self else { return false }
      return self.eventTap.start { [weak self] enabled in
        Task { @MainActor [weak self] in
          self?.show(enabled: enabled)
        }
      }
    }

    guard !install() else { return }

    eventTapRetryTask = Task { @MainActor [weak self] in
      for _ in 0..<30 {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, let self else { return }
        if install() {
          self.eventTapRetryTask = nil
          return
        }
      }
      self?.eventTapRetryTask = nil
    }
  }
}

private final class CapsLockEventTap: @unchecked Sendable {
  private static let capsLockKeyCode: Int64 = 57
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: ((Bool) -> Void)?

  @discardableResult
  @MainActor
  func start(onChange: @escaping (Bool) -> Void) -> Bool {
    stop()
    guard SystemEventTapPermission.isGranted else { return false }

    handler = onChange
    let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: capsLockEventTapCallback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else { return false }

    self.tap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  func stop() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    tap = nil
    runLoopSource = nil
    handler = nil
  }

  fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return false
    }
    guard type == .flagsChanged,
      event.getIntegerValueField(.keyboardEventKeycode) == Self.capsLockKeyCode
    else { return false }

    handler?(event.flags.contains(.maskAlphaShift))
    return true
  }

  deinit { stop() }
}

private func capsLockEventTapCallback(
  _ proxy: CGEventTapProxy,
  _ type: CGEventType,
  _ event: CGEvent,
  _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let eventTap = Unmanaged<CapsLockEventTap>.fromOpaque(refcon).takeUnretainedValue()
  if eventTap.handle(type: type, event: event) {
    // Caps Lock is toggled by HID before this session event arrives. Dropping
    // the downstream notification keeps the lock state while preventing the
    // standard macOS HUD and downstream event-based keyboard utilities from
    // drawing their overlays.
    return nil
  }
  return Unmanaged.passUnretained(event)
}
