import XCTest
@testable import Velnorr

final class VelnorrTimelineCadenceTests: XCTestCase {
  func testTimelineCadencesStayWithinThePerformanceBudget() {
    XCTAssertEqual(VelnorrTimelineCadence.waveformInterval, 1.0 / 15.0, accuracy: 0.0001)
    XCTAssertEqual(VelnorrTimelineCadence.progressInterval, 0.1, accuracy: 0.0001)
    XCTAssertEqual(VelnorrTimelineCadence.durationLabelInterval, 1.0, accuracy: 0.0001)
    XCTAssertEqual(VelnorrTimelineCadence.marqueeInterval, 1.0 / 15.0, accuracy: 0.0001)
    XCTAssertEqual(VelnorrTimelineCadence.expandedMarqueeInterval, 1.0 / 60.0, accuracy: 0.0001)
  }
}
