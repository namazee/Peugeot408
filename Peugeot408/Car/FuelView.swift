import CarKit
import SwiftUI

struct FuelView: View {
    @Environment(CarDataModel.self) private var model
    @State private var editingFill: FillUp?
    @State private var addingMod = false

    private var fills: [FillUp] { model.data.fuel.fillUps.sorted { $0.date > $1.date } }
    private var segments: [FuelSegment] { FuelMath.segments(model.data.fuel.fillUps) }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .fuel))

            Section {
                Button {
                    editingFill = newFill()
                } label: {
                    Label("Add fill-up", systemImage: "fuelpump.fill")
                }
            } footer: {
                Text("km/L uses the full-to-full method: it needs two full tanks, and partial fills in between are added to the next full one.")
            }

            if !fills.isEmpty {
                Section("Fill-ups") {
                    ForEach(fills) { fill in
                        Button {
                            editingFill = fill
                        } label: {
                            FillUpRow(fill: fill, segment: segments.first { $0.endFillID == fill.id })
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                model.updateFuel { $0.fillUps.removeAll { $0.id == fill.id } }
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(model.data.fuel.mods.sorted { $0.date > $1.date }) { mod in
                    ModRow(mod: mod, comparison: FuelMath.comparison(around: mod, segments: segments))
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                model.updateFuel { $0.mods.removeAll { $0.id == mod.id } }
                            }
                        }
                }
                Button {
                    addingMod = true
                } label: {
                    Label("Tag a mod", systemImage: "tag.fill")
                }
            } header: {
                Text("Mods")
            } footer: {
                Text("Tag a change (e.g. exhaust swap) to compare average km/L before and after it.")
            }
        }
        .navigationTitle("Fuel Log")
        .sheet(item: $editingFill) { fill in
            FillUpEditor(fill: fill, isNew: !model.data.fuel.fillUps.contains { $0.id == fill.id })
        }
        .sheet(isPresented: $addingMod) {
            ModEditor()
        }
    }

    private func newFill() -> FillUp {
        let last = model.data.fuel.fillUps.max { $0.date < $1.date }
        return FillUp(
            date: .now,
            odometerKm: model.estimatedKm ?? 0,
            litres: 0,
            totalRM: 0,
            grade: last?.grade ?? .ron95,
            isFullTank: true
        )
    }
}

struct FillUpRow: View {
    let fill: FillUp
    let segment: FuelSegment?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fill.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                Text("\(CarFormat.km(fill.odometerKm)) · \(CarFormat.litres(fill.litres)) · \(fill.grade.displayName)\(fill.isFullTank ? "" : " · partial")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CarFormat.rm(fill.totalRM)).font(.headline).monospacedDigit()
                if let segment {
                    Text(CarFormat.kmPerLitre(segment.kmPerLitre))
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct ModRow: View {
    let mod: ModEvent
    let comparison: (before: Double?, after: Double?)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mod.name).font(.headline)
                Spacer()
                Text(mod.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: 16) {
                Text("Before: \(comparison.before.map(CarFormat.kmPerLitre) ?? "--")")
                Text("After: \(comparison.after.map(CarFormat.kmPerLitre) ?? "--")")
            }
            .font(.subheadline)
            .monospacedDigit()
        }
    }
}

struct FillUpEditor: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var fill: FillUp
    @State private var odometerText: String
    @State private var litresText: String
    @State private var totalText: String

    init(fill: FillUp, isNew: Bool) {
        self.isNew = isNew
        _fill = State(initialValue: fill)
        _odometerText = State(initialValue: fill.odometerKm > 0 ? String(fill.odometerKm) : "")
        _litresText = State(initialValue: fill.litres > 0 ? NumberText.string(fill.litres) : "")
        _totalText = State(initialValue: fill.totalRM > 0 ? NumberText.string(fill.totalRM) : "")
    }

    private var odometer: Int? { NumberText.int(odometerText) }
    private var litres: Double? { NumberText.double(litresText) }
    private var total: Double? { NumberText.double(totalText) }

    private var canSave: Bool {
        (odometer ?? 0) > 0 && (litres ?? 0) > 0 && (total ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $fill.date, in: ...Date())
                    NumberField(title: "Odometer", text: $odometerText, unit: "km")
                    NumberField(title: "Litres", text: $litresText, unit: "L", decimal: true)
                    NumberField(title: "Total", text: $totalText, unit: "RM", decimal: true)
                    if let litres, let total, litres > 0 {
                        LabeledContent("Price per litre", value: "\(CarFormat.rm(total / litres))/L")
                    }
                }
                Section {
                    Picker("Fuel", selection: $fill.grade) {
                        ForEach(FuelGrade.allCases, id: \.self) { grade in
                            Text(grade.displayName).tag(grade)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Full tank", isOn: $fill.isFullTank)
                } footer: {
                    Text("Only full tanks close a km/L measurement. Turn this off for a partial top-up.")
                }
                if !isNew {
                    Section {
                        Button("Delete fill-up", role: .destructive) {
                            model.updateFuel { $0.fillUps.removeAll { $0.id == fill.id } }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New fill-up" : "Edit fill-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let odometer, let litres, let total else { return }
        var result = fill
        result.odometerKm = odometer
        result.litres = litres
        result.totalRM = total
        model.updateFuel { log in
            if let index = log.fillUps.firstIndex(where: { $0.id == result.id }) {
                log.fillUps[index] = result
            } else {
                log.fillUps.append(result)
            }
        }
    }
}

struct ModEditor: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("What changed, e.g. Exhaust swap", text: $name)
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Tag a mod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        model.updateFuel { $0.mods.append(ModEvent(date: date, name: trimmed)) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
