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

        for look in CardLook.allCases {
            let suffix = look == .bold ? "" : "-neon"
            // The head unit's three visible columns with the default Split setup.
            let columns: [SlotContent] = [
                .cards(.split, [card(.prayer), card(.renewals)]),
                .cards(.split, [card(.service), card(.fuel)]),
                .cards(.split, [card(.weather), card(.parking)]),
            ]
            save(carPlayScreen(columns).environment(\.cardLook, look), "carplay-split\(suffix).png", in: directory)

            let mixed: [SlotContent] = [
                .cards(.quad, [card(.prayer), card(.service), card(.fuel), card(.tng)]),
                .data(SampleData.card(for: .service, now: now)),
                .design(SlotDesign(value: "MY CAR", title: "Drive safe", symbol: "car.side.fill")),
            ]
            save(carPlayScreen(mixed).environment(\.cardLook, look), "carplay-mixed\(suffix).png", in: directory)

            for source in [DataSource.service, .fuel, .renewals, .tng, .prayer, .weather, .commute, .parking, .obd] {
                save(
                    DataCardTile(card: SampleData.card(for: source, now: now))
                        .frame(width: 170, height: 170)
                        .environment(\.cardLook, look),
                    "widget-\(source.rawValue)\(suffix).png",
                    in: directory
                )
            }
            save(
                VStack(spacing: 12) {
                    ForEach([DataSource.service, .prayer, .fuel], id: \.self) { source in
                        DataCardTile(card: SampleData.card(for: source, now: now), size: .medium)
                            .frame(width: 364, height: 170)
                    }
                }
                .padding(12)
                .background(Color(hex: 0x000000))
                .environment(\.cardLook, look),
                "widgets-medium\(suffix).png",
                in: directory
            )
        }

        // The Studio template gallery, small size, with sample data.
        let data = SampleData.carData(now: now)

        // Panorama hero across the three visible columns.
        let hero = Templates.make(.hero)
        let heroCard = DesignResolver.card(for: hero, data: data, studio: .empty, at: now)
        save(carPlayScreen((0..<3).map { SlotContent.panorama(heroCard, $0) }), "carplay-panorama.png", in: directory)
        for group in TemplateGroup.allCases {
            let designs = group.styles.map { Templates.make($0, source: .service, canvas: .small, eventDate: now.addingTimeInterval(-86_400 * 3_500)) }
            let rows = stride(from: 0, to: designs.count, by: 4).map { Array(designs[$0..<min($0 + 4, designs.count)]) }
            save(
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            ForEach(row) { design in
                                DesignView(card: DesignResolver.card(for: design, data: data, studio: .empty, at: now))
                                    .frame(width: 150 * min(design.canvas.aspectRatio, 2.4), height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(hex: 0x000000)),
                "templates-\(group.rawValue).png",
                in: directory
            )
        }

        // Realistic templates (Phase 16): each in Small and Medium, bound to a source that suits it.
        let realistic: [(TemplateStyle, DataSource)] = [
            (.chromeDial, .obd), (.fuelGauge, .fuel), (.odometer, .service), (.highwaySign, .commute), (.leatherStitch, .renewals),
            (.digitalCockpit, .service), (.headUpDisplay, .weather), (.frostedGlass, .tng), (.liveSky, .weather), (.boardingPass, .commute),
        ]
        saveBoth(realistic, data: data, now: now, "templates-realistic-both.png", in: directory)
        // Phase 17 realistic templates.
        let more: [(TemplateStyle, DataSource)] = [
            (.splitFlap, .commute), (.neonSign, .weather), (.woodTrim, .renewals), (.carStereo, .music),
            (.navigation, .commute), (.rainyWindow, .weather), (.parkingTicket, .parking), (.numberPlate, .service),
        ]
        saveBoth(more, data: data, now: now, "templates-realistic-more.png", in: directory)
        // Phase 18: realistic and other templates.
        let round3: [(TemplateStyle, DataSource)] = [
            (.shiftLight, .obd), (.polaroid, .service), (.stickyNote, .renewals), (.dotMatrix, .commute), (.chalkboard, .fuel),
            (.thermometer, .weather), (.battery, .tng), (.speedSign, .service), (.vinyl, .music), (.comicPop, .tng),
            (.flipClock, .service), (.wordClock, .service), (.hijriDate, .service), (.moonPhase, .service),
        ]
        saveBoth(round3, data: data, now: now, "templates-round3.png", in: directory)
        // Hero templates (Phase 17), each across the three visible columns.
        save(
            VStack(spacing: 10) {
                ForEach(TemplateGroup.hero.styles) { style in
                    let card = DesignResolver.card(for: Templates.make(style), data: data, studio: .empty, at: now)
                    carPlayScreen((0..<3).map { SlotContent.panorama(card, $0) })
                }
            },
            "carplay-heroes.png",
            in: directory
        )
    }

    private func saveBoth(_ realistic: [(TemplateStyle, DataSource)], data: CarData, now: Date, _ name: String, in directory: URL) {
        save(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(realistic.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 12) {
                        ForEach(DesignCanvas.widgetCanvases, id: \.self) { canvas in
                            let design = Templates.make(pair.0, source: pair.1, canvas: canvas)
                            DesignView(card: DesignResolver.card(for: design, data: data, studio: .empty, at: now))
                                .frame(width: 150 * design.canvas.aspectRatio, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(hex: 0x000000)),
            name,
            in: directory
        )
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
