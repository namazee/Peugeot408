import CarKit
import SwiftUI

@main
struct Peugeot408App: App {
    @State private var slots = SlotsModel()
    @State private var cars = CarDataModel()
    @State private var studio = StudioModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(slots)
                .environment(cars)
                .environment(studio)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
