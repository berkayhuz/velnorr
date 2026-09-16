import SwiftUI

@main
struct VelnorrApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    if #available(macOS 15.0, *) {
      Settings {
        VelnorrSettingsView(runtime: appDelegate.runtime)
      }
      .defaultLaunchBehavior(.suppressed)
      .restorationBehavior(.disabled)
    }
  }
}
