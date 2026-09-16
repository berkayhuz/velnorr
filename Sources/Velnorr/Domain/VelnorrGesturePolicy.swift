import CoreGraphics

enum VelnorrGesturePolicy {
  static let defaultSensitivity: CGFloat = 120

  static func progress(
    translation: CGFloat,
    sensitivity: CGFloat,
    direction: Direction
  ) -> CGFloat {
    let distance = direction == .down ? translation : -translation
    guard distance > 0, sensitivity > 0 else { return 0 }
    return min(1, distance / sensitivity)
  }

  static func shouldTrigger(
    translation: CGFloat,
    sensitivity: CGFloat,
    direction: Direction
  ) -> Bool {
    progress(translation: translation, sensitivity: sensitivity, direction: direction) >= 1
  }

  enum Direction: Sendable {
    case up
    case down
  }
}
