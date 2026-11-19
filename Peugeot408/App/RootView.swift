import CarKit
import SwiftUI

enum AppTab: Hashable {
    case slots, studio, car, daily, settings
}

struct SlotRef: Identifiable, Hashable {
    let id: Int
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var tab: AppTab = .slots
    @State private var editing: SlotRef?

    var body: some View {
        TabView(selection: $tab) {
            Tab("Slots", systemImage: "rectangle.grid.3x2", value: AppTab.slots) {
                SlotsView(editing: $editing)
            }
            Tab("Studio", systemImage: "paintpalette", value: AppTab.studio) {
                ComingSoonView(
                    title: "Studio",
                    symbol: "paintpalette.fill",
                    phase: 5,
                    summary: "Templates, the custom builder, seasonal packs, your car photo and connect sounds."
                )
            }
            Tab("Car", systemImage: "car", value: AppTab.car) {
                ComingSoonView(
                    title: "Car",
                    symbol: "car.side.fill",
                    phase: 2,
                    summary: "Service tracker, fuel log and renewals. Parking follows in Phase 3, OBD2 in Phase 7."
                )
            }
            Tab("Daily", systemImage: "sun.max", value: AppTab.daily) {
                ComingSoonView(
                    title: "Daily",
                    symbol: "sun.max.fill",
                    phase: 2,
                    summary: "Touch 'n Go balance. Prayer times, commute and weather follow in Phase 3."
                )
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .onOpenURL(perform: handle)
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )
    }

    /// `peugeot408://slot/3` opens the editor for slot 3 (used by the widgets' `widgetURL`).
    private func handle(_ url: URL) {
        guard url.scheme == "peugeot408", url.host() == "slot",
              let number = Int(url.lastPathComponent),
              SlotsState.slotNumbers.contains(number)
        else { return }
        tab = .slots
        editing = SlotRef(id: number)
    }
}

struct ComingSoonView: View {
    let title: String
    let symbol: String
    let phase: Int
    let summary: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: symbol)
            } description: {
                Text(summary)
            } actions: {
                Text("Arrives in Phase \(phase)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .navigationTitle(title)
        }
    }
}
