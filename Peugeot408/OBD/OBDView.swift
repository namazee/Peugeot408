import CarKit
import SwiftUI

/// Car → Live OBD2.
struct OBDView: View {
    @Environment(DriveSession.self) private var session
    @Environment(CarDataModel.self) private var cars
    @State private var demo = false

    var body: some View {
        List {
            Section {
                let reading = session.reading
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        OBDTile(value: .boost, reading: reading, big: 30, unsupported: session.unsupported.contains(.boost))
                        OBDTile(value: .rpm, reading: reading, big: 30, unsupported: session.unsupported.contains(.rpm))
                    }
                    HStack(spacing: 12) {
                        OBDTile(value: .coolant, reading: reading, big: 30, unsupported: session.unsupported.contains(.coolant))
                        OBDTile(value: .voltage, reading: reading, big: 30, unsupported: session.unsupported.contains(.voltage))
                    }
                }
                .padding(.vertical, 6)
                LabeledContent("Status", value: session.status)
                if let reading, !session.isRunning {
                    LabeledContent("Last read", value: reading.date.formatted(date: .abbreviated, time: .shortened))
                }
                if let error = session.lastError {
                    Text(error).font(.footnote).foregroundStyle(Theme.overdue)
                }
            } footer: {
                if !session.unsupported.isEmpty {
                    Text("Your car didn't report \(session.unsupported.map(\.displayName).sorted().joined(separator: ", ")), so it shows n/a. Some cars' ECUs don't answer every standard PID.")
                }
            }

            Section {
                if session.isRunning {
                    Button(role: .destructive) {
                        Task { await session.stop(); cars.reload() }
                    } label: {
                        Label("Stop drive session", systemImage: "stop.circle.fill")
                    }
                } else {
                    Toggle("Demo mode (no dongle)", isOn: $demo)
                    Button {
                        Task { await session.start(demo: demo) }
                    } label: {
                        Label("Start drive session", systemImage: "play.circle.fill")
                    }
                }
            } footer: {
                Text("While a session runs, a Live Activity shows the values on the Lock Screen and in CarPlay. Keep DashCraft open or in the background; the last values are saved for the Live OBD2 widget.")
            }

            Section {
                NavigationLink {
                    DongleView()
                } label: {
                    LabeledContent {
                        Text(session.state.peripheralName ?? "None").foregroundStyle(Theme.secondaryText)
                    } label: {
                        Label("OBD2 dongle", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            } footer: {
                Text("Needs a Bluetooth LE (4.0+) ELM327-compatible dongle, e.g. OBDLink CX or Vgate iCar Pro BLE. Classic-Bluetooth dongles don't work with iPhone.")
            }

            CardPreviewSection(card: cars.card(for: .obd))
        }
        .navigationTitle("Live OBD2")
    }
}

/// Settings → OBD2 dongle: scan, pick, UUIDs, poll rate.
struct DongleView: View {
    @Environment(DriveSession.self) private var session
    @State private var profile = OBDAdapterProfile.fff0
    @State private var pollInterval = 1.5
    @State private var saved: UUID?
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await session.link.startScan() }
                } label: {
                    Label(session.link.state == .scanning ? "Scanning…" : "Scan for dongles", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(session.isRunning)
                ForEach(session.link.found) { device in
                    Button {
                        session.updateState {
                            $0.peripheralID = device.id
                            $0.peripheralName = device.name
                        }
                        saved = device.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name).font(.headline)
                                Text("Signal \(device.rssi) dBm").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            if saved == device.id { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if session.link.state != .scanning && session.link.state != .idle {
                    Text(session.link.state.text).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            } header: {
                Text("Dongle")
            } footer: {
                Text("Plug the dongle into the OBD2 port (under the dashboard, driver's side) and switch the ignition on. Likely dongles are listed first.")
            }

            Section {
                Picker("Preset", selection: preset) {
                    ForEach(OBDAdapterProfile.presets, id: \.self) { Text($0.name).tag(Optional($0)) }
                    Text("Custom").tag(OBDAdapterProfile?.none)
                }
                UUIDField(title: "Service", text: $profile.serviceUUID)
                UUIDField(title: "Notify", text: $profile.notifyUUID)
                UUIDField(title: "Write", text: $profile.writeUUID)
                if !profile.isValid {
                    Text("Use 4 hex digits (FFF0) or a full UUID.").font(.footnote).foregroundStyle(Theme.overdue)
                }
                Button("Save UUIDs") { session.updateState { $0.profile = profile } }
                    .disabled(!profile.isValid || profile == session.state.profile)
            } header: {
                Text("Bluetooth UUIDs")
            } footer: {
                Text("Most BLE ELM327 dongles (and OBDLink CX) use FFF0/FFF1/FFF2. Vgate iCar Pro BLE uses its own UUIDs. If connecting fails, try the other preset.")
            }

            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Read every", value: String(format: "%.1f s", pollInterval))
                    Slider(value: $pollInterval, in: 0.5...5, step: 0.5, onEditingChanged: { editing in
                        if !editing { session.updateState { $0.pollInterval = pollInterval } }
                    })
                }
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Label("Test connection", systemImage: "bolt.horizontal.circle")
                        if testing { Spacer(); ProgressView() }
                    }
                }
                .disabled(saved == nil || testing || session.isRunning)
                if let testResult { Text(testResult).font(.footnote) }
            } footer: {
                Text("A modest rate keeps the dongle and the Live Activity responsive.")
            }
        }
        .navigationTitle("OBD2 dongle")
        .onAppear {
            let state = session.state
            profile = state.profile
            pollInterval = state.pollInterval
            saved = state.peripheralID
        }
        .onDisappear { session.link.stopScan() }
    }

    private var preset: Binding<OBDAdapterProfile?> {
        Binding(
            get: { OBDAdapterProfile.presets.first { $0.serviceUUID == profile.serviceUUID && $0.notifyUUID == profile.notifyUUID && $0.writeUUID == profile.writeUUID } },
            set: { if let value = $0 { profile = value } else { profile.name = "Custom" } }
        )
    }

    private func test() async {
        guard let id = saved else { return }
        testing = true
        defer { testing = false }
        session.updateState { $0.profile = profile }
        guard await session.link.connect(id: id, profile: profile) else {
            testResult = session.link.state.text
            return
        }
        let volts = (try? await session.link.send(OBDCommand.voltage.rawValue)).flatMap { try? OBDParser.voltage($0) }
        let rpmReply = try? await session.link.send(OBDCommand.rpm.rawValue, timeout: 6)
        let rpm = rpmReply.flatMap { try? OBDParser.dataBytes(for: OBDCommand.rpm.rawValue, in: $0) }.flatMap { try? OBDParser.rpm($0) }
        session.link.disconnect()
        testResult = "Connected. Battery \(volts.map { String(format: "%.1f V", $0) } ?? "--"), RPM \(rpm.map(String.init) ?? "no answer (ignition on?)")."
    }
}

private struct UUIDField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("FFF0", text: $text)
                .multilineTextAlignment(.trailing)
                .font(.footnote.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }
}
