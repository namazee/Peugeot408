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

        return CarData(service: service, fuel: fuel, renewals: renewals, tng: tng)
    }

    public static func card(for source: DataSource, now: Date = .now) -> DataCard {
        carData(now: now).card(for: source, at: now)
    }
}
