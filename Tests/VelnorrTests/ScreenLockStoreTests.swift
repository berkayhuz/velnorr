import AppKit
import CoreGraphics
import XCTest

@testable import Velnorr

@MainActor
final class ScreenLockStoreTests: XCTestCase {
  func testSessionDictionaryRecognizesLockedState() {
    XCTAssertTrue(
      ScreenLockStore.isLocked(in: ["CGSSessionScreenIsLocked": true])
    )
    XCTAssertTrue(
      ScreenLockStore.isLocked(in: ["kCGSessionScreenIsLocked": true])
    )
  }

  func testMissingOrMalformedLockStateFailsSafeToUnlocked() {
    XCTAssertFalse(ScreenLockStore.isLocked(in: [:]))
    XCTAssertFalse(
      ScreenLockStore.isLocked(in: ["CGSSessionScreenIsLocked": "true"])
    )
    XCTAssertFalse(
      ScreenLockStore.isLocked(in: ["CGSSessionScreenIsLocked": false])
    )
  }

  func testStartAndStopAreIdempotent() {
    let store = ScreenLockStore()

    store.start()
    store.start()
    store.stop()
    store.stop()

    XCTAssertFalse(store.isLocked)
  }

  func testDistributedNotificationNamesAreStable() {
    XCTAssertEqual(
      ScreenLockStore.screenLockedNotification.rawValue,
      "com.apple.screenIsLocked"
    )
    XCTAssertEqual(
      ScreenLockStore.screenUnlockedNotification.rawValue,
      "com.apple.screenIsUnlocked"
    )
  }

  func testLockScreenWindowLevelUsesMaximumWindowLevel() {
    XCTAssertEqual(
      VelnorrWindowLevel.lockScreen.rawValue,
      Int(Int32.max - 2)
    )
  }

  func testLockScreenSpaceUsesTheSystemLockScreenLevel() {
    XCTAssertEqual(VelnorrLockScreenSpaceManager.lockScreenSpaceLevel, 400)
  }

  func testLockScreenPresentationStartsWhenTrackArrivesAfterSpaceIsReady() {
    var state = VelnorrLockScreenPresentationState()

    XCTAssertFalse(state.markReady())
    XCTAssertTrue(state.updateTrackAvailability(true))
    XCTAssertFalse(state.updateTrackAvailability(true))
  }

  func testLockScreenPresentationStartsWhenSpaceBecomesReadyAfterTrack() {
    var state = VelnorrLockScreenPresentationState()

    XCTAssertFalse(state.updateTrackAvailability(true))
    XCTAssertTrue(state.markReady())
    XCTAssertFalse(state.markReady())
  }

  func testSkyLightUsesVersionIndependentFrameworkPathFirst() {
    XCTAssertEqual(
      VelnorrLockScreenSpaceManager.skyLightFrameworkPaths,
      [
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
      ]
    )
  }
}
