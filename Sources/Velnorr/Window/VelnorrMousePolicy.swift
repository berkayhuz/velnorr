import Foundation

enum VelnorrMousePolicy {
  static let mediaAutoDismissDelay: TimeInterval = 3
  static let fallbackIdlePollingInterval: TimeInterval = 1.0 / 4.0
  static let fallbackNearbyPollingInterval: TimeInterval = 1.0 / 20.0
  static let fallbackMediaPollingInterval: TimeInterval = 1.0 / 6.0

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

  static func shouldToggleCenter(
    displayMode: VelnorrDisplayMode,
    isExpanded: Bool,
    isLevelBarInteracting: Bool,
    location: CGPoint,
    frameSize: CGSize
  ) -> Bool {
    guard !isExpanded, !isLevelBarInteracting else { return false }
    let centerHalfWidth: CGFloat = displayMode == .pill ? 24 : 60
    return abs(location.x - frameSize.width / 2) <= centerHalfWidth
      && location.y >= frameSize.height - 45
      && location.y <= frameSize.height
  }

  static func shouldAutoDismissMedia(
    isMediaExpanded: Bool,
    pointerInsideMedia: Bool
  ) -> Bool {
    isMediaExpanded && !pointerInsideMedia
  }
}
