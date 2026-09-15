import CoreGraphics
import XCTest

@testable import Velnorr

final class HUDLevelInteractionTests: XCTestCase {
  func testValueClampsPointerPositionToTheBar() {
    XCTAssertEqual(HUDLevelInteraction.value(for: -10, width: 100), 0)
    XCTAssertEqual(HUDLevelInteraction.value(for: 35, width: 100), 0.35)
    XCTAssertEqual(HUDLevelInteraction.value(for: 120, width: 100), 1)
    XCTAssertEqual(HUDLevelInteraction.value(for: 35, width: 0), 0)
  }

  func testHoverExpansionStaysWithinAvailableSideWidth() {
    XCTAssertEqual(
      HUDLevelInteraction.expandedWidth(baseWidth: 52, availableWidth: 100),
      76
    )
    XCTAssertEqual(
      HUDLevelInteraction.expandedWidth(baseWidth: 52, availableWidth: 60),
      60
    )
    XCTAssertEqual(
      HUDLevelInteraction.expandedWidth(baseWidth: 52, availableWidth: 40),
      52
    )
    XCTAssertEqual(HUDLevelInteraction.hoverScale, 1.05)
  }
}
