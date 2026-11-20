import Foundation
import Testing
@testable import CarKit

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
    return calendar
}()

private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
}

private func plus(days: Int, _ date: Date) -> Date {
    calendar.date(byAdding: .day, value: days, to: date) ?? date
}

// MARK: - Fuel

@Suite("Fuel log")
struct FuelTests {
    @Test func fullToFullIncludesPartialFillsInBetween() {
        let fills = [
            FillUp(date: day(2026, 1, 1), odometerKm: 900, litres: 10, totalRM: 20, isFullTank: false), // before first full: ignored
            FillUp(date: day(2026, 1, 2), odometerKm: 1_000, litres: 40, totalRM: 80),
            FillUp(date: day(2026, 1, 9), odometerKm: 1_300, litres: 15, totalRM: 30, isFullTank: false),
            FillUp(date: day(2026, 1, 15), odometerKm: 1_600, litres: 20, totalRM: 40),
        ]
        let segments = FuelMath.segments(fills)
        #expect(segments.count == 1)
        #expect(segments[0].km == 600)
        #expect(segments[0].litres == 35)
        #expect(abs(segments[0].kmPerLitre - 600.0 / 35.0) < 0.0001)
    }

    @Test func segmentsIgnoreInputOrder() {
        let a = FillUp(date: day(2026, 2, 1), odometerKm: 2_000, litres: 40, totalRM: 80)
        let b = FillUp(date: day(2026, 2, 10), odometerKm: 2_500, litres: 35, totalRM: 70)
        #expect(FuelMath.segments([b, a]) == FuelMath.segments([a, b]))
        #expect(FuelMath.segments([a]).isEmpty)
    }

    @Test func averageUsesLastThreeSegmentsWeightedByDistance() {
        let fills = [
            FillUp(date: day(2026, 3, 1), odometerKm: 0, litres: 40, totalRM: 80),
            FillUp(date: day(2026, 3, 5), odometerKm: 100, litres: 20, totalRM: 40),  // 5 km/L, dropped
            FillUp(date: day(2026, 3, 10), odometerKm: 600, litres: 40, totalRM: 80), // 500 km / 40 L
            FillUp(date: day(2026, 3, 15), odometerKm: 1_100, litres: 30, totalRM: 60), // 500 / 30
            FillUp(date: day(2026, 3, 20), odometerKm: 1_400, litres: 30, totalRM: 60), // 300 / 30
        ]
        let average = FuelMath.averageKmPerLitre(FuelMath.segments(fills))
        #expect(average.map { abs($0 - 1_300.0 / 100.0) < 0.0001 } == true)
        #expect(FuelMath.averageKmPerLitre([]) == nil)
    }

    @Test func lastPriceAndMonthlySpend() {
        let fills = [
            FillUp(date: day(2026, 4, 28), odometerKm: 1_000, litres: 40, totalRM: 82),
            FillUp(date: day(2026, 5, 3), odometerKm: 1_500, litres: 30, totalRM: 61.5),
            FillUp(date: day(2026, 5, 20), odometerKm: 2_000, litres: 20, totalRM: 41),
        ]
        #expect(FuelMath.lastPricePerLitre(fills) == 2.05)
        #expect(FuelMath.spentInMonth(of: day(2026, 5, 25), fills: fills, calendar: calendar) == 102.5)
        #expect(FuelMath.spentInMonth(of: day(2026, 6, 1), fills: fills, calendar: calendar) == 0)
        #expect(FuelMath.lastPricePerLitre([]) == nil)
    }

    @Test func modComparisonSplitsSegments() {
        let fills = [
            FillUp(date: day(2026, 6, 1), odometerKm: 0, litres: 40, totalRM: 80),
            FillUp(date: day(2026, 6, 8), odometerKm: 500, litres: 40, totalRM: 80),   // 12.5 before
            FillUp(date: day(2026, 6, 20), odometerKm: 1_000, litres: 40, totalRM: 80), // spans the mod: neither
            FillUp(date: day(2026, 6, 28), odometerKm: 1_600, litres: 40, totalRM: 80), // 15 after
        ]
        let mod = ModEvent(date: day(2026, 6, 15), name: "Exhaust")
        let result = FuelMath.comparison(around: mod, segments: FuelMath.segments(fills))
        #expect(result.before == 12.5)
        #expect(result.after == 15)
    }
}

// MARK: - Service

@Suite("Service tracker")
struct ServiceTests {
    let start = day(2026, 1, 1)

    @Test func averageDailyKmAndEstimate() {
        let readings = [
            OdometerReading(date: start, km: 10_000),
            OdometerReading(date: plus(days: 100, start), km: 15_000),
        ]
        #expect(MileageEstimator.averageDailyKm(readings) == 50)
        #expect(MileageEstimator.estimatedKm(readings, at: plus(days: 110, start)) == 15_500)
        // Before the newest reading, or with no average, the highest reading is used.
        #expect(MileageEstimator.estimatedKm(readings, at: plus(days: 50, start)) == 15_000)
        #expect(MileageEstimator.estimatedKm([readings[0]], at: plus(days: 30, start)) == 10_000)
        #expect(MileageEstimator.averageDailyKm([readings[0]]) == nil)
        #expect(MileageEstimator.estimatedKm([], at: start) == nil)
    }

    @Test func kmRuleComesFirst() {
        let item = ServiceItem(name: "Oil", intervalKm: 10_000, intervalMonths: 12, lastDoneKm: 10_000, lastDoneDate: start)
        let status = ServiceRules.status(of: item, estimatedKm: 19_500, averageDailyKm: 50, now: plus(days: 100, start), calendar: calendar)
        #expect(status.kmLeft == 500)
        #expect(status.urgency == .dueSoon)
        #expect(status.effectiveDaysLeft == 10) // 500 km at 50 km/day, sooner than the date
    }

    @Test func dateRuleComesFirst() {
        let item = ServiceItem(name: "Oil", intervalKm: 10_000, intervalMonths: 12, lastDoneKm: 10_000, lastDoneDate: start)
        let now = day(2026, 12, 12)
        let status = ServiceRules.status(of: item, estimatedKm: 12_000, averageDailyKm: 10, now: now, calendar: calendar)
        #expect(status.daysLeft == 20)
        #expect(status.urgency == .dueSoon)
        #expect(status.effectiveDaysLeft == 20)
    }

    @Test func overdueByKmOrDateIsUrgent() {
        let item = ServiceItem(name: "Oil", intervalKm: 10_000, intervalMonths: 12, lastDoneKm: 10_000, lastDoneDate: start)
        let byKm = ServiceRules.status(of: item, estimatedKm: 20_300, averageDailyKm: 50, now: plus(days: 30, start), calendar: calendar)
        #expect(byKm.kmLeft == -300)
        #expect(byKm.urgency == .urgent)

        let byDate = ServiceRules.status(of: item, estimatedKm: 11_000, averageDailyKm: 5, now: day(2027, 1, 5), calendar: calendar)
        #expect(byDate.daysLeft == -4)
        #expect(byDate.urgency == .urgent)

        let fine = ServiceRules.status(of: item, estimatedKm: 11_000, averageDailyKm: 5, now: plus(days: 30, start), calendar: calendar)
        #expect(fine.urgency == .ok)
    }

    @Test func statusesSortMostUrgentFirstAndSkipClosedOneOffs() {
        let log = ServiceLog(
            readings: [
                OdometerReading(date: start, km: 10_000),
                OdometerReading(date: plus(days: 100, start), km: 15_000),
            ],
            items: [
                ServiceItem(name: "Air filter", intervalKm: 20_000, lastDoneKm: 10_000),
                ServiceItem(name: "Oil", intervalKm: 10_000, lastDoneKm: 4_000),        // 1,000 km overdue
                ServiceItem(name: "Tyres", intervalKm: 10_000, lastDoneKm: 10_000),     // 5,000 left
                ServiceItem(name: "Rim check", isOneOff: true, dueDate: plus(days: 105, start), completedAt: start),
                ServiceItem(name: "Battery"),                                           // no rule
            ]
        )
        let names = ServiceRules.statuses(log: log, now: plus(days: 100, start), calendar: calendar).map(\.item.name)
        #expect(names == ["Oil", "Tyres", "Air filter", "Battery"])
    }

    @Test func markDone() {
        var recurring = ServiceItem(name: "Oil", intervalKm: 10_000, lastDoneKm: 0, lastDoneDate: start)
        recurring.markDone(km: 10_200, date: plus(days: 200, start))
        #expect(recurring.nextDueKm == 20_200)
        #expect(recurring.isActive)

        var oneOff = ServiceItem(name: "Alignment", isOneOff: true, dueKm: 12_000)
        oneOff.markDone(km: 11_900, date: start)
        #expect(!oneOff.isActive)
    }

    @Test func presetsWithoutKmRuleKeepNoKm() {
        let battery = ServicePreset.all.first { $0.intervalKm == nil }
        let item = battery?.makeItem(lastDoneKm: 15_000, lastDoneDate: start)
        #expect(item?.lastDoneKm == nil)
        #expect(item?.nextDueDate(calendar: calendar) != nil)
    }
}

// MARK: - Renewals

@Suite("Road tax & insurance")
struct RenewalTests {
    @Test func countdownAndColours() {
        let now = day(2026, 11, 20, hour: 23)
        #expect(RenewalRules.daysLeft(until: day(2026, 11, 21, hour: 1), from: now, calendar: calendar) == 1)
        #expect(RenewalRules.daysLeft(until: day(2026, 11, 19), from: now, calendar: calendar) == -1)

        #expect(RenewalRules.urgency(daysLeft: 31) == .ok)
        #expect(RenewalRules.urgency(daysLeft: 30) == .dueSoon)
        #expect(RenewalRules.urgency(daysLeft: 8) == .dueSoon)
        #expect(RenewalRules.urgency(daysLeft: 7) == .urgent)
        #expect(RenewalRules.urgency(daysLeft: 0) == .urgent)
        #expect(RenewalRules.urgency(daysLeft: -3) == .urgent)
    }

    @Test func remindersThirtyAndSevenDaysBeforeAtNine() {
        let now = day(2026, 1, 1)
        let dates = RenewalRules.reminderDates(for: day(2026, 3, 2), now: now, calendar: calendar)
        #expect(dates.map(\.daysBefore) == [30, 7])
        #expect(dates.first?.date == day(2026, 1, 31, hour: 9))
        #expect(dates.last?.date == day(2026, 2, 23, hour: 9))

        let soon = RenewalRules.reminderDates(for: day(2026, 1, 10), now: now, calendar: calendar)
        #expect(soon.map(\.daysBefore) == [7])
    }

    @Test func nearestComesFirstInCard() {
        let now = day(2026, 1, 1)
        let data = CarData(renewals: RenewalLog(items: [
            Renewal(kind: .insurance, expiry: day(2026, 6, 1)),
            Renewal(kind: .roadTax, expiry: day(2026, 1, 20)),
        ]))
        guard case .renewals(let summary) = data.card(for: .renewals, at: now, calendar: calendar) else {
            Issue.record("wrong card")
            return
        }
        #expect(summary.lines.first?.name == "Road tax")
        #expect(summary.lines.first?.daysLeft == 19)
        #expect(summary.lines.first?.urgency == .dueSoon)
    }
}

// MARK: - Touch 'n Go

@Suite("Touch 'n Go")
struct TnGTests {
    @Test func lowBelowThreshold() {
        #expect(TnGState.isLow(balance: 19.99, threshold: 20))
        #expect(!TnGState.isLow(balance: 20, threshold: 20))
        #expect(!TnGState.empty.isLow) // no balance yet
    }

    @Test func quickButtonsAndHistory() {
        var state = TnGState()
        let now = day(2026, 1, 1)
        state.setBalance(50, at: now)
        state.apply(-2.10, at: now)
        state.apply(-1.30, at: now)
        #expect(state.balance == 46.6)
        #expect(state.history.map(\.amount) == [-1.3, -2.1, 50])
        #expect(!state.isLow)
        state.apply(-30, at: now)
        #expect(state.isLow)
    }

    @Test func historyIsCapped() {
        var state = TnGState()
        for _ in 0..<(TnGState.historyLimit + 10) {
            state.apply(1, at: day(2026, 1, 1))
        }
        #expect(state.history.count == TnGState.historyLimit)
    }
}

// MARK: - Slots + storage

@Suite("Data slots and storage")
struct DataSlotTests {
    @Test func phaseOneSlotFileStillDecodes() throws {
        let json = #"{"version":1,"slots":[{"value":"A","title":"a","symbol":"car.fill","style":"dark"}]}"#
        let state = try JSONDecoder().decode(SlotsState.self, from: Data(json.utf8))
        #expect(state.slots.first?.source == nil)
    }

    @Test func dataSlotGetsDailyEntries() {
        var state = SlotsState.starter
        state.setDesign(SlotDesign(value: "", title: "", symbol: "fuelpump.fill", source: .tng), for: 2)
        let data = CarData(tng: TnGState(balance: 12))
        let now = day(2026, 1, 1)
        let items = SlotTimeline.items(slot: 2, state: state, data: data, now: now, calendar: calendar)
        #expect(items.count == 8)
        #expect(items.first?.date == now)
        #expect(items.first?.content == .data(.tng(TnGSummary(balance: 12, threshold: 20, isLow: true))))
    }

    @Test func dataSlotStartsAfterFlash() {
        var state = SlotsState.starter
        state.setDesign(SlotDesign(value: "", title: "", symbol: "car.fill", source: .service), for: 1)
        let now = day(2026, 1, 1)
        state.flashUntil = now.addingTimeInterval(600)
        let items = SlotTimeline.items(slot: 1, state: state, now: now, calendar: calendar)
        #expect(items.first?.content == .flash)
        #expect(items[1].date == now.addingTimeInterval(600))
        if case .data = items[1].content {} else { Issue.record("expected data card after the flash") }
    }

    @Test func storesRoundTripAndFallBack() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        var empty = CarData.empty
        empty.directory = directory
        #expect(CarData.load(from: directory) == empty)

        let sample = SampleData.carData(now: day(2026, 1, 1), calendar: calendar)
        try CarStores.service(in: directory).save(sample.service)
        try CarStores.fuel(in: directory).save(sample.fuel)
        try CarStores.renewals(in: directory).save(sample.renewals)
        try CarStores.tng(in: directory).save(sample.tng)
        let loaded = CarData.load(from: directory)
        #expect(loaded.service == sample.service)
        #expect(loaded.fuel == sample.fuel)
        #expect(loaded.renewals == sample.renewals)
        #expect(loaded.tng == sample.tng)

        try Data("not json".utf8).write(to: CarStores.tng(in: directory).fileURL)
        #expect(CarData.load(from: directory).tng == .empty)
    }

    @Test func fuelChangesAlsoRedrawService() {
        #expect(DataSource.fuel.affectedSources == [.fuel, .service])
        #expect(DataSource.tng.affectedSources == [.tng])
    }
}
