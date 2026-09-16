import SwiftUI

enum CapsLockHUDMetrics {
  static let defaultDiameter: CGFloat = 38
  static let minimumDiameter: CGFloat = 30
  static let maximumDiameter: CGFloat = 64
  static let restingGap: CGFloat = 12

  static func diameter(from storedValue: Double) -> CGFloat {
    guard storedValue.isFinite, storedValue > 0 else { return defaultDiameter }
    return min(max(CGFloat(storedValue), minimumDiameter), maximumDiameter)
  }

  static func iconSize(for diameter: CGFloat) -> CGFloat {
    diameter * 13 / 30
  }

  static func frameWidth(for diameter: CGFloat) -> CGFloat {
    max(46, diameter + 16)
  }
}

/// A detached status bubble that leaves the Velnorr surface and its layout
/// untouched. The bubble begins partially inside the lower edge, stretches
/// like a liquid drop, then settles with an exact 12-point gap.
struct CapsLockHUDView: View {
  let isEnabled: Bool
  let isVisible: Bool
  let surfaceColor: Color
  let reduceMotion: Bool
  let diameter: CGFloat

  @State private var isSeparated = false
  @State private var isHovered = false

  var body: some View {
    ZStack(alignment: .top) {
      Capsule(style: .continuous)
        .fill(surfaceColor)
        .frame(
          width: isSeparated ? 3 : 15,
          height: isSeparated ? 2 : 19
        )
        .offset(y: -4)
        .opacity(isSeparated ? 0 : 1)

      Circle()
        .fill(surfaceColor)
        .frame(width: diameter, height: diameter)
        .overlay {
          Image(systemName: isEnabled ? "capslock.fill" : "capslock")
            .font(
              .system(
                size: CapsLockHUDMetrics.iconSize(for: diameter),
                weight: .semibold
              )
            )
            .foregroundStyle(isEnabled ? Color.green : Color.white)
            .id(isEnabled)
            .transition(.scale(scale: 0.72).combined(with: .opacity))
        }
        .shadow(color: .black.opacity(isSeparated ? 0.3 : 0), radius: 7, y: 3)
        .scaleEffect(
          isSeparated
            ? (isHovered ? 1.2 : 1)
            : 0.62,
          anchor: .top
        )
        .offset(
          y: isSeparated
            ? CapsLockHUDMetrics.restingGap
            : -diameter * 0.48
        )
        .contentShape(Circle())
        .onHover { hovering in
          guard isVisible else { return }
          withAnimation(
            reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control
          ) {
            isHovered = hovering
          }
        }
    }
    .frame(
      width: CapsLockHUDMetrics.frameWidth(for: diameter),
      height: CapsLockHUDMetrics.restingGap + diameter,
      alignment: .top
    )
    .opacity(isSeparated ? 1 : 0)
    .allowsHitTesting(isVisible)
    .accessibilityHidden(!isVisible)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AppLanguage.selected.localized(isEnabled ? "Caps Lock On" : "Caps Lock Off")
    )
    .onAppear {
      setVisible(isVisible, animated: false)
    }
    .onChange(of: isVisible) { visible in
      if !visible {
        isHovered = false
      }
      setVisible(visible, animated: true)
    }
    .animation(
      reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control,
      value: isEnabled
    )
  }

  private func setVisible(_ visible: Bool, animated: Bool) {
    let animation: Animation? = animated
      ? (reduceMotion
        ? .easeOut(duration: 0.12)
        : .spring(response: 0.46, dampingFraction: 0.7, blendDuration: 0.08))
      : nil
    withAnimation(animation) {
      isSeparated = visible
    }
  }
}
