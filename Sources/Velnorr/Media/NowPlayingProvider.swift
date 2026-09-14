import AppKit
import Foundation

protocol NowPlayingProviding: Sendable {
  var source: MusicSource { get }
  var applicationBundleIdentifier: String? { get }

  @MainActor var isInstalled: Bool { get }
  @MainActor var applicationIcon: NSImage? { get }
  @MainActor func openApplication()
  func read(isRunning: Bool) async -> NowPlayingSnapshot?
  func launchAndPlay() async
  func setPlaying(_ playing: Bool) async
  func perform(_ action: PlaybackAction) async
  func seek(to seconds: TimeInterval) async
  func openTrack(trackKey: String, title: String, artist: String) async
  func openArtist(name: String) async
}

extension NowPlayingProviding {
  var applicationBundleIdentifier: String? { nil }
}

enum MediaPollingPolicy {
  static func shouldRead(
    applicationBundleIdentifier: String?,
    source: MusicSource,
    runningSources: Set<MusicSource>
  ) -> Bool {
    applicationBundleIdentifier == nil || runningSources.contains(source)
  }
}

struct SourcedNowPlayingSnapshot: Sendable, Equatable {
  let source: MusicSource
  let snapshot: NowPlayingSnapshot
}

enum NowPlayingSourceResolver {
  static func select(
    from candidates: [SourcedNowPlayingSnapshot],
    currentSource: MusicSource
  ) -> SourcedNowPlayingSnapshot? {
    let playing = candidates.filter(\.snapshot.isPlaying)
    if let currentPlaying = playing.first(where: { $0.source == currentSource }) {
      return currentPlaying
    }
    if let playingSource = playing.first {
      return playingSource
    }
    if let current = candidates.first(where: { $0.source == currentSource }) {
      return current
    }
    return candidates.first
  }
}
