import AppKit
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
  case red
  case orange
  case yellow
  case green
  case mint
  case teal
  case cyan
  case blue
  case indigo
  case purple
  case pink
  case brown
  case gray

  var id: String { rawValue }

  var color: Color {
    switch self {
    case .white: .white
    case .accent: .accentColor
    case .red: Color(nsColor: .systemRed)
    case .orange: Color(nsColor: .systemOrange)
    case .yellow: Color(nsColor: .systemYellow)
    case .green: .green
    case .mint: Color(nsColor: .systemMint)
    case .teal: Color(nsColor: .systemTeal)
    case .cyan: Color(nsColor: .systemCyan)
    case .blue: Color(nsColor: .systemBlue)
    case .indigo: Color(nsColor: .systemIndigo)
    case .purple: Color(nsColor: .systemPurple)
    case .pink: Color(nsColor: .systemPink)
    case .brown: Color(nsColor: .systemBrown)
    case .gray: Color(nsColor: .systemGray)
    }
  }

  var localizationKey: String {
    switch self {
    case .white: "White"
    case .accent: "Accent"
    case .red: "Red"
    case .orange: "Orange"
    case .yellow: "Yellow"
    case .green: "Green"
    case .mint: "Mint"
    case .teal: "Teal"
    case .cyan: "Cyan"
    case .blue: "Blue"
    case .indigo: "Indigo"
    case .purple: "Purple"
    case .pink: "Pink"
    case .brown: "Brown"
    case .gray: "Gray"
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
  @AppStorage(AppSettings.lockScreenRightIcon) private var rightIconName =
    AppSettings.defaultLockScreenRightIcon
  @AppStorage(AppSettings.lockScreenRightIconColor) private var rightIconColorName =
    AppSettings.defaultLockScreenRightIconColor

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
          .foregroundStyle(
            LockScreenRightIconResolver.color(for: rightIconColorName).opacity(0.92)
          )
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
