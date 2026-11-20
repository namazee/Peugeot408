import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Renders the README images from the real SwiftUI widget views with sample data.
/// Only runs when CI sets SNAPSHOT_DIR (ci/test.sh passes TEST_RUNNER_SNAPSHOT_DIR); it never fails
/// the build, since the pictures are documentation, not a check.
@Suite("README snapshots")
@MainActor
struct ReadmeSnapshots {
    private static let column = CGSize(width: 170, height: 236)

    @Test func renderReadmeImages() throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !path.isEmpty else { return }
        let directory = URL(filePath: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date()
        let card: (DataSource) -> SlotContent = { .data(SampleData.card(for: $0, now: now)) }

        // The head unit's three visible columns with the default Split setup.
        let columns: [SlotContent] = [
            .cards(.split, [card(.prayer), card(.renewals)]),
            .cards(.split, [card(.service), card(.fuel)]),
            .cards(.split, [card(.weather), card(.parking)]),
        ]
        save(carPlayScreen(columns), "carplay-split.png", in: directory)

        let quad: [SlotContent] = [
            .cards(.quad, [card(.prayer), card(.service), card(.fuel), card(.tng)]),
            .cards(.split, [card(.weather), card(.renewals)]),
            .design(SlotDesign(value: "408 GT", title: "Drive safe", symbol: "car.side.fill", style: .accent)),
        ]
        save(carPlayScreen(quad), "carplay-mixed.png", in: directory)

        for source in [DataSource.service, .fuel, .renewals, .tng, .prayer, .weather, .commute, .parking, .obd] {
            save(
                DataCardTile(card: SampleData.card(for: source, now: now))
                    .frame(width: 170, height: 170),
                "widget-\(source.rawValue).png",
                in: directory
            )
        }
    }

    private func carPlayScreen(_ columns: [SlotContent]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, content in
                SlotTile(slot: index + 1, content: content)
                    .frame(width: Self.column.width, height: Self.column.height)
            }
        }
        .padding(22)
        .background(Color(hex: 0x000000))
    }

    private func save(_ view: some View, _ name: String, in directory: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 3
        guard let image = renderer.uiImage, let png = image.pngData() else {
            print("README snapshot: couldn't render \(name)")
            return
        }
        do {
            try png.write(to: directory.appending(path: name, directoryHint: .notDirectory), options: .atomic)
        } catch {
            print("README snapshot: couldn't save \(name): \(error)")
        }
    }
}
