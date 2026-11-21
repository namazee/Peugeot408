import CarKit
import CoreGraphics
import Foundation
import Observation
import UserNotifications
import WidgetKit

/// App-side owner of the car and daily data. Every change is saved to the App Group, then only the
/// affected widgets are reloaded: the source's own widget plus any Car Slot showing it.
@MainActor
@Observable
final class CarDataModel {
    private(set) var data: CarData
    var lastError: String?

    @ObservationIgnored private let directory: URL

    init(directory: URL = AppGroup.containerURL) {
        self.directory = directory
        self.data = CarData.load(from: directory)
    }

    func card(for source: DataSource, at date: Date = .now) -> DataCard {
        data.card(for: source, at: date)
    }

    var estimatedKm: Int? { data.estimatedKm(at: .now) }

    // MARK: Updates

    func updateService(_ change: (inout ServiceLog) -> Void) {
        var value = data.service
        change(&value)
        commit(value, to: CarStores.service(in: directory), source: .service) { $0.service = value }
    }

    func updateFuel(_ change: (inout FuelLog) -> Void) {
        var value = data.fuel
        change(&value)
        commit(value, to: CarStores.fuel(in: directory), source: .fuel) { $0.fuel = value }
    }

    func updateRenewals(_ change: (inout RenewalLog) -> Void) {
        var value = data.renewals
        change(&value)
        commit(value, to: CarStores.renewals(in: directory), source: .renewals) { $0.renewals = value }
        RenewalNotifier.reschedule(value.items)
    }

    func updateTnG(_ change: (inout TnGState) -> Void) {
        var value = data.tng
        change(&value)
        commit(value, to: CarStores.tng(in: directory), source: .tng) { $0.tng = value }
    }

    // MARK: Phase 3

    func updateParking(_ change: (inout ParkingState) -> Void) {
        var value = data.parking
        change(&value)
        commit(value, to: LiveStores.parking(in: directory), source: .parking) { $0.parking = value }
    }

    func updateCommute(_ change: (inout CommuteSettings) -> Void) {
        var value = data.commute
        change(&value)
        commit(value, to: LiveStores.commute(in: directory), source: .commute) { $0.commute = value }
        Task { await refresh(.commute, force: true) }
    }

    func updatePrayerSettings(_ change: (inout PrayerSettings) -> Void) {
        var value = data.prayerSettings
        change(&value)
        let service = PrayerService(directory: directory)
        do {
            try service.saveSettings(value)
            data.prayerSettings = value
            lastError = nil
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
            return
        }
        Task { await refresh(.prayer) }
    }

    /// Re-reads every file (e.g. after the Save Parking shortcut ran in the background).
    func reload() {
        data = CarData.load(from: directory)
        isSampleData = SampleMode.isOn(in: directory)
    }

    /// Settings → Sample data (spec §10): the app and every widget show `SampleData` while it's on.
    private(set) var isSampleData = SampleMode.isOn()

    func setSampleData(_ on: Bool) {
        SampleMode.set(on, in: directory)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Fetches fresh live data (prayer, commute, weather), then redraws the affected widgets.
    func refresh(_ source: DataSource, force: Bool = false) async {
        isRefreshing.insert(source)
        await LiveRefresher.refresh(source, directory: directory, force: force)
        isRefreshing.remove(source)
        reload()
        reloadWidgets(for: source)
    }

    /// Renders map previews for the app at the given sizes, then reloads the map widgets.
    func refreshMap(sizes: [CGSize], force: Bool = false) async {
        isRefreshing.insert(.map)
        for size in sizes {
            await MapSnapshotRenderer.ensure(size: size, directory: directory, force: force)
        }
        isRefreshing.remove(.map)
        reload()
        reloadWidgets(for: .map)
    }

    var isRefreshing: Set<DataSource> = []

    // MARK: Phase 4

    func updatePhotos(_ change: (inout PhotoLibraryState) -> Void) {
        var value = data.photos
        change(&value)
        commit(value, to: MediaStores.photos(in: directory), source: .photos) { $0.photos = value }
    }

    func updateMusic(_ change: (inout MusicCache) -> Void) {
        var value = data.music
        change(&value)
        commit(value, to: MediaStores.music(in: directory), source: .music) { $0.music = value }
    }

    /// Downsamples and adds picked photos. Returns how many were added.
    func addPhotos(_ images: [Data], toAlbum albumID: UUID?) -> Int {
        let folder = MediaStores.photosFolder(in: directory)
        var added: [PhotoItem] = []
        let room = max(0, PhotoLibraryState.maxPhotos - data.photos.photos.count)
        for imageData in images.prefix(room) {
            guard let jpeg = ImageDownsampler.jpeg(from: imageData, maxPixelSize: 1_000) else { continue }
            let item = PhotoItem(fileName: "\(UUID().uuidString).jpg", addedAt: .now)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try jpeg.write(to: folder.appending(path: item.fileName, directoryHint: .notDirectory), options: .atomic)
                added.append(item)
            } catch {
                lastError = "Couldn't save a photo: \(error.localizedDescription)"
            }
        }
        guard !added.isEmpty else { return 0 }
        updatePhotos { library in
            library.photos += added
            if let albumID, let index = library.albums.firstIndex(where: { $0.id == albumID }) {
                library.albums[index].photoIDs += added.map(\.id)
            }
        }
        return added.count
    }

    func deletePhotos(_ ids: Set<UUID>) {
        var files: [String] = []
        updatePhotos { files = $0.remove(photoIDs: ids) }
        let folder = MediaStores.photosFolder(in: directory)
        for file in files {
            try? FileManager.default.removeItem(at: folder.appending(path: file, directoryHint: .notDirectory))
        }
    }

    /// Refreshes the cached Music card (only when Apple Music access was granted).
    func refreshMusic() async {
        guard MusicLoader.isAuthorized else { return }
        isRefreshing.insert(.music)
        let result = await MusicLoader.load(cache: data.music, directory: directory)
        isRefreshing.remove(.music)
        updateMusic { cache in
            switch result {
            case .success(let item):
                cache.item = item
                cache.lastError = nil
            case .failure(let error):
                cache.lastError = error.localizedDescription
            }
        }
    }

    private func commit<Value: Codable & Sendable>(
        _ value: Value,
        to store: JSONFileStore<Value>,
        source: DataSource,
        apply: (inout CarData) -> Void
    ) {
        do {
            try store.save(value)
            apply(&data)
            lastError = nil
            reloadWidgets(for: source)
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    func reloadWidgets(for source: DataSource) {
        let slots = SlotStore(directory: directory).load()
        let studio = StudioStores.studio(in: directory).load()
        for affected in source.affectedSources {
            WidgetCenter.shared.reloadTimelines(ofKind: affected.widgetKind)
            // Slots showing it directly, in a rotation, or through a Studio design's data field.
            for slot in SlotsState.slotNumbers where SlotTimeline.sources(slot: slot, state: slots, studio: studio).contains(affected) {
                WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
            }
        }
    }
}

/// Local reminders 30 and 7 days before each renewal, at 09:00.
enum RenewalNotifier {
    static let identifierPrefix = "renewal-"

    static func reschedule(_ items: [Renewal]) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
                let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: stale)

                let calendar = Calendar.current
                let now = Date()
                for item in items {
                    for reminder in RenewalRules.reminderDates(for: item.expiry, now: now, calendar: calendar) {
                        let content = UNMutableNotificationContent()
                        content.title = "\(item.displayName) renews in \(reminder.daysBefore) days"
                        content.body = "Expires on \(item.expiry.formatted(date: .long, time: .omitted))."
                        content.sound = .default
                        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                        let request = UNNotificationRequest(
                            identifier: "\(identifierPrefix)\(item.id.uuidString)-\(reminder.daysBefore)",
                            content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        )
                        center.add(request, withCompletionHandler: nil)
                    }
                }
            }
        }
    }
}
