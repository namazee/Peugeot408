// Not in the App Store build (spec §10 Build flavours): LRCLIB lyrics are personal-build only.
#if !STORE_BUILD
import ActivityKit
import SwiftUI
import WidgetKit

/// The Lyrics Live Activity (Phase 13). The app updates it line by line while it's running
/// (Live Activities can't change text on their own); the widget timeline covers the rest.
public struct LyricsActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var previous: String?
        public var current: String
        public var next: String?

        public init(previous: String?, current: String, next: String?) {
            self.previous = previous
            self.current = current
            self.next = next
        }
    }

    public var title: String
    public var artist: String

    public init(title: String, artist: String) {
        self.title = title
        self.artist = artist
    }
}

public struct LyricsActivityView: View {
    let title: String
    let state: LyricsActivityAttributes.ContentState

    public init(title: String, state: LyricsActivityAttributes.ContentState) {
        self.title = title
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "quote.bubble.fill")
                .font(Theme.label(12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            if let previous = state.previous, !previous.isEmpty {
                Text(previous).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
            }
            Text(state.current.isEmpty ? "♪" : state.current)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: ThemeTokens.neon["lyrics"] ?? ThemeTokens.glow))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if let next = state.next, !next.isEmpty {
                Text(next).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
