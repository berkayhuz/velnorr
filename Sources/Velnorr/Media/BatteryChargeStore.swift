import Combine
import Foundation
import IOKit.ps

@MainActor
final class BatteryChargeStore: ObservableObject {
  enum HUDMode: Equatable { case charging, unplugged, low, full, threshold }
  @Published private(set) var isVisible = false
  @Published private(set) var level = 0
  @Published private(set) var isCharging = false
  @Published private(set) var mode: HUDMode = .charging

  private var timer: Timer?
  private var hideTask: Task<Void, Never>?
  private var lastSnapshot: Snapshot?
  private var previewTask: Task<Void, Never>?

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
    let timer = Timer(
      timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stop() {
    timer?.invalidate()
    timer = nil
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

  private func refresh(showOnChange: Bool) {
    guard let snapshot = Self.readSnapshot() else { return }
    let changed = lastSnapshot != nil && snapshot != lastSnapshot
    let previous = lastSnapshot
    lastSnapshot = snapshot
    level = snapshot.level
    isCharging = snapshot.isPluggedIn
    if snapshot.level == 100, previous?.level != 100 {
      mode = .full
    } else if snapshot.level < lowBatteryThreshold,
      (previous?.level ?? lowBatteryThreshold) >= lowBatteryThreshold
    {
      mode = .low
    } else if let previous,
      (previous.level < greenBatteryThreshold) != (snapshot.level < greenBatteryThreshold)
    {
      mode = .threshold
    } else {
      mode = snapshot.isPluggedIn ? .charging : .unplugged
    }
    guard showOnChange, changed, isModeEnabled(mode) else { return }

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

  private struct Snapshot: Equatable {
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
