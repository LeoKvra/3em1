import AppKit
import AVFoundation
import SwiftUI

final class PreviewPlayerContainerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

struct AVPlayerPreview: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> PreviewPlayerContainerView {
        let v = PreviewPlayerContainerView()
        v.playerLayer.player = player
        return v
    }

    func updateNSView(_ nsView: PreviewPlayerContainerView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }
}

struct ChannelPreviewContent: View {
    let url: URL?
    let player: AVPlayer?
    let isPlaying: Bool
    let effectOn: Bool

    var body: some View {
        ZStack {
            if let url, MediaKind.of(url: url) != .video {
                if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .saturation(effectOn ? 0 : 1)
                        .contrast(effectOn ? 1.45 : 1)
                        .brightness(effectOn ? 0.08 : 0)
                        .opacity(isPlaying ? 1 : 0.22)
                } else {
                    placeholder("Preview indisponível")
                }
            } else if let url, MediaKind.of(url: url) == .video {
                AVPlayerPreview(player: player)
                    .saturation(effectOn ? 0.2 : 1)
                    .contrast(effectOn ? 1.2 : 1)
                    .brightness(effectOn ? 0.04 : 0)
                    .overlay {
                        if !isPlaying {
                            Text("PAUSA")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(LiveTheme.border)
                                .padding(10)
                                .background(Color.black.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .allowsHitTesting(false)
            } else {
                placeholder("Nenhuma mídia\nAtribuir da biblioteca")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.96))
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(LiveTheme.textSecondary)
            .padding()
    }
}
