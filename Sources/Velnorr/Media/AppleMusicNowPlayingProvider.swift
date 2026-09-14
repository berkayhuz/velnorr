import AppKit
import Foundation

struct AppleMusicNowPlayingProvider: NowPlayingProviding {
  let source = MusicSource.music
  private let executor: AppleScriptExecutor
  private let bundleIdentifier = "com.apple.Music"

  var applicationBundleIdentifier: String? { bundleIdentifier }

  init(executor: AppleScriptExecutor = .shared) {
    self.executor = executor
  }

  @MainActor var isInstalled: Bool { applicationURL != nil }

  @MainActor var applicationIcon: NSImage? {
    MediaApplicationCache.icon(
      for: bundleIdentifier,
      resourceName: "apple-music-icon"
    )
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

  func read(isRunning: Bool) async -> NowPlayingSnapshot? {
    guard isRunning else { return nil }
    let script = #"""
      tell application "Music"
          if player state is playing then
              set currentTrack to current track
              return "playing" & tab & (database ID of currentTrack) & tab & "" & tab & (name of currentTrack) & tab & (artist of currentTrack) & tab & player position & tab & (duration of currentTrack)
          else
              try
                  set currentTrack to current track
                  return "paused" & tab & (database ID of currentTrack) & tab & "" & tab & (name of currentTrack) & tab & (artist of currentTrack) & tab & player position & tab & (duration of currentTrack)
              on error
                  return "stopped"
              end try
          end if
      end tell
      """#

    guard let result = await executor.execute(script, operation: "Music read") else { return nil }
    return Self.parse(result)
  }

  func setPlaying(_ playing: Bool) async {
    guard await isRunning() else { return }
    let command = playing ? "play" : "pause"
    _ = await executor.execute(
      "tell application \"Music\" to \(command)", operation: "Music \(command)")
  }

  func perform(_ action: PlaybackAction) async {
    guard await isRunning() else { return }
    let command: String
    switch action {
    case .previous: command = "previous track"
    case .next: command = "next track"
    case .toggleShuffle: command = "set shuffle enabled to not shuffle enabled"
    }
    _ = await executor.execute(
      "tell application \"Music\" to \(command)", operation: "Music command")
  }

  func seek(to seconds: TimeInterval) async {
    guard await isRunning() else { return }
    _ = await executor.execute(
      "tell application \"Music\" to set player position to \(max(0, seconds))",
      operation: "Music seek"
    )
  }

  func openTrack(trackKey: String, title: String, artist: String) async {
    await revealSearchResult(title)
  }

  func openArtist(name: String) async {
    await revealSearchResult(name)
  }

  private func revealSearchResult(_ query: String) async {
    let escaped =
      query
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
      tell application "Music"
          activate
          set matches to search playlist "Library" for "\(escaped)"
          if (count of matches) > 0 then reveal item 1 of matches
      end tell
      """
    _ = await executor.execute(script, operation: "Music open search result")
  }

  static func parse(_ result: String) -> NowPlayingSnapshot? {
    let parts = result.components(separatedBy: "\t")
    guard parts.count >= 7, ["playing", "paused"].contains(parts[0]), !parts[1].isEmpty else {
      return nil
    }
    return NowPlayingSnapshot(
      trackKey: "music-\(parts[1])", artworkURL: nil, isPlaying: parts[0] == "playing",
      title: parts[3], artist: parts[4], elapsed: Double(parts[5]) ?? 0,
      duration: Double(parts[6]) ?? 0
    )
  }

  @MainActor private var applicationURL: URL? {
    MediaApplicationCache.url(for: bundleIdentifier)
  }

  private func isRunning() async -> Bool {
    await MainActor.run {
      NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        .contains { !$0.isTerminated }
    }
  }
}
