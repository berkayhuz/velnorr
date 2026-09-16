import Foundation
import SwiftUI

struct NowPlayingInfoView: View {
  let title: String
  let artist: String
  let marqueeSpacing: CGFloat
  let scrollingEnabled: Bool
  let scrollSpeed: CGFloat
  let showTitle: Bool
  let showArtist: Bool

  private let foregroundColor = Color(
    red: 172 / 255,
    green: 172 / 255,
    blue: 172 / 255
  )

  init(
    title: String,
    artist: String,
    marqueeSpacing: CGFloat = 42,
    scrollingEnabled: Bool = true,
    scrollSpeed: CGFloat = 25,
    showTitle: Bool = true,
    showArtist: Bool = true
  ) {
    self.title = title
    self.artist = artist
    self.marqueeSpacing = marqueeSpacing
    self.scrollingEnabled = scrollingEnabled
    self.scrollSpeed = scrollSpeed
    self.showTitle = showTitle
    self.showArtist = showArtist
  }

  private var description: String {
    let resolvedTitle = title.isEmpty ? "Şarkı" : title
    let resolvedArtist = artist.isEmpty ? "Bilinmeyen Sanatçı" : artist
    switch (showTitle, showArtist) {
    case (true, true): return "\(resolvedTitle)  •  \(resolvedArtist)"
    case (true, false): return resolvedTitle
    case (false, true): return resolvedArtist
    case (false, false): return ""
    }
  }

  var body: some View {
    InfiniteMarqueeText(
      text: description,
      color: foregroundColor,
      spacing: marqueeSpacing,
      scrollingEnabled: scrollingEnabled,
      scrollSpeed: scrollSpeed
    )
  }
}

private struct InfiniteMarqueeText: View {
  let text: String
  let color: Color
  let spacing: CGFloat
  let scrollingEnabled: Bool
  let scrollSpeed: CGFloat

  @State private var textWidth: CGFloat = 0
  @State private var startDate = Date()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("reduceMotionOverride") private var reduceMotionOverride = false
  @AppStorage("appearanceAnimations") private var animationsEnabled = true

  private let speed: CGFloat = 25

  var body: some View {
    GeometryReader { geometry in
      if reduceMotion || reduceMotionOverride || !animationsEnabled || !scrollingEnabled
        || textWidth <= geometry.size.width
      {
        measuredMarqueeLabel
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        TimelineView(
          .animation(minimumInterval: VelnorrTimelineCadence.marqueeInterval)
        ) { timeline in
          let travel = max(1, textWidth + spacing)
          let elapsed = max(0, timeline.date.timeIntervalSince(startDate))
          let offset = -CGFloat(elapsed * Double(scrollSpeed))
            .truncatingRemainder(dividingBy: travel)

          HStack(spacing: spacing) {
            measuredMarqueeLabel
            marqueeLabel
          }
          .offset(x: offset)
          .frame(minWidth: geometry.size.width, alignment: .leading)
        }
      }
    }
    .clipped()
    .mask {
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: 0.04),
          .init(color: .black, location: 0.94),
          .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
    }
    .onPreferenceChange(MarqueeTextWidthKey.self) { textWidth = $0 }
    .onChange(of: text) { _ in startDate = Date() }
  }

  private var marqueeLabel: some View {
    HStack(spacing: 9) {
      Image(systemName: "music.note")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 14)

      Text(text)
        .font(.system(size: 12, weight: .semibold))
        .tracking(0.48)
    }
    .foregroundStyle(color)
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)
  }

  private var measuredMarqueeLabel: some View {
    marqueeLabel
      .background {
        GeometryReader { labelGeometry in
          Color.clear.preference(
            key: MarqueeTextWidthKey.self,
            value: labelGeometry.size.width
          )
        }
      }
  }
}

private struct MarqueeTextWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
