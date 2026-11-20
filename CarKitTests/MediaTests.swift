import Foundation
import Testing
@testable import CarKit

private func photo(_ n: Int) -> PhotoItem {
    PhotoItem(id: UUID(), fileName: "p\(n).jpg", addedAt: Date(timeIntervalSince1970: Double(n) * 1_000))
}

@Suite("Photo Frame")
struct PhotoFrameTests {
    @Test func rotationIsAFunctionOfTheClock() {
        let photos = (0..<3).map(photo)
        let t0 = Date(timeIntervalSince1970: 45 * 60 * 300)   // slot 300 → index 0
        #expect(PhotoRotation.photo(at: t0, in: photos, minutes: 45) == photos[0])
        #expect(PhotoRotation.photo(at: t0.addingTimeInterval(44 * 60), in: photos, minutes: 45) == photos[0])
        #expect(PhotoRotation.photo(at: t0.addingTimeInterval(45 * 60), in: photos, minutes: 45) == photos[1])
        #expect(PhotoRotation.photo(at: t0.addingTimeInterval(3 * 45 * 60), in: photos, minutes: 45) == photos[0]) // wraps
        #expect(PhotoRotation.photo(at: t0, in: [], minutes: 45) == nil)
    }

    @Test func changeTimesAreOnBoundariesForTwelveHours() {
        let start = Date(timeIntervalSince1970: 45 * 60 * 300 + 600)
        let dates = PhotoRotation.dates(after: start, minutes: 45)
        #expect(dates.first == Date(timeIntervalSince1970: 45 * 60 * 301))
        #expect(dates.count == 16) // 12 h / 45 min
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == 45 * 60 })
    }

    @Test func intervalIsClampedToThirtySixtyMinutes() {
        #expect(PhotoLibraryState(rotationMinutes: 5).clampedRotationMinutes == 30)
        #expect(PhotoLibraryState(rotationMinutes: 90).clampedRotationMinutes == 60)
        #expect(PhotoLibraryState(rotationMinutes: 45).clampedRotationMinutes == 45)
    }

    @Test func albumsFilterAndFallBackToAll() {
        let photos = (0..<4).map(photo)
        let album = PhotoAlbum(name: "Family", photoIDs: [photos[3].id, photos[1].id, UUID()])
        let state = PhotoLibraryState(photos: photos.reversed(), albums: [album])
        #expect(state.photos(inAlbum: album.id) == [photos[3], photos[1]]) // album order, missing ids skipped
        #expect(state.photos(inAlbum: nil) == photos)                       // all, oldest first
        #expect(state.photos(inAlbum: UUID()) == photos)                    // deleted album → all
    }

    @Test func removingPhotosCleansAlbums() {
        let photos = (0..<3).map(photo)
        var state = PhotoLibraryState(photos: photos, albums: [PhotoAlbum(name: "A", photoIDs: photos.map(\.id))])
        let files = state.remove(photoIDs: [photos[1].id])
        #expect(files == ["p1.jpg"])
        #expect(state.photos.count == 2)
        #expect(state.albums[0].photoIDs == [photos[0].id, photos[2].id])
    }

    @Test func photoCardPointsIntoThePhotosFolder() throws {
        let directory = URL(filePath: "/tmp/group", directoryHint: .isDirectory)
        let photos = [photo(0)]
        let data = CarData(photos: PhotoLibraryState(photos: photos), directory: directory)
        guard case .photos(let summary) = data.card(for: .photos, at: .now) else {
            Issue.record("expected a photo card")
            return
        }
        #expect(summary.photoCount == 1)
        let path = try #require(summary.imagePath)
        #expect(path.hasSuffix("/photos/p0.jpg"))
    }

    @Test func slotTimelineFollowsRotation() {
        let photos = (0..<3).map(photo)
        let data = CarData(photos: PhotoLibraryState(photos: photos, rotationMinutes: 30))
        let start = Date(timeIntervalSince1970: 1_800 * 1_000 + 60)
        let dates = DataTimeline.dates(for: .photos, data: data, from: start)
        #expect(dates.first == start)
        #expect(dates.count == 25) // now + 24 half-hours
        #expect(DataTimeline.dates(for: .photos, data: .empty, from: start) == [start])
    }

    @Test func libraryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = PhotoLibraryState(photos: [photo(1)], albums: [PhotoAlbum(name: "Car")], rotationMinutes: 60)
        try MediaStores.photos(in: directory).save(state)
        #expect(CarData.load(from: directory).photos == state)
    }
}

@Suite("Music")
struct MusicTests {
    @Test func emptyCacheAsksForSetup() {
        guard case .music(let summary) = CarData.empty.card(for: .music, at: .now) else {
            Issue.record("expected a music card")
            return
        }
        #expect(summary.title == nil)
        #expect(summary.artworkPath == nil)
    }

    @Test func cachedItemIsShownWithArtworkPath() {
        let item = MusicItemCard(title: "Drive Mix", subtitle: "Apple Music", kindLabel: "Playlist", artworkFile: MusicCache.artworkFile, updatedAt: .now)
        let data = CarData(music: MusicCache(item: item, showControls: false), directory: URL(filePath: "/tmp/group", directoryHint: .isDirectory))
        guard case .music(let summary) = data.card(for: .music, at: .now) else { return }
        #expect(summary.title == "Drive Mix")
        #expect(summary.kindLabel == "Playlist")
        #expect(summary.artworkPath?.hasSuffix("/music-artwork.jpg") == true)
        #expect(summary.showControls == false)
    }

    @Test func musicCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = MusicCache(mode: .pinnedPlaylist, pinnedPlaylistID: "p.123", pinnedPlaylistName: "Road trip")
        try MediaStores.music(in: directory).save(cache)
        #expect(CarData.load(from: directory).music == cache)
    }
}
