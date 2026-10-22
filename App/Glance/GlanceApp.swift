import SwiftUI

@main
struct GlanceApp: App {
  @State private var state = AppState()

  var body: some Scene {
    WindowGroup {
      BallView(state: state)
        .padding(40)
    }
    .windowResizability(.contentSize)
  }
}
