import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import SwiftUI

enum OnboardingPage: Int {
  case welcome
  case permissions
  case indicators

  var next: Self {
    Self(rawValue: rawValue + 1) ?? .indicators
  }

  var previous: Self {
    Self(rawValue: rawValue - 1) ?? .welcome
  }
}

enum OnboardingPermissionPolicy {
  static func shouldPoll(
    page: OnboardingPage,
    accessibilityGranted: Bool,
    deviceControlGranted: Bool
  ) -> Bool {
    page == .permissions
      && !(accessibilityGranted && deviceControlGranted)
  }
}

struct VelnorrOnboardingView: View {
  let onComplete: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var accessibilityGranted = false
  @State private var deviceControlGranted = false

  @State private var macOSIndicatorDisabled = false
  @State private var logiIndicatorDisabled = false
  @State private var logiOptionsInstalled = false

  @State private var page: OnboardingPage = .welcome
  @State private var showThirdPartyIndicators = false

  private var language: AppLanguage {
    AppLanguage.selected
  }

  private var isRightToLeft: Bool {
    language.isRightToLeft
  }

  private var requiredPermissionsGranted: Bool {
    accessibilityGranted && deviceControlGranted
  }

  init(onComplete: @escaping () -> Void) {
    self.onComplete = onComplete
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView(.vertical) {
        pageContent
          .frame(
            maxWidth: 420,
            alignment: .leading
          )
          .padding(.vertical, 28)
          .frame(
            maxWidth: .infinity,
            alignment: .center
          )
      }
      .scrollIndicators(.automatic)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
      )

      Divider()

      HStack(
        alignment: .center,
        spacing: 12
      ) {
        VStack(
          alignment: .leading,
          spacing: 4
        ) {
          Text(
            page == .permissions
              ? L(
                "You can change these permissions later in System Settings."
              )
              : L(
                "Your setup choices can be changed later in Velnorr Settings."
              )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        }

        Spacer(minLength: 12)

        if page != .welcome {
          Button(L("Back")) {
            withAnimation(
              reduceMotion
                ? .easeOut(duration: 0.12)
                : .easeInOut(duration: 0.2)
            ) {
              page = page.previous
            }
          }
          .buttonStyle(.bordered)
        }

        Button(
          page == .indicators
            ? L("Finish setup")
            : L("Next")
        ) {
          if page == .indicators {
            onComplete()
          } else {
            withAnimation(
              reduceMotion
                ? .easeOut(duration: 0.12)
                : .easeInOut(duration: 0.2)
            ) {
              page = page.next
            }
          }
        }
        .disabled(
          (page == .permissions && !requiredPermissionsGranted)
            || (
              page == .indicators
                && !externalIndicatorSetupComplete
            )
        )
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .padding(.vertical, 8)
    }
    .frame(
      width: 520,
      height: 640,
      alignment: .top
    )
    .environment(
      \.layoutDirection,
      isRightToLeft
        ? .rightToLeft
        : .leftToRight
    )
    .background(onboardingBackground)

    .onAppear {
      logiOptionsInstalled =
        FileManager.default.fileExists(
          atPath: "/Applications/logioptionsplus.app"
        )

      _ = refreshPermissions()
    }

    .onReceive(
      NotificationCenter.default.publisher(
        for: NSApplication.didBecomeActiveNotification
      )
    ) { _ in
      guard page == .permissions else {
        return
      }

      _ = refreshPermissions()
    }

    .task(id: page) {
      guard page == .permissions else {
        return
      }

      while !Task.isCancelled {
        let permissions = refreshPermissions()

        guard OnboardingPermissionPolicy.shouldPoll(
          page: page,
          accessibilityGranted: permissions.accessibility,
          deviceControlGranted: permissions.deviceControl
        ) else {
          return
        }

        try? await Task.sleep(
          for: .seconds(1)
        )
      }
    }
  }

  // MARK: - Page Content

  @ViewBuilder
  private var pageContent: some View {
    switch page {

    // MARK: Welcome

    case .welcome:
      VStack(
        alignment: .leading,
        spacing: 13
      ) {
        introduction

        featureRow(
          icon: "rectangle.3.group.fill",
          title: L("Everything at a glance"),
          detail: L(
            "See media, volume, brightness, battery, and connected devices in one consistent HUD."
          ),
          color: .cyan
        )

        featureRow(
          icon: "sparkles",
          title: L("A calmer way to interact"),
          detail: L(
            "Lightweight animations and clear feedback keep you informed without interrupting your flow."
          ),
          color: .purple
        )

        featureRow(
          icon: "capslock.fill",
          title: L("Caps Lock, redesigned"),
          detail: L(
            "Velnorr gives Caps Lock its own subtle indicator so your HUD stays clean and familiar."
          ),
          color: .orange
        )

        VStack(
          alignment: .leading,
          spacing: 5
        ) {
          Text(L("One-time setup"))
            .font(.title3.weight(.semibold))

          Text(
            L(
              "Velnorr needs two macOS permissions to intercept system keys and replace the native volume, brightness, and Caps Lock HUDs."
            )
          )
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(
            horizontal: false,
            vertical: true
          )
        }
      }

    // MARK: Permissions

    case .permissions:
      VStack(
        alignment: .leading,
        spacing: 13
      ) {
        Text(L("macOS permissions"))
          .font(.title3.weight(.semibold))

        Text(
          L(
            "Enable both permissions below so Velnorr can receive system key events and replace the native macOS HUDs."
          )
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(
          horizontal: false,
          vertical: true
        )
        .padding(.bottom, 10)

        permissionCard(
          icon: "accessibility",
          title: L("Accessibility"),
          detail: accessibilityGranted
            ? L(
              "Accessibility permission is enabled."
            )
            : L(
              "Required to intercept and suppress native macOS HUD events."
            ),
          granted: accessibilityGranted,
          action: requestAccessibilityPermission
        )

        permissionCard(
          icon: "keyboard.badge.ellipsis",
          title: L("Device Control & Data Access"),
          detail: deviceControlGranted
            ? L(
              "Device Control & Data Access permission is enabled."
            )
            : L(
              "Required for Velnorr to receive volume, brightness, and Caps Lock key events."
            ),
          granted: deviceControlGranted,
          action: requestDeviceControlPermission
        )
        .padding(.top, 10)

        if !requiredPermissionsGranted {
          permissionHelp
            .padding(.top, 5)
        }
      }

    // MARK: Indicators

    case .indicators:
      VStack(
        alignment: .leading,
        spacing: 13
      ) {
        Text(
          L(
            "Disable competing Caps Lock indicators"
          )
        )
        .font(.title3.weight(.semibold))

        Text(
          L(
            "Disable the macOS indicator so only Velnorr's indicator remains visible."
          )
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(
          horizontal: false,
          vertical: true
        )
        .padding(.bottom, 4)

        competingIndicatorCard(
          icon: "apple.logo",
          title: L(
            "macOS Caps Lock indicator"
          ),
          detail: L(
            "Copy the command, run it in Terminal, then restart your Mac or log out and back in."
          ),
          completed: macOSIndicatorDisabled,
          primaryTitle: L(
            "Copy Terminal command"
          ),
          primaryAction: copyMacOSIndicatorCommand,
          completionAction: {
            macOSIndicatorDisabled = true
          }
        )

        Button {
          showThirdPartyIndicators.toggle()
        } label: {
          HStack(spacing: 8) {
            Text(
              L(
                "Optional / third-party apps"
              )
            )
            .font(.headline)

            Spacer(minLength: 12)

            Image(
              systemName:
                showThirdPartyIndicators
                  ? "chevron.down"
                  : "chevron.right"
            )
            .font(
              .system(
                size: 12,
                weight: .semibold
              )
            )
            .foregroundStyle(.secondary)
            .id(showThirdPartyIndicators)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
          L(
            showThirdPartyIndicators
              ? "Expanded"
              : "Collapsed"
          )
        )
        .padding(.top, 8)

        if showThirdPartyIndicators {
          if logiOptionsInstalled {
            competingIndicatorCard(
              icon: "keyboard",
              title: L(
                "Logi Options+ Caps Lock notification"
              ),
              detail: L(
                "Open Logi Options+ → Settings → Notifications and turn off Caps Lock notifications."
              ),
              completed: logiIndicatorDisabled,
              primaryTitle: L(
                "Open Logi Options+"
              ),
              primaryAction: openLogiOptions,
              completionAction: {
                logiIndicatorDisabled = true
              }
            )
          } else {
            Text(
              L(
                "Logi Options+ was not detected on this Mac."
              )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  // MARK: - Permission Help

  private var permissionHelp: some View {
    VStack(
      alignment: .leading,
      spacing: 7
    ) {
      HStack(
        alignment: .top,
        spacing: 8
      ) {
        Image(systemName: "info.circle")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .padding(.top, 1)

        Text(
          L(
            "After enabling Velnorr in System Settings, return to the app. Velnorr will detect the permission automatically."
          )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(
          horizontal: false,
          vertical: true
        )
      }

      if !deviceControlGranted {
        HStack(
          alignment: .top,
          spacing: 8
        ) {
          Image(systemName: "gearshape")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.top, 1)

          Text(
            L(
              "In System Settings, look under Privacy & Security → Device Control & Data Access and enable Velnorr."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(
            horizontal: false,
            vertical: true
          )
        }
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(
      alignment: .center,
      spacing: 14
    ) {
      HStack(
        alignment: .center,
        spacing: 16
      ) {
        brandLogo

        Text("Velnorr")
          .font(
            .system(
              size: 36,
              weight: .regular,
              design: .rounded
            )
          )
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      Text(
        L(
          "Your Dynamic Island for macOS"
        )
      )
      .font(
        .system(
          size: 14,
          weight: .regular,
          design: .rounded
        )
      )
      .foregroundStyle(.secondary)
      .lineLimit(2)
      .fixedSize(
        horizontal: false,
        vertical: true
      )
    }
    .padding(.horizontal, 32)
    .padding(.top, 36)
    .padding(.bottom, 32)
    .frame(
      maxWidth: 420,
      alignment: .center
    )
    .frame(
      maxWidth: .infinity,
      alignment: .center
    )
    .background(onboardingBackground)
  }

  // MARK: - Background

  private var onboardingBackground: Color {
    Color(
      red: 30.0 / 255.0,
      green: 30.0 / 255.0,
      blue: 30.0 / 255.0
    )
  }

  // MARK: - Brand Logo

  private var brandLogo: some View {
    Group {
      if let image =
        ResourceImages.velnorrLogo
      {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(
          systemName: "waveform"
        )
        .font(
          .system(
            size: 42,
            weight: .semibold
          )
        )
        .foregroundStyle(.black)
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
        .background(.white)
      }
    }
    .frame(
      width: 64,
      height: 64
    )
    .clipShape(
      RoundedRectangle(
        cornerRadius: 12,
        style: .continuous
      )
    )
  }

  // MARK: - Introduction

  private var introduction: some View {
    VStack(
      alignment: .leading,
      spacing: 5
    ) {
      Text(
        L(
          "A calmer way to see what matters"
        )
      )
      .font(
        .title3.weight(.semibold)
      )

      Text(
        L(
          "Velnorr lives in your menu bar and brings media, sound, brightness, battery, and device updates into one beautiful HUD."
        )
      )
      .font(.body)
      .foregroundStyle(.secondary)
      .fixedSize(
        horizontal: false,
        vertical: true
      )
    }
  }

  // MARK: - Feature Row

  private func featureRow(
    icon: String,
    title: String,
    detail: String,
    color: Color
  ) -> some View {
    HStack(
      alignment: .center,
      spacing: 12
    ) {
      Image(systemName: icon)
        .font(
          .system(
            size: 16,
            weight: .semibold
          )
        )
        .foregroundStyle(color)
        .frame(
          width: 30,
          height: 30
        )

      VStack(
        alignment: .leading,
        spacing: 2
      ) {
        Text(title)
          .font(.headline)

        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(
            horizontal: false,
            vertical: true
          )
      }
    }
  }

  // MARK: - Permission Card

  private func permissionCard(
    icon: String,
    title: String,
    detail: String,
    granted: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(
        alignment: .center,
        spacing: 14
      ) {
        Image(systemName: icon)
          .font(
            .system(
              size: 22,
              weight: .semibold
            )
          )
          .foregroundStyle(
            granted
              ? .green
              : .orange
          )
          .frame(
            width: 34,
            height: 34
          )

        VStack(
          alignment: .leading,
          spacing: 2
        ) {
          Text(title)
            .font(.headline)

          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(
              horizontal: false,
              vertical: true
            )
        }

        Spacer(minLength: 8)

        Image(
          systemName:
            granted
              ? "checkmark.circle.fill"
              : "exclamationmark.circle"
        )
        .font(
          .system(
            size: 20,
            weight: .semibold
          )
        )
        .foregroundStyle(
          granted
            ? .green
            : .orange
        )
        .id(granted)
        .transition(
          .scale.combined(
            with: .opacity
          )
        )
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .animation(
      reduceMotion
        ? .easeOut(duration: 0.12)
        : .easeInOut(duration: 0.2),
      value: granted
    )
  }

  // MARK: - Competing Indicator Card

  private func competingIndicatorCard(
    icon: String,
    title: String,
    detail: String,
    completed: Bool,
    primaryTitle: String,
    primaryAction: @escaping () -> Void,
    completionAction: @escaping () -> Void
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: 9
    ) {
      HStack(
        alignment: .top,
        spacing: 14
      ) {
        Image(systemName: icon)
          .font(
            .system(
              size: 22,
              weight: .semibold
            )
          )
          .foregroundStyle(
            completed
              ? .green
              : .orange
          )
          .frame(
            width: 34,
            height: 34
          )

        VStack(
          alignment: .leading,
          spacing: 3
        ) {
          Text(title)
            .font(.headline)

          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(
              horizontal: false,
              vertical: true
            )
        }
      }

      HStack(spacing: 10) {
        Button(
          primaryTitle,
          action: primaryAction
        )
        .buttonStyle(.bordered)

        Button(
          L("I disabled it"),
          action: completionAction
        )
        .buttonStyle(
          .borderedProminent
        )
        .tint(
          completed
            ? .green
            : .accentColor
        )
      }
      .padding(.leading, 48)
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(12)
    .background(
      .white.opacity(0.06),
      in: RoundedRectangle(
        cornerRadius: 10
      )
    )
  }

  // MARK: - Permission Requests

  private func requestAccessibilityPermission() {
    _ = SystemEventTapPermission
      .requestAccessibility()

    Task { @MainActor in
      try? await Task.sleep(
        for: .milliseconds(750)
      )

      let permissions =
        refreshPermissions()

      if !permissions.accessibility {
        openAccessibilitySettings()
      }
    }
  }

  private func requestDeviceControlPermission() {
    _ = SystemEventTapPermission
      .requestInputMonitoring()

    Task { @MainActor in
      try? await Task.sleep(
        for: .milliseconds(750)
      )

      let permissions =
        refreshPermissions()

      if !permissions.deviceControl {
        openDeviceControlAndDataAccessSettings()
      }
    }
  }

  // MARK: - Permission State

  @discardableResult
  private func refreshPermissions() -> (
    accessibility: Bool,
    deviceControl: Bool
  ) {
    let status =
      SystemEventTapPermission.status

    accessibilityGranted =
      status.accessibilityGranted

    deviceControlGranted =
      status.listenEventsGranted

    return (
      accessibility:
        status.accessibilityGranted,
      deviceControl:
        status.listenEventsGranted
    )
  }

  // MARK: - Setup State

  private var externalIndicatorSetupComplete: Bool {
    macOSIndicatorDisabled
  }

  // MARK: - System Settings

  private func openAccessibilitySettings() {
    openPrivacyPane(
      "Privacy_Accessibility"
    )
  }

  private func openDeviceControlAndDataAccessSettings() {
    // ListenEvent is the TCC permission backing the system
    // keyboard/input access Velnorr needs.
    //
    // On newer macOS versions Apple may display this permission
    // under "Device Control & Data Access".
    openPrivacyPane(
      "Privacy_ListenEvent"
    )
  }

  // MARK: - Caps Lock Indicator

  private func copyMacOSIndicatorCommand() {
    let command =
      "sudo defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor -dict-add Enabled -bool NO"

    NSPasteboard.general
      .clearContents()

    NSPasteboard.general.setString(
      command,
      forType: .string
    )

    NSWorkspace.shared.open(
      URL(
        fileURLWithPath:
          "/System/Applications/Utilities/Terminal.app"
      )
    )
  }

  // MARK: - Logi Options+

  private func openLogiOptions() {
    let appURL = URL(
      fileURLWithPath:
        "/Applications/logioptionsplus.app"
    )

    if FileManager.default.fileExists(
      atPath: appURL.path
    ) {
      NSWorkspace.shared
        .openApplication(
          at: appURL,
          configuration:
            NSWorkspace.OpenConfiguration()
        )
    } else if let url = URL(
      string:
        "https://www.logitech.com/optionsplus"
    ) {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: - Privacy Pane

  private func openPrivacyPane(
    _ pane: String
  ) {
    guard let url = URL(
      string:
        "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    ) else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  // MARK: - Localization

  private func L(
    _ key: String
  ) -> String {
    language.localized(key)
  }
}