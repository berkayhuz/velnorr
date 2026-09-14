import AppKit
import SwiftUI

struct AlbumArtworkView: View {
  let image: NSImage?
  let trackKey: String
  let artworkSize: CGFloat
  let cornerRadius: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("reduceMotionOverride") private var reduceMotionOverride = false
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @State private var displayedImage: NSImage?
  @State private var displayedTrackKey: String
  @State private var rotation: Double = 0
  @State private var pendingTrackKey: String?
  @State private var transitionTrackKey: String?
  @State private var transitionImage: NSImage?
  @State private var artworkWaitTask: Task<Void, Never>?
  @State private var flipTask: Task<Void, Never>?

  init(
    image: NSImage?,
    trackKey: String,
    artworkSize: CGFloat = 20,
    cornerRadius: CGFloat = 4
  ) {
    self.image = image
    self.trackKey = trackKey
    self.artworkSize = artworkSize
    self.cornerRadius = cornerRadius
    _displayedImage = State(initialValue: image)
    _displayedTrackKey = State(initialValue: trackKey)
  }

  var body: some View {
    Group {
      if let displayedImage {
        Image(nsImage: displayedImage)
          .resizable()
          .interpolation(.high)
          .scaledToFill()
      } else {
        Image(systemName: "music.note")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.white.opacity(0.12))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .frame(width: artworkSize, height: artworkSize)
    .rotation3DEffect(
      .degrees(rotation),
      axis: (x: 0, y: 1, z: 0),
      perspective: 0.55
    )
    .onChange(of: artworkInput) { newInput in
      handleArtworkInput(newInput)
    }
    .onDisappear {
      artworkWaitTask?.cancel()
      artworkWaitTask = nil
      flipTask?.cancel()
      flipTask = nil
    }
  }

  private var artworkInput: ArtworkInput {
    ArtworkInput(trackKey: trackKey, image: image)
  }

  private func handleArtworkInput(_ input: ArtworkInput) {
    guard !input.trackKey.isEmpty else { return }

    if displayedTrackKey == input.trackKey {
      guard let image = input.image, displayedImage !== image else { return }
      displayedImage = image
      transitionImage = image
      return
    }

    if transitionTrackKey == input.trackKey {
      if let image = input.image {
        transitionImage = image
      }
      return
    }

    if pendingTrackKey == input.trackKey {
      guard let image = input.image else { return }
      startTransition(to: input.trackKey, image: image)
      return
    }

    prepareTransition(to: input)
  }

  private func prepareTransition(to input: ArtworkInput) {
    artworkWaitTask?.cancel()
    flipTask?.cancel()
    resetRotation()
    pendingTrackKey = input.trackKey
    transitionTrackKey = nil
    transitionImage = input.image

    if let image = input.image {
      startTransition(to: input.trackKey, image: image)
      return
    }

    let targetTrackKey = input.trackKey
    artworkWaitTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled, pendingTrackKey == targetTrackKey else { return }
      startTransition(to: targetTrackKey, image: nil)
    }
  }

  private func startTransition(to newTrackKey: String, image newImage: NSImage?) {
    artworkWaitTask?.cancel()
    artworkWaitTask = nil
    flipTask?.cancel()
    pendingTrackKey = nil
    transitionTrackKey = newTrackKey
    transitionImage = newImage

    guard !motionReduced else {
      displayedImage = newImage
      displayedTrackKey = newTrackKey
      transitionTrackKey = nil
      transitionImage = nil
      rotation = 0
      return
    }

    flipTask = Task { @MainActor in
      withAnimation(.easeIn(duration: 0.2)) {
        rotation = -90
      }

      try? await Task.sleep(for: .milliseconds(200))
      guard !Task.isCancelled, transitionTrackKey == newTrackKey else { return }

      var swapTransaction = Transaction()
      swapTransaction.disablesAnimations = true
      withTransaction(swapTransaction) {
        displayedImage = transitionImage
        displayedTrackKey = newTrackKey
        rotation = 90
      }

      try? await Task.sleep(for: .milliseconds(16))
      guard !Task.isCancelled, transitionTrackKey == newTrackKey else { return }

      withAnimation(.easeOut(duration: 0.24)) {
        rotation = 0
      }

      try? await Task.sleep(for: .milliseconds(240))
      guard !Task.isCancelled else { return }
      transitionTrackKey = nil
      transitionImage = nil
      flipTask = nil
    }
  }

  private var motionReduced: Bool {
    reduceMotion || reduceMotionOverride || !animationsEnabled
  }

  private func resetRotation() {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      rotation = 0
    }
  }
}

private struct ArtworkInput: Equatable {
  let trackKey: String
  let image: NSImage?

  static func == (lhs: ArtworkInput, rhs: ArtworkInput) -> Bool {
    lhs.trackKey == rhs.trackKey && lhs.image === rhs.image
  }
}
