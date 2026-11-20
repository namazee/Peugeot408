import CarKit
import SwiftUI

/// First-run walkthrough for the one-time CarPlay step.
/// Page 1 plays the icon reveal; pages 2 and 3 play the setup and flash-test clips rendered in /remotion.
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
            if IconRevealView.clipURL != nil {
                // Icon reveal clip from /remotion (spec §3 App icon).
                IconRevealView()
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .accessibilityLabel("Peugeot408 app icon")
            } else {
                SlotTile(slot: 1, content: .design(.starter(for: 1)))
                    .frame(width: 170, height: 170)
            }
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
            ClipOrFallback(resource: "OnboardingSetup") { EmptyView() }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
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
            ClipOrFallback(resource: "OnboardingFlash") {
                SlotTile(slot: 3, content: .flash)
                    .frame(width: 170, height: 170)
            }
            .frame(height: 280)
            Text("Check which is which")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("With the phone connected to the car, flash all slots. Each card shows its slot and position (\"Slot 2 · Top ✓\") for 10 minutes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText)
            FlashControls()
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
    }
}
