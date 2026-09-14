import SwiftUI

@main
struct VelnorrApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      VelnorrSettingsView()
    }
  }
}
