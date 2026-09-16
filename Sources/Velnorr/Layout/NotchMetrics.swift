import AppKit

enum VelnorrPanelNavigationLayout {
  private static let minimumSideContentWidth: CGFloat = 80

  static func physicalGap(
    displayMode: VelnorrDisplayMode,
    centerGap: CGFloat,
    availableWidth: CGFloat
  ) -> CGFloat {
    guard displayMode == .notch else { return 0 }
    return min(
      max(0, centerGap),
      max(0, availableWidth - minimumSideContentWidth)
    )
  }

  static func sideWidth(
    displayMode: VelnorrDisplayMode,
    centerGap: CGFloat,
    availableWidth: CGFloat
  ) -> CGFloat {
    let gap = physicalGap(
      displayMode: displayMode,
      centerGap: centerGap,
      availableWidth: availableWidth
    )
    return max(0, (availableWidth - gap) / 2)
  }
}

struct VelnorrNotchHeightConfiguration: Equatable, Sendable {
  let notchMode: VelnorrNotchHeightMode
  let nonNotchMode: VelnorrNotchHeightMode
  let notchHeight: CGFloat
  let nonNotchHeight: CGFloat

  static let `default` = VelnorrNotchHeightConfiguration(
    notchMode: .system,
    nonNotchMode: .menuBar,
    notchHeight: 32,
    nonNotchHeight: 32
  )

  func height(
    for mode: VelnorrNotchHeightMode,
    systemHeight: CGFloat,
    fallback: CGFloat,
    customHeight: CGFloat
  ) -> CGFloat {
    switch mode {
    case .system:
      return systemHeight > 0 ? systemHeight : fallback
    case .menuBar:
      return systemHeight > 0 ? systemHeight : fallback
    case .custom:
      return min(64, max(16, customHeight))
    }
  }
}

struct NotchMetrics {
  static let velnorrHeight: CGFloat = 32
  // Compact height used only by floating, notchless displays.
  static let pillCollapsedHeight: CGFloat = 24
  static let expandedWidth: CGFloat = 310
  static let expandedHeight: CGFloat = 36
  // Utility and media panels have their own vertical budgets. Media adds a
  // compact navigation row and reserves the physical notch before placing
  // track content, while calendar, shelf, and mirror keep their controls
  // below the physical notch without compressing content.
  static let utilityHeight: CGFloat = 270
  static let utilityContentSpacing: CGFloat = 8
  static let mediaNavigationHeight: CGFloat = 28
  static let mediaNavigationSpacing: CGFloat = 8
  static let mediaNavigationTopPadding: CGFloat = 2
  static let mediaNavigationHoverScale: CGFloat = 1.05
  static let mediaNavigationSideInset: CGFloat = 14
  // Track content starts with a small breathing room after the physical notch.
  // The following anchors preserve the existing internal media rhythm while
  // removing the redundant top gap introduced by the navigation row.
  static let mediaHeaderTopOffset: CGFloat = 8
  static let mediaProgressTopOffset: CGFloat = 81
  static let mediaControlsTopOffset: CGFloat = 109
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
  let collapsedHeight: CGFloat
  let physicalNotchHeight: CGFloat
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
  let topRadius: CGFloat = Self.topRadius

  var windowHeight: CGFloat {
    max(Self.interactionHeight, Self.utilityHeight, mediaHeight)
  }

  var velnorrWidth: CGFloat {
    collapsedWidth
  }

  /// Expanded utility content starts below the physical notch only. Simulated
  /// notch and pill displays do not have a real safe-area cutout to reserve.
  var physicalNotchContentTopInset: CGFloat {
    displayMode == .notch ? max(physicalNotchHeight, collapsedHeight) : 0
  }

  /// Keep the first utility row visibly clear of the physical notch edge.
  /// The extra spacing is intentionally not part of the notch height itself;
  /// it is a visual breathing room that keeps tabs from touching the cutout.
  var utilityContentTopInset: CGFloat {
    physicalNotchContentTopInset
      + (displayMode == .notch ? Self.utilityContentSpacing : 0)
  }

  /// Expanded media content starts just below the physical notch. Utility
  /// panels keep their additional visual spacing through utilityContentTopInset.
  var mediaContentTopInset: CGFloat {
    physicalNotchContentTopInset
  }

  /// Media content leaves the top navigation in the side areas and starts
  /// below the physical notch. Notchless displays only need the row's own
  /// height and breathing room before track content.
  var mediaContentOffset: CGFloat {
    if displayMode == .notch {
      return mediaContentTopInset
    }
    return max(
      0,
      Self.mediaNavigationHeight
        + Self.mediaNavigationSpacing
        - Self.mediaHeaderTopOffset
    )
  }

  var mediaHeight: CGFloat {
    Self.interactionHeight + mediaContentOffset
  }

  func collapsedWidth(hasTrack: Bool) -> CGFloat {
    if displayMode == .notch, !hasTrack {
      return centerGap
    }
    return collapsedWidth
  }

  init(
    screen: NSScreen,
    configuredMode: VelnorrDisplayMode,
    heightConfiguration: VelnorrNotchHeightConfiguration = .default
  ) {
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
      let systemNotchHeight = max(0, screen.safeAreaInsets.top)
      physicalNotchHeight = systemNotchHeight
      let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
      collapsedHeight = heightConfiguration.height(
        for: heightConfiguration.notchMode,
        systemHeight: heightConfiguration.notchMode == .menuBar
          ? menuBarHeight
          : systemNotchHeight,
        fallback: Self.velnorrHeight,
        customHeight: heightConfiguration.notchHeight
      )
    } else if configuredMode == .simulatedNotch {
      displayMode = .simulatedNotch
      collapsedWidth = 179
      physicalNotchHeight = 0
      let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
      collapsedHeight = heightConfiguration.height(
        for: heightConfiguration.nonNotchMode,
        systemHeight: menuBarHeight,
        fallback: Self.pillCollapsedHeight,
        customHeight: heightConfiguration.nonNotchHeight
      )
    } else {
      displayMode = .pill
      collapsedWidth = 136
      physicalNotchHeight = 0
      let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
      collapsedHeight = heightConfiguration.height(
        for: heightConfiguration.nonNotchMode,
        systemHeight: menuBarHeight,
        fallback: Self.pillCollapsedHeight,
        customHeight: heightConfiguration.nonNotchHeight
      )
    }
  }

  init(
    centerGap: CGFloat,
    displayMode: VelnorrDisplayMode,
    collapsedWidth: CGFloat,
    collapsedHeight: CGFloat? = nil,
    physicalNotchHeight: CGFloat? = nil
  ) {
    self.centerGap = centerGap
    self.displayID = 0
    self.displayMode = displayMode
    self.collapsedWidth = collapsedWidth
    let resolvedCollapsedHeight = collapsedHeight
      ?? (displayMode == .pill ? Self.pillCollapsedHeight : Self.velnorrHeight)
    self.collapsedHeight = resolvedCollapsedHeight
    self.physicalNotchHeight = physicalNotchHeight
      ?? (displayMode == .notch ? resolvedCollapsedHeight : 0)
  }
}
