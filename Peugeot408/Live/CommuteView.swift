import CarKit
import EventKit
import MapKit
import SwiftUI

struct CommuteView: View {
    @Environment(CarDataModel.self) private var model
    @State private var calendarStatus = EKEventStore.authorizationStatus(for: .event)

    private var settings: CommuteSettings { model.data.commute }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .commute))

            Section {
                placeRow(.home)
                placeRow(.work)
                Stepper(value: homeFromHour, in: 11...22) {
                    LabeledContent("Show trip home from", value: String(format: "%02d:00", settings.homeFromHour))
                }
            } header: {
                Text("Places")
            } footer: {
                Text("Before that hour the widget shows the drive to Work, after it the drive Home. Drive times use Apple Maps traffic, from where your phone is (or from the other place when location is off).")
            }

            Section {
                if let latest = model.data.commuteCache.latest {
                    LabeledContent(latest.destination.title, value: CarFormat.duration(latest.travelSeconds))
                    LabeledContent("Updated", value: latest.computedAt.formatted(date: .omitted, time: .shortened))
                    LabeledContent("From", value: latest.fromCurrentLocation ? "Current location" : "Other saved place")
                }
                if let error = model.data.commuteCache.lastError {
                    Text(error).font(.footnote).foregroundStyle(Theme.overdue)
                }
                Button {
                    Task { await model.refresh(.commute, force: true) }
                } label: {
                    HStack {
                        Label("Update drive time", systemImage: "arrow.clockwise")
                        if model.isRefreshing.contains(.commute) {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!settings.isSetUp && settings.home == nil && settings.work == nil)
            } header: {
                Text("Drive time")
            }

            Section {
                switch calendarStatus {
                case .fullAccess:
                    if let event = model.data.calendar.nextEvent(at: .now) {
                        LabeledContent(event.title, value: event.start.formatted(date: .omitted, time: .shortened))
                    } else {
                        Text("No events in the next 24 hours.").foregroundStyle(Theme.secondaryText)
                    }
                case .denied, .restricted:
                    Text("Calendar access is off. Turn it on in Settings → Privacy → Calendars → DashCraft.")
                        .foregroundStyle(Theme.secondaryText)
                default:
                    Button {
                        Task { await requestCalendar() }
                    } label: {
                        Label("Show my next event", systemImage: "calendar")
                    }
                }
            } header: {
                Text("Next event")
            } footer: {
                Text("Read on the phone only. The widget shows the next timed event's title and start time.")
            }
        }
        .navigationTitle("Commute")
        .task { await model.refresh(.commute) }
    }

    private func placeRow(_ destination: CommuteDestination) -> some View {
        NavigationLink {
            PlacePickerView(title: destination == .home ? "Home" : "Work") { place in
                model.updateCommute {
                    if destination == .home { $0.home = place } else { $0.work = place }
                }
            }
        } label: {
            LabeledContent {
                Text(settings.place(destination)?.name ?? "Not set")
                    .foregroundStyle(settings.place(destination) == nil ? Theme.secondaryText : Theme.primaryText)
            } label: {
                Label(destination == .home ? "Home" : "Work", systemImage: destination.symbol)
            }
        }
    }

    private var homeFromHour: Binding<Int> {
        Binding(
            get: { settings.homeFromHour },
            set: { value in model.updateCommute { $0.homeFromHour = value } }
        )
    }

    private func requestCalendar() async {
        _ = try? await EKEventStore().requestFullAccessToEvents()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        await model.refresh(.commute)
    }
}

/// Search Apple Maps for a place, or use the current location.
struct PlacePickerView: View {
    let title: String
    let onPick: (SavedPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label("Use my current location", systemImage: "location.fill")
                }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
            if searching {
                ProgressView()
            }
            Section {
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button {
                        let coordinate = item.placemark.coordinate
                        pick(SavedPlace(
                            name: item.name ?? title,
                            point: GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Place").font(.headline)
                            if let address = item.placemark.title {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $query, prompt: "Search, e.g. APU Bukit Jalil")
        .onSubmit(of: .search) { Task { await search() } }
        .navigationTitle(title)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        searching = true
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 3.0, longitude: 101.6),
            latitudinalMeters: 300_000,
            longitudinalMeters: 300_000
        )
        do {
            results = try await MKLocalSearch(request: request).start().mapItems
            message = results.isEmpty ? "No places found." : nil
        } catch {
            results = []
            message = "Search failed: \(error.localizedDescription)"
        }
    }

    private func useCurrentLocation() async {
        guard let point = await LocationService.current(askPermission: true) else {
            message = "Location isn't available. Allow it in Settings → Privacy → Location Services."
            return
        }
        let name = await PlaceNamer.place(for: point)?.name
        pick(SavedPlace(name: name?.isEmpty == false ? name ?? title : title, point: point))
    }

    private func pick(_ place: SavedPlace) {
        onPick(place)
        dismiss()
    }
}
