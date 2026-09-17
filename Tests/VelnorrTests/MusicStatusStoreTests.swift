import AppKit
import XCTest

@testable import Velnorr

@MainActor
final class MusicStatusStoreTests: XCTestCase {
  func testPlayingTrackKeepsLiveElapsedWhenMetadataRefreshes() async throws {
    let provider = TestNowPlayingProvider(
      snapshot: snapshot(title: "Original", isPlaying: true, elapsed: 42, duration: 180)
    )
    let store = MusicStatusStore(providers: [provider])
    store.start()
    defer { store.stop() }

    try await Task.sleep(for: .milliseconds(50))
    XCTAssertTrue(store.status.hasTrack)

    provider.snapshot = snapshot(title: "Refreshed", isPlaying: true, elapsed: 0, duration: 181)
    store.refresh()
    try await Task.sleep(for: .milliseconds(50))

    XCTAssertEqual(store.status.title, "Refreshed")
    XCTAssertGreaterThanOrEqual(store.status.elapsed, 42)
  }

  func testTrackResumingFromPausedStateUsesProviderElapsed() async throws {
    let provider = TestNowPlayingProvider(
      snapshot: snapshot(title: "Paused", isPlaying: false, elapsed: 30, duration: 180)
    )
    let store = MusicStatusStore(providers: [provider])
    store.start()
    defer { store.stop() }

    try await Task.sleep(for: .milliseconds(50))
    XCTAssertFalse(store.status.isPlaying)
    provider.snapshot = snapshot(title: "Resumed", isPlaying: true, elapsed: 60, duration: 180)
    store.refresh()
    try await Task.sleep(for: .milliseconds(50))

    XCTAssertTrue(store.status.isPlaying)
    XCTAssertGreaterThanOrEqual(store.status.elapsed, 60)
  }

  func testMissingSnapshotPreservesTrackOnlyWhileScreenIsLocked() async throws {
    let provider = TestNowPlayingProvider(
      snapshot: snapshot(title: "Locked", isPlaying: false, elapsed: 30, duration: 180)
    )
    let store = MusicStatusStore(providers: [provider])
    store.isScreenLocked = { true }
    store.start()
    defer { store.stop() }

    try await Task.sleep(for: .milliseconds(50))
    XCTAssertTrue(store.status.hasTrack)

    provider.snapshot = nil
    store.refresh()
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertTrue(store.status.hasTrack)

    store.isScreenLocked = { false }
    store.refresh()
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertFalse(store.status.hasTrack)
  }

  func testPollingPolicySkipsStoppedProviders() {
    XCTAssertFalse(
      MediaPollingPolicy.shouldRead(
        applicationBundleIdentifier: "com.velnorr.test.not-running",
        source: .music,
        runningSources: []
      )
    )
    XCTAssertTrue(
      MediaPollingPolicy.shouldRead(
        applicationBundleIdentifier: "com.velnorr.test.running",
        source: .music,
        runningSources: [.music]
      )
    )
    XCTAssertTrue(
      MediaPollingPolicy.shouldRead(
        applicationBundleIdentifier: nil,
        source: .unknown,
        runningSources: []
      )
    )
  }

  private func snapshot(
    title: String,
    isPlaying: Bool,
    elapsed: TimeInterval,
    duration: TimeInterval
  ) -> NowPlayingSnapshot {
    NowPlayingSnapshot(
      trackKey: "track-1",
      artworkURL: nil,
      isPlaying: isPlaying,
      title: title,
      artist: "Artist",
      elapsed: elapsed,
      duration: duration
    )
  }
}

private final class TestNowPlayingProvider: NowPlayingProviding, @unchecked Sendable {
  let source = MusicSource.music
  private let lock = NSLock()
  private var storedSnapshot: NowPlayingSnapshot?

  var snapshot: NowPlayingSnapshot? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storedSnapshot
    }
    set {
      lock.lock()
      storedSnapshot = newValue
      lock.unlock()
    }
  }

  init(snapshot: NowPlayingSnapshot?) {
    storedSnapshot = snapshot
  }

  @MainActor var isInstalled: Bool { true }
  @MainActor var applicationIcon: NSImage? { nil }
  @MainActor func openApplication() {}

  func read(isRunning: Bool) async -> NowPlayingSnapshot? {
    lock.withLock { storedSnapshot }
  }

  func launchAndPlay() async {}
  func setPlaying(_ playing: Bool) async {}
  func perform(_ action: PlaybackAction) async {}
  func seek(to seconds: TimeInterval) async {}
  func openTrack(trackKey: String, title: String, artist: String) async {}
  func openArtist(name: String) async {}
}
