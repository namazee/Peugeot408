import CarKit
import Foundation

/// App Store screenshots (spec §10 Store listing). The `StoreScreenshots` UI test launches the app
/// with `-screenshots` plus a few flags; a normal launch never has them.
enum ScreenshotMode {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isOn: Bool { arguments.contains("-screenshots") }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static var tab: AppTab? {
        switch value(after: "-screenshotTab") {
        case "slots": .slots
        case "studio": .studio
        case "car": .car
        case "daily": .daily
        case "settings": .settings
        default: nil
        }
    }

    static var look: CardLook? { value(after: "-screenshotLook").flatMap(CardLook.init(rawValue:)) }

    /// Panorama hero on (true) or off (false); nil leaves it as it is.
    static var panorama: Bool? { value(after: "-screenshotPanorama").map { $0 == "on" } }
}
