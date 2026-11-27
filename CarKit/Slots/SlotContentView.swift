import SwiftUI
import UIKit
import WidgetKit

/// The foreground of a slot, shared by the widget and the app's mock CarPlay screen
/// so both look identical.
public struct SlotContentView: View {
    @Environment(\.cardLook) private var look
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
                .accessibilityLabel(designLabel(design))
        case .data(let card):
            DataCardView(card: card, size: isMedium ? .medium : .small)
        case .pictured(let card, let file):
            if let image = UIImage(contentsOfFile: AppGroup.containerURL.appending(path: file, directoryHint: .notDirectory).path(percentEncoded: false)) {
                picturedView(card, image: image)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(card.source.displayName): \(card.compact.label)")
            } else {
                DataCardView(card: card, size: isMedium ? .medium : .small)
            }
        case .studio(let card):
            DesignView(card: card)
        case .panorama(let card, let part):
            PanoramaSlice(card: card, part: part)
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
    private func pictureView(_ design: SlotDesign, image: UIImage, labelColor: Color, valueColor: Color = Theme.primaryText, glow: Color? = nil) -> some View {
        let hasText = !design.value.trimmingCharacters(in: .whitespaces).isEmpty || !design.title.trimmingCharacters(in: .whitespaces).isEmpty
        let align = Self.alignment(design.textAlignment)
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
                VStack(alignment: align.horizontal, spacing: 2) {
                    valueText(design.value, size: 40 * design.clampedValueScale, color: valueColor, glow: glow)
                    labelText(design.title, color: labelColor, size: 13 * design.clampedLabelScale)
                }
                .frame(maxWidth: .infinity, alignment: align.frame)
            }
        } else {
            VStack(alignment: align.horizontal, spacing: 2) {
                picture
                valueText(design.value, size: 28 * design.clampedValueScale, color: valueColor, glow: glow)
                labelText(design.title, color: labelColor, size: 13 * design.clampedLabelScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align.frame)
        }
    }

    @ViewBuilder
    private func designView(_ design: SlotDesign) -> some View {
        let darkText = look == .bold && design.needsDarkText
        let neonColor = design.style == .custom ? design.paint.color(.neon) : CardLook.neon.appTint
        let iconColor: Color = darkText ? Color(hex: 0x111318)
            : (design.style == .accent || look == .bold ? Theme.primaryText : neonColor)
        let labelColor: Color = darkText ? Color(hex: 0x111318).opacity(0.75)
            : (design.style == .accent || (look == .bold && design.style == .custom) ? Theme.primaryText.opacity(0.85) : Theme.secondaryText)
        let valueColor: Color = darkText ? Color(hex: 0x111318) : Theme.primaryText
        let glow: Color? = look == .neon ? neonColor : nil
        let align = Self.alignment(design.textAlignment)
        let vs = design.clampedValueScale, ls = design.clampedLabelScale

        if let url = design.imageURL, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            pictureView(design, image: image, labelColor: labelColor, valueColor: valueColor, glow: glow)
                .multilineTextAlignment(align.text)
        } else if isMedium {
            HStack(spacing: 16) {
                Image(systemName: design.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .widgetAccentable()
                    .neonGlow(glow, radius: 6)
                    .frame(width: 64)
                VStack(alignment: align.horizontal, spacing: 2) {
                    valueText(design.value, size: 46 * vs, color: valueColor, glow: glow)
                    labelText(design.title, color: labelColor, size: 13 * ls)
                }
                .multilineTextAlignment(align.text)
                .frame(maxWidth: .infinity, alignment: align.frame)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: align.horizontal, spacing: 2) {
                Image(systemName: design.symbol)
                    .font(.system(size: look == .bold ? 30 : 26, weight: .bold))
                    .foregroundStyle(iconColor)
                    .widgetAccentable()
                    .neonGlow(glow, radius: 6)
                Spacer(minLength: 0)
                valueText(design.value, size: 36 * vs, color: valueColor, glow: glow)
                labelText(design.title, color: labelColor, size: 13 * ls)
            }
            .multilineTextAlignment(align.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align.frame)
        }
    }

    private func designLabel(_ design: SlotDesign) -> String {
        let text = [design.value, design.title].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let picture = design.imageFile == nil ? [] : [design.imageFile == SlotDesign.myCarImageFile ? "my car picture" : "picture"]
        let parts = text + (text.isEmpty ? picture : [])
        return "Car slot \(slot)" + (parts.isEmpty ? "" : ": " + parts.joined(separator: ", "))
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

    private func valueText(_ value: String, size: CGFloat, color: Color = Theme.primaryText, glow: Color? = nil) -> some View {
        Text(value)
            .font(Theme.number(size, weight: .heavy))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
            .neonGlow(glow, radius: 6)
    }

    /// Horizontal, frame and text alignment for a custom text design.
    static func alignment(_ value: SlotTextAlignment?) -> (horizontal: HorizontalAlignment, frame: Alignment, text: TextAlignment) {
        switch value ?? .leading {
        case .leading: (.leading, .leading, .leading)
        case .center: (.center, .center, .center)
        case .trailing: (.trailing, .trailing, .trailing)
        }
    }

    /// Single slot with a centre picture: label on top, the picture whole in the middle, the
    /// big value at the bottom (small). Medium: picture on the left, label and value on the right.
    @ViewBuilder
    private func picturedView(_ card: DataCard, image: UIImage) -> some View {
        let compact = card.compact
        let accent = look == .neon ? card.paint.color(.neon) : Theme.primaryText
        let header = HStack(spacing: 5) {
            Image(systemName: compact.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
                .widgetAccentable()
                .neonGlow(look == .neon ? accent : nil, radius: 4)
            Text(compact.label.uppercased())
                .font(Theme.label(12))
                .foregroundStyle(look == .bold ? Color.white.opacity(0.85) : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        let picture = Image(uiImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        let value = compactValueText(compact.value)
            .font(Theme.number(isMedium ? 38 : 28, weight: .heavy))
            .foregroundStyle(compact.urgency == .ok || look == .bold ? Theme.primaryText : compact.urgency.color())
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .widgetAccentable()
            .neonGlow(look == .neon ? accent : nil, radius: 6)
        if isMedium {
            HStack(spacing: 12) {
                picture
                VStack(alignment: .leading, spacing: 4) {
                    header
                    Spacer(minLength: 0)
                    value
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 3) {
                header.frame(maxWidth: .infinity, alignment: .leading)
                picture
                value.frame(maxWidth: .infinity)
            }
        }
    }

    private func compactValueText(_ value: CompactValue) -> Text {
        switch value {
        case .text(let text): Text(text)
        case .timer(let date): Text.countdown(to: date)
        case .relative(let date): Text(date, style: .relative)
        }
    }

    private func labelText(_ title: String, color: Color, size: CGFloat = 13) -> some View {
        Text(title.uppercased())
            .font(Theme.label(size))
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
            } else if case .panorama(let card, let part) = content {
                PanoramaSlice(card: card, part: part)
            } else {
                SlotContentView(slot: slot, content: content, isMedium: isMedium)
                    .padding(content.isCards ? 7 : 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(WidgetCardBackground(style: content.cardStyle, paint: content.paint))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
