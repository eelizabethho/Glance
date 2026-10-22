import Testing

@testable import Glance

private func expanded() -> HoverMachine {
  var machine = HoverMachine()
  machine.send(.enter)
  machine.send(.timerFired)
  return machine
}

struct HoverMachineTests {
  @Test func enterOpensAfterTheEnterDelay() {
    var machine = HoverMachine()
    machine.send(.enter)
    #expect(machine.state == .collapsed)
    #expect(machine.timer == .open)
    machine.send(.timerFired)
    #expect(machine.state == .expanded)
    #expect(machine.timer == nil)
  }

  @Test func leavingBeforeTheEnterDelayCancelsIt() {
    var machine = HoverMachine()
    machine.send(.enter)
    machine.send(.leave)
    #expect(machine.state == .collapsed)
    #expect(machine.timer == nil)
  }

  @Test func leaveFadesThenCollapses() {
    var machine = expanded()
    machine.send(.leave)
    #expect(machine.state == .expanded)
    #expect(machine.timer == .fade)
    machine.send(.timerFired)
    #expect(machine.state == .faded)
    #expect(machine.timer == .collapse)
    machine.send(.timerFired)
    #expect(machine.state == .collapsed)
    #expect(machine.timer == nil)
  }

  @Test func reenteringBeforeTheFadeKeepsItOpen() {
    var machine = expanded()
    machine.send(.leave)
    machine.send(.enter)
    #expect(machine.state == .expanded)
    #expect(machine.timer == nil)
  }

  @Test func reenteringWhileFadedRestoresIt() {
    var machine = expanded()
    machine.send(.leave)
    machine.send(.timerFired)
    machine.send(.enter)
    #expect(machine.state == .expanded)
    #expect(machine.timer == nil)
  }

  @Test func focusHoldsThePanelOpen() {
    var machine = expanded()
    machine.send(.focus(true))
    machine.send(.leave)
    #expect(machine.state == .expanded)
    #expect(machine.timer == nil)
    machine.send(.focus(false))
    #expect(machine.timer == .fade)
  }

  @Test func aStaleTimerDoesNothing() {
    var machine = HoverMachine()
    machine.send(.timerFired)
    #expect(machine.state == .collapsed)
    #expect(machine.timer == nil)
  }
}
