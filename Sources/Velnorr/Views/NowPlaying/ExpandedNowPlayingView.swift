import AppKit
import Foundation
import SwiftUI

struct ExpandedNowPlayingView: View {
  let status: MusicStatus
  let onOpenSource: () -> Void
  let onOpenTrack: () -> Void
  let onOpenArtist: () -> Void
  let onTogglePlayback: () -> Void
  let onShuffle: () -> Void
  let onPrevious: () -> Void
  let onNext: () -> Void
  let onAudioOutput: () -> Void
  let onSeek: (TimeInterval) -> Void
  let isFloatingPill: Bool
  let showArtwork: Bool
  let showProgress: Bool
  let showTrackNavigation: Bool
  let showShuffle: Bool
  let showAudioOutput: Bool
  let showPlaybackButton: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @State private var isShuffleEnabled = false

  var body: some View {
    GeometryReader { geometry in
      // OutwardTopVelnorrShape's vertical sides sit `topRadius` points
      // inside its bounding rect. Keep content an additional 12pt
      // inside those sides, otherwise it is clipped by the black shape.
      let horizontalInset = min(
        isFloatingPill ? 28 : NotchMetrics.notchExpandedRadius + 12,
        geometry.size.width / 2
      )
      let contentWidth = max(0, geometry.size.width - horizontalInset * 2)

      ZStack(alignment: .topLeading) {
        header
          .frame(width: contentWidth, height: 54)
          .offset(x: horizontalInset, y: 19)

        if showProgress {
          ExpandedPlaybackProgress(status: status, onSeek: onSeek)
            .frame(width: contentWidth, height: 18)
            .offset(x: horizontalInset, y: 82)
        }

        controls
          .frame(width: contentWidth, height: 34)
          .offset(x: horizontalInset, y: 120)
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
      .clipped()
    }
    .contentShape(Rectangle())
    .clipped()
  }

  private var header: some View {
    HStack(spacing: 15) {
      Button(action: onOpenSource) {
        expandedArtwork
          .id(status.trackKey)
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
          .offset(y: 3)
      }
      .buttonStyle(VelnorrButtonStyle())
      .accessibilityLabel("Open music source")

      VStack(alignment: .leading, spacing: 2) {
        Button(action: onOpenTrack) {
          Text(status.hasTrack && !status.title.isEmpty ? status.title : "Not Playing")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(status.hasTrack ? .white : .white.opacity(0.42))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!status.hasTrack)
        .accessibilityLabel("Open song")

        if status.hasTrack {
          Button(action: onOpenArtist) {
            Text(status.artist.isEmpty ? "Bilinmeyen Sanatçı" : status.artist)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.white.opacity(0.46))
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .disabled(status.artist.isEmpty)
          .accessibilityLabel("Open artist")
        }
      }
      .id(status.trackKey)
      .transition(.opacity.combined(with: .offset(x: 4)))
      .offset(y: 12)

      Spacer(minLength: 10)

      if status.isPlaying {
        WaveformIcon(color: Color(nsColor: status.accentColor).opacity(0.72))
          .frame(width: 24, height: 21)
          .offset(x: -4, y: 6)
      } else {
        if status.hasTrack {
          Image(systemName: "waveform")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(nsColor: status.accentColor).opacity(0.5))
            .frame(width: 24, height: 21)
        } else {
          NotPlayingIndicator()
            .frame(width: 24, height: 21)
            .scaleEffect(0.85)
            .offset(x: -2, y: 12)
        }
      }
    }
    .animation(
      motionReduced ? .easeOut(duration: 0.12) : VelnorrAnimation.content,
      value: status.trackKey
    )
  }

  private var expandedArtwork: some View {
    Group {
      if showArtwork, let artwork = status.artwork {
        Image(nsImage: artwork)
          .resizable()
          .interpolation(.high)
          .scaledToFill()
      } else {
        Image(systemName: "music.note")
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(.white.opacity(0.28))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.white.opacity(0.08))
      }
    }
    .frame(width: 54, height: 54)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var controls: some View {
    HStack {
      if showShuffle {
        controlButton(
          symbol: "shuffle",
          size: 16,
          color: isShuffleEnabled ? .green : .white.opacity(0.34),
          action: toggleShuffle
        )
      }
      if showTrackNavigation {
        Spacer()
        controlButton(symbol: "backward.fill", size: 21, action: onPrevious)
        Spacer()
      } else {
        Spacer()
      }
      if showPlaybackButton {
        controlButton(
          symbol: status.isPlaying ? "pause.fill" : "play.fill",
          size: 24,
          action: onTogglePlayback
        )
      }
      if showTrackNavigation {
        Spacer()
        controlButton(symbol: "forward.fill", size: 21, action: onNext)
        Spacer()
      } else {
        Spacer()
      }
      if showAudioOutput {
        controlButton(
          symbol: "airplayaudio",
          size: 17,
          color: .white.opacity(0.42),
          action: onAudioOutput
        )
      }
    }
  }

  private func toggleShuffle() {
    withAnimation(
      motionReduced ? .easeOut(duration: 0.12) : VelnorrAnimation.control
    ) {
      isShuffleEnabled.toggle()
    }
    onShuffle()
  }

  private var motionReduced: Bool {
    reduceMotion || !animationsEnabled
  }

  private func controlButton(
    symbol: String,
    size: CGFloat,
    color: Color = .white,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
    }
    .buttonStyle(VelnorrButtonStyle())
    .accessibilityLabel(accessibilityLabel(for: symbol))
  }

  private func accessibilityLabel(for symbol: String) -> String {
    switch symbol {
    case "shuffle": return "Shuffle"
    case "backward.fill": return "Previous track"
    case "forward.fill": return "Next track"
    case "airplayaudio": return "Audio output"
    case "pause.fill": return "Pause"
    case "play.fill": return "Play"
    default: return symbol
    }
  }
}

private struct VelnorrButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? (reduceMotion ? 0.98 : 0.94) : 1)
      .animation(
        reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
        value: configuration.isPressed
      )
  }
}

private struct NotPlayingIndicator: View {
  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<6, id: \.self) { _ in
        Circle()
          .fill(.white.opacity(0.28))
          .frame(width: 3, height: 3)
      }
    }
  }
}

private struct ExpandedPlaybackProgress: View {
  let status: MusicStatus
  let onSeek: (TimeInterval) -> Void
  @State private var previewElapsed: TimeInterval?

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !status.isPlaying)) { timeline in
      let elapsed = previewElapsed ?? currentElapsed(at: timeline.date)
      HStack(spacing: 10) {
        Text(status.hasTrack ? format(elapsed) : "--:--")
          .frame(width: 34, alignment: .leading)

        GeometryReader { geometry in
          let progress =
            status.duration > 0
            ? min(1, max(0, elapsed / status.duration))
            : 0

          ZStack(alignment: .leading) {
            Capsule()
              .fill(.white.opacity(0.16))
            Capsule()
              .fill(.white.opacity(0.62))
              .frame(width: geometry.size.width * progress)
          }
          .frame(height: 6)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                guard status.duration > 0, geometry.size.width > 0 else { return }
                let ratio = min(1, max(0, value.location.x / geometry.size.width))
                previewElapsed = status.duration * ratio
              }
              .onEnded { value in
                guard status.duration > 0, geometry.size.width > 0 else { return }
                let ratio = min(1, max(0, value.location.x / geometry.size.width))
                let target = status.duration * ratio
                previewElapsed = nil
                onSeek(target)
              }
          )
        }

        Text(
          status.hasTrack && status.duration > 0
            ? "-\(format(max(0, status.duration - elapsed)))" : "--:--"
        )
        .frame(width: 42, alignment: .trailing)
      }
      .font(.system(size: 11, weight: .semibold, design: .rounded))
      .foregroundStyle(.white.opacity(0.43))
    }
  }

  private func currentElapsed(at date: Date) -> TimeInterval {
    let liveElapsed =
      status.elapsed
      + (status.isPlaying
        ? date.timeIntervalSince(status.playbackUpdatedAt)
        : 0)
    guard status.duration > 0 else { return max(0, liveElapsed) }
    return min(status.duration, max(0, liveElapsed))
  }

  private func format(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
  }
}
