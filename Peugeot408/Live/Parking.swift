import AppIntents
import CarKit
import CoreLocation
import MapKit
import SwiftUI
import WidgetKit

/// Reverse geocoding for place names (parking) and zone lookup (prayer).
enum PlaceNamer {
    struct Place {
        var name: String
        /// District / town names, most specific first, for JAKIM zone matching.
        var areaNames: [String]
        var state: String?
    }

    static func place(for point: GeoPoint) async -> Place? {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let name = mark.areasOfInterest?.first ?? mark.name ?? mark.thoroughfare ?? mark.locality ?? ""
        let areas = [mark.subLocality, mark.locality, mark.subAdministrativeArea].compactMap { $0 }
        return Place(name: name, areaNames: areas, state: mark.administrativeArea)
    }
}

/// Saves the parking spot: used by the Parking screen and the Save Parking shortcut.
@MainActor
enum ParkingSaver {
    enum SaveError: Error, LocalizedError {
        case noLocation

        var errorDescription: String? {
            "No location. Allow location for Peugeot408 in Settings → Privacy → Location Services."
        }
    }

    /// Gets a fix (falling back to a location from the last 15 minutes), names it, saves it and
    /// reloads the Parking and Map widgets (and any slot showing them).
    static func save(floor: String = "", bay: String = "", note: String = "", directory: URL = AppGroup.containerURL) async throws -> ParkingSpot {
        var point = await LocationService.current(askPermission: true, timeout: 10, directory: directory)
        var approximate = false
        if point == nil, let last = LiveStores.lastLocation(in: directory).load(), Date().timeIntervalSince(last.date) < 15 * 60 {
            point = last.point
            approximate = true
        }
        guard let point else { throw SaveError.noLocation }
        let name = await PlaceNamer.place(for: point)?.name ?? ""
        let spot = ParkingSpot(point: point, savedAt: .now, placeName: name, floor: floor, bay: bay, note: note, isApproximate: approximate)
        try LiveStores.parking(in: directory).save(ParkingState(spot: spot))
        reloadWidgets(directory: directory)
        return spot
    }

    static func reloadWidgets(directory: URL = AppGroup.containerURL) {
        let slots = SlotStore(directory: directory).load()
        let studio = StudioStores.studio(in: directory).load()
        for source in DataSource.parking.affectedSources {
            WidgetCenter.shared.reloadTimelines(ofKind: source.widgetKind)
            for slot in SlotsState.slotNumbers where SlotTimeline.sources(slot: slot, state: slots, studio: studio).contains(source) {
                WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
            }
        }
    }
}

// MARK: - Shortcut

/// "Save Parking" for Shortcuts and Siri. Runs without opening the app, so it can be used in a
/// "When CarPlay disconnects" automation (see SETUP.md).
struct SaveParkingIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Parking"
    static let description = IntentDescription("Saves where you parked, with optional floor, bay and note, for the Parking widget.")
    static let openAppWhenRun = false

    @Parameter(title: "Floor", description: "e.g. B2")
    var floor: String?

    @Parameter(title: "Bay", description: "e.g. C14")
    var bay: String?

    @Parameter(title: "Note")
    var note: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let spot = try await ParkingSaver.save(floor: floor ?? "", bay: bay ?? "", note: note ?? "")
        return .result(dialog: "Parking saved: \(spot.title)")
    }
}

struct Peugeot408Shortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveParkingIntent(),
            phrases: [
                "Save parking in \(.applicationName)",
                "Save my parking with \(.applicationName)",
            ],
            shortTitle: "Save Parking",
            systemImageName: "parkingsign.circle.fill"
        )
        AppShortcut(
            intent: PlayConnectSoundIntent(),
            phrases: [
                "Play connect sound in \(.applicationName)",
                "Play my welcome sound with \(.applicationName)",
            ],
            shortTitle: "Play Connect Sound",
            systemImageName: "speaker.wave.2.fill"
        )
        AppShortcut(
            intent: SyncLyricsIntent(),
            phrases: ["Sync lyrics in \(.applicationName)"],
            shortTitle: "Sync Lyrics",
            systemImageName: "quote.bubble.fill"
        )
    }
}

// MARK: - Screen

struct ParkingView: View {
    @Environment(CarDataModel.self) private var model
    @State private var saving = false
    @State private var editing = false
    @State private var error: String?

    private var spot: ParkingSpot? { model.data.parking.spot }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .parking))

            if let spot {
                Section {
                    if let point = spot.point {
                        let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500))) {
                            Marker(spot.title, systemImage: "car.fill", coordinate: coordinate)
                                .tint(Theme.accent)
                        }
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                    }
                    LabeledContent("Place", value: spot.title)
                    if !spot.detailLine.isEmpty {
                        LabeledContent("Details", value: spot.detailLine)
                    }
                    LabeledContent("Saved", value: spot.savedAt.formatted(date: .abbreviated, time: .shortened))
                    if spot.isApproximate {
                        Label("Approximate: no fresh GPS fix when saved.", systemImage: "location.slash")
                            .foregroundStyle(Theme.dueSoon)
                    }
                    Button {
                        editing = true
                    } label: {
                        Label("Edit floor, bay or note", systemImage: "pencil")
                    }
                    if let point = spot.point {
                        Button {
                            openInMaps(point, name: spot.title)
                        } label: {
                            Label("Directions in Maps", systemImage: "figure.walk")
                        }
                    }
                    Button("I've left: clear parking", role: .destructive) {
                        model.updateParking { $0.spot = nil }
                    }
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Label(spot == nil ? "Save parking here" : "Save new spot here", systemImage: "parkingsign.circle.fill")
                        if saving {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(saving)
                if let error {
                    Text(error).foregroundStyle(Theme.overdue)
                }
            } footer: {
                Text("Also works from Siri and Shortcuts: \"Save parking in Peugeot408\". To save automatically when you leave the car, add a Shortcuts automation \"When CarPlay disconnects → Save Parking\" (steps in SETUP.md).")
            }
        }
        .navigationTitle("Parking")
        .onAppear { model.reload() }
        .sheet(isPresented: $editing) {
            if let spot {
                ParkingDetailsEditor(spot: spot)
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            _ = try await ParkingSaver.save()
            error = nil
            model.reload()
            editing = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func openInMaps(_ point: GeoPoint, name: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

struct ParkingDetailsEditor: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var spot: ParkingSpot

    init(spot: ParkingSpot) {
        _spot = State(initialValue: spot)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Place, e.g. IOI City Mall", text: $spot.placeName)
                    TextField("Floor, e.g. B2", text: $spot.floor)
                    TextField("Bay or pillar, e.g. C14", text: $spot.bay)
                    TextField("Note", text: $spot.note)
                } footer: {
                    Text("Keep it short: the widget shows place, then floor and bay.")
                }
            }
            .navigationTitle("Parking details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = spot
                        model.updateParking { $0.spot = result }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
