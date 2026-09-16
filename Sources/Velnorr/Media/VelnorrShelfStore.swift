import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

/// A small, persistent drop shelf for files, links and text.
///
/// Files are represented by security-scoped bookmarks rather than paths. This
/// keeps the shelf useful across launches without retaining file contents in
/// memory or copying user data into the app container.
@MainActor
final class VelnorrShelfStore: ObservableObject {
  nonisolated static let minimumItemLimit = 8
  nonisolated static let itemLimit = 32
  nonisolated static let maximumTextLength = 100_000
  nonisolated static let maximumURLLength = 4_096

  @Published private(set) var items: [VelnorrShelfItem]
  @Published private(set) var isLoading = false
  @Published private(set) var lastError: VelnorrShelfStoreError?

  private let persistenceURL: URL
  private var dropTask: Task<Void, Never>?
  private static let iconCache: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 64
    return cache
  }()

  init(storageURL: URL? = nil) {
    if let storageURL {
      persistenceURL = storageURL
    } else {
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
      let directory = applicationSupport
        .appendingPathComponent("Velnorr", isDirectory: true)
        .appendingPathComponent("Shelf", isDirectory: true)
      persistenceURL = directory.appendingPathComponent("items.json")
    }
    items = Self.load(from: persistenceURL, limit: Self.configuredItemLimit())
  }

  deinit {
    dropTask?.cancel()
  }

  func start() {
    // Loading is synchronous and bounded by the small persisted item list.
    items = Self.load(from: persistenceURL, limit: Self.configuredItemLimit())
    lastError = nil
  }

  func stop() {
    dropTask?.cancel()
    dropTask = nil
    isLoading = false
  }

  func acceptDrop(_ providers: [NSItemProvider]) {
    guard !providers.isEmpty else { return }
    dropTask?.cancel()
    isLoading = true
    dropTask = Task { @MainActor [weak self] in
      var droppedItems: [VelnorrShelfItem] = []
      for provider in providers {
        guard !Task.isCancelled else { return }
        if let item = await Self.item(from: provider) {
          droppedItems.append(item)
        }
      }
      guard let self, !Task.isCancelled else { return }
      self.add(droppedItems)
      self.isLoading = false
      self.dropTask = nil
    }
  }

  func add(_ newItems: [VelnorrShelfItem]) {
    guard !newItems.isEmpty else { return }
    var merged = items
    var identities = Set(merged.map(\.identityKey))
    for item in newItems where !identities.contains(item.identityKey) {
      merged.append(item)
      identities.insert(item.identityKey)
    }
    items = Array(merged.suffix(Self.configuredItemLimit()))
    save()
  }

  func applyConfiguredLimit() {
    let limit = Self.configuredItemLimit()
    guard items.count > limit else { return }
    items = Array(items.suffix(limit))
    save()
  }

  func remove(_ item: VelnorrShelfItem) {
    items.removeAll { $0.id == item.id }
    save()
  }

  func removeAll() {
    items.removeAll()
    save()
  }

  func resolveFileURL(for item: VelnorrShelfItem) -> URL? {
    guard case .file(let bookmarkData, _) = item.kind else { return nil }
    var isStale = false
    guard let url = try? URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
    else { return nil }

    if isStale, let refreshed = try? url.bookmarkData(options: [.withSecurityScope]) {
      let replacement = VelnorrShelfItem.Kind.file(
        bookmark: refreshed,
        displayName: item.displayName
      )
      if let index = items.firstIndex(where: { $0.id == item.id }) {
        items[index] = VelnorrShelfItem(
          id: item.id,
          kind: replacement,
          createdAt: item.createdAt
        )
        save()
      }
    }
    return url
  }

  func open(_ item: VelnorrShelfItem) {
    switch item.kind {
    case .file:
      guard let url = resolveFileURL(for: item) else { return }
      let started = url.startAccessingSecurityScopedResource()
      defer {
        if started { url.stopAccessingSecurityScopedResource() }
      }
      NSWorkspace.shared.open(url)
    case .link(let url):
      NSWorkspace.shared.open(url)
    case .text(let value):
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(value, forType: .string)
    }
  }

  func icon(for item: VelnorrShelfItem) -> NSImage {
    let cacheKey = item.identityKey as NSString
    if let cached = Self.iconCache.object(forKey: cacheKey) {
      return cached
    }

    let image: NSImage
    switch item.kind {
    case .file:
      if let url = resolveFileURLWithoutMutation(for: item) {
        image = NSWorkspace.shared.icon(forFile: url.path)
      } else {
        image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
          ?? NSImage()
      }
    case .link:
      image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        ?? NSImage()
    case .text:
      image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        ?? NSImage()
    }
    Self.iconCache.setObject(image, forKey: cacheKey)
    return image
  }

  func dragProvider(for item: VelnorrShelfItem) -> NSItemProvider {
    switch item.kind {
    case .file:
      if let url = resolveFileURL(for: item) {
        return NSItemProvider(object: url as NSURL)
      }
    case .link(let url):
      return NSItemProvider(
        item: url.absoluteString.data(using: .utf8) as NSData?,
        typeIdentifier: UTType.url.identifier
      )
    case .text(let value):
      return NSItemProvider(object: value as NSString)
    }
    return NSItemProvider(object: item.displayName as NSString)
  }

  private func save() {
    do {
      let data = try JSONEncoder.velnorr.encode(items)
      try FileManager.default.createDirectory(
        at: persistenceURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: persistenceURL, options: .atomic)
      lastError = nil
    } catch {
      lastError = .persistenceFailed
    }
  }

  private func resolveFileURLWithoutMutation(for item: VelnorrShelfItem) -> URL? {
    guard case .file(let bookmarkData, _) = item.kind else { return nil }
    var isStale = false
    return try? URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  nonisolated static func configuredItemLimit(userDefaults: UserDefaults = .standard) -> Int {
    let stored = userDefaults.object(forKey: AppSettings.shelfMaximumItems) as? Int ?? itemLimit
    return min(itemLimit, max(minimumItemLimit, stored))
  }

  private static func load(from url: URL, limit: Int) -> [VelnorrShelfItem] {
    guard let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder.velnorr.decode([VelnorrShelfItem].self, from: data)
    else { return [] }
    var seen = Set<String>()
    return decoded.filter { item in
      guard seen.insert(item.identityKey).inserted else { return false }
      return true
    }.suffix(limit).map { $0 }
  }

  private static func item(from provider: NSItemProvider) async -> VelnorrShelfItem? {
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
      let data = await data(from: provider, typeIdentifier: UTType.fileURL.identifier),
      let url = URL(dataRepresentation: data, relativeTo: nil),
      let bookmark = try? url.bookmarkData(options: [.withSecurityScope])
    {
      return VelnorrShelfItem(
        kind: .file(bookmark: bookmark, displayName: url.lastPathComponent)
      )
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
      let data = await data(from: provider, typeIdentifier: UTType.url.identifier),
      let rawValue = String(data: data, encoding: .utf8),
      let url = URL(string: String(rawValue.prefix(Self.maximumURLLength)))
    {
      if url.isFileURL, let bookmark = try? url.bookmarkData(options: [.withSecurityScope]) {
        return VelnorrShelfItem(
          kind: .file(bookmark: bookmark, displayName: url.lastPathComponent)
        )
      }
      return VelnorrShelfItem(kind: .link(url: url))
    }

    let textTypes = [UTType.utf8PlainText.identifier, UTType.plainText.identifier]
    for typeIdentifier in textTypes where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
      guard let data = await data(from: provider, typeIdentifier: typeIdentifier),
        let text = String(data: data, encoding: .utf8)
      else { continue }
      return VelnorrShelfItem(kind: .text(String(text.prefix(Self.maximumTextLength))))
    }
    return nil
  }

  private static func data(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async -> Data? {
    await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }
}

private extension JSONEncoder {
  static var velnorr: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }
}

private extension JSONDecoder {
  static var velnorr: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
