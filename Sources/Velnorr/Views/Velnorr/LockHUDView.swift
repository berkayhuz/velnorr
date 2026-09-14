import SwiftUI

enum LockScreenRightIconOption: String, CaseIterable, Identifiable {
  case smile = "face.smiling"
  case heart = "heart.fill"
  case star = "star.fill"
  case sparkles = "sparkles"
  case bolt = "bolt.fill"
  case moon = "moon.fill"
  case sun = "sun.max.fill"
  case music = "music.note"
  case thumbsUp = "hand.thumbsup.fill"

  var id: String { rawValue }
}

enum LockScreenRightIconColorOption: String, CaseIterable, Identifiable {
  case white
  case accent
  case green

  var id: String { rawValue }

  var color: Color {
    switch self {
    case .white: .white
    case .accent: .accentColor
    case .green: .green
    }
  }

  var localizationKey: String {
    switch self {
    case .white: "White"
    case .accent: "Accent"
    case .green: "Green"
    }
  }
}

enum LockScreenRightIconResolver {
  static func symbol(for value: String) -> String {
    LockScreenRightIconOption(rawValue: value)?.rawValue ?? AppSettings.defaultLockScreenRightIcon
  }

  static func color(for value: String) -> Color {
    LockScreenRightIconColorOption(rawValue: value)?.color
      ?? LockScreenRightIconColorOption.white.color
  }
}

struct LockHUDView: View {
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat
  let rightIconName: String
  let rightIconColor: Color

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

      sideRegion(width: rightSideWidth, isLeading: false) {
        Image(systemName: LockScreenRightIconResolver.symbol(for: rightIconName))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(rightIconColor.opacity(0.92))
      }
      .frame(width: rightSideWidth, height: height)
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
    return ZStack {
      content()
        .position(
          x: VelnorrLockScreenLayout.sideIconX(
            width: width,
            topRadius: topRadius,
            centerGap: centerGap,
            isLeading: isLeading
          ),
          y: height / 2
        )
    }
    .frame(width: width, height: height)
  }
}
