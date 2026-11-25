import AppIntents
import CarKit
import Foundation

/// "Start Drive Session" (spec §4 item 5): for the "When CarPlay connects" automation. Connects to
/// the saved dongle and starts the Live Activity, also while DashCraft runs in the background.
struct StartDriveSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Start Drive Session" }
    static var description: IntentDescription {
        IntentDescription("Connects to your OBD2 dongle and shows live values on the car screen and the Lock Screen.")
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let problem = await DriveSession.shared.startFromShortcut() {
            throw DriveIntentError(message: problem)
        }
        return .result()
    }
}

/// "Stop Drive Session": for the "When CarPlay disconnects" automation.
struct StopDriveSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Stop Drive Session" }
    static var description: IntentDescription {
        IntentDescription("Ends the running drive session and disconnects the OBD2 dongle.")
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        let session = DriveSession.shared
        if session.isRunning { await session.stop() }
        return .result()
    }
}

struct DriveIntentError: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}
