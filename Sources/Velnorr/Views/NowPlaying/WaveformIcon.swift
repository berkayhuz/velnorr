import Foundation
import SwiftUI

struct WaveformIcon: View {
  let color: Color
  var animationSpeed: Double = 1
  var isAnimating: Bool = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("reduceMotionOverride") private var reduceMotionOverride = false
  @AppStorage("appearanceAnimations") private var animationsEnabled = true

  @ViewBuilder
  var body: some View {
    if reduceMotion || reduceMotionOverride || !animationsEnabled {
      bars(at: 0)
    } else {
      TimelineView(
        .animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)
      ) { timeline in
        bars(at: timeline.date.timeIntervalSinceReferenceDate)
      }
    }
  }

  private func bars(at time: Double) -> some View {
    HStack(spacing: 2) {
      ForEach(0..<5, id: \.self) { index in
        Capsule()
          .fill(color)
          .frame(width: 2.5, height: barHeight(index: index, time: time))
      }
    }
  }

  private func barHeight(index: Int, time: Double) -> CGFloat {
    let wave = (sin(time * 5 * animationSpeed + Double(index) * 1.35) + 1) / 2
    return 6 + CGFloat(wave) * 10
  }
}
