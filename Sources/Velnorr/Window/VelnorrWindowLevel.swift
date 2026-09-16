import AppKit
import CoreGraphics

enum VelnorrWindowLevel {
  static var lockScreen: NSWindow.Level {
    NSWindow.Level(rawValue: Int(Int32.max - 2))
  }
}
