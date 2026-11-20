import Foundation
import SwiftUI
import Testing
@testable import CarKit

private let my = PrayerCalendar.malaysia

private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    my.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
}

private func roundTrip(_ design: CardDesign) throws -> CardDesign {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(CardDesign.self, from: design.exportData())
}

private var allTemplates: [CardDesign] {
    DesignCanvas.allCases.flatMap { canvas in
        TemplateStyle.allCases.map { Templates.make($0, source: .prayer, canvas: canvas, eventDate: at(2017, 4, 21)) }
            + SeasonalOccasion.allCases.map { Templates.seasonal($0, canvas: canvas) }
    }
}

@Suite("Studio designs")
struct StudioDesignTests {
    @Test func everyTemplateSurvivesJSON() throws {
        for design in allTemplates {
            #expect(try roundTrip(design) == design, "\(design.name)")
        }
    }

    /// Renders each template from its JSON with the same view the widget uses.
    @MainActor
    @Test func everyTemplateRendersFromJSON() throws {
        let data = SampleData.carData(now: at(2026, 11, 20, 9))
        for design in allTemplates {
            let decoded = try roundTrip(design)
            let card = DesignResolver.card(for: decoded, data: data, studio: .empty, at: at(2026, 11, 20, 9))
            let size = CGSize(width: 170 * decoded.canvas.aspectRatio, height: 170)
            let renderer = ImageRenderer(content: DesignView(card: card).frame(width: size.width, height: size.height))
            renderer.scale = 1
            let image = try #require(renderer.cgImage, "\(design.name) didn't render")
            #expect(image.width == Int(size.width.rounded()))
            #expect(image.height == 170)
        }
    }

    @Test func templatesStayGlanceable() {
        for design in allTemplates {
            #expect(!DesignLinter.blocksSaving(design), "\(design.name) has too many data fields")
            let small = DesignLinter.warnings(for: design).filter { $0.message.contains("too small") }
            #expect(small.isEmpty, "\(design.name): \(small.map(\.message))")
        }
    }

    @Test func importGivesFreshIDs() throws {
        let design = Templates.make(.sporty, source: .fuel)
        let imported = try CardDesign.importing(design.exportData())
        #expect(imported.id != design.id)
        #expect(Set(imported.layers.map(\.id)).isDisjoint(with: Set(design.layers.map(\.id))))
        #expect(imported.layers.map(\.content) == design.layers.map(\.content))
    }

    @Test func newerFormatIsRefused() throws {
        var design = Templates.make(.minimal)
        design.version = CardDesign.currentVersion + 1
        #expect(throws: StudioError.newerVersion(CardDesign.currentVersion + 1)) {
            try CardDesign.importing(design.exportData())
        }
    }

    @Test func designSourcesFollowItsFields() {
        let design = Templates.make(.premium, source: .service)
        #expect(design.sources == [.service])
        #expect(Templates.make(.clockDigital).sources.isEmpty)
    }
}

@Suite("Glanceability linter")
struct LinterTests {
    @Test func contrastRatios() {
        #expect(abs(ColorMath.contrast(0xFFFFFF, 0x000000) - 21) < 0.01)
        #expect(abs(ColorMath.contrast(0x777777, 0x777777) - 1) < 0.01)
    }

    @Test func threeDataFieldsOnSmallBlockSaving() {
        let layers = [DataField.clock, .date, .temperature].map { DesignLayer(content: .data($0), fontSize: 20) }
        let design = CardDesign(name: "Busy", canvas: .small, background: .solid(0x000000), layers: layers)
        #expect(DesignLinter.blocksSaving(design))
        var medium = design
        medium.canvas = .medium
        #expect(!DesignLinter.blocksSaving(medium))
    }

    @Test func smallTextAndLowContrastWarn() {
        let tiny = DesignLayer(content: .text("Hi"), fontSize: 9, colorHex: 0xFFFFFF)
        let dim = DesignLayer(content: .text("Hello"), fontSize: 24, colorHex: 0x222222)
        let design = CardDesign(name: "Bad", background: .solid(0x111111), layers: [tiny, dim])
        let warnings = DesignLinter.warnings(for: design)
        #expect(warnings.contains { $0.layerID == tiny.id && $0.message.contains("too small") })
        #expect(warnings.contains { $0.layerID == dim.id && $0.message.contains("contrast") })
    }

    @Test func photoBackgroundsSkipTheContrastCheck() {
        let layer = DesignLayer(content: .text("Hello"), fontSize: 24, colorHex: 0x222222)
        let design = CardDesign(name: "Photo", background: .photo("p.jpg"), layers: [layer])
        #expect(DesignLinter.warnings(for: design).isEmpty)
    }
}

@Suite("Data fields")
struct DataFieldTests {
    @Test func anniversaryCountsYearsThenDays() {
        let married = at(2017, 4, 21)
        let later = my.date(byAdding: .day, value: 213, to: at(2026, 4, 21)) ?? .now
        #expect(DesignResolver.anniversaryText(from: married, to: later, calendar: my) == "9 years, 213 days")
        #expect(DesignResolver.anniversaryText(from: married, to: at(2026, 4, 21), calendar: my) == "9 years")
        #expect(DesignResolver.anniversaryText(from: married, to: at(2017, 4, 23), calendar: my) == "2 days")
    }

    @Test func countdownDaysToEvent() {
        let design = CardDesign(name: "Trip", eventDate: at(2026, 12, 1))
        let value = DesignResolver.resolve(.countdownDays, data: .empty, design: design, at: at(2026, 11, 20), calendar: my)
        #expect(value.text == "11 days")
    }

    @Test func iftarCountsDownToMaghrib() {
        let zone = PrayerZone.all[0]
        let day = PrayerCalculator.jakim.day(for: at(2027, 2, 20), zone: zone)
        let data = CarData(prayer: PrayerCache(zoneCode: "SGR01", days: day.map { [$0] } ?? []))
        let value = DesignResolver.resolve(.iftarCountdown, data: data, design: CardDesign(name: "R"), at: at(2027, 2, 20, 15), calendar: my)
        #expect(value.style == .timer(day?.maghrib ?? .distantPast))
        let after = DesignResolver.resolve(.iftarCountdown, data: data, design: CardDesign(name: "R"), at: at(2027, 2, 20, 21), calendar: my)
        #expect(after.text == "Selamat berbuka")
    }

    @Test func missingDataShowsDashes() {
        let design = CardDesign(name: "Empty")
        for field in DataField.allCases {
            let value = DesignResolver.resolve(field, data: .empty, design: design, at: at(2026, 11, 20), calendar: my)
            #expect(!value.text.isEmpty || value.style != .plain, "\(field)")
        }
    }

    @Test func analogueClockGetsMinuteEntries() {
        let design = Templates.make(.clockAnalog)
        let dates = DesignResolver.dates(for: design, data: .empty, from: at(2026, 11, 20, 9), calendar: my)
        #expect(dates.count >= 61)
        #expect(dates[1].timeIntervalSince(dates[0]) == 60)
    }
}

@Suite("Seasonal packs")
struct SeasonalTests {
    @Test func fixedDateOccasions() {
        let settings = SeasonalSettings(enabled: true)
        #expect(SeasonalCalendar.active(at: at(2026, 8, 31), settings: settings) == .merdeka)
        #expect(SeasonalCalendar.active(at: at(2026, 9, 16), settings: settings) == .merdeka)
        #expect(SeasonalCalendar.active(at: at(2026, 9, 20), settings: settings) == nil)
        #expect(SeasonalCalendar.active(at: at(2026, 12, 25), settings: settings) == .christmas)
        #expect(SeasonalCalendar.active(at: at(2027, 1, 1), settings: settings) == .newYear)
    }

    @Test func chineseNewYear2027() {
        #expect(SeasonalCalendar.mainDay(of: .chineseNewYear, year: 2027) == at(2027, 2, 6, 0))
        #expect(SeasonalCalendar.active(at: at(2027, 2, 6), settings: SeasonalSettings()) == .chineseNewYear)
    }

    @Test func rayaAndRamadanFollowTheHijriCalendar() throws {
        let raya = try #require(SeasonalCalendar.mainDay(of: .hariRaya, year: 2027))
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = my.timeZone
        #expect(islamic.component(.month, from: raya) == 10)
        #expect(islamic.component(.day, from: raya) == 1)
        #expect(SeasonalCalendar.active(at: raya.addingTimeInterval(12 * 3600), settings: SeasonalSettings()) == .hariRaya)
        let midRamadan = raya.addingTimeInterval(-15 * 86_400)
        #expect(SeasonalCalendar.active(at: midRamadan, settings: SeasonalSettings()) == .ramadan)
    }

    @Test func deepavaliComesFromTheEditableTable() {
        var settings = SeasonalSettings()
        #expect(SeasonalCalendar.active(at: at(2027, 10, 28), settings: settings) == .deepavali)
        settings.deepavaliDates[2027] = "2027-10-29"
        #expect(SeasonalCalendar.mainDay(of: .deepavali, year: 2027, settings: settings) == at(2027, 10, 29, 0))
    }

    @Test func disabledPacksAreSkipped() {
        let settings = SeasonalSettings(disabled: [.christmas])
        #expect(SeasonalCalendar.active(at: at(2026, 12, 25), settings: settings) == nil)
    }
}

@Suite("Slot rotation")
struct SlotRotationTests {
    @Test func hourWindowsWrapPastMidnight() {
        let evening = SlotRotation(choice: SlotChoice(source: .prayer), fromHour: 18, toHour: 6)
        #expect(evening.contains(hour: 23))
        #expect(evening.contains(hour: 3))
        #expect(!evening.contains(hour: 12))
        let dawn = SlotRotation(choice: SlotChoice(source: .prayer), fromHour: 5, toHour: 7)
        #expect(dawn.contains(hour: 5) && dawn.contains(hour: 6) && !dawn.contains(hour: 7))
    }

    @Test func rotationSwitchesContentAtItsHours() {
        var state = SlotsState.starter
        var design = SlotDesign.starter(for: 1)
        design.source = .service
        design.rotations = [SlotRotation(choice: SlotChoice(source: .tng), fromHour: 18, toHour: 21)]
        state.setDesign(design, for: 1)
        let items = SlotTimeline.items(slot: 1, state: state, data: .empty, now: at(2026, 11, 20, 17), calendar: my)
        #expect(items.contains { $0.date == at(2026, 11, 20, 18) })
        #expect(items.contains { $0.date == at(2026, 11, 20, 21) })
        func source(at date: Date) -> DataSource? {
            guard case .data(let card) = items.last(where: { $0.date <= date })?.content else { return nil }
            return card.source
        }
        #expect(source(at: at(2026, 11, 20, 17)) == .service)
        #expect(source(at: at(2026, 11, 20, 19)) == .tng)
        #expect(source(at: at(2026, 11, 20, 22)) == .service)
    }

    @Test func studioDesignInASlot() {
        let design = Templates.make(.minimal, source: .tng)
        let studio = StudioState(designs: [design])
        var state = SlotsState.starter
        var slot = SlotDesign.starter(for: 2)
        slot.studioDesignID = design.id
        state.setDesign(slot, for: 2)
        let items = SlotTimeline.items(slot: 2, state: state, data: .empty, studio: studio, now: at(2026, 11, 20), calendar: my)
        guard case .studio(let card) = items.first?.content else {
            Issue.record("expected a Studio card")
            return
        }
        #expect(card.design.id == design.id)
        #expect(SlotTimeline.sources(slot: 2, state: state, studio: studio) == [.tng])
    }

    @Test func seasonalTakeoverOnlyOnItsSlotAndDates() {
        let studio = StudioState(seasonal: SeasonalSettings(enabled: true, slot: 3))
        let state = SlotsState.starter
        let merdeka = SlotTimeline.items(slot: 3, state: state, studio: studio, now: at(2026, 8, 31), calendar: my)
        if case .studio(let card) = merdeka.first?.content {
            #expect(card.design.template == "seasonal.merdeka")
        } else {
            Issue.record("expected the Merdeka design")
        }
        let otherSlot = SlotTimeline.items(slot: 1, state: state, studio: studio, now: at(2026, 8, 31), calendar: my)
        if case .studio = otherSlot.first?.content { Issue.record("slot 1 shouldn't change") }
        let normalDay = SlotTimeline.items(slot: 3, state: state, studio: studio, now: at(2026, 10, 1), calendar: my)
        if case .studio = normalDay.first?.content { Issue.record("no occasion on 1 October") }
    }

    @Test func olderSlotFilesStillDecode() throws {
        let json = #"{"value":"Slot 2","title":"Set in app","symbol":"star.fill","style":"dark","source":"fuel"}"#
        let design = try JSONDecoder().decode(SlotDesign.self, from: Data(json.utf8))
        #expect(design.studioDesignID == nil)
        #expect(design.rotations == nil)
        #expect(design.source == .fuel)
    }
}
