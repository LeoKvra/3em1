import SwiftUI

/// Efeito visual global da live (separado do botão «Alto contraste» na faixa do canal).
enum LiveVisualEffectMode: String, CaseIterable, Identifiable, Equatable {
    case none = "Sem efeito"
    case pixelWorld = "Mundo pixel"
    case randomGlitch = "Falha aleatória"

    var id: String { rawValue }

    /// Rótulo curto para o controlo segmentado (nome completo em `rawValue`).
    var segmentLabel: String {
        switch self {
        case .none: return "Normal"
        case .pixelWorld: return "Pixel"
        case .randomGlitch: return "Falha"
        }
    }
}

// MARK: - Mundo pixel (subamostragem encaixada)

struct PixelWorldModifier: ViewModifier {
    let enabled: Bool
    /// Tamanho do «bloco» em pixels lógicos (maior = mais blocos).
    var blockSize: CGFloat = 8

    func body(content: Content) -> some View {
        Group {
            if enabled {
                GeometryReader { geo in
                    let w = max(geo.size.width, 1)
                    let h = max(geo.size.height, 1)
                    let s = blockSize
                    content
                        .frame(width: w, height: h)
                        .scaleEffect(1 / s, anchor: .center)
                        .frame(width: w / s, height: h / s)
                        .scaleEffect(s, anchor: .center)
                        .frame(width: w, height: h)
                        .clipped()
                }
            } else {
                content
            }
        }
    }
}

// MARK: - Falha tipo LED / vídeo analógico

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func unit01() -> CGFloat {
        CGFloat(next() % 10_000) / 10_000
    }
}

/// Linhas verticais e artefactos que mudam ao longo do tempo (TimelineView).
struct AnalogGlitchOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            GlitchFrame(seed: context.date.timeIntervalSinceReferenceDate)
        }
        .allowsHitTesting(false)
    }
}

private struct GlitchFrame: View {
    var seed: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed * 1_000_000)))
            let w = max(size.width, 1)
            let h = max(size.height, 1)

            for _ in 0..<24 {
                let x = rng.unit01() * w
                let bw = 1 + CGFloat(rng.next() % 5)
                let band = CGRect(x: x, y: 0, width: bw, height: h)
                ctx.fill(
                    Path(band),
                    with: .color(glitchColor(i: rng.next()).opacity(0.06 + Double(rng.next() % 15) / 100))
                )
            }

            for _ in 0..<10 {
                let y = rng.unit01() * h
                let bh = 2 + CGFloat(rng.next() % 12)
                let shift = CGFloat(Int64(rng.next() % 40)) - 20
                let tear = CGRect(x: shift, y: y, width: w + abs(shift) * 2, height: bh)
                ctx.fill(
                    Path(tear),
                    with: .color(Color.white.opacity(0.04 + rng.unit01() * 0.08))
                )
            }

            for i in 0..<6 {
                let x = CGFloat(i + 1) / 7 * w * 0.98 + rng.unit01() * 12
                ctx.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + CGFloat(rng.next() % 3) - 1, y: h))
                    },
                    with: .color(Color(red: 0.4, green: 1, blue: 1).opacity(0.12)),
                    lineWidth: 1
                )
            }
        }
        .blendMode(.screen)
        .opacity(0.92)
    }

    private func glitchColor(i: UInt64) -> Color {
        switch i % 5 {
        case 0: return .white
        case 1: return Color(red: 1, green: 0.35, blue: 0.95)
        case 2: return Color(red: 0.3, green: 1, blue: 1)
        case 3: return Color(red: 1, green: 0.95, blue: 0.2)
        default: return Color(red: 1, green: 0.5, blue: 0.2)
        }
    }
}
