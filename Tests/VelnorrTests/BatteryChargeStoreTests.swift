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

  func testBatteryThresholdNotificationsDefaultToTenPercentagePoints() {
    XCTAssertEqual(BatteryChargeStore.defaultBatteryThresholdInterval, 10)
    XCTAssertNil(notificationMode(currentLevel: 63, previousLevel: 64))
    XCTAssertEqual(
      notificationMode(currentLevel: 60, previousLevel: 61),
      .threshold
    )
    XCTAssertNil(notificationMode(currentLevel: 59, previousLevel: 60))
    XCTAssertNil(notificationMode(currentLevel: 79, previousLevel: 80))
  }

  func testUnpluggedNotificationOnlyAppearsWhenPowerStateChanges() {
    XCTAssertEqual(
      notificationMode(
        currentLevel: 64,
        previousLevel: 64,
        currentIsPluggedIn: false,
        previousIsPluggedIn: true
      ),
      .unplugged
    )
    XCTAssertNil(
      notificationMode(
        currentLevel: 63,
        previousLevel: 64,
        currentIsPluggedIn: false,
        previousIsPluggedIn: false
      )
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

  private func notificationMode(
    currentLevel: Int,
    previousLevel: Int,
    currentIsPluggedIn: Bool = false,
    previousIsPluggedIn: Bool = false
  ) -> BatteryChargeStore.HUDMode? {
    BatteryChargeStore.notificationMode(
      current: BatteryChargeStore.Snapshot(
        level: currentLevel,
        isCharging: currentIsPluggedIn,
        isPluggedIn: currentIsPluggedIn
      ),
      previous: BatteryChargeStore.Snapshot(
        level: previousLevel,
        isCharging: previousIsPluggedIn,
        isPluggedIn: previousIsPluggedIn
      ),
      lowBatteryThreshold: 20,
      greenBatteryThreshold: 80
    )
  }
}
