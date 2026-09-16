import Foundation

enum VelnorrUtilityPanel: String, CaseIterable, Equatable, Sendable {
  case media
  case calendar
  case shelf
  case mirror

  var titleKey: String {
    switch self {
    case .media: "Now Playing"
    case .calendar: "Calendar"
    case .shelf: "Shelf"
    case .mirror: "Mirror"
    }
  }

  var symbolName: String {
    switch self {
    case .media: "music.note"
    case .calendar: "calendar"
    case .shelf: "tray.full"
    case .mirror: "video.fill"
    }
  }
}

struct VelnorrCalendarItem: Identifiable, Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case event
    case reminder(completed: Bool)
  }

  let id: String
  let title: String
  let startDate: Date
  let endDate: Date
  let isAllDay: Bool
  let location: String?
  let url: URL?
  let kind: Kind

  var isReminder: Bool {
    if case .reminder = kind { return true }
    return false
  }

  var isCompleted: Bool {
    if case .reminder(let completed) = kind { return completed }
    return false
  }
}

struct VelnorrCalendarFilter: Equatable, Sendable {
  var showEvents = true
  var showReminders = true
  var showCompletedReminders = true

  func includes(_ item: VelnorrCalendarItem) -> Bool {
    if item.isReminder {
      return showReminders && (showCompletedReminders || !item.isCompleted)
    }
    return showEvents
  }
}

enum VelnorrShelfStoreError: Equatable, Sendable {
  case persistenceFailed
}

struct VelnorrShelfItem: Codable, Equatable, Identifiable, Sendable {
  enum Kind: Codable, Equatable, Sendable {
    case file(bookmark: Data, displayName: String)
    case link(url: URL)
    case text(String)

    private enum CodingKeys: String, CodingKey {
      case type
      case bookmark
      case displayName
      case url
      case value
    }

    private enum KindType: String, Codable {
      case file
      case link
      case text
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      switch try container.decode(KindType.self, forKey: .type) {
      case .file:
        self = .file(
          bookmark: try container.decode(Data.self, forKey: .bookmark),
          displayName: try container.decode(String.self, forKey: .displayName)
        )
      case .link:
        self = .link(url: try container.decode(URL.self, forKey: .url))
      case .text:
        self = .text(try container.decode(String.self, forKey: .value))
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .file(let bookmark, let displayName):
        try container.encode(KindType.file, forKey: .type)
        try container.encode(bookmark, forKey: .bookmark)
        try container.encode(displayName, forKey: .displayName)
      case .link(let url):
        try container.encode(KindType.link, forKey: .type)
        try container.encode(url, forKey: .url)
      case .text(let value):
        try container.encode(KindType.text, forKey: .type)
        try container.encode(value, forKey: .value)
      }
    }
  }

  let id: UUID
  let kind: Kind
  let createdAt: Date

  init(id: UUID = UUID(), kind: Kind, createdAt: Date = Date()) {
    self.id = id
    self.kind = kind
    self.createdAt = createdAt
  }

  var displayName: String {
    switch kind {
    case .file(_, let displayName): return displayName
    case .link(let url): return url.host ?? url.absoluteString
    case .text(let value):
      let firstLine = value.split(whereSeparator: \.isNewline).first.map(String.init) ?? value
      return firstLine.isEmpty ? AppLanguage.selected.localized("Text") : firstLine
    }
  }

  var identityKey: String {
    switch kind {
    case .file(let bookmark, _): return "file:\(bookmark.base64EncodedString())"
    case .link(let url): return "link:\(url.absoluteString)"
    case .text(let value): return "text:\(value)"
    }
  }
}
