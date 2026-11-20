import CarKit
import SwiftUI

@main
struct Peugeot408App: App {
    @State private var slots = SlotsModel()
    @State private var cars = CarDataModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(slots)
                .environment(cars)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
