import AppKit
import XCTest

@testable import Velnorr

@MainActor
final class ResourceImagesTests: XCTestCase {
  func testStaticResourcesLoadAndShareInstances() {
    let images = (
      ResourceImages.battery,
      ResourceImages.appleMusicIcon,
      ResourceImages.spotifyIcon,
      ResourceImages.velnorrLogo,
      ResourceImages.huzstudioLogo
    )

    XCTAssertNotNil(images.0)
    XCTAssertNotNil(images.1)
    XCTAssertNotNil(images.2)
    XCTAssertNotNil(images.3)
    XCTAssertNotNil(images.4)

    let repeatedBattery = ResourceImages.battery
    XCTAssertTrue(images.0 === repeatedBattery)
  }
}
