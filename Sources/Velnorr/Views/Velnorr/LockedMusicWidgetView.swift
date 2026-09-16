import SwiftUI

struct LockedMusicWidgetView: View {
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
    widgetSurface
      .contentShape(roundedWidgetShape)
      .accessibilityElement(children: .contain)
      .onAppear {
        onTrackAvailabilityChange(music.status.hasTrack)
      }
      .onChange(of: music.status.hasTrack) { hasTrack in
        onTrackAvailabilityChange(hasTrack)
      }
  }

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

  @ViewBuilder
private var widgetSurface: some View {
  if #available(macOS 26.0, *) {
    widgetContent
      .glassEffect(
        .clear.interactive(),
        in: roundedWidgetShape
      )
  } else {
    widgetContent
      .background(
        .ultraThinMaterial,
        in: roundedWidgetShape
      )
  }
}

private var roundedWidgetShape: RoundedRectangle {
  RoundedRectangle(
    cornerRadius: 28,
    style: .continuous
  )
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
      allowsAudioOutput: true,
      isLockScreenWidget: true
    )
.frame(
  width: VelnorrLockScreenLayout.widgetSize.width,
  height: VelnorrLockScreenLayout.widgetSize.height
)
  }
}
