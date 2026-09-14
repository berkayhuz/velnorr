import XCTest

@testable import Velnorr

final class PerformanceSignpostsTests: XCTestCase {
  func testCatalogMatchesPerformanceAuditMeasurementPoints() {
    XCTAssertEqual(
      VelnorrPerformanceSignpost.allCases.map { String(describing: $0.staticName) },
      [
        "media.refresh",
        "applescript.execute",
        "artwork.download",
        "artwork.decode",
        "battery.read",
        "bluetooth.system_profiler",
        "window.mouse.refresh",
        "shell.presentation.transition",
      ]
    )
  }

  func testCatalogCanEmitAndCloseEveryMeasurementPoint() {
    for name in VelnorrPerformanceSignpost.allCases {
      let state = VelnorrPerformance.begin(name)
      VelnorrPerformance.end(name, state)
      VelnorrPerformance.emit(name)
    }
  }
}
