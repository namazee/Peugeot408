import CarKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showReloaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("CarPlay") {
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
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

                Section("Data") {
                    NavigationLink {
                        ZonePickerView()
                    } label: {
                        Label("Prayer zone", systemImage: "moon.stars")
                    }
                    NavigationLink {
                        CommuteView()
                    } label: {
                        Label("Home and Work", systemImage: "house")
                    }
                    NavigationLink {
                        APIKeysView()
                    } label: {
                        Label("API keys", systemImage: "key")
                    }
                    NavigationLink {
                        DongleView()
                    } label: {
                        Label("OBD2 dongle", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                Section {
                    Toggle("Sample data", isOn: Binding(get: { cars.isSampleData }, set: { cars.setSampleData($0) }))
                } footer: {
                    Text("Shows a made-up service history, fill-ups, renewals, prayer times and OBD values in the app and on every widget, to try things out. Your own data is kept and comes back when you turn this off.")
                }

                BackupSection()

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
                    Text("Not affiliated with any car maker.")
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

/// Settings → Backup: export everything I entered as one JSON file, or restore one.
struct BackupSection: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(CarDataModel.self) private var cars
    @Environment(StudioModel.self) private var studio
    @Environment(AppearanceModel.self) private var appearance
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var message: String?

    var body: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Save or share the backup", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    makeBackup()
                } label: {
                    Label("Export backup", systemImage: "externaldrive.badge.plus")
                }
            }
            Button {
                importing = true
            } label: {
                Label("Restore from backup", systemImage: "arrow.counterclockwise")
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("One JSON file with your service, fuel, renewals, TnG, parking, Home and Work, prayer zone, slots, Studio designs, appearance, connect sound and OBD2 settings. Photos, pictures and imported sounds aren't included.")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { pendingImport = url }
        }
        .confirmationDialog("Replace your data with this backup?", isPresented: showConfirm, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                if let url = pendingImport { restore(from: url) }
                pendingImport = nil
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Everything in the backup overwrites what's on this iPhone. Export a backup first if you might want today's data back.")
        }
    }

    private var showConfirm: Binding<Bool> {
        Binding { pendingImport != nil } set: { if !$0 { pendingImport = nil } }
    }

    private func makeBackup() {
        do {
            let url = FileManager.default.temporaryDirectory.appending(path: Backup.fileName(), directoryHint: .notDirectory)
            try Backup.export().write(to: url, options: .atomic)
            exportURL = url
            message = "Backup ready. Save it to Files or iCloud Drive."
        } catch {
            message = "Couldn't make the backup: \(error.localizedDescription)"
        }
    }

    private func restore(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let result = try Backup.restore(Data(contentsOf: url))
            cars.reload()
            slots.reload()
            studio.reload()
            appearance.reload()
            slots.reloadAllWidgets()
            exportURL = nil
            let when = result.createdAt.map { " from \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
            message = result.restored.isEmpty
                ? "That backup had nothing to restore."
                : "Restored\(when): \(result.restored.joined(separator: ", ")). The widgets are redrawing."
        } catch {
            message = error.localizedDescription
        }
    }
}

struct HowToCarPlayView: View {
    var body: some View {
        List {
            Section {
                ClipOrFallback(resource: "OnboardingWelcome") { EmptyView() }
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
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
            Section {
                Label("Google Maps has its own CarPlay widget with ETA, distance and the next turn while it navigates. Update Google Maps, then in the same Widgets screen add \"Google Maps\" to a stack with a Car Slot.", systemImage: "map")
                Label("Keep Smart Rotate on for that stack: it brings Google's widget forward while you navigate and goes back to your slot afterwards.", systemImage: "arrow.triangle.2.circlepath")
                Label("DashCraft can't show Google's turn-by-turn itself: iOS doesn't let other apps read Google Maps' navigation.", systemImage: "info.circle")
                    .foregroundStyle(Theme.secondaryText)
            } header: {
                Text("Google Maps ETA")
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
