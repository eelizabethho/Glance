import SwiftUI

struct BallView: View {
  let state: AppState

  var body: some View {
    Text("\(state.todoCount)")
      .font(.system(size: 16, weight: .medium))
      .frame(width: 56, height: 56)
      .glassEffect(.regular, in: .circle)
  }
}
