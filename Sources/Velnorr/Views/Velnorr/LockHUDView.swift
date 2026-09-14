import SwiftUI

struct LockHUDView: View {
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      sideRegion {
        Image(systemName: "lock.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))
          .accessibilityLabel("Screen locked")
      }

      Color.clear
        .frame(width: centerGap)
        .allowsHitTesting(false)
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Screen locked")
    .allowsHitTesting(false)
  }

  private func sideRegion<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    ZStack {
      content()
        .position(
          x: (topRadius + leftSideWidth) / 2,
          y: height / 2
        )
    }
    .frame(width: leftSideWidth, height: height)
  }
}
