import XCTest

@testable import Velnorr

final class BluetoothConnectionStoreTests: XCTestCase {
  func testBeatsAudioDeviceUsesBeatsIcon() {
    let device = ConnectedAppleDevice(
      name: "Beats Studio Pro",
      kind: .speaker,
      batteryPercentage: nil
    )

    XCTAssertEqual(device.symbolName, "beats.headphones")
  }

  func testGenericSpeakerUsesSpeakerIcon() {
    let device = ConnectedAppleDevice(
      name: "Portable Speaker",
      kind: .speaker,
      batteryPercentage: nil
    )

    XCTAssertEqual(device.symbolName, "speaker.wave.2.fill")
  }

  func testBeatsNameIsClassifiedAsSpeakerWithoutDeviceClassMetadata() {
    XCTAssertEqual(
      BluetoothConnectionStore.kind(for: "Beats Studio Pro", classOfDevice: 0),
      .speaker
    )
  }
}
