import CarKit
import MusicKit
import SwiftUI

/// Studio → Data sources → Music.
struct MusicView: View {
    @Environment(CarDataModel.self) private var model
    @State private var status = MusicAuthorization.currentStatus
    @State private var playlists: [Playlist] = []

    private var cache: MusicCache { model.data.music }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .music))

            switch status {
            case .authorized:
                Section {
                    Picker("Show", selection: mode) {
                        ForEach(MusicMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if cache.mode == .pinnedPlaylist {
                        Picker("Playlist", selection: pinned) {
                            Text("Choose…").tag(String?.none)
                            ForEach(playlists) { playlist in
                                Text(playlist.name).tag(String?.some(playlist.id.rawValue))
                            }
                        }
                    }
                    Button {
                        Task { await model.refreshMusic() }
                    } label: {
                        HStack {
                            Label("Refresh now", systemImage: "arrow.clockwise")
                            if model.isRefreshing.contains(.music) {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    if let error = cache.lastError {
                        Text(error).font(.footnote).foregroundStyle(Theme.overdue)
                    }
                } footer: {
                    Text("The card updates each time you open the app. Some library-only artwork can't be copied; the card then shows plain artwork.")
                }

                Section {
                    Toggle("Show play buttons", isOn: controls)
                } footer: {
                    Text("Play/pause and next on the medium widget, for the iPhone. CarPlay may ignore taps on widgets, so the card works without them. Turn this off if they don't respond.")
                }
            case .denied, .restricted:
                Section {
                    Text("Apple Music access is off. Turn it on in Settings → Privacy & Security → Media & Apple Music → DashCraft.")
                        .foregroundStyle(Theme.secondaryText)
                }
            default:
                Section {
                    Button {
                        Task {
                            _ = await MusicLoader.requestAccess()
                            status = MusicAuthorization.currentStatus
                            await model.refreshMusic()
                        }
                    } label: {
                        Label("Allow Apple Music", systemImage: "music.note")
                    }
                } footer: {
                    Text("Needed to read your recently played items and playlists. Nothing leaves your phone.")
                }
            }

            Section {
                Text("Spotify doesn't share what's playing with other apps' widgets, so this card uses Apple Music only.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .navigationTitle("Music")
        .task {
            status = MusicAuthorization.currentStatus
            guard status == .authorized else { return }
            playlists = await MusicLoader.libraryPlaylists()
            await model.refreshMusic()
        }
    }

    private var mode: Binding<MusicMode> {
        Binding(
            get: { cache.mode },
            set: { value in
                model.updateMusic { $0.mode = value }
                Task { await model.refreshMusic() }
            }
        )
    }

    private var pinned: Binding<String?> {
        Binding(
            get: { cache.pinnedPlaylistID },
            set: { value in
                let name = playlists.first { $0.id.rawValue == value }?.name
                model.updateMusic {
                    $0.pinnedPlaylistID = value
                    $0.pinnedPlaylistName = name
                }
                Task { await model.refreshMusic() }
            }
        )
    }

    private var controls: Binding<Bool> {
        Binding(
            get: { cache.showControls },
            set: { value in model.updateMusic { $0.showControls = value } }
        )
    }
}
