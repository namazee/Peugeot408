import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Phase 16 realistic templates (spec §4b Templates): Small and Medium layouts, JSON, rendering and Live Sky.
@MainActor
struct RealisticTemplateTests {
    private var malaysia: Calendar { PrayerCalendar.malaysia }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        malaysia.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: hour, minute: minute)) ?? .now
    }

    @Test func realisticGroupComesFirstWithAllItsTemplates() {
        #expect(TemplateGroup.allCases.first == .realistic)
        #expect(TemplateGroup.realistic.styles.count == 32)  // 10 + 8 (Phase 17) + 8 (Phase 18) + 6 (Phase 19)
        #expect(TemplateGroup.realistic.styles.allSatisfy { $0.isNew && $0.usesDataSource })
    }

    @Test func smallAndMediumHaveTheirOwnLayouts() {
        for style in TemplateGroup.realistic.styles {
            let small = Templates.make(style, source: .service, canvas: .small)
            let medium = Templates.make(style, source: .service, canvas: .medium)
            #expect(!small.layers.isEmpty, "\(style)")
            #expect(small.canvas == .small && medium.canvas == .medium, "\(style)")
            let positions = { (design: CardDesign) in design.layers.map { [$0.x, $0.y, $0.width, $0.height] } }
            #expect(positions(small) != positions(medium), "\(style) medium is the small layout stretched")
        }
    }

    @Test func glanceableInBothSizes() {
        for style in TemplateGroup.realistic.styles {
            for canvas in DesignCanvas.widgetCanvases {
                let design = Templates.make(style, source: .fuel, canvas: canvas)
                #expect(!DesignLinter.blocksSaving(design), "\(style) \(canvas)")
                let warnings = DesignLinter.warnings(for: design)
                #expect(warnings.isEmpty, "\(style) \(canvas): \(warnings.map(\.message))")
            }
        }
    }

    @Test func renderFromJSONInBothSizes() throws {
        let data = SampleData.carData(now: at(10))
        for style in TemplateGroup.realistic.styles {
            for canvas in DesignCanvas.widgetCanvases {
                let design = Templates.make(style, source: .service, canvas: canvas)
                let back = try CardDesign.importing(design.exportData())
                #expect(back.background == design.background, "\(style) \(canvas)")
                #expect(back.layers.map(\.content) == design.layers.map(\.content), "\(style) \(canvas)")
                #expect(back.layers.map(\.segments) == design.layers.map(\.segments), "\(style) \(canvas)")
                let card = DesignResolver.card(for: back, data: data, studio: .empty, at: at(10))
                let renderer = ImageRenderer(content: DesignView(card: card).frame(width: 170 * canvas.aspectRatio, height: 170))
                #expect(renderer.uiImage != nil, "\(style) \(canvas)")
            }
        }
    }

    @Test func newPiecesSurviveOlderFiles() throws {
        // A layer saved before Phase 16 has no "segments" key.
        let old = #"{"version":1,"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Old","canvas":"small","background":{"solid":{"_0":0}},"layers":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964F0","content":{"progressBar":{"_0":"yearProgress"}},"x":0.5,"y":0.5,"width":0.8,"height":0.1,"rotation":0,"opacity":1,"font":"rounded","weight":"bold","fontSize":28,"colorHex":16777215,"alignment":"leading","shadow":false,"locked":false}],"updatedAt":"2026-01-01T00:00:00Z"}"#
        let design = try CardDesign.importing(Data(old.utf8))
        #expect(design.layers.first?.segments == nil)
        let new = CardDesign(name: "n", background: .frosted(1, 2), layers: [DesignLayer(content: .dial(.kmPerLitre, .fuel)), DesignLayer(content: .odometer(.kmToService))])
        let back = try CardDesign.importing(new.exportData())
        #expect(back.background == .frosted(1, 2))
        #expect(back.layers.map(\.content) == [.dial(.kmPerLitre, .fuel), .odometer(.kmToService)])
        #expect(back.dataFields == [.kmPerLitre, .kmToService])
    }

    @Test func skyFollowsSyurukAndMaghrib() {
        let sun = SunTimes(sunrise: at(7, 5), sunset: at(19, 10))
        #expect(Sky.phase(at: at(3), sun: sun) == .night)
        #expect(Sky.phase(at: at(7, 20), sun: sun) == .dawn)
        #expect(Sky.phase(at: at(12), sun: sun) == .day)
        #expect(Sky.phase(at: at(19), sun: sun) == .dusk)
        #expect(Sky.phase(at: at(21), sun: sun) == .night)
        #expect(Sky.sunProgress(at: at(7, 5), sun: sun) == 0)
        #expect(Sky.sunProgress(at: at(22), sun: sun) == 1)
        #expect(abs(Sky.sunProgress(at: at(13, 7), sun: sun) - 0.5) < 0.01)
    }

    @Test func skyUsesPrayerTimesOrFallback() {
        let fallback = Sky.sunTimes(on: at(12), prayerDays: [], calendar: malaysia)
        #expect(fallback.sunrise == at(7, 15))
        #expect(fallback.sunset == at(19, 20))
        let day = PrayerCalculator.jakim.day(for: at(12), zone: PrayerZone.all[0])
        if let day {
            let sun = Sky.sunTimes(on: at(12), prayerDays: [day], calendar: malaysia)
            #expect(sun == SunTimes(sunrise: day.syuruk, sunset: day.maghrib))
        }
    }

    @Test func liveSkyChangesThroughTheDay() {
        let design = Templates.make(.liveSky, source: .weather, canvas: .medium)
        let dates = DesignResolver.dates(for: design, data: .empty, from: at(6), calendar: malaysia)
        for boundary in [at(7, 15) - Sky.twilight, at(7, 15) + Sky.twilight, at(19, 20) - Sky.twilight, at(19, 20) + Sky.twilight] {
            #expect(dates.contains(boundary), "\(boundary)")
        }
        let card = DesignResolver.card(for: design, data: .empty, studio: .empty, at: at(12), calendar: malaysia)
        #expect(card.sun == SunTimes(sunrise: at(7, 15), sunset: at(19, 20)))
        let other = DesignResolver.card(for: Templates.make(.chromeDial), data: .empty, studio: .empty, at: at(12))
        #expect(other.sun == nil)
    }
}
