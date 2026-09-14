import AppKit
import Foundation

struct MusicStatus {
  var hasTrack = false
  var isPlaying = false
  var artwork: NSImage?
  var artworkTrackKey = ""
  var applicationIcon: NSImage?
  var accentColor = NSColor.systemGreen
  var trackKey = ""
  var title = ""
  var artist = ""
  var source: MusicSource = .unknown
  var elapsed: TimeInterval = 0
  var duration: TimeInterval = 0
  var playbackUpdatedAt = Date()

  func currentElapsed(at date: Date) -> TimeInterval {
    let liveElapsed =
      elapsed + (isPlaying ? date.timeIntervalSince(playbackUpdatedAt) : 0)
    guard duration > 0 else { return max(0, liveElapsed) }
    return min(duration, max(0, liveElapsed))
  }
}
