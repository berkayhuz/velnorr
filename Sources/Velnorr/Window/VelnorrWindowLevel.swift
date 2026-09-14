import AppKit
import CoreGraphics

enum VelnorrWindowLevel {
  static var lockScreen: NSWindow.Level {
    NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
  }
}
