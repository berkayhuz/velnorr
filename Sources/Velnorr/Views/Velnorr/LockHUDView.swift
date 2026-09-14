import SwiftUI

struct LockHUDView: View {
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      sideRegion(width: leftSideWidth) {
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
    @ViewBuilder content: () -> Content
  ) -> some View {
    return ZStack {
      content()
        .position(
          x: VelnorrLockScreenLayout.lockIconX(
            width: width,
            topRadius: topRadius,
            centerGap: centerGap
          ),
          y: height / 2
        )
    }
    .frame(width: width, height: height)
  }
}
