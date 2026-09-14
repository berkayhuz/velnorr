import XCTest
@testable import Velnorr

@MainActor
final class BatteryChargeStoreTests: XCTestCase {
  func testFallbackPollingIsLongAndTolerant() {
    XCTAssertEqual(BatteryChargeStore.fallbackPollingInterval, 60)
    XCTAssertGreaterThanOrEqual(
      BatteryChargeStore.fallbackPollingTolerance,
      BatteryChargeStore.fallbackPollingInterval * 0.1
    )
  }

  func testPreviewStoreCanRestartAndStopWithoutRetainingPreviewTask() {
    let store = BatteryChargeStore(preview: true)

    store.start()
    store.stop()
    store.start()
    store.stop()

    XCTAssertFalse(store.isVisible)
  }

  func testSystemStoreCanRestartAndStopItsPowerSourceObserver() {
    let store = BatteryChargeStore(preview: false)

    store.start()
    store.stop()
    store.start()
    store.stop()
  }
}
