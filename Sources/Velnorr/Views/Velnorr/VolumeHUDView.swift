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
          barColor: barColor,
          barHeight: barHeight
        )
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLanguage.selected.localized("Sound volume"))
    .accessibilityValue("\(Int((volume * 100).rounded())) percent")
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
  let barColor: Color
  let barHeight: CGFloat

  var body: some View {
    GeometryReader { geometry in
      let barWidth = max(0, geometry.size.width)
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(Color.white.opacity(0.18))

        Capsule(style: .continuous)
          .fill(barColor.opacity(0.9))
          .frame(width: barWidth * volume)
      }
      .frame(height: barHeight)
      .frame(maxHeight: .infinity)
    }
    .frame(width: width, height: 18)
    .animation(
      reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
      value: volume
    )
  }
}
