import os

enum VelnorrPerformanceSignpost: CaseIterable {
  case mediaRefresh
  case appleScriptExecute
  case artworkDownload
  case artworkDecode
  case batteryRead
  case bluetoothSystemProfiler
  case windowMouseRefresh
  case shellPresentationTransition

  @inline(__always)
  var staticName: StaticString {
    switch self {
    case .mediaRefresh: "media.refresh"
    case .appleScriptExecute: "applescript.execute"
    case .artworkDownload: "artwork.download"
    case .artworkDecode: "artwork.decode"
    case .batteryRead: "battery.read"
    case .bluetoothSystemProfiler: "bluetooth.system_profiler"
    case .windowMouseRefresh: "window.mouse.refresh"
    case .shellPresentationTransition: "shell.presentation.transition"
    }
  }
}

enum VelnorrPerformance {
  private static let logger = Logger(
    subsystem: "com.berkayhuz.velnorr",
    category: "Performance"
  )
  static let signposter = OSSignposter(logger: logger)

  @inline(__always)
  static func begin(_ name: VelnorrPerformanceSignpost) -> OSSignpostIntervalState? {
    guard signposter.isEnabled else { return nil }
    return signposter.beginInterval(name.staticName)
  }

  @inline(__always)
  static func end(
    _ name: VelnorrPerformanceSignpost,
    _ state: OSSignpostIntervalState?
  ) {
    guard let state else { return }
    signposter.endInterval(name.staticName, state)
  }

  @inline(__always)
  static func emit(_ name: VelnorrPerformanceSignpost) {
    guard signposter.isEnabled else { return }
    signposter.emitEvent(name.staticName)
  }
}
