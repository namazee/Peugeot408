import Foundation
import SwiftUI
import Testing
@testable import CarKit

/// Phase 21 (spec §3): Blend edges on the Panorama hero.
@MainActor
struct PanoramaBlendTests {
    private func blend(of content: SlotContent?) -> Bool? {
        guard case .panorama(_, _, let blend) = content else { return nil }
        return blend
    }

    @Test func onByDefaultAndForOlderFiles() throws {
        #expect(PanoramaSettings().blends)
        let data = try JSONEncoder().encode(PanoramaSettings(enabled: true, designID: UUID()))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "blendEdges")
        let back = try JSONDecoder().decode(PanoramaSettings.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(back.blends)
    }

    @Test func slotsFollowTheToggle() {
        let hero = Templates.make(.hero)
        let studio = StudioState(designs: [hero])
        var state = SlotsState.starter
        let now = Date()
        for on in [true, false] {
            state.panorama = PanoramaSettings(enabled: true, designID: hero.id, blendEdges: on)
            for slot in 1...3 {
                #expect(blend(of: SlotTimeline.items(slot: slot, state: state, studio: studio, now: now).first?.content) == on)
                #expect(blend(of: SlotTimeline.currentContent(slot: slot, state: state, data: .empty, studio: studio, at: now)) == on)
            }
        }
    }

    @Test func bothLooksRender() {
        let card = DesignResolver.card(for: Templates.make(.hero), data: .empty, studio: .empty, at: .now)
        for blend in [true, false] {
            for part in 0..<PanoramaGeometry.columns {
                let view = PanoramaSlice(card: card, part: part, blend: blend).frame(width: 120, height: 167)
                #expect(ImageRenderer(content: view).uiImage != nil)
            }
        }
    }
}
