import CoreGraphics

/// Resolves the visible velnorr geometry for a presentation state.
struct VelnorrLayout: Equatable {
  let width: CGFloat
  let height: CGFloat
  let topRadius: CGFloat
  let bottomRadius: CGFloat
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let horizontalOffset: CGFloat

  init(
    state: VelnorrPresentationState,
    isArtworkHovered: Bool,
    hasTrack: Bool,
    metrics: NotchMetrics
  ) {
    let baseWidth: CGFloat
    switch state {
    case .collapsed:
      baseWidth = metrics.collapsedWidth(hasTrack: hasTrack)
      height = metrics.displayMode == .pill
        ? NotchMetrics.pillCollapsedHeight
        : NotchMetrics.velnorrHeight
      topRadius = metrics.topRadius
      bottomRadius = NotchMetrics.collapsedBottomRadius
    case .quickPeek:
      if hasTrack {
        if metrics.displayMode == .pill {
          // Floating notchless HUDs keep one stable height while the track
          // details move into the horizontal space between both controls.
          baseWidth = isArtworkHovered ? NotchMetrics.nowPlayingWidth : NotchMetrics.expandedWidth
          height = NotchMetrics.expandedHeight
        } else {
          baseWidth = isArtworkHovered ? NotchMetrics.nowPlayingWidth : NotchMetrics.expandedWidth
          height = isArtworkHovered ? NotchMetrics.nowPlayingHeight : NotchMetrics.expandedHeight
        }
        topRadius = isArtworkHovered ? NotchMetrics.nowPlayingRadius : NotchMetrics.quickPeekRadius
        bottomRadius = topRadius
      } else {
  baseWidth = metrics.collapsedWidth(hasTrack: false) + 30
  height = NotchMetrics.velnorrHeight + 1.5

  topRadius = metrics.displayMode == .pill
    ? NotchMetrics.pillCollapsedRadius
    : metrics.topRadius

  bottomRadius = metrics.displayMode == .pill
    ? NotchMetrics.pillCollapsedRadius
    : NotchMetrics.collapsedBottomRadius
}
    case .volume:
      baseWidth = NotchMetrics.volumeWidth
      height = NotchMetrics.volumeHeight
      topRadius = NotchMetrics.quickPeekRadius
      bottomRadius = topRadius
    case .brightness:
      baseWidth = NotchMetrics.brightnessWidth
      height = NotchMetrics.brightnessHeight
      topRadius = NotchMetrics.quickPeekRadius
      bottomRadius = topRadius
    case .battery:
      // Keep both labels fully readable on a physical notch. The minimum
      // width is a fallback for simulated displays; on a real notch the
      // center gap plus both content areas determines the width.
      baseWidth = max(
        NotchMetrics.batteryWidth,
        metrics.centerGap + NotchMetrics.batterySideContentWidth * 2
      )
      height = NotchMetrics.batteryHeight
      topRadius = NotchMetrics.quickPeekRadius
      bottomRadius = topRadius
    case .deviceConnection:
      baseWidth = NotchMetrics.deviceConnectionWidth
      height = NotchMetrics.deviceConnectionHeight
      topRadius = NotchMetrics.quickPeekRadius
      bottomRadius = topRadius
    case .expanded, .media:
      baseWidth =
        state == .media
          ? (metrics.displayMode == .pill
            ? NotchMetrics.pillExpandedWidth
            : NotchMetrics.notchExpandedWidth)
          : NotchMetrics.interactionWidth
      height = NotchMetrics.interactionHeight
      let radius = metrics.displayMode == .pill
        ? NotchMetrics.pillExpandedRadius
        : NotchMetrics.notchExpandedRadius
      topRadius = radius
      bottomRadius = radius
    }

    let leftExpansion: CGFloat = 0
    let rightExpansion: CGFloat = 0

    width = baseWidth + leftExpansion + rightExpansion
    horizontalOffset = (rightExpansion - leftExpansion) / 2
    centerGap = min(metrics.centerGap, max(0, baseWidth - 64))
    let baseSideWidth = max(12, (baseWidth - centerGap) / 2)
    leftSideWidth = baseSideWidth + leftExpansion
    rightSideWidth = baseSideWidth + rightExpansion
  }
}
