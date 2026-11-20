import AVFoundation
import CarKit
import SwiftUI
import UniformTypeIdentifiers

/// Studio → Connect sounds.
struct ConnectSoundView: View {
    @State private var settings = SoundStores.settings().load()
    @State private var playing = false
    @State private var message: String?
    @State private var importing = false
    @State private var trimming: TrimSource?

    var body: some View {
        List {
            Section {
                ForEach(settings.allSounds, id: \.self) { sound in
                    HStack {
                        Button {
                            update { $0.defaultSound = sound }
                        } label: {
                            HStack {
                                Image(systemName: symbol(sound)).frame(width: 28).foregroundStyle(Theme.accent)
                                Text(settings.name(of: sound))
                                Spacer()
                                if settings.resolved(nil) == sound {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            Task { await test(sound) }
                        } label: {
                            Image(systemName: "play.circle.fill").font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Play \(settings.name(of: sound))")
                    }
                    .swipeActions {
                        if case .imported(let id) = sound {
                            Button("Delete", role: .destructive) { deleteImported(id) }
                        }
                    }
                }
                Button {
                    importing = true
                } label: {
                    Label("Import your own (up to 5 s)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Sound")
            } footer: {
                Text("All bundled sounds are original, made for this app. Tap a sound to make it the default; ▶ plays it.")
            }

            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Volume", value: "\(Int(settings.clampedVolume * 100))%")
                    Slider(value: binding(\.volume), in: 0.1...1, onEditingChanged: { editing in
                        if !editing { save() }
                    })
                }
                Button {
                    Task { await test(nil) }
                } label: {
                    Label(playing ? "Playing…" : "Test sound", systemImage: "speaker.wave.2.fill")
                }
                .disabled(playing)
                if let message {
                    Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            } footer: {
                Text("Plays through whatever is connected (the car speakers in CarPlay) and lowers other audio while it plays. Volume is relative to the phone's volume.")
            }

            Section {
                TextField("Your name", text: binding(\.greetingName))
                    .onSubmit { save() }
                Picker("Language", selection: binding(\.greetingLanguage)) {
                    ForEach(GreetingLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Says", value: settings.greetingText)
            } header: {
                Text("Spoken greeting")
            } footer: {
                Text("Spoken by the iPhone's built-in voice. If no Malay voice is installed, iOS uses English; add one in Settings → Accessibility → Spoken Content → Voices.")
            }

            Section {
                NavigationLink {
                    AutomationGuideView(kind: .connect)
                } label: {
                    Label("Set up: play when CarPlay connects", systemImage: "car.side.and.exclamationmark")
                }
                NavigationLink {
                    AutomationGuideView(kind: .disconnect)
                } label: {
                    Label("Optional: goodbye + save parking on disconnect", systemImage: "parkingsign.circle")
                }
            } header: {
                Text("Automation")
            } footer: {
                Text("iOS doesn't let apps play sounds by themselves when CarPlay connects, so a Shortcuts automation does it. Set it up once.")
            }
        }
        .navigationTitle("Connect sounds")
        .onDisappear { save() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { Task { await prepareImport(url) } }
        }
        .sheet(item: $trimming) { source in
            TrimView(source: source) { item in
                update { $0.imported.append(item) }
            }
        }
    }

    private func symbol(_ sound: ConnectSoundKind) -> String {
        switch sound {
        case .bundled(let id): BundledSound.all.first { $0.id == id }?.symbol ?? "speaker.wave.2"
        case .imported: "waveform"
        case .greeting: "person.wave.2.fill"
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ConnectSoundSettings, Value>) -> Binding<Value> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
    }

    private func update(_ change: (inout ConnectSoundSettings) -> Void) {
        change(&settings)
        save()
    }

    private func save() {
        do {
            try SoundStores.settings().save(settings)
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func test(_ sound: ConnectSoundKind?) async {
        save()
        playing = true
        defer { playing = false }
        do {
            try await ConnectSoundPlayer.shared.play(sound)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteImported(_ id: UUID) {
        guard let item = settings.imported.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: SoundStores.folder().appending(path: item.fileName, directoryHint: .notDirectory))
        update {
            $0.imported.removeAll { $0.id == id }
            if $0.defaultSound == .imported(id) { $0.defaultSound = .bundled("welcome-tone") }
        }
    }

    /// Copies the picked file locally (it may be security-scoped), then opens the trimmer.
    private func prepareImport(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory.appending(path: "import-\(UUID().uuidString).\(url.pathExtension)", directoryHint: .notDirectory)
        do {
            try FileManager.default.copyItem(at: url, to: local)
            let duration = try await AVURLAsset(url: local).load(.duration).seconds
            guard duration.isFinite, duration > 0.2 else {
                message = "That file has no audio we can use."
                return
            }
            trimming = TrimSource(url: local, name: url.deletingPathExtension().lastPathComponent, duration: duration)
        } catch {
            message = "Couldn't open that file: \(error.localizedDescription)"
        }
    }
}

struct TrimSource: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let duration: Double
}

/// Pick up to 5 seconds of an imported clip, preview it, and save it as AAC in the App Group.
struct TrimView: View {
    let source: TrimSource
    let onSave: (ImportedSound) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start = 0.0
    @State private var length = ConnectSoundSettings.maxClipSeconds
    @State private var name = ""
    @State private var preview: AVAudioPlayer?
    @State private var working = false
    @State private var error: String?

    private var range: ClosedRange<Double> { ClipTrim.range(start: start, length: length, clipDuration: source.duration) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    LabeledContent("Clip length", value: String(format: "%.1f s", source.duration))
                }
                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Start", value: String(format: "%.1f s", range.lowerBound))
                        Slider(value: $start, in: 0...max(source.duration - 0.1, 0.1))
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Length", value: String(format: "%.1f s", range.upperBound - range.lowerBound))
                        Slider(value: $length, in: 0.5...min(ConnectSoundSettings.maxClipSeconds, max(source.duration, 0.6)))
                    }
                    Button("Preview", systemImage: "play.fill") { playPreview() }
                } header: {
                    Text("Trim (5 seconds at most)")
                }
                if let error {
                    Text(error).foregroundStyle(Theme.overdue)
                }
            }
            .navigationTitle("Import sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await export() } }.disabled(working)
                }
            }
            .onAppear { name = source.name }
            .onDisappear { preview?.stop() }
        }
    }

    private func playPreview() {
        preview?.stop()
        guard let player = try? AVAudioPlayer(contentsOf: source.url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.currentTime = range.lowerBound
        player.play()
        preview = player
        let stopAfter = range.upperBound - range.lowerBound
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(stopAfter))
            player.stop()
        }
    }

    private func export() async {
        working = true
        defer { working = false }
        preview?.stop()
        let asset = AVURLAsset(url: source.url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            error = "This file can't be converted."
            return
        }
        let folder = SoundStores.folder()
        let item = ImportedSound(name: name.isEmpty ? source.name : name, fileName: "\(UUID().uuidString).m4a", duration: range.upperBound - range.lowerBound)
        let output = folder.appending(path: item.fileName, directoryHint: .notDirectory)
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
            end: CMTime(seconds: range.upperBound, preferredTimescale: 600)
        )
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await session.export(to: output, as: .m4a)
            onSave(item)
            dismiss()
        } catch {
            self.error = "Couldn't save the clip: \(error.localizedDescription)"
        }
    }
}

/// Step-by-step setup of the Shortcuts automations, with drawn screens of each step.
struct AutomationGuideView: View {
    enum Kind { case connect, disconnect }
    let kind: Kind

    private struct Step: Identifiable {
        let id = UUID()
        let text: String
        let screen: [String]
        let highlight: Int
    }

    private var steps: [Step] {
        let trigger = kind == .connect ? "Connects" : "Disconnects"
        var list = [
            Step(text: "Open the Shortcuts app and tap Automation at the bottom.", screen: ["Shortcuts", "Gallery", "Automation"], highlight: 2),
            Step(text: "Tap + (or New Automation), then choose CarPlay.", screen: ["New Automation", "Time of Day", "Alarm", "CarPlay"], highlight: 3),
            Step(text: "Tick \"\(trigger)\" only, and choose \"Run Immediately\". Turn off \"Notify When Run\" if you like.", screen: ["CarPlay", kind == .connect ? "✓ Connects" : "Connects", kind == .connect ? "Disconnects" : "✓ Disconnects", "Run Immediately"], highlight: 1),
            Step(text: "Tap Next, then New Blank Automation, then Add Action.", screen: ["When CarPlay \(trigger.lowercased())", "New Blank Automation", "Add Action"], highlight: 2),
        ]
        if kind == .connect {
            list.append(Step(text: "Search \"Play Connect Sound\" and pick it (Peugeot408). Leave Sound empty to use the one chosen in the app.", screen: ["Search: Play Connect Sound", "Peugeot408", "▶ Play Connect Sound"], highlight: 2))
        } else {
            list.append(Step(text: "Add \"Play Connect Sound\" and set Sound to Goodbye. Then add \"Save Parking\" (Peugeot408) below it.", screen: ["▶ Play Connect Sound · Goodbye", "+ Add Action", "P Save Parking"], highlight: 2))
        }
        list.append(Step(text: "Tap Done. Next time you plug in (or unplug), it runs by itself.", screen: ["When CarPlay \(trigger.lowercased())", kind == .connect ? "Play Connect Sound" : "Play Connect Sound, Save Parking", "Done"], highlight: 2))
        return list
    }

    var body: some View {
        List {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Theme.number(17))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Theme.accent))
                        Text(step.text)
                    }
                    PhoneScreenSketch(rows: step.screen, highlight: step.highlight)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                Text(kind == .connect
                     ? "Tip: the first run may ask for permission; allow it once. Use \"Test sound\" in the app to check the volume while connected to the car."
                     : "Saving parking needs location permission (Car → Parking). The spot is saved with the place name, so the Parking widget shows it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .navigationTitle(kind == .connect ? "When CarPlay connects" : "When CarPlay disconnects")
    }
}

/// A simple drawn phone screen for a guide step (real screenshots come with the Phase 8 clips).
private struct PhoneScreenSketch: View {
    let rows: [String]
    let highlight: Int

    var body: some View {
        VStack(spacing: 6) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 50, height: 5).padding(.top, 8)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Text(row)
                    .font(index == 0 ? .headline : .subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(index == highlight ? Theme.accent.opacity(0.35) : Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(index == highlight ? Theme.accent : .clear, lineWidth: 2)
                    )
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .frame(width: 220)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 2))
        .accessibilityHidden(true)
    }
}
