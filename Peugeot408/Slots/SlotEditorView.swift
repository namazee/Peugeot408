import CarKit
import SwiftUI

/// Slot editor: a live data widget (Phase 2) or a simple text design (big value, short label, icon, background).
struct SlotEditorView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @Environment(StudioModel.self) private var studio
    @Environment(AppearanceModel.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    let slot: Int
    let focusCard: Int
    @State private var draft: SlotDesign

    init(slot: Int, initial: SlotDesign, focusCard: Int = 0) {
        self.slot = slot
        self.focusCard = focusCard
        _draft = State(initialValue: initial)
    }

    private var isSplit: Bool { draft.effectiveLayout != .single }

    private var valueTooLong: Bool {
        draft.value.count > SlotDesign.maxGlanceableValueLength
    }

    private var canSave: Bool {
        isSplit || draft.imageFile != nil || draft.source != nil || draft.studioDesignID != nil || !draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewContent: SlotContent {
        SlotTimeline.content(at: .now, design: draft, rotations: [], seasonal: false, data: cars.data, studio: studio.state)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    HStack(spacing: 12) {
                        // As on a 3-column CarPlay screen: a tall column.
                        SlotTile(slot: slot, content: previewContent)
                            .frame(width: 116, height: 160)
                        SlotTile(slot: slot, content: previewContent, isMedium: true)
                            .frame(height: 120)
                    }
                    .environment(\.cardLook, draft.look ?? appearance.look)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                if SlotsState.isPanoramaSlot(slot) && slots.state.activePanoramaID != nil {
                    Section {
                        Label("The Panorama hero is on, so this slot shows its part of the panorama. What you set here comes back when you turn the panorama off (Slots → Panorama hero).", systemImage: "rectangle.split.3x1.fill")
                            .font(.footnote)
                    }
                }

                Section {
                    Picker("Look", selection: $draft.look) {
                        Text("App (\(appearance.look.displayName))").tag(CardLook?.none)
                        ForEach(CardLook.allCases) { Text($0.displayName).tag(CardLook?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Bold: full-colour tiles. Neon: dark tiles with glowing numbers. \"App\" follows Settings → Appearance.")
                }

                Section {
                    Picker("Layout", selection: layout) {
                        ForEach(SlotLayout.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    switch draft.effectiveLayout {
                    case .single: Text("One card fills the column.")
                    case .split: Text("Two cards stacked: icon, short label and one big value each.")
                    case .quad:
                        Label("Quad shows icon + value only, with no labels. It's harder to read while driving; prefer Split for anything you check on the move.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.dueSoon)
                    }
                }

                if isSplit {
                    cardSections
                } else {
                    singleSections
                }

                Section {
                    Button("Reset to default", role: .destructive) {
                        draft = SlotDesign.splitDefault(for: slot) ?? .starter(for: slot)
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

    @ViewBuilder
    private var singleSections: some View {
        Section {
            ChoicePicker(title: "Shows", choice: primaryChoice, allowsText: true, designs: studio.state.designs)
        } footer: {
            if draft.studioDesignID != nil {
                Text("A design from the Studio. Edit it there; the slot follows.")
            } else if draft.source != nil {
                Text("Live data from the Car and Daily tabs. The slot updates by itself when the data changes.")
            }
        }

        if let source = draft.source, ![DataSource.map, .photos, .music].contains(source) {
            Section {
                SlotPicturePicker(imageFile: $draft.centerImageFile, allowsNone: true)
            } header: {
                Text("Centre picture")
            } footer: {
                Text("Adds your car (or any picture) in the middle of this slot, with the label on top and the value at the bottom. \"None\" keeps the normal layout.")
            }
        }

        if draft.source == nil && draft.studioDesignID == nil {
            textSections
        }

        rotationSection
    }

    /// One picker per card; the card that was tapped on the Slots screen is highlighted.
    @ViewBuilder
    private var cardSections: some View {
        let names = draft.effectiveLayout.cardNames
        ForEach(Array(names.enumerated()), id: \.offset) { index, name in
            Section {
                ChoicePicker(title: "Shows", choice: cardChoice(index), allowsText: true, designs: studio.state.designs)
                if draft.card(index).source == nil && draft.card(index).studioDesignID == nil {
                    TextField("Big value (optional)", text: cardText(index, \.value))
                    TextField("Short label (optional)", text: cardText(index, \.title))
                    SlotPicturePicker(imageFile: cardImage(index))
                    Toggle("Own colour", isOn: Binding(
                        get: { draft.card(index).style == .custom },
                        set: { on in updateCard(index) { $0.style = on ? .custom : .dark; if on, $0.backgroundHex == nil { $0.backgroundHex = Theme.Hex.accent } } }
                    ))
                    if draft.card(index).style == .custom {
                        SlotColourPicker(hex: Binding(
                            get: { draft.card(index).backgroundHex ?? Theme.Hex.accent },
                            set: { hex in updateCard(index) { $0.backgroundHex = hex } }
                        ))
                    }
                }
            } header: {
                Text(index == focusCard ? "\(name) card (tapped)" : "\(name) card")
            }
            .listRowBackground(index == focusCard ? Theme.accent.opacity(0.18) : nil)
        }
    }

    private var layout: Binding<SlotLayout> {
        Binding(get: { draft.effectiveLayout }, set: { draft.setLayout($0) })
    }

    private func cardChoice(_ index: Int) -> Binding<SlotChoice?> {
        Binding(
            get: {
                let card = draft.card(index)
                return card.source == nil && card.studioDesignID == nil ? nil : card.primaryChoice
            },
            set: { choice in
                var cards = draft.layoutCards
                guard cards.indices.contains(index) else { return }
                guard let choice else {
                    // Custom text / picture card.
                    cards[index] = SlotDesign(value: "", title: "", symbol: "car.side.fill", imageFile: SlotDesign.myCarImageFile)
                    draft.cards = cards
                    return
                }
                if let source = choice.source {
                    cards[index] = .card(source)
                } else {
                    cards[index].source = nil
                    cards[index].studioDesignID = choice.studioDesignID
                    cards[index].symbol = "paintpalette.fill"
                }
                draft.cards = cards
            }
        )
    }

    private func cardText(_ index: Int, _ keyPath: WritableKeyPath<SlotDesign, String>) -> Binding<String> {
        Binding(
            get: { draft.card(index)[keyPath: keyPath] },
            set: { value in
                var cards = draft.layoutCards
                guard cards.indices.contains(index) else { return }
                cards[index][keyPath: keyPath] = value
                draft.cards = cards
            }
        )
    }

    private func updateCard(_ index: Int, _ change: (inout SlotDesign) -> Void) {
        var cards = draft.layoutCards
        guard cards.indices.contains(index) else { return }
        change(&cards[index])
        draft.cards = cards
    }

    private func cardImage(_ index: Int) -> Binding<String?> {
        Binding(
            get: { draft.card(index).imageFile },
            set: { value in
                var cards = draft.layoutCards
                guard cards.indices.contains(index) else { return }
                cards[index].imageFile = value
                draft.cards = cards
            }
        )
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
            Picker("Align", selection: Binding(get: { draft.textAlignment ?? .leading }, set: { draft.textAlignment = $0 })) {
                ForEach(SlotTextAlignment.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            ScaleSlider(title: "Big value size", value: Binding(get: { draft.clampedValueScale }, set: { draft.valueScale = $0 }))
            ScaleSlider(title: "Label size", value: Binding(get: { draft.clampedLabelScale }, set: { draft.labelScale = $0 }))
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

        Section {
            Picker("Background", selection: $draft.style) {
                ForEach(SlotStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            if draft.style == .custom {
                SlotColourPicker(hex: Binding(get: { draft.backgroundHex ?? Theme.Hex.accent }, set: { draft.backgroundHex = $0 }))
            }
        } header: {
            Text("Background")
        } footer: {
            if draft.style == .custom {
                Text("Bold look: the tile is this colour. Neon look: it's the glow colour on black. The first five are classic car paint colours.")
            }
        }

        Section {
            SlotPicturePicker(imageFile: $draft.imageFile)
        } header: {
            Text("Picture")
        } footer: {
            Text("A picture replaces the icon and is shown whole, as large as the slot allows. Leave the text empty to show only the picture.")
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
                ForEach(DataSource.available) { source in
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

/// Swatches (car paint colours first) plus a full colour picker.
struct SlotColourPicker: View {
    @Binding var hex: UInt32

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                ForEach(SlotDesign.colourSwatches, id: \.self) { swatch in
                    Button {
                        hex = swatch
                    } label: {
                        Circle()
                            .fill(Color(hex: swatch))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(.white.opacity(swatch == hex ? 0.95 : 0.2), lineWidth: swatch == hex ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: "Colour %06X", swatch))
                    .accessibilityAddTraits(swatch == hex ? .isSelected : [])
                }
            }
            ColorPicker("Any colour", selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hexValue }), supportsOpacity: false)
        }
        .padding(.vertical, 4)
    }
}

/// 70–150 % slider for a text line.
struct ScaleSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title, value: "\(Int((value * 100).rounded()))%")
            Slider(value: $value, in: 0.7...1.5, step: 0.05)
        }
    }
}
