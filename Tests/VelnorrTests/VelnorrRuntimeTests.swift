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
    let screenLock = runtime.screenLock
    let artworkService = runtime.artworkService
    let calendar = runtime.calendar
    let shelf = runtime.shelf
    let shelfActions = runtime.shelfActions
    let camera = runtime.camera

    XCTAssertTrue(music === runtime.music)
    XCTAssertTrue(audioVolume === runtime.audioVolume)
    XCTAssertTrue(screenBrightness === runtime.screenBrightness)
    XCTAssertTrue(capsLock === runtime.capsLock)
    XCTAssertTrue(batteryCharge === runtime.batteryCharge)
    XCTAssertTrue(bluetoothConnection === runtime.bluetoothConnection)
    XCTAssertTrue(screenLock === runtime.screenLock)
    XCTAssertTrue(artworkService === runtime.artworkService)
    XCTAssertTrue(calendar === runtime.calendar)
    XCTAssertTrue(shelf === runtime.shelf)
    XCTAssertTrue(shelfActions === runtime.shelfActions)
    XCTAssertTrue(camera === runtime.camera)
  }
}
