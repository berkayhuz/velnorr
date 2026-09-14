import AppKit
import Foundation

struct SpotifyNowPlayingProvider: NowPlayingProviding {
  let source = MusicSource.spotify
  private let executor: AppleScriptExecutor
  private let bundleIdentifier = "com.spotify.client"

  init(executor: AppleScriptExecutor = .shared) {
    self.executor = executor
  }

  @MainActor var isInstalled: Bool { applicationURL != nil }

  @MainActor var applicationIcon: NSImage? {
    Bundle.module.url(forResource: "spotify-icon", withExtension: "svg")
      .flatMap { NSImage(contentsOf: $0) }
  }

  @MainActor func openApplication() {
    guard let applicationURL else { return }
    NSWorkspace.shared.openApplication(
      at: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, _ in }
  }

  func launchAndPlay() async {
    guard await MainActor.run(body: { applicationURL }) != nil else { return }
    if await !isRunning() {
      await MainActor.run { openApplication() }
      for _ in 0..<30 {
        if await isRunning() { break }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
    await setPlaying(true)
  }

  func read() async -> NowPlayingSnapshot? {
    guard await isRunning() else { return nil }
    let script = #"""
      tell application "Spotify"
          if player state is playing then
              set currentTrack to current track
              return "playing" & tab & (id of currentTrack) & tab & (artwork url of currentTrack) & tab & (name of currentTrack) & tab & (artist of currentTrack) & tab & player position & tab & (duration of currentTrack)
          else
              try
                  set currentTrack to current track
                  return "paused" & tab & (id of currentTrack) & tab & (artwork url of currentTrack) & tab & (name of currentTrack) & tab & (artist of currentTrack) & tab & player position & tab & (duration of currentTrack)
              on error
                  return "stopped"
              end try
          end if
      end tell
      """#

    guard let result = await executor.execute(script, operation: "Spotify read") else { return nil }
    return Self.parse(result)
  }

  func setPlaying(_ playing: Bool) async {
    guard await isRunning() else { return }
    let command = playing ? "play" : "pause"
    _ = await executor.execute(
      "tell application \"Spotify\" to \(command)", operation: "Spotify \(command)")
  }

  func perform(_ action: PlaybackAction) async {
    guard await isRunning() else { return }
    let command: String
    switch action {
    case .previous: command = "previous track"
    case .next: command = "next track"
    case .toggleShuffle: command = "set shuffling to not shuffling"
    }
    _ = await executor.execute(
      "tell application \"Spotify\" to \(command)", operation: "Spotify command")
  }

  func seek(to seconds: TimeInterval) async {
    guard await isRunning() else { return }
    _ = await executor.execute(
      "tell application \"Spotify\" to set player position to \(max(0, seconds))",
      operation: "Spotify seek"
    )
  }

  func openTrack(trackKey: String, title: String, artist: String) async {
    let identifier =
      trackKey.hasPrefix("spotify:track:")
      ? trackKey
      : "spotify:track:\(trackKey)"
    guard let url = URL(string: identifier) else { return }
    let _ = await MainActor.run { NSWorkspace.shared.open(url) }
  }

  func openArtist(name: String) async {
    guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
      let url = URL(string: "spotify:search:artist:\(encoded)")
    else { return }
    let _ = await MainActor.run { NSWorkspace.shared.open(url) }
  }

  static func parse(_ result: String) -> NowPlayingSnapshot? {
    let parts = result.components(separatedBy: "\t")
    guard parts.count >= 7, ["playing", "paused"].contains(parts[0]), !parts[1].isEmpty else {
      return nil
    }
    return NowPlayingSnapshot(
      trackKey: parts[1], artworkURL: URL(string: parts[2]), isPlaying: parts[0] == "playing",
      title: parts[3], artist: parts[4], elapsed: Double(parts[5]) ?? 0,
      duration: (Double(parts[6]) ?? 0) / 1_000
    )
  }

  @MainActor private var applicationURL: URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }

  private func isRunning() async -> Bool {
    await MainActor.run {
      NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        .contains { !$0.isTerminated }
    }
  }
}
