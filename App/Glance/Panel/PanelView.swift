import SwiftUI

/// Placeholder list until T3 builds the real panel.
struct PanelView: View {
  let state: AppState

  var body: some View {
    List(state.document.categories, id: \.name) { category in
      Section(category.name) {
        ForEach(category.tasks) { Text($0.text) }
      }
    }
  }
}
