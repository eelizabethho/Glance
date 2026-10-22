import SwiftUI

/// Liquid Glass in `shape`, or a solid fill when Reduce Transparency is on.
struct GlassBackground<S: Shape>: ViewModifier {
  let shape: S
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(.background, in: shape)
    } else {
      content.glassEffect(.regular, in: shape)
    }
  }
}
