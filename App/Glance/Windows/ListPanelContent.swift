import SwiftUI

/// What the list panel's SwiftUI content needs from `WindowController`.
@Observable final class ListPanelModel {
  var shown = false
  var corner = Corner.topRight
}

/// Hosts T3's `PanelView` in a glass card that grows out of the ball's corner.
struct ListPanelContent: View {
  static let size = CGSize(width: 340, height: 520)

  let state: AppState
  let model: ListPanelModel
  @AppStorage("clearGlass") private var clearGlass = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 18)
    ZStack {
      if model.shown {
        PanelView(state: state)
          .scrollContentBackground(.hidden)
          .clipShape(shape)
          .modifier(GlassBackground(shape: shape, clear: clearGlass))
          .transition(.scale(scale: 0.15, anchor: anchor).combined(with: .opacity))
      }
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .padding(WindowController.buffer)
    .hitArea()
  }

  private var anchor: UnitPoint {
    switch model.corner {
    case .topLeft: .topLeading
    case .topRight: .topTrailing
    case .bottomLeft: .bottomLeading
    case .bottomRight: .bottomTrailing
    }
  }
}

extension View {
  /// The window server skips fully clear pixels, so the buffer gets a fill too faint to see.
  func hitArea() -> some View { background(Color.black.opacity(0.001)) }
}
