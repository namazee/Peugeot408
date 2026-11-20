import Foundation
import Testing
@testable import CarKit

private let my = PrayerCalendar.malaysia

private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    my.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
}

private func minutes(_ date: Date) -> Int {
    let c = my.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

private func hm(_ text: String) -> Int {
    let parts = text.split(separator: ":").compactMap { Int($0) }
    return parts[0] * 60 + parts[1]
}

/// A trimmed copy of the real e-Solat reply (SGR01), including a Malay month name ("Dis").
private let sampleJSON = """
{"prayerTime":[
 {"hijri":"1448-06-10","date":"20-Nov-2026","day":"Friday","imsak":"05:39:00","fajr":"05:49:00","syuruk":"06:58:00","dhuha":"07:23:00","dhuhr":"13:02:00","asr":"16:24:00","maghrib":"18:59:00","isha":"20:12:00"},
 {"hijri":"1448-06-11","date":"21-Nov-2026","day":"Saturday","imsak":"05:40:00","fajr":"05:50:00","syuruk":"06:58:00","dhuha":"07:23:00","dhuhr":"13:02:00","asr":"16:24:00","maghrib":"18:59:00","isha":"20:13:00"},
 {"hijri":"1448-07-21","date":"31-Dis-2026","day":"Thursday","imsak":"05:56:00","fajr":"06:06:00","syuruk":"07:16:00","dhuha":"07:41:00","dhuhr":"13:19:00","asr":"16:41:00","maghrib":"19:16:00","isha":"20:31:00"}
],"status":"OK!","serverTime":"2026-11-20 11:16:26","periodType":"duration","lang":"ms_my","zone":"SGR01"}
"""

// MARK: - Prayer times

@Suite("Prayer times")
struct PrayerTests {
    @Test func parsesJAKIMReplyWithMalayMonths() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        #expect(days.count == 3)
        #expect(days[0].date == at(2026, 11, 20))
        #expect(minutes(days[0].fajr) == hm("05:49"))
        #expect(minutes(days[0].isha) == hm("20:12"))
        #expect(days[2].date == at(2026, 12, 31))
        #expect(minutes(days[2].maghrib) == hm("19:16"))
        #expect(days.allSatisfy { $0.origin == .jakim })
        #expect(days[0].hijri == "1448-06-10")
    }

    @Test func noRecordReplyThrows() {
        let json = #"{"prayerTime":{"data":["No data available for the current request"]},"status":"NO_RECORD!","zone":"SGR01"}"#
        #expect(throws: JAKIMClient.ClientError.noData("NO_RECORD!")) {
            try JAKIMClient.parse(Data(json.utf8))
        }
    }

    @Test func rangesAreSplitAtYearEnd() {
        let ranges = JAKIMClient.yearRanges(from: at(2026, 12, 20), to: at(2027, 1, 24), calendar: my)
        #expect(ranges.count == 2)
        #expect(ranges[0].end == at(2026, 12, 31))
        #expect(ranges[1].start == at(2027, 1, 1))
        #expect(ranges[1].end == at(2027, 1, 24))
    }

    @Test(arguments: [
        // date, fajr, syuruk, dhuhr, asr, maghrib, isha (JAKIM SGR01, 2026)
        ((2026, 1, 1), ["06:06", "07:17", "13:19", "16:42", "19:17", "20:31"]),
        ((2026, 3, 21), ["06:10", "07:16", "13:23", "16:29", "19:26", "20:34"]),
        ((2026, 6, 21), ["05:52", "07:05", "13:18", "16:44", "19:27", "20:43"]),
        ((2026, 11, 20), ["05:49", "06:58", "13:02", "16:24", "18:59", "20:12"]),
    ])
    func offlineCalculationIsWithinThreeMinutesOfJAKIM(date: (Int, Int, Int), expected: [String]) throws {
        let zone = try #require(PrayerZone.zone(code: "SGR01"))
        let day = try #require(PrayerCalculator.jakim.day(for: at(date.0, date.1, date.2, 12), zone: zone))
        for (prayer, text) in zip(Prayer.allCases, expected) {
            let difference = abs(minutes(day.time(of: prayer)) - hm(text))
            #expect(difference <= 3, "\(prayer) off by \(difference) min on \(date)")
        }
        #expect(day.origin == .calculated)
    }

    @Test func nextPrayerCrossesMidnight() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        // 21:00 on the 20th: Isyak has passed, next is Subuh on the 21st.
        let next = try #require(PrayerSchedule.next(after: at(2026, 11, 20, 21), in: days))
        #expect(next.prayer == .fajr)
        #expect(next.time == at(2026, 11, 21, 5, 50))
        // 01:00 on the 21st: still "in" Isyak of the 20th.
        let current = try #require(PrayerSchedule.current(at: at(2026, 11, 21, 1), in: days))
        #expect(current.prayer == .isha)
        #expect(my.isDate(current.time, inSameDayAs: at(2026, 11, 20)))
    }

    @Test func syurukIsNeverTheNextPrayer() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let next = try #require(PrayerSchedule.next(after: at(2026, 11, 20, 6), in: days))
        #expect(next.prayer == .dhuhr)
    }

    @Test func exactlyAtPrayerTimeMovesToTheFollowingOne() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let next = try #require(PrayerSchedule.next(after: at(2026, 11, 20, 13, 2), in: days))
        #expect(next.prayer == .asr)
    }

    @Test func gapsAreFilledByCalculation() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let zone = try #require(PrayerZone.zone(code: "SGR01"))
        let cache = PrayerService.filled(PrayerCache(zoneCode: "SGR01", days: days), zone: zone, now: at(2026, 11, 20, 9))
        // Yesterday through 35 days ahead, every day present once.
        #expect(cache.days.count >= PrayerService.daysAhead + 2)
        #expect(cache.days.first?.date == at(2026, 11, 19))
        #expect(PrayerSchedule.day(containing: at(2026, 11, 20, 9), in: cache.days)?.origin == .jakim)
        #expect(PrayerSchedule.day(containing: at(2026, 11, 25, 9), in: cache.days)?.origin == .calculated)
        #expect(cache.hasJAKIM(from: at(2026, 11, 20), through: at(2026, 11, 21)))
        #expect(!cache.hasJAKIM(from: at(2026, 11, 20), through: at(2026, 11, 22)))
    }

    @Test func settingsAndCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = PrayerService(directory: directory)
        #expect(service.loadSettings().zoneCode == "SGR01")
        try service.saveSettings(PrayerSettings(zoneCode: "WLY01", autoZone: true))
        #expect(service.loadSettings() == PrayerSettings(zoneCode: "WLY01", autoZone: true))
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        try service.saveCache(PrayerCache(zoneCode: "WLY01", days: days, fetchedAt: at(2026, 11, 20)))
        #expect(service.loadCache().days == days)
    }

    @Test func prayerCardShowsNextAndToday() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let data = CarData(prayer: PrayerCache(zoneCode: "SGR01", days: days))
        guard case .prayer(let summary) = data.card(for: .prayer, at: at(2026, 11, 20, 14)) else {
            Issue.record("expected a prayer card")
            return
        }
        #expect(summary.next?.prayer == .asr)
        #expect(summary.today.count == 6)
        #expect(!summary.isEstimated)
    }

    @Test func prayerTimelineHasAnEntryAtEachPrayer() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let data = CarData(prayer: PrayerCache(zoneCode: "SGR01", days: days))
        let start = at(2026, 11, 20, 12)
        let dates = DataTimeline.dates(for: .prayer, data: data, from: start, calendar: my)
        #expect(dates.first == start)
        #expect(dates.contains(at(2026, 11, 20, 13, 2)))
        #expect(dates.contains(at(2026, 11, 21, 5, 50)))
        #expect(dates.contains(at(2026, 11, 21)))   // midnight: "today" list changes
        #expect(dates == dates.sorted())
    }
}

// MARK: - Zones

@Suite("Prayer zones")
struct ZoneTests {
    @Test func tableHasAllSixtyZones() {
        #expect(PrayerZone.all.count == 60)
        #expect(Set(PrayerZone.all.map(\.code)).count == 60)
        #expect(PrayerZone.byState.count == 14)
    }

    @Test func cyberjayaIsSGR01ViaSepang() {
        let zone = PrayerZone.locate(latitude: 2.92, longitude: 101.65, placeNames: ["Cyberjaya", "Sepang"], state: "Selangor")
        #expect(zone.code == "SGR01")
    }

    @Test func bukitJalilIsWLY01() {
        let zone = PrayerZone.locate(latitude: 3.055, longitude: 101.70, placeNames: ["Bukit Jalil", "Kuala Lumpur"], state: "Kuala Lumpur")
        #expect(zone.code == "WLY01")
    }

    @Test func putrajayaWithoutDistrictIsWLY01() {
        let zone = PrayerZone.locate(latitude: 2.93, longitude: 101.69, placeNames: [], state: "Putrajaya")
        #expect(zone.code == "WLY01")
    }

    @Test func labuanIsWLY02() {
        let zone = PrayerZone.locate(latitude: 5.28, longitude: 115.23, placeNames: [], state: "Labuan")
        #expect(zone.code == "WLY02")
    }

    @Test func klangMatchesSGR03() {
        let zone = PrayerZone.locate(latitude: 3.04, longitude: 101.45, placeNames: ["Klang"], state: "Selangor")
        #expect(zone.code == "SGR03")
    }

    @Test func fallsBackToNearestZoneTown() {
        let zone = PrayerZone.locate(latitude: 1.55, longitude: 110.35, placeNames: ["Somewhere"], state: nil)
        #expect(zone.code == "SWK08")
    }
}

// MARK: - Commute

@Suite("Commute")
struct CommuteTests {
    private let settings = CommuteSettings(
        home: SavedPlace(name: "Home", point: GeoPoint(latitude: 2.92, longitude: 101.65)),
        work: SavedPlace(name: "APU", point: GeoPoint(latitude: 3.055, longitude: 101.70)),
        homeFromHour: 16
    )

    @Test func workInTheMorningHomeFromFour() {
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 7), settings: settings, calendar: my) == .work)
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 15, 59), settings: settings, calendar: my) == .work)
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 16), settings: settings, calendar: my) == .home)
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 23), settings: settings, calendar: my) == .home)
    }

    @Test func onlyOnePlaceSetAlwaysShowsIt() {
        var homeOnly = settings
        homeOnly.work = nil
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 7), settings: homeOnly, calendar: my) == .home)
        #expect(CommuteRules.destination(at: at(2026, 11, 20, 7), settings: .empty, calendar: my) == nil)
    }

    @Test func nextSwitchIsFourPmThenMidnight() {
        #expect(CommuteRules.nextSwitch(after: at(2026, 11, 20, 9), settings: settings, calendar: my) == at(2026, 11, 20, 16))
        #expect(CommuteRules.nextSwitch(after: at(2026, 11, 20, 17), settings: settings, calendar: my) == at(2026, 11, 21))
    }

    @Test func staleOrOtherDestinationETAIsNotShown() {
        let fresh = CommuteCache(destination: .work, travelSeconds: 1_920, computedAt: at(2026, 11, 20, 7, 30), fromCurrentLocation: true)
        let data = CarData(commute: settings, commuteCache: CommuteCacheFile(latest: fresh))
        guard case .commute(let morning) = data.card(for: .commute, at: at(2026, 11, 20, 7, 40), calendar: my) else {
            Issue.record("expected a commute card")
            return
        }
        #expect(morning.travelText == "32 min")
        #expect(morning.arrival == at(2026, 11, 20, 8, 12))
        guard case .commute(let evening) = data.card(for: .commute, at: at(2026, 11, 20, 17), calendar: my) else { return }
        #expect(evening.destination == .home)
        #expect(evening.travelSeconds == nil)
    }

    @Test func nextEventSkipsFinishedOnes() {
        let cache = CalendarCache(events: [
            CachedEvent(title: "Done", start: at(2026, 11, 20, 8), end: at(2026, 11, 20, 9)),
            CachedEvent(title: "Lecture", start: at(2026, 11, 20, 10), end: at(2026, 11, 20, 12)),
            CachedEvent(title: "Later", start: at(2026, 11, 20, 14), end: at(2026, 11, 20, 15)),
        ])
        #expect(cache.nextEvent(at: at(2026, 11, 20, 9, 30))?.title == "Lecture")
        #expect(cache.nextEvent(at: at(2026, 11, 20, 11))?.title == "Lecture") // still running
        #expect(cache.nextEvent(at: at(2026, 11, 20, 16)) == nil)
    }

    @Test func durationFormatting() {
        #expect(CarFormat.duration(32 * 60) == "32 min")
        #expect(CarFormat.duration(65 * 60) == "1 h 05 min")
        #expect(CarFormat.duration(10) == "1 min")
    }
}

// MARK: - Weather & haze

@Suite("Weather and haze")
struct WeatherTests {
    private func snapshot(raining: Bool = false, rainAt hour: Int? = nil, base: Date) -> WeatherSnapshot {
        let hours = (0..<12).map { offset in
            HourForecast(
                date: base.addingTimeInterval(Double(offset) * 3600),
                temperatureC: 30,
                precipitationChance: offset == hour ? 0.7 : 0.1,
                symbol: "cloud",
                isRain: offset == hour
            )
        }
        return WeatherSnapshot(observedAt: base, temperatureC: 31, symbol: "sun.max", condition: "Sunny", isRainingNow: raining, hours: hours)
    }

    @Test func rainingNow() {
        let base = at(2026, 11, 20, 10)
        #expect(WeatherRules.rainText(at: base, in: snapshot(raining: true, base: base), calendar: my) == "Raining now")
    }

    @Test func nextRainyHourToday() {
        let base = at(2026, 11, 20, 10)
        let weather = snapshot(rainAt: 5, base: base) // 15:00
        let rain = WeatherRules.nextRainHour(after: base, in: weather, calendar: my)
        #expect(rain?.date == at(2026, 11, 20, 15))
        #expect(WeatherRules.rainText(at: base, in: weather, calendar: my).hasPrefix("Rain ~"))
    }

    @Test func rainTomorrowDoesNotCountForToday() {
        let base = at(2026, 11, 20, 20)
        let weather = snapshot(rainAt: 6, base: base) // 02:00 tomorrow
        #expect(WeatherRules.rainText(at: base, in: weather, calendar: my) == "No rain today")
    }

    @Test(arguments: [(0, AQIBand.good), (50, .good), (51, .moderate), (100, .moderate), (101, .unhealthy), (200, .unhealthy), (201, .veryUnhealthy), (300, .veryUnhealthy), (301, .hazardous)])
    func malaysianAPIBands(value: Int, band: AQIBand) {
        #expect(AQIBand(value: value) == band)
    }

    @Test func parsesWAQIReply() throws {
        let json = #"{"status":"ok","data":{"aqi":57,"idx":1,"city":{"name":"Putrajaya, Malaysia"},"dominentpol":"pm25","time":{"iso":"2026-11-20T10:00:00+08:00"}}}"#
        let air = try WAQIProvider.parse(Data(json.utf8))
        #expect(air.value == 57)
        #expect(air.band == .moderate)
        #expect(air.station == "Putrajaya, Malaysia")
        #expect(air.observedAt == at(2026, 11, 20, 10))
    }

    @Test func waqiErrorsAndMissingReadings() {
        #expect(throws: AirQualityError.provider("Invalid key")) {
            try WAQIProvider.parse(Data(#"{"status":"error","data":"Invalid key"}"#.utf8))
        }
        #expect(throws: AirQualityError.self) {
            try WAQIProvider.parse(Data(#"{"status":"ok","data":{"aqi":"-","city":{"name":"X"}}}"#.utf8))
        }
    }

    @Test func weatherTimelineFollowsForecastHours() {
        let base = at(2026, 11, 20, 10)
        let data = CarData(weather: WeatherCache(weather: snapshot(base: base), weatherFetchedAt: base))
        let dates = DataTimeline.dates(for: .weather, data: data, from: base, calendar: my)
        #expect(dates.count == 7) // now + 6 hours
        #expect(DataTimeline.reloadDate(for: .weather, data: data, now: base) == base.addingTimeInterval(1_800))
    }

    @Test func unhealthyHazeTintsTheCard() {
        let base = at(2026, 11, 20, 10)
        let air = AirQuality(value: 160, station: "Klang", observedAt: base, dominantPollutant: "pm25", provider: "test")
        let data = CarData(weather: WeatherCache(air: air, airFetchedAt: base))
        #expect(data.card(for: .weather, at: base, calendar: my).urgency == .dueSoon)
    }
}

// MARK: - Parking and map

@Suite("Parking and map")
struct ParkingMapTests {
    private let spot = ParkingSpot(
        point: GeoPoint(latitude: 2.97, longitude: 101.71),
        savedAt: at(2026, 11, 20, 9),
        placeName: "IOI City Mall",
        floor: "B2",
        bay: "C14"
    )

    @Test func detailLineSkipsEmptyParts() {
        #expect(spot.detailLine == "B2 · C14")
        var bare = spot
        bare.placeName = "  "
        bare.floor = ""
        #expect(bare.title == "Parked here")
        #expect(bare.detailLine == "C14")
    }

    @Test func parkingStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try LiveStores.parking(in: directory).save(ParkingState(spot: spot))
        #expect(CarData.load(from: directory).parking.spot == spot)
    }

    @Test func mapPrefersParkedCarThenCommute() {
        let commute = CommuteSettings(
            home: SavedPlace(name: "Home", point: GeoPoint(latitude: 2.92, longitude: 101.65)),
            work: SavedPlace(name: "APU", point: GeoPoint(latitude: 3.055, longitude: 101.70))
        )
        let parked = MapTarget.choose(parking: ParkingState(spot: spot), commute: commute, at: at(2026, 11, 20, 8), calendar: my)
        #expect(parked?.isParking == true)
        let commuting = MapTarget.choose(parking: .empty, commute: commute, at: at(2026, 11, 20, 8), calendar: my)
        #expect(commuting?.label == "To Work: APU")
        #expect(MapTarget.choose(parking: .empty, commute: .empty, at: .now) == nil)
        #expect(parked?.key != commuting?.key)
    }

    @Test func mapIndexPrefersExactSize() {
        let index = MapSnapshotIndex(entries: [
            "170x170": .init(fileName: "map-170x170.png", targetKey: "parking:1", renderedAt: at(2026, 11, 20, 9)),
            "364x170": .init(fileName: "map-364x170.png", targetKey: "parking:1", renderedAt: at(2026, 11, 20, 10)),
            "100x100": .init(fileName: "map-100x100.png", targetKey: "old", renderedAt: at(2026, 11, 20, 11)),
        ])
        #expect(index.entry(for: "parking:1", sizeKey: "170x170")?.fileName == "map-170x170.png")
        #expect(index.entry(for: "parking:1", sizeKey: nil)?.fileName == "map-364x170.png")
        #expect(index.entry(for: "parking:1", sizeKey: "100x100")?.fileName == "map-364x170.png")
        #expect(index.entry(for: "missing", sizeKey: nil) == nil)
    }

    @Test func parkingAndCommuteAlsoRedrawTheMap() {
        #expect(DataSource.parking.affectedSources == [.parking, .map])
        #expect(DataSource.commute.affectedSources == [.commute, .map])
        #expect(DataSource.prayer.affectedSources == [.prayer])
    }

    @Test func slotShowingPrayerUsesPrayerEntryDates() throws {
        let days = try JAKIMClient.parse(Data(sampleJSON.utf8))
        let data = CarData(prayer: PrayerCache(zoneCode: "SGR01", days: days))
        var state = SlotsState.starter
        var design = SlotDesign.starter(for: 2)
        design.source = .prayer
        state.setDesign(design, for: 2)
        let start = at(2026, 11, 20, 12)
        let items = SlotTimeline.items(slot: 2, state: state, data: data, now: start, calendar: my)
        #expect(items.map(\.date) == DataTimeline.dates(for: .prayer, data: data, from: start, calendar: my))
    }

    @Test func everySourceGivesAValidCardWithNoData() {
        for source in DataSource.allCases {
            #expect(CarData.empty.card(for: source, at: at(2026, 11, 20, 9)).source == source)
            #expect(!DataTimeline.dates(for: source, data: .empty, from: at(2026, 11, 20, 9)).isEmpty)
        }
    }
}
