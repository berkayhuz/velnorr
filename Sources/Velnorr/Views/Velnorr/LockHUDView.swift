import SwiftUI

struct LockHUDView: View {
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      sideRegion(width: leftSideWidth, isLeading: true) {
        Image(systemName: "lock.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))
          .accessibilityLabel(AppLanguage.selected.localized("Screen locked"))
      }
      .frame(width: leftSideWidth, height: height)

      Color.clear
        .frame(width: centerGap)
        .allowsHitTesting(false)

      Color.clear
        .frame(width: rightSideWidth)
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLanguage.selected.localized("Screen locked"))
    .allowsHitTesting(false)
  }

  private func sideRegion<Content: View>(
    width: CGFloat,
    isLeading: Bool,
    @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(12, max(8, width / 2 - 10))
    let iconX: CGFloat
    if isFloatingPill {
      iconX = isLeading
        ? topRadius + edgeInset
        : width - topRadius - edgeInset
    } else {
      iconX = isLeading
        ? (topRadius + width) / 2
        : (width - topRadius) / 2
    }
    return ZStack {
      content()
        .position(
          x: iconX,
          y: height / 2
        )
    }
    .frame(width: width, height: height)
  }
}
