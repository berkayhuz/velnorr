import Foundation

/// Command-line previews used while developing velnorr UI.
enum PreviewMode {
  static let batteryUnplugged = CommandLine.arguments.contains("--preview-unplugged")
  static let battery =
    CommandLine.arguments.contains("--preview-battery") || batteryUnplugged
    || CommandLine.arguments.contains("--preview-low-battery")
    || CommandLine.arguments.contains("--preview-full-charge")
    || CommandLine.arguments.contains("--preview-battery-threshold")
  static let lowBattery = CommandLine.arguments.contains("--preview-low-battery")
  static let fullCharge = CommandLine.arguments.contains("--preview-full-charge")
  static let batteryThreshold = CommandLine.arguments.contains("--preview-battery-threshold")

  static var bluetoothKind: ConnectedAppleDeviceKind? {
    if CommandLine.arguments.contains("--preview-airpods") { return .airPods }
    if CommandLine.arguments.contains("--preview-keyboard") { return .keyboard }
    if CommandLine.arguments.contains("--preview-mouse") { return .mouse }
    if CommandLine.arguments.contains("--preview-speaker") { return .speaker }
    return nil
  }
}
