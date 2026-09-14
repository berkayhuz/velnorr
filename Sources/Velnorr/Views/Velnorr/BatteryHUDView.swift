import AppKit
import SwiftUI

struct BatteryHUDView: View {
  let level: Int
  let isCharging: Bool
  let mode: BatteryChargeStore.HUDMode
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat
  let iconWidth: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 0) {
      sideRegion(isLeft: true, width: leftSideWidth) {
        HStack(spacing: 6) {
          if isCharging {
            Image(systemName: "bolt.fill")
              .font(.system(size: 13, weight: .semibold))
          }
          Text(label)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.white.opacity(0.9))
      }

      Color.clear.frame(width: centerGap).allowsHitTesting(false)

      sideRegion(isLeft: false, width: rightSideWidth) {
        HStack(spacing: 5) {
          BatteryLevelIcon(level: level, width: iconWidth)
          Text("\(level)%")
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(batteryColor(for: level))
        .animation(reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control, value: level)
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AppLanguage.selected.localized(isCharging ? "Charging" : "Battery disconnected"))
    .accessibilityValue("\(level) percent")
  }

  private var label: String {
    switch mode {
    case .charging: return AppLanguage.selected.localized("Charging")
    case .unplugged: return AppLanguage.selected.localized("Unplugged")
    case .low: return AppLanguage.selected.localized("Low")
    case .full: return AppLanguage.selected.localized("Charged")
    case .threshold: return AppLanguage.selected.localized("Battery")
    }
  }

  private func sideRegion<Content: View>(
    isLeft: Bool, width: CGFloat, @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(18, max(8, width / 2 - 10))
    return ZStack {
      content().position(
        x: isFloatingPill
          ? (isLeft ? topRadius + edgeInset : width - topRadius - edgeInset)
          : (isLeft ? width / 2 + 9 : width / 2 - 9),
        y: height / 2
      )
    }
    .frame(width: width, height: height)
  }
}

private struct BatteryLevelIcon: View {
  let level: Int
  let width: CGFloat

  var body: some View {
    ZStack(alignment: .leading) {
      svgImage
        .foregroundStyle(.white.opacity(0.22))

      svgImage
        .foregroundStyle(batteryColor(for: level))
        .mask(alignment: .leading) {
          Rectangle()
            .frame(width: 28 * CGFloat(min(100, max(0, level))) / 100)
        }
    }
            .frame(width: width, height: width * 13 / 28)
    .animation(.easeOut(duration: 0.2), value: level)
  }

  private var svgImage: some View {
    if let image = ResourceImages.battery {
      return AnyView(
        Image(nsImage: image)
          .resizable()
          .renderingMode(.template)
          .interpolation(.high)
          .frame(width: width, height: width * 13 / 28)
      )
    }
    return AnyView(
      Image(systemName: "battery.100percent").font(.system(size: 18, weight: .semibold)))
  }
}

private func batteryColor(for level: Int) -> Color {
  switch level {
  case 100: return .white
  case ..<20: return .red
  case 20..<80: return Color(red: 1, green: 0.72, blue: 0.12)
  default: return .green
  }
}
