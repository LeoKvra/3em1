import SwiftUI

/// Canvas único por live (MVP): espaço de coordenadas para composição e saída.
enum LiveCanvasMetrics {
    static let referenceWidth: CGFloat = 1920
    static let referenceHeight: CGFloat = 1080

    /// Largura / altura do rectângulo de programa (16:9).
    static var aspectRatio: CGFloat { referenceWidth / referenceHeight }

    static let displayLabel = "1920 × 1080"
}
