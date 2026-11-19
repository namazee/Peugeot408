import CarKit
import SwiftUI

@main
struct Peugeot408App: App {
    @State private var slots = SlotsModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(slots)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
