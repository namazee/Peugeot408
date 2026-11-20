import CarKit
import PhotosUI
import SwiftUI

/// Studio → Data sources → Photo Frame.
struct PhotoFrameView: View {
    @Environment(CarDataModel.self) private var model
    @State private var picked: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var message: String?
    @State private var newAlbumName = ""
    @State private var addingAlbum = false

    private var library: PhotoLibraryState { model.data.photos }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .photos))

            Section {
                PhotosPicker(selection: $picked, maxSelectionCount: max(1, PhotoLibraryState.maxPhotos - library.photos.count), matching: .images) {
                    HStack {
                        Label("Add photos", systemImage: "photo.badge.plus")
                        if importing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(importing || library.photos.count >= PhotoLibraryState.maxPhotos)
                if let message {
                    Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Picker("Change every", selection: rotation) {
                    ForEach(PhotoLibraryState.rotationChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            } footer: {
                Text("Photos are shrunk and copied into the app (up to \(PhotoLibraryState.maxPhotos)); the originals stay in Photos. The frame moves to the next photo on a fixed schedule, so it never restarts from the first one.")
            }

            if !library.photos.isEmpty {
                Section("All photos (\(library.photos.count))") {
                    PhotoGrid(photos: library.photos.sorted { $0.addedAt > $1.addedAt }, directory: model.data.directory) { ids in
                        model.deletePhotos(ids)
                    }
                }
            }

            Section {
                ForEach(library.albums) { album in
                    NavigationLink {
                        AlbumView(albumID: album.id)
                    } label: {
                        LabeledContent(album.name, value: "\(album.photoIDs.count)")
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { library.albums[$0].id }
                    model.updatePhotos { state in
                        state.albums.removeAll { ids.contains($0.id) }
                        if let slotAlbum = state.slotAlbumID, ids.contains(slotAlbum) { state.slotAlbumID = nil }
                    }
                }
                Button {
                    addingAlbum = true
                } label: {
                    Label("New album", systemImage: "plus")
                }
                Picker("Car Slots show", selection: slotAlbum) {
                    Text("All photos").tag(UUID?.none)
                    ForEach(library.albums) { album in
                        Text(album.name).tag(UUID?.some(album.id))
                    }
                }
            } header: {
                Text("Albums")
            } footer: {
                Text("To pick an album for the Photo Frame widget itself: long-press it → Edit Widget → Album.")
            }
        }
        .navigationTitle("Photo Frame")
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items, album: nil) }
        }
        .alert("New album", isPresented: $addingAlbum) {
            TextField("e.g. Family", text: $newAlbumName)
            Button("Cancel", role: .cancel) { newAlbumName = "" }
            Button("Create") {
                let name = newAlbumName.trimmingCharacters(in: .whitespaces)
                newAlbumName = ""
                guard !name.isEmpty else { return }
                model.updatePhotos { $0.albums.append(PhotoAlbum(name: name)) }
            }
        }
    }

    private var rotation: Binding<Int> {
        Binding(
            get: { library.clampedRotationMinutes },
            set: { value in model.updatePhotos { $0.rotationMinutes = value } }
        )
    }

    private var slotAlbum: Binding<UUID?> {
        Binding(
            get: { library.slotAlbumID },
            set: { value in model.updatePhotos { $0.slotAlbumID = value } }
        )
    }

    private func importPhotos(_ items: [PhotosPickerItem], album: UUID?) async {
        importing = true
        defer {
            importing = false
            picked = []
        }
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        let added = model.addPhotos(datas, toAlbum: album)
        message = added == items.count ? "Added \(added) photos." : "Added \(added) of \(items.count) photos."
    }
}

/// One album: choose which photos belong to it.
struct AlbumView: View {
    @Environment(CarDataModel.self) private var model
    let albumID: UUID

    private var album: PhotoAlbum? { model.data.photos.album(albumID) }

    var body: some View {
        List {
            if let album {
                Section {
                    TextField("Name", text: name)
                }
                Section {
                    let columns = [GridItem(.adaptive(minimum: 90), spacing: 6)]
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(model.data.photos.photos.sorted { $0.addedAt > $1.addedAt }) { photo in
                            let included = album.photoIDs.contains(photo.id)
                            PhotoThumb(photo: photo, directory: model.data.directory)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(included ? Theme.accent : .white)
                                        .shadow(radius: 2)
                                        .padding(4)
                                }
                                .opacity(included ? 1 : 0.6)
                                .onTapGesture { toggle(photo.id) }
                        }
                    }
                } header: {
                    Text("Tap to add or remove (\(album.photoIDs.count) in album)")
                }
            }
        }
        .navigationTitle(album?.name ?? "Album")
    }

    private var name: Binding<String> {
        Binding(
            get: { album?.name ?? "" },
            set: { value in
                model.updatePhotos { state in
                    if let index = state.albums.firstIndex(where: { $0.id == albumID }) { state.albums[index].name = value }
                }
            }
        )
    }

    private func toggle(_ photoID: UUID) {
        model.updatePhotos { state in
            guard let index = state.albums.firstIndex(where: { $0.id == albumID }) else { return }
            if let position = state.albums[index].photoIDs.firstIndex(of: photoID) {
                state.albums[index].photoIDs.remove(at: position)
            } else {
                state.albums[index].photoIDs.append(photoID)
            }
        }
    }
}

struct PhotoGrid: View {
    let photos: [PhotoItem]
    let directory: URL?
    let onDelete: (Set<UUID>) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
            ForEach(photos) { photo in
                PhotoThumb(photo: photo, directory: directory)
                    .contextMenu {
                        Button("Remove from Peugeot408", systemImage: "trash", role: .destructive) {
                            onDelete([photo.id])
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PhotoThumb: View {
    let photo: PhotoItem
    let directory: URL?

    var body: some View {
        let url = directory.map { MediaStores.photosFolder(in: $0).appending(path: photo.fileName, directoryHint: .notDirectory) }
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surface
            }
        }
        .frame(minWidth: 90, minHeight: 90)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
