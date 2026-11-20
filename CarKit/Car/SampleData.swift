import Foundation

/// Realistic sample data for `#Preview`s, widget placeholders and the gallery snapshot.
public enum SampleData {
    public static func carData(now: Date = .now, calendar: Calendar = .current) -> CarData {
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }
        func daysAhead(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: now) ?? now
        }

        let service = ServiceLog(
            readings: [
                OdometerReading(date: daysAgo(120), km: 14_200),
                OdometerReading(date: daysAgo(2), km: 19_050),
            ],
            items: [
                ServiceItem(
                    name: "Oil service",
                    symbol: "oilcan.fill",
                    intervalKm: 10_000,
                    intervalMonths: 12,
                    lastDoneKm: 10_350,
                    lastDoneDate: daysAgo(342)
                ),
                ServiceItem(
                    name: "Tyre rotation",
                    symbol: "arrow.triangle.2.circlepath",
                    intervalKm: 10_000,
                    intervalMonths: 12,
                    lastDoneKm: 12_000,
                    lastDoneDate: daysAgo(200)
                ),
                ServiceItem(
                    name: "Alignment after rim swap",
                    symbol: "steeringwheel",
                    isOneOff: true,
                    dueDate: daysAhead(40)
                ),
            ]
        )

        let fuel = FuelLog(fillUps: [
            FillUp(date: daysAgo(30), odometerKm: 17_900, litres: 42, totalRM: 86.10),
            FillUp(date: daysAgo(20), odometerKm: 18_420, litres: 36.5, totalRM: 74.83),
            FillUp(date: daysAgo(11), odometerKm: 18_950, litres: 37.2, totalRM: 76.26),
            FillUp(date: daysAgo(2), odometerKm: 19_480, litres: 36.8, totalRM: 75.44),
        ])

        let renewals = RenewalLog(items: [
            Renewal(kind: .roadTax, expiry: daysAhead(23)),
            Renewal(kind: .insurance, expiry: daysAhead(23)),
            Renewal(kind: .licence, expiry: daysAhead(410)),
        ])

        let tng = TnGState(balance: 42.50, threshold: 20, updatedAt: daysAgo(1))

        let parking = ParkingState(spot: ParkingSpot(
            point: GeoPoint(latitude: 2.9701, longitude: 101.7115),
            savedAt: now.addingTimeInterval(-(2 * 3600 + 14 * 60)),
            placeName: "IOI City Mall",
            floor: "B2",
            bay: "C14"
        ))

        let zone = PrayerZone.zone(code: PrayerZone.defaultCode) ?? PrayerZone.all[0]
        let prayerDays = (-1...2).compactMap { offset -> PrayerDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            var result = PrayerCalculator.jakim.day(for: day, zone: zone)
            result?.origin = .jakim
            return result
        }

        let commute = CommuteSettings(
            home: SavedPlace(name: "Home", point: GeoPoint(latitude: 2.9213, longitude: 101.6559)),
            work: SavedPlace(name: "APU", point: GeoPoint(latitude: 3.0553, longitude: 101.7005))
        )
        let destination = CommuteRules.destination(at: now, settings: commute, calendar: calendar) ?? .work
        let commuteCache = CommuteCacheFile(latest: CommuteCache(destination: destination, travelSeconds: 32 * 60, computedAt: now, fromCurrentLocation: true))
        let calendarCache = CalendarCache(events: [
            CachedEvent(title: "Team stand-up", start: now.addingTimeInterval(80 * 60), end: now.addingTimeInterval(110 * 60), location: "Block B"),
        ], updatedAt: now)

        var hours: [HourForecast] = []
        for hour in 0..<12 {
            let offset = Double(hour)
            let rainy = hour == 3
            let temperature: Double = 31.0 - offset * 0.4
            hours.append(HourForecast(
                date: now.addingTimeInterval(offset * 3600),
                temperatureC: temperature,
                precipitationChance: rainy ? 0.6 : 0.1,
                symbol: rainy ? "cloud.rain.fill" : "cloud.sun.fill",
                isRain: rainy
            ))
        }
        let weather = WeatherCache(
            weather: WeatherSnapshot(observedAt: now, temperatureC: 31, symbol: "cloud.sun.fill", condition: "Partly Cloudy", isRainingNow: false, hours: hours),
            air: AirQuality(value: 57, station: "Putrajaya", observedAt: now, dominantPollutant: "pm25", provider: "Sample"),
            weatherFetchedAt: now,
            airFetchedAt: now,
            placeLabel: "Current location"
        )

        return CarData(
            service: service, fuel: fuel, renewals: renewals, tng: tng,
            parking: parking,
            prayer: PrayerCache(zoneCode: zone.code, days: prayerDays, fetchedAt: now),
            commute: commute,
            commuteCache: commuteCache,
            calendar: calendarCache,
            weather: weather,
            music: MusicCache(item: MusicItemCard(title: "Drive Mix", subtitle: "Apple Music", kindLabel: "Playlist", artworkFile: nil, updatedAt: now))
        )
    }

    public static func card(for source: DataSource, now: Date = .now) -> DataCard {
        carData(now: now).card(for: source, at: now)
    }
}
