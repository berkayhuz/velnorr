import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ArtworkPayload: Sendable {
  let data: Data
  let color: ArtworkColor?
  let decodedByteCost: Int
}

struct ArtworkColor: Sendable {
  let red: Double
  let green: Double
  let blue: Double

  @MainActor var nsColor: NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
  }
}

actor ArtworkService {
  private final class CacheEntry: NSObject {
    let payload: ArtworkPayload

    init(payload: ArtworkPayload) {
      self.payload = payload
    }
  }

  private let cache = NSCache<NSURL, CacheEntry>()
  private var inFlight: [URL: Task<ArtworkPayload?, Never>] = [:]
  private let maximumDownloadSize = 10 * 1_024 * 1_024
  private let thumbnailMaxPixelSize = 160

  init() {
    cache.countLimit = 100
    cache.totalCostLimit = 50 * 1_024 * 1_024
  }

  func artwork(for url: URL) async -> ArtworkPayload? {
    if let cached = cache.object(forKey: url as NSURL) {
      return cached.payload
    }

    guard !Task.isCancelled else { return nil }

    if let task = inFlight[url] {
      return await task.value
    }

    let task = Task<ArtworkPayload?, Never> { [weak self] in
      guard let self else { return nil }
      return await self.downloadAndPrepareArtwork(from: url)
    }
    inFlight[url] = task
    let result = await task.value
    inFlight[url] = nil
    return result
  }

  private func downloadAndPrepareArtwork(from url: URL) async -> ArtworkPayload? {
    guard !Task.isCancelled else { return nil }

    let downloadSignpost = VelnorrPerformance.begin(.artworkDownload)
    let downloadResult = try? await URLSession.shared.data(from: url)
    VelnorrPerformance.end(.artworkDownload, downloadSignpost)

    guard !Task.isCancelled,
      let (data, response) = downloadResult,
      let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode),
      httpResponse.mimeType?.hasPrefix("image/") == true,
      httpResponse.expectedContentLength < 0
        || httpResponse.expectedContentLength <= maximumDownloadSize,
      data.count <= maximumDownloadSize
    else { return nil }

    let decodeSignpost = VelnorrPerformance.begin(.artworkDecode)
    let payload = Self.prepareArtwork(data: data, maxPixelSize: thumbnailMaxPixelSize)
    VelnorrPerformance.end(.artworkDecode, decodeSignpost)
    guard let payload else { return nil }
    cache.setObject(CacheEntry(payload: payload), forKey: url as NSURL, cost: payload.decodedByteCost)
    return payload
  }

  static func prepareArtwork(data: Data, maxPixelSize: Int) -> ArtworkPayload? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
      ),
      let data = pngData(for: image)
    else { return nil }

    return ArtworkPayload(
      data: data,
      color: dominantColor(from: image),
      decodedByteCost: max(1, image.bytesPerRow * image.height)
    )
  }

  private static func pngData(for image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    )
    else { return nil }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }

  private static func dominantColor(from image: CGImage) -> ArtworkColor? {
    let width = 5
    let height = 5
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard
      let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return nil }

    context.interpolationQuality = .low
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var red = 0.0
    var green = 0.0
    var blue = 0.0
    var count = 0.0
    for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index + 3] > 0 {
      red += Double(pixels[index]) / 255
      green += Double(pixels[index + 1]) / 255
      blue += Double(pixels[index + 2]) / 255
      count += 1
    }

    guard count > 0 else { return nil }
    return ArtworkColor(red: red / count, green: green / count, blue: blue / count)
  }
}
