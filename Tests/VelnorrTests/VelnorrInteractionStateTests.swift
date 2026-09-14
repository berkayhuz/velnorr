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
}
