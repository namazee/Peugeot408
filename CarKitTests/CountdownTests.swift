import Foundation
import Testing
@testable import CarKit

/// Prayer and iftar countdowns stop at 0:00 instead of counting up (spec §4 item 6).
struct CountdownTests {
    let target = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func countsDownBeforeTheTarget() {
        let now = target.addingTimeInterval(-90)
        #expect(Countdown.range(to: target, now: now) == now...target)
    }

    @Test func emptyRangeOnceTheTargetHasPassed() {
        let range = Countdown.range(to: target, now: target.addingTimeInterval(45))
        #expect(range.lowerBound == target && range.upperBound == target)
    }
}
