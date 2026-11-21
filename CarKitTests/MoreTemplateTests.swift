import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Phase 17 (spec §4b Templates, §3 Panorama hero): more realistic templates and the Hero templates.
@MainActor
struct MoreTemplateTests {
    private static let phase17Realistic: [TemplateStyle] = [.splitFlap, .neonSign, .woodTrim, .carStereo, .navigation, .rainyWindow, .parkingTicket, .numberPlate]
    private static let phase17Hero: [TemplateStyle] = [.heroSunsetRoad, .heroNightCity, .heroCockpit, .heroLiveSky, .heroNeonGrid, .heroGlassInfo]

    @Test func groups() {
        #expect(TemplateGroup.allCases.prefix(2) == [.realistic, .hero])
        #expect(Self.phase17Realistic.allSatisfy { $0.group == .realistic && $0.isNew && $0.usesDataSource })
        #expect(TemplateGroup.hero.styles == [.hero] + Self.phase17Hero)
        #expect(TemplateGroup.hero.styles.allSatisfy { !$0.usesDataSource && $0.isNew })
        #expect(TemplateGroup.car.styles.contains(.hero) == false)
    }

    @Test func realisticGlanceableInBothSizes() {
        for style in Self.phase17Realistic {
            for source in [DataSource.service, .fuel, .prayer] {
                for canvas in DesignCanvas.widgetCanvases {
                    let design = Templates.make(style, source: source, canvas: canvas)
                    #expect(!DesignLinter.blocksSaving(design), "\(style) \(canvas)")
                    let warnings = DesignLinter.warnings(for: design)
                    #expect(warnings.isEmpty, "\(style) \(source) \(canvas): \(warnings.map(\.message))")
                }
            }
            let small = Templates.make(style, canvas: .small).layers.map { [$0.x, $0.y, $0.width, $0.height] }
            let medium = Templates.make(style, canvas: .medium).layers.map { [$0.x, $0.y, $0.width, $0.height] }
            #expect(small != medium, "\(style) medium is the small layout stretched")
        }
    }

    @Test func heroTemplatesArePanoramaAndKeepTextInOneColumn() {
        for style in Self.phase17Hero {
            let design = Templates.make(style, source: .fuel, canvas: .small)
            #expect(design.canvas == .panorama, "\(style)")
            #expect(DesignLinter.warnings(for: design).isEmpty, "\(style): \(DesignLinter.warnings(for: design).map(\.message))")
            for layer in design.layers where layer.isText {
                let lo = layer.x - layer.width / 2, hi = layer.x + layer.width / 2
                let fits = (0..<PanoramaGeometry.columns).contains { part in
                    let start = PanoramaGeometry.partStart(part)
                    return lo >= start - 0.001 && hi <= start + PanoramaGeometry.partWidth + 0.001
                }
                #expect(fits, "\(style): \(layer.content) crosses a gap (\(lo)…\(hi))")
            }
        }
    }

    @Test func renderFromJSON() throws {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let data = SampleData.carData(now: now)
        var designs = Self.phase17Hero.map { Templates.make($0) }
        for style in Self.phase17Realistic {
            designs += DesignCanvas.widgetCanvases.map { Templates.make(style, source: .commute, canvas: $0) }
        }
        for design in designs {
            let back = try CardDesign.importing(design.exportData())
            #expect(back.background == design.background, "\(design.name)")
            #expect(back.layers.map(\.content) == design.layers.map(\.content), "\(design.name)")
            #expect(back.layers.map(\.rotation) == design.layers.map(\.rotation), "\(design.name)")
            let card = DesignResolver.card(for: back, data: data, studio: .empty, at: now)
            let renderer = ImageRenderer(content: DesignView(card: card).frame(width: 170 * back.canvas.aspectRatio, height: 170))
            #expect(renderer.uiImage != nil, "\(design.name)")
        }
    }

    @Test func newPiecesRoundTrip() throws {
        let design = CardDesign(name: "n", background: .rain(1, 2), layers: [
            DesignLayer(content: .splitFlap(.kmToService)),
            DesignLayer(content: .sticker(.streetMap)),
        ])
        let back = try CardDesign.importing(design.exportData())
        #expect(back.background == .rain(1, 2))
        #expect(back.layers.map(\.content) == [.splitFlap(.kmToService), .sticker(.streetMap)])
        #expect(back.dataFields == [.kmToService])
        for texture in [DesignTexture.wood, .brick] {
            let textured = CardDesign(name: "t", background: .texture(texture, 0x222222))
            #expect(try CardDesign.importing(textured.exportData()).background == .texture(texture, 0x222222))
        }
        #expect(DesignBackground.rain(0xFF4D6D, 0x3BA7FF).approximateHex != nil)
        #expect(ArtworkKind.stickers.contains(.skyline) && ArtworkKind.stickers.contains(.lcdPanel))
    }
}
