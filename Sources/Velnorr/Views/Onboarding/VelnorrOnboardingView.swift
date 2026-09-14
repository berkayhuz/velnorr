import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import SwiftUI

struct VelnorrOnboardingView: View {
  let onComplete: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var accessibilityGranted = false
  @State private var listenEventsGranted = false

  private var language: AppLanguage { AppLanguage.selected }
  private var isRightToLeft: Bool { language.isRightToLeft }

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          introduction

          VStack(alignment: .leading, spacing: 12) {
            Text(L("One-time setup"))
              .font(.title3.weight(.semibold))

            Text(L("Velnorr needs two macOS permissions to capture system media keys and replace the native volume and brightness HUDs."))
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            permissionCard(
              icon: "accessibility",
              title: L("Accessibility"),
              detail: L("Required to receive and handle system media key events."),
              granted: accessibilityGranted,
              actionTitle: L("Open Accessibility Settings"),
              action: openAccessibilitySettings
            )

            permissionCard(
              icon: "keyboard",
              title: L("Input Monitoring"),
              detail: L("Required to listen for volume and brightness key events."),
              granted: listenEventsGranted,
              actionTitle: L("Open Input Monitoring Settings"),
              action: openInputMonitoringSettings
            )
          }

          Text(L("Your permissions are checked automatically when Velnorr starts."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
      }

      Divider()

      HStack(spacing: 12) {
        Text(L("You can change these permissions later in System Settings."))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)

        Spacer(minLength: 12)

        Button(L("Finish setup")) {
          onComplete()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
    .frame(minWidth: 560, minHeight: 500)
    .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    .onAppear(perform: refreshPermissions)
    .onReceive(
      Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    ) { _ in
      refreshPermissions()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center, spacing: 34) {
        brandLogo

        Text("Velnorr")
          .font(.system(size: 56, weight: .regular, design: .default))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      Text(L("Your Dynamic Island for macOS"))
        .font(.system(size: 28, weight: .regular, design: .default))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 34)
    .padding(.vertical, 30)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var brandLogo: some View {
    Group {
      if let url = Bundle.module.url(forResource: "velnorr-logo", withExtension: "svg"),
        let image = NSImage(contentsOf: url)
      {
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
    .frame(width: 144, height: 144)
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L("A calmer way to see what matters"))
        .font(.title3.weight(.semibold))

      Text(L("Velnorr lives in your menu bar and brings media, sound, brightness, battery, and device updates into one beautiful HUD."))
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func permissionCard(
    icon: String,
    title: String,
    detail: String,
    granted: Bool,
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(granted ? .green : .orange)
        .frame(width: 30, height: 30)
        .background(
          (granted ? Color.green : Color.orange).opacity(0.12),
          in: RoundedRectangle(cornerRadius: 8)
        )

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Text(title)
            .font(.headline)
          Text(granted ? L("Permission granted") : L("Permission needed"))
            .font(.caption.weight(.medium))
            .foregroundStyle(granted ? .green : .orange)
        }

        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if !granted {
          Button(actionTitle, action: action)
            .buttonStyle(.link)
            .padding(.top, 2)
        }
      }

      Spacer(minLength: 8)

      Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(granted ? .green : .orange)
        .id(granted)
        .transition(.scale.combined(with: .opacity))
    }
    .padding(16)
    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2), value: granted)
  }

  private func refreshPermissions() {
    accessibilityGranted = AXIsProcessTrusted()
    listenEventsGranted = CGPreflightListenEventAccess()
  }

  private func openAccessibilitySettings() {
    openPrivacyPane("Privacy_Accessibility")
  }

  private func openInputMonitoringSettings() {
    openPrivacyPane("Privacy_ListenEvent")
  }

  private func openPrivacyPane(_ pane: String) {
    guard let url = URL(string: "x-apple-systempreferences:com.apple.preference.security?\(pane)")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func L(_ key: String) -> String {
    language.localized(key)
  }
}
