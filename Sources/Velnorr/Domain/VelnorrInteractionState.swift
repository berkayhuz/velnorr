struct VelnorrInteractionState: Equatable {
  private(set) var isOuterHovered = false
  private(set) var isArtworkHovered = false
  private(set) var activePanel: VelnorrUtilityPanel?
  private(set) var isPlaybackHovered = false

  var isWorkAreaExpanded: Bool {
    activePanel != nil && activePanel != .media
  }

  var isMediaExpanded: Bool {
    activePanel == .media
  }

  var hasExpandedPanel: Bool {
    activePanel != nil
  }

  var presentation: VelnorrPresentationState {
    if isMediaExpanded { return .media }
    if isWorkAreaExpanded { return .expanded }
    if isArtworkHovered || isOuterHovered { return .quickPeek }
    return .collapsed
  }

  mutating func showMedia() {
    activePanel = .media
    isArtworkHovered = false
    isPlaybackHovered = false
  }

  mutating func showUtility(_ panel: VelnorrUtilityPanel) {
    guard panel != .media else {
      showMedia()
      return
    }
    activePanel = panel
    isOuterHovered = false
    isArtworkHovered = false
    isPlaybackHovered = false
  }

  mutating func dismiss() {
    self = VelnorrInteractionState()
  }

  mutating func setOuterHovered(_ hovered: Bool) {
    guard !isMediaExpanded else { return }
    isOuterHovered = hovered
  }

  mutating func beginArtworkHover() {
    guard !isMediaExpanded else { return }
    isArtworkHovered = true
    activePanel = nil
    isOuterHovered = true
  }

  mutating func endArtworkHover() {
    isArtworkHovered = false
  }

  mutating func toggleWorkArea() {
    guard !isMediaExpanded else { return }
    if isWorkAreaExpanded {
      dismiss()
    } else {
      showUtility(.calendar)
    }
  }

  mutating func setPlaybackHovered(_ hovered: Bool) {
    isPlaybackHovered = hovered
  }

  mutating func applyPlaybackChange(wasPlaying: Bool, collapseAfterPause: Bool) {
    guard collapseAfterPause else { return }
    if wasPlaying {
      activePanel = nil
      isOuterHovered = false
      isPlaybackHovered = false
    } else {
      isOuterHovered = true
      isPlaybackHovered = true
    }
  }

  mutating func disableHoverExpansion() {
    isOuterHovered = false
    isArtworkHovered = false
  }
}
