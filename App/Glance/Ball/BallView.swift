import SwiftUI

struct BallView: View {
  let state: AppState

  var body: some View {
    Text("\(state.todoCount)")
      .font(.custom("JetBrainsMono-Regular", size: 16))
      .frame(width: 56, height: 56)
      .modifier(GlassBackground(shape: Circle()))
  }
}
