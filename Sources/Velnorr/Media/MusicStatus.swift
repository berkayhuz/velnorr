import AppKit
import Foundation

struct MusicStatus {
  var hasTrack = false
  var isPlaying = false
  var artwork: NSImage?
  var artworkTrackKey = ""
  var accentColor = NSColor.systemGreen
  var trackKey = ""
  var title = ""
  var artist = ""
  var source: MusicSource = .unknown
  var elapsed: TimeInterval = 0
  var duration: TimeInterval = 0
  var playbackUpdatedAt = Date()
}
