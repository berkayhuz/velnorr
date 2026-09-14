import SwiftUI

/// A detached status bubble that leaves the Velnorr surface and its layout
/// untouched. The bubble begins partially inside the lower edge, stretches
/// like a liquid drop, then settles with an exact 12-point gap.
struct CapsLockHUDView: View {
  let isEnabled: Bool
  let isVisible: Bool
  let surfaceColor: Color
  let reduceMotion: Bool

  @State private var isSeparated = false

  private let diameter: CGFloat = 30
  private let restingGap: CGFloat = 12

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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.green : Color.white)
            .id(isEnabled)
            .transition(.scale(scale: 0.72).combined(with: .opacity))
        }
        .shadow(color: .black.opacity(isSeparated ? 0.3 : 0), radius: 7, y: 3)
        .scaleEffect(isSeparated ? 1 : 0.62, anchor: .top)
        .offset(y: isSeparated ? restingGap : -diameter * 0.48)
    }
    .frame(width: 46, height: restingGap + diameter, alignment: .top)
    .opacity(isSeparated ? 1 : 0)
    .allowsHitTesting(false)
    .accessibilityHidden(!isVisible)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AppLanguage.selected.localized(isEnabled ? "Caps Lock On" : "Caps Lock Off")
    )
    .onAppear {
      setVisible(isVisible, animated: false)
    }
    .onChange(of: isVisible) { visible in
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
