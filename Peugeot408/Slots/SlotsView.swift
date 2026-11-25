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
                    Text("This is your car screen. Tap a slot (or one card in it) to change what it shows. Slots 4 and 5 sit behind the columns (Smart Rotate). CarPlay may take a moment to redraw; reconnecting the phone redraws it fastest.")
                }

                if let undo = slots.state.undoSetup {
                    Section {
                        Button {
                            slots.undoSetup()
                        } label: {
                            Label("Undo setup (\(undo.setupName))", systemImage: "arrow.uturn.backward.circle")
                        }
                    } footer: {
                        Text("Brings back what your five slots showed before you applied \(undo.setupName).")
                    }
                }

                Section {
                    NavigationLink {
                        PanoramaView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Panorama hero")
                                Text(slots.state.activePanoramaID != nil ? "On: one picture across Slots 1–3" : "Off")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        } icon: {
                            Image(systemName: "rectangle.split.3x1.fill")
                        }
                    }
                } footer: {
                    Text("Spread one wide design, like your car with big lettering behind it, across the three columns.")
                }

                Section {
                    NavigationLink {
                        SlotsMoreView(editing: $editing)
                    } label: {
                        Label("More options", systemImage: "slider.horizontal.3")
                    }
                } footer: {
                    Text("Change the slot order, or flash each slot's number to see which is which in the car.")
                }

                if let error = slots.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.overdue)
                    }
                }
            }
            .navigationTitle("Slots")
            .sheet(item: $editing) { ref in
                SlotEditorView(slot: ref.slot, initial: slots.design(for: ref.slot), focusCard: ref.card)
            }
        }
    }
}

/// Slots → More options (spec §4b, Phase 20): slot order and the flash test.
struct SlotsMoreView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(StudioModel.self) private var studio
    @Binding var editing: SlotRef?

    var body: some View {
        List {
            Section {
                ForEach(SlotsState.slotNumbers, id: \.self) { number in
                    Button {
                        editing = SlotRef(slot: number)
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
                Text("Shows \"Slot N ✓\" on each slot, or \"Slot N · Top ✓\" / \"Bottom ✓\" on each card, for 10 minutes so you can see which is which in the car.")
            }
        }
        .navigationTitle("More options")
        .toolbar { EditButton() }
    }
}

/// A mock of the CarPlay widget screen showing all five slots with their current designs.
struct MockCarPlayView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @Environment(StudioModel.self) private var studio
    @Environment(\.cardLook) private var appLook
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

                // A wide CarPlay screen: 3 tall columns (Slot 1–3).
                HStack(spacing: 10) {
                    ForEach(1...3, id: \.self) { number in
                        column(number, date: context.date)
                    }
                }
                .padding(.horizontal, 12)

                HStack(spacing: 8) {
                    Text("Behind (Smart Rotate)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(4...5, id: \.self) { number in
                        Button {
                            editing = SlotRef(slot: number)
                        } label: {
                            SlotTile(slot: number, content: content(for: number, at: context.date))
                                .environment(\.cardLook, look(for: number))
                                .frame(width: 64, height: 86)
                                .overlay(alignment: .bottomTrailing) {
                                    Text("\(number)").font(.caption2.bold()).padding(4)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit car slot \(number)")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
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

    /// The slot's own look, or the app-wide one.
    private func look(for number: Int) -> CardLook {
        slots.design(for: number).look ?? appLook
    }

    /// One tall CarPlay column. Split / Quad cards are tappable one by one.
    private func column(_ number: Int, date: Date) -> some View {
        let slotContent = content(for: number, at: date)
        return VStack(spacing: 6) {
            Group {
                if case .cards(let layout, let parts) = slotContent {
                    SlotCardsView(slot: number, layout: layout, parts: parts) { card in
                        editing = SlotRef(slot: number, card: card)
                    }
                    .padding(7)
                    .background(WidgetCardBackground(style: .frame))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    Button {
                        editing = SlotRef(slot: number)
                    } label: {
                        SlotTile(slot: number, content: slotContent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit car slot \(number)")
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .environment(\.cardLook, look(for: number))
            Text("Slot \(number)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func content(for slot: Int, at date: Date) -> SlotContent {
        SlotTimeline.currentContent(slot: slot, state: slots.state, data: cars.data, studio: studio.state, at: date)
    }
}

struct SlotRow: View {
    let number: Int
    let design: SlotDesign
    var studioName: String?

    var body: some View {
        let isAccent = design.source == nil && design.style != .dark
        HStack(spacing: 12) {
            Image(systemName: design.studioDesignID != nil ? "paintpalette.fill" : design.source?.symbol ?? design.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isAccent ? Theme.primaryText : Theme.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(design.style == .custom ? Color(hex: design.backgroundHex ?? Theme.Hex.accent) : (isAccent ? Theme.accent : Theme.surface))
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
