import CarKit
import MusicKit
import SwiftUI

/// Studio → Data sources → Lyrics.
struct LyricsView: View {
    @Environment(CarDataModel.self) private var model
    @State private var status: String?
    @State private var syncing = false
    @AppStorage("lyricsLiveActivity") private var liveActivity = false
    @State private var musicStatus = MusicAuthorization.currentStatus

    private var state: LyricsState { model.data.lyrics }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .lyrics))

            Section {
                if let playing = state.nowPlaying {
                    LabeledContent("Song", value: playing.title)
                    LabeledContent("Artist", value: playing.artist)
                    LabeledContent("Lyrics", value: lyricsStatus)
                }
                Button {
                    Task { await sync() }
                } label: {
                    HStack {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                        if syncing { Spacer(); ProgressView() }
                    }
                }
                .disabled(syncing || musicStatus != .authorized)
                if let status { Text(status).font(.footnote).foregroundStyle(Theme.secondaryText) }
                if let error = state.lastError { Text(error).font(.footnote).foregroundStyle(Theme.overdue) }
                if musicStatus != .authorized {
                    Button("Allow Apple Music") {
                        Task {
                            _ = await MusicAuthorization.request()
                            musicStatus = MusicAuthorization.currentStatus
                        }
                    }
                }
            } header: {
                Text("Now playing")
            } footer: {
                Text("The app reads what Apple Music is playing and when the song started, then the widget changes lines by itself. Sync again after you pause or skip within a song.")
            }

            Section {
                Picker("Lines", selection: setting(\.lineCount)) {
                    ForEach(LyricsSettings.lineChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Text size", selection: setting(\.textScale)) {
                    Text("Small").tag(0.85)
                    Text("Normal").tag(1.0)
                    Text("Large").tag(1.2)
                }
                .pickerStyle(.segmented)
                Toggle("Own colour for the active line", isOn: Binding(
                    get: { state.settings.accentHex != nil },
                    set: { on in update { $0.settings.accentHex = on ? 0xF472B6 : nil } }
                ))
                if let hex = state.settings.accentHex {
                    SlotColourPicker(hex: Binding(get: { hex }, set: { new in update { $0.settings.accentHex = new } }))
                }
                Toggle("Live Activity while the app is open", isOn: $liveActivity)
                    .onChange(of: liveActivity) { _, on in
                        if on { Task { await sync() } } else { LyricsSync.shared.endActivity() }
                    }
            } header: {
                Text("Look")
            } footer: {
                Text("1 line: just the current line. 3: the line before, current and next. 5: one before and three after. The Live Activity can only change lines while Peugeot408 is running.")
            }

            Section {
                Label("Add a Shortcuts automation \"When CarPlay connects → Sync Lyrics\" (and, if you like, \"When Music is opened → Sync Lyrics\"), so the widget knows the song without opening this app.", systemImage: "wand.and.stars")
                Label("Sync is approximate: pausing, skipping within a song or changing songs needs a new sync (opening the app or the automation does it).", systemImage: "clock.arrow.circlepath")
                Label("Spotify isn't supported: iOS doesn't let other apps read what Spotify is playing.", systemImage: "info.circle")
                Label("Lyrics come from LRCLIB (lrclib.net), a free community library. They're fetched only for songs you play, kept for your last \(LyricsState.cacheLimit) songs, and never bundled with the app.", systemImage: "quote.bubble")
            } header: {
                Text("How it works")
            }
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)

            if !state.songs.isEmpty {
                Section {
                    Button("Clear saved lyrics (\(state.songs.count) songs)", role: .destructive) {
                        update { $0.songs = [] }
                    }
                }
            }
        }
        .navigationTitle("Lyrics")
        .task {
            musicStatus = MusicAuthorization.currentStatus
            if musicStatus == .authorized { await sync() }
        }
    }

    private var lyricsStatus: String {
        guard let song = state.current else { return "Not fetched yet" }
        if song.isSynced { return "\(song.lines.count) synced lines" }
        if song.instrumental { return "Instrumental" }
        return song.plain != nil ? "Plain lyrics only" : "None found"
    }

    private func sync() async {
        syncing = true
        defer { syncing = false }
        status = await LyricsSync.shared.sync()
        model.reload()
    }

    private func update(_ change: (inout LyricsState) -> Void) {
        var next = LyricsStores.state().load()
        change(&next)
        try? LyricsStores.state().save(next)
        model.reload()
        model.reloadWidgets(for: .lyrics)
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<LyricsSettings, Value>) -> Binding<Value> {
        Binding(get: { state.settings[keyPath: keyPath] }, set: { value in update { $0.settings[keyPath: keyPath] = value } })
    }
}
