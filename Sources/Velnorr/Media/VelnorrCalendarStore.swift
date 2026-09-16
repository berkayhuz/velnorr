import AppKit
import Combine
@preconcurrency import EventKit
import Foundation

/// Immutable reminder data captured before EventKit's callback returns.
///
/// EventKit may invoke `fetchReminders`' completion handler off the main
/// thread. Keeping only value types across that boundary prevents an
/// `EKReminder` instance from escaping its callback queue into the main actor.
struct VelnorrReminderSnapshot: Sendable, Equatable {
  let id: String
  let title: String?
  let dueDate: Date
  let isAllDay: Bool
  let location: String?
  let url: URL?
  let isCompleted: Bool

  init(
    id: String,
    title: String?,
    dueDate: Date,
    isAllDay: Bool,
    location: String?,
    url: URL?,
    isCompleted: Bool
  ) {
    self.id = id
    self.title = title
    self.dueDate = dueDate
    self.isAllDay = isAllDay
    self.location = location
    self.url = url
    self.isCompleted = isCompleted
  }

  @MainActor
  init?(reminder: EKReminder) {
    guard let dueDateComponents = reminder.dueDateComponents,
      let dueDate = dueDateComponents.date
    else { return nil }
    self.init(
      id: reminder.calendarItemIdentifier,
      title: reminder.title,
      dueDate: dueDate,
      isAllDay: dueDateComponents.hour == nil,
      location: reminder.location,
      url: reminder.url,
      isCompleted: reminder.isCompleted
    )
  }

  func isDue(from start: Date, to end: Date) -> Bool {
    dueDate >= start && dueDate < end
  }
}

/// Resolves an EventKit reminder fetch exactly once, including cancellation.
///
/// EventKit invokes its completion handler asynchronously and the handler may
/// race with cancellation of the task awaiting it. The lock protects the
/// continuation from that race and also lets cancellation complete before the
/// continuation has been installed.
final class VelnorrReminderFetchGate: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<[VelnorrReminderSnapshot], Never>?
  private var pendingResult: [VelnorrReminderSnapshot]?
  private var isFinished = false

  func install(_ continuation: CheckedContinuation<[VelnorrReminderSnapshot], Never>) {
    var resultToResume: [VelnorrReminderSnapshot]?

    lock.lock()
    if let pendingResult {
      self.pendingResult = nil
      resultToResume = pendingResult
    } else if isFinished {
      resultToResume = []
    } else {
      self.continuation = continuation
    }
    lock.unlock()

    if let resultToResume {
      continuation.resume(returning: resultToResume)
    }
  }

  func finish(_ result: [VelnorrReminderSnapshot]) {
    var continuationToResume: CheckedContinuation<[VelnorrReminderSnapshot], Never>?

    lock.lock()
    guard !isFinished else {
      lock.unlock()
      return
    }
    isFinished = true
    if let continuation {
      continuationToResume = continuation
      self.continuation = nil
    } else {
      pendingResult = result
    }
    lock.unlock()

    continuationToResume?.resume(returning: result)
  }
}

/// EventKit-backed calendar and reminder data for the utility panel.
///
/// The store is deliberately demand-driven: it reads only when the panel is
/// visible or EventKit reports a change, so an idle Velnorr never polls the
/// calendar database.
@MainActor
final class VelnorrCalendarStore: NSObject, ObservableObject {
  @Published private(set) var items: [VelnorrCalendarItem] = []
  @Published private(set) var authorizationStatus = EKAuthorizationStatus.notDetermined
  @Published private(set) var reminderAuthorizationStatus = EKAuthorizationStatus.notDetermined
  @Published private(set) var isLoading = false
  @Published private(set) var isRequestingAccess = false
  @Published private(set) var lastLoadedDate: Date?

  var hasEventReadAccess: Bool {
    Self.hasAccess(to: .event)
  }

  var hasReminderReadAccess: Bool {
    Self.hasAccess(to: .reminder)
  }

  var hasReadAccess: Bool {
    hasEventReadAccess || hasReminderReadAccess
  }

  private let eventStore = EKEventStore()
  private var eventStoreObserver: NSObjectProtocol?
  private var loadTask: Task<Void, Never>?
  private var loadIdentifier: UUID?
  private var reminderFetchRequest: Any?
  private var reminderFetchIdentifier: UUID?
  private var isActive = false

  override init() {
    authorizationStatus = Self.status(for: .event)
    reminderAuthorizationStatus = Self.status(for: .reminder)
    super.init()

    eventStoreObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.refreshAuthorizationStatus()
        guard self.isActive, let date = self.lastLoadedDate else { return }
        self.load(for: date)
      }
    }
  }

  isolated deinit {
    if let eventStoreObserver {
      NotificationCenter.default.removeObserver(eventStoreObserver)
    }
    cancelActiveLoad()
  }

  func start() {
    refreshAuthorizationStatus()
  }

  func activate(for date: Date) {
    isActive = true
    refreshAuthorizationStatus()
    load(for: date)
  }

  func deactivate() {
    isActive = false
    cancelActiveLoad()
    loadIdentifier = nil
    isLoading = false
    items = []
    lastLoadedDate = nil
  }

  func stop() {
    deactivate()
  }

  func requestAccessAndLoad(for date: Date) async {
    NSApp.activate(ignoringOtherApps: true)
    await requestAccess()
    refreshAuthorizationStatus()
    if Self.shouldOpenCalendarSettings(
      eventStatus: authorizationStatus,
      reminderStatus: reminderAuthorizationStatus
    ) {
      openCalendarSettings()
    }
    guard isActive else { return }
    load(for: date)
  }

  func requestAccess() async {
    guard !isRequestingAccess else { return }
    isRequestingAccess = true
    defer { isRequestingAccess = false }

    refreshAuthorizationStatus()
    if authorizationStatus == .notDetermined {
      _ = await requestAccess(to: .event)
      refreshAuthorizationStatus()
    }

    if reminderAuthorizationStatus == .notDetermined {
      _ = await requestAccess(to: .reminder)
      refreshAuthorizationStatus()
    }
  }

  func refreshAuthorizationStatus() {
    authorizationStatus = Self.status(for: .event)
    reminderAuthorizationStatus = Self.status(for: .reminder)
  }

  func load(for date: Date) {
    guard isActive else { return }
    cancelActiveLoad()
    let normalizedDate = Calendar.current.startOfDay(for: date)
    let identifier = UUID()
    loadIdentifier = identifier
    lastLoadedDate = normalizedDate

    guard Self.hasAccess(to: .event) || Self.hasAccess(to: .reminder) else {
      isLoading = false
      items = []
      return
    }

    isLoading = true
    loadTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let loadedItems = await self.fetchItems(for: normalizedDate)
      guard !Task.isCancelled, self.loadIdentifier == identifier else { return }
      self.items = loadedItems
      self.isLoading = false
      self.loadTask = nil
    }
  }

  private func cancelActiveLoad() {
    loadTask?.cancel()
    loadTask = nil

    if let reminderFetchRequest {
      eventStore.cancelFetchRequest(reminderFetchRequest)
    }
    reminderFetchRequest = nil
    reminderFetchIdentifier = nil
  }

  func items(for date: Date) -> [VelnorrCalendarItem] {
    guard let lastLoadedDate,
      Calendar.current.isDate(lastLoadedDate, inSameDayAs: date)
    else { return [] }
    return items
  }

  func setReminderCompleted(_ item: VelnorrCalendarItem, completed: Bool) async {
    guard isActive, item.isReminder,
      let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder
    else { return }

    reminder.isCompleted = completed
    do {
      try eventStore.save(reminder, commit: true)
      if let date = lastLoadedDate {
        load(for: date)
      }
    } catch {
      // EventKit errors are intentionally not logged with item titles or
      // identifiers, which may contain personal calendar information.
    }
  }

  func open(_ item: VelnorrCalendarItem) {
    guard let url = item.url else { return }
    NSWorkspace.shared.open(url)
  }

  func openCalendarSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func requestAccess(to type: EKEntityType) async -> Bool {
    do {
      if #available(macOS 14.0, *) {
        switch type {
        case .event:
          return try await eventStore.requestFullAccessToEvents()
        case .reminder:
          return try await eventStore.requestFullAccessToReminders()
        @unknown default:
          return false
        }
      }
      return try await eventStore.requestAccess(to: type)
    } catch {
      return false
    }
  }

  private func fetchItems(for date: Date) async -> [VelnorrCalendarItem] {
    let endDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    var result: [VelnorrCalendarItem] = []

    if Self.hasAccess(to: .event) {
      let calendars = eventStore.calendars(for: .event)
      let predicate = eventStore.predicateForEvents(
        withStart: date,
        end: endDate,
        calendars: calendars
      )
      result.append(contentsOf: eventStore.events(matching: predicate).map(Self.makeItem))
    }

    if Self.hasAccess(to: .reminder) {
      let calendars = eventStore.calendars(for: .reminder)
      result.append(contentsOf: await fetchReminders(from: date, to: endDate, calendars: calendars))
    }

    return result.sorted { lhs, rhs in
      if lhs.startDate == rhs.startDate { return lhs.title < rhs.title }
      return lhs.startDate < rhs.startDate
    }
  }

  private func fetchReminders(
    from start: Date,
    to end: Date,
    calendars: [EKCalendar]
  ) async -> [VelnorrCalendarItem] {
    let gate = VelnorrReminderFetchGate()
    let fetchIdentifier = UUID()
    let snapshots: [VelnorrReminderSnapshot] = await withTaskCancellationHandler(
      operation: {
        await withCheckedContinuation { continuation in
          gate.install(continuation)
          let predicate = eventStore.predicateForReminders(in: calendars)
          let request = eventStore.fetchReminders(matching: predicate) { [weak self, gate] reminders in
            // EventKit can invoke this callback on a non-main queue, while its
            // object accessors are main-actor isolated on newer SDKs. Move the
            // short-lived EventKit read back to the main actor before converting
            // the objects into Sendable snapshots.
            Task { @MainActor [weak self, gate] in
              let snapshots = (reminders ?? []).compactMap { reminder in
                VelnorrReminderSnapshot(reminder: reminder)
              }
              if self?.reminderFetchIdentifier == fetchIdentifier {
                self?.reminderFetchRequest = nil
                self?.reminderFetchIdentifier = nil
              }
              gate.finish(snapshots.filter { $0.isDue(from: start, to: end) })
            }
          }
          reminderFetchRequest = request
          reminderFetchIdentifier = fetchIdentifier

          if Task.isCancelled {
            eventStore.cancelFetchRequest(request)
            gate.finish([])
          }
        }
      },
      onCancel: {
        gate.finish([])
      }
    )
    return snapshots.map(Self.makeItem)
  }

  private static func makeItem(_ event: EKEvent) -> VelnorrCalendarItem {
    VelnorrCalendarItem(
      id: event.calendarItemIdentifier,
      title: event.title ?? AppLanguage.selected.localized("Untitled event"),
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: event.location,
      url: event.url,
      kind: .event
    )
  }

  private static func makeItem(_ snapshot: VelnorrReminderSnapshot) -> VelnorrCalendarItem {
    let endDate = Calendar.current.dateInterval(of: .day, for: snapshot.dueDate)?.end
      ?? snapshot.dueDate
    return VelnorrCalendarItem(
      id: snapshot.id,
      title: snapshot.title ?? AppLanguage.selected.localized("Untitled reminder"),
      startDate: snapshot.dueDate,
      endDate: endDate,
      isAllDay: snapshot.isAllDay,
      location: snapshot.location,
      url: snapshot.url,
      kind: .reminder(completed: snapshot.isCompleted)
    )
  }

  private static func status(for type: EKEntityType) -> EKAuthorizationStatus {
    EKEventStore.authorizationStatus(for: type)
  }

  private static func hasAccess(to type: EKEntityType) -> Bool {
    hasReadAccess(status: status(for: type))
  }

  nonisolated static func hasReadAccess(status: EKAuthorizationStatus) -> Bool {
    if #available(macOS 14.0, *) {
      // Some upgraded or previously authorized installations still report
      // the legacy authorized value even though the app can read entities.
      return status == .fullAccess || status == .authorized
    }
    return status == .authorized
  }

  nonisolated static func shouldOpenCalendarSettings(
    eventStatus: EKAuthorizationStatus,
    reminderStatus: EKAuthorizationStatus
  ) -> Bool {
    isUnresolved(status: eventStatus) || isUnresolved(status: reminderStatus)
  }

  private nonisolated static func isUnresolved(status: EKAuthorizationStatus) -> Bool {
    status == .notDetermined || status == .denied || status == .restricted
  }
}
