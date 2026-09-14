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
  let showApplicationIcon: Bool
  let showProgress: Bool
  let showTrackNavigation: Bool
  let showShuffle: Bool
  let showAudioOutput: Bool
  let showPlaybackButton: Bool
  let allowsExternalNavigation: Bool
  let allowsAudioOutput: Bool
  let isLockScreenWidget: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @State private var isShuffleEnabled = false

  init(
    status: MusicStatus,
    onOpenSource: @escaping () -> Void,
    onOpenTrack: @escaping () -> Void,
    onOpenArtist: @escaping () -> Void,
    onTogglePlayback: @escaping () -> Void,
    onShuffle: @escaping () -> Void,
    onPrevious: @escaping () -> Void,
    onNext: @escaping () -> Void,
    onAudioOutput: @escaping () -> Void,
    onSeek: @escaping (TimeInterval) -> Void,
    isFloatingPill: Bool,
    showArtwork: Bool,
    showApplicationIcon: Bool,
    showProgress: Bool,
    showTrackNavigation: Bool,
    showShuffle: Bool,
    showAudioOutput: Bool,
    showPlaybackButton: Bool,
    allowsExternalNavigation: Bool = true,
    allowsAudioOutput: Bool = true,
    isLockScreenWidget: Bool = false
  ) {
    self.status = status
    self.onOpenSource = onOpenSource
    self.onOpenTrack = onOpenTrack
    self.onOpenArtist = onOpenArtist
    self.onTogglePlayback = onTogglePlayback
    self.onShuffle = onShuffle
    self.onPrevious = onPrevious
    self.onNext = onNext
    self.onAudioOutput = onAudioOutput
    self.onSeek = onSeek
    self.isFloatingPill = isFloatingPill
    self.showArtwork = showArtwork
    self.showApplicationIcon = showApplicationIcon
    self.showProgress = showProgress
    self.showTrackNavigation = showTrackNavigation
    self.showShuffle = showShuffle
    self.showAudioOutput = showAudioOutput
    self.showPlaybackButton = showPlaybackButton
    self.allowsExternalNavigation = allowsExternalNavigation
    self.allowsAudioOutput = allowsAudioOutput
    self.isLockScreenWidget = isLockScreenWidget
  }

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
            .offset(x: horizontalInset, y: 92)
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
    HStack(
      alignment: isLockScreenWidget ? .top : .center,
      spacing: isLockScreenWidget ? 16 : 10
    ) {
      Button(action: onOpenSource) {
        expandedArtwork
          .id(status.trackKey)
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
          .offset(y: 3)
      }
      .buttonStyle(VelnorrButtonStyle())
      .disabled(!allowsExternalNavigation)
      .accessibilityLabel("Open music source")

      VStack(alignment: .leading, spacing: isLockScreenWidget ? 7 : 2) {
        Button(action: onOpenTrack) {
          ExpandedTrackTitle(
            text: status.hasTrack && !status.title.isEmpty ? status.title : "Not Playing",
            color: status.hasTrack ? .white : .white.opacity(0.42)
          )
        }
        .buttonStyle(
          VelnorrButtonStyle(
            hoverScale: 0.98,
            pressedScale: 0.96
          )
        )
        .disabled(!status.hasTrack || !allowsExternalNavigation)
        .accessibilityLabel("Open song")

        if status.hasTrack {
          Button(action: onOpenArtist) {
            Text(status.artist.isEmpty ? "Bilinmeyen Sanatçı" : status.artist)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white.opacity(0.46))
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(
            VelnorrButtonStyle(
              hoverScale: 0.98,
              pressedScale: 0.96
            )
          )
          .disabled(status.artist.isEmpty || !allowsExternalNavigation)
          .accessibilityLabel("Open artist")
        }
      }
      .id(status.trackKey)
      .transition(.opacity.combined(with: .offset(x: 4)))
      .frame(
        height: isLockScreenWidget ? 54 : nil,
        alignment: .center
      )
      .offset(y: isLockScreenWidget ? 3 : 12)

      Spacer(minLength: 10)

      if status.hasTrack {
        WaveformIcon(
          color: Color(nsColor: status.accentColor).opacity(0.72),
          isAnimating: status.isPlaying
        )
          .frame(
            width: 24,
            height: 21,
            alignment: isLockScreenWidget ? .top : .center
          )
          .offset(x: -4, y: isLockScreenWidget ? 10 : 6)
      } else {
        NotPlayingIndicator()
          .frame(width: 24, height: 21)
          .scaleEffect(0.85)
          .offset(x: -2, y: 12)
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
    .overlay(alignment: .bottomTrailing) {
      if showApplicationIcon, status.hasTrack, let applicationIcon = status.applicationIcon {
        Image(nsImage: applicationIcon)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: 18, height: 18)
          .offset(x: 4, y: 4)
          .accessibilityHidden(true)
      }
    }
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
      if showAudioOutput && allowsAudioOutput {
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
  let hoverScale: CGFloat
  let pressedScale: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovered = false

  init(hoverScale: CGFloat = 0.95, pressedScale: CGFloat = 0.9) {
    self.hoverScale = hoverScale
    self.pressedScale = pressedScale
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(
        configuration.isPressed
          ? pressedScale
          : (isHovered ? hoverScale : 1)
      )
      .onHover { hovering in
        isHovered = hovering
      }
      .animation(
        reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
        value: configuration.isPressed
      )
      .animation(
        reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
        value: isHovered
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

private struct ExpandedTrackTitle: View {
  let text: String
  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @AppStorage("mediaMarquee") private var marqueeEnabled = true
  @AppStorage("mediaMarqueeSpeed") private var marqueeSpeed = 25.0
  @State private var textWidth: CGFloat = 0
  @State private var loopStartDate: Date?
  @State private var hasStartedLoop = false
  @State private var pausedElapsed: TimeInterval = 0
  @State private var loopTask: Task<Void, Never>?
  @State private var isHovered = false

  private let loopSpacing: CGFloat = 28
  private let loopDelay: Duration = .seconds(1.5)

  var body: some View {
    GeometryReader { geometry in
      if shouldLoop && !isHovered && textWidth > geometry.size.width,
        let loopStartDate
      {
        TimelineView(
          .animation(minimumInterval: VelnorrTimelineCadence.marqueeInterval)
        ) { timeline in
          let elapsed = pausedElapsed + max(
            0,
            timeline.date.timeIntervalSince(loopStartDate)
          )
          let travel = max(1, textWidth + loopSpacing)
          let offset = -CGFloat(elapsed * marqueeSpeed)
            .truncatingRemainder(dividingBy: travel)

          HStack(spacing: loopSpacing) {
            measuredTitle
            titleLabel
          }
          .offset(x: offset)
          .frame(minWidth: geometry.size.width, alignment: .leading)
        }
      } else {
        truncatedTitleLabel
          .frame(width: geometry.size.width, alignment: .leading)
      }
    }
    .frame(height: 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(alignment: .leading) {
      measuredTitle
        .opacity(0)
        .allowsHitTesting(false)
    }
    .clipped()
    .onHover { hovering in
      updateHoverState(hovering)
    }
    .onPreferenceChange(ExpandedTrackTitleWidthKey.self) { width in
      textWidth = width
    }
    .onAppear {
      scheduleLoop()
    }
    .onChange(of: text) { _ in
      scheduleLoop()
    }
    .onChange(of: marqueeEnabled) { _ in
      scheduleLoop()
    }
    .onChange(of: motionReduced) { _ in
      scheduleLoop()
    }
    .onDisappear {
      loopTask?.cancel()
      loopTask = nil
    }
  }

  private var shouldLoop: Bool {
    marqueeEnabled && !motionReduced && hasStartedLoop && loopStartDate != nil
  }

  private var motionReduced: Bool {
    reduceMotion || !animationsEnabled
  }

  private var titleLabel: some View {
    Text(text)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(color)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
  }

  private var truncatedTitleLabel: some View {
    Text(text)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(color)
      .lineLimit(1)
      .truncationMode(.tail)
  }

  private var measuredTitle: some View {
    titleLabel
      .background {
        GeometryReader { geometry in
          Color.clear.preference(
            key: ExpandedTrackTitleWidthKey.self,
            value: geometry.size.width
          )
        }
      }
  }

  private func updateHoverState(_ hovering: Bool) {
    guard isHovered != hovering else { return }
    isHovered = hovering

    guard hasStartedLoop else { return }

    if hovering {
      if let loopStartDate {
        pausedElapsed += max(0, Date().timeIntervalSince(loopStartDate))
        self.loopStartDate = nil
      }
    } else if loopStartDate == nil {
      loopStartDate = Date()
    }
  }

  private func scheduleLoop() {
    loopTask?.cancel()
    loopTask = nil
    loopStartDate = nil
    hasStartedLoop = false
    pausedElapsed = 0

    guard marqueeEnabled, !motionReduced else { return }

    loopTask = Task { @MainActor in
      try? await Task.sleep(for: loopDelay)
      guard !Task.isCancelled, marqueeEnabled, !motionReduced else { return }
      hasStartedLoop = true
      if !isHovered {
        loopStartDate = Date()
      }
      loopTask = nil
    }
  }
}

private struct ExpandedTrackTitleWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct ExpandedPlaybackProgress: View {
  let status: MusicStatus
  let onSeek: (TimeInterval) -> Void
  @State private var previewElapsed: TimeInterval?

  var body: some View {
    HStack(spacing: 10) {
      PlaybackTimeLabel(
        status: status,
        previewElapsed: previewElapsed,
        showsRemaining: false
      )

      ExpandedProgressBar(
        status: status,
        previewElapsed: $previewElapsed,
        onSeek: onSeek
      )

      PlaybackTimeLabel(
        status: status,
        previewElapsed: previewElapsed,
        showsRemaining: true
      )
    }
    .font(.system(size: 11, weight: .semibold, design: .rounded))
    .foregroundStyle(.white.opacity(0.43))
  }
}

private struct PlaybackTimeLabel: View {
  let status: MusicStatus
  let previewElapsed: TimeInterval?
  let showsRemaining: Bool

  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: VelnorrTimelineCadence.durationLabelInterval,
        paused: !status.isPlaying && previewElapsed == nil
      )
    ) { timeline in
      let elapsed = previewElapsed ?? status.currentElapsed(at: timeline.date)
      Text(label(for: elapsed))
        .frame(width: 34, alignment: .center)
    }
  }

  private func label(for elapsed: TimeInterval) -> String {
    guard status.hasTrack else { return "--:--" }
    if showsRemaining {
      guard status.duration > 0 else { return "--:--" }
      return "-\(PlaybackTimeFormatter.string(max(0, status.duration - elapsed)))"
    }
    return PlaybackTimeFormatter.string(elapsed)
  }
}

private struct ExpandedProgressBar: View {
  let status: MusicStatus
  @Binding var previewElapsed: TimeInterval?
  let onSeek: (TimeInterval) -> Void

  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: VelnorrTimelineCadence.progressInterval,
        paused: !status.isPlaying && previewElapsed == nil
      )
    ) { timeline in
      let elapsed = previewElapsed ?? status.currentElapsed(at: timeline.date)
      GeometryReader { geometry in
        let progress = status.duration > 0
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
    }
  }
}

private enum PlaybackTimeFormatter {
  static func string(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
  }
}
