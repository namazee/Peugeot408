import CarKit
import SwiftUI

struct SlotsView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(StudioModel.self) private var studio
    @Binding var editing: SlotRef?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MockCarPlayView(editing: $editing)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("Tap a slot to change it. CarPlay may take a moment to redraw; reconnecting the phone redraws it fastest.")
                }

                Section {
                    ForEach(SlotsState.slotNumbers, id: \.self) { number in
                        Button {
                            editing = SlotRef(id: number)
                        } label: {
                            SlotRow(number: number, design: slots.design(for: number), studioName: studio.design(slots.design(for: number).studioDesignID)?.name)
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { source, destination in
                        slots.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Order")
                } footer: {
                    Text("Drag to reorder. The design moves; the widget in the car stays where you put it.")
                }

                Section {
                    FlashControls()
                } header: {
                    Text("Test")
                } footer: {
                    Text("Shows a big \"Slot N ✓\" on each slot for 10 minutes so you can see which is which in the car.")
                }

                if let error = slots.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.overdue)
                    }
                }
            }
            .navigationTitle("Slots")
            .toolbar { EditButton() }
            .sheet(item: $editing) { ref in
                SlotEditorView(slot: ref.id, initial: slots.design(for: ref.id))
            }
        }
    }
}

/// A mock of the CarPlay widget screen showing all five slots with their current designs.
struct MockCarPlayView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @Environment(StudioModel.self) private var studio
    @Binding var editing: SlotRef?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Head unit", systemImage: "car.side")
                    Spacer()
                    Text(context.date, style: .time)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SlotsState.slotNumbers, id: \.self) { number in
                            Button {
                                editing = SlotRef(id: number)
                            } label: {
                                VStack(spacing: 6) {
                                    SlotTile(slot: number, content: content(for: number, at: context.date))
                                        .frame(width: 140, height: 140)
                                    Text("Slot \(number)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit car slot \(number)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08))
                    )
            )
        }
    }

    private func content(for slot: Int, at date: Date) -> SlotContent {
        if slots.state.isFlashing(at: date) { return .flash }
        let design = slots.design(for: slot)
        return SlotTimeline.content(
            at: date,
            design: design,
            rotations: Array((design.rotations ?? []).prefix(SlotDesign.maxRotations)),
            seasonal: studio.state.seasonal.enabled && studio.state.seasonal.slot == slot,
            data: cars.data,
            studio: studio.state
        )
    }
}

struct SlotRow: View {
    let number: Int
    let design: SlotDesign
    var studioName: String?

    var body: some View {
        let isAccent = design.source == nil && design.style == .accent
        HStack(spacing: 12) {
            Image(systemName: design.studioDesignID != nil ? "paintpalette.fill" : design.source?.symbol ?? design.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isAccent ? Theme.primaryText : Theme.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isAccent ? Theme.accent : Theme.surface)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(studioName ?? design.summary).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
    private var subtitle: String {
        var text = "Car Slot \(number)"
        if design.studioDesignID != nil { text += " · Studio" }
        else if design.source != nil { text += " · live data" }
        else { text += " · \(design.title)" }
        let rotations = design.rotations?.count ?? 0
        if rotations > 0 { text += " · +\(rotations) by time" }
        return text
    }
}
}

struct FlashControls: View {
    @Environment(SlotsModel.self) private var slots

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let until = slots.state.flashUntil, until > context.date {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                        Text("Flashing, ends in")
                        Text(until, style: .timer).monospacedDigit()
                    }
                    Button("Stop flash", role: .destructive) { slots.stopFlash() }
                }
            } else {
                Button {
                    slots.flashAll()
                } label: {
                    Label("Test: flash all slots", systemImage: "bolt.fill")
                }
            }
        }
    }
}
