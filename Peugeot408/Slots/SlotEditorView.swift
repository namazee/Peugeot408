import CarKit
import SwiftUI

/// Slot editor: a live data widget (Phase 2) or a simple text design (big value, short label, icon, background).
struct SlotEditorView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @Environment(StudioModel.self) private var studio
    @Environment(\.dismiss) private var dismiss

    let slot: Int
    @State private var draft: SlotDesign

    init(slot: Int, initial: SlotDesign) {
        self.slot = slot
        _draft = State(initialValue: initial)
    }

    private var valueTooLong: Bool {
        draft.value.count > SlotDesign.maxGlanceableValueLength
    }

    private var canSave: Bool {
        draft.source != nil || draft.studioDesignID != nil || !draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewContent: SlotContent {
        SlotTimeline.content(at: .now, design: draft, rotations: [], seasonal: false, data: cars.data, studio: studio.state)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    HStack(spacing: 12) {
                        SlotTile(slot: slot, content: previewContent)
                            .frame(width: 130, height: 130)
                        SlotTile(slot: slot, content: previewContent, isMedium: true)
                            .frame(height: 130)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ChoicePicker(title: "Shows", choice: primaryChoice, allowsText: true, designs: studio.state.designs)
                } footer: {
                    if draft.studioDesignID != nil {
                        Text("A design from the Studio. Edit it there; the slot follows.")
                    } else if draft.source != nil {
                        Text("Live data from the Car and Daily tabs. The slot updates by itself when the data changes.")
                    }
                }

                if draft.source == nil && draft.studioDesignID == nil {
                    textSections
                }

                rotationSection

                Section {
                    Button("Reset to default", role: .destructive) {
                        draft = .starter(for: slot)
                    }
                }
            }
            .navigationTitle("Car Slot \(slot)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        slots.save(draft, for: slot)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    /// The main choice: text (both nil), a data source, or a Studio design.
    private var primaryChoice: Binding<SlotChoice?> {
        Binding(
            get: { draft.source == nil && draft.studioDesignID == nil ? nil : draft.primaryChoice },
            set: { choice in
                draft.source = choice?.source
                draft.studioDesignID = choice?.studioDesignID
            }
        )
    }

    private var rotations: [SlotRotation] { draft.rotations ?? [] }

    @ViewBuilder
    private var rotationSection: some View {
        Section {
            ForEach(Array(rotations.enumerated()), id: \.element.id) { index, _ in
                VStack(alignment: .leading, spacing: 6) {
                    ChoicePicker(title: "Show", choice: rotationChoice(index), allowsText: false, designs: studio.state.designs)
                    Stepper(value: rotationHour(index, from: true), in: 0...23) {
                        LabeledContent("From", value: String(format: "%02d:00", rotations[index].fromHour))
                    }
                    Stepper(value: rotationHour(index, from: false), in: 0...23) {
                        LabeledContent("Until", value: String(format: "%02d:00", rotations[index].toHour))
                    }
                }
                .swipeActions {
                    Button("Remove", role: .destructive) { draft.rotations?.remove(at: index) }
                }
            }
            if rotations.count < SlotDesign.maxRotations {
                Button {
                    var list = rotations
                    list.append(SlotRotation(choice: SlotChoice(source: .prayer), fromHour: 18, toHour: 21))
                    draft.rotations = list
                } label: {
                    Label("Add a timed design", systemImage: "clock.arrow.2.circlepath")
                }
            }
        } header: {
            Text("Rotate by time of day")
        } footer: {
            Text("Up to 3 designs per slot: this one, plus up to 2 shown during set hours (e.g. Prayer Times 05:00–07:00 and 18:00–21:00). Changes happen through timeline entries, so no reloads are needed.")
        }
    }

    private func rotationChoice(_ index: Int) -> Binding<SlotChoice?> {
        Binding(
            get: { rotations.indices.contains(index) ? rotations[index].choice : nil },
            set: { choice in
                guard let choice, draft.rotations?.indices.contains(index) == true else { return }
                draft.rotations?[index].choice = choice
            }
        )
    }

    private func rotationHour(_ index: Int, from: Bool) -> Binding<Int> {
        Binding(
            get: { rotations.indices.contains(index) ? (from ? rotations[index].fromHour : rotations[index].toHour) : 0 },
            set: { value in
                guard draft.rotations?.indices.contains(index) == true else { return }
                if from { draft.rotations?[index].fromHour = value } else { draft.rotations?[index].toHour = value }
            }
        )
    }

    @ViewBuilder
    private var textSections: some View {
        Section {
            TextField("Big value", text: $draft.value)
            TextField("Short label", text: $draft.title)
        } header: {
            Text("Text")
        } footer: {
            if valueTooLong {
                Text("Keep the big value to \(SlotDesign.maxGlanceableValueLength) characters or fewer so it stays readable while driving.")
                    .foregroundStyle(Theme.dueSoon)
            } else {
                Text("One big value and a short label read best in the car.")
            }
        }

        Section("Background") {
            Picker("Background", selection: $draft.style) {
                ForEach(SlotStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }

        Section("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(SlotDesign.symbolChoices, id: \.self) { name in
                    Button {
                        draft.symbol = name
                    } label: {
                        Image(systemName: name)
                            .font(.title3)
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(draft.symbol == name ? Theme.accent : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

/// Picks a data widget or a Studio design (and, for the main choice, "Custom text").
struct ChoicePicker: View {
    let title: String
    @Binding var choice: SlotChoice?
    let allowsText: Bool
    let designs: [CardDesign]

    init(title: String, choice: Binding<SlotChoice?>, allowsText: Bool, designs: [CardDesign]) {
        self.title = title
        self._choice = choice
        self.allowsText = allowsText
        self.designs = designs
    }

    var body: some View {
        Picker(title, selection: $choice) {
            if allowsText {
                Text("Custom text").tag(SlotChoice?.none)
            }
            Section("Data widgets") {
                ForEach(DataSource.allCases) { source in
                    Label(source.displayName, systemImage: source.symbol).tag(SlotChoice?.some(SlotChoice(source: source)))
                }
            }
            if !designs.isEmpty {
                Section("Studio designs") {
                    ForEach(designs) { design in
                        Label(design.name, systemImage: "paintpalette").tag(SlotChoice?.some(SlotChoice(studioDesignID: design.id)))
                    }
                }
            }
        }
    }
}
