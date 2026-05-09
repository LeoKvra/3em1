import AppKit
import AVFoundation
import SwiftUI

/// Área transparente sobre o vídeo: clique simples (com pequeno atraso) vs duplo clique.
private final class VideoPreviewTapSurfaceView: NSView {
    var onSingle: () -> Void = {}
    var onDouble: () -> Void = {}
    private var pendingSingle: DispatchWorkItem?

    override func mouseDown(with event: NSEvent) {
        let clicks = event.clickCount
        if clicks >= 2 {
            pendingSingle?.cancel()
            pendingSingle = nil
            if clicks == 2 {
                onDouble()
            }
            return
        }
        pendingSingle?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onSingle()
            self?.pendingSingle = nil
        }
        pendingSingle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }
}

private struct VideoPreviewTapOverlay: NSViewRepresentable {
    var onSingleClick: () -> Void
    var onDoubleClick: () -> Void

    func makeNSView(context: Context) -> VideoPreviewTapSurfaceView {
        let v = VideoPreviewTapSurfaceView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }

    func updateNSView(_ nsView: VideoPreviewTapSurfaceView, context: Context) {
        nsView.onSingle = onSingleClick
        nsView.onDouble = onDoubleClick
    }
}

final class PreviewPlayerContainerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.isOpaque = true
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

/// Vídeo: filtros só com «Efeito» ligado. Imagem JPEG/PNG não tem frames — só mostra foto; não “reproduz” como vídeo no sentido cinematográfico.
struct ChannelPreviewContent: View {
    let url: URL?
    let player: AVPlayer?
    let isPlaying: Bool
    let effectOn: Bool
    var visualEffectMode: LiveVisualEffectMode
    /// Só vídeo: clique alterna pausa/reprodução; duplo clique volta ao início.
    var onVideoSingleTap: (() -> Void)?
    var onVideoDoubleTap: (() -> Void)?

    init(
        url: URL?,
        player: AVPlayer?,
        isPlaying: Bool,
        effectOn: Bool,
        visualEffectMode: LiveVisualEffectMode = .none,
        onVideoSingleTap: (() -> Void)? = nil,
        onVideoDoubleTap: (() -> Void)? = nil
    ) {
        self.url = url
        self.player = player
        self.isPlaying = isPlaying
        self.effectOn = effectOn
        self.visualEffectMode = visualEffectMode
        self.onVideoSingleTap = onVideoSingleTap
        self.onVideoDoubleTap = onVideoDoubleTap
    }

    var body: some View {
        ZStack {
            if let url, MediaKind.of(url: url) != .video {
                photoBranch(url: url)
            } else if let url, MediaKind.of(url: url) == .video {
                videoBranch()
            } else {
                ZStack {
                    placeholder("Nenhuma mídia\nAtribuir da biblioteca")
                    if visualEffectMode == .randomGlitch {
                        AnalogGlitchOverlay()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.96))
    }

    @ViewBuilder
    private func photoBranch(url: URL) -> some View {
        Group {
            if let nsImage = NSImage(contentsOf: url) {
                Group {
                    if effectOn {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .saturation(0)
                            .contrast(1.45)
                            .brightness(0.08)
                    } else {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .modifier(MonochromeLookModifier(enabled: visualEffectMode == .monochrome))
            } else {
                placeholder("Não consegui ler a imagem\n(tenta exportar doutro formato)")
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                Text("IMAGEM ESTÁTICA")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(LiveTheme.border)
                Text("Não há filme para dar play aqui · escolha um `.mov`/`.mp4` na biblioteca para vídeo.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LiveTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.72))
        }
        .overlay(alignment: .topTrailing) {
            Text(isPlaying ? "MARCA · NO AR" : "MARCA · PARADO")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(isPlaying ? Color.black.opacity(0.88) : LiveTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isPlaying ? LiveTheme.border : LiveTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(LiveTheme.border.opacity(0.6), lineWidth: 1)
                )
                .padding(10)
        }
        .overlay {
            if visualEffectMode == .randomGlitch {
                AnalogGlitchOverlay()
            }
        }
    }

    @ViewBuilder
    private func videoBranch() -> some View {
        ZStack {
            Group {
                if effectOn {
                    AVPlayerPreview(player: player)
                        .saturation(0.2)
                        .contrast(1.2)
                        .brightness(0.04)
                } else {
                    AVPlayerPreview(player: player)
                }
            }
            .modifier(MonochromeLookModifier(enabled: visualEffectMode == .monochrome))
            .allowsHitTesting(false)

            if !isPlaying {
                Text("PAUSA / PARADO")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(LiveTheme.border)
                    .padding(10)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }

            if let single = onVideoSingleTap, let double = onVideoDoubleTap {
                VideoPreviewTapOverlay(onSingleClick: single, onDoubleClick: double)
                    .help("Clique: pausa ou continua · duplo clique: volta ao início e fica em pausa")
            }

            if visualEffectMode == .randomGlitch {
                AnalogGlitchOverlay()
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(LiveTheme.textSecondary)
            .padding()
    }
}
