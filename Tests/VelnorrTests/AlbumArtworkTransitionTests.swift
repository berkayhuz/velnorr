import AppKit
import SwiftUI
import XCTest

@testable import Velnorr

@MainActor
final class AlbumArtworkTransitionTests: XCTestCase {
  func testImmediateAndLateArtworkFinishWithCurrentImageVisible() async throws {
    let model = ArtworkTestModel(
      image: solidImage(color: .red),
      trackKey: "track-one"
    )
    let hostingView = NSHostingView(rootView: ArtworkTestHarness(model: model))
    hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    let window = NSWindow(
      contentRect: hostingView.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.contentView = hostingView
    window.orderFrontRegardless()
    defer { window.close() }
    hostingView.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))

    model.image = solidImage(color: .blue)
    model.trackKey = "track-two"

    try await Task.sleep(for: .milliseconds(700))
    hostingView.layoutSubtreeIfNeeded()

    let color = try XCTUnwrap(centerColor(of: hostingView))
    XCTAssertGreaterThan(color.blueComponent, 0.8)
    XCTAssertLessThan(color.redComponent, 0.2)

    model.image = nil
    model.trackKey = "track-three"
    try await Task.sleep(for: .milliseconds(900))

    model.image = solidImage(color: .green)
    try await Task.sleep(for: .milliseconds(100))
    hostingView.layoutSubtreeIfNeeded()

    let lateColor = try XCTUnwrap(centerColor(of: hostingView))
    XCTAssertGreaterThan(lateColor.greenComponent, 0.8)
    XCTAssertGreaterThan(lateColor.greenComponent, lateColor.redComponent)
    XCTAssertGreaterThan(lateColor.greenComponent, lateColor.blueComponent)
  }

  private func solidImage(color: NSColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 20, height: 20))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 20, height: 20)).fill()
    image.unlockFocus()
    return image
  }

  private func centerColor(of view: NSView) -> NSColor? {
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?
      .usingColorSpace(.deviceRGB)
  }
}

@MainActor
private final class ArtworkTestModel: ObservableObject {
  @Published var image: NSImage?
  @Published var trackKey: String

  init(image: NSImage?, trackKey: String) {
    self.image = image
    self.trackKey = trackKey
  }
}

private struct ArtworkTestHarness: View {
  @ObservedObject var model: ArtworkTestModel

  var body: some View {
    AlbumArtworkView(image: model.image, trackKey: model.trackKey)
      .frame(width: 40, height: 40)
  }
}
