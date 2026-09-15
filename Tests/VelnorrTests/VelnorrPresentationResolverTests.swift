@testable import Velnorr
import XCTest

final class VelnorrPresentationResolverTests: XCTestCase {
  func testDisabledVolumeDoesNotChangeLayout() {
    XCTAssertEqual(resolve(volumeEnabled: false, volumeVisible: true), .collapsed)
  }

  func testDisabledBrightnessDoesNotChangeLayout() {
    XCTAssertEqual(resolve(brightnessEnabled: false, brightnessVisible: true), .collapsed)
  }

  func testDisabledBatteryDoesNotChangeLayout() {
    XCTAssertEqual(resolve(batteryEnabled: false, batteryVisible: true), .collapsed)
  }

  func testDisabledDeviceDoesNotChangeLayout() {
    XCTAssertEqual(resolve(deviceEnabled: false, deviceVisible: true), .collapsed)
  }

  func testOverlayPriorityMatchesVisibleContentPriority() {
    XCTAssertEqual(
      resolve(
        volumeEnabled: true,
        volumeVisible: true,
        batteryEnabled: true,
        batteryVisible: true,
        brightnessEnabled: true,
        brightnessVisible: true
      ),
      .volume
    )
  }

  func testBrightnessBecomesTheNextPresentationAfterVolumeDisappears() {
    let volumePresentation = resolve(
      volumeEnabled: true,
      volumeVisible: true,
      brightnessEnabled: true,
      brightnessVisible: true
    )
    let brightnessPresentation = resolve(
      volumeEnabled: true,
      volumeVisible: false,
      brightnessEnabled: true,
      brightnessVisible: true
    )

    XCTAssertEqual(volumePresentation, .volume)
    XCTAssertEqual(brightnessPresentation, .brightness)
    XCTAssertNotEqual(volumePresentation, brightnessPresentation)
  }

  private func resolve(
    deviceEnabled: Bool = false,
    deviceVisible: Bool = false,
    volumeEnabled: Bool = false,
    volumeVisible: Bool = false,
    batteryEnabled: Bool = false,
    batteryVisible: Bool = false,
    brightnessEnabled: Bool = false,
    brightnessVisible: Bool = false
  ) -> VelnorrPresentationState {
    VelnorrPresentationResolver.resolve(
      base: .collapsed,
      isMediaExpanded: false,
      deviceEnabled: deviceEnabled,
      deviceVisible: deviceVisible,
      volumeEnabled: volumeEnabled,
      volumeVisible: volumeVisible,
      batteryEnabled: batteryEnabled,
      batteryVisible: batteryVisible,
      brightnessEnabled: brightnessEnabled,
      brightnessVisible: brightnessVisible,
      automaticTrackPeekVisible: false,
      hasTrack: false
    )
  }
}
