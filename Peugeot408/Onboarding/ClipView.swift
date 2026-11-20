import AVFoundation
import SwiftUI

/// A short, muted, looping clip rendered in /remotion (spec §7: onboarding clips played with AVPlayer).
struct ClipView: UIViewRepresentable {
    let resource: String

    static func url(_ resource: String) -> URL? {
        Bundle.main.url(forResource: resource, withExtension: "mp4")
    }

    func makeUIView(context: Context) -> IconRevealView.PlayerView {
        let view = IconRevealView.PlayerView()
        view.backgroundColor = .clear
        if let url = Self.url(resource), let layer = view.playerLayer {
            let player = AVQueuePlayer()
            player.isMuted = true
            // Don't interrupt music playing on the phone.
            player.preventsDisplaySleepDuringVideoPlayback = false
            context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            layer.player = player
            layer.videoGravity = .resizeAspect
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: IconRevealView.PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: IconRevealView.PlayerView, coordinator: Coordinator) {
        uiView.playerLayer?.player?.pause()
        coordinator.looper = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}

/// The clip if it's bundled, otherwise `fallback`.
struct ClipOrFallback<Fallback: View>: View {
    let resource: String
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        if ClipView.url(resource) != nil {
            ClipView(resource: resource)
                .accessibilityHidden(true)
        } else {
            fallback()
        }
    }
}
