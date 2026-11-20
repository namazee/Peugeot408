import CarKit
import SwiftUI

/// Studio → Data sources → Map Snapshot.
struct MapSnapshotView: View {
    @Environment(CarDataModel.self) private var model

    /// Sizes of the two previews below (match `CardPreviewSection`'s tiles minus padding).
    private static let smallSize = CGSize(width: 112, height: 112)
    private static let mediumSize = CGSize(width: 220, height: 112)

    private var target: MapTarget? {
        MapTarget.choose(parking: model.data.parking, commute: model.data.commute, at: .now)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    DataCardTile(card: model.data.mapCard(at: .now, width: Self.smallSize.width, height: Self.smallSize.height))
                        .frame(width: 140, height: 140)
                    DataCardTile(card: model.data.mapCard(at: .now, width: Self.mediumSize.width, height: Self.mediumSize.height), size: .medium)
                        .frame(height: 140)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                .listRowBackground(Color.clear)
            } footer: {
                Text("A still map image (CarPlay widgets can't run live maps). Assign it to a slot, or add the Map Snapshot widget.")
            }

            Section {
                switch target {
                case .parking(_, let label):
                    Label("Showing your parked car: \(label)", systemImage: "parkingsign.circle.fill")
                case .commute(_, _, let label, _):
                    Label("Showing \(label)", systemImage: "car.rear.road.lane")
                case nil:
                    Text("Save a parking spot (Car → Parking) or set Home and Work (Daily → Commute) to get a map.")
                        .foregroundStyle(Theme.secondaryText)
                }
                Button {
                    Task { await model.refreshMap(sizes: [Self.smallSize, Self.mediumSize], force: true) }
                } label: {
                    HStack {
                        Label("Redraw map", systemImage: "arrow.clockwise")
                        if model.isRefreshing.contains(.map) {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(target == nil)
            } header: {
                Text("What it shows")
            } footer: {
                Text("The parked car when a spot is saved; otherwise the area of your next commute destination. Dark map, blue pin.")
            }
        }
        .navigationTitle("Map Snapshot")
        .task { await model.refreshMap(sizes: [Self.smallSize, Self.mediumSize]) }
    }
}

/// Studio tab. Data sources (Map, Photo Frame, Music) are here; templates and the builder arrive in Phase 5.
struct StudioView: View {
    @Binding var path: [DataSource]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Data sources") {
                    NavigationLink(value: DataSource.map) {
                        Label("Map Snapshot", systemImage: DataSource.map.symbol)
                    }
                    NavigationLink(value: DataSource.photos) {
                        Label("Photo Frame", systemImage: DataSource.photos.symbol)
                    }
                    NavigationLink(value: DataSource.music) {
                        Label("Music", systemImage: DataSource.music.symbol)
                    }
                }
                Section("Coming in Phase 5") {
                    Label("Templates and seasonal packs", systemImage: "square.grid.2x2")
                    Label("Custom builder", systemImage: "paintbrush.pointed")
                    Label("My Car photo", systemImage: "car.side")
                }
                .foregroundStyle(Theme.secondaryText)
                Section("Coming in Phase 6") {
                    Label("Connect sounds", systemImage: "speaker.wave.2")
                }
                .foregroundStyle(Theme.secondaryText)
            }
            .navigationTitle("Studio")
            .navigationDestination(for: DataSource.self) { DataSourceScreen(source: $0) }
        }
    }
}
