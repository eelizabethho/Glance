import ServiceManagement
import SwiftUI

@main
struct GlanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @Environment(\.openSettings) private var openSettings

  // The ball and list are panels made at launch; the menu bar and Settings are the only scenes.
  var body: some Scene {
    MenuBarExtra("Glance", systemImage: "checklist") {
      Button(delegate.windows?.hidden == true ? "Show Glance" : "Hide Glance") {
        delegate.windows?.toggleVisible()
      }
      Button("Open List") { delegate.windows?.summon() }
      LaunchAtLoginToggle()
      Button("Settings…") {
        NSApp.activate()
        openSettings()
      }
      Button("Quit Glance") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
    Settings { EmptyView() }
  }
}

/// Backed by `SMAppService.mainApp`; a failed register or unregister shows in the label.
struct LaunchAtLoginToggle: View {
  @State private var enabled = SMAppService.mainApp.status == .enabled
  @State private var error: String?

  var body: some View {
    Toggle(
      error ?? "Launch at Login",
      isOn: Binding(
        get: { enabled },
        set: { wanted in
          do {
            if wanted {
              try SMAppService.mainApp.register()
            } else {
              try SMAppService.mainApp.unregister()
            }
            error = nil
          } catch {
            self.error = error.localizedDescription
          }
          enabled = SMAppService.mainApp.status == .enabled
        }))
  }
}

@Observable final class AppDelegate: NSObject, NSApplicationDelegate {
  private(set) var windows: WindowController?
  private var hotKey: HotKey?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let windows = WindowController(state: AppState())
    self.windows = windows
    hotKey = HotKey { windows.summon() }
  }
}
