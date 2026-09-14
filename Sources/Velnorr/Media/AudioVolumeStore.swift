import AppKit
@preconcurrency import ApplicationServices
import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioVolumeStore: ObservableObject {
  @Published private(set) var volume: Double = 0
  @Published private(set) var isVisible = false

  private let monitor = AudioOutputVolumeMonitor()
  private let eventTap = SystemVolumeEventTap()
  private var hideTask: Task<Void, Never>?
  private var hasReceivedInitialValue = false

  func start() {
    monitor.start { [weak self] value in
      Task { @MainActor [weak self] in
        self?.volumeDidChange(value)
      }
    }
    eventTap.start { [weak self] event in
      Task { @MainActor [weak self] in
        self?.apply(event)
      }
    }
  }

  func stop() {
    monitor.stop()
    eventTap.stop()
    hideTask?.cancel()
    hideTask = nil
    isVisible = false
    hasReceivedInitialValue = false
  }

  func showPreview() {
    volume = 0.65
    isVisible = true
    hideTask?.cancel()
    let duration = hudDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private func volumeDidChange(_ value: Float) {
    let clampedValue = min(1, max(0, Double(value)))
    volume = clampedValue

    // The first read establishes the current level without flashing a HUD
    // when the velnorr appears.
    guard hasReceivedInitialValue else {
      hasReceivedInitialValue = true
      return
    }

    isVisible = true
    hideTask?.cancel()
    let displayDuration = hudDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(displayDuration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private var hudDisplayDuration: Double {
    let value = UserDefaults.standard.double(forKey: "volumeDisplayDuration")
    return value > 0 ? min(10, max(0.5, value)) : 1.6
  }

  private func apply(_ event: SystemVolumeEvent) {
    let currentVolume = monitor.readCurrentVolume()
    let nextVolume: Float32
    switch event {
    case .increase:
      nextVolume = min(1, currentVolume + 0.0625)
    case .decrease:
      nextVolume = max(0, currentVolume - 0.0625)
    case .mute:
      nextVolume = currentVolume > 0.001 ? 0 : 0.5
    }
    let appliedVolume = monitor.setVolume(nextVolume)
    volumeDidChange(appliedVolume)
  }
}

private final class AudioOutputVolumeMonitor {
  private var deviceID = AudioDeviceID(kAudioObjectUnknown)
  private var volumeAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyVolumeScalar,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )
  private var defaultDeviceAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  private var listener: AudioObjectPropertyListenerBlock?
  private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

  func start(onChange: @escaping (Float32) -> Void) {
    stop()

    let defaultDeviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.bindToDefaultOutput(onChange: onChange)
    }
    self.defaultDeviceListener = defaultDeviceListener
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &defaultDeviceAddress,
      DispatchQueue.main,
      defaultDeviceListener
    )
    bindToDefaultOutput(onChange: onChange)
  }

  private func bindToDefaultOutput(onChange: @escaping (Float32) -> Void) {
    removeVolumeListener()
    deviceID = defaultOutputDevice()
    guard deviceID != kAudioObjectUnknown else { return }

    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      guard let self else { return }
      let value = self.readVolume()
      onChange(value)
    }
    self.listener = listener
    AudioObjectAddPropertyListenerBlock(
      deviceID,
      &volumeAddress,
      DispatchQueue.main,
      listener
    )
    onChange(readVolume())
  }

  func stop() {
    removeVolumeListener()
    if let defaultDeviceListener {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultDeviceAddress,
        DispatchQueue.main,
        defaultDeviceListener
      )
    }
    self.defaultDeviceListener = nil
  }

  private func removeVolumeListener() {
    guard let registeredListener = listener, deviceID != kAudioObjectUnknown else {
      self.listener = nil
      deviceID = kAudioObjectUnknown
      return
    }
    AudioObjectRemovePropertyListenerBlock(
      deviceID,
      &volumeAddress,
      DispatchQueue.main,
      registeredListener
    )
    self.listener = nil
    deviceID = kAudioObjectUnknown
  }

  private func defaultOutputDevice() -> AudioDeviceID {
    var deviceID = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )
    return status == noErr ? deviceID : kAudioObjectUnknown
  }

  private func readVolume() -> Float32 {
    var value: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectGetPropertyData(
      deviceID,
      &volumeAddress,
      0,
      nil,
      &size,
      &value
    )
    return status == noErr ? value : 0
  }

  func readCurrentVolume() -> Float32 {
    readVolume()
  }

  @discardableResult
  func setVolume(_ value: Float32) -> Float32 {
    guard deviceID != kAudioObjectUnknown else { return value }
    var nextValue = min(1, max(0, value))
    let size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectSetPropertyData(
      deviceID,
      &volumeAddress,
      0,
      nil,
      size,
      &nextValue
    )
    return status == noErr ? nextValue : readVolume()
  }

  deinit {
    stop()
  }
}

private enum SystemVolumeEvent: Sendable {
  case increase
  case decrease
  case mute
}

private final class SystemVolumeEventTap: @unchecked Sendable {
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: ((SystemVolumeEvent) -> Void)?

  func start(onEvent: @escaping (SystemVolumeEvent) -> Void) {
    stop()
    let accessibilityPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let accessibilityOptions = [accessibilityPromptKey: true] as CFDictionary
    guard AXIsProcessTrustedWithOptions(accessibilityOptions) else { return }
    guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else { return }

    // `systemDefined` is not exposed by the Swift CoreGraphics overlay on
    // every SDK, but its Quartz event type is stable at raw value 14.
    let mask = CGEventMask(1 << 14)
    handler = onEvent
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: systemVolumeEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else { return }

    self.tap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  func stop() {
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    runLoopSource = nil
    tap = nil
    handler = nil
  }

  fileprivate static func parse(_ data1: Int64) -> SystemVolumeEvent? {
    let keyCode = (data1 >> 16) & 0xFFFF
    let keyState = (data1 >> 8) & 0xFF
    guard keyState == 0x0A else { return nil }

    switch keyCode {
    case 0: return .increase
    case 1: return .decrease
    case 7: return .mute
    default: return nil
    }
  }

  fileprivate func handle(_ event: SystemVolumeEvent) {
    handler?(event)
  }

  deinit {
    stop()
  }
}

private func systemVolumeEventTapCallback(
  _ proxy: CGEventTapProxy,
  _ type: CGEventType,
  _ event: CGEvent,
  _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<SystemVolumeEventTap>
    .fromOpaque(refcon)
    .takeUnretainedValue()

  guard type.rawValue == 14,
    let systemEvent = NSEvent(cgEvent: event),
    systemEvent.subtype.rawValue == 8,
    let volumeEvent = SystemVolumeEventTap.parse(Int64(systemEvent.data1))
  else {
    return Unmanaged.passUnretained(event)
  }

  tap.handle(volumeEvent)
  return nil
}
