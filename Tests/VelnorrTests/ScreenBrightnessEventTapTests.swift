import XCTest

@testable import Velnorr

final class ScreenBrightnessEventTapTests: XCTestCase {
  func testSystemDefinedBrightnessEventsPreserveDirectionAndKeyState() {
    let increaseDown = (Int64(2) << 16) | (Int64(0x0A) << 8)
    let decreaseUp = (Int64(3) << 16) | (Int64(0x0B) << 8)

    let increase = SystemBrightnessEventTap.parse(increaseDown)
    XCTAssertEqual(increase?.event, .increase)
    XCTAssertEqual(increase?.isDown, true)

    let decrease = SystemBrightnessEventTap.parse(decreaseUp)
    XCTAssertEqual(decrease?.event, .decrease)
    XCTAssertEqual(decrease?.isDown, false)
  }

  func testSystemDefinedBrightnessParserRejectsUnrecognizedEvents() {
    let unknownKey = (Int64(4) << 16) | (Int64(0x0A) << 8)
    let unknownState = (Int64(2) << 16) | (Int64(0x0C) << 8)

    XCTAssertNil(SystemBrightnessEventTap.parse(unknownKey))
    XCTAssertNil(SystemBrightnessEventTap.parse(unknownState))
  }
}
