import SwiftUI
import UIKit
import WidgetKit

// MARK: - Photo Frame

struct PhotoCard: View {
    let summary: PhotoSummary
    let size: CardSize

    var body: some View {
        if let path = summary.imagePath, let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(summary.albumName.map { "Photo from \($0)" } ?? "Photo")
        } else {
            EmptyCard(source: .photos, hint: "Add photos in the app")
        }
    }
}

// MARK: - Music

/// Artwork, title and subtitle. Playback buttons (iPhone only) are added by the widget on top.
public struct MusicCardView: View {
    let summary: MusicSummary
    let size: CardSize

    public init(summary: MusicSummary, size: CardSize) {
        self.summary = summary
        self.size = size
    }

    public var body: some View {
        if let title = summary.title {
            if size == .medium {
                HStack(spacing: 12) {
                    artwork
                        .aspectRatio(1, contentMode: .fit)
                    VStack(alignment: .leading, spacing: 3) {
                        CardHeader(symbol: "music.note", title: summary.kindLabel, color: Theme.accent)
                        Spacer(minLength: 0)
                        Text(title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .widgetAccentable()
                        if let subtitle = summary.subtitle {
                            SmallLine(text: subtitle)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            } else {
                ZStack(alignment: .bottomLeading) {
                    artwork
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let subtitle = summary.subtitle {
                            Text(subtitle)
                                .font(Theme.label(11))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
                }
            }
        } else {
            EmptyCard(source: .music, hint: "Set up Music in the app")
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let path = summary.artworkPath, let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        } else {
            // Original placeholder art: accent gradient with a note.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent, Theme.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.primaryText.opacity(0.85))
                }
                .accessibilityHidden(true)
        }
    }
}
