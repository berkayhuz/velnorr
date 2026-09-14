import AppKit
import Combine
import Foundation
@preconcurrency import IOBluetooth

enum ConnectedAppleDeviceKind: Sendable, Equatable {
  case airPods
  case appleWatch
  case keyboard
  case mouse
  case speaker

  var symbolName: String {
    switch self {
    case .airPods: "airpodspro"
    case .appleWatch: "applewatch"
    case .keyboard: "keyboard.macwindow"
    case .mouse: "magicmouse.fill"
    case .speaker: "speaker.wave.2.fill"
    }
  }
}

struct ConnectedAppleDevice: Equatable, Sendable {
  let name: String
  let kind: ConnectedAppleDeviceKind
  let batteryPercentage: Int?
}

@MainActor
final class BluetoothConnectionStore: NSObject, ObservableObject {
  // Connection notifications can be delivered more than once (and once per
  // velnorr window when multiple displays are connected). Keep the debounce
  // shared across stores so one physical connection creates one HUD event.
  private static var recentConnectionEvents: [String: Date] = [:]
  private static let duplicateEventWindow: TimeInterval = 4

  @Published private(set) var device: ConnectedAppleDevice?
  @Published private(set) var isVisible = false

  private let detailsProvider = BluetoothDeviceDetailsProvider()
  private var connectNotification: IOBluetoothUserNotification?
  private var hideTask: Task<Void, Never>?
  private var lookupTask: Task<Void, Never>?
  private var initialConnectedAddresses = Set<String>()
  private var initialBaselineTask: Task<Void, Never>?

  func start() {
    guard connectNotification == nil else { return }
    if let previewKind = PreviewMode.bluetoothKind {
      let name: String
      switch previewKind {
      case .airPods: name = "AirPods Pro"
      case .appleWatch: name = "Apple Watch"
      case .keyboard: name = "Magic Keyboard"
      case .mouse: name = "Magic Mouse"
      case .speaker: name = "Portable Speaker"
      }
      device = ConnectedAppleDevice(name: name, kind: previewKind, batteryPercentage: 78)
      isVisible = true
      return
    }
    initialConnectedAddresses = Set(
      IOBluetoothDevice.pairedDevices().compactMap { item in
        guard let device = item as? IOBluetoothDevice,
          device.isConnected(),
          let address = device.addressString
        else { return nil }
        return address.uppercased()
      }
    )
    initialBaselineTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      self?.initialConnectedAddresses.removeAll()
      self?.initialBaselineTask = nil
    }
    connectNotification = IOBluetoothDevice.register(
      forConnectNotifications: self,
      selector: #selector(deviceDidConnect(_:device:))
    )
  }

  func stop() {
    connectNotification?.unregister()
    connectNotification = nil
    lookupTask?.cancel()
    lookupTask = nil
    initialBaselineTask?.cancel()
    initialBaselineTask = nil
    initialConnectedAddresses.removeAll()
    hideTask?.cancel()
    hideTask = nil
    isVisible = false
    device = nil
  }

  func showPreview(kind: ConnectedAppleDeviceKind) {
    let name: String
    switch kind {
    case .airPods: name = "AirPods Pro"
    case .appleWatch: name = "Apple Watch"
    case .keyboard: name = "Keyboard"
    case .mouse: name = "Mouse"
    case .speaker: name = "Portable Speaker"
    }
    device = ConnectedAppleDevice(name: name, kind: kind, batteryPercentage: 78)
    isVisible = true
    hideTask?.cancel()
    let duration = Self.displayDuration
    hideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  @objc nonisolated private func deviceDidConnect(
    _ notification: IOBluetoothUserNotification,
    device bluetoothDevice: IOBluetoothDevice
  ) {
    guard bluetoothDevice.isConnected() else { return }
    let name = bluetoothDevice.name ?? "Apple device"
    let address = bluetoothDevice.addressString ?? ""
    guard let kind = Self.kind(for: name, classOfDevice: bluetoothDevice.classOfDevice) else {
      return
    }

    Task { @MainActor [weak self] in
      self?.showConnection(name: name, address: address, kind: kind)
    }
  }

  private func showConnection(
    name: String,
    address: String,
    kind: ConnectedAppleDeviceKind
  ) {
    guard Self.isKindEnabled(kind) else { return }
    if !address.isEmpty {
      let normalizedAddress = address.uppercased()
      if initialConnectedAddresses.contains(normalizedAddress) {
        initialConnectedAddresses.remove(normalizedAddress)
        return
      }
    }
    let eventKey = address.isEmpty ? "name:\(name)" : "address:\(address)"
    let now = Date()
    if let previous = Self.recentConnectionEvents[eventKey],
      now.timeIntervalSince(previous) < Self.duplicateEventWindow
    {
      return
    }
    Self.recentConnectionEvents[eventKey] = now

    lookupTask?.cancel()
    hideTask?.cancel()

    device = ConnectedAppleDevice(name: name, kind: kind, batteryPercentage: nil)
    isVisible = true

    lookupTask = Task { @MainActor [weak self, detailsProvider] in
      try? await Task.sleep(for: .milliseconds(650))
      guard !Task.isCancelled else { return }
      let battery = await detailsProvider.batteryPercentage(address: address, name: name)
      guard !Task.isCancelled, let self, self.device?.name == name else { return }
      self.device = ConnectedAppleDevice(
        name: name,
        kind: kind,
        batteryPercentage: battery
      )
      self.lookupTask = nil
    }

    hideTask = Task { @MainActor [weak self] in
      let duration = Self.displayDuration
      try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
      guard !Task.isCancelled else { return }
      self?.isVisible = false
      self?.hideTask = nil
    }
  }

  private static var displayDuration: Double {
    let value = UserDefaults.standard.double(forKey: "deviceDisplayDuration")
    return value > 0 ? min(10, max(0.5, value)) : 3.5
  }

  private static func isKindEnabled(_ kind: ConnectedAppleDeviceKind) -> Bool {
    let key: String
    switch kind {
    case .airPods: key = "deviceAirPods"
    case .appleWatch: key = "deviceAppleWatch"
    case .keyboard: key = "deviceKeyboard"
    case .mouse: key = "deviceMouse"
    case .speaker: key = "deviceSpeaker"
    }
    return UserDefaults.standard.object(forKey: key) as? Bool ?? true
  }

  nonisolated private static func kind(for name: String, classOfDevice: UInt32)
    -> ConnectedAppleDeviceKind?
  {
    let normalizedName = name.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: .current
    )
    if normalizedName.contains("airpods") {
      return .airPods
    }
    if normalizedName.contains("apple watch") {
      return .appleWatch
    }
    if normalizedName.contains("keyboard")
      || normalizedName.contains("mx keys")
      || normalizedName.contains("keys mini")
      || normalizedName.contains("pebble")
      || normalizedName.contains("k380")
      || Self.isLogitechKeyboard(normalizedName)
    {
      return .keyboard
    }
    if normalizedName.contains("mouse")
      || normalizedName.contains("trackpad")
      || normalizedName.contains("lift")
      || normalizedName.contains("mx master")
      || normalizedName.contains("mx anywhere")
    {
      return .mouse
    }
    if Self.isLogitechMouse(normalizedName) { return .mouse }
    let majorClass = (classOfDevice >> 8) & 0x1F
    let peripheralMinor = classOfDevice & 0xC0
    if majorClass == 0x05 {
      if peripheralMinor == 0x40 || peripheralMinor == 0xC0 { return .keyboard }
      if peripheralMinor == 0x80 { return .mouse }
    }
    if majorClass == 0x04 { return .speaker }
    return nil
  }

  nonisolated private static func isLogitechKeyboard(_ name: String) -> Bool {
    guard name.contains("logitech") || name.contains("logicool") else { return false }
    let keyboardFamilies = [
      "keys", "keyboard", "mechanical", "craft", "k380", "k480", "k580", "k780",
      "k810", "k811", "k840", "k845", "k860", "k855", "k950", "pop keys", "wave keys",
      "signature k", "ergo k", "g915", "g715", "g913", "g613", "g512", "g pro keyboard",
    ]
    return keyboardFamilies.contains(where: name.contains)
  }

  nonisolated private static func isLogitechMouse(_ name: String) -> Bool {
    guard name.contains("logitech") || name.contains("logicool") else { return false }
    let mouseFamilies = [
      "mouse", "lift", "mx master", "mx anywhere", "mx ergo", "pebble", "m185", "m187",
      "m220", "m325", "m350", "m510", "m590", "m650", "m720", "m705", "m585", "m557",
      "g pro", "g203", "g305", "g502", "g603", "g604", "g703", "g705", "g903", "g pro x",
    ]
    return mouseFamilies.contains(where: name.contains)
  }
}

private actor BluetoothDeviceDetailsProvider {
  func batteryPercentage(address: String, name: String) -> Int? {
    let signpost = VelnorrPerformance.begin(.bluetoothSystemProfiler)
    defer { VelnorrPerformance.end(.bluetoothSystemProfiler, signpost) }

    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    process.arguments = ["SPBluetoothDataType", "-json"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      return Self.findBattery(in: data, address: address, name: name)
    } catch {
      return nil
    }
  }

  private static func findBattery(in data: Data, address: String, name: String) -> Int? {
    guard
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let sections = root["SPBluetoothDataType"] as? [[String: Any]]
    else { return nil }

    let normalizedAddress = address.uppercased()
    for section in sections {
      guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
      for entry in connected {
        for (deviceName, rawProperties) in entry {
          guard let properties = rawProperties as? [String: Any] else { continue }
          let candidateAddress = (properties["device_address"] as? String)?.uppercased()
          guard candidateAddress == normalizedAddress || deviceName == name else { continue }
          return batteryValue(from: properties)
        }
      }
    }
    return nil
  }

  private static func batteryValue(from properties: [String: Any]) -> Int? {
    if let main = parsePercentage(properties["device_batteryLevelMain"]) {
      return main
    }

    let componentValues = [
      "device_batteryLevelLeft",
      "device_batteryLevelRight",
      "device_batteryLevelCase",
    ].compactMap { parsePercentage(properties[$0]) }

    guard !componentValues.isEmpty else { return nil }
    return Int((Double(componentValues.reduce(0, +)) / Double(componentValues.count)).rounded())
  }

  private static func parsePercentage(_ rawValue: Any?) -> Int? {
    guard let text = rawValue as? String else { return nil }
    let digits = text.filter(\.isNumber)
    guard let value = Int(digits) else { return nil }
    return min(100, max(0, value))
  }
}
