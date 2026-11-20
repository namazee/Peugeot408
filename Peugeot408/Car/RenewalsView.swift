import CarKit
import SwiftUI

struct RenewalsView: View {
    @Environment(CarDataModel.self) private var model
    @State private var editing: Renewal?

    private var items: [Renewal] { RenewalRules.sorted(model.data.renewals.items) }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .renewals))

            Section {
                if items.isEmpty {
                    Text("Add your road tax and insurance expiry dates.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        RenewalRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            model.updateRenewals { $0.items.removeAll { $0.id == item.id } }
                        }
                    }
                }
                Button {
                    editing = Renewal(kind: nextKind, expiry: Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
                } label: {
                    Label("Add renewal", systemImage: "plus")
                }
            } header: {
                Text("Renewals")
            } footer: {
                Text("Amber at 30 days or less, red at 7 days or less. You get a reminder 30 and 7 days before each expiry, at 9 am.")
            }
        }
        .navigationTitle("Road Tax & Insurance")
        .sheet(item: $editing) { item in
            RenewalEditor(item: item, isNew: !model.data.renewals.items.contains { $0.id == item.id })
        }
    }

    /// Suggests road tax first, then insurance, then "other".
    private var nextKind: RenewalKind {
        let used = Set(model.data.renewals.items.map(\.kind))
        return [RenewalKind.roadTax, .insurance].first { !used.contains($0) } ?? .other
    }
}

struct RenewalRow: View {
    let item: Renewal

    var body: some View {
        let days = RenewalRules.daysLeft(until: item.expiry, from: .now)
        let urgency = RenewalRules.urgency(daysLeft: days)
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbol)
                .font(.title3)
                .foregroundStyle(urgency.color(fallback: Theme.accent))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.headline)
                Text(item.expiry.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            UrgencyBadge(text: days < 0 ? "\(-days) d overdue" : "\(days) d", urgency: urgency)
        }
        .contentShape(Rectangle())
    }
}

struct RenewalEditor: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let isNew: Bool
    @State private var item: Renewal

    init(item: Renewal, isNew: Bool) {
        self.isNew = isNew
        _item = State(initialValue: item)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $item.kind) {
                        ForEach(RenewalKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField(item.kind == .other ? "Name" : "Name (optional)", text: $item.name)
                    DatePicker("Expires", selection: $item.expiry, displayedComponents: .date)
                }
                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) {
                            model.updateRenewals { $0.items.removeAll { $0.id == item.id } }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New renewal" : "Edit renewal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = item
                        model.updateRenewals { log in
                            if let index = log.items.firstIndex(where: { $0.id == result.id }) {
                                log.items[index] = result
                            } else {
                                log.items.append(result)
                            }
                        }
                        dismiss()
                    }
                    .disabled(item.kind == .other && item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
