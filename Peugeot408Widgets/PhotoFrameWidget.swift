import AppIntents
import CarKit
import SwiftUI
import WidgetKit

// MARK: - Configuration (long-press the widget → Edit Widget → Album)

struct PhotoAlbumEntity: AppEntity {
    /// "all" stands for every photo.
    static let allID = "all"

    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Album" }
    static var defaultQuery: PhotoAlbumQuery { PhotoAlbumQuery() }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    var albumID: UUID? { UUID(uuidString: id) }

    static let all = PhotoAlbumEntity(id: allID, name: "All photos")
}

struct PhotoAlbumQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PhotoAlbumEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PhotoAlbumEntity] {
        let albums = MediaStores.photos().load().albums
        return [PhotoAlbumEntity.all] + albums.map { PhotoAlbumEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> PhotoAlbumEntity? { .all }
}

struct PhotoFrameConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Photo Frame" }
    static var description: IntentDescription { IntentDescription("Choose which album the frame shows.") }

    @Parameter(title: "Album")
    var album: PhotoAlbumEntity?
}

// MARK: - Timeline

struct PhotoFrameProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DataEntry {
        DataEntry(date: .now, card: .photos(PhotoSummary(imagePath: nil, photoCount: 0, albumName: nil)))
    }

    func snapshot(for configuration: PhotoFrameConfigurationIntent, in context: Context) async -> DataEntry {
        let now = Date()
        return DataEntry(date: now, card: CarData.load().photoCard(at: now, albumID: configuration.album?.albumID))
    }

    /// One entry per change (every 30–60 minutes) for the next 12 hours. The photo at each time is
    /// fixed by the clock, so a reload keeps the sequence going instead of starting over.
    func timeline(for configuration: PhotoFrameConfigurationIntent, in context: Context) async -> Timeline<DataEntry> {
        let now = Date()
        let data = CarData.load()
        let albumID = configuration.album?.albumID
        let photos = data.photos.photos(inAlbum: albumID)
        let dates = photos.isEmpty ? [] : PhotoRotation.dates(after: now, minutes: data.photos.clampedRotationMinutes)
        let entries = ([now] + dates).map { DataEntry(date: $0, card: data.photoCard(at: $0, albumID: albumID)) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Widget

struct PhotoFrameWidget: Widget {
    var body: some WidgetConfiguration {
        // Plain Strings (see CHANGELOG, Phase 1 fixes).
        let name: String = DataSource.photos.displayName
        let details: String = "Your photos, changing every 30 to 60 minutes."
        return AppIntentConfiguration(kind: DataSource.photos.widgetKind, intent: PhotoFrameConfigurationIntent.self, provider: PhotoFrameProvider()) { entry in
            DataWidgetView(entry: entry)
        }
        .configurationDisplayName(name)
        .description(details)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Photo Frame", as: .systemSmall) {
    PhotoFrameWidget()
} timeline: {
    DataEntry(date: .now, card: .photos(PhotoSummary(imagePath: nil, photoCount: 0, albumName: nil)))
}
