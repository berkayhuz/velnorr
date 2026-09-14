import XCTest

@testable import Velnorr

final class NowPlayingSourceResolverTests: XCTestCase {
  func testPlayingMusicWinsOverPausedSpotify() {
    let selected = NowPlayingSourceResolver.select(
      from: [candidate(.spotify, playing: false), candidate(.music, playing: true)],
      currentSource: .spotify
    )

    XCTAssertEqual(selected?.source, .music)
  }

  func testCurrentSourceWinsWhenAllSourcesArePaused() {
    let selected = NowPlayingSourceResolver.select(
      from: [candidate(.spotify, playing: false), candidate(.music, playing: false)],
      currentSource: .music
    )

    XCTAssertEqual(selected?.source, .music)
  }

  func testCurrentPlayingSourceWinsWhenBothSourcesPlay() {
    let selected = NowPlayingSourceResolver.select(
      from: [candidate(.spotify, playing: true), candidate(.music, playing: true)],
      currentSource: .music
    )

    XCTAssertEqual(selected?.source, .music)
  }

  private func candidate(_ source: MusicSource, playing: Bool) -> SourcedNowPlayingSnapshot {
    SourcedNowPlayingSnapshot(
      source: source,
      snapshot: NowPlayingSnapshot(
        trackKey: "\(source)", artworkURL: nil, isPlaying: playing,
        title: "Title", artist: "Artist", elapsed: 0, duration: 100
      )
    )
  }
}
