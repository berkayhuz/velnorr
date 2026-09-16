import Foundation

enum MusicSource: Sendable, Equatable, Hashable {
  case spotify
  case music
  case unknown
}

enum PlaybackAction: Sendable {
  case previous
  case next
  case toggleShuffle
}

struct NowPlayingSnapshot: Sendable, Equatable {
  let trackKey: String
  let artworkURL: URL?
  let isPlaying: Bool
  let title: String
  let artist: String
  let elapsed: TimeInterval
  let duration: TimeInterval
}
