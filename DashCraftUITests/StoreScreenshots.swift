import XCTest

/// App Store screenshots (spec §10 Store listing): the app on the simulator with Sample data on.
/// `ci/screenshots.sh` runs this on a 6.9-inch iPhone and passes `TEST_RUNNER_SCREENSHOT_DIR`;
/// Remotion's `StoreScreenshot` then adds the headline frame.
final class StoreScreenshots: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testStoreScreenshots() {
        shoot("1-slots", ["-screenshotTab", "slots", "-screenshotLook", "bold", "-screenshotPanorama", "off"])
        shoot("2-neon", ["-screenshotTab", "slots", "-screenshotLook", "neon", "-screenshotPanorama", "off"])
        shoot("3-panorama", ["-screenshotTab", "slots", "-screenshotLook", "bold", "-screenshotPanorama", "on"])
        shoot("4-templates", ["-screenshotTab", "studio", "-screenshotLook", "bold", "-screenshotPanorama", "off"]) { app in
            self.open("Template gallery", in: app)
        }
        shoot("5-car", ["-screenshotTab", "car", "-screenshotLook", "bold"])
        shoot("6-sounds", ["-screenshotTab", "studio", "-screenshotLook", "bold"]) { app in
            self.open("Connect sounds", in: app)
        }
    }

    @MainActor
    private func open(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: 8) {
            button.tap()
        } else {
            let text = app.staticTexts[label].firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 4), "\(label) not found")
            text.tap()
        }
    }

    @MainActor
    private func shoot(_ name: String, _ arguments: [String], then: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshots", "-hasCompletedOnboarding", "YES"] + arguments
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20) || app.buttons.firstMatch.waitForExistence(timeout: 5))
        then?(app)
        Thread.sleep(forTimeInterval: 3)   // let images, glows and the sample data settle

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let folder = URL(fileURLWithPath: directory, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        }
        app.terminate()
    }
}
