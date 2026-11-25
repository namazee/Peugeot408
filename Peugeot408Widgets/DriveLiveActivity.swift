import ActivityKit
import CarKit
import SwiftUI
import WidgetKit

/// The drive-session Live Activity. CarPlay (iOS 26) shows Live Activities using the `.small`
/// family, so that layout is a compact 2×2 grid of big values.
struct DriveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            DriveActivityView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.primaryText)
        } dynamicIsland: { context in
            let reading = context.state.reading
            let panel = OBDPanel.normalized(context.state.panel)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    OBDTile(value: panel[0], reading: reading, big: 22)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    OBDTile(value: panel[1], reading: reading, big: 22)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        OBDTile(value: panel[2], reading: reading, big: 18)
                        OBDTile(value: panel[3], reading: reading, big: 18)
                        Text(context.state.status)
                            .font(Theme.label(11))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            } compactLeading: {
                Image(systemName: panel[0].symbol).foregroundStyle(Theme.accent)
            } compactTrailing: {
                Text(reading.text(panel[0]))
                    .font(Theme.number(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: "gauge.with.dots.needle.67percent").foregroundStyle(Theme.accent)
            }
            .widgetURL(DataSource.obd.deepLink)
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

struct LiveOBDWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .obd, description: "Last values from your OBD2 drive session, with the time they were read.")
    }
}

#Preview("Live Activity", as: .content, using: DriveActivityAttributes(startedAt: .now, isDemo: true)) {
    DriveLiveActivity()
} contentStates: {
    DriveActivityAttributes.ContentState(reading: OBDDemo.reading(at: .now.addingTimeInterval(13), sessionStart: .now), status: "Demo")
}
