# Velnorr macOS package

From the project root, run:

```sh
./Packaging/build_dmg.sh
```

The generated file is `dist/Velnorr-1.0.0.dmg`. Open it, drag
`Velnorr.app` to `Applications`, then launch it from Applications.

This local package is signed with the first available Apple Development or
Developer ID Application identity. For distribution to other Macs, replace
the local identity with a Developer ID Application certificate and notarize
the app/DMG with Apple before publishing it.

The package build compiles `Packaging/Velnorr.icon` into the app’s `Assets.car`
and `Velnorr.icns`, including the light and dark appearance variants.
