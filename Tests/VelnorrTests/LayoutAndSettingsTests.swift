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
    defaults.set(VelnorrNotchHeightMode.custom.rawValue, forKey: AppSettings.notchHeightMode)
    defaults.set(48.0, forKey: AppSettings.notchHeight)

    let snapshot = AppSettingsSnapshot(userDefaults: defaults)

    XCTAssertFalse(snapshot.showInFullscreen)
    XCTAssertEqual(snapshot.externalDisplayMode, .simulatedNotch)
    XCTAssertEqual(snapshot.notchHeightMode, .custom)
    XCTAssertEqual(snapshot.notchHeight, 48)
  }

  func testNotchHeightConfigurationUsesFallbackAndBoundsCustomValues() {
    let configuration = VelnorrNotchHeightConfiguration(
      notchMode: .custom,
      nonNotchMode: .menuBar,
      notchHeight: 90,
      nonNotchHeight: 32
    )

    XCTAssertEqual(
      configuration.height(
        for: .system,
        systemHeight: 0,
        fallback: 32,
        customHeight: 32
      ),
      32
    )
    XCTAssertEqual(
      configuration.height(
        for: .custom,
        systemHeight: 38,
        fallback: 32,
        customHeight: configuration.notchHeight
      ),
      64
    )
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

  func testExpandedUtilityContentInsetStaysInsideRoundedSurfaceSides() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 274
    )
    let layout = VelnorrLayout(
      state: .expanded,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )
    let contentInset = min(layout.topRadius + 12, layout.width / 2)
    let path = VelnorrShapePath.make(
      in: CGRect(x: 0, y: 0, width: layout.width, height: layout.height),
      topRadius: layout.topRadius,
      bottomRadius: layout.bottomRadius,
      isPill: false
    )

    XCTAssertEqual(contentInset, 46)
    XCTAssertTrue(path.contains(CGPoint(x: contentInset, y: 80)))
    XCTAssertFalse(path.contains(CGPoint(x: layout.topRadius - 1, y: 80)))
  }

  func testUtilityContentStartsBelowPhysicalNotchOnly() {
    let physicalMetrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 274,
      collapsedHeight: 32,
      physicalNotchHeight: 38
    )
    let pillMetrics = NotchMetrics(
      centerGap: 0,
      displayMode: .pill,
      collapsedWidth: 136
    )

    XCTAssertEqual(physicalMetrics.physicalNotchContentTopInset, 38)
    XCTAssertEqual(
      physicalMetrics.utilityContentTopInset,
      38 + NotchMetrics.utilityContentSpacing
    )
    XCTAssertEqual(pillMetrics.physicalNotchContentTopInset, 0)
    XCTAssertEqual(pillMetrics.utilityContentTopInset, 0)
  }

  func testUtilityLayoutHasRoomForNotchInsetAndPanelContent() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 274,
      collapsedHeight: 38,
      physicalNotchHeight: 38
    )
    let layout = VelnorrLayout(
      state: .expanded,
      isArtworkHovered: false,
      hasTrack: false,
      metrics: metrics
    )

    XCTAssertEqual(layout.height, NotchMetrics.utilityHeight)
    XCTAssertGreaterThan(layout.height, NotchMetrics.interactionHeight)
    XCTAssertGreaterThan(
      layout.height - metrics.utilityContentTopInset - 14,
      200
    )
    XCTAssertGreaterThanOrEqual(metrics.windowHeight, layout.height)
  }

  func testMediaLayoutStartsBelowPhysicalNotchAndFitsCanvas() {
    let metrics = NotchMetrics(
      centerGap: 179,
      displayMode: .notch,
      collapsedWidth: 274,
      collapsedHeight: 38,
      physicalNotchHeight: 38
    )
    let layout = VelnorrLayout(
      state: .media,
      isArtworkHovered: false,
      hasTrack: true,
      metrics: metrics
    )

    XCTAssertEqual(metrics.mediaContentTopInset, 38)
    XCTAssertEqual(metrics.mediaContentOffset, metrics.mediaContentTopInset)
    XCTAssertEqual(
      metrics.mediaContentOffset + NotchMetrics.mediaHeaderTopOffset,
      metrics.physicalNotchContentTopInset + 8
    )
    XCTAssertEqual(
      VelnorrPanelNavigationLayout.physicalGap(
        displayMode: metrics.displayMode,
        centerGap: metrics.centerGap,
        availableWidth: NotchMetrics.notchExpandedWidth
      ),
      metrics.centerGap
    )
    XCTAssertEqual(
      VelnorrPanelNavigationLayout.sideWidth(
        displayMode: metrics.displayMode,
        centerGap: metrics.centerGap,
        availableWidth: NotchMetrics.notchExpandedWidth
      ),
      (NotchMetrics.notchExpandedWidth - metrics.centerGap) / 2
    )
    XCTAssertEqual(
      VelnorrPanelNavigationLayout.physicalGap(
        displayMode: .pill,
        centerGap: metrics.centerGap,
        availableWidth: NotchMetrics.pillExpandedWidth
      ),
      0
    )
    XCTAssertEqual(layout.height, metrics.mediaHeight)
    XCTAssertGreaterThan(layout.height, NotchMetrics.interactionHeight)
    XCTAssertGreaterThanOrEqual(metrics.windowHeight, layout.height)
  }

  func testLockScreenWidgetLeaves36PointsAboveProfilePhotoAnchor() {
    let screenFrame = CGRect(x: -20, y: -10, width: 1470, height: 956)
    let widgetFrame = VelnorrLockScreenLayout.widgetFrame(for: screenFrame)
    let profilePhotoTop = VelnorrLockScreenLayout.profilePhotoTop(in: screenFrame)

    XCTAssertEqual(widgetFrame.minY - profilePhotoTop, 36, accuracy: 0.001)
    XCTAssertEqual(widgetFrame.midX, screenFrame.midX, accuracy: 0.001)
    XCTAssertEqual(widgetFrame.size, VelnorrLockScreenLayout.widgetSize)
  }

  func testLockScreenLockIconIsCenteredInLeadingSide() {
    XCTAssertEqual(
      VelnorrLockScreenLayout.lockIconX(
        width: 68,
        topRadius: 12,
        centerGap: 0
      ),
      34,
      accuracy: 0.001
    )
    XCTAssertEqual(
      VelnorrLockScreenLayout.lockIconX(
        width: 63,
        topRadius: 12,
        centerGap: 148
      ),
      37.5,
      accuracy: 0.001
    )
  }

  func testLockScreenRightIconIsCenteredInTrailingSide() {
    XCTAssertEqual(
      VelnorrLockScreenLayout.sideIconX(
        width: 63,
        topRadius: 12,
        centerGap: 148,
        isLeading: false
      ),
      25.5,
      accuracy: 0.001
    )
    XCTAssertEqual(
      VelnorrLockScreenLayout.sideIconX(
        width: 68,
        topRadius: 12,
        centerGap: 0,
        isLeading: false
      ),
      34,
      accuracy: 0.001
    )
  }

  func testLockScreenRightIconSettingsHaveSafeDefaultsAndFallbacks() {
    XCTAssertEqual(AppSettings.defaultLockScreenRightIcon, "face.smiling")
    XCTAssertEqual(AppSettings.defaultLockScreenRightIconColor, "white")
    XCTAssertEqual(
      LockScreenRightIconResolver.symbol(for: "face.smiling"),
      "face.smiling"
    )
    XCTAssertEqual(
      LockScreenRightIconResolver.symbol(for: "not-a-symbol"),
      AppSettings.defaultLockScreenRightIcon
    )
    XCTAssertEqual(
      LockScreenRightIconResolver.symbol(for: ""),
      AppSettings.defaultLockScreenRightIcon
    )
    XCTAssertEqual(
      LockScreenRightIconResolver.color(for: "not-a-color"),
      LockScreenRightIconColorOption.white.color
    )
  }

  func testLockScreenRightIconColorsIncludeAppleSystemPalette() {
    let expectedSystemColors: [LockScreenRightIconColorOption] = [
      .red, .orange, .yellow, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .gray,
    ]

    XCTAssertEqual(expectedSystemColors.count, 12)
    XCTAssertEqual(
      Set(LockScreenRightIconColorOption.allCases),
      Set([.white, .accent, .green] + expectedSystemColors)
    )

    for option in expectedSystemColors {
      XCTAssertEqual(
        LockScreenRightIconResolver.color(for: option.rawValue),
        option.color,
        "Resolver should support the \(option.rawValue) system color"
      )
    }
  }
}
