import AppKit
@preconcurrency import AVFoundation
@preconcurrency import EventKit
import SwiftUI
import UniformTypeIdentifiers

/// Shared sizing rules for the utility surfaces.
///
/// Keeping the touch targets and vertical budget together prevents Calendar
/// and Shelf from drifting apart as their content evolves. These values are
/// intentionally sized for the existing utility canvas rather than adding a
/// second, competing layout system.
enum VelnorrUtilityLayout {
  static let controlHitSize: CGFloat = 32
  static let calendarHeaderHeight: CGFloat = 40
  static let filterHeight: CGFloat = 24
  static let shelfShareHeight: CGFloat = 40
  static let shelfDropMinimumHeight: CGFloat = 126
  static let shelfItemWidth: CGFloat = 108
  static let shelfItemHeight: CGFloat = 118
  static let shelfItemIconSize: CGFloat = 56
  static let shelfItemNameHeight: CGFloat = 30
  static let shelfItemSpacing: CGFloat = 8
  static let shelfListHorizontalInset: CGFloat = 6

  static func shelfContentWidth(for itemCount: Int) -> CGFloat {
    guard itemCount > 0 else { return 0 }
    return CGFloat(itemCount) * shelfItemWidth
      + CGFloat(max(0, itemCount - 1)) * shelfItemSpacing
      + shelfListHorizontalInset * 2
  }
}

struct VelnorrUtilityPanelView: View {
  let runtime: VelnorrRuntime
  let selectedPanel: VelnorrUtilityPanel
  let displayMode: VelnorrDisplayMode
  let centerGap: CGFloat
  let contentHorizontalInset: CGFloat
  let contentTopInset: CGFloat
  let onSelect: (VelnorrUtilityPanel) -> Void
  let onOpenMedia: () -> Void
  let onOpenMirror: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearanceAnimations") private var animationsEnabled = true

  var body: some View {
    ZStack(alignment: .top) {
      VelnorrPanelNavigationView(
        displayMode: displayMode,
        centerGap: centerGap,
        selectedPanel: selectedPanel,
        onOpenCalendar: { onSelect(.calendar) },
        onOpenShelf: { onSelect(.shelf) },
        onOpenMedia: onOpenMedia,
        onOpenMirror: onOpenMirror
      )
      .frame(height: NotchMetrics.mediaNavigationHeight)

      VStack(spacing: 10) {
        Group {
          switch selectedPanel {
          case .calendar:
            VelnorrCalendarPanel(store: runtime.calendar)
          case .shelf:
            VelnorrShelfPanel(store: runtime.shelf, actions: runtime.shelfActions)
          case .mirror:
            VelnorrMirrorPanel(store: runtime.camera)
          case .media:
            EmptyView()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(VelnorrTransition.panel)
      }
      // Expanded surfaces curve inward at both sides. Keep every utility view
      // inside that black surface instead of relying on the outer clip to hide
      // overflow from the tab bar or panel content.
      .padding(.horizontal, contentHorizontalInset)
      .padding(.top, max(contentTopInset, NotchMetrics.mediaNavigationHeight + NotchMetrics.mediaNavigationSpacing))
      .padding(.bottom, 14)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(
      motionReduced ? .easeOut(duration: 0.12) : VelnorrAnimation.content,
      value: selectedPanel
    )
  }

  private var motionReduced: Bool {
    reduceMotion || !animationsEnabled
  }
}

struct VelnorrPanelNavigationView: View {
  let displayMode: VelnorrDisplayMode
  let centerGap: CGFloat
  let selectedPanel: VelnorrUtilityPanel
  let onOpenCalendar: () -> Void
  let onOpenShelf: () -> Void
  let onOpenMedia: () -> Void
  let onOpenMirror: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let physicalGap = VelnorrPanelNavigationLayout.physicalGap(
        displayMode: displayMode,
        centerGap: centerGap,
        availableWidth: geometry.size.width
      )
      let sideWidth = VelnorrPanelNavigationLayout.sideWidth(
        displayMode: displayMode,
        centerGap: centerGap,
        availableWidth: geometry.size.width
      )
      let notchSideAlignment: Alignment = displayMode == .notch ? .center : .leading

      HStack(spacing: 0) {
        navigationGroup(isLeft: true)
          .frame(width: sideWidth, alignment: notchSideAlignment)
          .offset(
            x: displayMode == .notch
              ? NotchMetrics.mediaNavigationSideInset
              : 12
          )

        if physicalGap > 0 {
          Color.clear
            .frame(width: physicalGap)
        }

        navigationGroup(isLeft: false)
          .frame(
            width: sideWidth,
            alignment: displayMode == .notch ? .center : .trailing
          )
          .offset(
            x: displayMode == .notch
              ? -NotchMetrics.mediaNavigationSideInset
              : -12
          )
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .offset(y: NotchMetrics.mediaNavigationTopPadding)
    }
    .frame(height: NotchMetrics.mediaNavigationHeight)
  }

  private func navigationGroup(isLeft: Bool) -> some View {
    HStack(spacing: 4) {
      if isLeft {
        navigationButton(
          symbol: VelnorrUtilityPanel.calendar.symbolName,
          label: VelnorrUtilityPanel.calendar.titleKey,
          isSelected: selectedPanel == .calendar,
          action: onOpenCalendar
        )
        navigationButton(
          symbol: VelnorrUtilityPanel.shelf.symbolName,
          label: VelnorrUtilityPanel.shelf.titleKey,
          isSelected: selectedPanel == .shelf,
          action: onOpenShelf
        )
      } else {
        navigationButton(
          symbol: VelnorrUtilityPanel.media.symbolName,
          label: VelnorrUtilityPanel.media.titleKey,
          isSelected: selectedPanel == .media,
          action: onOpenMedia
        )
        navigationButton(
          symbol: VelnorrUtilityPanel.mirror.symbolName,
          label: VelnorrUtilityPanel.mirror.titleKey,
          isSelected: selectedPanel == .mirror,
          action: onOpenMirror
        )
      }
    }
  }

  private func navigationButton(
    symbol: String,
    label: String,
    isSelected: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .frame(width: 32, height: 28)
        .background {
          if isSelected {
            Capsule()
              .fill(.white.opacity(0.16))
          }
        }
        .contentShape(Capsule())
    }
    .buttonStyle(VelnorrPanelNavigationButtonStyle(isSelected: isSelected))
    .accessibilityLabel(utilityLocalized(label))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct VelnorrPanelNavigationButtonStyle: ButtonStyle {
  let isSelected: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovered = false

  init(isSelected: Bool) {
    self.isSelected = isSelected
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(
        isSelected || isHovered ? .white : .white.opacity(0.5)
      )
      .scaleEffect(
        configuration.isPressed
          ? 0.88
          : (isHovered && !reduceMotion ? NotchMetrics.mediaNavigationHoverScale : 1)
      )
      .onHover { hovering in
        isHovered = hovering
      }
      .animation(
        reduceMotion ? .easeOut(duration: 0.08) : VelnorrAnimation.control,
        value: configuration.isPressed
      )
      .animation(
        reduceMotion ? .easeOut(duration: 0.08) : VelnorrAnimation.control,
        value: isHovered
      )
  }
}

private struct VelnorrUtilityTabButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .animation(
        reduceMotion ? .easeOut(duration: 0.08) : VelnorrAnimation.control,
        value: configuration.isPressed
      )
  }
}

private struct VelnorrUtilityActionButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .animation(
        reduceMotion ? .easeOut(duration: 0.08) : VelnorrAnimation.control,
        value: configuration.isPressed
      )
  }
}

private struct VelnorrCalendarPanel: View {
  @ObservedObject var store: VelnorrCalendarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(AppSettings.calendarShowEvents) private var showEvents = true
  @AppStorage(AppSettings.calendarShowReminders) private var showReminders = true
  @AppStorage(AppSettings.calendarShowCompletedReminders) private var showCompletedReminders = true
  @State private var selectedDate = Date()
  @State private var hoveredItemID: String?

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Button(action: { shiftDate(by: -1) }) {
          Image(systemName: "chevron.left")
            .frame(
              width: VelnorrUtilityLayout.controlHitSize,
              height: VelnorrUtilityLayout.controlHitSize
            )
        }
        .buttonStyle(VelnorrUtilityTabButtonStyle())
        .contentShape(Circle())
        .accessibilityLabel(utilityLocalized("Previous day"))

        VStack(alignment: .leading, spacing: 0) {
          Text(selectedDate.formatted(.dateTime.weekday(.wide)))
            .font(.system(size: 12, weight: .semibold))
          Text(selectedDate.formatted(.dateTime.month(.abbreviated).day()))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if !Calendar.current.isDateInToday(selectedDate) {
          Button(utilityLocalized("Today"), action: selectToday)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale))
        }

        Button(action: { shiftDate(by: 1) }) {
          Image(systemName: "chevron.right")
            .frame(
              width: VelnorrUtilityLayout.controlHitSize,
              height: VelnorrUtilityLayout.controlHitSize
            )
        }
        .buttonStyle(VelnorrUtilityTabButtonStyle())
        .contentShape(Circle())
        .accessibilityLabel(utilityLocalized("Next day"))
      }
      .foregroundStyle(.white.opacity(0.9))
      .padding(.horizontal, 4)
      .frame(maxWidth: .infinity, minHeight: VelnorrUtilityLayout.calendarHeaderHeight)
      .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
      .animation(
        reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control,
        value: selectedDate
      )

      if !store.hasReadAccess {
        permissionContent
      } else if store.isLoading {
        loadingContent
        Spacer(minLength: 0)
      } else {
        if needsAccessPrompt {
          accessPrompt
        }
        filterSummary
        if hasPartialPermission {
          partialPermissionNotice
        }
        if dayItems.isEmpty {
          emptyContent(hasFilteredItems: !rawDayItems.isEmpty)
        } else {
          ScrollView(.vertical) {
            LazyVStack(spacing: 4) {
              ForEach(dayItems) { item in
                calendarRow(item)
              }
            }
          }
          .scrollIndicators(.never)
        }
      }
    }
    .onAppear { store.activate(for: selectedDate) }
    .onDisappear { store.deactivate() }
    .accessibilityElement(children: .contain)
  }

  private var rawDayItems: [VelnorrCalendarItem] {
    store.items(for: selectedDate)
  }

  private var dayItems: [VelnorrCalendarItem] {
    rawDayItems.filter { calendarFilter.includes($0) }
  }

  private var calendarFilter: VelnorrCalendarFilter {
    VelnorrCalendarFilter(
      showEvents: showEvents,
      showReminders: showReminders,
      showCompletedReminders: showCompletedReminders
    )
  }

  private var hasPartialPermission: Bool {
    store.hasReadAccess && (isRestrictedOrDenied(store.authorizationStatus)
      || isRestrictedOrDenied(store.reminderAuthorizationStatus))
  }

  private var needsAccessPrompt: Bool {
    store.authorizationStatus == .notDetermined
      || store.reminderAuthorizationStatus == .notDetermined
  }

  private var permissionContent: some View {
    VStack(spacing: 8) {
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(.white.opacity(0.52))
      Text(utilityLocalized("Calendar and Reminders access is needed to show this panel."))
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.5))
        .multilineTextAlignment(.center)
      accessButton
      if isRestrictedOrDenied(store.authorizationStatus)
        || isRestrictedOrDenied(store.reminderAuthorizationStatus)
      {
        Button(utilityLocalized("Open Calendar Settings"), action: store.openCalendarSettings)
          .buttonStyle(.link)
          .font(.system(size: 10))
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
  }

  private var loadingContent: some View {
    VStack(spacing: 8) {
      ProgressView().controlSize(.small)
      Text(utilityLocalized("Loading calendar"))
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.46))
    }
    .frame(maxWidth: .infinity)
  }

  private var accessPrompt: some View {
    HStack(spacing: 6) {
      Image(systemName: "calendar.badge.clock")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.white.opacity(0.42))
      Text(utilityLocalized("Calendar access is not fully configured"))
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.48))
        .lineLimit(1)
      Spacer(minLength: 0)
      Button(utilityLocalized("Allow Calendar & Reminders")) {
        Task { await store.requestAccessAndLoad(for: selectedDate) }
      }
      .buttonStyle(.link)
      .font(.system(size: 9, weight: .semibold))
      .disabled(store.isRequestingAccess)
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
  }

  private var accessButton: some View {
    Button {
      Task { await store.requestAccessAndLoad(for: selectedDate) }
    } label: {
      HStack(spacing: 6) {
        if store.isRequestingAccess {
          ProgressView().controlSize(.small)
        }
        Text(utilityLocalized("Allow Calendar & Reminders"))
      }
    }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(store.isRequestingAccess)
  }

  private func isRestrictedOrDenied(_ status: EKAuthorizationStatus) -> Bool {
    status == .denied || status == .restricted
  }

  private var filterSummary: some View {
    HStack(spacing: 5) {
      filterPill(icon: "calendar", title: "Events", active: showEvents) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control) {
          showEvents.toggle()
        }
      }
      filterPill(icon: "checklist", title: "Reminders", active: showReminders) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VelnorrAnimation.control) {
          showReminders.toggle()
        }
      }
      Spacer(minLength: 4)
      Text("\(dayItems.count)")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
        .monospacedDigit()
        .accessibilityLabel(utilityLocalized("Visible items"))
    }
  }

  private func filterPill(
    icon: String,
    title: String,
    active: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(utilityLocalized(title), systemImage: icon)
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(active ? .white.opacity(0.7) : .white.opacity(0.28))
        .padding(.horizontal, 7)
        .frame(minHeight: VelnorrUtilityLayout.filterHeight)
        .background(.white.opacity(active ? 0.1 : 0.035), in: Capsule())
    }
    .buttonStyle(VelnorrUtilityActionButtonStyle())
    .contentShape(Capsule())
    .accessibilityAddTraits(active ? .isSelected : [])
  }

  private var partialPermissionNotice: some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.orange)
      Text(utilityLocalized("Some calendar data is unavailable"))
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.52))
        .lineLimit(1)
      Spacer(minLength: 0)
      Button(utilityLocalized("Open"), action: store.openCalendarSettings)
        .buttonStyle(.link)
        .font(.system(size: 9, weight: .semibold))
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
  }

  private func emptyContent(hasFilteredItems: Bool) -> some View {
    VStack(spacing: 4) {
      Image(systemName: "calendar.badge.checkmark")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white.opacity(0.42))
        .frame(width: 38, height: 38)
        .background(.white.opacity(0.06), in: Circle())
      Text(hasFilteredItems
        ? utilityLocalized("No matching items")
        : Calendar.current.isDateInToday(selectedDate)
        ? utilityLocalized("No events today")
        : utilityLocalized("No events"))
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.64))
      Text(hasFilteredItems
        ? utilityLocalized("Try changing the Calendar filters in Settings.")
        : utilityLocalized("Enjoy your free time!"))
        .font(.system(size: 9, weight: .regular))
        .foregroundStyle(.white.opacity(0.4))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private func calendarRow(_ item: VelnorrCalendarItem) -> some View {
    if item.isReminder {
      calendarRowSurface(item)
    } else {
      Button(action: { store.open(item) }) {
        calendarRowSurface(item)
      }
      .buttonStyle(.plain)
    }
  }

  private func calendarRowSurface(_ item: VelnorrCalendarItem) -> some View {
    HStack(spacing: 7) {
      Image(systemName: item.isReminder ? "checklist" : "calendar")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(item.isReminder ? .orange : .blue)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 1) {
        Text(item.title)
          .font(.system(size: 11, weight: .semibold))
          .lineLimit(1)
          .strikethrough(item.isCompleted, color: .white.opacity(0.5))
        Text(timeDescription(for: item))
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.46))
        if let location = item.location, !location.isEmpty {
          Label(location, systemImage: "mappin.and.ellipse")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.white.opacity(0.36))
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(item.isCompleted ? 0.45 : 1)

      if item.isReminder {
        Button {
          Task { await store.setReminderCompleted(item, completed: !item.isCompleted) }
        } label: {
          Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(item.isCompleted ? .green : .white.opacity(0.42))
        }
        .buttonStyle(.plain)
        .frame(width: VelnorrUtilityLayout.controlHitSize, height: VelnorrUtilityLayout.controlHitSize)
        .contentShape(Circle())
        .accessibilityLabel(utilityLocalized(item.isCompleted ? "Mark incomplete" : "Mark complete"))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(hoveredItemID == item.id ? .white.opacity(0.1) : .white.opacity(0.06))
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(hoveredItemID == item.id ? .white.opacity(0.14) : .clear, lineWidth: 1)
        }
    )
    .scaleEffect(hoveredItemID == item.id ? 1.006 : 1)
    .contentShape(Rectangle())
    .onHover { isHovered in
      hoveredItemID = isHovered ? item.id : nil
    }
    .animation(
      reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
      value: hoveredItemID == item.id
    )
  }

  private func timeDescription(for item: VelnorrCalendarItem) -> String {
    if item.isAllDay { return utilityLocalized("All-day") }
    let start = item.startDate.formatted(date: .omitted, time: .shortened)
    let end = item.endDate.formatted(date: .omitted, time: .shortened)
    return start == end ? start : "\(start) – \(end)"
  }

  private func shiftDate(by days: Int) {
    guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
    else { return }
    selectedDate = date
    store.load(for: date)
  }

  private func selectToday() {
    let today = Date()
    selectedDate = today
    store.load(for: today)
  }
}

private struct VelnorrShelfPanel: View {
  @ObservedObject var store: VelnorrShelfStore
  @ObservedObject var actions: VelnorrShelfActionService
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(AppSettings.shelfShowQuickShare) private var showQuickShare = true
  @AppStorage(AppSettings.shelfMaximumItems) private var maximumItems = VelnorrShelfStore.itemLimit
  @State private var isTargeted = false
  @State private var shareAnchor: NSView?

  var body: some View {
    VStack(spacing: 8) {
      shelfHeader

      if showQuickShare {
        VelnorrShelfShareCard(
          actions: actions,
          shareAnchor: shareAnchor
        )
      }

      ZStack {
        if store.items.isEmpty {
          VStack(spacing: 6) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
              .font(.system(size: 20, weight: .medium))
              .frame(width: 40, height: 40)
            Text(utilityLocalized("Drop files, links, or text here"))
              .font(.system(size: 11, weight: .semibold))
            Text(utilityLocalized("Click an item to open or copy it"))
              .font(.system(size: 9))
              .foregroundStyle(.white.opacity(0.42))
          }
          .foregroundStyle(isTargeted ? Color.accentColor : .white.opacity(0.48))
        } else {
          ScrollView(.horizontal) {
            LazyHStack(spacing: VelnorrUtilityLayout.shelfItemSpacing) {
              ForEach(store.items) { item in
                VelnorrShelfItemCard(
                  item: item,
                  store: store,
                  actions: actions,
                  shareAnchor: shareAnchor
                )
              }
            }
            .padding(.horizontal, VelnorrUtilityLayout.shelfListHorizontalInset)
            // Keep the scroll content wider than the viewport when the shelf
            // has more cards than can be shown at once.
            .frame(
              minWidth: VelnorrUtilityLayout.shelfContentWidth(for: store.items.count),
              maxHeight: .infinity,
              alignment: .leading
            )
          }
          .scrollIndicators(.automatic)
        }
      }
      .frame(
        maxWidth: .infinity,
        minHeight: VelnorrUtilityLayout.shelfDropMinimumHeight,
        maxHeight: .infinity,
        alignment: .center
      )
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.035))
          .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(
                isTargeted ? Color.accentColor.opacity(0.85) : .white.opacity(0.1),
                style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7, 5])
              )
          }
      )
      .scaleEffect(isTargeted && !reduceMotion ? 1.015 : 1)
      .animation(
        reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
        value: isTargeted
      )
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .onDrop(
        of: [
          UTType.fileURL.identifier,
          UTType.url.identifier,
          UTType.utf8PlainText.identifier,
          UTType.plainText.identifier,
        ],
        isTargeted: $isTargeted
      ) { providers in
        store.acceptDrop(providers)
        return true
      }
      .contextMenu {
        if !store.items.isEmpty {
          Button(utilityLocalized("Clear Shelf"), role: .destructive) {
            store.removeAll()
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        if store.isLoading {
          ProgressView()
            .controlSize(.small)
            .padding(8)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(8)
        }
      }

      if store.lastError != nil {
        Label(utilityLocalized("Shelf could not be saved"), systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.orange.opacity(0.9))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      VelnorrShareAnchorView { view in
        shareAnchor = view
      }
    }
  }

  private var shelfHeader: some View {
    HStack(spacing: 6) {
      Image(systemName: "tray.full")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white.opacity(0.58))
      Text(utilityLocalized("Shelf"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white.opacity(0.72))
      Spacer(minLength: 0)
      Text("\(store.items.count) / \(min(VelnorrShelfStore.itemLimit, max(VelnorrShelfStore.minimumItemLimit, maximumItems)))")
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.38))
        .monospacedDigit()
        .accessibilityLabel(utilityLocalized("Saved items"))
    }
    .frame(minHeight: 18)
  }
}

private struct VelnorrShelfShareCard: View {
  @ObservedObject var actions: VelnorrShelfActionService
  let shareAnchor: NSView?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isTargeted = false
  @State private var isHovered = false

  var body: some View {
    Button(action: { actions.chooseFilesAndShare(from: shareAnchor) }) {
      HStack(spacing: 8) {
        Image(systemName: isTargeted ? "square.and.arrow.up.fill" : "square.and.arrow.up")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isTargeted ? Color.accentColor : .white.opacity(0.72))
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 1) {
          Text(utilityLocalized("Quick Share"))
            .font(.system(size: 11, weight: .semibold))
          Text(utilityLocalized("Drop to share or click to choose"))
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
        }
        Spacer(minLength: 0)
        if actions.isSharing {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.38))
        }
      }
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: VelnorrUtilityLayout.shelfShareHeight, alignment: .leading)
    }
    .buttonStyle(VelnorrUtilityActionButtonStyle())
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(
          isTargeted
            ? Color.accentColor.opacity(0.14)
            : isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.05)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(
              isTargeted
                ? Color.accentColor.opacity(0.75)
                : isHovered ? .white.opacity(0.16) : .white.opacity(0.09),
              lineWidth: 1
            )
        }
    )
    .scaleEffect(isTargeted && !reduceMotion ? 1.01 : 1)
    .animation(
      reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
      value: isTargeted
    )
    .animation(
      reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
      value: isHovered
    )
    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .onHover { isHovered = $0 }
    .onDrop(
      of: [
        UTType.fileURL.identifier,
        UTType.url.identifier,
        UTType.utf8PlainText.identifier,
        UTType.plainText.identifier,
      ],
      isTargeted: $isTargeted
    ) { providers in
      actions.shareDropped(providers, from: shareAnchor)
      return true
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(utilityLocalized("Quick Share"))
    .accessibilityHint(utilityLocalized("Drop to share or click to choose"))
  }
}

private struct VelnorrShelfItemCard: View {
  let item: VelnorrShelfItem
  @ObservedObject var store: VelnorrShelfStore
  let actions: VelnorrShelfActionService
  let shareAnchor: NSView?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovered = false

  var body: some View {
    Button(action: { store.open(item) }) {
      VStack(spacing: 4) {
        Image(nsImage: store.icon(for: item))
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .frame(
            width: VelnorrUtilityLayout.shelfItemIconSize,
            height: VelnorrUtilityLayout.shelfItemIconSize
          )
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
        Text(item.displayName)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white.opacity(0.88))
          .lineLimit(2)
          .truncationMode(.middle)
          .multilineTextAlignment(.center)
          .frame(
            width: VelnorrUtilityLayout.shelfItemWidth - 16,
            height: VelnorrUtilityLayout.shelfItemNameHeight,
            alignment: .top
          )
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 8)
      .frame(
        width: VelnorrUtilityLayout.shelfItemWidth,
        height: VelnorrUtilityLayout.shelfItemHeight
      )
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isHovered ? Color.white.opacity(0.11) : Color.white.opacity(0.055))
          .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(isHovered ? .white.opacity(0.18) : .white.opacity(0.04), lineWidth: 1)
          }
      )
      .scaleEffect(isHovered ? 1.03 : 1)
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .onDrag { store.dragProvider(for: item) }
    .contextMenu {
      Button(utilityLocalized("Open")) { store.open(item) }
      Button(utilityLocalized("Preview")) {
        actions.preview(item, using: store)
      }
      .disabled(!canPreview)
      Button(utilityLocalized("Share")) {
        actions.share(item, using: store, from: shareAnchor)
      }
      if isFile {
        Button(utilityLocalized("Show in Finder")) {
          actions.reveal(item, using: store)
        }
        Button(utilityLocalized("Copy Path")) {
          actions.copyPath(item, using: store)
        }
      }
      Button(utilityLocalized("Remove"), role: .destructive) { store.remove(item) }
    }
    .animation(
      reduceMotion ? .easeOut(duration: 0.1) : VelnorrAnimation.control,
      value: isHovered
    )
    .accessibilityLabel(item.displayName)
  }

  private var isFile: Bool {
    if case .file = item.kind { return true }
    return false
  }

  private var canPreview: Bool {
    switch item.kind {
    case .file, .link: return true
    case .text: return false
    }
  }
}

private struct VelnorrMirrorPanel: View {
  @ObservedObject var store: VelnorrCameraStore
  @AppStorage(AppSettings.mirrorShape) private var mirrorShape = VelnorrMirrorShape.roundedRectangle.rawValue

  var body: some View {
    ZStack {
      if let previewLayer = store.previewLayer, store.isRunning {
        mirrorClipped(
          VelnorrCameraPreviewLayerView(previewLayer: previewLayer)
            .scaleEffect(x: -1, y: 1)
        )
      } else {
        mirrorClipped(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay {
              VStack(spacing: 6) {
                Image(systemName: !store.isAvailable
                  ? "video.slash"
                  : store.authorizationStatus == .denied
                    ? "exclamationmark.triangle"
                    : "video")
                  .font(.system(size: 23, weight: .medium))
                  .foregroundStyle(.white.opacity(0.42))
                if !store.isAvailable {
                  Text(utilityLocalized("No camera available"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                } else {
                  Button(
                    store.authorizationStatus == .denied
                      ? utilityLocalized("Open Camera Settings")
                      : utilityLocalized("Enable Mirror"),
                    action: store.requestAccessAndStart
                  )
                  .buttonStyle(.borderedProminent)
                  .controlSize(.small)
                }
              }
            }
        )
      }
    }
    .onAppear { store.start() }
    .onDisappear { store.stop() }
  }

  @ViewBuilder
  private func mirrorClipped<Content: View>(_ content: Content) -> some View {
    if VelnorrMirrorShape(rawValue: mirrorShape) == .circle {
      content.clipShape(Circle())
    } else {
      content.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }
}

private struct VelnorrCameraPreviewLayerView: NSViewRepresentable {
  let previewLayer: AVCaptureVideoPreviewLayer

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    view.wantsLayer = true
    view.layer = previewLayer
    previewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    previewLayer.frame = nsView.bounds
    CATransaction.commit()
  }
}

private struct VelnorrShareAnchorView: NSViewRepresentable {
  let onReady: (NSView) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    DispatchQueue.main.async {
      onReady(view)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    // The first layout pass supplies the stable anchor. Re-publishing it on
    // every update would turn a picker presentation into a SwiftUI update loop.
  }
}

private func utilityLocalized(_ key: String) -> String {
  AppLanguage.selected.localized(key)
}
