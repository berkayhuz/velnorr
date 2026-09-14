@testable import Velnorr
import XCTest

final class AppLanguageTests: XCTestCase {
  func testTurkishTranslationLoadsFromPackageBundle() {
    XCTAssertEqual(AppLanguage.turkish.localized("General"), "Genel")
  }

  func testMissingTranslationFallsBackToEnglishKey() {
    XCTAssertEqual(AppLanguage.turkish.localized("Missing localization key"), "Missing localization key")
  }

  func testContextMenuItemsUseSelectedLocalizationTable() {
    XCTAssertEqual(AppLanguage.turkish.localized("Settings"), "Ayarlar")
    XCTAssertEqual(AppLanguage.german.localized("Quit Velnorr"), "Velnorr beenden")
  }

  func testArabicAccessibilityTranslationLoads() {
    XCTAssertEqual(AppLanguage.arabic.localized("Reduce motion"), "تقليل الحركة")
  }

  func testJapanesePageDescriptionsDoNotFallBackToEnglish() {
    let keys = [
      "Manage Velnorr's behavior and appearance.",
      "Choose what appears in the Now Playing experience.",
      "Control the Sound HUD and its visibility.",
      "Control the Brightness HUD and its visibility.",
      "Choose which battery events appear in Velnorr.",
      "Manage Bluetooth device connection notifications.",
      "Diagnostics and performance options.",
    ]
    for key in keys {
      XCTAssertNotEqual(AppLanguage.japanese.localized(key), key)
    }
  }

  func testEveryLanguageContainsTheCompleteEnglishCatalog() throws {
    let englishKeys = try localizationKeys(for: "en")
    XCTAssertFalse(englishKeys.isEmpty)

    for language in AppLanguage.allCases where language != .system && language != .english {
      XCTAssertEqual(
        try localizationKeys(for: language.rawValue),
        englishKeys,
        "Incomplete localization catalog: \(language.rawValue)"
      )
    }
  }

  func testOnlyArabicUsesRightToLeftLayout() {
    XCTAssertTrue(AppLanguage.arabic.isRightToLeft)
    for language in AppLanguage.allCases where language != .arabic {
      XCTAssertFalse(language.isRightToLeft)
    }
  }

  private func localizationKeys(for locale: String) throws -> Set<String> {
    let path = try XCTUnwrap(Bundle.module.path(forResource: locale, ofType: "lproj"))
    let url = URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings")
    let data = try Data(contentsOf: url)
    let values = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
    )
    return Set(values.keys)
  }
}
