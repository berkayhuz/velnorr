enum VelnorrDisplayMode: String {
  case notch
  case pill
  case simulatedNotch
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
    hasTrack: Bool
  ) -> VelnorrPresentationState {
    guard !isMediaExpanded else { return base }
    if deviceEnabled && deviceVisible { return .deviceConnection }
    if volumeEnabled && volumeVisible { return .volume }
    if batteryEnabled && batteryVisible { return .battery }
    if brightnessEnabled && brightnessVisible { return .brightness }
    if automaticTrackPeekVisible && hasTrack { return .quickPeek }
    return base
  }
}
