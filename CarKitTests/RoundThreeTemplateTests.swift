import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Phase 18 (spec §4b Templates, §3 Panorama hero): another round of realistic, other and Hero templates.
@MainActor
struct RoundThreeTemplateTests {
    private static let realistic: [TemplateStyle] = [.shiftLight, .polaroid, .stickyNote, .dotMatrix, .chalkboard, .thermometer, .battery, .speedSign]
    private static let others: [TemplateStyle] = [.vinyl, .comicPop, .flipClock, .wordClock, .hijriDate, .moonPhase]
    private static let heroes: [TemplateStyle] = [.heroGarage, .heroCoastal, .heroRainCity, .heroStartingGrid, .heroMountainPass, .heroDepartureBoard]

    private var malaysia: Calendar { PrayerCalendar.malaysia }

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        malaysia.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }

    @Test func groups() {
        #expect(Self.realistic.allSatisfy { $0.group == .realistic && $0.usesDataSource })
        #expect([TemplateStyle.vinyl, .comicPop].allSatisfy { $0.group == .data && $0.usesDataSource })
        #expect([TemplateStyle.flipClock, .wordClock, .hijriDate].allSatisfy { $0.group == .clockDate && !$0.usesDataSource })
        #expect(TemplateStyle.moonPhase.group == .special)
        #expect(Self.heroes.allSatisfy { $0.group == .hero && !$0.usesDataSource })
        #expect((Self.realistic + Self.others + Self.heroes).allSatisfy(\.isNew))
    }

    @Test func glanceableWithTheirOwnSmallAndMedium() {
        for style in Self.realistic + Self.others {
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
        let now = at(2026, 11, 21, 21)
        let data = SampleData.carData(now: now)
        var designs = Self.heroes.map { Templates.make($0) }
        for style in Self.realistic + Self.others {
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
        let design = CardDesign(name: "n", background: .texture(.halftone, 0xFFD400), layers: [
            DesignLayer(content: .shiftLights(.engineRPM)), DesignLayer(content: .thermometer(nil)),
            DesignLayer(content: .battery(.tngBalance)), DesignLayer(content: .moonPhase),
            DesignLayer(content: .data(.hijriDate)), DesignLayer(content: .sticker(.vinylRecord)),
        ])
        let back = try CardDesign.importing(design.exportData())
        #expect(back.layers.map(\.content) == design.layers.map(\.content))
        #expect(back.dataFields == [.engineRPM, .tngBalance, .hijriDate])
        for texture in [DesignTexture.cork, .chalkboard] {
            #expect(try CardDesign.importing(CardDesign(name: "t", background: .texture(texture, 1)).exportData()).background == .texture(texture, 1))
        }
    }

    @Test func wordClock() {
        #expect(WordClock.text(at: at(2026, 11, 21, 10, 30), calendar: malaysia) == "HALF PAST TEN")
        #expect(WordClock.text(at: at(2026, 11, 21, 10, 52), calendar: malaysia) == "TEN TO ELEVEN")
        #expect(WordClock.text(at: at(2026, 11, 21, 23, 58), calendar: malaysia) == "TWELVE O'CLOCK")
        #expect(WordClock.text(at: at(2026, 11, 21, 0, 2), calendar: malaysia) == "TWELVE O'CLOCK")
        #expect(WordClock.text(at: at(2026, 11, 21, 13, 13), calendar: malaysia) == "QUARTER PAST ONE")
        let changes = WordClock.changeDates(from: at(2026, 11, 21, 10, 1), count: 3, calendar: malaysia)
        #expect(changes == [at(2026, 11, 21, 10, 3), at(2026, 11, 21, 10, 8), at(2026, 11, 21, 10, 13)])
        let design = Templates.make(.wordClock)
        let dates = DesignResolver.dates(for: design, data: .empty, from: at(2026, 11, 21, 10, 1), calendar: malaysia)
        #expect(dates.contains(at(2026, 11, 21, 10, 8)))
    }

    @Test func hijriAndMoon() {
        let kl = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
        // Mid-March 2026 falls in Ramadan 1447; late November 2026 in Jamadilawal or Jamadilakhir 1448.
        #expect(HijriDate.text(at: at(2026, 3, 5, 12), timeZone: kl).hasSuffix(" Ramadan 1447"))
        let november = HijriDate.text(at: at(2026, 11, 21, 12), timeZone: kl)
        #expect(november.hasSuffix(" 1448") && (november.contains("Jamadilawal") || november.contains("Jamadilakhir")), "\(november)")
        #expect(HijriDate.months.count == 12)
        // Full moon on 24 November 2026 (about 22:53 Malaysia time); new moon on 9 November 2026.
        #expect(MoonPhase.name(at: at(2026, 11, 25, 0)) == "Full moon")
        #expect(MoonPhase.name(at: at(2026, 11, 9, 12)) == "New moon")
        #expect(MoonPhase.name(at: at(2026, 11, 13, 12)) == "Waxing crescent")
        let f = MoonPhase.fraction(at: at(2026, 11, 21, 0))
        #expect(f > 0.25 && f < 0.5)
    }
}
