import CarKit
import SwiftUI

/// First-run walkthrough for the one-time CarPlay step.
/// Screenshots / animated clips are added in Phase 8 (Remotion onboarding clip).
struct OnboardingView: View {
    @Environment(SlotsModel.self) private var slots
    let onFinish: () -> Void
    @State private var page = 0

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                steps.tag(1)
                test.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                Button("Skip") { onFinish() }
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Button(page < lastPage ? "Next" : "Done") {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            SlotTile(slot: 1, content: .design(.starter(for: 1)))
                .frame(width: 170, height: 170)
            Text("Your car screen, your way")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Add five Car Slot widgets to CarPlay once. From then on, everything you set here shows up on the head unit by itself.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(24)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Add the slots")
                .font(.largeTitle.bold())
            CarPlaySetupSteps()
            Text("Up to 5 widgets fit in one stack.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(24)
    }

    private var test: some View {
        VStack(spacing: 20) {
            Spacer()
            SlotTile(slot: 3, content: .flash)
                .frame(width: 170, height: 170)
            Text("Check which is which")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("With the phone connected to the car, flash all slots. Each one shows its number for 10 minutes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText)
            FlashControls()
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
    }
}
