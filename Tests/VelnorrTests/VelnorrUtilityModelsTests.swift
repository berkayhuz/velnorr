import Foundation
@preconcurrency import EventKit
import XCTest

@testable import Velnorr

final class VelnorrUtilityModelsTests: XCTestCase {
  func testShelfItemCodingPreservesEverySupportedKind() throws {
    let linkURL = try XCTUnwrap(URL(string: "https://example.com/path"))
    let items = [
      VelnorrShelfItem(kind: .file(bookmark: Data([1, 2, 3]), displayName: "Notes.txt")),
      VelnorrShelfItem(kind: .link(url: linkURL)),
      VelnorrShelfItem(kind: .text("A copied note")),
    ]

    let encoded = try JSONEncoder().encode(items)
    let decoded = try JSONDecoder().decode([VelnorrShelfItem].self, from: encoded)

    XCTAssertEqual(decoded, items)
  }

  @MainActor
  func testShelfStoreDeduplicatesAndBoundsPersistedItems() throws {
    let storageURL = temporaryStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }

    let store = VelnorrShelfStore(storageURL: storageURL)
    let items = (0..<(VelnorrShelfStore.itemLimit + 8)).map {
      VelnorrShelfItem(
        kind: .text("Item \($0)"),
        createdAt: Date(timeIntervalSince1970: TimeInterval($0))
      )
    }

    store.add(items)
    store.add([try XCTUnwrap(items.last)])

    XCTAssertEqual(store.items.count, VelnorrShelfStore.itemLimit)
    XCTAssertEqual(Set(store.items.map(\.identityKey)).count, store.items.count)

    let reloaded = VelnorrShelfStore(storageURL: storageURL)
    XCTAssertEqual(reloaded.items, store.items)
  }

  @MainActor
  func testCalendarStoreClearsDemandDrivenStateWhenDeactivated() {
    let store = VelnorrCalendarStore()

    store.activate(for: Date())
    store.deactivate()

    XCTAssertTrue(store.items.isEmpty)
    XCTAssertNil(store.lastLoadedDate)
    XCTAssertFalse(store.isLoading)
  }

  @MainActor
  func testReminderFetchGateCompletesCancellationAndIgnoresLateCallback() async {
    let gate = VelnorrReminderFetchGate()
    let fetchTask = Task {
      await withCheckedContinuation { continuation in
        gate.install(continuation)
      }
    }

    await Task.yield()
    gate.finish([])
    let fetchedResult = await fetchTask.value
    XCTAssertTrue(fetchedResult.isEmpty)

    let lateResult = await withCheckedContinuation { continuation in
      gate.install(continuation)
    }
    XCTAssertTrue(lateResult.isEmpty)
    gate.finish([
      VelnorrReminderSnapshot(
        id: "late",
        title: "Late callback",
        dueDate: Date(),
        isAllDay: false,
        location: nil,
        url: nil,
        isCompleted: false
      )
    ])
  }

  func testUtilityPanelsExposeStableTitlesAndSymbols() {
    XCTAssertEqual(VelnorrUtilityPanel.calendar.titleKey, "Calendar")
    XCTAssertEqual(VelnorrUtilityPanel.shelf.symbolName, "tray.full")
    XCTAssertEqual(VelnorrUtilityPanel.mirror.symbolName, "video.fill")
    XCTAssertEqual(
      VelnorrUtilityPanel.allCases.filter { $0 != .media },
      [.calendar, .shelf, .mirror]
    )
  }

  func testUtilityLayoutKeepsControlsTouchableAndSurfacesBalanced() {
    XCTAssertEqual(NotchMetrics.mediaNavigationTopPadding, 2)
    XCTAssertEqual(NotchMetrics.mediaNavigationHoverScale, 1.05)
    XCTAssertGreaterThanOrEqual(VelnorrUtilityLayout.controlHitSize, 32)
    XCTAssertGreaterThanOrEqual(VelnorrUtilityLayout.shelfItemWidth, 104)
    XCTAssertGreaterThanOrEqual(VelnorrUtilityLayout.shelfItemIconSize, 56)
    XCTAssertGreaterThanOrEqual(
      VelnorrUtilityLayout.shelfItemNameHeight,
      30
    )
    XCTAssertEqual(VelnorrUtilityLayout.shelfContentWidth(for: 0), 0)
    XCTAssertEqual(
      VelnorrUtilityLayout.shelfContentWidth(for: 4),
      4 * VelnorrUtilityLayout.shelfItemWidth
        + 3 * VelnorrUtilityLayout.shelfItemSpacing
        + 2 * VelnorrUtilityLayout.shelfListHorizontalInset
    )
    XCTAssertGreaterThan(VelnorrUtilityLayout.calendarHeaderHeight, VelnorrUtilityLayout.filterHeight)
    XCTAssertGreaterThan(VelnorrUtilityLayout.shelfShareHeight, VelnorrUtilityLayout.filterHeight)
    XCTAssertGreaterThanOrEqual(
      VelnorrUtilityLayout.shelfDropMinimumHeight,
      VelnorrUtilityLayout.shelfItemHeight
    )
  }

  func testMirrorShapeOptionsRemainStable() {
    XCTAssertEqual(VelnorrMirrorShape.roundedRectangle.titleKey, "Rounded rectangle")
    XCTAssertEqual(VelnorrMirrorShape.circle.titleKey, "Circle")
    XCTAssertEqual(VelnorrMirrorShape.allCases, [.roundedRectangle, .circle])
  }

  func testCalendarFilterHonorsEventReminderAndCompletedVisibility() {
    let event = VelnorrCalendarItem(
      id: "event",
      title: "Planning",
      startDate: Date(),
      endDate: Date().addingTimeInterval(3_600),
      isAllDay: false,
      location: nil,
      url: nil,
      kind: .event
    )
    let openReminder = VelnorrCalendarItem(
      id: "open-reminder",
      title: "Submit report",
      startDate: Date(),
      endDate: Date(),
      isAllDay: true,
      location: nil,
      url: nil,
      kind: .reminder(completed: false)
    )
    let completedReminder = VelnorrCalendarItem(
      id: "completed-reminder",
      title: "Book venue",
      startDate: Date(),
      endDate: Date(),
      isAllDay: true,
      location: nil,
      url: nil,
      kind: .reminder(completed: true)
    )

    let filter = VelnorrCalendarFilter(
      showEvents: true,
      showReminders: true,
      showCompletedReminders: false
    )

    XCTAssertTrue(filter.includes(event))
    XCTAssertTrue(filter.includes(openReminder))
    XCTAssertFalse(filter.includes(completedReminder))
    XCTAssertFalse(VelnorrCalendarFilter(showEvents: false).includes(event))
    XCTAssertFalse(VelnorrCalendarFilter(showReminders: false).includes(openReminder))
  }

  func testCalendarReadAccessAcceptsLegacyAuthorizedStatus() throws {
    // Raw value 3 is EKAuthorizationStatus.authorized, which is deprecated
    // in the SDK but still returned by upgraded macOS installations.
    let legacyAuthorizedStatus = try XCTUnwrap(EKAuthorizationStatus(rawValue: 3))
    XCTAssertTrue(VelnorrCalendarStore.hasReadAccess(status: legacyAuthorizedStatus))
    XCTAssertFalse(VelnorrCalendarStore.hasReadAccess(status: .denied))
    if #available(macOS 14.0, *) {
      XCTAssertTrue(VelnorrCalendarStore.hasReadAccess(status: .fullAccess))
    }
  }

  func testCalendarPermissionFallbackRequiresSettingsWhenUnresolved() throws {
    let legacyAuthorizedStatus = try XCTUnwrap(EKAuthorizationStatus(rawValue: 3))

    XCTAssertTrue(
      VelnorrCalendarStore.shouldOpenCalendarSettings(
        eventStatus: .notDetermined,
        reminderStatus: legacyAuthorizedStatus
      )
    )
    XCTAssertTrue(
      VelnorrCalendarStore.shouldOpenCalendarSettings(
        eventStatus: .denied,
        reminderStatus: legacyAuthorizedStatus
      )
    )
    XCTAssertFalse(
      VelnorrCalendarStore.shouldOpenCalendarSettings(
        eventStatus: legacyAuthorizedStatus,
        reminderStatus: legacyAuthorizedStatus
      )
    )
    if #available(macOS 14.0, *) {
      XCTAssertFalse(
        VelnorrCalendarStore.shouldOpenCalendarSettings(
          eventStatus: .fullAccess,
          reminderStatus: .fullAccess
        )
      )
    }
  }

  func testReminderSnapshotUsesHalfOpenDateWindow() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 2_000)
    let snapshot = VelnorrReminderSnapshot(
      id: "reminder",
      title: "Submit report",
      dueDate: Date(timeIntervalSince1970: 1_500),
      isAllDay: false,
      location: nil,
      url: nil,
      isCompleted: false
    )
    let atEnd = VelnorrReminderSnapshot(
      id: "at-end",
      title: nil,
      dueDate: end,
      isAllDay: true,
      location: nil,
      url: nil,
      isCompleted: false
    )

    XCTAssertTrue(snapshot.isDue(from: start, to: end))
    XCTAssertFalse(atEnd.isDue(from: start, to: end))
  }

  func testShelfConfiguredItemLimitIsBounded() throws {
    let suiteName = "VelnorrTests.ShelfLimit.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(
      VelnorrShelfStore.configuredItemLimit(userDefaults: defaults),
      VelnorrShelfStore.itemLimit
    )

    defaults.set(2, forKey: AppSettings.shelfMaximumItems)
    XCTAssertEqual(
      VelnorrShelfStore.configuredItemLimit(userDefaults: defaults),
      VelnorrShelfStore.minimumItemLimit
    )

    defaults.set(16, forKey: AppSettings.shelfMaximumItems)
    XCTAssertEqual(VelnorrShelfStore.configuredItemLimit(userDefaults: defaults), 16)

    defaults.set(100, forKey: AppSettings.shelfMaximumItems)
    XCTAssertEqual(
      VelnorrShelfStore.configuredItemLimit(userDefaults: defaults),
      VelnorrShelfStore.itemLimit
    )
  }

  @MainActor
  func testShelfStoreReportsPersistenceFailure() throws {
    let parentURL = temporaryStorageURL()
    let storageURL = parentURL.appendingPathComponent("items.json")
    defer { try? FileManager.default.removeItem(at: parentURL) }
    XCTAssertTrue(FileManager.default.createFile(atPath: parentURL.path, contents: Data()))

    let store = VelnorrShelfStore(storageURL: storageURL)
    store.add([VelnorrShelfItem(kind: .text("A note"))])

    XCTAssertEqual(store.lastError, .persistenceFailed)
  }

  private func temporaryStorageURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("velnorr-shelf-\(UUID().uuidString)", isDirectory: false)
  }
}
