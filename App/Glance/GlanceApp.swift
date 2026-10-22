import SwiftUI

@main
struct GlanceApp: App {
  var body: some Scene {
    WindowGroup {
      Text("0")
        .font(.system(size: 16, weight: .medium))
        .frame(width: 56, height: 56)
        .glassEffect(.regular, in: .circle)
        .padding(40)
    }
    .windowResizability(.contentSize)
  }
}
