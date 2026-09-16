import Combine
import Foundation
import IOKit.ps

@MainActor
final class BatteryChargeStore: ObservableObject {
  static let fallbackPollingInterval: TimeInterval = 60
  static let fallbackPollingTolerance: TimeInterval = 6
  static let defaultBatteryThresholdInterval = 10

  enum HUDMode: Equatable { case charging, unplugged, low, full, threshold }
  @Published private(set) var isVisible = false
  @Published private(set) var level = 0
  @Published private(set) var isCharging = false
  @Published private(set) var mode: HUDMode = .charging

  private var timer: Timer?
  private var powerSourceRunLoopSource: CFRunLoopSource?
  private var hideTask: Task<Void, Never>?
  private var lastSnapshot: Snapshot?
  private var previewTask: Task<Void, Never>?
  private var isStarted = false

  init(preview: Bool = PreviewMode.battery) {
    if preview {
      level = PreviewMode.lowBattery ? 15 : (PreviewMode.fullCharge ? 100 : 64)
      isCharging = !PreviewMode.batteryUnplugged
      mode =
        PreviewMode.lowBattery
        ? .low
        : (PreviewMode.fullCharge ? .full : (PreviewMode.batteryUnplugged ? .unplugged : .charging))
      isVisible = true
      lastSnapshot = Snapshot(
        level: level,
        isCharging: !PreviewMode.batteryUnplugged,
        isPluggedIn: !PreviewMode.batteryUnplugged
      )
    }
  }

  func start() {
    stop()
    isStarted = true
    if PreviewMode.battery {
      level = PreviewMode.lowBattery ? 15 : (PreviewMode.fullCharge ? 100 : 64)
      isCharging = !PreviewMode.batteryUnplugged
      mode =
        PreviewMode.lowBattery
        ? .low
        : (PreviewMode.fullCharge ? .full : (PreviewMode.batteryUnplugged ? .unplugged : .charging))
      isVisible = true
      lastSnapshot = Snapshot(
        level: level,
        isCharging: !PreviewMode.batteryUnplugged,
        isPluggedIn: !PreviewMode.batteryUnplugged
      )
      if PreviewMode.batteryThreshold { startThresholdPreview() }
      return
    }

    refresh(showOnChange: false)
    installPowerSourceMonitoring()
  }

  func stop() {
    isStarted = false
    timer?.invalidate()
    timer = nil
    if let powerSourceRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .commonModes)
      self.powerSourceRunLoopSource = nil
    }
    hideTask?.cancel()
    hideTask = nil
    previewTask?.cancel()
    previewTask = nil
    isVisible = false
    lastSnapshot = nil
  }

  func showPreview(mode previewMode: HUDMode = .low) {
    switch previewMode {
    case .charging:
      level = 64; isCharging = true
    case .unplugged:
      level = 64; isCharging = false
    case .low:
      level = 15; isCharging = false
    case .full:
      level = 100; isCharging = true
    case .threshold:
      level = 80; isCharging = false
    }
    mode = previewMode
    isVisible = true
    hideTask?.cancel()
    let displayDuration = batteryDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(displayDuration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  @objc private func tick() {
    refresh(showOnChange: true)
  }

  private func installPowerSourceMonitoring() {
    let context = Unmanaged.passUnretained(self).toOpaque()
    if let source = IOPSNotificationCreateRunLoopSource(
      batteryPowerSourceCallback,
      context
    ) {
      let retainedSource = source.takeRetainedValue()
      CFRunLoopAddSource(CFRunLoopGetMain(), retainedSource, .commonModes)
      powerSourceRunLoopSource = retainedSource
      return
    }

    let timer = Timer(
      timeInterval: Self.fallbackPollingInterval,
      target: self,
      selector: #selector(tick),
      userInfo: nil,
      repeats: true
    )
    timer.tolerance = Self.fallbackPollingTolerance
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func refresh(showOnChange: Bool) {
    guard isStarted else { return }
    guard let snapshot = Self.readSnapshot() else { return }
    let previous = lastSnapshot
    lastSnapshot = snapshot
    let eventMode = Self.notificationMode(
      current: snapshot,
      previous: previous,
      lowBatteryThreshold: lowBatteryThreshold,
      greenBatteryThreshold: greenBatteryThreshold
    )
    let nextMode = eventMode ?? (snapshot.isPluggedIn ? .charging : .unplugged)

    if level != snapshot.level {
      level = snapshot.level
    }
    if isCharging != snapshot.isCharging {
      isCharging = snapshot.isCharging
    }
    if mode != nextMode {
      mode = nextMode
    }
    guard showOnChange, let eventMode, isModeEnabled(eventMode) else {
      return
    }

    isVisible = true
    hideTask?.cancel()
    let displayDuration = batteryDisplayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(displayDuration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private var lowBatteryThreshold: Int {
    min(50, max(5, UserDefaults.standard.integer(forKey: "batteryLowThreshold")))
  }

  private var greenBatteryThreshold: Int {
    let value = UserDefaults.standard.integer(forKey: "batteryGreenThreshold")
    return min(95, max(lowBatteryThreshold + 5, value == 0 ? 80 : value))
  }

  private var batteryDisplayDuration: Double {
    let value = UserDefaults.standard.double(forKey: "batteryDisplayDuration")
    return value > 0 ? min(10, max(0.5, value)) : 1.5
  }

  private func isModeEnabled(_ mode: HUDMode) -> Bool {
    let key: String
    switch mode {
    case .charging: key = "batteryShowCharging"
    case .unplugged: key = "batteryShowUnplugged"
    case .low: key = "batteryShowLow"
    case .full: key = "batteryShowFull"
    case .threshold: key = "batteryShowThreshold"
    }
    return UserDefaults.standard.object(forKey: key) as? Bool ?? true
  }

  static func notificationMode(
    current: Snapshot?,
    previous: Snapshot?,
    lowBatteryThreshold: Int,
    greenBatteryThreshold: Int,
    thresholdInterval: Int = defaultBatteryThresholdInterval
  ) -> HUDMode? {
    guard let current, let previous else { return nil }

    if current.level == 100, previous.level != 100 {
      return .full
    }
    if current.level < lowBatteryThreshold, previous.level >= lowBatteryThreshold {
      return .low
    }
    if current.isPluggedIn != previous.isPluggedIn {
      return current.isPluggedIn ? .charging : .unplugged
    }

    let crossesConfiguredGreenThreshold =
      (previous.level < greenBatteryThreshold) != (current.level < greenBatteryThreshold)
    let greenThresholdCoveredByCadence =
      thresholdInterval > 0 && greenBatteryThreshold % thresholdInterval == 0
    let crossedGreenThreshold =
      crossesConfiguredGreenThreshold && !greenThresholdCoveredByCadence
    let crossedBatteryThreshold = crossedBatteryThreshold(
      from: previous.level,
      to: current.level,
      interval: thresholdInterval
    )
    return crossedGreenThreshold || crossedBatteryThreshold ? .threshold : nil
  }

  private static func crossedBatteryThreshold(from previous: Int, to current: Int, interval: Int) -> Bool {
    guard interval > 0, previous != current else { return false }

    if current > previous {
      return current / interval != previous / interval
    }
    return thresholdBucket(for: previous, interval: interval)
      != thresholdBucket(for: current, interval: interval)
  }

  private static func thresholdBucket(for level: Int, interval: Int) -> Int? {
    guard interval > 0 else { return nil }
    let boundedLevel = min(100, max(0, level))
    return (boundedLevel + interval - 1) / interval
  }

  private func startThresholdPreview() {
    previewTask = Task { @MainActor [weak self] in
      let values = [79, 80, 99, 100]
      var index = 0
      while !Task.isCancelled {
        guard let self else { return }
        self.level = values[index % values.count]
        self.mode = self.level == 100 ? .full : .threshold
        index += 1
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  struct Snapshot: Equatable {
    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool
  }

  private static func readSnapshot() -> Snapshot? {
    let signpost = VelnorrPerformance.begin(.batteryRead)
    defer { VelnorrPerformance.end(.batteryRead, signpost) }

    let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
    for source in sources {
      guard
        let description = IOPSGetPowerSourceDescription(info, source)
          .takeUnretainedValue() as? [String: Any],
        let current = description[kIOPSCurrentCapacityKey] as? Int,
        let maximum = description[kIOPSMaxCapacityKey] as? Int,
        maximum > 0
      else { continue }
      let charging = description[kIOPSIsChargingKey] as? Bool ?? false
      let powerState = description[kIOPSPowerSourceStateKey] as? String
      let pluggedIn = charging || powerState == kIOPSACPowerValue
      return Snapshot(
        level: min(100, max(0, current * 100 / maximum)),
        isCharging: charging,
        isPluggedIn: pluggedIn
      )
    }
    return nil
  }
}

private func batteryPowerSourceCallback(_ context: UnsafeMutableRawPointer?) {
  guard let context else { return }
  let store = Unmanaged<BatteryChargeStore>.fromOpaque(context).takeUnretainedValue()
  Task { @MainActor [weak store] in
    store?.refreshFromPowerSourceNotification()
  }
}

extension BatteryChargeStore {
  fileprivate func refreshFromPowerSourceNotification() {
    refresh(showOnChange: true)
  }
}
