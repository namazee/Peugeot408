import Foundation

/// The App Group shared by the app and the widget extension.
/// Its identifier comes from the `AppGroupID` Info.plist key, which `project.yml` fills from `APP_GROUP_ID`.
public enum AppGroup {
    public static var identifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
    }

    private static var sharedContainer: URL? {
        guard let identifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// True when the shared container is reachable (entitlement and provisioning are correct).
    public static var isAvailable: Bool { sharedContainer != nil }

    /// The shared container, or a private temporary folder when the App Group is unavailable
    /// (unit tests, misconfigured signing). The app's Settings → Diagnostics shows which one is in use.
    public static var containerURL: URL {
        sharedContainer
            ?? FileManager.default.temporaryDirectory.appending(path: "Peugeot408-local", directoryHint: .isDirectory)
    }
}
