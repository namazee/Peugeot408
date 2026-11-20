import Foundation
import Testing
@testable import CarKit

@Suite("JSON backup")
struct BackupTests {
    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    @Test func exportThenRestoreGivesTheSameData() throws {
        let source = folder()
        let fuel = FuelLog(fillUps: [FillUp(date: Date(timeIntervalSince1970: 1_790_000_000), odometerKm: 12_345, litres: 40.5, totalRM: 81.2)])
        let tng = TnGState(balance: 42.5, threshold: 25)
        var slots = SlotsState.starter
        slots.setDesign(SlotDesign(value: "408", title: "GT", symbol: "car.fill", imageFile: SlotDesign.myCarImageFile), for: 4)
        try CarStores.fuel(in: source).save(fuel)
        try CarStores.tng(in: source).save(tng)
        try SlotStore(directory: source).save(slots)

        let backup = try Backup.export(from: source, now: Date(timeIntervalSince1970: 1_790_000_000))
        let target = folder()
        let result = try Backup.restore(backup, into: target)

        #expect(Set(result.restored) == ["Fuel", "Touch 'n Go", "Car Slots"])
        #expect(result.createdAt == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(CarStores.fuel(in: target).load() == fuel)
        #expect(CarStores.tng(in: target).load() == tng)
        #expect(SlotStore(directory: target).load().design(for: 4).imageFile == "mycar.png")
    }

    @Test func damagedBackupChangesNothing() throws {
        let target = folder()
        let kept = TnGState(balance: 10)
        try CarStores.tng(in: target).save(kept)
        let json = #"{"format":"peugeot408-backup","version":1,"files":{"tng.json":{"balance":99,"version":1,"threshold":20,"history":[]},"fuel.json":{"fillUps":"oops"}}}"#
        #expect(throws: Backup.BackupError.badFile("Fuel")) {
            try Backup.restore(Data(json.utf8), into: target)
        }
        #expect(CarStores.tng(in: target).load() == kept)
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: Backup.BackupError.notABackup) {
            try Backup.restore(Data(#"{"designs":[]}"#.utf8), into: folder())
        }
        #expect(throws: Backup.BackupError.newerVersion(9)) {
            try Backup.restore(Data(#"{"format":"peugeot408-backup","version":9,"files":{}}"#.utf8), into: folder())
        }
    }
}
