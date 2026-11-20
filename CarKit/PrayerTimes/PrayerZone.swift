import Foundation

/// A JAKIM prayer-time zone. Coordinates are a representative town in the zone; they are used
/// for the offline fallback calculation and to find the nearest zone from a location.
public struct PrayerZone: Sendable, Equatable, Hashable, Identifiable {
    public let code: String
    /// Areas as JAKIM lists them, e.g. "Gombak, Petaling, Sepang, …".
    public let areas: String
    public let latitude: Double
    public let longitude: Double

    public init(code: String, areas: String, latitude: Double, longitude: Double) {
        self.code = code
        self.areas = areas
        self.latitude = latitude
        self.longitude = longitude
    }

    public var id: String { code }

    /// "SGR", "WLY", …
    public var statePrefix: String { String(code.prefix(3)) }

    public var stateName: String { Self.stateNames[statePrefix] ?? statePrefix }

    public var areaList: [String] {
        areas.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "SGR01 · Gombak, Petaling, Sepang…" shortened for lists and widgets.
    public var shortName: String {
        let first = areaList.prefix(2).joined(separator: ", ")
        return areaList.count > 2 ? "\(first)…" : first
    }

    public static let defaultCode = "SGR01"

    public static func zone(code: String) -> PrayerZone? {
        all.first { $0.code == code.uppercased() }
    }

    /// Zones grouped by state, in JAKIM's state order.
    public static var byState: [(state: String, zones: [PrayerZone])] {
        var order: [String] = []
        var groups: [String: [PrayerZone]] = [:]
        for zone in all {
            if groups[zone.statePrefix] == nil { order.append(zone.statePrefix) }
            groups[zone.statePrefix, default: []].append(zone)
        }
        return order.map { (stateNames[$0] ?? $0, groups[$0] ?? []) }
    }

    static let stateNames: [String: String] = [
        "JHR": "Johor", "KDH": "Kedah", "KTN": "Kelantan", "MLK": "Melaka",
        "NGS": "Negeri Sembilan", "PHG": "Pahang", "PLS": "Perlis", "PNG": "Pulau Pinang",
        "PRK": "Perak", "SBH": "Sabah", "SGR": "Selangor", "SWK": "Sarawak",
        "TRG": "Terengganu", "WLY": "Wilayah Persekutuan",
    ]

    // MARK: Finding the zone for a location

    /// Picks the zone for a place. Tries the reverse-geocoded place names (district, town) against
    /// JAKIM's area lists first, within the state when it is known, then falls back to the nearest
    /// zone town. Example: Cyberjaya → district "Sepang" → SGR01; Bukit Jalil → "Kuala Lumpur" → WLY01.
    public static func locate(latitude: Double, longitude: Double, placeNames: [String] = [], state: String? = nil) -> PrayerZone {
        let prefix = state.flatMap(statePrefix(forStateName:))
        let candidates = prefix.map { p in all.filter { $0.statePrefix == p } } ?? all
        let pool = candidates.isEmpty ? all : candidates

        for name in placeNames.map(normalize) where name.count >= 4 {
            if let match = pool.first(where: { zone in
                zone.areaList.map(normalize).contains { area in
                    area == name || (area.count >= 4 && (name.hasPrefix(area) || area.hasPrefix(name)))
                }
            }) {
                return match
            }
        }
        // Federal territories have no districts: the state name is the answer.
        if prefix == "WLY", let state {
            let name = normalize(state)
            if name.contains("labuan") { return zone(code: "WLY02") ?? pool[0] }
            return zone(code: "WLY01") ?? pool[0]
        }
        return nearest(latitude: latitude, longitude: longitude, in: pool)
    }

    public static func nearest(latitude: Double, longitude: Double, in zones: [PrayerZone] = all) -> PrayerZone {
        let pool = zones.isEmpty ? all : zones
        func distance(_ zone: PrayerZone) -> Double {
            let dLat = zone.latitude - latitude
            let dLng = (zone.longitude - longitude) * cos(latitude * .pi / 180)
            return dLat * dLat + dLng * dLng
        }
        return pool.min { distance($0) < distance($1) } ?? all[0]
    }

    static func statePrefix(forStateName raw: String) -> String? {
        let name = normalize(raw)
        let aliases: [(String, String)] = [
            ("kuala lumpur", "WLY"), ("putrajaya", "WLY"), ("labuan", "WLY"), ("wilayah", "WLY"), ("federal territory", "WLY"),
            ("johor", "JHR"), ("kedah", "KDH"), ("kelantan", "KTN"), ("melaka", "MLK"), ("malacca", "MLK"),
            ("negeri sembilan", "NGS"), ("pahang", "PHG"), ("perlis", "PLS"), ("pinang", "PNG"), ("penang", "PNG"),
            ("perak", "PRK"), ("sabah", "SBH"), ("selangor", "SGR"), ("sarawak", "SWK"), ("terengganu", "TRG"),
        ]
        return aliases.first { name.contains($0.0) }?.1
    }

    static func normalize(_ text: String) -> String {
        var value = text.lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "s.alam", with: "shah alam")
            .replacingOccurrences(of: "sg.", with: "sungai")
        for word in ["daerah kecil", "daerah", "bahagian", "jajahan kecil", "jajahan", "mukim", "bandar", "(", ")"] {
            value = value.replacingOccurrences(of: word, with: " ")
        }
        return value.split(separator: " ").joined(separator: " ")
    }

    /// All 60 JAKIM zones (from e-solat.gov.my, November 2026).
    public static let all: [PrayerZone] = [
        PrayerZone(code: "JHR01", areas: "Pulau Aur dan Pulau Pemanggil", latitude: 2.45, longitude: 104.52),
        PrayerZone(code: "JHR02", areas: "Johor Bahru, Kota Tinggi, Mersing, Kulai", latitude: 1.4927, longitude: 103.7414),
        PrayerZone(code: "JHR03", areas: "Kluang, Pontian", latitude: 2.0251, longitude: 103.3328),
        PrayerZone(code: "JHR04", areas: "Batu Pahat, Muar, Segamat, Gemas Johor, Tangkak", latitude: 1.8548, longitude: 102.9325),
        PrayerZone(code: "KDH01", areas: "Kota Setar, Kubang Pasu, Pokok Sena (Daerah Kecil)", latitude: 6.1248, longitude: 100.3678),
        PrayerZone(code: "KDH02", areas: "Kuala Muda, Yan, Pendang", latitude: 5.647, longitude: 100.4877),
        PrayerZone(code: "KDH03", areas: "Padang Terap, Sik", latitude: 6.2526, longitude: 100.6129),
        PrayerZone(code: "KDH04", areas: "Baling", latitude: 5.6766, longitude: 100.9176),
        PrayerZone(code: "KDH05", areas: "Bandar Baharu, Kulim", latitude: 5.365, longitude: 100.5617),
        PrayerZone(code: "KDH06", areas: "Langkawi", latitude: 6.35, longitude: 99.8),
        PrayerZone(code: "KDH07", areas: "Puncak Gunung Jerai", latitude: 5.79, longitude: 100.43),
        PrayerZone(code: "KTN01", areas: "Bachok, Kota Bharu, Machang, Pasir Mas, Pasir Puteh, Tanah Merah, Tumpat, Kuala Krai, Mukim Chiku", latitude: 6.1254, longitude: 102.2381),
        PrayerZone(code: "KTN02", areas: "Gua Musang (Daerah Galas Dan Bertam), Jeli, Jajahan Kecil Lojing", latitude: 4.8823, longitude: 101.9644),
        PrayerZone(code: "MLK01", areas: "SELURUH NEGERI MELAKA", latitude: 2.1896, longitude: 102.2501),
        PrayerZone(code: "NGS01", areas: "Tampin, Jempol", latitude: 2.4701, longitude: 102.2302),
        PrayerZone(code: "NGS02", areas: "Jelebu, Kuala Pilah, Rembau", latitude: 2.7389, longitude: 102.2487),
        PrayerZone(code: "NGS03", areas: "Port Dickson, Seremban", latitude: 2.7259, longitude: 101.9378),
        PrayerZone(code: "PHG01", areas: "Pulau Tioman", latitude: 2.79, longitude: 104.17),
        PrayerZone(code: "PHG02", areas: "Kuantan, Pekan, Muadzam Shah", latitude: 3.8077, longitude: 103.326),
        PrayerZone(code: "PHG03", areas: "Jerantut, Temerloh, Maran, Bera, Chenor, Jengka", latitude: 3.45, longitude: 102.4176),
        PrayerZone(code: "PHG04", areas: "Bentong, Lipis, Raub", latitude: 3.5226, longitude: 101.9086),
        PrayerZone(code: "PHG05", areas: "Genting Sempah, Janda Baik, Bukit Tinggi", latitude: 3.36, longitude: 101.79),
        PrayerZone(code: "PHG06", areas: "Cameron Highlands, Genting Higlands, Bukit Fraser", latitude: 4.47, longitude: 101.38),
        PrayerZone(code: "PHG07", areas: "Daerah Rompin, (Mukim Rompin, Mukim Endau, Mukim Pontian)", latitude: 2.8, longitude: 103.48),
        PrayerZone(code: "PLS01", areas: "Kangar, Padang Besar, Arau", latitude: 6.4414, longitude: 100.1986),
        PrayerZone(code: "PNG01", areas: "Seluruh Negeri Pulau Pinang", latitude: 5.4141, longitude: 100.3288),
        PrayerZone(code: "PRK01", areas: "Tapah, Slim River, Tanjung Malim", latitude: 4.198, longitude: 101.261),
        PrayerZone(code: "PRK02", areas: "Kuala Kangsar, Sg. Siput , Ipoh, Batu Gajah, Kampar", latitude: 4.5975, longitude: 101.0901),
        PrayerZone(code: "PRK03", areas: "Lenggong, Pengkalan Hulu, Grik", latitude: 5.43, longitude: 101.13),
        PrayerZone(code: "PRK04", areas: "Temengor, Belum", latitude: 5.4, longitude: 101.3),
        PrayerZone(code: "PRK05", areas: "Kg Gajah, Teluk Intan, Bagan Datuk, Seri Iskandar, Beruas, Parit, Lumut, Sitiawan, Pulau Pangkor", latitude: 4.0259, longitude: 101.0213),
        PrayerZone(code: "PRK06", areas: "Selama, Taiping, Bagan Serai, Parit Buntar", latitude: 4.85, longitude: 100.7333),
        PrayerZone(code: "PRK07", areas: "Bukit Larut", latitude: 4.86, longitude: 100.79),
        PrayerZone(code: "SBH01", areas: "Bahagian Sandakan (Timur), Bukit Garam, Semawang, Temanggong, Tambisan, Bandar Sandakan, Sukau", latitude: 5.8402, longitude: 118.1179),
        PrayerZone(code: "SBH02", areas: "Beluran, Telupid, Pinangah, Terusan, Kuamut, Bahagian Sandakan (Barat)", latitude: 5.893, longitude: 117.56),
        PrayerZone(code: "SBH03", areas: "Lahad Datu, Silabukan, Kunak, Sahabat, Semporna, Tungku, Bahagian Tawau  (Timur)", latitude: 5.03, longitude: 118.34),
        PrayerZone(code: "SBH04", areas: "Bandar Tawau, Balong, Merotai, Kalabakan, Bahagian Tawau (Barat)", latitude: 4.2448, longitude: 117.8912),
        PrayerZone(code: "SBH05", areas: "Kudat, Kota Marudu, Pitas, Pulau Banggi, Bahagian Kudat", latitude: 6.8837, longitude: 116.8477),
        PrayerZone(code: "SBH06", areas: "Gunung Kinabalu", latitude: 6.075, longitude: 116.558),
        PrayerZone(code: "SBH07", areas: "Kota Kinabalu, Ranau, Kota Belud, Tuaran, Penampang, Papar, Putatan, Bahagian Pantai Barat", latitude: 5.9804, longitude: 116.0735),
        PrayerZone(code: "SBH08", areas: "Pensiangan, Keningau, Tambunan, Nabawan, Bahagian Pendalaman (Atas)", latitude: 5.3378, longitude: 116.1602),
        PrayerZone(code: "SBH09", areas: "Beaufort, Kuala Penyu, Sipitang, Tenom, Long Pasia, Membakut, Weston, Bahagian Pendalaman (Bawah)", latitude: 5.3473, longitude: 115.7455),
        PrayerZone(code: "SGR01", areas: "Gombak, Petaling, Sepang, Hulu Langat, Hulu Selangor, S.Alam", latitude: 3.0733, longitude: 101.5185),
        PrayerZone(code: "SGR02", areas: "Kuala Selangor, Sabak Bernam", latitude: 3.34, longitude: 101.25),
        PrayerZone(code: "SGR03", areas: "Klang, Kuala Langat", latitude: 3.0449, longitude: 101.4456),
        PrayerZone(code: "SWK01", areas: "Limbang, Lawas, Sundar, Trusan", latitude: 4.75, longitude: 115.0),
        PrayerZone(code: "SWK02", areas: "Miri, Niah, Bekenu, Sibuti, Marudi", latitude: 4.3995, longitude: 113.9914),
        PrayerZone(code: "SWK03", areas: "Pandan, Belaga, Suai, Tatau, Sebauh, Bintulu", latitude: 3.17, longitude: 113.03),
        PrayerZone(code: "SWK04", areas: "Sibu, Mukah, Dalat, Song, Igan, Oya, Balingian, Kanowit, Kapit", latitude: 2.287, longitude: 111.8305),
        PrayerZone(code: "SWK05", areas: "Sarikei, Matu, Julau, Rajang, Daro, Bintangor, Belawai", latitude: 2.1251, longitude: 111.5218),
        PrayerZone(code: "SWK06", areas: "Lubok Antu, Sri Aman, Roban, Debak, Kabong, Lingga, Engkelili, Betong, Spaoh, Pusa, Saratok", latitude: 1.237, longitude: 111.4621),
        PrayerZone(code: "SWK07", areas: "Serian, Simunjan, Samarahan, Sebuyau, Meludam", latitude: 1.1667, longitude: 110.5667),
        PrayerZone(code: "SWK08", areas: "Kuching, Bau, Lundu, Sematan", latitude: 1.5535, longitude: 110.3593),
        PrayerZone(code: "SWK09", areas: "Zon Khas (Kampung Patarikan)", latitude: 4.85, longitude: 115.4),
        PrayerZone(code: "TRG01", areas: "Kuala Terengganu, Marang, Kuala Nerus", latitude: 5.3302, longitude: 103.1408),
        PrayerZone(code: "TRG02", areas: "Besut, Setiu", latitude: 5.736, longitude: 102.49),
        PrayerZone(code: "TRG03", areas: "Hulu Terengganu", latitude: 5.07, longitude: 103.01),
        PrayerZone(code: "TRG04", areas: "Dungun, Kemaman", latitude: 4.7566, longitude: 103.42),
        PrayerZone(code: "WLY01", areas: "Kuala Lumpur, Putrajaya", latitude: 3.139, longitude: 101.6869),
        PrayerZone(code: "WLY02", areas: "Labuan", latitude: 5.2831, longitude: 115.2308),
    ]
}
