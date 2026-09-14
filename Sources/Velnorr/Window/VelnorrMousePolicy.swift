enum VelnorrMousePolicy {
  static func acceptsPointerNotification(
    displayID: UInt32?,
    targetDisplayID: UInt32
  ) -> Bool {
    displayID == targetDisplayID
  }

  static func ignoresMouseEvents(
    isMediaExpanded: Bool,
    pointerInsideShape: Bool
  ) -> Bool {
    if isMediaExpanded {
      return false
    }
    return !pointerInsideShape
  }
}
