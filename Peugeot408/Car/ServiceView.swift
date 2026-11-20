import CarKit
import SwiftUI

struct ServiceView: View {
    @Environment(CarDataModel.self) private var model
    @State private var sheet: ServiceSheet?

    enum ServiceSheet: Identifiable {
        case reading
        case edit(ServiceItem, isNew: Bool)
        case done(ServiceItem)

        var id: String {
            switch self {
            case .reading: "reading"
            case .edit(let item, _): "edit-\(item.id)"
            case .done(let item): "done-\(item.id)"
            }
        }
    }

    private var statuses: [ServiceStatus] { model.data.serviceStatuses(at: .now) }

    private var readings: [OdometerReading] {
        model.data.service.readings.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .service))

            Section {
                LabeledContent("Estimated now", value: model.estimatedKm.map(CarFormat.km) ?? "No readings yet")
                if let average = MileageEstimator.averageDailyKm(model.data.service.readings + model.data.fuel.odometerReadings) {
                    LabeledContent("Average", value: "\(Int(average.rounded())) km/day")
                }
                Button {
                    sheet = .reading
                } label: {
                    Label("Log odometer reading", systemImage: "gauge.with.dots.needle.67percent")
                }
            } header: {
                Text("Odometer")
            } footer: {
                Text("Between readings the mileage is estimated from your average daily km. Fuel fill-ups count as readings too.")
            }

            Section("Due") {
                if statuses.isEmpty {
                    Text("Add a service item with the + button.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(statuses) { status in
                    Button {
                        sheet = .edit(status.item, isNew: false)
                    } label: {
                        ServiceStatusRow(status: status)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button("Done") { sheet = .done(status.item) }
                            .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            model.updateService { $0.items.removeAll { $0.id == status.item.id } }
                        }
                    }
                }
            }

            if !readings.isEmpty {
                Section("Readings") {
                    ForEach(readings.prefix(20)) { reading in
                        LabeledContent(reading.date.formatted(date: .abbreviated, time: .omitted), value: CarFormat.km(reading.km))
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    model.updateService { $0.readings.removeAll { $0.id == reading.id } }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Service Tracker")
        .toolbar {
            Menu {
                Section("Presets") {
                    ForEach(ServicePreset.all) { preset in
                        Button(preset.name) {
                            sheet = .edit(preset.makeItem(lastDoneKm: model.estimatedKm, lastDoneDate: .now), isNew: true)
                        }
                    }
                }
                Button("Custom item…") {
                    sheet = .edit(ServiceItem(name: "", intervalKm: 10_000, intervalMonths: 12, lastDoneKm: model.estimatedKm, lastDoneDate: .now), isNew: true)
                }
                Button("One-off check…") {
                    sheet = .edit(ServiceItem(name: "", isOneOff: true), isNew: true)
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add service item")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .reading:
                OdometerReadingSheet(suggestedKm: model.estimatedKm)
            case .edit(let item, let isNew):
                ServiceItemEditor(item: item, isNew: isNew)
            case .done(let item):
                MarkDoneSheet(item: item, suggestedKm: model.estimatedKm)
            }
        }
    }
}

struct ServiceStatusRow: View {
    let status: ServiceStatus

    private var line: ServiceLine {
        ServiceLine(
            name: status.item.name,
            symbol: status.item.symbol,
            kmLeft: status.kmLeft,
            daysLeft: status.daysLeft,
            urgency: status.urgency
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.item.symbol)
                .font(.title3)
                .foregroundStyle(status.urgency.color(fallback: Theme.accent))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.item.name).font(.headline)
                Text(status.item.isOneOff ? "One-off" : rule)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            UrgencyBadge(text: line.compactText, urgency: status.urgency)
        }
        .contentShape(Rectangle())
    }

    private var rule: String {
        var parts: [String] = []
        if let km = status.item.intervalKm { parts.append("every \(CarFormat.km(km))") }
        if let months = status.item.intervalMonths { parts.append("\(months) months") }
        return parts.isEmpty ? "No interval" : parts.joined(separator: " or ")
    }
}

// MARK: - Sheets

struct OdometerReadingSheet: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kmText: String
    @State private var date = Date()

    init(suggestedKm: Int?) {
        _kmText = State(initialValue: NumberText.string(suggestedKm))
    }

    var body: some View {
        NavigationStack {
            Form {
                NumberField(title: "Odometer", text: $kmText, unit: "km")
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Odometer reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let km = NumberText.int(kmText) {
                            model.updateService { $0.readings.append(OdometerReading(date: date, km: km)) }
                        }
                        dismiss()
                    }
                    .disabled(NumberText.int(kmText) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct MarkDoneSheet: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: ServiceItem
    @State private var kmText: String
    @State private var date = Date()

    init(item: ServiceItem, suggestedKm: Int?) {
        self.item = item
        _kmText = State(initialValue: NumberText.string(suggestedKm))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField(title: "Odometer", text: $kmText, unit: "km")
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text(item.isOneOff ? "Closes this one-off check." : "Restarts the interval from this km and date.")
                }
            }
            .navigationTitle("\(item.name) done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let km = NumberText.int(kmText)
                        model.updateService { log in
                            guard let index = log.items.firstIndex(where: { $0.id == item.id }) else { return }
                            log.items[index].markDone(km: km ?? log.items[index].lastDoneKm ?? 0, date: date)
                            if let km { log.readings.append(OdometerReading(date: date, km: km)) }
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ServiceItemEditor: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var item: ServiceItem
    @State private var intervalKmText: String
    @State private var intervalMonthsText: String
    @State private var lastKmText: String
    @State private var hasLastDate: Bool
    @State private var lastDate: Date
    @State private var dueKmText: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(item: ServiceItem, isNew: Bool) {
        self.isNew = isNew
        _item = State(initialValue: item)
        _intervalKmText = State(initialValue: NumberText.string(item.intervalKm))
        _intervalMonthsText = State(initialValue: NumberText.string(item.intervalMonths))
        _lastKmText = State(initialValue: NumberText.string(item.lastDoneKm))
        _hasLastDate = State(initialValue: item.lastDoneDate != nil)
        _lastDate = State(initialValue: item.lastDoneDate ?? .now)
        _dueKmText = State(initialValue: NumberText.string(item.dueKm))
        _hasDueDate = State(initialValue: item.dueDate != nil)
        _dueDate = State(initialValue: item.dueDate ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
    }

    private var canSave: Bool {
        !item.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Alignment check after rim swap", text: $item.name)
                }

                if item.isOneOff {
                    Section {
                        NumberField(title: "Due at", text: $dueKmText, unit: "km")
                        Toggle("Due by date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                        }
                    } header: {
                        Text("One-off")
                    } footer: {
                        Text("Set a km, a date, or both. Whichever comes first counts.")
                    }
                } else {
                    Section {
                        NumberField(title: "Every", text: $intervalKmText, unit: "km")
                        NumberField(title: "Or every", text: $intervalMonthsText, unit: "months")
                    } header: {
                        Text("Interval")
                    } footer: {
                        Text("Leave one empty to use only the other. Typical values; check your service booklet.")
                    }
                    Section("Last done") {
                        NumberField(title: "At", text: $lastKmText, unit: "km")
                        Toggle("Date known", isOn: $hasLastDate)
                        if hasLastDate {
                            DatePicker("Date", selection: $lastDate, in: ...Date(), displayedComponents: .date)
                        }
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete item", role: .destructive) {
                            model.updateService { $0.items.removeAll { $0.id == item.id } }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New item" : "Edit item")
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
        var result = item
        result.name = item.name.trimmingCharacters(in: .whitespaces)
        if result.isOneOff {
            result.dueKm = NumberText.int(dueKmText)
            result.dueDate = hasDueDate ? dueDate : nil
        } else {
            result.intervalKm = NumberText.int(intervalKmText)
            result.intervalMonths = NumberText.int(intervalMonthsText)
            result.lastDoneKm = NumberText.int(lastKmText)
            result.lastDoneDate = hasLastDate ? lastDate : nil
        }
        model.updateService { log in
            if let index = log.items.firstIndex(where: { $0.id == result.id }) {
                log.items[index] = result
            } else {
                log.items.append(result)
            }
        }
    }
}
