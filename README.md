<div align="center">
  <img src="Sources/Velnorr/Resources/velnorr-logo-curved.svg" width="180" alt="Velnorr logo" style="border-radius: 24px;">
  
  <h1>Velnorr - DynamicIsland for macOS</h1>

  <p>A polished, responsive media and system status experience for the macOS menu bar.</p>
  
  <p>
    <img src="https://img.shields.io/badge/platform-macOS%2013%2B-111827?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+">
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0">
    <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-2563EB?style=flat-square" alt="SwiftUI and AppKit">
    <img src="https://img.shields.io/badge/status-in%20development-F59E0B?style=flat-square" alt="In development">
  </p>
</div>

<hr>

## Overview

Velnorr brings a compact, animated status surface to macOS. It adapts to MacBooks with a physical notch and to notchless displays, while keeping the desktop underneath fully usable through shape-aware mouse passthrough.

The interface stays quiet when nothing needs attention and expands naturally when you hover, interact with media, change volume or brightness, connect a device, or receive a battery event.

The expanded music panel closes with an animation after three seconds of pointer-free inactivity.

## Highlights

<table>
  <tr>
    <td width="50%">
      <strong>Now Playing</strong><br>
      Spotify and Apple Music artwork, track metadata, progress, seek, playback and navigation controls.
    </td>
    <td width="50%">
      <strong>Adaptive displays</strong><br>
      Physical-notch geometry plus configurable pill and simulated-notch modes for external displays.
    </td>
  </tr>
  <tr>
    <td>
      <strong>System HUDs</strong><br>
      Animated volume, brightness and Caps Lock feedback with configurable visibility and durations.
    </td>
    <td>
      <strong>Battery events</strong><br>
      Charging, unplugged, low battery, full charge and threshold-change notifications with level-aware color.
    </td>
  </tr>
  <tr>
    <td>
      <strong>Connected devices</strong><br>
      AirPods, Apple Watch, keyboards, mice/trackpads and speakers with Bluetooth battery details.
    </td>
    <td>
      <strong>Designed to be personal</strong><br>
      A macOS-style Settings window, profiles, preview mode, reduced motion and extensive appearance controls.
    </td>
  </tr>
</table>

## Requirements

- macOS 13 Ventura or later
- Swift 6 toolchain (included with current Xcode or Swift toolchain installation)
- Spotify and/or Apple Music for media controls

Velnorr uses Apple Events to read and control supported media players. macOS may ask for Automation permission the first time a player is accessed.

## Install

### DMG (recommended)

Build the distributable app and disk image from the project root:

```sh
./Packaging/build_dmg.sh
```

Open `dist/Velnorr-1.0.0.dmg`, then drag `Velnorr.app` into `Applications`.

For distribution to other Macs, sign the app with a Developer ID certificate and notarize the app/DMG with Apple.

### Build from source

```sh
git clone <your-repository-url>
cd velnorr
swift build -c release
```

## Run

Start the development build with:

```sh
swift run
```

The app is a menu-bar utility, so it does not open a conventional main window on launch. Use the Velnorr context menu to open Settings or quit the app.

## Preview mode

Preview command-line states without changing real hardware or repeatedly connecting devices:

```sh
# Battery states
swift run Velnorr --preview-battery
swift run Velnorr --preview-unplugged
swift run Velnorr --preview-low-battery
swift run Velnorr --preview-full-charge
swift run Velnorr --preview-battery-threshold

# Connected-device states
swift run Velnorr --preview-airpods
swift run Velnorr --preview-keyboard
swift run Velnorr --preview-mouse
swift run Velnorr --preview-speaker
```

Preview mode is also available from Settings → Preview for volume, brightness, Caps Lock and music states.

## Settings

Right-click Velnorr and choose **Settings** to customize:

- General behavior, launch at login and fullscreen visibility
- External display mode and position
- Interface language and system-default language detection
- Animation, artwork size/radius, opacity and theme
- Now Playing content, waveform and marquee behavior
- Volume, brightness and Caps Lock HUD visibility, styling, timing and size
- Battery event types, thresholds, icon size and notification duration
- Connected-device notification categories and timing
- Reduced motion, diagnostics, JSON import/export and saved profiles

The interface is localized for English, Spanish, German, French, Brazilian Portuguese, Italian, Turkish, Japanese, Korean, Simplified Chinese, Traditional Chinese and Arabic. Arabic automatically uses right-to-left layout.

## Architecture

The project is organized as a Swift Package with feature-oriented layers:

```text
Sources/Velnorr/
├── App/          Application lifecycle, settings and notifications
├── Domain/       Presentation state and media models
├── Layout/       Notch, display and adaptive geometry
├── Media/        Media players, artwork, battery, audio and Bluetooth
├── Window/       AppKit window and shape-aware hit testing
├── DesignSystem/ Shared shapes, transitions and animation values
├── Views/Velnorr/ HUD shell and system status surfaces
├── Views/NowPlaying/
└── Views/Settings/
```

The media layer serializes AppleScript work, polling is sequential, and the window shares the same CGPath geometry as the SwiftUI shape to keep rendering and hit testing aligned.

## Development

Run the complete test suite before submitting changes:

```sh
swift test
```

The tests cover layout calculations, source arbitration, media parsing, interaction transitions, mouse policy, artwork transitions, localization catalog completeness and Arabic layout direction.

When adding a user-visible string, add the key to every `Resources/*.lproj/Localizable.strings` file. The localization test intentionally fails when a language catalog is incomplete.

## Packaging notes

`Packaging/build_dmg.sh` creates a self-contained `Velnorr.app`, copies the SwiftPM resource bundle and localization directories into the app bundle, signs it with an available local identity (or ad-hoc signing), and creates `dist/Velnorr-1.0.0.dmg`.

Local development signing is not a substitute for release signing and notarization. Apple Events behavior, launch-at-login registration and permissions should be re-tested with the final signed build.

## Project

Velnorr is designed and developed by **Berkay Huz** at **Huzstudio**.

- [Velnorr](http://huzstudio.com/velnorr)
- [Huzstudio](http://huzstudio.com)
