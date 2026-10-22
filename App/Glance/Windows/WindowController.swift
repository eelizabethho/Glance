import AppKit
import SwiftUI

/// Borderless panels refuse key status by default. The list panel opts in so its text field can
/// take typing; the ball never does, so it never steals focus.
final class GlancePanel: NSPanel {
  var keyable = false
  override var canBecomeKey: Bool { keyable }
  override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.2 }
}

/// Drags its window with the mouse and reports moves and the drop.
final class DragHostingView<Content: View>: NSHostingView<Content> {
  var onMove: () -> Void = {}
  var onDrop: () -> Void = {}
  private var start: (mouse: CGPoint, origin: CGPoint)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    start = (NSEvent.mouseLocation, window?.frame.origin ?? .zero)
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start else { return }
    let mouse = NSEvent.mouseLocation
    window?.setFrameOrigin(
      CGPoint(
        x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y)
    )
    onMove()
  }

  override func mouseUp(with event: NSEvent) {
    start = nil
    onDrop()
  }
}

/// Owns the ball and list panels and runs `HoverMachine` between them.
final class WindowController: NSObject, NSWindowDelegate {
  /// Invisible hit area around each panel's content, so crossing from ball to list never leaves.
  static let buffer: CGFloat = 6
  static let cornerKey = "ballCorner"
  static let fadeOpacityKey = "fadeOpacity"
  static let fadeDelayKey = "fadeDelay"

  private let defaults: UserDefaults
  private let ball: GlancePanel
  private let list: GlancePanel
  private let model = ListPanelModel()
  private var ballArea: NSTrackingArea?
  private var machine = HoverMachine()
  private var timerTask: Task<Void, Never>?
  private var overBall = false
  private var overList = false

  init(state: AppState, defaults: UserDefaults = .standard) {
    defaults.register(defaults: [Self.fadeOpacityKey: 0.3, Self.fadeDelayKey: 0.6])
    self.defaults = defaults
    let ballView = DragHostingView(rootView: BallView(state: state).padding(Self.buffer).hitArea())
    ball = Self.panel(
      ballView, size: CGSize(width: 56 + 2 * Self.buffer, height: 56 + 2 * Self.buffer))
    let listView = NSHostingView(rootView: ListPanelContent(state: state, model: model))
    let size = ListPanelContent.size
    list = Self.panel(
      listView,
      size: CGSize(width: size.width + 2 * Self.buffer, height: size.height + 2 * Self.buffer))
    super.init()

    ball.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
    list.keyable = true
    list.setAccessibilityLabel("Glance list")
    list.becomesKeyOnlyIfNeeded = true  // only a click in the text field takes focus
    list.delegate = self
    ballView.onMove = { [weak self] in self?.placeList() }
    ballView.onDrop = { [weak self] in self?.snap() }
    ballArea = track(ballView)
    track(listView)

    let corner = defaults.string(forKey: Self.cornerKey).flatMap(Corner.init) ?? .topRight
    ball.setFrameOrigin(corner.origin(for: ball.frame.size, in: Self.screenRect(NSScreen.main)))
    ball.orderFrontRegardless()
  }

  private static func panel(_ view: NSView, size: CGSize) -> GlancePanel {
    let panel = GlancePanel(
      contentRect: CGRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.contentView = view
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    return panel
  }

  private static func screenRect(_ screen: NSScreen?) -> CGRect {
    (screen?.visibleFrame ?? .zero).insetBy(dx: 4, dy: 4)
  }

  private static var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  // MARK: Ball position

  private var corner: Corner {
    Corner.nearest(
      to: CGPoint(x: ball.frame.midX, y: ball.frame.midY), in: Self.screenRect(ball.screen))
  }

  private func placeList() {
    model.corner = corner
    list.setFrameOrigin(corner.panelOrigin(for: list.frame.size, beside: ball.frame))
  }

  private func snap() {
    let corner = corner
    defaults.set(corner.rawValue, forKey: Self.cornerKey)
    let origin = corner.origin(for: ball.frame.size, in: Self.screenRect(ball.screen))
    // animator().setFrame on this panel traps inside AppKit on macOS 26; the built-in move doesn't.
    ball.setFrame(
      CGRect(origin: origin, size: ball.frame.size), display: true, animate: !Self.reduceMotion)
    placeList()
  }

  // MARK: Hover

  @discardableResult private func track(_ view: NSView) -> NSTrackingArea {
    let area = NSTrackingArea(
      rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
    view.addTrackingArea(area)
    return area
  }

  @objc(mouseEntered:) func mouseEntered(with event: NSEvent) { hover(event.trackingArea, true) }
  @objc(mouseExited:) func mouseExited(with event: NSEvent) { hover(event.trackingArea, false) }

  private func hover(_ area: NSTrackingArea?, _ isInside: Bool) {
    let wasInside = overBall || overList
    if area === ballArea { overBall = isInside } else { overList = isInside }
    let inside = overBall || overList
    if inside != wasInside { send(inside ? .enter : .leave) }
  }

  func windowDidBecomeKey(_ notification: Notification) { send(.focus(true)) }
  func windowDidResignKey(_ notification: Notification) { send(.focus(false)) }

  private func send(_ event: HoverMachine.Event) {
    let old = machine
    machine.send(event)
    if machine.state != old.state { show(machine.state, from: old.state) }
    if machine.timer != old.timer { schedule(machine.timer) }
  }

  /// One sleeping task at a time, so idle costs no CPU.
  private func schedule(_ timer: HoverMachine.Timer?) {
    timerTask?.cancel()
    guard let timer else { return }
    let delay =
      switch timer {
      case .open: 0.12
      case .fade: defaults.double(forKey: Self.fadeDelayKey)
      case .collapse: 0.4
      }
    timerTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      self?.send(.timerFired)
    }
  }

  private func show(_ state: HoverMachine.State, from old: HoverMachine.State) {
    switch state {
    case .expanded where old == .collapsed:
      placeList()
      list.alphaValue = 1
      list.orderFrontRegardless()
      withAnimation(Self.reduceMotion ? nil : .easeOut(duration: 0.18)) { model.shown = true }
    case .expanded: fade(to: 1, over: 0.18)
    case .faded: fade(to: defaults.double(forKey: Self.fadeOpacityKey), over: 0.4)
    case .collapsed:
      model.shown = false
      list.orderOut(nil)
    }
  }

  private func fade(to alpha: Double, over duration: Double) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      list.animator().alphaValue = alpha
    }
  }
}
