import AppKit
import Foundation
import ImageIO

struct ArtworkPayload: Sendable {
  let data: Data
  let color: ArtworkColor?
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
  private let maximumDownloadSize = 10 * 1_024 * 1_024

  init() {
    cache.countLimit = 100
    cache.totalCostLimit = 50 * 1_024 * 1_024
  }

  func artwork(for url: URL) async -> ArtworkPayload? {
    if let cached = cache.object(forKey: url as NSURL) {
      return cached.payload
    }

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
    let color = dominantColor(from: data)
    VelnorrPerformance.end(.artworkDecode, decodeSignpost)
    let payload = ArtworkPayload(data: data, color: color)
    cache.setObject(CacheEntry(payload: payload), forKey: url as NSURL, cost: data.count)
    return payload
  }

  private func dominantColor(from data: Data) -> ArtworkColor? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }

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
