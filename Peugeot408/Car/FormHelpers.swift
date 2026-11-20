import CarKit
import SwiftUI

/// Text-backed number entry, so fields can be left empty (optional values) without fighting formatters.
enum NumberText {
    static func int(_ text: String) -> Int? {
        let digits = text.filter { $0.isNumber || $0 == "-" }
        return Int(digits)
    }

    static func double(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "RM", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    static func string(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    static func string(_ value: Double?, decimals: Int = 2) -> String {
        guard let value else { return "" }
        return String(format: "%.\(decimals)f", value)
    }
}

struct NumberField: View {
    let title: String
    @Binding var text: String
    var unit: String = ""
    var decimal: Bool = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(unit.isEmpty ? title : unit, text: $text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
            if !unit.isEmpty {
                Text(unit).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

/// Small coloured status capsule used in the lists.
struct UrgencyBadge: View {
    let text: String
    let urgency: Urgency

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(urgency == .ok ? Theme.primaryText : Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(urgency.color(fallback: Theme.surface)))
    }
}

/// The card as it looks on the head unit, at the top of each data screen.
struct CardPreviewSection: View {
    let card: DataCard

    var body: some View {
        Section {
            HStack(spacing: 12) {
                DataCardTile(card: card)
                    .frame(width: 140, height: 140)
                DataCardTile(card: card, size: .medium)
                    .frame(height: 140)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            .listRowBackground(Color.clear)
        } footer: {
            Text("This is how the widget looks in the car. Assign it to a slot on the Slots tab, or add the widget on its own.")
        }
    }
}
