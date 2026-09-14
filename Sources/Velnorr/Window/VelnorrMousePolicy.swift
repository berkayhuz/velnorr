enum VelnorrMousePolicy {
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
