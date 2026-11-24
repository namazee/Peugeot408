import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Phase 19 (spec §4b Templates, §3 Panorama hero): one-tap templates, setups, and the third round of templates.
@MainActor
struct RoundFourTemplateTests {
    private static let realistic: [TemplateStyle] = [.tachometer, .compass, .cassette, .neonTube, .glowOrb, .postageStamp]
    private static let clocks: [TemplateStyle] = [.tearOffCalendar, .lcdWatch]
    private static let heroes = TemplateStyle.roundFourHeroes

    private var malaysia: Calendar { PrayerCalendar.malaysia }

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        malaysia.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }

    @Test func groups() {
        let realisticOK = Self.realistic.allSatisfy { style in style.group == TemplateGroup.realistic && style.usesDataSource && style.isNew }
        #expect(realisticOK)
        let clocksOK = Self.clocks.allSatisfy { style in style.group == TemplateGroup.clockDate && !style.usesDataSource && style.isNew }
        #expect(clocksOK)
        #expect(Self.heroes.count == 6)
        let heroesOK = Self.heroes.allSatisfy { style in style.group == TemplateGroup.hero && !style.usesDataSource && style.isNew }
        #expect(heroesOK)
    }

    @Test func glanceableWithTheirOwnSmallAndMedium() {
        for style in Self.realistic + Self.clocks {
            for source in [DataSource.service, .fuel, .prayer] {
                for canvas in DesignCanvas.widgetCanvases {
                    let design = Templates.make(style, source: source, canvas: canvas)
                    #expect(!DesignLinter.blocksSaving(design), "\(style) \(canvas)")
                    let warnings = DesignLinter.warnings(for: design)
                    #expect(warnings.isEmpty, "\(style) \(source) \(canvas): \(warnings.map(\.message))")
                }
            }
            let positions = { (design: CardDesign) in design.layers.map { [$0.x, $0.y, $0.width, $0.height] } }
            #expect(positions(Templates.make(style, canvas: .small)) != positions(Templates.make(style, canvas: .medium)), "\(style)")
        }
    }

    @Test func heroTextStaysInOneColumn() {
        for style in Self.heroes {
            let design = Templates.make(style)
            #expect(design.canvas == .panorama, "\(style)")
            let hasCar = design.layers.contains { layer in layer.content == LayerContent.carPhoto }
            #expect(hasCar, "\(style) has no car photo")
            #expect(DesignLinter.warnings(for: design).isEmpty, "\(style): \(DesignLinter.warnings(for: design).map(\.message))")
            for layer in design.layers where layer.isText {
                let lo = layer.x - layer.width / 2, hi = layer.x + layer.width / 2
                let fits = (0..<PanoramaGeometry.columns).contains { part in
                    let start = PanoramaGeometry.partStart(part)
                    return lo >= start - 0.001 && hi <= start + PanoramaGeometry.partWidth + 0.001
                }
                #expect(fits, "\(style): \(layer.content) crosses a gap")
            }
        }
    }

    @Test func renderFromJSON() throws {
        let now = at(2026, 11, 25, 21)
        let data = SampleData.carData(now: now)
        var designs = Self.heroes.map { Templates.make($0) }
        for style in Self.realistic + Self.clocks {
            designs += DesignCanvas.widgetCanvases.map { Templates.make(style, source: .weather, canvas: $0) }
        }
        for design in designs {
            let back = try CardDesign.importing(design.exportData())
            #expect(back.background == design.background, "\(design.name)")
            #expect(back.layers.map(\.content) == design.layers.map(\.content), "\(design.name)")
            let card = DesignResolver.card(for: back, data: data, studio: .empty, at: now)
            let renderer = ImageRenderer(content: DesignView(card: card).frame(width: 170 * back.canvas.aspectRatio, height: 170))
            #expect(renderer.uiImage != nil, "\(design.name)")
        }
    }

    @Test func newPiecesRoundTrip() throws {
        let stickers: [ArtworkKind] = [.lightTrails, .paddyTerraces, .rainforest, .lightning, .stripLights, .tyreStack, .dimensionLines,
                                       .cassette, .tubeClips, .calendarRings, .postmark, .stampEdge]
        let listed = stickers.allSatisfy { kind in ArtworkKind.stickers.contains(kind) }
        #expect(listed)
        let design = CardDesign(name: "n", layers: [
            DesignLayer(content: .dial(.engineRPM, .tachometer)), DesignLayer(content: .compass(nil)),
            DesignLayer(content: .glowOrb(.kmPerLitre)),
        ] + stickers.map { DesignLayer(content: .sticker($0)) })
        let back = try CardDesign.importing(design.exportData())
        #expect(back.layers.map(\.content) == design.layers.map(\.content))
        #expect(back.dataFields == [.engineRPM, .kmPerLitre])
        let card = DesignResolver.card(for: back, data: .empty, studio: .empty, at: .now)
        #expect(ImageRenderer(content: DesignView(card: card).frame(width: 170, height: 170)).uiImage != nil)
    }

    // MARK: One-tap use and setups

    @Test func templateGoesOnASlotAsOneCard() {
        let design = Templates.make(.tachometer, source: .obd)
        let slot = TemplateUse.slotDesign(showing: design)
        #expect(slot.studioDesignID == design.id)
        #expect(slot.effectiveLayout == .single)
        #expect(TemplateUse.replacesCards(SlotDesign.splitDefault(for: 2) ?? .starter(for: 2)))
        #expect(!TemplateUse.replacesCards(slot))
    }

    @Test func setupsFillAllFiveSlotsAndUndo() {
        let before = SlotsState.starter
        for setup in ReadySetup.allCases {
            var state = before
            state.panorama = PanoramaSettings(enabled: true, designID: UUID())
            let resolved = setup.resolveDesigns(existing: [])
            state.apply(setup, designs: resolved.use)
            #expect(state.slots.count == SlotsState.slotCount, "\(setup)")
            #expect(state.panorama?.enabled == false, "\(setup) leaves Panorama on")
            #expect(state.undoSetup?.setupName == setup.displayName)
            // Studio designs the setup points at are the ones it asked to save.
            let ids = Set(state.slots.compactMap(\.studioDesignID))
            #expect(ids == Set(resolved.use.map(\.id)), "\(setup)")
            #expect(state.undoLastSetup())
            #expect(state.slots == before.slots, "\(setup) undo")
            #expect(state.panorama?.enabled == true)
            #expect(state.undoSetup == nil)
            #expect(!state.undoLastSetup())
        }
    }

    @Test func setupContents() {
        let daily = ReadySetup.dailyDriver.slots(using: [])
        #expect(daily[0].layoutCards.map(\.source) == [.prayer, .weather])
        #expect(daily[2].layoutCards.map(\.source) == [.parking, .renewals])
        #expect(daily[4].source == .tng)
        let night = ReadySetup.nightCruise.slots(using: ReadySetup.nightCruise.designs)
        let allNeon = night.allSatisfy { slot in slot.look == CardLook.neon }
        #expect(allNeon)
        #expect(night[1].layoutCards.map(\.source) == [.weather, .obd])
        let ramadan = ReadySetup.ramadan.designs
        #expect(ramadan.map(\.template) == ["seasonal.ramadan", TemplateStyle.hijriDate.rawValue])
    }

    @Test func setupsReuseSavedDesigns() {
        let saved = ReadySetup.ramadan.designs
        let again = ReadySetup.ramadan.resolveDesigns(existing: saved)
        #expect(again.new.isEmpty)
        #expect(again.use.map(\.id) == saved.map(\.id))
    }

    @Test func olderSlotsFilesStillLoad() throws {
        var state = SlotsState.starter
        state.undoSetup = nil
        let data = try JSONEncoder().encode(state)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "undoSetup")
        let old = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(SlotsState.self, from: old)
        #expect(back.undoSetup == nil)
        #expect(back.slots == state.slots)
    }
}
