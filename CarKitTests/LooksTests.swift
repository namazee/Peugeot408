import Foundation
import SwiftUI
import Testing
@testable import CarKit

@Suite("Widget looks and new templates")
struct LooksTests {
    @Test func olderFilesHaveNoLookAndDefaultToBold() throws {
        let json = #"{"value":"408","title":"GT","symbol":"car.fill","style":"dark"}"#
        let design = try JSONDecoder().decode(SlotDesign.self, from: Data(json.utf8))
        #expect(design.look == nil)
        #expect(AppearanceSettings.default.look == .bold)
        let missing = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        #expect(AppearanceStore.settings(in: missing).load().look == .bold)
    }

    @Test func customSlotColour() throws {
        var design = SlotDesign(value: "408", title: "GT", symbol: "car.fill", style: .custom, backgroundHex: 0x8E1A22)
        #expect(design.paint.hex(.bold) == 0x8E1A22)
        #expect(SlotContent.design(design).cardStyle == .standard)
        #expect(!design.needsDarkText)
        design.backgroundHex = 0xE6E6E2
        #expect(design.needsDarkText)
        let back = try JSONDecoder().decode(SlotDesign.self, from: JSONEncoder().encode(design))
        #expect(back.backgroundHex == 0xE6E6E2 && back.style == .custom)
        #expect(SlotContent.design(SlotDesign(value: "", title: "", symbol: "car.fill")).cardStyle == .frame)
    }

    @Test func centrePictureAlignmentAndSizes() {
        let data = SampleData.carData(now: Date())
        var design = SlotDesign.card(.service)
        design.centerImageFile = SlotDesign.myCarImageFile
        let content = SlotTimeline.content(at: .now, design: design, rotations: [], seasonal: false, data: data, studio: .empty)
        guard case .pictured(let card, let file) = content else {
            Issue.record("expected a pictured data card")
            return
        }
        #expect(card.source == .service && file == "mycar.png")
        #expect(content.cardStyle == .standard)
        design.source = .map
        let map = SlotTimeline.content(at: .now, design: design, rotations: [], seasonal: false, data: data, studio: .empty)
        if case .pictured = map { Issue.record("map cards keep their own image") }

        var text = SlotDesign(value: "408", title: "GT", symbol: "car.fill", textAlignment: .trailing, valueScale: 3, labelScale: 0.2)
        #expect(text.clampedValueScale == 1.5 && text.clampedLabelScale == 0.7)
        text.valueScale = nil
        #expect(text.clampedValueScale == 1)
        #expect(SlotContentView.alignment(.center).text == .center)
    }

    @Test func paintFollowsSourceAndState() {
        #expect(CardPaint(source: .fuel).hex(.bold) == ThemeTokens.bold["fuel"])
        #expect(CardPaint(source: .fuel).hex(.neon) == ThemeTokens.neon["fuel"])
        #expect(CardPaint(source: .service, stateHex: Theme.Hex.overdue).hex(.bold) == Theme.Hex.overdue)
        #expect(CardPaint.plain.hex(.bold) == Theme.Hex.accent)
        for source in DataSource.allCases {
            #expect(ThemeTokens.bold[source.rawValue] != nil, "bold \(source)")
            #expect(ThemeTokens.neon[source.rawValue] != nil, "neon \(source)")
        }
    }

    @Test func sampleCardsHaveFaces() {
        let now = Date()
        for source in [DataSource.service, .fuel, .renewals, .tng, .parking, .prayer, .weather, .obd] {
            let face = SampleData.card(for: source, now: now).face
            #expect(face != nil, "\(source)")
            if let progress = face?.progress { #expect((0...1).contains(progress), "\(source)") }
        }
        #expect(SampleData.card(for: .map, now: now).face == nil)
        #expect(CarData.empty.card(for: .service, at: now).face == nil)
    }

    @Test func newTemplatesAreGlanceable() {
        for style in TemplateStyle.allCases where style.isNew {
            for canvas in DesignCanvas.allCases {
                let design = Templates.make(style, source: .service, canvas: canvas)
                #expect(!DesignLinter.blocksSaving(design), "\(style) \(canvas)")
                let small = DesignLinter.warnings(for: design).filter { $0.message.contains("too small") }
                #expect(small.isEmpty, "\(style) \(canvas): \(small.map(\.message))")
            }
        }
        #expect(TemplateGroup.allCases.flatMap(\.styles).count == TemplateStyle.allCases.count)
        #expect(TemplateStyle.allCases.filter(\.isNew).count == 23)
    }

    @Test func calendarFields() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
        let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 12)) ?? .now
        let design = CardDesign(name: "t")
        let day = DesignResolver.resolve(.dayOfMonth, data: .empty, design: design, at: date, calendar: calendar)
        #expect(day.text == "1")
        let year = DesignResolver.resolve(.yearProgress, data: .empty, design: design, at: date, calendar: calendar)
        #expect(year.text == "24%")
        #expect(abs((year.progress ?? 0) - 90.5 / 365) < 0.001)
    }

    @Test func newBackgroundsAndLayersSurviveJSON() throws {
        let design = CardDesign(name: "x", background: .aurora(1, 2, 3),
                                layers: [DesignLayer(content: .ring(.kmToService), glow: true), DesignLayer(content: .progressBar(nil))])
        let data = try design.exportData()
        let back = try CardDesign.importing(data)
        #expect(back.background == .aurora(1, 2, 3))
        #expect(back.layers.first?.glow == true)
        #expect(back.layers.last?.content == .progressBar(nil))
    }
}
