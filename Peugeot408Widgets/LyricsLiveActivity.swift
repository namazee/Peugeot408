// Not in the App Store build (spec §10 Build flavours): LRCLIB lyrics are personal-build only.
#if !STORE_BUILD
import ActivityKit
import CarKit
import SwiftUI
import WidgetKit

/// Lyrics as a Live Activity (CarPlay shows it with the `.small` family).
struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            LyricsActivityView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.primaryText)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    LyricsActivityView(title: context.attributes.title, state: context.state)
                }
            } compactLeading: {
                Image(systemName: "quote.bubble.fill").foregroundStyle(Color(hex: ThemeTokens.neon["lyrics"] ?? ThemeTokens.glow))
            } compactTrailing: {
                Text(context.state.current)
                    .font(Theme.label(12))
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            } minimal: {
                Image(systemName: "quote.bubble.fill")
            }
            .widgetURL(DataSource.lyrics.deepLink)
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}
#endif
