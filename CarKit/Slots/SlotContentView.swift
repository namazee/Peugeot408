import SwiftUI
import UIKit
import WidgetKit

/// The foreground of a slot, shared by the widget and the app's mock CarPlay screen
/// so both look identical.
public struct SlotContentView: View {
    private let slot: Int
    private let content: SlotContent
    private let isMedium: Bool

    public init(slot: Int, content: SlotContent, isMedium: Bool = false) {
        self.slot = slot
        self.content = content
        self.isMedium = isMedium
    }

    public var body: some View {
        switch content {
        case .design(let design):
            designView(design)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Car slot \(slot): \(design.value), \(design.title)")
        case .data(let card):
            DataCardView(card: card, size: isMedium ? .medium : .small)
        case .studio(let card):
            DesignView(card: card)
        case .flash:
            flashView
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Car slot \(slot) test card")
        case .cards(let layout, let parts):
            SlotCardsView(slot: slot, layout: layout, parts: parts, isMedium: isMedium)
        case .flashCard:
            SlotCardView(slot: slot, content: content, compact: false)
        }
    }

    /// A picture design: the picture whole (fit, never cropped) at the largest size the slot
    /// allows, with the value and label below it (small) or beside it (medium).
    @ViewBuilder
    private func pictureView(_ design: SlotDesign, image: UIImage, labelColor: Color) -> some View {
        let hasText = !design.value.trimmingCharacters(in: .whitespaces).isEmpty || !design.title.trimmingCharacters(in: .whitespaces).isEmpty
        let picture = Image(uiImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        if !hasText {
            picture
        } else if isMedium {
            HStack(spacing: 14) {
                picture
                VStack(alignment: .leading, spacing: 2) {
                    valueText(design.value, size: 40)
                    labelText(design.title, color: labelColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                picture
                valueText(design.value, size: 28)
                labelText(design.title, color: labelColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func designView(_ design: SlotDesign) -> some View {
        let iconColor: Color = design.style == .accent ? Theme.primaryText : Theme.accent
        let labelColor: Color = design.style == .accent ? Theme.primaryText.opacity(0.8) : Theme.secondaryText

        if let url = design.imageURL, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            pictureView(design, image: image, labelColor: labelColor)
        } else if isMedium {
            HStack(spacing: 16) {
                Image(systemName: design.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .widgetAccentable()
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    valueText(design.value, size: 46)
                    labelText(design.title, color: labelColor)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: design.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .widgetAccentable()
                Spacer(minLength: 0)
                valueText(design.value, size: 36)
                labelText(design.title, color: labelColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var flashView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isMedium ? 40 : 32, weight: .bold))
                .widgetAccentable()
            Text("Slot \(slot)")
                .font(Theme.number(isMedium ? 48 : 40, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
        }
        .foregroundStyle(Theme.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func valueText(_ value: String, size: CGFloat) -> some View {
        Text(value)
            .font(Theme.number(size))
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
    }

    private func labelText(_ title: String, color: Color) -> some View {
        Text(title.uppercased())
            .font(Theme.label(13))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// A slot drawn as a self-contained rounded tile, for previews inside the app.
public struct SlotTile: View {
    private let slot: Int
    private let content: SlotContent
    private let isMedium: Bool

    public init(slot: Int, content: SlotContent, isMedium: Bool = false) {
        self.slot = slot
        self.content = content
        self.isMedium = isMedium
    }

    public var body: some View {
        Group {
            if case .studio(let card) = content {
                // Studio designs fill the whole tile, edge to edge, like in the car.
                DesignView(card: card)
            } else {
                SlotContentView(slot: slot, content: content, isMedium: isMedium)
                    .padding(content.isCards ? 7 : 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(WidgetCardBackground(style: content.cardStyle, tint: content.tint))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
