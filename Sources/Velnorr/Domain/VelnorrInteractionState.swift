struct VelnorrInteractionState: Equatable {
  private(set) var isOuterHovered = false
  private(set) var isArtworkHovered = false
  private(set) var isWorkAreaExpanded = false
  private(set) var isMediaExpanded = false
  private(set) var isPlaybackHovered = false

  var presentation: VelnorrPresentationState {
    if isMediaExpanded { return .media }
    if isWorkAreaExpanded { return .expanded }
    if isArtworkHovered || isOuterHovered { return .quickPeek }
    return .collapsed
  }

  mutating func showMedia() {
    isMediaExpanded = true
    isWorkAreaExpanded = false
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
    isWorkAreaExpanded = false
    isOuterHovered = true
  }

  mutating func endArtworkHover() {
    isArtworkHovered = false
  }

  mutating func toggleWorkArea() {
    guard !isMediaExpanded else { return }
    isWorkAreaExpanded.toggle()
    if !isWorkAreaExpanded { isOuterHovered = false }
  }

  mutating func setPlaybackHovered(_ hovered: Bool) {
    isPlaybackHovered = hovered
  }

  mutating func applyPlaybackChange(wasPlaying: Bool, collapseAfterPause: Bool) {
    guard collapseAfterPause else { return }
    if wasPlaying {
      isWorkAreaExpanded = false
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
