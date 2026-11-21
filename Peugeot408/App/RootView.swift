import CarKit
import SwiftUI

enum AppTab: Hashable {
    case slots, studio, car, daily, settings
}

struct SlotRef: Identifiable, Hashable {
    let slot: Int
    /// Card tapped in a Split / Quad slot (0 = top / first).
    var card: Int = 0

    var id: Int { slot * 10 + card }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var tab: AppTab = .slots
    @State private var editing: SlotRef?
    @State private var carPath: [DataSource] = []
    @State private var dailyPath: [DataSource] = []
    @State private var studioPath: [DataSource] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CarDataModel.self) private var cars
    @Environment(SlotsModel.self) private var slots
    @Environment(StudioModel.self) private var studio
    @Environment(AppearanceModel.self) private var appearance

    var body: some View {
        TabView(selection: $tab) {
            Tab("Slots", systemImage: "rectangle.grid.3x2", value: AppTab.slots) {
                SlotsView(editing: $editing)
            }
            Tab("Studio", systemImage: "paintpalette", value: AppTab.studio) {
                StudioView(path: $studioPath)
            }
            Tab("Car", systemImage: "car", value: AppTab.car) {
                CarView(path: $carPath)
            }
            Tab("Daily", systemImage: "sun.max", value: AppTab.daily) {
                DailyView(path: $dailyPath)
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if cars.isSampleData {
                Label("Sample data", systemImage: "testtube.2")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.25), in: Capsule())
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Turn it off in Settings → Sample data")
            }
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .onOpenURL(perform: handle)
        .task { setUpScreenshot() }
        .onChange(of: scenePhase) { _, phase in
            // Pick up changes made while away (e.g. the Save Parking shortcut), refresh the
            // calendar copy the Commute widget uses, and keep the prayer cache topped up.
            guard phase == .active else { return }
            cars.reload()
            Task {
                await cars.refresh(.prayer)
                await cars.refresh(.commute)
                await cars.refreshMusic()
                #if !STORE_BUILD
                // Re-anchor the lyrics timing and keep listening while the app runs.
                LyricsSync.shared.startObserving()
                await LyricsSync.shared.sync()
                #endif
                cars.reload()
            }
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )
    }

    /// `peugeot408://slot/3` opens the editor for slot 3; `peugeot408://data/fuel` opens the Fuel Log.
    /// Used by the widgets' `widgetURL` on the iPhone (CarPlay may ignore taps).
    /// Store screenshots only (`ScreenshotMode`, spec §10): sample data, a tab, a look, the panorama.
    private func setUpScreenshot() {
        guard ScreenshotMode.isOn else { return }
        hasCompletedOnboarding = true
        if !cars.isSampleData { cars.setSampleData(true) }
        if let next = ScreenshotMode.tab { tab = next }
        if let look = ScreenshotMode.look { appearance.setLook(look) }
        if let on = ScreenshotMode.panorama {
            if on {
                let hero = studio.state.designs.first { $0.canvas == .panorama } ?? Templates.make(.hero)
                if studio.design(hero.id) == nil { studio.save(hero) }
                slots.setPanorama(PanoramaSettings(enabled: true, designID: hero.id))
            } else if slots.state.activePanoramaID != nil {
                slots.setPanorama(PanoramaSettings(enabled: false, designID: slots.state.panorama?.designID))
            }
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "peugeot408" else { return }
        switch url.host() {
        case "slot":
            guard let number = Int(url.lastPathComponent), SlotsState.slotNumbers.contains(number) else { return }
            tab = .slots
            editing = SlotRef(slot: number)
        case "data":
            guard let source = DataSource(rawValue: url.lastPathComponent) else { return }
            switch source {
            case .tng, .prayer, .commute, .weather:
                tab = .daily
                dailyPath = [source]
            case .map, .photos, .music, .lyrics:
                tab = .studio
                studioPath = [source]
            case .service, .fuel, .renewals, .parking, .obd:
                tab = .car
                carPath = [source]
            }
        default:
            break
        }
    }
}
