import CarKit
import SwiftUI

struct SettingsView: View {
    @Environment(SlotsModel.self) private var slots
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showReloaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("CarPlay") {
                    NavigationLink {
                        HowToCarPlayView()
                    } label: {
                        Label("How to add to CarPlay", systemImage: "car.side")
                    }
                    Button {
                        slots.reloadAllWidgets()
                        showReloaded = true
                    } label: {
                        Label("Reload all widgets", systemImage: "arrow.clockwise")
                    }
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Show setup guide again", systemImage: "sparkles")
                    }
                }

                Section {
                    LabeledContent("App Group", value: AppGroup.isAvailable ? "Connected" : "Not available")
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("Diagnostics")
                } footer: {
                    if !AppGroup.isAvailable {
                        Text("Widgets can't see the app's data. Check the App Group in SETUP.md, step 2.")
                            .foregroundStyle(Theme.overdue)
                    }
                }

                Section {
                    Text("Units, accent colour, prayer zone, locations, API keys, OBD2 dongle and backup arrive with the features that use them.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                    Text("Personal project. Not affiliated with Peugeot or Stellantis.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("Settings")
            .alert("Widgets reloaded", isPresented: $showReloaded) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("CarPlay redraws on its next refresh. Reconnecting the phone is fastest.")
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct HowToCarPlayView: View {
    var body: some View {
        List {
            Section {
                CarPlaySetupSteps()
            } header: {
                Text("One-time setup")
            }
            Section {
                Label("Each stack holds up to 5 widgets. Put Car Slot 1–5 in one stack, or spread them over several.", systemImage: "square.stack.3d.up")
                Label("Turn Smart Rotate off if you want a stack to stay on the slot you chose. Leave it on to let iOS pick.", systemImage: "arrow.triangle.2.circlepath")
                Label("After that, change what the slots show from this app. You never need to go back into CarPlay settings.", systemImage: "checkmark.circle")
            } header: {
                Text("Tips")
            }
        }
        .navigationTitle("Add to CarPlay")
    }
}

/// The numbered steps, shared by onboarding and Settings.
struct CarPlaySetupSteps: View {
    private let steps = [
        "Connect your iPhone to the car.",
        "On the iPhone, open Settings → General → CarPlay and tap your car.",
        "Tap Widgets, then add Car Slot 1, 2, 3, 4 and 5.",
        "Come back here and tap \"Test: flash all slots\" to see which is which.",
    ]

    var body: some View {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(index + 1)")
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accent))
                Text(step)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
