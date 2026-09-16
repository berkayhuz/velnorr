import SwiftUI

struct VolumeHUDView: View {
  let volume: Double
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
          Image(systemName: volumeSymbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .id(volumeSymbol)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
          Text(AppLanguage.selected.localized("Sound"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
        }
        .lineLimit(1)
        .animation(
          reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control,
          value: volumeSymbol
        )
      }

      Color.clear
        .frame(width: centerGap)
        .allowsHitTesting(false)

      sideRegion(isLeft: false, width: rightSideWidth) {
        VolumeLevelBar(
          volume: volume,
          reduceMotion: reduceMotion,
          width: barWidth,
          availableWidth: max(barWidth, rightSideWidth - 16),
          barColor: barColor,
          barHeight: barHeight,
          onValueChanged: onValueChanged,
          onInteractionChanged: onInteractionChanged
        )
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLanguage.selected.localized("Sound volume"))
    .accessibilityValue("\(Int((volume * 100).rounded())) percent")
    .accessibilityAdjustableAction { direction in
      let step = 0.0625
      switch direction {
      case .increment:
        onValueChanged(min(1, volume + step))
      case .decrement:
        onValueChanged(max(0, volume - step))
      @unknown default:
        break
      }
    }
  }

  private var volumeSymbol: String {
    switch volume {
    case ...0.001: return "speaker.slash.fill"
    case ...0.33: return "speaker.wave.1.fill"
    case ...0.66: return "speaker.wave.2.fill"
    default: return "speaker.wave.3.fill"
    }
  }

  private func sideRegion<Content: View>(
    isLeft: Bool,
    width: CGFloat,
    @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(24, max(8, width / 2 - 10))
    return ZStack {
      content()
        .position(
          x: isFloatingPill
            ? (isLeft ? topRadius + edgeInset : width - topRadius - edgeInset)
            : (isLeft ? (topRadius + width) / 2 : (width - topRadius) / 2),
          y: height / 2
        )
    }
    .frame(width: width, height: height)
  }
}

private struct VolumeLevelBar: View {
  let volume: Double
  let reduceMotion: Bool
  let width: CGFloat
  let availableWidth: CGFloat
  let barColor: Color
  let barHeight: CGFloat
  let onValueChanged: (Double) -> Void
  let onInteractionChanged: (Bool) -> Void

  var body: some View {
    InteractiveHUDLevelBar(
      value: volume,
      reduceMotion: reduceMotion,
      width: width,
      availableWidth: availableWidth,
      barColor: barColor,
      barHeight: barHeight,
      accessibilityLabel: AppLanguage.selected.localized("Sound volume"),
      onValueChanged: onValueChanged,
      onInteractionChanged: onInteractionChanged
    )
  }
}
