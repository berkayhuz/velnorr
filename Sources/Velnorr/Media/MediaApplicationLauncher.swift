import AppKit
import Foundation

@MainActor
protocol MediaApplicationLaunching {
  @discardableResult func openDefaultAudioApplication() -> Bool
  @discardableResult func openMusicDiscovery() -> Bool
}

@MainActor
struct SystemMediaApplicationLauncher: MediaApplicationLaunching {
  private let workspace = NSWorkspace.shared

  func openDefaultAudioApplication() -> Bool {
    let audioProbeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("velnorr-audio-probe")
      .appendingPathExtension("mp3")

    guard let applicationURL = workspace.urlForApplication(toOpen: audioProbeURL) else {
      return false
    }

    workspace.openApplication(
      at: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, _ in }
    return true
  }

  func openMusicDiscovery() -> Bool {
    guard let appStoreURL = URL(string: "macappstore://apps.apple.com/genre/mac-music/id12011")
    else { return false }
    return workspace.open(appStoreURL)
  }
}
