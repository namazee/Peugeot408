import CarKit
import Foundation
import Observation
import UserNotifications
import WidgetKit

/// App-side owner of the Phase 2 data. Every change is saved to the App Group, then only the
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

    private func reloadWidgets(for source: DataSource) {
        let slots = SlotStore(directory: directory).load()
        for affected in source.affectedSources {
            WidgetCenter.shared.reloadTimelines(ofKind: affected.widgetKind)
            for slot in SlotsState.slotNumbers where slots.design(for: slot).source == affected {
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
