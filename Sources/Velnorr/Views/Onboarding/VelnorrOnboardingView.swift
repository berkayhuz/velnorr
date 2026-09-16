import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import SwiftUI

enum OnboardingPage: Int {
  case welcome
  case permissions
  case indicators

  var next: Self { Self(rawValue: rawValue + 1) ?? .indicators }
  var previous: Self { Self(rawValue: rawValue - 1) ?? .welcome }
}

enum OnboardingPermissionPolicy {
  static func shouldPoll(
    page: OnboardingPage,
    accessibilityGranted: Bool,
    listenEventsGranted: Bool
  ) -> Bool {
    page == .permissions && (
      !accessibilityGranted
        || !listenEventsGranted
    )
  }
}

struct VelnorrOnboardingView: View {
  let onComplete: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var accessibilityGranted = false
  @State private var listenEventsGranted = false
  @State private var macOSIndicatorDisabled = false
  @State private var logiIndicatorDisabled = false
  @State private var logiOptionsInstalled = false
  @State private var page: OnboardingPage = .welcome
  @State private var showThirdPartyIndicators = false

  private var language: AppLanguage { AppLanguage.selected }
  private var isRightToLeft: Bool { language.isRightToLeft }

  init(onComplete: @escaping () -> Void) {
    self.onComplete = onComplete
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView(.vertical) {
        pageContent
          .frame(maxWidth: 420, alignment: .leading)
          .padding(.vertical, 28)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .scrollIndicators(.automatic)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(page == .permissions
            ? L("You can change these permissions later in System Settings.")
            : L("Your setup choices can be changed later in Velnorr Settings."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer(minLength: 12)

        if page != .welcome {
          Button(L("Back")) {
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2)) {
              page = page.previous
            }
          }
          .buttonStyle(.bordered)
        }

        Button(page == .indicators ? L("Finish setup") : L("Next")) {
          if page == .indicators {
            onComplete()
          } else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2)) {
              page = page.next
            }
          }
        }
        .disabled(page == .indicators && !externalIndicatorSetupComplete)
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .padding(.vertical, 8)
    }
    .frame(width: 520, height: 640, alignment: .top)
    .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    .background(onboardingBackground)
    .onAppear {
      logiOptionsInstalled = FileManager.default.fileExists(
        atPath: "/Applications/logioptionsplus.app"
      )
      _ = refreshPermissions()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      guard page == .permissions else { return }
      _ = refreshPermissions()
    }
    .task(id: page) {
      guard page == .permissions else { return }
      while !Task.isCancelled {
        let permissions = refreshPermissions()
        guard OnboardingPermissionPolicy.shouldPoll(
          page: page,
          accessibilityGranted: permissions.accessibility,
          listenEventsGranted: permissions.listenEvents
        ) else { return }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  @ViewBuilder
  private var pageContent: some View {
    switch page {
    case .welcome:
      VStack(alignment: .leading, spacing: 13) {
        introduction

        featureRow(
          icon: "rectangle.3.group.fill",
          title: L("Everything at a glance"),
          detail: L("See media, volume, brightness, battery, and connected devices in one consistent HUD."),
          color: .cyan
        )

        featureRow(
          icon: "sparkles",
          title: L("A calmer way to interact"),
          detail: L("Lightweight animations and clear feedback keep you informed without interrupting your flow."),
          color: .purple
        )

        featureRow(
          icon: "capslock.fill",
          title: L("Caps Lock, redesigned"),
          detail: L("Velnorr gives Caps Lock its own subtle indicator so your HUD stays clean and familiar."),
          color: .orange
        )

        VStack(alignment: .leading, spacing: 5) {
          Text(L("One-time setup"))
            .font(.title3.weight(.semibold))
          Text(L("Velnorr needs two macOS permissions to capture system keys and replace the native volume, brightness, and Caps Lock HUDs."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

    case .permissions:
      VStack(alignment: .leading, spacing: 13) {
        Text(L("macOS permissions"))
          .font(.title3.weight(.semibold))
        Text(L("These permissions allow Velnorr to receive system key events and replace the native HUDs."))
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 10)

        permissionCard(
          icon: "accessibility",
          title: L("Accessibility"),
          detail: L("Required to receive and handle system media key events."),
          granted: accessibilityGranted,
          action: openAccessibilitySettings
        )

        permissionCard(
          icon: "keyboard",
          title: L("Input Monitoring"),
          detail: L("Required to listen for volume, brightness, and Caps Lock key events."),
          granted: listenEventsGranted,
          action: openInputMonitoringSettings
        )
        .padding(.top, 10)
      }

    case .indicators:
      VStack(alignment: .leading, spacing: 13) {
        Text(L("Disable competing Caps Lock indicators"))
          .font(.title3.weight(.semibold))
        Text(L("Disable the macOS indicator so only Velnorr's indicator remains visible."))
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 4)

        competingIndicatorCard(
          icon: "apple.logo",
          title: L("macOS Caps Lock indicator"),
          detail: L("Copy the command, run it in Terminal, then restart your Mac or log out and back in."),
          completed: macOSIndicatorDisabled,
          primaryTitle: L("Copy Terminal command"),
          primaryAction: copyMacOSIndicatorCommand,
          completionAction: { macOSIndicatorDisabled = true }
        )

        Button {
          // Keep the accordion layout deterministic. Animating the parent VStack
          // makes the fixed-size onboarding window re-center its entire content,
          // which causes the sections above to jump while this area opens.
          showThirdPartyIndicators.toggle()
        } label: {
          HStack(spacing: 8) {
            Text(L("Optional / third-party apps"))
              .font(.headline)
            Spacer(minLength: 12)
            Image(systemName: showThirdPartyIndicators ? "chevron.down" : "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.secondary)
              .id(showThirdPartyIndicators)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
          L(showThirdPartyIndicators ? "Expanded" : "Collapsed")
        )
        .padding(.top, 8)

        if showThirdPartyIndicators {
          if logiOptionsInstalled {
            competingIndicatorCard(
              icon: "keyboard",
              title: L("Logi Options+ Caps Lock notification"),
              detail: L("Open Logi Options+ → Settings → Notifications and turn off Caps Lock notifications."),
              completed: logiIndicatorDisabled,
              primaryTitle: L("Open Logi Options+"),
              primaryAction: openLogiOptions,
              completionAction: { logiIndicatorDisabled = true }
            )
          } else {
            Text(L("Logi Options+ was not detected on this Mac."))
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .center, spacing: 14) {
      HStack(alignment: .center, spacing: 16) {
        brandLogo

        Text("Velnorr")
          .font(.system(size: 36, weight: .regular, design: .rounded))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      Text(L("Your Dynamic Island for macOS"))
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 32)
    .padding(.top, 36)
    .padding(.bottom, 32)
    .frame(maxWidth: 420, alignment: .center)
    .frame(maxWidth: .infinity, alignment: .center)
    .background(onboardingBackground)
  }

  private var onboardingBackground: Color {
    Color(red: 30.0 / 255.0, green: 30.0 / 255.0, blue: 30.0 / 255.0)
  }

  private var brandLogo: some View {
    Group {
      if let image = ResourceImages.velnorrLogo {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "waveform")
          .font(.system(size: 42, weight: .semibold))
          .foregroundStyle(.black)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.white)
      }
    }
    .frame(width: 64, height: 64)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(L("A calmer way to see what matters"))
        .font(.title3.weight(.semibold))

      Text(L("Velnorr lives in your menu bar and brings media, sound, brightness, battery, and device updates into one beautiful HUD."))
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func featureRow(icon: String, title: String, detail: String, color: Color) -> some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 30, height: 30)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func permissionCard(
    icon: String,
    title: String,
    detail: String,
    granted: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(granted ? .green : .orange)
          .frame(width: 34, height: 34)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)

          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 8)

        Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(granted ? .green : .orange)
          .id(granted)
          .transition(.scale.combined(with: .opacity))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2), value: granted)
  }

  private func competingIndicatorCard(
    icon: String,
    title: String,
    detail: String,
    completed: Bool,
    primaryTitle: String,
    primaryAction: @escaping () -> Void,
    completionAction: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(completed ? .green : .orange)
          .frame(width: 34, height: 34)

        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline)
          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      HStack(spacing: 10) {
        Button(primaryTitle, action: primaryAction)
          .buttonStyle(.bordered)
        Button(L("I disabled it"), action: completionAction)
          .buttonStyle(.borderedProminent)
          .tint(completed ? .green : .accentColor)
      }
      .padding(.leading, 48)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
  }

  private func refreshPermissions() -> (accessibility: Bool, listenEvents: Bool) {
    let permissions = (
      accessibility: AXIsProcessTrusted(),
      listenEvents: CGPreflightListenEventAccess()
    )
    accessibilityGranted = permissions.accessibility
    listenEventsGranted = permissions.listenEvents
    return permissions
  }

  private var externalIndicatorSetupComplete: Bool {
    macOSIndicatorDisabled
  }

  private func openAccessibilitySettings() {
    openPrivacyPane("Privacy_Accessibility")
  }

  private func openInputMonitoringSettings() {
    openPrivacyPane("Privacy_ListenEvent")
  }

  private func copyMacOSIndicatorCommand() {
    let command = "sudo defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor -dict-add Enabled -bool NO"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(command, forType: .string)
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
  }

  private func openLogiOptions() {
    let appURL = URL(fileURLWithPath: "/Applications/logioptionsplus.app")
    if FileManager.default.fileExists(atPath: appURL.path) {
      NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(URL(string: "https://www.logitech.com/optionsplus")!)
    }
  }

  private func openPrivacyPane(_ pane: String) {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func L(_ key: String) -> String {
    language.localized(key)
  }
}
