import AppKit
import SwiftUI

private func L(_ key: String) -> String {
  AppLanguage.selected.localized(key)
}

struct VelnorrSettingsView: View {
  @AppStorage(AppSettings.expandOnHover) private var expandOnHover = true
  @AppStorage(AppSettings.showInFullscreen) private var showInFullscreen = true
  @AppStorage(AppSettings.externalDisplayMode) private var externalDisplayMode =
    VelnorrDisplayMode.pill.rawValue
  @AppStorage(AppSettings.language) private var language = AppLanguage.system.rawValue

  @State private var selectedSection: SettingsSection? = .general
  @State private var searchText = ""

  private var visibleSections: [SettingsSection] {
    guard !searchText.isEmpty else { return SettingsSection.allCases }
    return SettingsSection.allCases.filter {
      $0.title.localizedCaseInsensitiveContains(searchText)
        || $0.searchTerms.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
  }

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: language) ?? .system
  }

  var body: some View {
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField(selectedLanguage.localized("Search"), text: $searchText)
            .textFieldStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 10)

        ScrollView {
          VStack(alignment: .leading, spacing: 3) {
            ForEach(visibleSections) { section in
              Button {
                selectedSection = section
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: section.icon)
                    .frame(width: 24, alignment: .center)
                  Text(selectedLanguage.localized(section.title))
                  Spacer(minLength: 0)
                }
                  .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                  .foregroundStyle(selectedSection == section ? .white : .primary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 7)
                  .background(
                    selectedSection == section
                      ? Color.accentColor
                      : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                  )
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .frame(maxWidth: .infinity)
            }
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 12)
        }
      }
      .background(Color(nsColor: .windowBackgroundColor))
      .frame(width: 250)

      Group {
        switch selectedSection ?? .general {
        case .general:
          GeneralSettingsPage(
            expandOnHover: $expandOnHover,
            showInFullscreen: $showInFullscreen
          )
        case .displays:
          DisplaySettingsPage(externalDisplayMode: $externalDisplayMode)
        case .language:
          LanguageSettingsPage(language: $language)
        default:
          AdditionalSettingsPage(section: selectedSection ?? .general)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .frame(minWidth: 760, minHeight: 520)
    .background(Color(nsColor: .windowBackgroundColor))
    .id(language)
    .environment(\.locale, Locale(identifier: (AppLanguage(rawValue: language) ?? .system).localeIdentifier))
    .environment(\.layoutDirection, selectedLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
  }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case displays
  case language
  case appearance
  case media
  case volume
  case brightness
  case battery
  case devices
  case notifications
  case accessibility
  case advanced
  case preview
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .displays: "Displays"
    case .language: "Language"
    case .appearance: "Appearance"
    case .media: "Media"
    case .volume: "Volume"
    case .brightness: "Brightness"
    case .battery: "Battery"
    case .devices: "Devices"
    case .notifications: "Notifications"
    case .accessibility: "Accessibility"
    case .advanced: "Advanced"
    case .preview: "Preview"
    case .about: "About"
    }
  }

  var icon: String {
    switch self {
    case .general: "gearshape"
    case .displays: "display.2"
    case .language: "globe"
    case .appearance: "paintbrush"
    case .media: "music.note"
    case .volume: "speaker.wave.2"
    case .brightness: "sun.max"
    case .battery: "battery.75percent"
    case .devices: "headphones"
    case .notifications: "bell"
    case .accessibility: "accessibility"
    case .advanced: "slider.horizontal.3"
    case .preview: "play.rectangle"
    case .about: "info.circle"
    }
  }

  var searchTerms: [String] {
    switch self {
    case .general: ["hover", "fullscreen", "behavior"]
    case .displays: ["external", "screen", "pill", "notch"]
    case .language: ["locale", "translation", "device language", "system default"]
    case .appearance: ["theme", "color", "radius", "animation", "padding"]
    case .media: ["spotify", "apple music", "artwork", "waveform", "marquee"]
    case .volume: ["sound", "speaker", "volume", "hud"]
    case .brightness: ["screen", "sun", "brightness", "display"]
    case .battery: ["charging", "low battery", "power", "percentage"]
    case .devices: ["bluetooth", "airpods", "keyboard", "mouse", "speaker"]
    case .notifications: ["alerts", "notification", "apps"]
    case .accessibility: ["reduce motion", "contrast", "voiceover"]
    case .advanced: ["debug", "cache", "timeout", "polling"]
    case .preview: ["test", "developer", "preview"]
    case .about: ["version", "build", "velnorr"]
    }
  }
}

private struct GeneralSettingsPage: View {
  @Binding var expandOnHover: Bool
  @Binding var showInFullscreen: Bool
  @AppStorage(AppSettings.launchAtLogin) private var launchAtLogin = true
  @State private var showingResetConfirmation = false

  var body: some View {
    SettingsPageContainer(
      icon: "gearshape",
      title: "General",
      subtitle: "Manage Velnorr's behavior and appearance."
    ) {
      Section(AppLanguage.selected.localized("Behavior")) {
        Toggle(AppLanguage.selected.localized("Launch Velnorr at login"), isOn: $launchAtLogin)
        Toggle(AppLanguage.selected.localized("Expand on hover"), isOn: $expandOnHover)
        Toggle(AppLanguage.selected.localized("Show in fullscreen"), isOn: $showInFullscreen)
      }
      Section(L("Reset")) {
        Button(AppLanguage.selected.localized("Reset All Settings"), role: .destructive) {
          showingResetConfirmation = true
        }
        Text(L("Restore Velnorr's original appearance and behavior settings."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .alert(L("Reset all settings?"), isPresented: $showingResetConfirmation) {
      Button(L("Cancel"), role: .cancel) {}
      Button(L("Reset"), role: .destructive) {
        SettingsResetter.reset()
      }
    } message: {
      Text(L("All Velnorr preferences will return to their default values."))
    }
  }
}

private enum SettingsResetter {
  fileprivate static let managedKeys: Set<String> = [
    AppSettings.launchAtLogin,
    AppSettings.expandOnHover,
    AppSettings.showInFullscreen,
    AppSettings.externalDisplayMode,
    AppSettings.horizontalOffset, AppSettings.verticalOffset, AppSettings.language,
    "appearanceAnimations", "appearanceArtwork", "appearanceOpacity", "appearanceTheme",
    "appearanceArtworkSize", "appearanceArtworkRadius", "mediaWaveform", "mediaMarquee",
    "mediaWaveformSpeed", "mediaMarqueeSpeed", "mediaProgressBar", "mediaShowTitle", "mediaShowArtist",
    "mediaSourceIcon", "mediaTrackNavigation", "mediaShuffleButton", "mediaAudioOutputButton", "mediaPlaybackButton",
    "volumeHUD", "brightnessHUD", "volumeBarWidth", "brightnessBarWidth", "volumeIconSize",
    "brightnessIconSize", "volumeBarColor", "brightnessBarColor", "volumeBarHeight", "brightnessBarHeight",
    "batteryIconWidth", "showOnExternalDisplays", "batteryHUD", "deviceHUD", "notificationHUD",
    AppSettings.capsLockHUD, AppSettings.capsLockDisplayDuration, AppSettings.capsLockHUDSize,
    "reduceMotionOverride", "debugLogging", "previewMode", "batteryLowThreshold", "batteryGreenThreshold",
    "batteryDisplayDuration", "volumeDisplayDuration", "brightnessDisplayDuration", "batteryShowCharging",
    "batteryShowUnplugged", "batteryShowLow", "batteryShowFull", "batteryShowThreshold", "deviceAirPods",
    "deviceAppleWatch", "deviceKeyboard", "deviceMouse", "deviceSpeaker", "deviceDisplayDuration",
  ]

  private static func settingsJSON() -> Data? {
    let allSettings = UserDefaults.standard.dictionaryRepresentation()
    var settings = allSettings.filter { managedKeys.contains($0.key) }
    settings["_formatVersion"] = 1
    if let profilesJSON = UserDefaults.standard.string(forKey: "settingsProfiles"),
      let profilesData = profilesJSON.data(using: .utf8),
      let profiles = try? JSONSerialization.jsonObject(with: profilesData) {
      settings["_profiles"] = profiles
    }
    return try? JSONSerialization.data(
      withJSONObject: settings,
      options: [.prettyPrinted, .sortedKeys]
    )
  }

  @MainActor static func copyJSONToClipboard() {
    guard let data = settingsJSON(), let json = String(data: data, encoding: .utf8) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(json, forType: .string)
  }

  @MainActor static func exportJSONToFile() {
    guard let data = settingsJSON() else { return }

    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "velnorr-settings.json"

    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? data.write(to: url, options: .atomic)
  }

  @MainActor static func importJSONFromFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url,
      let data = try? Data(contentsOf: url),
      let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return }

    if let version = values["_formatVersion"] as? Int, version > 1 {
      return
    }

    for (key, value) in values {
      guard managedKeys.contains(key) else { continue }
      UserDefaults.standard.set(value, forKey: key)
    }
    if let profiles = values["_profiles"],
      let profilesData = try? JSONSerialization.data(withJSONObject: profiles),
      let profilesJSON = String(data: profilesData, encoding: .utf8) {
      UserDefaults.standard.set(profilesJSON, forKey: "settingsProfiles")
    }
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
  }

  static func reset() {
    for key in managedKeys {
      UserDefaults.standard.removeObject(forKey: key)
    }
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
  }
}

private struct DisplaySettingsPage: View {
  @Binding var externalDisplayMode: String
  @AppStorage("showOnExternalDisplays") private var showOnExternalDisplays = true
  @AppStorage(AppSettings.horizontalOffset) private var horizontalOffset = 0.0
  @AppStorage(AppSettings.verticalOffset) private var verticalOffset = 0.0

  var body: some View {
    SettingsPageContainer(
      icon: "display.2",
      title: "Displays",
      subtitle: "Choose how Velnorr appears on displays without a physical notch."
    ) {
      Section(L("External displays")) {
        Toggle(L("Show on external displays"), isOn: $showOnExternalDisplays)
        Picker(L("Display style"), selection: $externalDisplayMode) {
          Text(L("Pill")).tag(VelnorrDisplayMode.pill.rawValue)
          Text(L("Simulated notch")).tag(VelnorrDisplayMode.simulatedNotch.rawValue)
        }
        VStack(alignment: .leading, spacing: 6) {
          HStack { Text(L("Horizontal position")); Spacer(); Text("\(Int(horizontalOffset)) pt").foregroundStyle(.secondary) }
          Slider(value: $horizontalOffset, in: -120...120, step: 1)
        }
        VStack(alignment: .leading, spacing: 6) {
          HStack { Text(L("Vertical position")); Spacer(); Text("\(Int(verticalOffset)) pt").foregroundStyle(.secondary) }
          Slider(value: $verticalOffset, in: -40...40, step: 1)
        }
      }
    }
  }
}

private struct LanguageSettingsPage: View {
  @Binding var language: String

  var body: some View {
    SettingsPageContainer(
      icon: "globe",
      title: "Language",
      subtitle: "Choose the language Velnorr uses for its interface."
    ) {
      Section(AppLanguage.selected.localized("Application Language")) {
        Picker(AppLanguage.selected.localized("Language"), selection: $language) {
          ForEach(AppLanguage.allCases) { option in
            Text(option == .system ? L("System Default / Device Language") : option.label)
              .tag(option.rawValue)
          }
        }
        Text(L("System Default follows the device language and falls back to English when unavailable."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

/// Settings that are intentionally opt-in and start with values matching the
/// current Velnorr design. They are persisted now so each feature can be
/// wired to its runtime service without changing the settings UI later.
private struct AdditionalSettingsPage: View {
  let section: SettingsSection
  @AppStorage("appearanceAnimations") private var animations = true
  @AppStorage("appearanceArtwork") private var artwork = true
  @AppStorage("appearanceArtworkSize") private var artworkSize = 18.0
  @AppStorage("appearanceArtworkRadius") private var artworkRadius = 4.0
  @AppStorage("appearanceOpacity") private var opacity = 1.0
  @AppStorage("appearanceTheme") private var appearanceTheme = "black"
  @AppStorage("mediaWaveform") private var waveform = true
  @AppStorage("mediaMarquee") private var marquee = true
  @AppStorage("mediaProgressBar") private var progressBar = true
  @AppStorage("mediaTrackNavigation") private var trackNavigation = true
  @AppStorage("mediaShuffleButton") private var shuffleButton = true
  @AppStorage("mediaAudioOutputButton") private var audioOutputButton = true
  @AppStorage("mediaPlaybackButton") private var playbackButton = true
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
  @AppStorage("volumeHUD") private var volumeHUD = true
  @AppStorage("brightnessHUD") private var brightnessHUD = true
  @AppStorage("batteryHUD") private var batteryHUD = true
  @AppStorage("deviceHUD") private var deviceHUD = true
  @AppStorage("deviceAirPods") private var airPods = true
  @AppStorage("deviceAppleWatch") private var appleWatch = true
  @AppStorage("deviceKeyboard") private var keyboard = true
  @AppStorage("deviceMouse") private var mouse = true
  @AppStorage("deviceSpeaker") private var speaker = true
  @AppStorage("deviceDisplayDuration") private var deviceDisplayDuration = 3.5
  @AppStorage("notificationHUD") private var notificationHUD = true
  @AppStorage(AppSettings.capsLockHUD) private var capsLockHUD = true
  @AppStorage(AppSettings.capsLockDisplayDuration) private var capsLockDisplayDuration = 1.6
  @AppStorage(AppSettings.capsLockHUDSize) private var capsLockHUDSize = 38.0
  @AppStorage("reduceMotionOverride") private var reduceMotionOverride = false
  @AppStorage("debugLogging") private var debugLogging = false
  @AppStorage("previewMode") private var previewMode = false
  @AppStorage("settingsProfiles") private var settingsProfilesData = "{}"
  @State private var profileName = L("Default")
  @AppStorage("batteryLowThreshold") private var lowBatteryThreshold = 20
  @AppStorage("batteryGreenThreshold") private var greenBatteryThreshold = 80
  @AppStorage("batteryDisplayDuration") private var batteryDisplayDuration = 1.5
  @AppStorage("batteryShowCharging") private var batteryShowCharging = true
  @AppStorage("batteryShowUnplugged") private var batteryShowUnplugged = true
  @AppStorage("batteryShowLow") private var batteryShowLow = true
  @AppStorage("batteryShowFull") private var batteryShowFull = true
  @AppStorage("batteryShowThreshold") private var batteryShowThreshold = true
  @AppStorage("volumeDisplayDuration") private var volumeDisplayDuration = 1.6
  @AppStorage("brightnessDisplayDuration") private var brightnessDisplayDuration = 1.6

  var body: some View {
    SettingsPageContainer(
      icon: section.icon,
      title: section == .about ? "About Velnorr" : section.title,
      subtitle: subtitle
    ) {
      switch section {
      case .appearance:
        Section(AppLanguage.selected.localized("Animation")) {
          Toggle(AppLanguage.selected.localized("Use animations"), isOn: $animations)
        }
        Section(AppLanguage.selected.localized("Content")) {
          Toggle(AppLanguage.selected.localized("Show album artwork"), isOn: $artwork)
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(L("Collapsed artwork size"))
              Spacer()
              Text("\(Int(artworkSize)) pt")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Slider(value: $artworkSize, in: 14...24, step: 1)
              .disabled(!artwork)
          }
          radiusSlider(title: "Artwork corner radius", value: $artworkRadius)
            .disabled(!artwork)
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(L("Velnorr opacity"))
              Spacer()
              Text("\(Int(opacity * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Slider(value: $opacity, in: 0.65...1, step: 0.01)
          }
          Picker(L("Velnorr theme"), selection: $appearanceTheme) {
            Text(L("Black")).tag("black")
            Text(L("Midnight")).tag("midnight")
            Text(L("Graphite")).tag("graphite")
          }
        }
      case .media:
        Section(AppLanguage.selected.localized("Now Playing")) {
          Toggle(AppLanguage.selected.localized("Show waveform"), isOn: $waveform)
          Toggle(AppLanguage.selected.localized("Scroll long text"), isOn: $marquee)
          Toggle(AppLanguage.selected.localized("Show progress bar"), isOn: $progressBar)
          Toggle(AppLanguage.selected.localized("Show song title"), isOn: $showMediaTitle)
          Toggle(AppLanguage.selected.localized("Show artist name"), isOn: $showMediaArtist)
          Toggle(L("Show source application icon"), isOn: $showMediaSourceIcon)
          Toggle(L("Show previous and next buttons"), isOn: $trackNavigation)
          Toggle(L("Show shuffle button"), isOn: $shuffleButton)
          Toggle(L("Show audio output button"), isOn: $audioOutputButton)
          Toggle(L("Show play/pause button"), isOn: $playbackButton)
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(L("Waveform speed"))
              Spacer()
              Text(String(format: "%.1fx", waveformSpeed))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Slider(value: $waveformSpeed, in: 0.25...2, step: 0.05)
          }
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(L("Marquee speed"))
              Spacer()
              Text("\(Int(marqueeSpeed)) pt/s")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Slider(value: $marqueeSpeed, in: 10...60, step: 1)
              .disabled(!marquee)
          }
        }
      case .volume:
        Section(L("Volume HUD")) {
          Toggle(L("Show volume HUD"), isOn: $volumeHUD)
          durationSlider(title: "Notification duration", value: $volumeDisplayDuration)
          sizeSlider(title: "Bar width", value: $volumeBarWidth)
          sizeSlider(title: "Icon size", value: $volumeIconSize)
          Picker(L("Bar color"), selection: $volumeBarColor) {
            Text(L("White")).tag("white")
            Text(L("Accent")).tag("accent")
            Text(L("Green")).tag("green")
          }
          heightSlider(title: "Bar height", value: $volumeBarHeight)
        }
      case .brightness:
        Section(L("Brightness HUD")) {
          Toggle(L("Show brightness HUD"), isOn: $brightnessHUD)
          durationSlider(title: "Notification duration", value: $brightnessDisplayDuration)
          sizeSlider(title: "Bar width", value: $brightnessBarWidth)
          sizeSlider(title: "Icon size", value: $brightnessIconSize)
          Picker(L("Bar color"), selection: $brightnessBarColor) {
            Text(L("White")).tag("white")
            Text(L("Accent")).tag("accent")
            Text(L("Green")).tag("green")
          }
          heightSlider(title: "Bar height", value: $brightnessBarHeight)
        }
      case .battery:
        Section(L("Battery Events")) {
          Toggle(L("Show battery notifications"), isOn: $batteryHUD)
          Toggle(L("Charging"), isOn: $batteryShowCharging).disabled(!batteryHUD)
          Toggle(L("Unplugged"), isOn: $batteryShowUnplugged).disabled(!batteryHUD)
          Toggle(L("Low battery"), isOn: $batteryShowLow).disabled(!batteryHUD)
          Toggle(L("Full charge"), isOn: $batteryShowFull).disabled(!batteryHUD)
          Toggle(L("Threshold changes"), isOn: $batteryShowThreshold).disabled(!batteryHUD)
          sizeSlider(title: "Battery icon width", value: $batteryIconWidth)
            .disabled(!batteryHUD)
          Stepper(value: $lowBatteryThreshold, in: 5...50, step: 5) {
            HStack {
              Text(L("Low battery threshold"))
              Spacer()
              Text("\(lowBatteryThreshold)%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
          }
          Stepper(value: $greenBatteryThreshold, in: 60...95, step: 5) {
            HStack {
              Text(L("Green battery threshold"))
              Spacer()
              Text("\(greenBatteryThreshold)%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
          }
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(L("Notification duration"))
              Spacer()
              Text(String(format: "%.1f s", batteryDisplayDuration))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Slider(value: $batteryDisplayDuration, in: 0.5...10, step: 0.5)
          }
        }
      case .devices:
        Section(L("Connected Devices")) {
          Toggle(L("Show device notifications"), isOn: $deviceHUD)
          Toggle(L("AirPods"), isOn: $airPods).disabled(!deviceHUD)
          Toggle(L("Apple Watch"), isOn: $appleWatch).disabled(!deviceHUD)
          Toggle(L("Keyboards"), isOn: $keyboard).disabled(!deviceHUD)
          Toggle(L("Mice and trackpads"), isOn: $mouse).disabled(!deviceHUD)
          Toggle(L("Speakers"), isOn: $speaker).disabled(!deviceHUD)
          durationSlider(title: "Notification duration", value: $deviceDisplayDuration)
            .disabled(!deviceHUD)
        }
      case .notifications:
        Section(L("Notifications")) {
          Toggle(L("Show notifications in Velnorr"), isOn: $notificationHUD)
        }
        Section(L("Caps Lock HUD")) {
          Toggle(L("Show Caps Lock HUD"), isOn: $capsLockHUD)
          durationSlider(title: "Notification duration", value: $capsLockDisplayDuration)
            .disabled(!capsLockHUD)
          sizeSlider(title: "Icon size", value: $capsLockHUDSize, range: 30...64)
            .disabled(!capsLockHUD)
          Text(L("Velnorr consumes the Caps Lock event to suppress the macOS overlay. If Logi Options+ still shows its own overlay, disable Caps Lock notifications in Logi Options+ settings."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      case .accessibility:
        Section(AppLanguage.selected.localized("Motion")) {
          Toggle(AppLanguage.selected.localized("Reduce motion"), isOn: $reduceMotionOverride)
          Text(AppLanguage.selected.localized("When enabled, transitions use shorter, simpler animations."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      case .advanced:
        Section(L("Diagnostics")) {
          Toggle(L("Debug logging"), isOn: $debugLogging)
          Button(L("Copy settings as JSON")) {
            SettingsResetter.copyJSONToClipboard()
          }
          Button(L("Export settings to JSON…")) {
            SettingsResetter.exportJSONToFile()
          }
          Button(L("Import settings from JSON…")) {
            SettingsResetter.importJSONFromFile()
          }
        }
        Section(L("Profiles")) {
          TextField(L("Profile name"), text: $profileName)
          HStack {
            Button(L("Save current profile")) {
              saveProfile()
            }
            Button(L("Load profile")) {
              loadProfile()
            }
            Button(L("Delete profile"), role: .destructive) {
              deleteProfile()
            }
            Menu(L("Saved profiles")) {
              if profileNames.isEmpty {
                Text(L("No saved profiles"))
              } else {
                ForEach(profileNames, id: \.self) { name in
                  Button(name) { profileName = name }
                }
              }
            }
          }
          Text(L("Profiles store Velnorr preferences only."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      case .preview:
        Section(L("Preview")) {
          Toggle(L("Enable preview mode"), isOn: $previewMode)
          Button(L("Preview low battery HUD")) { postBatteryPreview("low") }
          Button(L("Preview charging HUD")) { postBatteryPreview("charging") }
          Button(L("Preview unplugged HUD")) { postBatteryPreview("unplugged") }
          Button(L("Preview full charge HUD")) { postBatteryPreview("full") }
          Button(L("Preview threshold HUD")) { postBatteryPreview("threshold") }
          Button(L("Preview volume HUD")) {
            NotificationCenter.default.post(name: .velnorrPreviewVolume, object: nil)
          }
          Button(L("Preview brightness HUD")) {
            NotificationCenter.default.post(name: .velnorrPreviewBrightness, object: nil)
          }
          Button(L("Preview Caps Lock HUD")) {
            NotificationCenter.default.post(name: .velnorrPreviewCapsLock, object: nil)
          }
          Button(L("Preview AirPods")) { postDevicePreview("airPods") }
          Button(L("Preview Apple Watch")) { postDevicePreview("appleWatch") }
          Button(L("Preview keyboard")) { postDevicePreview("keyboard") }
          Button(L("Preview mouse")) { postDevicePreview("mouse") }
          Button(L("Preview speaker")) { postDevicePreview("speaker") }
          Button(L("Preview music HUD")) {
            NotificationCenter.default.post(name: .velnorrPreviewMusic, object: nil)
          }
          Text(L("Preview controls will appear here for testing HUD states without triggering real events."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      case .about:
        Section {
          AboutLogoView()
          LabeledContent(L("Version"), value: "1.0.0")
          LabeledContent(L("Build"), value: L("Release"))
          LabeledContent(L("Developer"), value: "Berkay Huz")
          LabeledContent(L("Studio"), value: "Huzstudio")
          Link("huzstudio.com/velnorr", destination: URL(string: "http://huzstudio.com/velnorr")!)
          Text(L("Velnorr is a lightweight Dynamic Velnorr experience for macOS, designed and developed by Berkay Huz at Huzstudio."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      default:
        EmptyView()
      }
    }
  }

  private var subtitle: String {
    switch section {
    case .appearance: "Customize Velnorr's visual language and motion."
    case .media: "Choose what appears in the Now Playing experience."
    case .volume: "Control the Sound HUD and its visibility."
    case .brightness: "Control the Brightness HUD and its visibility."
    case .battery: "Choose which battery events appear in Velnorr."
    case .devices: "Manage Bluetooth device connection notifications."
    case .notifications: "Control application notifications shown by Velnorr."
    case .accessibility: "Adjust motion and accessibility behavior."
    case .advanced: "Diagnostics and performance options."
    case .preview: "Test Velnorr states without changing system hardware."
    case .about: "Information about Velnorr."
    default: "Configure Velnorr."
    }
  }

  private func postBatteryPreview(_ mode: String) {
    NotificationCenter.default.post(
      name: .velnorrPreviewBattery,
      object: nil,
      userInfo: ["mode": mode]
    )
  }

  private func postDevicePreview(_ kind: String) {
    NotificationCenter.default.post(
      name: .velnorrPreviewDevice,
      object: nil,
      userInfo: ["kind": kind]
    )
  }

  private func saveProfile() {
    let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
      let data = try? JSONSerialization.data(withJSONObject: UserDefaults.standard.dictionaryRepresentation().filter { SettingsResetter.managedKeys.contains($0.key) }),
      let json = String(data: data, encoding: .utf8),
      var profiles = try? JSONSerialization.jsonObject(with: Data(settingsProfilesData.utf8)) as? [String: String]
    else { return }
    profiles[name] = json
    if let encoded = try? JSONSerialization.data(withJSONObject: profiles),
      let value = String(data: encoded, encoding: .utf8) {
      settingsProfilesData = value
    }
  }

  private func loadProfile() {
    let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
      let profiles = try? JSONSerialization.jsonObject(with: Data(settingsProfilesData.utf8)) as? [String: String],
      let json = profiles[name],
      let data = json.data(using: .utf8),
      let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return }
    for (key, value) in values where SettingsResetter.managedKeys.contains(key) {
      UserDefaults.standard.set(value, forKey: key)
    }
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
  }

  private var profileNames: [String] {
    guard let data = settingsProfilesData.data(using: .utf8),
      let profiles = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return [] }
    return profiles.keys.sorted()
  }

  private func deleteProfile() {
    let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
      var profiles = try? JSONSerialization.jsonObject(with: Data(settingsProfilesData.utf8)) as? [String: String],
      profiles.removeValue(forKey: name) != nil,
      let encoded = try? JSONSerialization.data(withJSONObject: profiles),
      let value = String(data: encoded, encoding: .utf8)
    else { return }
    settingsProfilesData = value
  }

  private func durationSlider(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(AppLanguage.selected.localized(title))
        Spacer()
        Text(String(format: "%.1f s", value.wrappedValue))
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(value: value, in: 0.5...10, step: 0.5)
    }
  }

  private func sizeSlider(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double> = 32...90
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(AppLanguage.selected.localized(title))
        Spacer()
        Text("\(Int(value.wrappedValue)) pt")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(value: value, in: range, step: 1)
    }
  }

  private func radiusSlider(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(AppLanguage.selected.localized(title))
        Spacer()
        Text("\(Int(value.wrappedValue)) pt")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(value: value, in: 0...12, step: 1)
    }
  }

  private func heightSlider(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(AppLanguage.selected.localized(title))
        Spacer()
        Text("\(Int(value.wrappedValue)) pt")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(value: value, in: 2...10, step: 1)
    }
  }
}

private struct SettingsPageContainer<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: () -> Content
  @AppStorage(AppSettings.language) private var language = AppLanguage.system.rawValue

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: language) ?? .system
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 8) {
          Text(selectedLanguage.localized(title)).font(.system(size: 28, weight: .bold))
          Text(selectedLanguage.localized(subtitle))
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 4)

        Form { content() }
          .formStyle(.grouped)
          .scrollContentBackground(.hidden)
          // Grouped forms add their own horizontal inset. The settings
          // content should line up with the detail column instead.
          .padding(.horizontal, -20)
          .padding(.top, -20)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
    .scrollContentBackground(.hidden)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

private struct AboutLogoView: View {
  var body: some View {
    HStack(spacing: 20) {
      if let image = ResourceImages.velnorrLogo {
        Button {
          NSWorkspace.shared.open(URL(string: "http://huzstudio.com/velnorr")!)
        } label: {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(AboutLogoButtonStyle())
      }
      if let image = ResourceImages.huzstudioLogo {
        Button {
          NSWorkspace.shared.open(URL(string: "http://huzstudio.com")!)
        } label: {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(AboutLogoButtonStyle())
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.vertical, 8)
  }
}

private struct AboutLogoButtonStyle: ButtonStyle {
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed ? 0.9 : (isHovered ? 0.95 : 1))
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
      .animation(.easeOut(duration: 0.16), value: isHovered)
      .onHover { isHovered = $0 }
  }
}
