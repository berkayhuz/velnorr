import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case english = "en"
  case spanish = "es"
  case german = "de"
  case french = "fr"
  case portugueseBrazil = "pt-BR"
  case italian = "it"
  case turkish = "tr"
  case japanese = "ja"
  case korean = "ko"
  case chineseSimplified = "zh-Hans"
  case chineseTraditional = "zh-Hant"
  case arabic = "ar"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .system: "System Default / Device Language"
    case .english: "English"
    case .spanish: "Español"
    case .german: "Deutsch"
    case .french: "Français"
    case .portugueseBrazil: "Português (Brasil)"
    case .italian: "Italiano"
    case .turkish: "Türkçe"
    case .japanese: "日本語"
    case .korean: "한국어"
    case .chineseSimplified: "简体中文"
    case .chineseTraditional: "繁體中文"
    case .arabic: "العربية"
    }
  }

  var localeIdentifier: String {
    guard self == .system else { return rawValue }
    let preferred = Locale.preferredLanguages.first ?? "en"
    let supported = Self.allCases.dropFirst().map(\.rawValue)
    return supported.first { preferred.hasPrefix($0) } ?? "en"
  }

  var isRightToLeft: Bool {
    self == .arabic
  }

  func localized(_ key: String) -> String {
    guard let path = Bundle.module.path(forResource: localeIdentifier, ofType: "lproj"),
      let languageBundle = Bundle(path: path)
    else { return key }
    return languageBundle.localizedString(forKey: key, value: key, table: nil)
  }

  static var selected: AppLanguage {
    let rawValue = UserDefaults.standard.string(forKey: AppSettings.language) ?? system.rawValue
    return AppLanguage(rawValue: rawValue) ?? .system
  }
}
