import AppKit

struct NotchMetrics {
  static let velnorrHeight: CGFloat = 32
  // Compact height used only by floating, notchless displays.
  static let pillCollapsedHeight: CGFloat = 24
  static let expandedWidth: CGFloat = 310
  static let expandedHeight: CGFloat = 36
  // The volume HUD needs more room than the launcher peek: the left label
  // and right level bar should breathe around the physical notch.
  static let volumeWidth: CGFloat = 420
  static let volumeHeight: CGFloat = 36
  static let brightnessWidth: CGFloat = 420
  static let brightnessHeight: CGFloat = 36
  static let batteryWidth: CGFloat = 420
  static let batteryHeight: CGFloat = 36
  static let batterySideContentWidth: CGFloat = 92
  static let deviceConnectionWidth: CGFloat = 340
  static let deviceConnectionHeight: CGFloat = 40
  static let nowPlayingWidth: CGFloat = 310
  static let nowPlayingHeight: CGFloat = 74
  static let nowPlayingRadius: CGFloat = 22
  static let quickPeekRadius: CGFloat = 20
  static let notchExpandedWidth: CGFloat = 400
  static let pillExpandedWidth: CGFloat = 360
  static let notchExpandedRadius: CGFloat = 34
  static let pillExpandedRadius: CGFloat = 34
  static let interactionWidth: CGFloat = 400
  static let interactionHeight: CGFloat = 175
  static let topRadius: CGFloat = 12
  static let collapsedBottomRadius: CGFloat = 12
  static let pillCollapsedRadius: CGFloat = 24
  static let minimumNotchCollapsedWidth: CGFloat = 274
  static let minimumNotchSideWidth: CGFloat = 40

  let centerGap: CGFloat
  let displayID: CGDirectDisplayID
  let displayMode: VelnorrDisplayMode
  let collapsedWidth: CGFloat
  // Keep a fixed transparent canvas for every presentation state. The
  // visible black surface is centered inside it; clicks outside the custom
  // hit path still pass through to the app underneath. A fixed canvas also
  // prevents NSHostingView from negotiating a new NSWindow size during
  // AppKit's display-cycle layout pass.
  // The transparent host must be at least as wide as every visible state.
  // This keeps a user-customized 400pt media panel from extending outside
  // the original 350pt interaction canvas.
  static var canvasWidth: CGFloat {
    max(
      interactionWidth, notchExpandedWidth, nowPlayingWidth, expandedWidth, volumeWidth,
      brightnessWidth, batteryWidth)
  }

  let windowWidth: CGFloat = canvasWidth
  let windowHeight: CGFloat = interactionHeight
  let topRadius: CGFloat = Self.topRadius

  var velnorrWidth: CGFloat {
    collapsedWidth
  }

  func collapsedWidth(hasTrack: Bool) -> CGFloat {
    if displayMode == .notch, !hasTrack {
      return centerGap
    }
    return collapsedWidth
  }

  init(screen: NSScreen, configuredMode: VelnorrDisplayMode) {
    displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    let leftArea = screen.auxiliaryTopLeftArea
    let rightArea = screen.auxiliaryTopRightArea

    // On notched MacBooks these areas stop at the physical notch edges.
    // On older/non-notched displays, use a conservative centered gap so
    // the shell remains useful while developing in the simulator.
    let hasPhysicalNotch: Bool
    if let leftArea, let rightArea, leftArea.width > 0, rightArea.width > 0 {
      let detectedGap = max(0, rightArea.minX - leftArea.maxX)
      hasPhysicalNotch = detectedGap > 0
      centerGap = detectedGap
    } else {
      hasPhysicalNotch = false
      centerGap = 0
    }

    if hasPhysicalNotch {
      displayMode = .notch
      // Keep the physical notch gap in the center while extending the black
      // surface on both sides so compact controls remain visible.
      collapsedWidth = max(
        Self.minimumNotchCollapsedWidth,
        centerGap + Self.minimumNotchSideWidth * 2
      )
    } else if configuredMode == .simulatedNotch {
      displayMode = .simulatedNotch
      collapsedWidth = 179
    } else {
      displayMode = .pill
      collapsedWidth = 136
    }
  }

  init(centerGap: CGFloat, displayMode: VelnorrDisplayMode, collapsedWidth: CGFloat) {
    self.centerGap = centerGap
    self.displayID = 0
    self.displayMode = displayMode
    self.collapsedWidth = collapsedWidth
  }
}
