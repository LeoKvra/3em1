import SwiftUI

/// Camada global de «cor/unidade» aplicada a todas as pré-visualizações (controlada na live **Geral**).
enum MasterIlluminatorPreset: String, CaseIterable, Identifiable, Equatable {
    case neutral = "Neutro"
    case greenWash = "Verde"
    case blueWash = "Azul"
    /// Faixas horizontais inspiradas na bandeira (proporções aproximadas).
    case jamaica = "Jamaica"
    /// Faixas horizontais verde / amarelo / azul (simplificado).
    case brazil = "Brasil"

    var id: String { rawValue }

    var detailHint: String {
        switch self {
        case .neutral:
            return "Sem camada de cor sobre as imagens."
        case .greenWash:
            return "Tom verde uniforme (multiply) sobre todas as saídas."
        case .blueWash:
            return "Tom azul uniforme sobre todas as saídas."
        case .jamaica:
            return "Gradiente verde · amarelo · negro (referência Jamaica)."
        case .brazil:
            return "Faixas verde · amarelo · azul (referência Brasil)."
        }
    }
}

/// Camada não interactiva por cima do vídeo/imagem.
struct MasterIlluminatorOverlay: View {
    let preset: MasterIlluminatorPreset

    var body: some View {
        GeometryReader { geo in
            Group {
                switch preset {
                case .neutral:
                    Color.clear
                case .greenWash:
                    Color(red: 0.22, green: 0.92, blue: 0.48).opacity(0.44).blendMode(.multiply)
                case .blueWash:
                    Color(red: 0.35, green: 0.52, blue: 1.0).opacity(0.42).blendMode(.multiply)
                case .jamaica:
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.0, green: 0.55, blue: 0.22), location: 0),
                            .init(color: Color(red: 1.0, green: 0.88, blue: 0.05), location: 0.36),
                            .init(color: Color.black.opacity(0.92), location: 0.68),
                            .init(color: Color(red: 0.02, green: 0.42, blue: 0.16), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.overlay)
                    .opacity(0.52)
                case .brazil:
                    VStack(spacing: 0) {
                        Color(red: 0.0, green: 0.52, blue: 0.28).opacity(0.48).blendMode(.multiply)
                            .frame(height: geo.size.height * 0.52)
                        Color(red: 1.0, green: 0.84, blue: 0.08).opacity(0.44).blendMode(.multiply)
                            .frame(height: geo.size.height * 0.24)
                        Color(red: 0.02, green: 0.2, blue: 0.68).opacity(0.46).blendMode(.multiply)
                            .frame(height: geo.size.height * 0.24)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Aplica o iluminador master quando não está em «Neutro».
    func masterIlluminator(_ preset: MasterIlluminatorPreset) -> some View {
        overlay {
            if preset != .neutral {
                MasterIlluminatorOverlay(preset: preset)
            }
        }
    }
}
