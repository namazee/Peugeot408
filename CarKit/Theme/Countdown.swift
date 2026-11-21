import SwiftUI

/// Live countdowns (spec §4 item 6): they tick down to the target and stop at 0:00 instead of
/// counting up past it, so a card waiting for its next timeline entry never shows "0:01, 0:02…".
public enum Countdown {
    /// The interval `Text(timerInterval:countsDown:)` counts down over. Always valid, even when
    /// the target is already in the past (then it's an empty range at the target: 0:00).
    public static func range(to target: Date, now: Date = .now) -> ClosedRange<Date> {
        min(now, target)...target
    }
}

extension Text {
    /// A live countdown to `target` that stops at 0:00.
    public static func countdown(to target: Date, now: Date = .now) -> Text {
        Text(timerInterval: Countdown.range(to: target, now: now), countsDown: true)
    }
}
