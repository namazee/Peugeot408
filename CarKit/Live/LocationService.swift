import CoreLocation
import Foundation

/// One-shot location for the app and the widget extension.
///
/// In the extension it only works when the app has location permission and the widget
/// Info.plist has `NSWidgetWantsLocation`; otherwise it returns nil quickly and callers fall
/// back to the last saved location or a saved place.
@MainActor
public final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint?, Never>?
    private var requestPermission = false

    private override init() {
        super.init()
    }

    /// Current position, or nil (no permission, no fix within `timeout`).
    /// `askPermission` shows the system prompt in the app when it hasn't been asked yet.
    public static func current(askPermission: Bool = false, timeout: TimeInterval = 8, directory: URL = AppGroup.containerURL) async -> GeoPoint? {
        let service = LocationService()
        let point = await service.fetch(askPermission: askPermission, timeout: timeout)
        if let point {
            try? LiveStores.lastLocation(in: directory).save(LastLocation(point: point, date: .now))
        }
        return point
    }

    nonisolated public static var authorizationStatus: CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    nonisolated public static var isAuthorized: Bool {
        let status = authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private static var isExtension: Bool {
        Bundle.main.bundleURL.pathExtension == "appex"
    }

    private func fetch(askPermission: Bool, timeout: TimeInterval) async -> GeoPoint? {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        if Self.isExtension && (!authorized || !manager.isAuthorizedForWidgetUpdates) { return nil }
        if !authorized && !(status == .notDetermined && askPermission) { return nil }

        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.manager.delegate = self
            if authorized {
                self.manager.requestLocation()
            } else {
                self.requestPermission = true
                self.manager.requestWhenInUseAuthorization()
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish(nil)
            }
        }
    }

    private func finish(_ point: GeoPoint?) {
        guard let continuation else { return }
        self.continuation = nil
        manager.delegate = nil
        continuation.resume(returning: point)
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        guard requestPermission else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            requestPermission = false
            manager.requestLocation()
        case .denied, .restricted:
            finish(nil)
        default:
            break
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let point = locations.last.map { GeoPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        Task { @MainActor in self.finish(point) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(status) }
    }
}

/// Picks the best point for weather and the commute origin.
public enum LocationFallback {
    /// Current position if possible, else the last known one (up to `maxAge`), else nil.
    public static func bestKnown(directory: URL = AppGroup.containerURL, maxAge: TimeInterval = 6 * 3600, timeout: TimeInterval = 6) async -> (point: GeoPoint, isCurrent: Bool)? {
        if let point = await LocationService.current(timeout: timeout, directory: directory) {
            return (point, true)
        }
        if let last = LiveStores.lastLocation(in: directory).load(), Date().timeIntervalSince(last.date) < maxAge {
            return (last.point, false)
        }
        return nil
    }
}
