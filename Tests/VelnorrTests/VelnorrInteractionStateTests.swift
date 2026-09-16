import XCTest

@testable import Velnorr

final class VelnorrInteractionStateTests: XCTestCase {
  func testShowingMediaClearsConflictingInteractionState() {
    var state = VelnorrInteractionState()
    state.beginArtworkHover()
    state.setPlaybackHovered(true)

    state.showMedia()

    XCTAssertEqual(state.presentation, .media)
    XCTAssertFalse(state.isArtworkHovered)
    XCTAssertFalse(state.isWorkAreaExpanded)
    XCTAssertFalse(state.isPlaybackHovered)
  }

  func testDismissResetsEveryTransientState() {
    var state = VelnorrInteractionState()
    state.setOuterHovered(true)
    state.setPlaybackHovered(true)

    state.dismiss()

    XCTAssertEqual(state, VelnorrInteractionState())
    XCTAssertEqual(state.presentation, .collapsed)
  }

  func testWorkAreaToggleOpensAndClosesCalendarPanel() {
    var state = VelnorrInteractionState()

    state.toggleWorkArea()

    XCTAssertEqual(state.activePanel, .calendar)
    XCTAssertTrue(state.isWorkAreaExpanded)
    XCTAssertEqual(state.presentation, .expanded)

    state.toggleWorkArea()

    XCTAssertNil(state.activePanel)
    XCTAssertEqual(state.presentation, .collapsed)
  }

  func testUtilityPanelSwitchPreservesExpandedState() {
    var state = VelnorrInteractionState()

    state.showUtility(.shelf)
    XCTAssertEqual(state.activePanel, .shelf)
    XCTAssertTrue(state.hasExpandedPanel)

    state.showUtility(.mirror)
    XCTAssertEqual(state.activePanel, .mirror)
    XCTAssertTrue(state.isWorkAreaExpanded)
  }
}
