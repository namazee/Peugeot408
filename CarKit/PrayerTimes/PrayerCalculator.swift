import Foundation

/// Offline prayer times with JAKIM-style parameters, used when e-Solat is unreachable or a
/// year isn't published yet. Shown in the app as "estimated".
///
/// Parameters were tuned against JAKIM's 2026 tables (SGR01, WLY01, JHR02, PNG01, SBH07, SWK08,
/// KTN01) using each zone's reference town: Subuh at 18° below the horizon, Isyak at 18°, Asar at a
/// shadow length of 1 (Shafi'i), and a minute of ihtiyat (safety margin) on each time. Results are
/// within about 2 minutes of the published times.
public struct PrayerCalculator: Sendable {
    public var fajrAngle: Double
    public var ishaAngle: Double
    public var asrShadowFactor: Double
    /// Minutes added after rounding (negative for syuruk, so sunrise is never late).
    public var adjustments: [Prayer: Int]

    public init(
        fajrAngle: Double = 18,
        ishaAngle: Double = 18,
        asrShadowFactor: Double = 1,
        adjustments: [Prayer: Int] = [.fajr: 1, .syuruk: -1, .dhuhr: 1, .asr: 1, .maghrib: 1, .isha: 1]
    ) {
        self.fajrAngle = fajrAngle
        self.ishaAngle = ishaAngle
        self.asrShadowFactor = asrShadowFactor
        self.adjustments = adjustments
    }

    public static let jakim = PrayerCalculator()

    /// Times for the day containing `date`, or nil where the sun never reaches an angle (not in Malaysia).
    public func day(for date: Date, latitude: Double, longitude: Double, calendar: Calendar = PrayerCalendar.malaysia) -> PrayerDay? {
        let midnight = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: midnight)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        let offsetHours = Double(calendar.timeZone.secondsFromGMT(for: midnight)) / 3600

        // Julian day of local midnight, then the sun's position at local noon.
        let a = (month + 9) / 12
        let jdMidnight = Double(367 * year - (7 * (year + a)) / 4 + (275 * month) / 9 + day) + 1_721_013.5 - offsetHours / 24
        let (declination, equationOfTime) = Self.sun(julianDay: jdMidnight + 0.5)

        let noon = 12 + offsetHours - longitude / 15 - equationOfTime
        let phi = latitude * .pi / 180

        func hourAngle(altitude: Double) -> Double? {
            let cosH = (sin(altitude * .pi / 180) - sin(phi) * sin(declination)) / (cos(phi) * cos(declination))
            guard (-1...1).contains(cosH) else { return nil }
            return acos(cosH) * 180 / .pi / 15
        }
        let asrAltitude = atan(1 / (asrShadowFactor + tan(abs(phi - declination)))) * 180 / .pi

        guard
            let fajrH = hourAngle(altitude: -fajrAngle),
            let sunH = hourAngle(altitude: -0.833),
            let asrH = hourAngle(altitude: asrAltitude),
            let ishaH = hourAngle(altitude: -ishaAngle)
        else { return nil }

        func time(_ prayer: Prayer, hours: Double) -> Date {
            let minutes = hours * 60
            // Round toward the safe side: up for prayers, down for sunrise.
            let rounded = prayer == .syuruk ? floor(minutes) : ceil(minutes)
            let total = Int(rounded) + (adjustments[prayer] ?? 0)
            return midnight.addingTimeInterval(TimeInterval(total * 60))
        }

        return PrayerDay(
            date: midnight,
            fajr: time(.fajr, hours: noon - fajrH),
            syuruk: time(.syuruk, hours: noon - sunH),
            dhuhr: time(.dhuhr, hours: noon),
            asr: time(.asr, hours: noon + asrH),
            maghrib: time(.maghrib, hours: noon + sunH),
            isha: time(.isha, hours: noon + ishaH),
            origin: .calculated
        )
    }

    public func day(for date: Date, zone: PrayerZone, calendar: Calendar = PrayerCalendar.malaysia) -> PrayerDay? {
        day(for: date, latitude: zone.latitude, longitude: zone.longitude, calendar: calendar)
    }

    /// Low-precision solar coordinates (accurate to about a minute of time for these years).
    /// Returns declination in radians and the equation of time in hours.
    static func sun(julianDay: Double) -> (declination: Double, equationOfTime: Double) {
        let d = julianDay - 2_451_545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360) * .pi / 180
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360)
        let lambda = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)).truncatingRemainder(dividingBy: 360) * .pi / 180
        let epsilon = (23.439 - 0.00000036 * d) * .pi / 180
        var rightAscension = atan2(cos(epsilon) * sin(lambda), cos(lambda)) * 180 / .pi / 15
        rightAscension = rightAscension.truncatingRemainder(dividingBy: 24)
        if rightAscension < 0 { rightAscension += 24 }
        var equation = q / 15 - rightAscension
        equation = (equation + 12).truncatingRemainder(dividingBy: 24)
        if equation < 0 { equation += 24 }
        equation -= 12
        return (asin(sin(epsilon) * sin(lambda)), equation)
    }
}
