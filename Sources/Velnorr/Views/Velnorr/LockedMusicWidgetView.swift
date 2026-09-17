import SwiftUI

@MainActor
final class LockedMusicWidgetPresentationModel: ObservableObject {
  @Published private(set) var isPresented = false

  func present() {
    isPresented = true
  }
}

struct LockedMusicWidgetView: View {
  let runtime: VelnorrRuntime
  let onTrackAvailabilityChange: (Bool) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @AppStorage("appearanceArtwork")
  private var artworkEnabled = true

  @AppStorage("mediaProgressBar")
  private var progressBarEnabled = true

  @AppStorage("mediaTrackNavigation")
  private var trackNavigationEnabled = true

  @AppStorage("mediaShuffleButton")
  private var shuffleButtonEnabled = true

  @AppStorage("mediaAudioOutputButton")
  private var audioOutputButtonEnabled = true

  @AppStorage("mediaPlaybackButton")
  private var playbackButtonEnabled = true

  @AppStorage("mediaMarquee")
  private var marqueeEnabled = true

  @AppStorage("mediaMarqueeSpeed")
  private var marqueeSpeed = 25.0

  @AppStorage("mediaShowTitle")
  private var showMediaTitle = true

  @AppStorage("mediaShowArtist")
  private var showMediaArtist = true

  @AppStorage("mediaSourceIcon")
  private var showMediaSourceIcon = false

  @ObservedObject private var music: MusicStatusStore
  @ObservedObject private var presentationModel: LockedMusicWidgetPresentationModel

  init(
    runtime: VelnorrRuntime,
    presentationModel: LockedMusicWidgetPresentationModel,
    onTrackAvailabilityChange: @escaping (Bool) -> Void
  ) {
    self.runtime = runtime
    self.onTrackAvailabilityChange = onTrackAvailabilityChange

    _music = ObservedObject(
      wrappedValue: runtime.music
    )
    _presentationModel = ObservedObject(wrappedValue: presentationModel)
  }

  // MARK: - Body

  var body: some View {
    ZStack {
      widgetSurface
        .scaleEffect(
          bubbleScale,
          anchor: .center
        )
        .opacity(
          presentationModel.isPresented ? 1 : 0
        )
        .contentShape(roundedWidgetShape)
        .accessibilityElement(children: .contain)
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .center
    )
    .onAppear {
      onTrackAvailabilityChange(
        music.status.hasTrack
      )
    }
    .onChange(of: music.status.hasTrack) { hasTrack in
      onTrackAvailabilityChange(hasTrack)
    }
    .animation(bubbleAnimation, value: presentationModel.isPresented)
  }

  // MARK: - Bubble Animation

  private var bubbleScale: CGFloat {
    if reduceMotion {
      return 1
    }

    return presentationModel.isPresented ? 1 : 0.001
  }

  private var bubbleAnimation: Animation {
    if reduceMotion {
      return .easeOut(duration: 0.12)
    }

    return .spring(
      response: 0.38,
      dampingFraction: 0.58,
      blendDuration: 0.04
    )
  }

  // MARK: - Widget Content

  @ViewBuilder
  private var widgetContent: some View {
    Group {
      if music.status.hasTrack {
        lockedNowPlayingView
      }
    }
    .frame(
      width: VelnorrLockScreenLayout.widgetSize.width,
      height: VelnorrLockScreenLayout.widgetSize.height
    )
  }

  // MARK: - Surface

  @ViewBuilder
  private var widgetSurface: some View {
    if #available(macOS 26.0, *) {
      widgetContent
        .glassEffect(
          .regular
            .tint(.white.opacity(0.08))
            .interactive(),
          in: roundedWidgetShape
        )
        .overlay {
          roundedWidgetShape
            .strokeBorder(
              LinearGradient(
                colors: [
                  .white.opacity(0.75),
                  .white.opacity(0.22),
                  .white.opacity(0.08),
                  .white.opacity(0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1.2
            )
        }
        .overlay {
          roundedWidgetShape
            .strokeBorder(
              .white.opacity(0.10),
              lineWidth: 3
            )
            .blur(radius: 3)
        }
    } else {
      widgetContent
        .background(
          .ultraThinMaterial,
          in: roundedWidgetShape
        )
        .overlay {
          roundedWidgetShape
            .strokeBorder(
              .white.opacity(0.32),
              lineWidth: 1
            )
        }
    }
  }

  private var roundedWidgetShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: 28,
      style: .continuous
    )
  }

  // MARK: - Playback

  private func togglePlayback() {
    let wasPlaying = music.status.isPlaying
    let shouldPlay = !wasPlaying

    guard music.hasInstalledMediaSource else {
      return
    }

    withAnimation(
      reduceMotion
        ? .easeOut(duration: 0.12)
        : VelnorrAnimation.control
    ) {
      music.setPlaybackOptimistically(
        shouldPlay
      )
    }

    music.setSourcePlaying(
      shouldPlay
    )
  }

  // MARK: - Now Playing

  private var lockedNowPlayingView: some View {
    let status = music.status

    return ExpandedNowPlayingView(
      status: status,

      onOpenSource: {
        music.openSource()
      },

      onOpenTrack: {
        music.openCurrentTrack()
      },

      onOpenArtist: {
        music.openCurrentArtist()
      },

      onTogglePlayback: {
        togglePlayback()
      },

      onShuffle: {
        music.perform(.toggleShuffle)
      },

      onPrevious: {
        music.perform(.previous)
      },

      onNext: {
        music.perform(.next)
      },

      onAudioOutput: {
        music.openAudioOutputSettings()
      },

      onSeek: {
        music.seek(to: $0)
      },

      isFloatingPill: true,

      showArtwork: artworkEnabled,
      showApplicationIcon: showMediaSourceIcon,
      showProgress: progressBarEnabled,
      showTrackNavigation: trackNavigationEnabled,
      showShuffle: shuffleButtonEnabled,
      showAudioOutput: audioOutputButtonEnabled,
      showPlaybackButton: playbackButtonEnabled,

      allowsExternalNavigation: false,
      allowsAudioOutput: true,
      isLockScreenWidget: true
    )
    .frame(
      width: VelnorrLockScreenLayout.widgetSize.width,
      height: VelnorrLockScreenLayout.widgetSize.height
    )
  }
}
