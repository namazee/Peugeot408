import CarKit
import SwiftUI

/// Slot editor: a live data widget (Phase 2) or a simple text design (big value, short label, icon, background).
struct SlotEditorView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
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
        draft.source != nil || !draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewContent: SlotContent {
        if let source = draft.source { return .data(cars.card(for: source)) }
        return .design(draft)
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
                    Picker("Shows", selection: $draft.source) {
                        Text("Custom text").tag(DataSource?.none)
                        ForEach(DataSource.allCases) { source in
                            Label(source.displayName, systemImage: source.symbol).tag(DataSource?.some(source))
                        }
                    }
                } footer: {
                    if draft.source != nil {
                        Text("Live data from the Car and Daily tabs. The slot updates by itself when the data changes.")
                    }
                }

                if draft.source == nil {
                    textSections
                }

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
