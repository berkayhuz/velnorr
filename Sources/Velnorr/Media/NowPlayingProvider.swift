import AppKit
import Foundation

protocol NowPlayingProviding: Sendable {
  var source: MusicSource { get }

  @MainActor var isInstalled: Bool { get }
  @MainActor var applicationIcon: NSImage? { get }
  @MainActor func openApplication()
  func read() async -> NowPlayingSnapshot?
  func launchAndPlay() async
  func setPlaying(_ playing: Bool) async
  func perform(_ action: PlaybackAction) async
  func seek(to seconds: TimeInterval) async
  func openTrack(trackKey: String, title: String, artist: String) async
  func openArtist(name: String) async
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
