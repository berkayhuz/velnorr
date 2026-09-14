import Foundation
import XCTest

@testable import Velnorr

final class LayoutAndSettingsTests: XCTestCase {
  func testCollapsedLayoutUsesMetricsWidth() {
    let metrics = NotchMetrics(centerGap: 0, displayMode: .pill, collapsedWidth: 132)
    let layout = VelnorrLayout(
      state: .collapsed,
      isArtworkHovered: false,
      hasTrack: true,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, 132)
  }

  func testPhysicalNotchCollapsedLayoutKeepsVisibleSideWings() {
    let physicalNotchWidth: CGFloat = 179
    let visibleWidth = max(
      NotchMetrics.minimumNotchCollapsedWidth,
      physicalNotchWidth + NotchMetrics.minimumNotchSideWidth * 2
    )
    let metrics = NotchMetrics(
      centerGap: physicalNotchWidth,
      displayMode: .notch,
      collapsedWidth: visibleWidth
    )
    let layout = VelnorrLayout(
      state: .collapsed,
      isArtworkHovered: false,
      hasTrack: true,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, 274)
    XCTAssertGreaterThan(layout.leftSideWidth, 40)
    XCTAssertGreaterThan(layout.rightSideWidth, 40)
  }

  func testPhysicalNotchHidesSideWingsWithoutMusic() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 260
    )
    let layout = VelnorrLayout(
      state: .collapsed,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, 179)
  }

  func testHoverExpandsNoMusicVelnorrByThirtyWidthAndOnePointFiveHeight() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 260
    )
    let layout = VelnorrLayout(
      state: .quickPeek,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, metrics.centerGap + 30)
    XCTAssertGreaterThan(layout.width, metrics.centerGap)
  }

  func testHoverKeepsNoMusicVelnorrInsidePhysicalNotch() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 260
    )
    let layout = VelnorrLayout(
      state: .quickPeek,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, metrics.centerGap + 30)
    XCTAssertEqual(layout.height, NotchMetrics.velnorrHeight + 1.5)
  }

  func testVolumeLayoutLeavesRoomOnBothSidesOfPhysicalNotch() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 260
    )
    let layout = VelnorrLayout(
      state: .volume,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, NotchMetrics.volumeWidth)
    XCTAssertGreaterThanOrEqual(layout.leftSideWidth, 120)
    XCTAssertGreaterThanOrEqual(layout.rightSideWidth, 120)
  }

  func testBatteryLayoutExpandsForPhysicalNotchContent() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 274
    )
    let layout = VelnorrLayout(
      state: .battery,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, 420)
    XCTAssertGreaterThanOrEqual(layout.leftSideWidth, NotchMetrics.batterySideContentWidth)
    XCTAssertGreaterThanOrEqual(layout.rightSideWidth, NotchMetrics.batterySideContentWidth)
  }

  func testDeviceConnectionLayoutLeavesRoomForIconAndBattery() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 280
    )
    let layout = VelnorrLayout(
      state: .deviceConnection,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.width, NotchMetrics.deviceConnectionWidth)
    XCTAssertEqual(layout.height, NotchMetrics.deviceConnectionHeight)
    XCTAssertGreaterThan(layout.leftSideWidth, 70)
    XCTAssertGreaterThan(layout.rightSideWidth, 70)
  }

  func testSettingsSnapshotUsesInjectedDefaults() throws {
    let suiteName = "VelnorrTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(false, forKey: AppSettings.showInFullscreen)
    defaults.set(VelnorrDisplayMode.simulatedNotch.rawValue, forKey: AppSettings.externalDisplayMode)

    let snapshot = AppSettingsSnapshot(userDefaults: defaults)

    XCTAssertFalse(snapshot.showInFullscreen)
    XCTAssertEqual(snapshot.externalDisplayMode, .simulatedNotch)
  }

  func testCapsLockHUDSizeUsesLargerDefaultAndScalesIcon() {
    let defaultDiameter = CapsLockHUDMetrics.diameter(from: 0)
    XCTAssertEqual(defaultDiameter, 38)
    XCTAssertEqual(CapsLockHUDMetrics.diameter(from: 48), 48)
    XCTAssertEqual(
      CapsLockHUDMetrics.iconSize(for: defaultDiameter),
      13 * (38.0 / 30.0),
      accuracy: 0.001
    )
  }

  func testCapsLockHUDSizeClampsInvalidStoredValues() {
    XCTAssertEqual(
      CapsLockHUDMetrics.diameter(from: 12),
      CapsLockHUDMetrics.minimumDiameter
    )
    XCTAssertEqual(
      CapsLockHUDMetrics.diameter(from: 100),
      CapsLockHUDMetrics.maximumDiameter
    )
  }

  func testSharedShapePathExcludesTransparentCorner() {
    let path = VelnorrShapePath.make(
      in: CGRect(x: 0, y: 0, width: 400, height: 175),
      topRadius: 34,
      bottomRadius: 34,
      isPill: false
    )

    XCTAssertFalse(path.contains(CGPoint(x: 399, y: 174)))
    XCTAssertTrue(path.contains(CGPoint(x: 200, y: 100)))
  }

  func testLockScreenWidgetLeaves36PointsAboveProfilePhotoAnchor() {
    let screenFrame = CGRect(x: -20, y: -10, width: 1470, height: 956)
    let widgetFrame = VelnorrLockScreenLayout.widgetFrame(for: screenFrame)
    let profilePhotoTop = VelnorrLockScreenLayout.profilePhotoTop(in: screenFrame)

    XCTAssertEqual(widgetFrame.minY - profilePhotoTop, 36, accuracy: 0.001)
    XCTAssertEqual(widgetFrame.midX, screenFrame.midX, accuracy: 0.001)
    XCTAssertEqual(widgetFrame.size, VelnorrLockScreenLayout.widgetSize)
  }
}
