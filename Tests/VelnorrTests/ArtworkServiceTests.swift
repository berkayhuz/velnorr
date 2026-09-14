import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import Velnorr

final class ArtworkServiceTests: XCTestCase {
  func testPrepareArtworkDownsamplesAndStoresDecodedCost() throws {
    let sourceData = try makePNG(width: 640, height: 640)
    let payload = try XCTUnwrap(ArtworkService.prepareArtwork(data: sourceData, maxPixelSize: 160))
    let source = try XCTUnwrap(CGImageSourceCreateWithData(payload.data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

    XCTAssertLessThanOrEqual(max(image.width, image.height), 160)
    XCTAssertEqual(payload.decodedByteCost, image.bytesPerRow * image.height)
    XCTAssertNotNil(payload.color)
  }

  func testPrepareArtworkRejectsInvalidData() {
    XCTAssertNil(ArtworkService.prepareArtwork(data: Data("not-an-image".utf8), maxPixelSize: 160))
  }

  private func makePNG(width: Int, height: Int) throws -> Data {
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }
}
