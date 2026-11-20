import AVFoundation
import SwiftUI
import UIKit

/// Plays the bundled `IconReveal.mp4` once (silent), then holds on the last frame: the finished icon.
/// The clip is rendered by `npm run icon` in `/remotion` (spec §3 App icon).
struct IconRevealView: UIViewRepresentable {
    static var clipURL: URL? { Bundle.main.url(forResource: "IconReveal", withExtension: "mp4") }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        if let url = Self.clipURL, let playerLayer = view.playerLayer {
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .pause
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.playerLayer?.player?.pause()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }
}
