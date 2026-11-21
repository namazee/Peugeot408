import Foundation

/// Settings → Sample data (spec §10). While it is on, `CarData.load` returns `SampleData`, so the
/// app and every widget show a full, made-up history (for App Review and a first look). The real
/// files in the App Group are never touched, and they show again when it is turned off.
public enum SampleMode {
    static let fileName = "sample-mode.json"

    public static func isOn(in directory: URL = AppGroup.containerURL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: fileName).path(percentEncoded: false))
    }

    public static func set(_ on: Bool, in directory: URL = AppGroup.containerURL) {
        let url = directory.appending(path: fileName)
        if on {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data(#"{"on":true}"#.utf8).write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
