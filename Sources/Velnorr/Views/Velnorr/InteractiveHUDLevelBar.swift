import CoreGraphics
import SwiftUI

enum HUDLevelInteraction {
  static let hoverExpansion: CGFloat = 24

  static func value(for locationX: CGFloat, width: CGFloat) -> Double {
    guard width > 0 else { return 0 }
    return Double(min(1, max(0, locationX / width)))
  }

  static func expandedWidth(baseWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
    guard baseWidth > 0 else { return 0 }
    let maximumWidth = max(baseWidth, availableWidth)
    return min(baseWidth + hoverExpansion, maximumWidth)
  }
}

struct InteractiveHUDLevelBar: View {
  let value: Double
  let reduceMotion: Bool
  let width: CGFloat
  let availableWidth: CGFloat
  let barColor: Color
  let barHeight: CGFloat
  let accessibilityLabel: String
  let onValueChanged: (Double) -> Void
  let onInteractionChanged: (Bool) -> Void
  @State private var isHovered = false
  @State private var isDragging = false

  private var displayedWidth: CGFloat {
    isHovered || isDragging
      ? HUDLevelInteraction.expandedWidth(
        baseWidth: width,
        availableWidth: availableWidth
      )
      : width
  }

  private var clampedValue: Double {
    min(1, max(0, value))
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(Color.white.opacity(0.18))

        Capsule(style: .continuous)
          .fill(barColor.opacity(0.9))
          .frame(width: geometry.size.width * clampedValue)
      }
      .frame(height: isHovered ? min(10, barHeight + 2) : barHeight)
      .frame(maxHeight: .infinity)
    }
    .frame(width: displayedWidth, height: 18)
    // Keep the whole 18-point control frame interactive, not only the thin
    // rendered capsule. High priority also prevents the surrounding HUD
    // interaction layer from winning the mouse-drag gesture.
    .contentShape(Rectangle())
    .highPriorityGesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { gesture in
          if !isDragging {
            isDragging = true
            onInteractionChanged(true)
          }
          onValueChanged(
            HUDLevelInteraction.value(
              for: gesture.location.x,
              width: displayedWidth
            )
          )
        }
        .onEnded { _ in
          isDragging = false
          onInteractionChanged(isHovered)
        }
    )
    .onHover { hovering in
      isHovered = hovering
      onInteractionChanged(hovering || isDragging)
    }
    .animation(
      isDragging || reduceMotion ? nil : VelnorrAnimation.control,
      value: displayedWidth
    )
    .accessibilityElement()
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue("\(Int((clampedValue * 100).rounded())) percent")
    .accessibilityAdjustableAction { direction in
      let step = 0.0625
      switch direction {
      case .increment:
        onValueChanged(min(1, clampedValue + step))
      case .decrement:
        onValueChanged(max(0, clampedValue - step))
      @unknown default:
        break
      }
    }
  }
}
