# Velnorr macOS package

From the project root, run:

```sh
./Packaging/build_dmg.sh
```

For local development and Mirror camera testing, build and launch the app
bundle directly:

```sh
./Packaging/build_dmg.sh --run
```

This is important for camera permissions. macOS associates camera access with
an application bundle; a raw `swift run` executable can cause the permission
to appear under Terminal instead of Velnorr. The launched app is
`dist/Velnorr.app` and contains the privacy usage description and bundle
identifier used by System Settings, plus the camera entitlement required by
macOS hardened runtime.

The generated file is `dist/Velnorr-1.0.1.dmg`. Open it, drag
`Velnorr.app` to `Applications`, then launch it from Applications.

This command creates a local validation package. It prefers a Developer ID
Application identity when one is installed, then falls back to Apple
Development or ad-hoc signing.

For a distribution-signing package, use a Developer ID Application identity
explicitly:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./Packaging/build_dmg.sh --distribution
```

The `--distribution` mode fails closed if a Developer ID identity is not
available. Notarize and staple the resulting DMG before publishing it:

```sh
xcrun notarytool submit dist/Velnorr-1.0.1.dmg \
  --keychain-profile "YOUR_NOTARY_PROFILE" --wait
xcrun stapler staple dist/Velnorr-1.0.1.dmg
xcrun stapler validate dist/Velnorr-1.0.1.dmg
spctl --assess --type execute --verbose=4 dist/Velnorr.app
```

The package build compiles `Packaging/Velnorr.icon` into the app’s `Assets.car`
and `Velnorr.icns`, including the light and dark appearance variants.
