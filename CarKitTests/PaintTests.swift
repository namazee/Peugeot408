import Foundation
import Testing
@testable import CarKit

@Suite("My Car paint and plate")
struct PaintTests {
    private let obsessionBlue = (r: 40.0 / 255, g: 120.0 / 255, b: 180.0 / 255)

    @Test func bluePaintCountsAsPaint() {
        #expect(PaintRecolor.weight(r: obsessionBlue.r, g: obsessionBlue.g, b: obsessionBlue.b) == 1)
        // A darker, teal-ish shade from the rear photo still counts.
        #expect(PaintRecolor.weight(r: 0.08, g: 0.35, b: 0.42) > 0.5)
    }

    @Test func trimGlassLightsAndReflectionsAreLeftAlone() {
        #expect(PaintRecolor.weight(r: 0.05, g: 0.05, b: 0.06) == 0)   // black trim / tyres
        #expect(PaintRecolor.weight(r: 0.72, g: 0.75, b: 0.78) == 0)   // grey show plate
        #expect(PaintRecolor.weight(r: 0.85, g: 0.12, b: 0.12) == 0)   // red tail light
        #expect(PaintRecolor.weight(r: 0.30, g: 0.55, b: 0.20) == 0)   // green tree reflection
        #expect(PaintRecolor.weight(r: 1, g: 1, b: 1) == 0)            // white highlight
    }

    @Test func redTargetTurnsBlueIntoRedKeepingShading() {
        let red: UInt32 = 0x8E1A22
        let lit = PaintRecolor.map(r: obsessionBlue.r, g: obsessionBlue.g, b: obsessionBlue.b, target: red)
        #expect(lit.r > lit.g && lit.r > lit.b)
        let shadow = PaintRecolor.map(r: 0.06, g: 0.2, b: 0.32, target: red)
        #expect(shadow.r < lit.r)   // darker paint stays darker
    }

    @Test func nonPaintPixelsAreUnchanged() {
        let plate = PaintRecolor.map(r: 0.72, g: 0.75, b: 0.78, target: 0x8E1A22)
        #expect(plate.r == 0.72 && plate.g == 0.75 && plate.b == 0.78)
    }

    @Test func cubeHasTheRightSize() {
        let cube = PaintRecolor.cube(dimension: 8, target: 0xE6E6E2)
        #expect(cube.count == 8 * 8 * 8 * 4)
        #expect(cube.allSatisfy { (0...1).contains($0) })
        // Pure black (first entry) stays black.
        #expect(Array(cube.prefix(4)) == [0, 0, 0, 1])
    }

    @Test func presetsStartWithTheOriginalBlue() {
        #expect(PaintRecolor.presets.first?.hex == nil)
        #expect(PaintRecolor.presets.count == 5)
    }

    @Test func plateQuadAspectAndGrowth() {
        let quad = PlateQuad((380, 555), (587, 554), (587, 631), (380, 632))
        #expect(abs(quad.aspect - 207.0 / 77.0) < 0.05)
        let grown = quad.expanded(by: 2)
        #expect(grown.topLeft.x < quad.topLeft.x && grown.topLeft.y < quad.topLeft.y)
        #expect(grown.bottomRight.x > quad.bottomRight.x && grown.bottomRight.y > quad.bottomRight.y)
    }

    @Test func plateFontIsKeptAndOlderFilesDecode() throws {
        let state = StudioState(plateText: "VKL 408")
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(StudioState.self, from: data)
        #expect(decoded.plateFont == nil)       // older/default = classic
        #expect(decoded.carPaintHex == nil)     // original blue
        let card = DesignResolver.card(for: Templates.make(.myCar, canvas: .medium), data: .empty, studio: state, at: .now)
        #expect(card.plateFont == .classic)
        #expect(card.plateText == "VKL 408")
    }
}
