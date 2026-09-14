import AppKit
import SwiftUI

struct CompactPlaybackControl: View {
  let status: MusicStatus
  let isHovered: Bool
  let showWaveform: Bool
  let waveformSpeed: Double
  let onHover: (Bool) -> Void
  let onToggle: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @State private var isPressed = false

  var body: some View {
    Button(action: onToggle) {
      ZStack {
      if status.isPlaying && showWaveform {
        WaveformIcon(
          color: Color(nsColor: status.accentColor),
          animationSpeed: waveformSpeed
        )
        .frame(
          width: 20,
          height: 20
        )
        .blur(
          radius: isHovered ? 2.2 : 0
        )
        .opacity(
          isHovered ? 0.5 : 1
        )
        .shadow(
          color: Color(nsColor: status.accentColor)
            .opacity(isHovered ? 0.72 : 0),
          radius: 5.5
        )
      }

      if isHovered && status.isPlaying {
        Image(systemName: "pause.fill")
          .font(
            .system(
              size: 11,
              weight: .bold
            )
          )
          .foregroundStyle(.white)
          .frame(
            width: 20,
            height: 20
          )
          .scaleEffect(
            isPressed ? 1.0 : 1.25
          )
          .shadow(
            color: Color(nsColor: status.accentColor)
              .opacity(0.56),
            radius: 4
          )
          .transition(
            .scale(scale: 0.25)
              .combined(with: .opacity)
          )
      } else if !status.isPlaying {
        Image(systemName: "play.fill")
          .font(
            .system(
              size: 11,
              weight: .bold
            )
          )
          .foregroundStyle(.white)
          .frame(
            width: 20,
            height: 20
          )
          .scaleEffect(
            isHovered && !isPressed ? 1.25 : 1.0
          )
          .transition(
            .scale(scale: 0.25)
              .combined(with: .opacity)
          )
      }
      }
      .frame(width: 20, height: 20)
      .contentShape(Rectangle())
      .scaleEffect(status.isPlaying && isPressed ? 0.95 : 1)
    }
    .buttonStyle(.plain)
    .onHover(perform: onHover)
    .onLongPressGesture(
      minimumDuration: 0,
      maximumDistance: 12,
      pressing: { pressing in
        isPressed = pressing
      },
      perform: {}
    )
    .animation(
      motionReduced
        ? .easeOut(duration: 0.12)
        : VelnorrAnimation.control,
      value: status.isPlaying
    )
    .animation(
      motionReduced
        ? .easeOut(duration: 0.12)
        : VelnorrAnimation.content,
      value: isHovered
    )
    .animation(
      motionReduced
        ? .easeOut(duration: 0.08)
        : VelnorrAnimation.control,
      value: isPressed
    )
    .accessibilityLabel(
      status.isPlaying ? "Pause" : "Play"
    )
    .accessibilityHint(
      "Toggle playback"
    )
  }

  private var motionReduced: Bool {
    reduceMotion || !animationsEnabled
  }
}
