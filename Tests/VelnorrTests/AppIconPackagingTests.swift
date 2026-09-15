import Foundation
import XCTest

final class AppIconPackagingTests: XCTestCase {
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
