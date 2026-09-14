import SwiftUI

struct LockHUDView: View {
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      Color.clear
        .frame(width: leftSideWidth)

      Color.clear
        .frame(width: centerGap)
        .allowsHitTesting(false)

      sideRegion {
        Image(systemName: "lock.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))
          .accessibilityLabel(AppLanguage.selected.localized("Screen locked"))
      }
      .frame(width: rightSideWidth, height: height)
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLanguage.selected.localized("Screen locked"))
    .allowsHitTesting(false)
  }

  private func sideRegion<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(12, max(8, rightSideWidth / 2 - 10))
    return ZStack {
      content()
        .position(
          x: isFloatingPill
            ? rightSideWidth - topRadius - edgeInset
            : (rightSideWidth - topRadius) / 2,
          y: height / 2
        )
    }
    .frame(width: rightSideWidth, height: height)
  }
}
