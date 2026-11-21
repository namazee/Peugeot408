import CarKit
import CoreBluetooth
import Foundation
import Observation

/// A BLE ELM327-type dongle: scan, connect, find the serial characteristics, send AT/OBD commands
/// and read replies up to the `>` prompt. All CoreBluetooth callbacks arrive on the main queue.
@MainActor
@Observable
final class OBDLink: NSObject {
    enum State: Equatable {
        case idle
        case bluetoothOff
        case unauthorized
        case scanning
        case connecting
        case ready
        case failed(String)

        var text: String {
            switch self {
            case .idle: "Not connected"
            case .bluetoothOff: "Bluetooth is off"
            case .unauthorized: "Bluetooth permission is off (Settings → DashCraft)"
            case .scanning: "Scanning…"
            case .connecting: "Connecting…"
            case .ready: "Connected"
            case .failed(let message): message
            }
        }
    }

    struct Found: Identifiable, Equatable {
        let id: UUID
        let name: String
        var rssi: Int
    }

    enum LinkError: Error, LocalizedError {
        case notReady
        case timeout(String)

        var errorDescription: String? {
            switch self {
            case .notReady: "The dongle isn't connected."
            case .timeout(let command): "No reply to \(command)."
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var found: [Found] = []

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var writeCharacteristic: CBCharacteristic?
    @ObservationIgnored private var notifyCharacteristic: CBCharacteristic?
    @ObservationIgnored private var profile: OBDAdapterProfile = .fff0
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var buffer = ""
    @ObservationIgnored private var pending: CheckedContinuation<String, Error>?
    @ObservationIgnored private var connectWaiters: [CheckedContinuation<Bool, Never>] = []
    @ObservationIgnored private var poweredOnWaiters: [CheckedContinuation<Void, Never>] = []

    private func makeCentral() -> CBCentralManager {
        if let central { return central }
        let manager = CBCentralManager(delegate: self, queue: nil)
        central = manager
        return manager
    }

    private func waitForPowerOn() async -> Bool {
        let manager = makeCentral()
        if manager.state == .unknown || manager.state == .resetting {
            await withCheckedContinuation { poweredOnWaiters.append($0) }
        }
        switch manager.state {
        case .poweredOn: return true
        case .unauthorized: state = .unauthorized; return false
        default: state = .bluetoothOff; return false
        }
    }

    // MARK: Scan

    func startScan() async {
        guard await waitForPowerOn(), let central else { return }
        found = []
        state = .scanning
        // Many adapters don't advertise their service, so scan for everything and show names.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.stopScan()
        }
    }

    func stopScan() {
        central?.stopScan()
        if state == .scanning { state = .idle }
    }

    // MARK: Connect

    /// Connects to a remembered or picked dongle and runs the ELM327 setup. Returns true when ready.
    func connect(id: UUID, profile: OBDAdapterProfile) async -> Bool {
        guard await waitForPowerOn(), let central else { return false }
        stopScan()
        self.profile = profile
        guard let target = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else {
            state = .failed("Dongle not found. Plug it in, turn the ignition on and scan again.")
            return false
        }
        peripherals[id] = target
        peripheral = target
        target.delegate = self
        state = .connecting
        let connected = await withCheckedContinuation { continuation in
            connectWaiters.append(continuation)
            central.connect(target)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                self?.resolveConnect(false, message: "The dongle didn't answer. Is the ignition on?")
            }
        }
        guard connected else { return false }
        do {
            for command in OBDCommand.initSequence {
                _ = try await send(command, timeout: command == "ATZ" ? 4 : 2)
            }
            state = .ready
            return true
        } catch {
            state = .failed("The dongle didn't accept the setup commands (\(error.localizedDescription)). Check the UUIDs.")
            return false
        }
    }

    func disconnect() {
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        failPending(LinkError.notReady)
        state = .idle
    }

    private func resolveConnect(_ ok: Bool, message: String? = nil) {
        guard !connectWaiters.isEmpty else { return }
        if !ok, let message { state = .failed(message) }
        let waiters = connectWaiters
        connectWaiters = []
        waiters.forEach { $0.resume(returning: ok) }
    }

    // MARK: Commands

    /// Sends a command and returns the reply text (without the `>` prompt).
    func send(_ command: String, timeout: TimeInterval = 2.5) async throws -> String {
        guard let peripheral, let writeCharacteristic else { throw LinkError.notReady }
        failPending(LinkError.timeout("previous command"))
        buffer = ""
        let data = Data((command + "\r").utf8)
        let type: CBCharacteristicWriteType = writeCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            peripheral.writeValue(data, for: writeCharacteristic, type: type)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.failPending(LinkError.timeout(command))
            }
        }
    }

    private func failPending(_ error: Error) {
        guard let pending else { return }
        self.pending = nil
        pending.resume(throwing: error)
    }

    private func received(_ text: String) {
        buffer += text
        guard buffer.contains(">") else { return }
        let reply = buffer.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        if let pending {
            self.pending = nil
            pending.resume(returning: reply)
        }
    }

    // MARK: CBCentralManagerDelegate / CBPeripheralDelegate
    // The manager uses the main queue, so these run on the main actor (`@preconcurrency`
    // conformance below checks that at run time).

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let waiters = poweredOnWaiters
        poweredOnWaiters = []
        waiters.forEach { $0.resume() }
        if central.state != .poweredOn, state == .ready || state == .connecting { state = .bluetoothOff }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        // Unnamed devices are almost never OBD dongles; skip them to keep the list short.
        guard let name, !name.isEmpty else { return }
        peripherals[peripheral.identifier] = peripheral
        if let index = found.firstIndex(where: { $0.id == peripheral.identifier }) {
            found[index].rssi = RSSI.intValue
        } else {
            found.append(Found(id: peripheral.identifier, name: name, rssi: RSSI.intValue))
            found.sort { Self.likelyDongle($0.name) && !Self.likelyDongle($1.name) }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let services = profile.isValid ? [CBUUID(string: profile.serviceUUID)] : nil
        peripheral.discoverServices(services)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        resolveConnect(false, message: error?.localizedDescription ?? "Couldn't connect.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        failPending(LinkError.notReady)
        resolveConnect(false, message: "Disconnected.")
        if state == .ready { state = .failed("The dongle disconnected.") }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let services = peripheral.services, !services.isEmpty else {
            resolveConnect(false, message: "The dongle doesn't have the service \(profile.serviceUUID). Try another UUID preset.")
            return
        }
        services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        for characteristic in service.characteristics ?? [] {
            let uuid = characteristic.uuid.uuidString.uppercased()
            if uuid == profile.notifyUUID.uppercased() || (notifyCharacteristic == nil && characteristic.properties.contains(.notify)) {
                notifyCharacteristic = characteristic
            }
            if uuid == profile.writeUUID.uppercased() || (writeCharacteristic == nil && (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse))) {
                writeCharacteristic = characteristic
            }
        }
        if let notifyCharacteristic, writeCharacteristic != nil {
            peripheral.setNotifyValue(true, for: notifyCharacteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        resolveConnect(error == nil && characteristic.isNotifying, message: "Couldn't subscribe to the dongle's replies.")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard let data = characteristic.value, let text = String(data: data, encoding: .ascii) else { return }
        received(text)
    }

    static func likelyDongle(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["obd", "elm", "vgate", "icar", "vlink", "obdlink", "v-link", "konnwei", "veepeak"].contains { lower.contains($0) }
    }
}

extension OBDLink: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {}
