import XCTest

@testable import Velnorr

final class ProviderParsingTests: XCTestCase {
  func testSpotifyResultParsingConvertsMilliseconds() {
    let snapshot = SpotifyNowPlayingProvider.parse(
      "playing\ttrack-id\thttps://example.com/art.jpg\tSong\tArtist\t12.5\t180000")

    XCTAssertEqual(snapshot?.trackKey, "track-id")
    XCTAssertEqual(snapshot?.duration, 180)
    XCTAssertEqual(snapshot?.isPlaying, true)
  }

  func testAppleMusicResultParsingNamespacesTrackKey() {
    let snapshot = AppleMusicNowPlayingProvider.parse(
      "paused\t42\t\tSong\tArtist\t12.5\t180")

    XCTAssertEqual(snapshot?.trackKey, "music-42")
    XCTAssertEqual(snapshot?.duration, 180)
    XCTAssertEqual(snapshot?.isPlaying, false)
  }

  func testMalformedResultIsRejected() {
    XCTAssertNil(SpotifyNowPlayingProvider.parse("stopped"))
    XCTAssertNil(AppleMusicNowPlayingProvider.parse("invalid"))
  }
}
