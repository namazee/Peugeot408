import CoreLocation
import EventKit
import Foundation
import MapKit
import WeatherKit

/// WeatherKit: current conditions and the next 24 hours.
public enum WeatherFetcher {
    public static func fetch(at point: GeoPoint) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let (current, hourly) = try await WeatherService.shared.weather(for: location, including: .current, .hourly)
        let hours = hourly.forecast.prefix(24).map { hour in
            HourForecast(
                date: hour.date,
                temperatureC: hour.temperature.converted(to: .celsius).value,
                precipitationChance: hour.precipitationChance,
                symbol: hour.symbolName,
                isRain: hour.precipitation == .rain || hour.precipitation == .mixed
            )
        }
        return WeatherSnapshot(
            observedAt: current.date,
            temperatureC: current.temperature.converted(to: .celsius).value,
            symbol: current.symbolName,
            condition: current.condition.description,
            isRainingNow: current.precipitationIntensity.value > 0,
            hours: Array(hours)
        )
    }
}

/// MapKit driving time with live traffic.
public enum CommuteFetcher {
    public static func travelTime(from origin: GeoPoint, to destination: GeoPoint, departing: Date = .now) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = mapItem(origin)
        request.destination = mapItem(destination)
        request.transportType = .automobile
        request.departureDate = departing
        let response = try await MKDirections(request: request).calculateETA()
        return response.expectedTravelTime
    }

    static func mapItem(_ point: GeoPoint) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)))
    }
}

/// EventKit. The app asks for access; the widget reads directly when access was granted,
/// otherwise it uses the copy the app cached in `calendar.json`.
public enum CalendarReader {
    public static var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Timed (not all-day) events that haven't ended, starting within `hours`.
    public static func upcoming(from date: Date = .now, hours: Double = 36) -> [CachedEvent] {
        guard hasFullAccess else { return [] }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: date.addingTimeInterval(-12 * 3600), end: date.addingTimeInterval(hours * 3600), calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > date }
            .sorted { $0.startDate < $1.startDate }
            .prefix(20)
            .map { CachedEvent(title: $0.title ?? "Event", start: $0.startDate, end: $0.endDate, location: $0.location) }
    }

    /// Reads the calendar (if allowed) and saves the copy widgets use.
    @discardableResult
    public static func refreshCache(directory: URL = AppGroup.containerURL, now: Date = .now) -> CalendarCache? {
        guard hasFullAccess else { return nil }
        let cache = CalendarCache(events: upcoming(from: now), updatedAt: now)
        try? LiveStores.calendar(in: directory).save(cache)
        return cache
    }
}

/// Refreshes the cached files behind the live widgets. Called by the widget providers before
/// they build a timeline, and by the app when a screen opens. Each source throttles itself so
/// widget reloads don't burn through WeatherKit, WAQI or MapKit quotas.
public enum LiveRefresher {
    public static let weatherInterval: TimeInterval = 30 * 60
    public static let airInterval: TimeInterval = 30 * 60
    public static let commuteInterval: TimeInterval = 15 * 60

    public static func refresh(_ source: DataSource, directory: URL = AppGroup.containerURL, force: Bool = false, now: Date = .now, mapSize: CGSize? = nil) async {
        switch source {
        case .prayer:
            await PrayerService(directory: directory).refreshIfNeeded(now: now, force: force)
        case .weather:
            await refreshWeather(directory: directory, force: force, now: now)
        case .commute:
            await refreshCommute(directory: directory, force: force, now: now)
        case .map:
            if let mapSize {
                await MapSnapshotRenderer.ensure(size: mapSize, directory: directory, now: now, force: force)
            }
        case .service, .fuel, .renewals, .tng, .parking, .photos, .music:
            break
        }
    }

    // MARK: Weather & haze

    static func refreshWeather(directory: URL, force: Bool, now: Date) async {
        let store = LiveStores.weather(in: directory)
        var cache = store.load()
        let weatherDue = force || (cache.weatherFetchedAt ?? .distantPast) < now.addingTimeInterval(-weatherInterval)
        let airDue = force || (cache.airFetchedAt ?? .distantPast) < now.addingTimeInterval(-airInterval)
        guard weatherDue || airDue else { return }

        guard let place = await weatherPlace(directory: directory) else {
            cache.weatherError = "No location yet. Open the app once, or set Home in Commute."
            try? store.save(cache)
            return
        }
        cache.point = place.point
        cache.placeLabel = place.label

        if weatherDue {
            do {
                cache.weather = try await WeatherFetcher.fetch(at: place.point)
                cache.weatherFetchedAt = now
                cache.weatherError = nil
            } catch {
                cache.weatherError = error.localizedDescription
                // Back off for 10 minutes before trying again.
                cache.weatherFetchedAt = now.addingTimeInterval(-weatherInterval + 600)
            }
        }
        if airDue {
            if let provider = AirQualityProviders.current() {
                do {
                    cache.air = try await provider.fetch(at: place.point, session: .shared)
                    cache.airFetchedAt = now
                    cache.airError = nil
                } catch {
                    cache.airError = error.localizedDescription
                    cache.airFetchedAt = now.addingTimeInterval(-airInterval + 600)
                }
            } else {
                cache.airError = AirQualityError.noToken.localizedDescription
            }
        }
        try? store.save(cache)
    }

    /// Current location, else last known, else Home, else Work.
    static func weatherPlace(directory: URL) async -> (point: GeoPoint, label: String)? {
        if let best = await LocationFallback.bestKnown(directory: directory) {
            return (best.point, best.isCurrent ? "Current location" : "Last known location")
        }
        let commute = LiveStores.commute(in: directory).load()
        if let home = commute.home { return (home.point, home.name) }
        if let work = commute.work { return (work.point, work.name) }
        return nil
    }

    // MARK: Commute

    static func refreshCommute(directory: URL, force: Bool, now: Date) async {
        CalendarReader.refreshCache(directory: directory, now: now)

        let settings = LiveStores.commute(in: directory).load()
        guard let destination = CommuteRules.destination(at: now, settings: settings),
              let place = settings.place(destination) else { return }
        let store = LiveStores.commuteCache(in: directory)
        var file = store.load()
        if !force, let latest = file.latest, latest.destination == destination,
           latest.computedAt > now.addingTimeInterval(-commuteInterval) {
            return
        }

        // From where the phone is; if that's unknown, from the other saved place.
        var origin: GeoPoint?
        var fromCurrent = false
        if let current = await LocationService.current(timeout: 6, directory: directory) {
            origin = current
            fromCurrent = true
        } else {
            origin = settings.place(destination.other)?.point
        }
        guard let origin else {
            file.lastError = "Set both Home and Work, or allow location."
            try? store.save(file)
            return
        }
        if origin.distance(to: place.point) < 300 {
            // Already there.
            file.latest = CommuteCache(destination: destination, travelSeconds: 0, computedAt: now, fromCurrentLocation: fromCurrent)
            file.lastError = nil
            try? store.save(file)
            return
        }
        do {
            let seconds = try await CommuteFetcher.travelTime(from: origin, to: place.point, departing: now)
            file.latest = CommuteCache(destination: destination, travelSeconds: seconds, computedAt: now, fromCurrentLocation: fromCurrent)
            file.lastError = nil
        } catch {
            file.lastError = error.localizedDescription
        }
        try? store.save(file)
    }
}
