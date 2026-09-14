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
      Int(CGWindowLevelForKey(.maximumWindow))
    )
  }
}
