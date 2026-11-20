import Foundation

// MARK: - Photo Frame

/// One downsampled photo in the App Group (`photos/<id>.jpg`).
public struct PhotoItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var fileName: String
    public var addedAt: Date

    public init(id: UUID = UUID(), fileName: String, addedAt: Date) {
        self.id = id
        self.fileName = fileName
        self.addedAt = addedAt
    }
}

/// A named selection of photos, e.g. "Family". The Photo Frame widget can be set to one album.
public struct PhotoAlbum: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var photoIDs: [UUID]

    public init(id: UUID = UUID(), name: String, photoIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.photoIDs = photoIDs
    }
}

/// `photos.json`: every photo, the albums, and how often the frame changes.
public struct PhotoLibraryState: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    /// Keeps the App Group small (each photo is about 150–300 KB).
    public static let maxPhotos = 60
    public static let folder = "photos"
    public static let rotationChoices = [30, 45, 60]

    public var version: Int
    public var photos: [PhotoItem]
    public var albums: [PhotoAlbum]
    /// Minutes between photos (30–60).
    public var rotationMinutes: Int
    /// Album shown by Car Slots set to Photo Frame; nil = all photos.
    public var slotAlbumID: UUID?

    public init(version: Int = PhotoLibraryState.currentVersion, photos: [PhotoItem] = [], albums: [PhotoAlbum] = [], rotationMinutes: Int = 45, slotAlbumID: UUID? = nil) {
        self.version = version
        self.photos = photos
        self.albums = albums
        self.rotationMinutes = rotationMinutes
        self.slotAlbumID = slotAlbumID
    }

    public static let empty = PhotoLibraryState()

    /// Photos in an album, in album order. Nil, or an album that no longer exists, means all photos (oldest first).
    public func photos(inAlbum albumID: UUID?) -> [PhotoItem] {
        guard let albumID, let album = albums.first(where: { $0.id == albumID }) else {
            return photos.sorted { $0.addedAt < $1.addedAt }
        }
        let byID = Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return album.photoIDs.compactMap { byID[$0] }
    }

    public func album(_ id: UUID?) -> PhotoAlbum? {
        guard let id else { return nil }
        return albums.first { $0.id == id }
    }

    /// Removes photos and any album references to them. Returns the file names to delete.
    public mutating func remove(photoIDs: Set<UUID>) -> [String] {
        let removed = photos.filter { photoIDs.contains($0.id) }.map(\.fileName)
        photos.removeAll { photoIDs.contains($0.id) }
        for index in albums.indices {
            albums[index].photoIDs.removeAll { photoIDs.contains($0) }
        }
        return removed
    }

    /// Clamps the interval to the 30–60 minute range the spec asks for.
    public var clampedRotationMinutes: Int { min(max(rotationMinutes, 30), 60) }
}

/// Which photo shows when. The photo is a pure function of the time, so reloading the widget
/// never jumps back to the first photo: slot n = floor(time / interval), photo = n mod count.
public enum PhotoRotation {
    public static func slotNumber(at date: Date, minutes: Int) -> Int {
        let interval = Double(max(minutes, 1) * 60)
        return Int(floor(date.timeIntervalSince1970 / interval))
    }

    public static func photo(at date: Date, in photos: [PhotoItem], minutes: Int) -> PhotoItem? {
        guard !photos.isEmpty else { return nil }
        let slot = slotNumber(at: date, minutes: minutes)
        let index = ((slot % photos.count) + photos.count) % photos.count
        return photos[index]
    }

    /// The change times after `start`, covering `hours`.
    public static func dates(after start: Date, minutes: Int, hours: Double = 12) -> [Date] {
        let interval = Double(max(minutes, 1) * 60)
        var next = Double(slotNumber(at: start, minutes: minutes) + 1) * interval
        let end = start.timeIntervalSince1970 + hours * 3600
        var dates: [Date] = []
        while next <= end {
            dates.append(Date(timeIntervalSince1970: next))
            next += interval
        }
        return dates
    }
}

public struct PhotoSummary: Sendable, Equatable {
    public let imagePath: String?
    public let photoCount: Int
    public let albumName: String?

    public init(imagePath: String?, photoCount: Int, albumName: String?) {
        self.imagePath = imagePath
        self.photoCount = photoCount
        self.albumName = albumName
    }
}

// MARK: - Music

public enum MusicMode: String, Codable, Sendable, CaseIterable {
    /// The most recently played album, playlist or station.
    case recentlyPlayed
    /// A playlist from the library that you pick ("featured").
    case pinnedPlaylist

    public var displayName: String {
        switch self {
        case .recentlyPlayed: "Recently played"
        case .pinnedPlaylist: "My featured playlist"
        }
    }
}

/// What the Music card shows, cached by the app (the widget never calls MusicKit).
public struct MusicItemCard: Codable, Sendable, Equatable {
    public var title: String
    public var subtitle: String?
    /// "Album", "Playlist", "Station".
    public var kindLabel: String
    /// File in the App Group, downsampled. Nil when the artwork couldn't be downloaded.
    public var artworkFile: String?
    public var updatedAt: Date

    public init(title: String, subtitle: String?, kindLabel: String, artworkFile: String?, updatedAt: Date) {
        self.title = title
        self.subtitle = subtitle
        self.kindLabel = kindLabel
        self.artworkFile = artworkFile
        self.updatedAt = updatedAt
    }
}

/// `music.json`.
public struct MusicCache: Codable, Sendable, Equatable {
    public var mode: MusicMode
    public var pinnedPlaylistID: String?
    public var pinnedPlaylistName: String?
    public var item: MusicItemCard?
    /// Play/pause and next buttons on the medium widget (iPhone only; CarPlay ignores taps).
    public var showControls: Bool
    public var lastError: String?

    public init(mode: MusicMode = .recentlyPlayed, pinnedPlaylistID: String? = nil, pinnedPlaylistName: String? = nil, item: MusicItemCard? = nil, showControls: Bool = true, lastError: String? = nil) {
        self.mode = mode
        self.pinnedPlaylistID = pinnedPlaylistID
        self.pinnedPlaylistName = pinnedPlaylistName
        self.item = item
        self.showControls = showControls
        self.lastError = lastError
    }

    public static let empty = MusicCache()

    public static let artworkFile = "music-artwork.jpg"
}

public struct MusicSummary: Sendable, Equatable {
    public let title: String?
    public let subtitle: String?
    public let kindLabel: String
    public let artworkPath: String?
    public let showControls: Bool

    public init(title: String?, subtitle: String?, kindLabel: String, artworkPath: String?, showControls: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.kindLabel = kindLabel
        self.artworkPath = artworkPath
        self.showControls = showControls
    }
}

// MARK: - Stores and cards

public enum MediaStores {
    public static func photos(in directory: URL = AppGroup.containerURL) -> JSONFileStore<PhotoLibraryState> {
        JSONFileStore(directory: directory, fileName: "photos.json") { .empty }
    }

    public static func music(in directory: URL = AppGroup.containerURL) -> JSONFileStore<MusicCache> {
        JSONFileStore(directory: directory, fileName: "music.json") { .empty }
    }

    public static func photosFolder(in directory: URL = AppGroup.containerURL) -> URL {
        directory.appending(path: PhotoLibraryState.folder, directoryHint: .isDirectory)
    }
}

extension CarData {
    /// The photo showing at `date` for an album (nil = all photos).
    public func photoCard(at date: Date, albumID: UUID?) -> DataCard {
        let list = photos.photos(inAlbum: albumID)
        let photo = PhotoRotation.photo(at: date, in: list, minutes: photos.clampedRotationMinutes)
        let path = photo.flatMap { photo in
            directory.map { MediaStores.photosFolder(in: $0).appending(path: photo.fileName, directoryHint: .notDirectory).path(percentEncoded: false) }
        }
        return .photos(PhotoSummary(imagePath: path, photoCount: list.count, albumName: photos.album(albumID)?.name))
    }

    func musicCard() -> DataCard {
        let item = music.item
        let path = item?.artworkFile.flatMap { file in
            directory?.appending(path: file, directoryHint: .notDirectory).path(percentEncoded: false)
        }
        return .music(MusicSummary(
            title: item?.title,
            subtitle: item?.subtitle,
            kindLabel: item?.kindLabel ?? "Apple Music",
            artworkPath: path,
            showControls: music.showControls
        ))
    }
}
