import Foundation

/// Posição na linha de tempo do vídeo por canal (para barra de progressão).
struct VideoPlaybackInfo: Equatable {
    var currentSeconds: Double
    var durationSeconds: Double

    var fraction: Double {
        guard durationSeconds > 0, durationSeconds.isFinite else { return 0 }
        return min(1, max(0, currentSeconds / durationSeconds))
    }

    static func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
