import SwiftUI

struct BrightnessHUDView: View {
  let brightness: Double
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat
  let barWidth: CGFloat
  let iconSize: CGFloat
  let barColor: Color
  let barHeight: CGFloat
  let onValueChanged: (Double) -> Void
  let onInteractionChanged: (Bool) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 0) {
      sideRegion(isLeft: true, width: leftSideWidth) {
        HStack(spacing: 6) {
          Image(systemName: brightnessSymbol)
            .font(.system(size: iconSize, weight: .semibold))
            .id(brightnessSymbol)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
          Text(AppLanguage.selected.localized("Brightness"))
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.88))
        .animation(
          reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control,
          value: brightnessSymbol
        )
      }
      Color.clear.frame(width: centerGap).allowsHitTesting(false)
      sideRegion(isLeft: false, width: rightSideWidth) {
        InteractiveHUDLevelBar(
          value: brightness,
          reduceMotion: reduceMotion,
          width: barWidth,
          availableWidth: max(barWidth, rightSideWidth - 16),
          barColor: barColor,
          barHeight: barHeight,
          accessibilityLabel: AppLanguage.selected.localized("Brightness"),
          onValueChanged: onValueChanged,
          onInteractionChanged: onInteractionChanged
        )
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLanguage.selected.localized("Brightness"))
    .accessibilityValue("\(Int((brightness * 100).rounded())) percent")
    .accessibilityAdjustableAction { direction in
      let step = 0.0625
      switch direction {
      case .increment:
        onValueChanged(min(1, brightness + step))
      case .decrement:
        onValueChanged(max(0, brightness - step))
      @unknown default:
        break
      }
    }
  }

  private var brightnessSymbol: String {
    switch brightness {
    case ..<0.18: return "moon.fill"
    case ..<0.42: return "sun.min.fill"
    case ..<0.72: return "sun.haze.fill"
    default: return "sun.max.fill"
    }
  }

  private func sideRegion<Content: View>(
    isLeft: Bool, width: CGFloat, @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(24, max(8, width / 2 - 10))
    return ZStack {
      content().position(
        x: isFloatingPill
          ? (isLeft ? edgeInset + 32 : width - edgeInset - 12)
          : (isLeft ? width / 2 + 9 : width / 2 - 9),
        y: height / 2
      )
    }
      .frame(width: width, height: height)
  }
}
