import AppKit
import Foundation
import QuickLookUI
import UniformTypeIdentifiers

/// Owns transient Shelf actions that need AppKit delegates or security scope.
/// The Shelf store remains responsible for persistence and bookmark resolution.
@MainActor
final class VelnorrShelfActionService: ObservableObject {
  @Published private(set) var isSharing = false

  private var previewPanel: QLPreviewPanel?
  private var previewDataSource: VelnorrQuickLookDataSource?
  private var previewURLs: [URL] = []
  private var previewAccessedURLs: [URL] = []
  private var sharingPicker: NSSharingServicePicker?
  private var sharingDelegate: VelnorrSharingDelegate?
  private var sharingURLs: [URL] = []
  private var sharingTimeoutTask: Task<Void, Never>?

  deinit {
    sharingTimeoutTask?.cancel()
    for url in previewAccessedURLs {
      url.stopAccessingSecurityScopedResource()
    }
    for url in sharingURLs {
      url.stopAccessingSecurityScopedResource()
    }
  }

  func stop() {
    stopPreview()
    stopSharing()
  }

  func preview(_ item: VelnorrShelfItem, using store: VelnorrShelfStore) {
    guard let url = previewURL(for: item, using: store) else { return }
    stopPreview()
    guard let panel = QLPreviewPanel.shared() else { return }

    // Unsandboxed builds may receive regular file URLs that do not expose a
    // security scope. Quick Look can still preview those URLs; only balance
    // calls for scopes that were actually opened.
    if url.isFileURL, url.startAccessingSecurityScopedResource() {
      previewAccessedURLs = [url]
    }
    previewURLs = [url]

    let dataSource = VelnorrQuickLookDataSource(urls: previewURLs) { [weak self] in
      Task { @MainActor [weak self] in
        self?.stopPreview()
      }
    }
    previewDataSource = dataSource
    previewPanel = panel
    panel.dataSource = dataSource
    panel.delegate = dataSource
    panel.reloadData()
    panel.makeKeyAndOrderFront(nil)
  }

  func share(
    _ item: VelnorrShelfItem,
    using store: VelnorrShelfStore,
    from sourceView: NSView?
  ) {
    guard !isSharing else { return }
    guard let shareItem = shareItem(for: item, using: store) else { return }
    share(items: [shareItem], from: sourceView)
  }

  func chooseFilesAndShare(from sourceView: NSView?) {
    guard !isSharing else { return }
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.title = AppLanguage.selected.localized("Choose items to share")
    guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
    share(items: panel.urls, from: sourceView)
  }

  func shareDropped(_ providers: [NSItemProvider], from sourceView: NSView?) {
    guard !isSharing, !providers.isEmpty else { return }
    Task { @MainActor [weak self] in
      var items: [Any] = []
      for provider in providers {
        guard !Task.isCancelled else { return }
        if let data = await Self.data(
          from: provider,
          typeIdentifier: UTType.fileURL.identifier
        ), let url = URL(dataRepresentation: data, relativeTo: nil) {
          items.append(url)
          continue
        }
        if let data = await Self.data(
          from: provider,
          typeIdentifier: UTType.url.identifier
        ), let value = String(data: data, encoding: .utf8), let url = URL(string: value) {
          items.append(url)
          continue
        }
        for typeIdentifier in [UTType.utf8PlainText.identifier, UTType.plainText.identifier]
          where provider.hasItemConformingToTypeIdentifier(typeIdentifier)
        {
          if let data = await Self.data(from: provider, typeIdentifier: typeIdentifier),
            let value = String(data: data, encoding: .utf8)
          {
            items.append(value)
            break
          }
        }
      }
      guard let self, !items.isEmpty else { return }
      self.share(items: items, from: sourceView)
    }
  }

  private func share(items: [Any], from sourceView: NSView?) {
    guard !isSharing, !items.isEmpty else { return }
    guard let sourceView = sourceView ?? NSApp.keyWindow?.contentView else { return }

    stopSharing()
    let fileURLs = items.compactMap { item in
      (item as? URL).flatMap { $0.isFileURL ? $0 : nil }
    }
    // Keep sharing regular URLs even when they have no security scope. The
    // service only needs to retain scopes that were successfully opened.
    sharingURLs = fileURLs.filter { $0.startAccessingSecurityScopedResource() }

    let delegate = VelnorrSharingDelegate { [weak self] in
      Task { @MainActor [weak self] in
        self?.stopSharing()
      }
    }
    let picker = NSSharingServicePicker(items: items)
    picker.delegate = delegate
    sharingDelegate = delegate
    sharingPicker = picker
    isSharing = true
    picker.show(
      relativeTo: sourceView.bounds,
      of: sourceView,
      preferredEdge: .minY
    )

    // A picker can be dismissed without selecting a service. Keep the security
    // scope bounded even when AppKit does not send a delegate callback.
    sharingTimeoutTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(15))
      guard !Task.isCancelled else { return }
      self?.stopSharing()
    }
  }

  func reveal(_ item: VelnorrShelfItem, using store: VelnorrShelfStore) {
    guard let url = fileURL(for: item, using: store) else { return }
    let started = url.startAccessingSecurityScopedResource()
    defer {
      if started { url.stopAccessingSecurityScopedResource() }
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func copyPath(_ item: VelnorrShelfItem, using store: VelnorrShelfStore) {
    guard let url = fileURL(for: item, using: store) else { return }
    let started = url.startAccessingSecurityScopedResource()
    defer {
      if started { url.stopAccessingSecurityScopedResource() }
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(url.path, forType: .string)
  }

  private func previewURL(
    for item: VelnorrShelfItem,
    using store: VelnorrShelfStore
  ) -> URL? {
    switch item.kind {
    case .file:
      return fileURL(for: item, using: store)
    case .link(let url):
      return url
    case .text:
      return nil
    }
  }

  private func shareItem(
    for item: VelnorrShelfItem,
    using store: VelnorrShelfStore
  ) -> Any? {
    switch item.kind {
    case .file:
      return fileURL(for: item, using: store)
    case .link(let url):
      return url
    case .text(let value):
      return value
    }
  }

  private func fileURL(
    for item: VelnorrShelfItem,
    using store: VelnorrShelfStore
  ) -> URL? {
    guard case .file = item.kind else { return nil }
    return store.resolveFileURL(for: item)
  }

  private func stopPreview() {
    if let panel = previewPanel {
      panel.orderOut(nil)
      panel.dataSource = nil
      panel.delegate = nil
    }
    for url in previewAccessedURLs {
      url.stopAccessingSecurityScopedResource()
    }
    previewURLs.removeAll()
    previewAccessedURLs.removeAll()
    previewDataSource = nil
    previewPanel = nil
  }

  private func stopSharing() {
    sharingTimeoutTask?.cancel()
    sharingTimeoutTask = nil
    for url in sharingURLs {
      url.stopAccessingSecurityScopedResource()
    }
    sharingURLs.removeAll()
    sharingPicker = nil
    sharingDelegate = nil
    isSharing = false
  }

  private static func data(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async -> Data? {
    guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { return nil }
    return await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }
}

private final class VelnorrQuickLookDataSource: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  private let urls: [URL]
  private let onClose: () -> Void

  init(urls: [URL], onClose: @escaping () -> Void) {
    self.urls = urls
    self.onClose = onClose
    super.init()
  }

  nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    urls.count
  }

  nonisolated func previewPanel(
    _ panel: QLPreviewPanel!,
    previewItemAt index: Int
  ) -> QLPreviewItem! {
    guard urls.indices.contains(index) else { return nil }
    return urls[index] as QLPreviewItem
  }

  nonisolated func previewPanelWillClose(_ panel: QLPreviewPanel!) {
    onClose()
  }
}

private final class VelnorrSharingDelegate: NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate {
  private let onFinish: () -> Void

  init(onFinish: @escaping () -> Void) {
    self.onFinish = onFinish
    super.init()
  }

  func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    didChoose service: NSSharingService?
  ) {
    guard let service else {
      onFinish()
      return
    }
    service.delegate = self
  }

  func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
    onFinish()
  }

  func sharingService(
    _ sharingService: NSSharingService,
    didFailToShareItems items: [Any],
    error: Error
  ) {
    onFinish()
  }
}
