import ActivityKit
import CarKit
import Foundation
import Observation
import WidgetKit

/// Runs a drive session: polls the dongle (or the demo), shows the values in a Live Activity
/// (which CarPlay displays) and keeps the last values in the App Group for the OBD2 widget.
@MainActor
@Observable
final class DriveSession {
    private(set) var isRunning = false
    private(set) var isDemo = false
    private(set) var reading: OBDReading?
    private(set) var status = "Not running"
    private(set) var unsupported: Set<OBDValue> = []
    var lastError: String?

    let link = OBDLink()

    @ObservationIgnored private var task: Task<Void, Never>?
    /// `Activity` isn't Sendable, so it is only touched from the nonisolated helpers below
    /// (and assigned on the main actor before any of them run).
    @ObservationIgnored nonisolated(unsafe) private var activity: Activity<DriveActivityAttributes>?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var lastActivityUpdate = Date.distantPast
    @ObservationIgnored private var lastSave = Date.distantPast
    /// Barometric pressure is read once per session (it barely changes); sea level until then.
    @ObservationIgnored private var barometricKPa = OBDParser.standardBarometricKPa
    @ObservationIgnored private var misses: [OBDValue: Int] = [:]

    /// Live Activity updates are rate-limited by iOS; every 2 s is plenty for glancing.
    static let activityInterval: TimeInterval = 2

    init(directory: URL = AppGroup.containerURL) {
        self.directory = directory
        let saved = OBDStores.state(in: directory).load()
        reading = saved.last
        unsupported = saved.unsupported
        if saved.sessionActive {
            // The app was closed mid-session; mark it stopped.
            updateState { $0.sessionActive = false }
        }
    }

    var state: OBDState { OBDStores.state(in: directory).load() }

    func updateState(_ change: (inout OBDState) -> Void) {
        var value = OBDStores.state(in: directory).load()
        change(&value)
        try? OBDStores.state(in: directory).save(value)
    }

    // MARK: Start / stop

    func start(demo: Bool) async {
        guard !isRunning else { return }
        lastError = nil
        isDemo = demo
        misses = [:]
        barometricKPa = OBDParser.standardBarometricKPa
        let started = Date()

        if !demo {
            let saved = state
            guard let id = saved.peripheralID else {
                lastError = "Pick your dongle first (Scan for dongles)."
                return
            }
            status = "Connecting…"
            guard await link.connect(id: id, profile: saved.profile) else {
                lastError = link.state.text
                status = "Not running"
                return
            }
            unsupported = []
        }

        isRunning = true
        status = demo ? "Demo" : "Live"
        updateState { $0.sessionActive = true }
        startActivity(startedAt: started, demo: demo)
        WidgetCenter.shared.reloadTimelines(ofKind: DataSource.obd.widgetKind)

        task = Task { [weak self] in
            await self?.loop(started: started)
        }
    }

    func stop() async {
        task?.cancel()
        task = nil
        if !isDemo { link.disconnect() }
        isRunning = false
        status = "Stopped"
        save(force: true, sessionActive: false)
        let final = DriveActivityAttributes.ContentState(reading: reading ?? OBDReading(date: .now), status: "Ended")
        await endActivity(final)
        reloadWidgets()
    }

    // MARK: Loop

    private func loop(started: Date) async {
        var cycle = 0
        while !Task.isCancelled {
            let interval = max(state.pollInterval, 0.5)
            let next: OBDReading
            if isDemo {
                next = OBDDemo.reading(at: .now, sessionStart: started)
            } else {
                next = await pollOnce(cycle: cycle)
                if link.state != .ready {
                    status = "Dongle disconnected"
                    lastError = link.state.text
                    await stop()
                    return
                }
            }
            reading = next
            await pushActivity()
            save(force: false, sessionActive: true)
            cycle += 1
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    /// One poll of every supported PID (barometric once at the start, voltage every 5th cycle).
    private func pollOnce(cycle: Int) async -> OBDReading {
        var result = OBDReading(
            rpm: reading?.rpm, coolantC: reading?.coolantC, boostBar: reading?.boostBar, voltage: reading?.voltage, date: .now
        )
        if !unsupported.contains(.rpm), let bytes = await ask(.rpm, for: .rpm) {
            result.rpm = try? OBDParser.rpm(bytes)
        }
        if cycle % 3 == 0, !unsupported.contains(.coolant), let bytes = await ask(.coolant, for: .coolant) {
            result.coolantC = try? OBDParser.coolant(bytes)
        }
        if cycle == 0, let bytes = await ask(.barometric, for: nil), let baro = try? OBDParser.kilopascals(bytes), (80...110).contains(baro) {
            barometricKPa = baro
        }
        if !unsupported.contains(.boost), let bytes = await ask(.intakePressure, for: .boost), let map = try? OBDParser.kilopascals(bytes) {
            result.boostBar = OBDParser.boostBar(manifoldKPa: map, barometricKPa: barometricKPa)
        }
        if cycle % 5 == 0, !unsupported.contains(.voltage) {
            if let reply = try? await link.send(OBDCommand.voltage.rawValue), let volts = try? OBDParser.voltage(reply) {
                result.voltage = volts
                misses[.voltage] = 0
            } else {
                miss(.voltage)
            }
        }
        status = unsupported.isEmpty ? "Live" : "Live · \(unsupported.count) not reported"
        return result
    }

    /// Sends a mode-01 PID. Two "NO DATA" answers in a row mark the value as not supported by
    /// this car (not every ECU reports every PID), so it stops being polled.
    private func ask(_ command: OBDCommand, for value: OBDValue?) async -> [UInt8]? {
        do {
            let reply = try await link.send(command.rawValue, timeout: 2.5)
            let bytes = try OBDParser.dataBytes(for: command.rawValue, in: reply)
            if let value { misses[value] = 0 }
            return bytes
        } catch OBDParseError.unsupported {
            if let value { miss(value) }
            return nil
        } catch {
            return nil
        }
    }

    private func miss(_ value: OBDValue) {
        misses[value, default: 0] += 1
        if misses[value, default: 0] >= 2 {
            unsupported.insert(value)
        }
    }

    // MARK: Live Activity and widget

    private func startActivity(startedAt: Date, demo: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "Live Activities are off for DashCraft (Settings → DashCraft → Live Activities)."
            return
        }
        let initial = DriveActivityAttributes.ContentState(reading: reading ?? OBDReading(date: .now), status: demo ? "Demo" : "Live")
        do {
            activity = try Activity.request(
                attributes: DriveActivityAttributes(startedAt: startedAt, isDemo: demo),
                content: ActivityContent(state: initial, staleDate: .now.addingTimeInterval(120)),
                pushType: nil
            )
        } catch {
            lastError = "Couldn't start the Live Activity: \(error.localizedDescription)"
        }
    }

    private func pushActivity() async {
        guard activity != nil, let reading, Date().timeIntervalSince(lastActivityUpdate) >= Self.activityInterval else { return }
        lastActivityUpdate = .now
        let content = DriveActivityAttributes.ContentState(reading: reading, status: status)
        await updateActivity(content)
    }

    /// Stale after 2 minutes without updates (e.g. the app was suspended).
    nonisolated private func updateActivity(_ state: DriveActivityAttributes.ContentState) async {
        await activity?.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(120)))
    }

    /// Ends the Live Activity; it stays on the Lock Screen for 15 minutes with the final values.
    nonisolated private func endActivity(_ state: DriveActivityAttributes.ContentState) async {
        let current = activity
        activity = nil
        await current?.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now.addingTimeInterval(15 * 60)))
    }

    /// Saves the last values (every 10 s while running) so the OBD2 widget shows them with a time.
    private func save(force: Bool, sessionActive: Bool) {
        guard force || Date().timeIntervalSince(lastSave) >= 10 else { return }
        lastSave = .now
        let reading = reading
        let demo = isDemo
        let unsupported = unsupported
        updateState {
            $0.last = reading
            $0.lastWasDemo = demo
            $0.unsupported = demo ? $0.unsupported : unsupported
            $0.sessionActive = sessionActive
        }
    }

    private func reloadWidgets() {
        let slots = SlotStore(directory: directory).load()
        let studio = StudioStores.studio(in: directory).load()
        WidgetCenter.shared.reloadTimelines(ofKind: DataSource.obd.widgetKind)
        for slot in SlotsState.slotNumbers where SlotTimeline.sources(slot: slot, state: slots, studio: studio).contains(.obd) {
            WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
        }
    }
}
