import CarKit
import SwiftUI

struct TnGView: View {
    @Environment(CarDataModel.self) private var model
    @State private var settingBalance = false
    @State private var balanceText = ""

    private static let topUps: [Double] = [10, 20, 50, 100]
    private static let tolls: [Double] = [1, 2, 5, 10]

    private var tng: TnGState { model.data.tng }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .tng))

            Section {
                Button {
                    balanceText = NumberText.string(tng.balance)
                    settingBalance = true
                } label: {
                    Label(tng.balance == nil ? "Enter balance" : "Set exact balance", systemImage: "pencil")
                }
                if let updated = tng.updatedAt {
                    LabeledContent("Updated", value: updated.formatted(.relative(presentation: .named)))
                }
            } footer: {
                Text("There is no Touch 'n Go API, so the balance is what you enter here.")
            }

            Section("Top up") {
                quickButtons(amounts: Self.topUps, sign: 1)
            }
            Section("Toll or parking") {
                quickButtons(amounts: Self.tolls, sign: -1)
            }

            Section {
                Stepper(value: threshold, in: 5...200, step: 5) {
                    LabeledContent("Warn below", value: CarFormat.rm(tng.threshold, decimals: 0))
                }
            } footer: {
                Text("The widget says \"Top up soon\" when the balance is below this.")
            }

            if !tng.history.isEmpty {
                Section("Recent changes") {
                    ForEach(tng.history.prefix(15)) { change in
                        HStack {
                            Text(change.date.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text(signed(change.amount))
                                .foregroundStyle(change.amount < 0 ? Theme.primaryText : Color.green)
                            Text(CarFormat.rm(change.balanceAfter))
                                .frame(minWidth: 90, alignment: .trailing)
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Touch 'n Go")
        .alert("Balance", isPresented: $settingBalance) {
            TextField("RM", text: $balanceText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let value = NumberText.double(balanceText) {
                    model.updateTnG { $0.setBalance(value, at: .now) }
                }
            }
        } message: {
            Text("Enter the balance shown on your card or in the TNG eWallet app.")
        }
    }

    private var threshold: Binding<Double> {
        Binding(
            get: { tng.threshold },
            set: { value in model.updateTnG { $0.threshold = value } }
        )
    }

    private func quickButtons(amounts: [Double], sign: Double) -> some View {
        HStack(spacing: 8) {
            ForEach(amounts, id: \.self) { amount in
                Button {
                    model.updateTnG { $0.apply(sign * amount, at: .now) }
                } label: {
                    Text("\(sign > 0 ? "+" : "−")\(Int(amount))")
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(sign > 0 ? Color.green : Theme.accent)
                .disabled(tng.balance == nil)
                .accessibilityLabel(sign > 0 ? "Top up \(Int(amount)) ringgit" : "Deduct \(Int(amount)) ringgit")
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private func signed(_ amount: Double) -> String {
        amount < 0 ? "−\(CarFormat.rm(-amount))" : "+\(CarFormat.rm(amount))"
    }
}
