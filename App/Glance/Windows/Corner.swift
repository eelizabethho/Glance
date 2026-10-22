import CoreGraphics

/// A screen corner the ball snaps to. The raw value is what `UserDefaults` stores.
enum Corner: String {
  case topLeft, topRight, bottomLeft, bottomRight

  var isTop: Bool { self == .topLeft || self == .topRight }
  var isRight: Bool { self == .topRight || self == .bottomRight }

  static func nearest(to point: CGPoint, in rect: CGRect) -> Corner {
    switch (point.y >= rect.midY, point.x >= rect.midX) {
    case (true, true): .topRight
    case (true, false): .topLeft
    case (false, true): .bottomRight
    case (false, false): .bottomLeft
    }
  }

  /// The origin that puts a window of `size` into this corner of `rect`.
  func origin(for size: CGSize, in rect: CGRect) -> CGPoint {
    CGPoint(
      x: isRight ? rect.maxX - size.width : rect.minX,
      y: isTop ? rect.maxY - size.height : rect.minY)
  }

  /// The origin that hangs a panel of `size` off `ball`, toward the middle of the screen.
  func panelOrigin(for size: CGSize, beside ball: CGRect) -> CGPoint {
    CGPoint(
      x: isRight ? ball.maxX - size.width : ball.minX,
      y: isTop ? ball.minY - size.height : ball.maxY)
  }
}
