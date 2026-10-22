import SwiftUI

/// Line-art butterfly: two upper wings, two lower wings, a body, two antennae.
nonisolated struct Butterfly: Shape {
  func path(in rect: CGRect) -> Path {
    func point(_ posX: CGFloat, _ posY: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + posX * rect.width, y: rect.minY + posY * rect.height)
    }
    let mid: CGFloat = 0.5
    var path = Path()
    for side: CGFloat in [-1, 1] {
      let edge = { (off: CGFloat) in mid + side * off }
      // Upper wing
      path.move(to: point(mid, 0.45))
      path.addCurve(
        to: point(mid, 0.5), control1: point(edge(0.2), -0.1), control2: point(edge(0.6), 0.1))
      path.move(to: point(mid, 0.45))
      path.addCurve(
        to: point(mid, 0.55), control1: point(edge(0.55), 0.0), control2: point(edge(0.55), 0.6))
      // Lower wing
      path.move(to: point(mid, 0.55))
      path.addCurve(
        to: point(mid, 0.7), control1: point(edge(0.45), 0.55), control2: point(edge(0.35), 1.05))
      // Antenna
      path.move(to: point(mid, 0.3))
      path.addQuadCurve(to: point(edge(0.2), 0.02), control: point(edge(0.05), 0.1))
    }
    // Body
    path.addEllipse(
      in: CGRect(
        x: rect.midX - 2, y: rect.minY + 0.3 * rect.height, width: 4, height: 0.5 * rect.height))
    return path
  }
}
