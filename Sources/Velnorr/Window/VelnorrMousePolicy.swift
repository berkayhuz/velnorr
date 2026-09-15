import Foundation

enum VelnorrMousePolicy {
  static let mediaAutoDismissDelay: TimeInterval = 3

  static func acceptsPointerNotification(
    displayID: UInt32?,
    targetDisplayID: UInt32
  ) -> Bool {
    displayID == targetDisplayID
  }

  static func ignoresMouseEvents(
    isMediaExpanded: Bool,
    isLevelBarInteracting: Bool = false,
    pointerInsideShape: Bool
  ) -> Bool {
    if isMediaExpanded || isLevelBarInteracting {
      return false
    }
    return !pointerInsideShape
  }

  static func shouldAutoDismissMedia(
    isMediaExpanded: Bool,
    pointerInsideMedia: Bool
  ) -> Bool {
    isMediaExpanded && !pointerInsideMedia
  }
}
