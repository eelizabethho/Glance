import Foundation
import GlanceCore
import Testing

@testable import Glance

struct LinkifiedTests {
  @Test func urlBecomesLinkRun() {
    let result = linkified("see https://example.com/conf")
    #expect(result.runs.contains { $0.link == URL(string: "https://example.com/conf") })
    #expect(linkified("no links").runs.allSatisfy { $0.link == nil })
  }
}
