import Foundation
import MapKit
import UIKit

/// Renders the Map Snapshot widget image with `MKMapSnapshotter`: dark map, accent pin.
/// One PNG per widget size is kept in the App Group (`map-<w>x<h>.png`) and indexed in `map.json`.
/// An image is re-rendered only when its target moves, or (for the commute view) after 6 hours.
public enum MapSnapshotRenderer {
    public static let commuteMaxAge: TimeInterval = 6 * 3600

    /// Makes sure an up-to-date image exists for `size` (points). Returns its file URL.
    @discardableResult
    public static func ensure(size: CGSize, directory: URL = AppGroup.containerURL, now: Date = .now, force: Bool = false) async -> URL? {
        guard size.width >= 20, size.height >= 20 else { return nil }
        let data = CarData.load(from: directory)
        guard let target = MapTarget.choose(parking: data.parking, commute: data.commute, at: now) else { return nil }

        let sizeKey = MapSnapshotIndex.sizeKey(width: size.width, height: size.height)
        let fileName = "map-\(sizeKey).png"
        let fileURL = directory.appending(path: fileName, directoryHint: .notDirectory)
        let store = LiveStores.map(in: directory)
        var index = store.load()

        if !force, let existing = index.entries[sizeKey], existing.targetKey == target.key,
           FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)),
           target.isParking || now.timeIntervalSince(existing.renderedAt) < commuteMaxAge {
            return fileURL
        }

        guard let png = await render(target: target, size: size) else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: fileURL, options: .atomic)
            index.entries[sizeKey] = MapSnapshotIndex.Entry(fileName: fileName, targetKey: target.key, renderedAt: now)
            try store.save(index)
            return fileURL
        } catch {
            return nil
        }
    }

    /// PNG data at 2x, small enough for the widget memory limit.
    public static func render(target: MapTarget, size: CGSize) async -> Data? {
        let options = MKMapSnapshotter.Options()
        options.region = region(for: target)
        options.size = size
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection { traits in
            traits.userInterfaceStyle = .dark
            traits.displayScale = 2
        }

        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await MKMapSnapshotter(options: options).start()
        } catch {
            return nil
        }

        let base = snapshot.image
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        let accent = UIColor(red: CGFloat((Theme.Hex.accent >> 16) & 0xFF) / 255, green: CGFloat((Theme.Hex.accent >> 8) & 0xFF) / 255, blue: CGFloat(Theme.Hex.accent & 0xFF) / 255, alpha: 1)

        let image = UIGraphicsImageRenderer(size: base.size, format: format).image { context in
            base.draw(at: .zero)
            switch target {
            case .parking(let point, _):
                drawPin(at: snapshot.point(for: coordinate(point)), symbol: "parkingsign", color: accent, in: context.cgContext)
            case .commute(let destination, let origin, _, let symbol):
                if let origin {
                    let p = snapshot.point(for: coordinate(origin))
                    let dot = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fillEllipse(in: dot)
                }
                drawPin(at: snapshot.point(for: coordinate(destination)), symbol: symbol, color: accent, in: context.cgContext)
            }
        }
        return image.pngData()
    }

    static func region(for target: MapTarget) -> MKCoordinateRegion {
        switch target {
        case .parking(let point, _):
            return MKCoordinateRegion(center: coordinate(point), latitudinalMeters: 700, longitudinalMeters: 700)
        case .commute(let destination, let origin, _, _):
            guard let origin else {
                return MKCoordinateRegion(center: coordinate(destination), latitudinalMeters: 6_000, longitudinalMeters: 6_000)
            }
            let center = CLLocationCoordinate2D(
                latitude: (origin.latitude + destination.latitude) / 2,
                longitude: (origin.longitude + destination.longitude) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max(abs(origin.latitude - destination.latitude) * 1.5, 0.02),
                longitudeDelta: max(abs(origin.longitude - destination.longitude) * 1.5, 0.02)
            )
            return MKCoordinateRegion(center: center, span: span)
        }
    }

    static func coordinate(_ point: GeoPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private static func drawPin(at point: CGPoint, symbol: String, color: UIColor, in context: CGContext) {
        let radius: CGFloat = 13
        let circle = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 4, color: UIColor.black.withAlphaComponent(0.6).cgColor)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circle)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.5)
        context.strokeEllipse(in: circle.insetBy(dx: 1.25, dy: 1.25))

        let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        if let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            let origin = CGPoint(x: point.x - glyph.size.width / 2, y: point.y - glyph.size.height / 2)
            glyph.draw(at: origin)
        }
    }
}
