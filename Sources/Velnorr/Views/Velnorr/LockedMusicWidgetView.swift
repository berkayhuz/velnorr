import SwiftUI

struct LockedMusicWidgetView: View {
  private let widgetWidth: CGFloat = 440
  private let widgetHeight: CGFloat = 190

  let runtime: VelnorrRuntime
  let onTrackAvailabilityChange: (Bool) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceArtwork") private var artworkEnabled = true
  @AppStorage("mediaProgressBar") private var progressBarEnabled = true
  @AppStorage("mediaTrackNavigation") private var trackNavigationEnabled = true
  @AppStorage("mediaShuffleButton") private var shuffleButtonEnabled = true
  @AppStorage("mediaAudioOutputButton") private var audioOutputButtonEnabled = true
  @AppStorage("mediaPlaybackButton") private var playbackButtonEnabled = true
  @AppStorage("mediaMarquee") private var marqueeEnabled = true
  @AppStorage("mediaMarqueeSpeed") private var marqueeSpeed = 25.0
  @AppStorage("mediaShowTitle") private var showMediaTitle = true
  @AppStorage("mediaShowArtist") private var showMediaArtist = true
  @AppStorage("mediaSourceIcon") private var showMediaSourceIcon = false
  @ObservedObject private var music: MusicStatusStore

  init(
    runtime: VelnorrRuntime,
    onTrackAvailabilityChange: @escaping (Bool) -> Void
  ) {
    self.runtime = runtime
    self.onTrackAvailabilityChange = onTrackAvailabilityChange
    _music = ObservedObject(wrappedValue: runtime.music)
  }

  var body: some View {
    Group {
      if music.status.hasTrack {
        lockedNowPlayingView
      }
    }
    .frame(width: widgetWidth, height: widgetHeight)
    .background(
      Color.white.opacity(0.30),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.14), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .accessibilityElement(children: .contain)
    .onAppear {
      onTrackAvailabilityChange(music.status.hasTrack)
    }
    .onChange(of: music.status.hasTrack) { hasTrack in
      onTrackAvailabilityChange(hasTrack)
    }
  }

  private func togglePlayback() {
    let wasPlaying = music.status.isPlaying
    let shouldPlay = !wasPlaying

    guard music.hasInstalledMediaSource else { return }

    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control) {
      music.setPlaybackOptimistically(shouldPlay)
    }
    music.setSourcePlaying(shouldPlay)
  }

  private var lockedNowPlayingView: some View {
    let status = music.status
    return ExpandedNowPlayingView(
      status: status,
      onOpenSource: { music.openSource() },
      onOpenTrack: { music.openCurrentTrack() },
      onOpenArtist: { music.openCurrentArtist() },
      onTogglePlayback: { togglePlayback() },
      onShuffle: { music.perform(.toggleShuffle) },
      onPrevious: { music.perform(.previous) },
      onNext: { music.perform(.next) },
      onAudioOutput: { music.openAudioOutputSettings() },
      onSeek: { music.seek(to: $0) },
      isFloatingPill: true,
      showArtwork: artworkEnabled,
      showApplicationIcon: showMediaSourceIcon,
      showProgress: progressBarEnabled,
      showTrackNavigation: trackNavigationEnabled,
      showShuffle: shuffleButtonEnabled,
      showAudioOutput: audioOutputButtonEnabled,
      showPlaybackButton: playbackButtonEnabled,
      allowsExternalNavigation: false,
      allowsAudioOutput: false
    )
    .frame(width: widgetWidth - 24, height: widgetHeight - 15)
    .padding(.top, 6)
  }
}
