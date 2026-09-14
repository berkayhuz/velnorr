import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var velnorrWindows: [VelnorrWindow] = []
  private var screenObserver: NSObjectProtocol?
  private var activeSpaceObserver: NSObjectProtocol?
  private var settingsObserver: NSObjectProtocol?
  private var openSettingsObserver: NSObjectProtocol?
  private var clickMonitors: [Any] = []
  private var appliedSettings: AppSettingsSnapshot?
  private var settingsWindow: NSWindow?
  private var onboardingWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    UserDefaults.standard.register(defaults: AppSettings.defaults)
    appliedSettings = AppSettingsSnapshot()
    applyLaunchAtLogin(appliedSettings?.launchAtLogin ?? true)
    NSApp.setActivationPolicy(.accessory)
    terminateOtherInstances()
    rebuildVelnorrs()

    if !UserDefaults.standard.bool(forKey: AppSettings.onboardingCompleted) {
      DispatchQueue.main.async { [weak self] in
        self?.showOnboardingWindow()
      }
    }

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.rebuildVelnorrs()
      }
    }

    activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.updateVelnorrVisibility()
      }
    }

    settingsObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.applyChangedSettings()
      }
    }

    openSettingsObserver = NotificationCenter.default.addObserver(
      forName: .velnorrOpenSettings,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.showSettingsWindow()
      }
    }

    let dismiss: (NSEvent) -> Void = { [weak self] _ in
      Task { @MainActor [weak self] in
        // A stale passthrough state can briefly route an velnorr click
        // to the app underneath. Never treat a click geometrically
        // inside the velnorr as an outside-click dismissal.
        guard !(self?.velnorrWindows.contains { window in
          window.containsVelnorr(atScreenPoint: NSEvent.mouseLocation)
        } ?? false) else { return }
        NotificationCenter.default.post(name: .velnorrDismiss, object: nil)
      }
    }
    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown],
      handler: dismiss
    ) {
      clickMonitors.append(monitor)
    }
  }

  private func registerLaunchAtLogin() {
    // `swift run` launches the raw executable, not an app bundle. macOS
    // cannot register that executable with SMAppService and returns
    // kSMErrorInvalidArgument; launch-at-login is only meaningful for the
    // packaged Velnorr.app build.
    guard Bundle.main.bundleURL.pathExtension == "app" else { return }
    guard #available(macOS 13.0, *) else { return }
    do {
      if SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
      }
    } catch {
      NSLog("Velnorr could not register for launch at login: \(error.localizedDescription)")
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    if let activeSpaceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
    }
    if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
    if let openSettingsObserver {
      NotificationCenter.default.removeObserver(openSettingsObserver)
    }
    for monitor in clickMonitors {
      NSEvent.removeMonitor(monitor)
    }
    clickMonitors.removeAll()
    velnorrWindows.forEach { $0.close() }
    velnorrWindows.removeAll()
    settingsWindow?.close()
    settingsWindow = nil
    onboardingWindow?.close()
    onboardingWindow = nil
  }

  private func showSettingsWindow() {
    if let settingsWindow {
      NSApp.activate(ignoringOtherApps: true)
      settingsWindow.makeKeyAndOrderFront(nil)
      return
    }

    let hostingController = NSHostingController(rootView: VelnorrSettingsView())
    let window = NSWindow(contentViewController: hostingController)
    let initialSize = NSSize(width: 440, height: 260)
    window.title = AppLanguage.selected.localized("Velnorr Settings")
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.setContentSize(initialSize)
    window.isReleasedWhenClosed = false
    window.center()
    settingsWindow = window

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func showOnboardingWindow() {
    if let onboardingWindow {
      NSApp.activate(ignoringOtherApps: true)
      onboardingWindow.makeKeyAndOrderFront(nil)
      return
    }

    let hostingController = NSHostingController(
      rootView: VelnorrOnboardingView { [weak self] in
        UserDefaults.standard.set(true, forKey: AppSettings.onboardingCompleted)
        self?.onboardingWindow?.close()
        self?.onboardingWindow = nil
      }
    )
    let window = NSWindow(contentViewController: hostingController)
    window.title = AppLanguage.selected.localized("Velnorr Setup")
    window.styleMask = [.titled, .closable]
    window.setContentSize(NSSize(width: 720, height: 760))
    window.contentMinSize = NSSize(width: 720, height: 760)
    window.contentMaxSize = NSSize(width: 720, height: 760)
    window.isReleasedWhenClosed = false
    window.center()
    onboardingWindow = window

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func terminateOtherInstances() {
    guard let currentExecutable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
      return
    }
    let currentPID = ProcessInfo.processInfo.processIdentifier

    for application in NSWorkspace.shared.runningApplications {
      guard application.processIdentifier != currentPID,
        application.executableURL?.resolvingSymlinksInPath() == currentExecutable
      else {
        continue
      }
      application.terminate()
    }
  }

  private func applyChangedSettings() {
    let newSettings = AppSettingsSnapshot()
    guard newSettings != appliedSettings else { return }

    let previousSettings = appliedSettings
    appliedSettings = newSettings

    guard let previousSettings else {
      rebuildVelnorrs()
      return
    }

    if newSettings.externalDisplayMode != previousSettings.externalDisplayMode {
      rebuildVelnorrs()
    } else if newSettings.showInFullscreen != previousSettings.showInFullscreen {
      updateVelnorrVisibility()
    }
    if newSettings.launchAtLogin != previousSettings.launchAtLogin {
      applyLaunchAtLogin(newSettings.launchAtLogin)
    }
    if newSettings.language != previousSettings.language {
      settingsWindow?.title = newSettings.language.localized("Velnorr Settings")
    }
  }

  private func applyLaunchAtLogin(_ enabled: Bool) {
    guard Bundle.main.bundleURL.pathExtension == "app" else { return }
    guard #available(macOS 13.0, *) else { return }
    do {
      if enabled {
        if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
      } else if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      NSLog("Velnorr launch-at-login update failed: \(error.localizedDescription)")
    }
  }

  private func rebuildVelnorrs() {
    velnorrWindows.forEach { $0.close() }
    velnorrWindows.removeAll()

    let settings = appliedSettings ?? AppSettingsSnapshot()
    for screen in NSScreen.screens where shouldShowVelnorr(on: screen) {
      let hasPhysicalNotch = screenHasPhysicalNotch(screen)
      let window = VelnorrWindow(
        screen: screen,
        configuredMode: hasPhysicalNotch ? settings.externalDisplayMode : .pill,
        isFloating: !hasPhysicalNotch
      )
      velnorrWindows.append(window)
      window.orderFrontRegardless()
    }
  }

  private func updateVelnorrVisibility() {
    let settings = appliedSettings ?? AppSettingsSnapshot()
    velnorrWindows.removeAll { window in
      guard let screen = window.screen, shouldShowVelnorr(on: screen) else {
        window.close()
        return true
      }
      window.orderFrontRegardless()
      return false
    }

    // A Space/fullscreen transition can make a previously hidden display
    // eligible without changing the screen list.
    let existingScreens = Set(velnorrWindows.compactMap { $0.screen?.displayID })
    for screen in NSScreen.screens
      where shouldShowVelnorr(on: screen) && !existingScreens.contains(screen.displayID)
    {
      let hasPhysicalNotch = screenHasPhysicalNotch(screen)
      let window = VelnorrWindow(
        screen: screen,
        configuredMode: hasPhysicalNotch ? settings.externalDisplayMode : .pill,
        isFloating: !hasPhysicalNotch
      )
      velnorrWindows.append(window)
      window.orderFrontRegardless()
    }
  }

  private func screenHasPhysicalNotch(_ screen: NSScreen) -> Bool {
    guard let left = screen.auxiliaryTopLeftArea,
      let right = screen.auxiliaryTopRightArea
    else { return false }
    return left.width > 0 && right.width > 0 && right.minX > left.maxX
  }

  private func shouldShowVelnorr(on screen: NSScreen) -> Bool {
    let settings = appliedSettings ?? AppSettingsSnapshot()
    if !settings.showOnExternalDisplays,
      screen != NSScreen.main
    {
      return false
    }
    return settings.showInFullscreen || screen.visibleFrame.height < screen.frame.height - 1
  }
}

private extension NSScreen {
  var displayID: CGDirectDisplayID {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
  }
}
