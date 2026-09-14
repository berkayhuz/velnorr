// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Velnorr",
  defaultLocalization: "en",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "Velnorr", targets: ["Velnorr"])
  ],
  targets: [
    .executableTarget(
      name: "Velnorr",
      path: "Sources/Velnorr",
      resources: [
        .copy("Resources/Battery.svg"),
        .copy("Resources/velnorr-logo.svg"),
        .copy("Resources/logo-huzstudio.svg"),
        .copy("Resources/apple-music-icon.svg"),
        .copy("Resources/spotify-icon.svg"),
        .copy("Resources/tr.lproj"),
        .copy("Resources/es.lproj"),
        .copy("Resources/de.lproj"),
        .copy("Resources/fr.lproj"),
        .copy("Resources/it.lproj"),
        .copy("Resources/pt-BR.lproj"),
        .copy("Resources/ja.lproj"),
        .copy("Resources/ko.lproj"),
        .copy("Resources/zh-Hans.lproj"),
        .copy("Resources/zh-Hant.lproj"),
        .copy("Resources/ar.lproj"),
        .copy("Resources/en.lproj"),
      ]
    ),
    .testTarget(
      name: "VelnorrTests",
      dependencies: ["Velnorr"],
      path: "Tests/VelnorrTests"
    ),
  ]
)
