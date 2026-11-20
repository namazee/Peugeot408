import Foundation
import Security

/// Any air-quality source. Swap providers by adding a type here and changing `AirQualityProviders.current`.
public protocol AirQualityProvider: Sendable {
    var name: String { get }
    func fetch(at point: GeoPoint, session: URLSession) async throws -> AirQuality
}

public enum AirQualityError: Error, LocalizedError, Equatable {
    case noToken
    case provider(String)
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .noToken: "No air-quality token. Add AQI_API_KEY in GitHub secrets or in Settings → API keys."
        case .provider(let message): "Air-quality provider: \(message)"
        case .unreadable: "Couldn't read the air-quality response"
        }
    }
}

public enum AirQualityProviders {
    /// The provider in use. WAQI (aqicn.org) covers the Malaysian DOE stations.
    public static func current() -> (any AirQualityProvider)? {
        AirQualityKey.current.map { WAQIProvider(token: $0) }
    }
}

/// World Air Quality Index project (aqicn.org), free token.
/// Note: WAQI reports the US EPA AQI scale; the widget colours it with the Malaysian API bands, as the spec asks.
public struct WAQIProvider: AirQualityProvider {
    public let token: String
    public var name: String { "WAQI (aqicn.org)" }

    public init(token: String) {
        self.token = token
    }

    public func fetch(at point: GeoPoint, session: URLSession = .shared) async throws -> AirQuality {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.waqi.info"
        components.path = "/feed/geo:\(point.latitude);\(point.longitude)/"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw AirQualityError.unreadable }
        let (data, _) = try await session.data(for: URLRequest(url: url, timeoutInterval: 15))
        return try Self.parse(data, provider: name)
    }

    /// `{"status":"ok","data":{"aqi":57,"city":{"name":"…"},"dominentpol":"pm25","time":{"iso":"…"}}}`
    /// `aqi` can be "-" when the station has no reading; errors are `{"status":"error","data":"Invalid key"}`.
    public static func parse(_ data: Data, provider: String = "WAQI (aqicn.org)") throws -> AirQuality {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AirQualityError.unreadable
        }
        guard root["status"] as? String == "ok", let body = root["data"] as? [String: Any] else {
            throw AirQualityError.provider(root["data"] as? String ?? "error")
        }
        let value: Int
        if let number = body["aqi"] as? Int {
            value = number
        } else if let text = body["aqi"] as? String, let number = Int(text) {
            value = number
        } else {
            throw AirQualityError.provider("no reading at the nearest station")
        }
        let city = (body["city"] as? [String: Any])?["name"] as? String ?? "Nearest station"
        let iso = (body["time"] as? [String: Any])?["iso"] as? String
        return AirQuality(
            value: value,
            station: city,
            observedAt: iso.flatMap { ISO8601DateFormatter().date(from: $0) },
            dominantPollutant: body["dominentpol"] as? String,
            provider: provider
        )
    }
}

/// The air-quality token. Built into the app from the `AQI_API_KEY` GitHub secret (via
/// `Config/Secrets.xcconfig` → Info.plist `AQIAPIKey`); a token typed in Settings overrides it.
/// The override lives in the Keychain, shared with the widget through the App Group access group.
public enum AirQualityKey {
    static let infoKey = "AQIAPIKey"
    static let service = "Peugeot408.AirQuality"
    static let account = "token"

    public static var builtIn: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.hasPrefix("$(") ? nil : value
    }

    public static var override: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    public static var current: String? { override ?? builtIn }

    /// Saves (or with nil/empty, removes) the Settings override. Returns false if the Keychain refused.
    @discardableResult
    public static func setOverride(_ token: String?) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)
        let value = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return true }
        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = AppGroup.identifier {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }
}
