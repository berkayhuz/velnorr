import XCTest

@testable import Velnorr

@MainActor
final class AppleScriptExecutorTests: XCTestCase {
  func testExecutesABoundedScriptOnMainActor() {
    let executor = AppleScriptExecutor()

    XCTAssertEqual(
      executor.execute("return \"ok\"", operation: "test bounded script"),
      "ok"
    )
  }
}
