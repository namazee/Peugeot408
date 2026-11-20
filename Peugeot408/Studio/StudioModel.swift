import CarKit
import Foundation
import Observation
import UIKit
import WidgetKit

/// App-side owner of `studio.json` (designs, seasonal packs, My Car photo).
/// Saving reloads only the Car Slots that can show the changed design.
@MainActor
@Observable
final class StudioModel {
    private(set) var state: StudioState
    var lastError: String?
    /// True while a studio-render photo is being cut out and painted.
    private(set) var isPreparingPhoto = false

    @ObservationIgnored let directory: URL

    init(directory: URL = AppGroup.containerURL) {
        self.directory = directory
        self.state = StudioStores.studio(in: directory).load()
        // Spec: the side view is used until a photo is chosen.
        if state.carPhotoFile == nil {
            useBuiltInCarPhoto(BuiltInCarPhoto.defaultID)
        }
    }

    /// Renders a bundled photo (with the chosen paint colour and plate) into the App Group as the My Car photo.
    /// Studio renders are cut out on the device first (the Vision mask is cached in the App Group).
    func useBuiltInCarPhoto(_ id: String) {
        guard let photo = BuiltInCarPhoto.all.first(where: { $0.id == id }) else { return }
        let font = state.plateFont ?? .classic
        if photo.needsCutout {
            isPreparingPhoto = true
            Task {
                defer { isPreparingPhoto = false }
                guard let processed = CarPhotoRenderer.processed(photo, paintHex: state.carPaintHex, plate: state.plateText, font: font),
                      let mask = await cutoutMask(for: photo),
                      let cutout = CarCutout.composite(image: UIImage(cgImage: processed), mask: mask, maxPixelSize: 900),
                      let png = cutout.pngData() else {
                    lastError = "Couldn't cut out that photo on this device."
                    return
                }
                finishBuiltIn(png, id: id)
            }
            return
        }
        guard let png = CarPhotoRenderer.render(photo, paintHex: state.carPaintHex, plate: state.plateText, font: font) else {
            lastError = "Couldn't prepare that photo."
            return
        }
        finishBuiltIn(png, id: id)
    }

    /// The foreground mask of a studio render: made once with Vision, then reused.
    private func cutoutMask(for photo: BuiltInCarPhoto) async -> UIImage? {
        let cache = directory.appending(path: "mask-\(photo.id).png", directoryHint: .notDirectory)
        if let cached = UIImage(contentsOfFile: cache.path(percentEncoded: false)) { return cached }
        guard let url = photo.url, let data = try? Data(contentsOf: url),
              let result = try? await CarCutout.makeMask(from: data) else { return nil }
        try? result.mask.pngData()?.write(to: cache, options: .atomic)
        return result.mask
    }

    private func finishBuiltIn(_ png: Data, id: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: StudioState.carPhotoFileName, directoryHint: .notDirectory)
            try png.write(to: target, options: .atomic)
            var next = state
            next.builtInCarPhoto = id
            next.carPhotoFile = StudioState.carPhotoFileName
            state = next
            setCarPhoto(file: StudioState.carPhotoFileName)
        } catch {
            lastError = "Couldn't use that photo: \(error.localizedDescription)"
        }
    }

    func reload() {
        state = StudioStores.studio(in: directory).load()
    }

    func design(_ id: UUID?) -> CardDesign? { state.design(id) }

    func save(_ design: CardDesign) {
        var next = state
        var stamped = design
        stamped.updatedAt = .now
        if let index = next.designs.firstIndex(where: { $0.id == design.id }) {
            next.designs[index] = stamped
        } else {
            next.designs.append(stamped)
        }
        commit(next, reloadSlotsShowing: [design.id])
    }

    func delete(_ ids: Set<UUID>) {
        var next = state
        next.designs.removeAll { ids.contains($0.id) }
        commit(next, reloadSlotsShowing: ids)
    }

    func updateSeasonal(_ change: (inout SeasonalSettings) -> Void) {
        var next = state
        let oldSlot = next.seasonal.slot
        change(&next.seasonal)
        commit(next, reloadSlotsShowing: [])
        reloadSlots([oldSlot, next.seasonal.slot])
    }

    /// Your own cut-out photo replaces the built-in one.
    func setCustomCarPhoto() {
        var next = state
        next.builtInCarPhoto = nil
        state = next
        setCarPhoto(file: StudioState.carPhotoFileName)
    }

    func setCarPhoto(file: String?, plate: String? = nil) {
        var next = state
        next.carPhotoFile = file
        if let plate { next.plateText = plate }
        commit(next, reloadSlotsShowing: Set(next.designs.filter { $0.layers.contains { $0.content == .carPhoto || $0.content == .plate("") } }.map(\.id)))
    }

    /// Paint colour of the built-in photos (nil = original blue). Re-renders the photo in use.
    func setPaint(_ hex: UInt32?) {
        var next = state
        next.carPaintHex = hex
        commit(next, reloadSlotsShowing: [])
        rerenderBuiltIn()
    }

    func setPlateFont(_ font: PlateFont) {
        var next = state
        next.plateFont = font
        commit(next, reloadSlotsShowing: Set(next.designs.map(\.id)))
        rerenderBuiltIn()
    }

    private func rerenderBuiltIn() {
        if let id = state.builtInCarPhoto { useBuiltInCarPhoto(id) }
    }

    func setPlate(_ text: String) {
        var next = state
        next.plateText = text
        commit(next, reloadSlotsShowing: Set(next.designs.map(\.id)))
        rerenderBuiltIn()
    }

    /// Imports a design file (fresh id).
    func importDesign(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let design = try CardDesign.importing(Data(contentsOf: url))
            save(design)
        } catch {
            lastError = "Couldn't import: \(error.localizedDescription)"
        }
    }

    /// A file for the share sheet.
    func exportURL(for design: CardDesign) -> URL? {
        let safe = design.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(safe).peugeot408.json", directoryHint: .notDirectory)
        do {
            try design.exportData().write(to: url, options: .atomic)
            return url
        } catch {
            lastError = "Couldn't export: \(error.localizedDescription)"
            return nil
        }
    }

    private func commit(_ next: StudioState, reloadSlotsShowing ids: Set<UUID>) {
        do {
            try StudioStores.studio(in: directory).save(next)
            state = next
            lastError = nil
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
            return
        }
        let slots = SlotStore(directory: directory).load()
        let affected = SlotsState.slotNumbers.filter { slot in
            let design = slots.design(for: slot)
            let choices = [design.primaryChoice] + (design.rotations ?? []).map(\.choice)
            return choices.contains { $0.studioDesignID.map(ids.contains) ?? false }
        }
        reloadSlots(affected)
    }

    private func reloadSlots(_ slots: [Int]) {
        for slot in Set(slots) {
            WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
        }
    }
}

/// Built-in My Car photos (spec §4b): supplied by the owner, badges pixelated.
/// Files: `Resources/MyCar/mycar-<id>.png` (already cut out) and `mycar-studio-<view>.jpg`
/// (dark studio background, cut out on the device). Plate corners are in the file's pixels.
struct BuiltInCarPhoto: Identifiable {
    let id: String
    let name: String
    /// Corners of the show plate, measured from the photo; nil when no plate is visible.
    var plateQuad: PlateQuad? = nil
    /// Studio renders keep their background in the bundle; Vision removes it.
    var needsCutout = false
    /// Window outlines (pixels), kept out of the paint recolour.
    var glass: [[(Double, Double)]] = []

    var resource: String { "mycar-\(id)" }
    var fileExtension: String { needsCutout ? "jpg" : "png" }
    var url: URL? { Bundle.main.url(forResource: resource, withExtension: fileExtension) }

    static let defaultID = "side"

    static let all: [BuiltInCarPhoto] = [
        BuiltInCarPhoto(id: "side", name: "Side", glass: [[(160, 52), (215, 30), (330, 20), (420, 17), (500, 28), (560, 52), (602, 88), (430, 90), (272, 84), (205, 75)]]),
        BuiltInCarPhoto(id: "front-three-quarter", name: "Front ¾", plateQuad: PlateQuad((575, 406), (762, 398), (762, 455), (575, 464)), glass: [[(222, 30), (545, 28), (575, 50), (665, 138), (560, 145), (232, 150), (218, 90)], [(40, 75), (110, 35), (198, 28), (205, 145), (160, 140), (95, 110), (55, 98)]]),
        BuiltInCarPhoto(id: "rear-three-quarter", name: "Rear ¾", plateQuad: PlateQuad((87, 174), (186, 172), (184, 200), (82, 203)), glass: [[(95, 72), (175, 40), (335, 38), (385, 62), (350, 92), (240, 98), (108, 98)], [(440, 62), (475, 40), (560, 30), (640, 35), (748, 102), (700, 108), (520, 112), (440, 95)]]),
        BuiltInCarPhoto(id: "front", name: "Front", plateQuad: PlateQuad((380, 555), (587, 554), (587, 631), (380, 632)), glass: [[(215, 42), (685, 42), (740, 120), (755, 192), (140, 192), (160, 120)]]),
        BuiltInCarPhoto(id: "front-detail", name: "Front detail", plateQuad: PlateQuad((828, 377), (892, 339), (890, 413), (830, 455)), glass: [[(0, 0), (300, 0), (345, 25), (200, 45), (60, 62), (0, 70)]]),
        // Studio renders (1024 x 1024).
        BuiltInCarPhoto(id: "studio-front-three-quarter", name: "Studio front ¾", plateQuad: PlateQuad((262, 676), (478, 678), (478, 731), (262, 728)), needsCutout: true, glass: [[(288, 380), (410, 260), (782, 256), (808, 300), (808, 392), (560, 384)], [(800, 255), (858, 262), (906, 345), (812, 392)]]),
        BuiltInCarPhoto(id: "studio-front", name: "Studio front", plateQuad: PlateQuad((378, 708), (646, 708), (646, 760), (378, 760)), needsCutout: true, glass: [[(268, 222), (752, 222), (838, 366), (172, 366)]]),
        BuiltInCarPhoto(id: "studio-side", name: "Studio side", needsCutout: true, glass: [[(158, 447), (240, 412), (330, 402), (470, 400), (585, 410), (708, 484), (500, 486), (265, 464)]]),
        BuiltInCarPhoto(id: "studio-rear-three-quarter", name: "Studio rear ¾", plateQuad: PlateQuad((750, 522), (874, 516), (873, 557), (749, 562)), needsCutout: true, glass: [[(178, 452), (262, 378), (332, 350), (482, 350), (522, 396), (470, 422), (360, 442), (232, 455)], [(522, 362), (600, 344), (762, 350), (884, 418), (820, 428), (640, 422), (562, 398)]]),
        BuiltInCarPhoto(id: "studio-rear", name: "Studio rear", plateQuad: PlateQuad((383, 519), (641, 519), (641, 576), (383, 576)), needsCutout: true, glass: [[(240, 243), (782, 243), (812, 362), (204, 362)]]),
        BuiltInCarPhoto(id: "studio-front-detail", name: "Studio detail", plateQuad: PlateQuad((826, 572), (893, 548), (894, 617), (828, 646)), needsCutout: true, glass: [[(0, 98), (125, 112), (302, 236), (205, 248), (0, 268)]]),
    ]
}
