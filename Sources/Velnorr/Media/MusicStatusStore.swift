import AppKit
import Combine
import Foundation

@MainActor
final class MusicStatusStore: ObservableObject {
  private enum MediaCommand {
    case playback(Bool, MusicSource)
    case action(PlaybackAction)
    case seek(TimeInterval)
  }

  @Published private(set) var status = MusicStatus()

  private let providers: [any NowPlayingProviding]
  private let artworkService: ArtworkService
  private let mediaApplicationLauncher: any MediaApplicationLaunching
  private var hasStarted = false
  private var pendingPlaybackState: Bool?
  private var pendingPlaybackDeadline = Date.distantPast
  private var pendingSeekDeadline = Date.distantPast
  private var pollingTask: Task<Void, Never>?
  private var refreshTask: Task<Void, Never>?
  private var artworkTask: Task<Void, Never>?
  private var artworkTaskIdentifier: UUID?
  private var artworkRetryAfter = Date.distantPast
  private var commandTail: Task<Void, Never>?
  private var commandTailIdentifier: UUID?
  private var commandTasks: [UUID: Task<Void, Never>] = [:]
  private var previewTask: Task<Void, Never>?

  init(
    providers: [any NowPlayingProviding] = [
      SpotifyNowPlayingProvider(), AppleMusicNowPlayingProvider(),
    ],
    artworkService: ArtworkService = ArtworkService(),
    mediaApplicationLauncher: any MediaApplicationLaunching = SystemMediaApplicationLauncher()
  ) {
    self.providers = providers
    self.artworkService = artworkService
    self.mediaApplicationLauncher = mediaApplicationLauncher
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    pollingTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        guard let self, self.hasStarted else { return }
        await self.refreshOnce()
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  func stop() {
    guard hasStarted else { return }
    hasStarted = false
    pendingPlaybackState = nil
    pendingSeekDeadline = .distantPast

    pollingTask?.cancel()
    pollingTask = nil
    refreshTask?.cancel()
    refreshTask = nil
    artworkTask?.cancel()
    artworkTask = nil
    artworkTaskIdentifier = nil
    for task in commandTasks.values {
      task.cancel()
    }
    commandTasks.removeAll()
    commandTail = nil
    commandTailIdentifier = nil
    previewTask?.cancel()
    previewTask = nil
  }

  func showPreview() {
    status = MusicStatus(
      hasTrack: true,
      isPlaying: true,
      artwork: nil,
      artworkTrackKey: "",
      applicationIcon: applicationIcon(for: .music),
      accentColor: .systemGreen,
      trackKey: "velnorr-preview",
      title: "Preview Song",
      artist: "Velnorr Artist",
      source: .music,
      elapsed: 42,
      duration: 210,
      playbackUpdatedAt: Date()
    )
    previewTask?.cancel()
    previewTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(5))
      guard !Task.isCancelled, let self else { return }
      self.status = MusicStatus()
      self.previewTask = nil
      self.refresh()
    }
  }

  func refresh() {
    guard hasStarted, refreshTask == nil else { return }
    refreshTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.loadAndApplyNowPlaying()
      self.refreshTask = nil
    }
  }

  func setPlaybackOptimistically(_ isPlaying: Bool) {
    let now = Date()
    if status.isPlaying, !isPlaying {
      status.elapsed = currentElapsed(at: now)
    }
    pendingPlaybackState = isPlaying
    pendingPlaybackDeadline = now.addingTimeInterval(1.25)
    status.isPlaying = isPlaying
    status.playbackUpdatedAt = now
  }

  func openSource() {
    resolvedProvider()?.openApplication()
  }

  func openSource(_ source: MusicSource) {
    providers.first(where: { $0.source == source })?.openApplication()
  }

  func openCurrentTrack() {
    let current = status
    Task {
      await resolvedProvider()?.openTrack(
        trackKey: current.trackKey,
        title: current.title,
        artist: current.artist
      )
    }
  }

  func openCurrentArtist() {
    let current = status
    guard !current.artist.isEmpty else { return }
    Task {
      await resolvedProvider()?.openArtist(name: current.artist)
    }
  }

  var hasInstalledMediaSource: Bool {
    providers.contains(where: \.isInstalled)
  }

  func openFallbackMediaApplication() {
    if mediaApplicationLauncher.openDefaultAudioApplication() { return }
    if mediaApplicationLauncher.openMusicDiscovery() { return }
    NSSound.beep()
  }

  func setSourcePlaying(_ isPlaying: Bool) {
    enqueue(.playback(isPlaying, status.source))
  }

  func perform(_ action: PlaybackAction) {
    enqueue(.action(action))
  }

  func seek(to seconds: TimeInterval) {
    let target = max(0, min(status.duration, seconds))
    status.elapsed = target
    status.playbackUpdatedAt = Date()
    pendingSeekDeadline = Date().addingTimeInterval(2.5)
    enqueue(.seek(target))
  }

  func openAudioOutputSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func refreshOnce() async {
    guard previewTask == nil else { return }
    if let refreshTask {
      await refreshTask.value
      return
    }

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.loadAndApplyNowPlaying()
    }
    refreshTask = task
    await task.value
    refreshTask = nil
  }

  private func loadAndApplyNowPlaying() async {
    let signpost = VelnorrPerformance.begin(.mediaRefresh)
    defer { VelnorrPerformance.end(.mediaRefresh, signpost) }

    guard hasStarted, !Task.isCancelled else { return }

    var candidates: [SourcedNowPlayingSnapshot] = []
    for provider in providers {
      guard !Task.isCancelled else { return }
      if let snapshot = await provider.read() {
        candidates.append(SourcedNowPlayingSnapshot(source: provider.source, snapshot: snapshot))
      }
    }

    guard hasStarted, !Task.isCancelled else { return }
    let selected = NowPlayingSourceResolver.select(from: candidates, currentSource: status.source)
    apply(selected)
  }

  private func apply(_ selected: SourcedNowPlayingSnapshot?) {
    expirePendingPlaybackStateIfNeeded()
    guard let selected else {
      guard pendingPlaybackState == nil, status.hasTrack else { return }
      artworkTask?.cancel()
      artworkTask = nil
      artworkTaskIdentifier = nil
      status = MusicStatus()
      return
    }

    let snapshot = selected.snapshot
    let now = Date()
    let resolvedIsPlaying = resolvePlaybackState(snapshot.isPlaying, now: now)
    let sameTrack = status.trackKey == snapshot.trackKey && status.source == selected.source
    let expectedElapsed = currentElapsed(at: now)
    let seekIsPending = now < pendingSeekDeadline
    if !seekIsPending {
      pendingSeekDeadline = .distantPast
    }
    // While playing, the UI's timeline is smoother and more accurate than
    // occasionally stale AppleScript player-position values. Only rebase a
    // paused track (or a newly selected track); seek has its own short grace
    // period so the provider can catch up before a refresh is applied.
    let elapsedNeedsCorrection =
      !sameTrack || (!resolvedIsPlaying && !seekIsPending && abs(expectedElapsed - snapshot.elapsed) > 0.75)
    let metadataChanged =
      !sameTrack || status.title != snapshot.title || status.artist != snapshot.artist
      || status.duration != snapshot.duration || status.isPlaying != resolvedIsPlaying
    let shouldUpdateStatus = metadataChanged || elapsedNeedsCorrection
    let artworkNeedsLoading =
      status.artwork == nil && snapshot.artworkURL != nil && artworkTask == nil
      && now >= artworkRetryAfter

    guard shouldUpdateStatus || artworkNeedsLoading else { return }

    if !sameTrack {
      artworkTask?.cancel()
      artworkTask = nil
      artworkTaskIdentifier = nil
      artworkRetryAfter = .distantPast
    }

    if shouldUpdateStatus {
      // A playing same-track refresh can contain a stale provider position.
      // Preserve the local timeline anchor so UI recreation cannot rewind it.
      let elapsed = sameTrack && status.isPlaying && resolvedIsPlaying
        ? expectedElapsed
        : snapshot.elapsed
      status = MusicStatus(
        hasTrack: true,
        isPlaying: resolvedIsPlaying,
        artwork: sameTrack ? status.artwork : nil,
        artworkTrackKey: sameTrack ? status.artworkTrackKey : "",
        applicationIcon: applicationIcon(for: selected.source),
        accentColor: sameTrack ? status.accentColor : defaultAccentColor(for: selected.source),
        trackKey: snapshot.trackKey,
        title: snapshot.title,
        artist: snapshot.artist,
        source: selected.source,
        elapsed: elapsed,
        duration: snapshot.duration,
        playbackUpdatedAt: now
      )
    }

    if status.artwork == nil, let artworkURL = snapshot.artworkURL {
      loadArtwork(from: artworkURL, trackKey: snapshot.trackKey)
    }
  }

  private func loadArtwork(from url: URL, trackKey: String) {
    artworkTask?.cancel()
    let identifier = UUID()
    artworkTaskIdentifier = identifier
    artworkTask = Task { @MainActor [weak self, artworkService] in
      var didLoadArtwork = false
      defer {
        if let self, self.artworkTaskIdentifier == identifier {
          self.artworkTask = nil
          self.artworkTaskIdentifier = nil
          if !didLoadArtwork {
            self.artworkRetryAfter = Date().addingTimeInterval(10)
          }
        }
      }

      guard let payload = await artworkService.artwork(for: url), !Task.isCancelled,
        let image = NSImage(data: payload.data), let self, self.status.trackKey == trackKey
      else { return }

      didLoadArtwork = true
      var updatedStatus = self.status
      updatedStatus.artwork = image
      updatedStatus.artworkTrackKey = trackKey
      if let color = payload.color {
        updatedStatus.accentColor = color.nsColor
      }
      self.status = updatedStatus
    }
  }

  private func enqueue(_ command: MediaCommand) {
    guard hasStarted else { return }
    let identifier = UUID()
    let predecessor = commandTail
    let task = Task { @MainActor [weak self] in
      await predecessor?.value
      guard let self else { return }
      defer {
        self.commandTasks[identifier] = nil
        if self.commandTailIdentifier == identifier {
          self.commandTail = nil
          self.commandTailIdentifier = nil
        }
      }

      guard self.hasStarted, !Task.isCancelled else { return }
      await self.execute(command)
      guard self.hasStarted, !Task.isCancelled else { return }
      await self.refreshOnce()
    }
    commandTail = task
    commandTailIdentifier = identifier
    commandTasks[identifier] = task
  }

  private func execute(_ command: MediaCommand) async {
    guard let provider = resolvedProvider() else { return }
    switch command {
    case .playback(let isPlaying, let source):
      let provider = providers.first(where: { $0.source == source && $0.isInstalled })
        ?? resolvedProvider()
      guard let provider else { return }
      if isPlaying {
        await provider.launchAndPlay()
      } else {
        await provider.setPlaying(false)
      }
    case .action(let action):
      await provider.perform(action)
    case .seek(let seconds):
      await provider.seek(to: seconds)
    }
  }

  private func resolvedProvider() -> (any NowPlayingProviding)? {
    if let active = providers.first(where: { $0.source == status.source && $0.isInstalled }) {
      return active
    }
    return providers.first(where: \.isInstalled)
  }

  private func resolvePlaybackState(_ observedState: Bool, now: Date) -> Bool {
    expirePendingPlaybackStateIfNeeded(now: now)
    return pendingPlaybackState ?? observedState
  }

  private func expirePendingPlaybackStateIfNeeded(now: Date = Date()) {
    if pendingPlaybackState != nil, now >= pendingPlaybackDeadline {
      pendingPlaybackState = nil
    }
  }

  private func currentElapsed(at date: Date) -> TimeInterval {
    status.currentElapsed(at: date)
  }

  private func defaultAccentColor(for source: MusicSource) -> NSColor {
    source == .music ? .systemPink : .systemGreen
  }

  private func applicationIcon(for source: MusicSource) -> NSImage? {
    providers.first(where: { $0.source == source })?.applicationIcon
  }
}
