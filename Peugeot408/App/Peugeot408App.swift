import CarKit
import SwiftUI

@main
struct Peugeot408App: App {
    @State private var slots = SlotsModel()
    @State private var cars = CarDataModel()
    @State private var studio = StudioModel()
    @State private var drive = DriveSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(slots)
                .environment(cars)
                .environment(studio)
                .environment(drive)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
