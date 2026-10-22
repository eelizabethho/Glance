import SwiftUI

@main
struct GlanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate

  // The ball and list are panels made at launch; Settings is the only SwiftUI scene.
  var body: some Scene {
    Settings { EmptyView() }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windows: WindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    windows = WindowController(state: AppState())
  }
}
