import CarKit
import SwiftUI

@main
struct Peugeot408App: App {
    @State private var slots = SlotsModel()
    @State private var cars = CarDataModel()
    @State private var studio = StudioModel()
    @State private var drive = DriveSession()
    @State private var appearance = AppearanceModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(slots)
                .environment(cars)
                .environment(studio)
                .environment(drive)
                .environment(appearance)
                .environment(\.cardLook, appearance.look)
                .tint(appearance.look.appTint)
                .preferredColorScheme(.dark)
        }
    }
}
