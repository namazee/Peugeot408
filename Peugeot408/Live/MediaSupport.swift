import CarKit
import Foundation
import ImageIO
import MusicKit
import UIKit
import UniformTypeIdentifiers

/// Shrinks photos and artwork before they go into the App Group (the widget extension has a
/// ~30 MB memory limit, and a medium widget is at most ~1,100 px wide on a 3x screen).
enum ImageDownsampler {
    static func jpeg(from data: Data, maxPixelSize: Int, quality: CGFloat = 0.82) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respect EXIF rotation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }
}

/// Reads the Music card from MusicKit in the app and caches it (title + downsampled artwork).
enum MusicLoader {
    enum LoadError: Error, LocalizedError {
        case notAuthorized
        case nothingFound(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: "Apple Music access is off."
            case .nothingFound(let what): what
            }
        }
    }

    static var isAuthorized: Bool { MusicAuthorization.currentStatus == .authorized }

    static func requestAccess() async -> Bool {
        await MusicAuthorization.request() == .authorized
    }

    static func load(cache: MusicCache, directory: URL) async -> Result<MusicItemCard, Error> {
        guard isAuthorized else { return .failure(LoadError.notAuthorized) }
        do {
            let found: (title: String, subtitle: String?, kind: String, artwork: Artwork?)
            switch cache.mode {
            case .pinnedPlaylist:
                guard let id = cache.pinnedPlaylistID else { throw LoadError.nothingFound("Pick a playlist first.") }
                var request = MusicLibraryRequest<Playlist>()
                request.filter(matching: \.id, equalTo: MusicItemID(id))
                guard let playlist = try await request.response().items.first else {
                    throw LoadError.nothingFound("That playlist is no longer in your library.")
                }
                found = (playlist.name, playlist.curatorName, "Playlist", playlist.artwork)
            case .recentlyPlayed:
                var request = MusicRecentlyPlayedContainerRequest()
                request.limit = 1
                guard let item = try await request.response().items.first else {
                    throw LoadError.nothingFound("Nothing played recently.")
                }
                found = (item.title, item.subtitle, kindLabel(item), item.artwork)
            }
            let file = await saveArtwork(found.artwork, directory: directory)
            return .success(MusicItemCard(title: found.title, subtitle: found.subtitle, kindLabel: found.kind, artworkFile: file, updatedAt: .now))
        } catch {
            return .failure(error)
        }
    }

    /// Library playlists for the "featured" picker.
    static func libraryPlaylists() async -> [Playlist] {
        guard isAuthorized else { return [] }
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 100
        return (try? await request.response().items.map { $0 }) ?? []
    }

    private static func kindLabel(_ item: RecentlyPlayedMusicItem) -> String {
        switch item {
        case .album: "Album"
        case .playlist: "Playlist"
        case .station: "Station"
        @unknown default: "Recently played"
        }
    }

    /// Downloads the artwork when it has a web URL. Library-only artwork uses a private URL
    /// scheme that can't be downloaded; the card then shows the placeholder art.
    private static func saveArtwork(_ artwork: Artwork?, directory: URL) async -> String? {
        guard let url = artwork?.url(width: 600, height: 600),
              url.scheme == "https" || url.scheme == "http",
              let download = try? await URLSession.shared.data(from: url),
              let jpeg = ImageDownsampler.jpeg(from: download.0, maxPixelSize: 600) else { return nil }
        let fileURL = directory.appending(path: MusicCache.artworkFile, directoryHint: .notDirectory)
        do {
            try jpeg.write(to: fileURL, options: .atomic)
            return MusicCache.artworkFile
        } catch {
            return nil
        }
    }
}
