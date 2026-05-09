import SwiftUI

/// Barra de progressão + tempos para um canal de vídeo.
struct ChannelVideoProgressRow: View {
    @ObservedObject var vm: OrchestratorViewModel
    let channelId: Int

    @State private var dragFraction: Double?

    var body: some View {
        let info = vm.videoPlayback(for: channelId)
        let fraction = dragFraction ?? info?.fraction ?? 0
        let safeFraction = min(1, max(0, fraction))

        VStack(alignment: .leading, spacing: 6) {
            Slider(
                value: Binding(
                    get: { safeFraction },
                    set: { newVal in
                        dragFraction = newVal
                        vm.seekVideo(channelId: channelId, fraction: newVal)
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    vm.setVideoScrubbing(channelId, editing)
                    if !editing {
                        dragFraction = nil
                    }
                }
            )
            .tint(LiveTheme.border)
            .disabled(info?.durationSeconds ?? 0 <= 0)

            HStack {
                Text(clockCurrent(info))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LiveTheme.textSecondary)
                Spacer()
                Text(clockDuration(info))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LiveTheme.textSecondary)
            }
        }
    }

    private func clockCurrent(_ info: VideoPlaybackInfo?) -> String {
        guard let info else { return VideoPlaybackInfo.formatClock(0) }
        if let dragFraction {
            let approx = dragFraction * info.durationSeconds
            return VideoPlaybackInfo.formatClock(approx)
        }
        return VideoPlaybackInfo.formatClock(info.currentSeconds)
    }

    private func clockDuration(_ info: VideoPlaybackInfo?) -> String {
        guard let info, info.durationSeconds > 0 else { return "--:--" }
        return VideoPlaybackInfo.formatClock(info.durationSeconds)
    }
}
