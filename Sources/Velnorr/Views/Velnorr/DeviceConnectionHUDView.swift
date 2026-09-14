import SwiftUI

struct DeviceConnectionHUDView: View {
  let device: ConnectedAppleDevice
  let centerGap: CGFloat
  let leftSideWidth: CGFloat
  let rightSideWidth: CGFloat
  let height: CGFloat
  let topRadius: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("reduceMotionOverride") private var reduceMotionOverride = false
  @AppStorage("appearanceAnimations") private var animationsEnabled = true
  @State private var iconVisible = false
  @State private var ringProgress: CGFloat = 0
  @State private var checkmarkVisible = false

  var body: some View {
    HStack(spacing: 0) {
      sideRegion(isLeft: true, width: leftSideWidth) {
        Image(systemName: device.symbolName)
          .font(.system(size: 19, weight: .medium))
          .symbolRenderingMode(.monochrome)
          .foregroundStyle(.white.opacity(0.94))
          .scaleEffect(iconVisible ? 1 : 0.45)
          .rotationEffect(.degrees(iconVisible ? 0 : -18))
          .opacity(iconVisible ? 1 : 0)
      }

      Color.clear
        .frame(width: centerGap)

      sideRegion(isLeft: false, width: rightSideWidth) {
        batteryIndicator
      }
    }
    .frame(height: height)
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(device.name) connected")
    .accessibilityValue(
      device.batteryPercentage.map { "Battery \($0) percent" } ?? "Connected"
    )
    .onAppear {
      animateEntrance()
    }
    .onChange(of: device.batteryPercentage) { _ in
      animateBatteryUpdate()
    }
  }

  private var batteryIndicator: some View {
    return ZStack {
      Circle()
        .stroke(Color.white.opacity(0.2), lineWidth: 2.6)

      Circle()
        .trim(from: 0, to: ringProgress)
        .stroke(
          ringColor,
          style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))

      if let battery = device.batteryPercentage {
        Text("\(battery)")
          .font(.system(size: 8, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .transition(.scale.combined(with: .opacity))
      } else {
        Image(systemName: "checkmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .scaleEffect(checkmarkVisible ? 1 : 0.25)
          .opacity(checkmarkVisible ? 1 : 0)
      }
    }
    .frame(width: 24, height: 24)
    .transition(.scale.combined(with: .opacity))
    .animation(
      motionReduced ? .easeOut(duration: 0.12) : VelnorrAnimation.content,
      value: device.batteryPercentage
    )
  }

  private var ringColor: Color {
    guard let battery = device.batteryPercentage else { return .green }
    return batteryColor(battery)
  }

  private var targetRingProgress: CGFloat {
    guard let battery = device.batteryPercentage else { return 1 }
    return CGFloat(battery) / 100
  }

  private func animateEntrance() {
    if motionReduced {
      iconVisible = true
      ringProgress = targetRingProgress
      checkmarkVisible = device.batteryPercentage == nil
      return
    }

    withAnimation(VelnorrAnimation.control) {
      iconVisible = true
    }
    withAnimation(.easeOut(duration: 0.62)) {
      ringProgress = targetRingProgress
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(360))
      guard device.batteryPercentage == nil else { return }
      withAnimation(VelnorrAnimation.control) {
        checkmarkVisible = true
      }
    }
  }

  private func animateBatteryUpdate() {
    checkmarkVisible = false
    guard !motionReduced else {
      ringProgress = targetRingProgress
      return
    }
    ringProgress = 0
    withAnimation(.easeOut(duration: 0.58)) {
      ringProgress = targetRingProgress
    }
  }

  private var motionReduced: Bool {
    reduceMotion || reduceMotionOverride || !animationsEnabled
  }

  private func batteryColor(_ percentage: Int) -> Color {
    switch percentage {
    case ..<20: .red
    case ..<40: .orange
    default: .green
    }
  }

  private func sideRegion<Content: View>(
    isLeft: Bool,
    width: CGFloat,
    @ViewBuilder content: () -> Content
  ) -> some View {
    let isFloatingPill = centerGap == 0
    let edgeInset = min(16, max(8, width / 2 - 10))
    return ZStack {
      content()
        .position(
          x: isFloatingPill
            ? (isLeft ? topRadius + edgeInset : width - topRadius - edgeInset)
            : (isLeft ? (topRadius + width) / 2 : (width - topRadius) / 2),
          y: height / 2
        )
    }
    .frame(width: width, height: height)
  }
}
