import AppKit

@MainActor
enum MediaApplicationCache {
  private static var applicationURLs: [String: URL] = [:]
  private static var applicationIcons: [String: NSImage] = [:]

  static func url(for bundleIdentifier: String) -> URL? {
    if let cached = applicationURLs[bundleIdentifier] {
      return cached
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else { return nil }
    applicationURLs[bundleIdentifier] = url
    return url
  }

  static func icon(for bundleIdentifier: String, resourceName: String) -> NSImage? {
    if let cached = applicationIcons[bundleIdentifier] {
      return cached
    }
    let image: NSImage?
    switch resourceName {
    case "apple-music-icon": image = ResourceImages.appleMusicIcon
    case "spotify-icon": image = ResourceImages.spotifyIcon
    default: image = nil
    }
    guard let image else { return nil }
    applicationIcons[bundleIdentifier] = image
    return image
  }
}
