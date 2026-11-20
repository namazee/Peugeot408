import CarKit
import Observation
import SwiftUI
import WidgetKit

/// App-side owner of Settings → Appearance (spec §3 "Widget styles"). Saved in the App Group so
/// the widgets use the same look; every widget is reloaded when it changes.
@MainActor
@Observable
final class AppearanceModel {
    private(set) var settings: AppearanceSettings
    @ObservationIgnored private let store: JSONFileStore<AppearanceSettings>

    init(directory: URL = AppGroup.containerURL) {
        store = AppearanceStore.settings(in: directory)
        settings = store.load()
    }

    var look: CardLook { settings.look }

    func setLook(_ look: CardLook) {
        guard look != settings.look else { return }
        var next = settings
        next.look = look
        try? store.save(next)
        settings = next
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// After a backup is restored.
    func reload() {
        settings = store.load()
    }
}

/// Settings → Appearance: pick Bold or Neon, with live previews of your own data.
struct AppearanceView: View {
    @Environment(AppearanceModel.self) private var appearance
    @Environment(CarDataModel.self) private var cars

    var body: some View {
        List {
            Section {
                ForEach(CardLook.allCases) { look in
                    Button {
                        appearance.setLook(look)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(look.displayName).font(.headline)
                                Spacer()
                                Image(systemName: appearance.look == look ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(appearance.look == look ? look.appTint : Theme.secondaryText)
                            }
                            Text(look.summary)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                            HStack(spacing: 10) {
                                ForEach([DataSource.service, .prayer, .fuel], id: \.self) { source in
                                    DataCardTile(card: cars.card(for: source))
                                        .frame(width: 104, height: 104)
                                }
                            }
                            .environment(\.cardLook, look)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(appearance.look == look ? .isSelected : [])
                }
            } footer: {
                Text("Used by every widget and slot on CarPlay and in the app. Each Car Slot can still choose its own look in its editor. CarPlay redraws on its next refresh; reconnecting is fastest.")
            }
        }
        .navigationTitle("Appearance")
    }
}
