import SwiftUI
import WidgetKit

/// The Lyrics card: the active line big and bright, the previous line faded, the next line(s) dimmer.
struct LyricsCardView: View {
    @Environment(\.cardLook) private var look
    @Environment(\.widgetRenderingMode) private var renderingMode
    let summary: LyricsSummary
    let size: CardSize

    private var accent: Color {
        if let hex = summary.accentHex { return Color(hex: hex) }
        return look == .neon ? CardPaint(source: .lyrics).color(.neon) : .white
    }

    private var scale: Double { min(max(summary.textScale, 0.7), 1.4) }

    var body: some View {
        switch summary.mode {
        case .idle:
            EmptyCard(source: .lyrics, hint: "Play something in Apple Music")
        case .songOnly(let note):
            VStack(alignment: .leading, spacing: 3) {
                header
                Spacer(minLength: 0)
                Text(summary.title ?? "--")
                    .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                if let artist = summary.artist, !artist.isEmpty {
                    Text(artist).font(Theme.label(14)).foregroundStyle(Theme.primaryText.opacity(0.75)).lineLimit(1)
                }
                Text(note).font(Theme.label(12)).foregroundStyle(accent).lineLimit(1)
            }
        case .synced(let window):
            VStack(alignment: .leading, spacing: size == .medium ? 5 : 3) {
                header
                Spacer(minLength: 0)
                if summary.lineCount > 1, let previous = window.previous, !previous.isEmpty {
                    line(previous, size: 14, opacity: 0.38)
                }
                Text(window.current.flatMap { $0.isEmpty ? nil : $0 } ?? "♪")
                    .font(.system(size: (summary.lineCount == 1 ? 26 : 22) * scale * (size == .medium ? 1.1 : 1), weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(summary.lineCount == 1 ? 4 : 3)
                    .minimumScaleFactor(0.55)
                    .widgetAccentable()
                    .neonGlow(look == .neon && renderingMode == .fullColor ? accent : nil, radius: 5)
                ForEach(Array(window.next.prefix(size == .medium ? 3 : 2).enumerated()), id: \.offset) { index, next in
                    line(next.isEmpty ? "♪" : next, size: 14, opacity: index == 0 ? 0.6 : 0.4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .widgetAccentable()
            Text((summary.title ?? "Lyrics").uppercased())
                .font(Theme.label(11))
                .tracking(0.4)
                .foregroundStyle(look == .bold ? Color.white.opacity(0.8) : Theme.secondaryText)
                .lineLimit(1)
        }
    }

    private func line(_ text: String, size: CGFloat, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: size * scale, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.primaryText.opacity(opacity))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
