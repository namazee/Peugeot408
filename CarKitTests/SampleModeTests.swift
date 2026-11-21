import Foundation
import Testing
@testable import CarKit

@Suite("Sample data mode")
struct SampleModeTests {
    @Test func sampleModeShowsSampleDataAndKeepsTheRealFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        var tng = TnGState.empty
        tng.balance = 12.5
        try CarStores.tng(in: directory).save(tng)

        #expect(!SampleMode.isOn(in: directory))
        SampleMode.set(true, in: directory)
        #expect(SampleMode.isOn(in: directory))
        let sample = CarData.load(from: directory)
        #expect(!sample.service.items.isEmpty)
        #expect(sample.tng.balance != 12.5)

        SampleMode.set(false, in: directory)
        #expect(!SampleMode.isOn(in: directory))
        #expect(CarData.load(from: directory).tng.balance == 12.5)
    }
}
