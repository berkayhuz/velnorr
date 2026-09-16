enum VelnorrDisplayMode: String {
  case notch
  case pill
  case simulatedNotch
}

enum VelnorrMirrorShape: String, CaseIterable, Identifiable {
  case roundedRectangle
  case circle

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .roundedRectangle: "Rounded rectangle"
    case .circle: "Circle"
    }
  }
}

enum VelnorrNotchHeightMode: String, CaseIterable, Identifiable, Sendable {
  case system
  case menuBar
  case custom

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .system: "Match system notch"
    case .menuBar: "Match menu bar"
    case .custom: "Custom height"
    }
  }
}

enum VelnorrPresentationState: Equatable {
  case collapsed
  case quickPeek
  case volume
  case brightness
  case battery
  case deviceConnection
  case expanded
  case media
}

enum VelnorrPresentationResolver {
  static func resolve(
    base: VelnorrPresentationState,
    isMediaExpanded: Bool,
    deviceEnabled: Bool,
    deviceVisible: Bool,
    volumeEnabled: Bool,
    volumeVisible: Bool,
    batteryEnabled: Bool,
    batteryVisible: Bool,
    brightnessEnabled: Bool,
    brightnessVisible: Bool,
    automaticTrackPeekVisible: Bool,
    hasTrack: Bool,
    lastLevelHUD: VelnorrPresentationState? = nil
  ) -> VelnorrPresentationState {
    guard !isMediaExpanded else { return base }
    if deviceEnabled && deviceVisible { return .deviceConnection }
    if volumeEnabled && volumeVisible && brightnessEnabled && brightnessVisible {
      if lastLevelHUD == .brightness { return .brightness }
      return .volume
    }
    if volumeEnabled && volumeVisible { return .volume }
    if batteryEnabled && batteryVisible { return .battery }
    if brightnessEnabled && brightnessVisible { return .brightness }
    if automaticTrackPeekVisible && hasTrack { return .quickPeek }
    return base
  }
}
