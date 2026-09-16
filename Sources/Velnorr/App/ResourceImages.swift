import AppKit

@MainActor
enum ResourceImages {
  static let battery = load(resourceName: "Battery")
  static let appleMusicIcon = load(resourceName: "apple-music-icon")
  static let spotifyIcon = load(resourceName: "spotify-icon")
  static let velnorrLogo = load(resourceName: "velnorr-logo")
  static let huzstudioLogo = load(resourceName: "logo-huzstudio")

  private static func load(resourceName: String) -> NSImage? {
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: "svg")
    else { return nil }
    return NSImage(contentsOf: url)
  }
}
