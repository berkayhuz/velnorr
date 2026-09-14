import XCTest
@testable import Velnorr

@MainActor
final class VelnorrRuntimeTests: XCTestCase {
  func testRuntimeKeepsOneStableInstancePerSharedService() {
    let runtime = VelnorrRuntime()

    let music = runtime.music
    let audioVolume = runtime.audioVolume
    let screenBrightness = runtime.screenBrightness
    let capsLock = runtime.capsLock
    let batteryCharge = runtime.batteryCharge
    let bluetoothConnection = runtime.bluetoothConnection
    let artworkService = runtime.artworkService

    XCTAssertTrue(music === runtime.music)
    XCTAssertTrue(audioVolume === runtime.audioVolume)
    XCTAssertTrue(screenBrightness === runtime.screenBrightness)
    XCTAssertTrue(capsLock === runtime.capsLock)
    XCTAssertTrue(batteryCharge === runtime.batteryCharge)
    XCTAssertTrue(bluetoothConnection === runtime.bluetoothConnection)
    XCTAssertTrue(artworkService === runtime.artworkService)
  }
}
