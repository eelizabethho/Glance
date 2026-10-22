/// The list panel's hover logic: collapsed → expanded → faded → collapsed.
/// Pure state; `WindowController` runs the one timer it asks for and reports `.timerFired`.
struct HoverMachine: Equatable {
  enum State { case collapsed, expanded, faded }
  enum Event: Equatable {
    case enter, leave
    /// Expand now (the global shortcut), skipping the enter delay.
    case summon
    case focus(Bool)
    case timerFired
  }
  /// What the pending timer does when it fires.
  enum Timer {
    case open, fade, collapse

    var target: State {
      switch self {
      case .open: .expanded
      case .fade: .faded
      case .collapse: .collapsed
      }
    }
  }

  private(set) var state = State.collapsed
  /// The timer that should be running now, or nil for none.
  private(set) var timer: Timer?
  private var inside = false
  private var focused = false

  mutating func send(_ event: Event) {
    switch event {
    case .enter: inside = true
    case .leave: inside = false
    case .summon: state = .expanded
    case .focus(let isFocused): focused = isFocused
    case .timerFired: if let timer { state = timer.target }
    }
    let held = inside || focused
    if state == .faded && held { state = .expanded }
    timer =
      switch state {
      case .collapsed: inside ? .open : nil
      case .expanded: held ? nil : .fade
      case .faded: .collapse
      }
  }
}
