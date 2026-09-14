import AppKit
import Foundation
import SwiftUI

struct VelnorrShellView: View {
  let metrics: NotchMetrics
  let onLayoutChange: ((CGRect, CGFloat, CGFloat) -> Void)?
  let onMediaExpandedChange: ((Bool) -> Void)?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(AppSettings.expandOnHover) private var expandOnHover = true
  @AppStorage("volumeHUD") private var volumeHUDEnabled = true
  @AppStorage("brightnessHUD") private var brightnessHUDEnabled = true
  @AppStorage(AppSettings.capsLockHUD) private var capsLockHUDEnabled = true
  @AppStorage("batteryHUD") private var batteryHUDEnabled = true
  @AppStorage("deviceHUD") private var deviceHUDEnabled = true
  @AppStorage("notificationHUD") private var notificationHUDEnabled = true
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @AppStorage("appearanceArtwork") private var artworkEnabled = true
  @AppStorage("appearanceArtworkSize") private var artworkSize = 18.0
  @AppStorage("appearanceArtworkRadius") private var artworkRadius = 4.0
  @AppStorage("appearanceOpacity") private var velnorrOpacity = 1.0
  @AppStorage("appearanceTheme") private var appearanceTheme = "black"
  @AppStorage("mediaWaveform") private var waveformEnabled = true
  @AppStorage("mediaMarquee") private var marqueeEnabled = true
  @AppStorage("mediaProgressBar") private var progressBarEnabled = true
  @AppStorage("mediaTrackNavigation") private var trackNavigationEnabled = true
  @AppStorage("mediaShuffleButton") private var shuffleButtonEnabled = true
  @AppStorage("mediaAudioOutputButton") private var audioOutputButtonEnabled = true
  @AppStorage("mediaPlaybackButton") private var playbackButtonEnabled = true
  @AppStorage("mediaWaveformSpeed") private var waveformSpeed = 1.0
  @AppStorage("mediaMarqueeSpeed") private var marqueeSpeed = 25.0
  @AppStorage("mediaShowTitle") private var showMediaTitle = true
  @AppStorage("mediaShowArtist") private var showMediaArtist = true
  @AppStorage("mediaSourceIcon") private var showMediaSourceIcon = false
  @AppStorage("volumeBarWidth") private var volumeBarWidth = 52.0
  @AppStorage("brightnessBarWidth") private var brightnessBarWidth = 52.0
  @AppStorage("volumeIconSize") private var volumeIconSize = 13.0
  @AppStorage("brightnessIconSize") private var brightnessIconSize = 13.0
  @AppStorage("batteryIconWidth") private var batteryIconWidth = 28.0
  @AppStorage("volumeBarColor") private var volumeBarColor = "white"
  @AppStorage("brightnessBarColor") private var brightnessBarColor = "white"
  @AppStorage("volumeBarHeight") private var volumeBarHeight = 5.0
  @AppStorage("brightnessBarHeight") private var brightnessBarHeight = 5.0
  @StateObject private var music = MusicStatusStore()
  @StateObject private var audioVolume = AudioVolumeStore()
  @StateObject private var screenBrightness = ScreenBrightnessStore()
  @StateObject private var capsLock = CapsLockStore()
  @StateObject private var batteryCharge = BatteryChargeStore()
  @StateObject private var bluetoothConnection = BluetoothConnectionStore()
  @State private var interaction = VelnorrInteractionState()
  @State private var isAutomaticTrackPeekVisible = false
  @State private var observedTrackKey = ""
  @State private var automaticTrackPeekTask: Task<Void, Never>?
  @State private var hoverGeneration = 0
  @State private var leftHoverGeneration = 0

  var body: some View {
    let trackDetailsVisible = interaction.isArtworkHovered
      || (metrics.displayMode == .pill && interaction.isOuterHovered)
      || isAutomaticTrackPeekVisible
    let deviceOverlayVisible =
      deviceHUDEnabled
      && notificationHUDEnabled
      && bluetoothConnection.isVisible
      && bluetoothConnection.device != nil
      && !interaction.isMediaExpanded
    let volumeOverlayVisible =
      volumeHUDEnabled
      && audioVolume.isVisible
      && !interaction.isMediaExpanded
      && !deviceOverlayVisible
    let batteryOverlayVisible =
      batteryHUDEnabled
      && notificationHUDEnabled
      && batteryCharge.isVisible && !interaction.isMediaExpanded && !deviceOverlayVisible
      && !volumeOverlayVisible
    let brightnessOverlayVisible =
      brightnessHUDEnabled
      && screenBrightness.isVisible
      && !interaction.isMediaExpanded
      && !deviceOverlayVisible
      && !volumeOverlayVisible
      && !batteryOverlayVisible
    let layout = VelnorrLayout(
      state: currentPresentationState,
      isArtworkHovered: trackDetailsVisible,
      hasTrack: music.status.hasTrack,
      metrics: metrics
    )

    let velnorrShape = OutwardTopVelnorrShape(
      topRadius: layout.topRadius,
      bottomRadius: layout.bottomRadius,
      isPill: metrics.displayMode == .pill
    )

    velnorrShape
      .fill(velnorrColor.opacity(velnorrOpacity))

      .frame(
        width: layout.width,
        height: layout.height
      )

      .overlay {
        ZStack {
          Group {

            // Normal / collapsed velnorr interaction areas
            Group {
              if !music.status.hasTrack {
                notchTapArea
                  .frame(width: layout.width, height: layout.height)
                  .accessibilityLabel("Open media panel")
              } else {
                HStack(spacing: 0) {
                  workAreaRegion(
                    isLeft: true,
                    width: layout.leftSideWidth,
                    height: layout.height,
                    topRadius: layout.topRadius
                  )

                  notchTapArea
                    .frame(width: layout.centerGap)
                    .accessibilityLabel(
                      "Physical notch safe area"
                    )

                  workAreaRegion(
                    isLeft: false,
                    width: layout.rightSideWidth,
                    height: layout.height,
                    topRadius: layout.topRadius
                  )
                }
                .frame(height: layout.height)
              }
            }

            // Detay ekranı açıldığında alttaki eski
            // interaction layer mouse event almasın.
            .allowsHitTesting(!interaction.isMediaExpanded)

            // MARK: - Expanded Music View

            if interaction.isMediaExpanded {

              ExpandedNowPlayingView(
                status: music.status,

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
                  togglePlayback(
                    collapseAfterPause: false
                  )
                },

                onShuffle: {
                  performSourceAction(
                    .toggleShuffle
                  )
                },

                onPrevious: {
                  performSourceAction(
                    .previous
                  )
                },

                onNext: {
                  performSourceAction(
                    .next
                  )
                },

                onAudioOutput: {
                  music.openAudioOutputSettings()
                },

                onSeek: {
                  seek(to: $0)
                },
                isFloatingPill: metrics.displayMode == .pill,
                showArtwork: artworkEnabled,
                showApplicationIcon: showMediaSourceIcon,
                showProgress: progressBarEnabled,
                showTrackNavigation: trackNavigationEnabled,
                showShuffle: shuffleButtonEnabled,
                showAudioOutput: audioOutputButtonEnabled,
                showPlaybackButton: playbackButtonEnabled
              )
              .frame(
                width: layout.width,
                height: layout.height
              )
              .transition(VelnorrTransition.panel)

            } else if music.status.hasTrack {

              HStack(spacing: 0) {

                // MARK: Left Side

                sideRegion(
                  isLeft: true,
                  width: layout.leftSideWidth,
                  height: layout.height,
                  topRadius: layout.topRadius,
                  contentY: trackDetailsVisible
                    ? NotchMetrics.expandedHeight / 2
                    : nil
                ) {

                  AlbumArtworkView(
                    image: artworkEnabled && music.status.artworkTrackKey == music.status.trackKey
                      ? music.status.artwork
                      : nil,
                    trackKey: music.status.trackKey,
                    artworkSize: metrics.displayMode == .pill
                      && currentPresentationState == .collapsed ? CGFloat(artworkSize) : 20,
                    cornerRadius: CGFloat(artworkRadius)
                  )

                  .transition(VelnorrTransition.content)

                  .scaleEffect(
                    trackDetailsVisible
                      ? 1.2
                      : (music.status.isPlaying
                        ? 1
                        : 0.9)
                  )

                  .opacity(
                    music.status.isPlaying
                      ? 1
                      : 0.72
                  )

                  .animation(
                    reduceMotion
                      ? .easeOut(duration: 0.12)
                      : VelnorrAnimation.content,
                    value: music.status.isPlaying
                  )

                  .animation(
                    VelnorrAnimation.hover(
                      reduceMotion: reduceMotion,
                      entering: trackDetailsVisible
                    ),
                    value: trackDetailsVisible
                  )

                  .frame(
                    width: 32,
                    height: 32
                  )

                  .contentShape(
                    Rectangle()
                  )

                  .onHover { hovering in
                    handleArtworkHover(
                      hovering
                    )
                  }

                  .onTapGesture {
                    music.openSource()
                  }

                  .accessibilityLabel(
                    "Open music source"
                  )
                }

                // MARK: Physical Notch Area

                notchTapArea
                  .frame(
                    width: layout.centerGap
                  )

                // MARK: Right Side

                sideRegion(
                  isLeft: false,
                  width: layout.rightSideWidth,
                  height: layout.height,
                  topRadius: layout.topRadius,
                  contentY: trackDetailsVisible
                    ? NotchMetrics.expandedHeight / 2
                    : nil
                ) {
                  playbackControl
                }
              }
              .frame(
                height: layout.height
              )
              .overlay {
                if metrics.displayMode == .pill && interaction.isOuterHovered
                  && !interaction.isMediaExpanded
                {
                  notchTapArea
                    .frame(width: 72, height: layout.height)
                    .accessibilityLabel("Open media panel")
                }
              }

              if trackDetailsVisible {

                NowPlayingInfoView(
                  title: music.status.title,
                  artist: music.status.artist,
                  marqueeSpacing: metrics.displayMode == .pill ? 28 : 42,
                  scrollingEnabled: marqueeEnabled,
                  scrollSpeed: CGFloat(marqueeSpeed),
                  showTitle: showMediaTitle,
                  showArtist: showMediaArtist
                )
                .frame(
                  width: layout.width - (metrics.displayMode == .pill ? 120 : 52),
                  height: 28
                )
                .position(
                  x: layout.width / 2,
                  y: metrics.displayMode == .pill
                    ? layout.height / 2 + 6
                    : 58
                )
                .transition(VelnorrTransition.content)
                .allowsHitTesting(false)
              }
            }
          }
          .opacity(
            volumeOverlayVisible || brightnessOverlayVisible || batteryOverlayVisible
              || deviceOverlayVisible ? 0 : 1)

          if volumeOverlayVisible {
            VolumeHUDView(
              volume: audioVolume.volume,
              centerGap: layout.centerGap,
              leftSideWidth: layout.leftSideWidth,
              rightSideWidth: layout.rightSideWidth,
              height: layout.height,
              topRadius: layout.topRadius,
              barWidth: CGFloat(volumeBarWidth),
              iconSize: CGFloat(volumeIconSize),
              barColor: hudColor(volumeBarColor),
              barHeight: CGFloat(volumeBarHeight)
            )
            .transition(VelnorrTransition.content)
            .allowsHitTesting(false)
          }

          if brightnessOverlayVisible {
            BrightnessHUDView(
              brightness: screenBrightness.brightness,
              centerGap: layout.centerGap,
              leftSideWidth: layout.leftSideWidth,
              rightSideWidth: layout.rightSideWidth,
              height: layout.height,
              topRadius: layout.topRadius,
              barWidth: CGFloat(brightnessBarWidth),
              iconSize: CGFloat(brightnessIconSize),
              barColor: hudColor(brightnessBarColor),
              barHeight: CGFloat(brightnessBarHeight)
            )
            .transition(VelnorrTransition.content)
            .allowsHitTesting(false)
          }

          if batteryOverlayVisible {
            BatteryHUDView(
              level: batteryCharge.level,
              isCharging: batteryCharge.isCharging,
              mode: batteryCharge.mode,
              centerGap: layout.centerGap,
              leftSideWidth: layout.leftSideWidth,
              rightSideWidth: layout.rightSideWidth,
              height: layout.height,
              topRadius: layout.topRadius,
              iconWidth: CGFloat(batteryIconWidth)
            )
            .transition(VelnorrTransition.content)
          }

          if deviceOverlayVisible, let device = bluetoothConnection.device {
            DeviceConnectionHUDView(
              device: device,
              centerGap: layout.centerGap,
              leftSideWidth: layout.leftSideWidth,
              rightSideWidth: layout.rightSideWidth,
              height: layout.height,
              topRadius: layout.topRadius
            )
            .id(device.name)
            .transition(VelnorrTransition.deviceConnection)
          }

        }
      }

      .clipShape(
        velnorrShape
      )
      .overlay(alignment: .top) {
        CapsLockHUDView(
          isEnabled: capsLock.isEnabled,
          isVisible: capsLockHUDEnabled && capsLock.isVisible,
          surfaceColor: velnorrColor.opacity(velnorrOpacity),
          reduceMotion: reduceMotion || !animationsEnabled
        )
        .offset(y: layout.height)
      }
      .offset(x: layout.horizontalOffset)
      .animation(
        animationsEnabled ? VelnorrAnimation.surface(reduceMotion: reduceMotion) : nil,
        value: layout
      )

      // MARK: - Hover

      .onHover { hovering in
        handleOuterHover(
          hovering
        )
      }

      .onReceive(
        NotificationCenter.default.publisher(for: .velnorrPreviewBattery)
      ) { notification in
        let mode: BatteryChargeStore.HUDMode
        switch notification.userInfo?["mode"] as? String {
        case "charging": mode = .charging
        case "unplugged": mode = .unplugged
        case "full": mode = .full
        case "threshold": mode = .threshold
        default: mode = .low
        }
        batteryCharge.showPreview(mode: mode)
      }

      .onReceive(NotificationCenter.default.publisher(for: .velnorrPreviewVolume)) { _ in
        audioVolume.showPreview()
      }
      .onReceive(NotificationCenter.default.publisher(for: .velnorrPreviewBrightness)) { _ in
        screenBrightness.showPreview()
      }
      .onReceive(NotificationCenter.default.publisher(for: .velnorrPreviewCapsLock)) { _ in
        capsLock.showPreview()
      }
      .onReceive(NotificationCenter.default.publisher(for: .velnorrPreviewDevice)) { notification in
        let kind: ConnectedAppleDeviceKind
        switch notification.userInfo?["kind"] as? String {
        case "airPods": kind = .airPods
        case "appleWatch": kind = .appleWatch
        case "keyboard": kind = .keyboard
        case "mouse": kind = .mouse
        default: kind = .speaker
        }
        bluetoothConnection.showPreview(kind: kind)
      }
      .onReceive(NotificationCenter.default.publisher(for: .velnorrPreviewMusic)) { _ in
        music.showPreview()
      }

      // MARK: - Outside Click / Dismiss

      .onReceive(
        NotificationCenter.default.publisher(
          for: .velnorrDismiss
        )
      ) { _ in

        withAnimation(
          reduceMotion
            ? .easeOut(duration: 0.12)
            : VelnorrAnimation.content
        ) {
          interaction.dismiss()
        }
      }

      .onReceive(
        NotificationCenter.default.publisher(
          for: .velnorrCenterTapped
        )
      ) { notification in
        guard
          let id = notification.userInfo?["displayID"] as? CGDirectDisplayID,
          id == metrics.displayID
        else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.hoverIn) {
          if interaction.isMediaExpanded {
            interaction.dismiss()
          } else {
            interaction.showMedia()
          }
        }
      }


      // MARK: - Pointer State

      .onReceive(
        NotificationCenter.default.publisher(
          for: .velnorrPointerInsideChanged
        )
      ) { notification in

        guard
          let inside =
            notification.userInfo?["inside"] as? Bool
        else {
          return
        }

        if inside {

          handleOuterHover(true)

        } else if !interaction.isMediaExpanded {

          handleArtworkHover(false)
          handleOuterHover(false)
        }
      }

      // MARK: - Wake

      .onReceive(
        NotificationCenter.default.publisher(
          for: NSWorkspace.didWakeNotification
        )
      ) { _ in
        music.refresh()
      }

      // MARK: - Initial Setup

      .onAppear {

        music.start()
        audioVolume.start()
        screenBrightness.start()
        capsLock.start()
        batteryCharge.start()
        bluetoothConnection.start()
        onMediaExpandedChange?(interaction.isMediaExpanded)

        reportLayout(
          horizontalOffset: layout.horizontalOffset,
          width: layout.width,
          height: layout.height,
          radius: layout.topRadius,
          bottomRadius: layout.bottomRadius
        )
      }

      .onDisappear {
        onMediaExpandedChange?(false)
        automaticTrackPeekTask?.cancel()
        automaticTrackPeekTask = nil
        music.stop()
        audioVolume.stop()
        screenBrightness.stop()
        capsLock.stop()
        batteryCharge.stop()
        bluetoothConnection.stop()
      }

      .onChange(of: interaction.isMediaExpanded) { expanded in
        onMediaExpandedChange?(expanded)
        if expanded {
          automaticTrackPeekTask?.cancel()
          automaticTrackPeekTask = nil
          isAutomaticTrackPeekVisible = false
        }
      }

      .onChange(of: music.status.trackKey) { trackKey in
        handleTrackChange(trackKey)
      }

      .onChange(
        of: layout
      ) { _ in

        reportLayout(
          horizontalOffset: layout.horizontalOffset,
          width: layout.width,
          height: layout.height,
          radius: layout.topRadius,
          bottomRadius: layout.bottomRadius
        )
      }

      // MARK: - Hover Setting

      .onChange(
        of: expandOnHover
      ) { enabled in

        guard !enabled else {
          return
        }

        withAnimation(
          reduceMotion
            ? .easeOut(duration: 0.12)
            : VelnorrAnimation.content
        ) {
          interaction.disableHoverExpansion()
        }
      }

      // MARK: - Fixed Window Canvas

      .frame(
        width: metrics.windowWidth,
        height: metrics.windowHeight,
        alignment: .top
      )
  }

  private func reportLayout(
    horizontalOffset: CGFloat,
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat,
    bottomRadius: CGFloat
  ) {
    onLayoutChange?(
      CGRect(
        x: horizontalOffset,
        y: 0,
        width: width,
        height: height
      ), radius, bottomRadius)
  }

  private var currentPresentationState: VelnorrPresentationState {
    VelnorrPresentationResolver.resolve(
      base: interaction.presentation,
      isMediaExpanded: interaction.isMediaExpanded,
      deviceEnabled: deviceHUDEnabled && notificationHUDEnabled,
      deviceVisible: bluetoothConnection.isVisible && bluetoothConnection.device != nil,
      volumeEnabled: volumeHUDEnabled,
      volumeVisible: audioVolume.isVisible,
      batteryEnabled: batteryHUDEnabled && notificationHUDEnabled,
      batteryVisible: batteryCharge.isVisible,
      brightnessEnabled: brightnessHUDEnabled,
      brightnessVisible: screenBrightness.isVisible,
      automaticTrackPeekVisible: isAutomaticTrackPeekVisible,
      hasTrack: music.status.hasTrack
    )
  }

  private var velnorrColor: Color {
    switch appearanceTheme {
    case "midnight": return Color(red: 0.015, green: 0.025, blue: 0.06)
    case "graphite": return Color(red: 0.08, green: 0.08, blue: 0.09)
    default: return .black
    }
  }

  private func hudColor(_ value: String) -> Color {
    switch value {
    case "accent": return .accentColor
    case "green": return .green
    default: return .white
    }
  }

  private func handleTrackChange(_ trackKey: String) {
    guard !trackKey.isEmpty else { return }

    let previousTrackKey = observedTrackKey
    observedTrackKey = trackKey
    guard !previousTrackKey.isEmpty, previousTrackKey != trackKey else { return }
    guard !interaction.isMediaExpanded else { return }

    automaticTrackPeekTask?.cancel()
    withAnimation(VelnorrAnimation.surface(reduceMotion: reduceMotion)) {
      isAutomaticTrackPeekVisible = true
    }

    automaticTrackPeekTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      withAnimation(VelnorrAnimation.surface(reduceMotion: reduceMotion)) {
        isAutomaticTrackPeekVisible = false
      }
      automaticTrackPeekTask = nil
    }
  }

  private var notchTapArea: some View {
    Color.clear
      .contentShape(Rectangle())
      .onTapGesture {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.hoverIn) {
          interaction.showMedia()
        }
      }
  }

  private func handleOuterHover(_ hovering: Bool) {
    guard expandOnHover else { return }
    hoverGeneration += 1
    let generation = hoverGeneration

    if hovering {
      withAnimation(VelnorrAnimation.hover(reduceMotion: reduceMotion, entering: true)) {
        interaction.setOuterHovered(true)
      }
      return
    }

    // A short hysteresis keeps the pointer inside the continuously
    // resizing window during rapid edge crossings. Re-entry invalidates
    // this task and reverses the same in-flight spring.
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(110))
      guard generation == hoverGeneration else { return }
      withAnimation(VelnorrAnimation.hover(reduceMotion: reduceMotion, entering: false)) {
        interaction.setOuterHovered(false)
      }
    }
  }

  private func handleArtworkHover(_ hovering: Bool) {
    guard expandOnHover else { return }
    leftHoverGeneration += 1
    let generation = leftHoverGeneration

    if hovering {
      withAnimation(VelnorrAnimation.hover(reduceMotion: reduceMotion, entering: true)) {
        interaction.beginArtworkHover()
      }
      return
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(110))
      guard generation == leftHoverGeneration else { return }
      withAnimation(VelnorrAnimation.hover(reduceMotion: reduceMotion, entering: false)) {
        interaction.endArtworkHover()
      }
    }
  }

  private func workArea(isLeft: Bool) -> some View {
    Color.clear
      .frame(width: 20, height: 20)
      .contentShape(Rectangle())
      .onTapGesture {
        guard isLeft else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.content) {
          interaction.toggleWorkArea()
        }
      }
      .accessibilityLabel("20 by 20 point work area")
  }

  private var playbackControl: some View {
    CompactPlaybackControl(
                status: music.status,
                isHovered: interaction.isPlaybackHovered,
                showWaveform: waveformEnabled,
                waveformSpeed: waveformSpeed,
                onHover: { interaction.setPlaybackHovered($0) },
      onToggle: { togglePlayback(collapseAfterPause: true) },
    )
  }

  private func togglePlayback(collapseAfterPause: Bool) {
    let wasPlaying = music.status.isPlaying
    let shouldPlay = !wasPlaying

    if shouldPlay, !music.hasInstalledMediaSource {
      music.openFallbackMediaApplication()
      return
    }

    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control) {
      music.setPlaybackOptimistically(shouldPlay)
      interaction.applyPlaybackChange(
        wasPlaying: wasPlaying,
        collapseAfterPause: collapseAfterPause
      )
    }

    music.setSourcePlaying(shouldPlay)
  }

  private func performSourceAction(_ action: PlaybackAction) {
    music.perform(action)
  }

  private func seek(to seconds: TimeInterval) {
    music.seek(to: seconds)
  }

  private func workAreaRegion(
    isLeft: Bool,
    width: CGFloat,
    height: CGFloat,
    topRadius: CGFloat
  ) -> some View {
    sideRegion(isLeft: isLeft, width: width, height: height, topRadius: topRadius) {
      workArea(isLeft: isLeft)
    }
  }

  private func sideRegion<Content: View>(
    isLeft: Bool,
    width: CGFloat,
    height: CGFloat,
    topRadius: CGFloat,
    contentY: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) -> some View {
    // Pill HUDs have no physical notch gap. Anchor their content near the
    // outer edges instead of centering it in each half of the velnorr.
    let pillContentInset: CGFloat = metrics.displayMode == .pill
      ? min(12, max(8, width / 2 - 10))
      : 0

    return ZStack {
      content()
        // Match the visible side interval of OutwardTopVelnorrShape,
        // so every side element shares one exact anchor.
        .position(
          x: isLeft
            ? (metrics.displayMode == .pill
              ? topRadius + pillContentInset
              : (topRadius + width) / 2)
            : (metrics.displayMode == .pill
              ? width - topRadius - pillContentInset
              : (width - topRadius) / 2),
          y: contentY ?? height / 2
        )
    }
    .frame(width: width, height: height)
  }
}
