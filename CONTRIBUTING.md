# Contributing to Velnorr

Thank you for taking the time to contribute to Velnorr. Bug reports, design feedback, documentation improvements and focused code changes are all welcome.

Velnorr is a SwiftUI and AppKit macOS utility. Contributions should preserve the lightweight, unobtrusive nature of the app while keeping the code easy to extend.

## Before you start

For substantial changes, open an issue first so the scope and implementation direction can be discussed. Small fixes, documentation updates and test improvements can be opened directly as a pull request.

Please avoid combining unrelated changes in one pull request. A focused change is easier to review, test and safely merge.

## Development requirements

- macOS 13 Ventura or later
- Swift 6 toolchain, provided by a current Xcode or Swift toolchain installation
- Git
- Spotify and/or Apple Music only when working on media integration

## Set up the project

```sh
git clone <your-fork-url>
cd velnorr
swift build
```

Run the app during development with:

```sh
./Packaging/build_dmg.sh --run
```

Velnorr is a menu-bar utility and does not open a conventional main window on launch. Right-click the Velnorr surface to open Settings or quit. The packaged app flow is required for Mirror camera permission tests; a raw `swift run` executable has no application bundle identity, so macOS may associate camera access with Terminal.

Right-click also exposes the optional Calendar, Shelf and Mirror utility panels. Calendar and Reminders use EventKit and can be authorized during onboarding or from Settings, Mirror uses the camera only while visible, and Shelf stores file bookmarks plus bounded link/text entries in Application Support. Shelf actions use transient Quick Look/share presenters, and vertical gestures are optional, haptic-aware and Reduce Motion-aware. Display style and notch height are applied by rebuilding the affected windows from one settings snapshot.

## Branches

Create a short-lived branch from `main`:

```sh
git switch -c feature/short-description
```

Recommended prefixes:

- `feature/` for user-facing functionality
- `fix/` for bug fixes
- `refactor/` for internal improvements
- `docs/` for documentation
- `test/` for test-only changes

Keep branch names lowercase and use hyphens or a short descriptive path.

## Make a change

1. Read the relevant code in `Domain/`, `Layout/`, `Media/`, `Window/` or `Views/` before editing.
2. Keep platform-specific code in the appropriate AppKit or media layer.
3. Add or update a focused unit test for changed behavior.
4. Run the complete test suite.
5. Review the final diff for unrelated files, generated artifacts and accidental credentials.

The project intentionally separates responsibilities:

```text
Sources/Velnorr/
├── App/          Lifecycle, settings and notifications
├── Domain/       State and media models
├── Layout/       Notch and display geometry
├── Media/        Players, artwork, battery, audio and Bluetooth
├── Window/       AppKit window and hit testing
├── DesignSystem/ Shapes, transitions and animation values
└── Views/        HUD, Now Playing and Settings UI
```

Prefer extending an existing service or resolver over adding more orchestration to a view. Keep shared geometry in the shape/path factory so SwiftUI rendering and AppKit hit testing cannot drift apart.

## Tests and verification

Run all tests from the repository root:

```sh
swift test
```

Tests cover layout, presentation state, source arbitration, AppleScript result parsing, interaction transitions, mouse policy, artwork transitions, localization catalog completeness and Arabic right-to-left layout.

When changing media behavior, also test the relevant preview state where possible. Preview commands avoid requiring real hardware events:

```sh
swift run Velnorr --preview-battery
swift run Velnorr --preview-unplugged
swift run Velnorr --preview-low-battery
swift run Velnorr --preview-full-charge
swift run Velnorr --preview-battery-threshold
swift run Velnorr --preview-airpods
swift run Velnorr --preview-keyboard
swift run Velnorr --preview-mouse
swift run Velnorr --preview-speaker
```

For a release-style smoke test, build the app and DMG:

```sh
swift build -c release
./Packaging/build_dmg.sh
```

Do not commit `.build/`, `dist/`, `.DS_Store` files, signing identities or credentials. These paths are covered by `.gitignore`.

## Localization

Velnorr supports English, Spanish, German, French, Brazilian Portuguese, Italian, Turkish, Japanese, Korean, Simplified Chinese, Traditional Chinese and Arabic.

When adding a user-visible string:

1. Use the localization helper instead of a hard-coded label.
2. Add the same key to every `Sources/Velnorr/Resources/*.lproj/Localizable.strings` file.
3. Keep language names in their native form in the language picker.
4. Check Arabic with right-to-left layout enabled.
5. Run `swift test`; the localization catalog test must remain green.

Do not use a localized value as a persistence key. Settings keys and notification identifiers must remain stable across languages.

## UI and interaction guidelines

- Preserve shape-aware mouse passthrough on compact surfaces.
- Keep expanded media controls fully interactive.
- Respect Reduce Motion for new animations and transitions.
- Avoid permanent timers or per-frame work when an event-driven update is sufficient.
- Keep optional utility services demand-driven; stop calendar loads and camera capture when their panel is inactive.
- Keep artwork and network work off the main thread where possible.
- Check both physical-notch MacBooks and notchless/external displays.
- Verify that content remains aligned when the window changes size or display mode.

## Media and permissions

Spotify and Apple Music integrations use Apple Events. Do not bypass the existing serialized AppleScript executor or introduce independent detached commands without a clear concurrency design.

Never include personal media data, artwork downloads, device identifiers, automation payloads or permission screenshots in a commit. When a provider is unavailable, the UI should fail quietly and leave the rest of Velnorr usable.

## Commit messages

Use concise, imperative commit messages:

```text
Add Arabic right-to-left settings layout
Fix compact playback hit testing
Update battery HUD preview documentation
```

Keep each commit focused. Do not include generated DMGs, local build products or unrelated formatting changes.

## Pull requests

A pull request should include:

- A clear explanation of the user-visible or architectural change
- The relevant issue number, if one exists
- Tests run and their result
- Preview states or screenshots for visual changes
- Notes about required macOS permissions or hardware
- Localization updates for every supported language when text changed

Before requesting review, confirm:

- [ ] `swift test` passes
- [ ] Release build succeeds when packaging-related code changed
- [ ] No generated or sensitive files are staged
- [ ] Physical-notch and notchless layouts were considered
- [ ] Reduce Motion and accessibility behavior were considered
- [ ] The diff contains only the intended changes

## Reporting bugs

Please include:

- macOS version and Mac model
- Velnorr version or commit
- Physical notch, notchless display or external display setup
- Steps to reproduce
- Expected and actual behavior
- Relevant console output, with personal data removed
- Whether the issue reproduces in a preview mode

## Code ownership

The repository uses `.github/CODEOWNERS` for default review ownership. Reviewers may request changes to protect media permissions, interaction behavior, localization consistency and release packaging.

Thank you for helping make Velnorr more reliable, accessible and delightful on macOS.
