import SwiftUI

struct VelnorrAnimation {
  // A slightly under-damped entrance gives the velnorr a restrained overshoot,
  // while the slower exit lets it settle back into the notch without snapping.
  static let hoverIn = Animation.spring(
    response: 0.32,
    dampingFraction: 0.72,
    blendDuration: 0.08
  )
  static let hoverOut = Animation.spring(
    response: 0.4,
    dampingFraction: 0.88,
    blendDuration: 0.1
  )
  static let surface = Animation.spring(
    response: 0.38,
    dampingFraction: 0.78,
    blendDuration: 0.1
  )
  static let content = Animation.spring(
    response: 0.34,
    dampingFraction: 0.82,
    blendDuration: 0.08
  )
  static let control = Animation.spring(
    response: 0.26,
    dampingFraction: 0.7,
    blendDuration: 0.06
  )

  static func hover(reduceMotion: Bool, entering: Bool) -> Animation {
    if reduceMotion { return .easeOut(duration: 0.12) }
    return entering ? hoverIn : hoverOut
  }

  static func surface(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.12) : surface
  }

}

enum VelnorrTransition {
  static var deviceConnection: AnyTransition {
    .asymmetric(
      insertion: .opacity
        .combined(with: .scale(scale: 0.72, anchor: .top)),
      removal: .opacity
        .combined(with: .scale(scale: 0.55, anchor: .top))
    )
  }

  static var panel: AnyTransition {
    .asymmetric(
      insertion: .opacity
        .combined(with: .scale(scale: 0.9, anchor: .top))
        .combined(with: .offset(y: -5)),
      removal: .opacity
        .combined(with: .scale(scale: 0.97, anchor: .top))
    )
  }

  static var content: AnyTransition {
    .asymmetric(
      insertion: .opacity
        .combined(with: .scale(scale: 0.92))
        .combined(with: .offset(y: -3)),
      removal: .opacity.combined(with: .scale(scale: 0.97))
    )
  }
}
