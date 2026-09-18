import Foundation
import XCTest

final class AppIconPackagingTests: XCTestCase {
    func testInfoPlistDeclaresPrivacyUsageDescriptions() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoURL = projectURL.appendingPathComponent("Packaging/Info.plist")
        let infoData = try Data(contentsOf: infoURL)
        let info = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
        )

        XCTAssertEqual(info["CFBundleIdentifier"] as? String, "com.berkayhuz.velnorr")
        XCTAssertEqual(info["CFBundlePackageType"] as? String, "APPL")
        XCTAssertEqual(info["CFBundleExecutable"] as? String, "Velnorr")
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "1.0.2")
        XCTAssertEqual(info["CFBundleVersion"] as? String, "3")
        XCTAssertFalse((info["NSCameraUsageDescription"] as? String ?? "").isEmpty)
        XCTAssertFalse((info["NSCalendarsFullAccessUsageDescription"] as? String ?? "").isEmpty)
        XCTAssertFalse((info["NSRemindersFullAccessUsageDescription"] as? String ?? "").isEmpty)
    }

    func testDevelopmentLauncherSupportsApplicationBundleMode() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let scriptURL = projectURL.appendingPathComponent(
            "Packaging/build_dmg.sh"
        )

        let script = try String(
            contentsOf: scriptURL,
            encoding: .utf8
        )

        XCTAssertTrue(
            script.contains("--run")
        )

        XCTAssertTrue(
            script.contains("open \"$APP_PATH\"")
        )

        XCTAssertTrue(
            script.contains("Velnorr-$APP_VERSION.dmg")
        )

        // Do not depend on shell formatting or line breaks.
        XCTAssertTrue(
            script.contains(
                "\"$PROJECT_DIR/Packaging/Info.plist\""
            )
        )

        XCTAssertTrue(
            script.contains(
                "\"$APP_PATH/Contents/Info.plist\""
            )
        )
    }

    func testEntitlementsDeclareCameraAccessForHardenedRuntime() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementsURL = projectURL.appendingPathComponent("Packaging/Entitlements.plist")
        let entitlementsData = try Data(contentsOf: entitlementsURL)
        let entitlements = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: entitlementsData, format: nil) as? [String: Any]
        )

        XCTAssertEqual(entitlements["com.apple.security.device.camera"] as? Bool, true)
    }

    func testIconComposerManifestDeclaresLightAndDarkLayers() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = projectURL.appendingPathComponent("Packaging/Velnorr.icon")
        let manifestURL = iconURL.appendingPathComponent("icon.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        let groups = try XCTUnwrap(manifest["groups"] as? [[String: Any]])
        let layers = try XCTUnwrap(groups.first?["layers"] as? [[String: Any]])
        XCTAssertEqual(layers.count, 2)

        let lightLayer = try XCTUnwrap(layers.first { $0["name"] as? String == "Light" })
        let darkLayer = try XCTUnwrap(layers.first { $0["name"] as? String == "Dark" })

        XCTAssertEqual(lightLayer["image-name"] as? String, "light.png")
        XCTAssertEqual(darkLayer["image-name"] as? String, "dark-icon@1024w.png")

        let lightVisibility = try XCTUnwrap(lightLayer["hidden-specializations"] as? [[String: Any]])
        let darkVisibility = try XCTUnwrap(darkLayer["hidden-specializations"] as? [[String: Any]])
        XCTAssertEqual(lightVisibility.first?["value"] as? Bool, false)
        XCTAssertEqual(lightVisibility.last?["appearance"] as? String, "dark")
        XCTAssertEqual(lightVisibility.last?["value"] as? Bool, true)
        XCTAssertEqual(darkVisibility.first?["value"] as? Bool, true)
        XCTAssertEqual(darkVisibility.last?["appearance"] as? String, "dark")
        XCTAssertEqual(darkVisibility.last?["value"] as? Bool, false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.appendingPathComponent("Assets/light.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.appendingPathComponent("Assets/dark-icon@1024w.png").path))
    }
}
