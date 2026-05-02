import SwiftUI

struct AudioControlView: View {
    @ObservedObject var vm: OrchestratorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Áudio (loop / ambiente)")
                .font(.title2.weight(.heavy))
                .foregroundStyle(LiveTheme.textPrimary)

            HStack(spacing: 14) {
                Button("Escolher ficheiro de áudio…") {
                    vm.pickAudioViaPanel()
                }
                .buttonStyle(LiveSecondaryButtonStyle())

                Button("Tocar") {
                    vm.playAudio()
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.success))
                .disabled(vm.audioURL == nil || vm.audioIsPlaying)

                Button("Parar áudio") {
                    vm.stopAudio()
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.danger))
                .disabled(!vm.audioIsPlaying)

                Spacer()

                statusPill
            }

            if let url = vm.audioURL {
                Text(url.lastPathComponent)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LiveTheme.border)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Nenhum ficheiro de áudio carregado.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(LiveTheme.textSecondary)
            }
        }
        .padding(16)
        .background(LiveTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.55), lineWidth: 2)
        )
    }

    private var statusPill: some View {
        let on = vm.audioIsPlaying
        return Text(on ? "ÁUDIO NO AR" : "ÁUDIO PARADO")
            .font(.caption.weight(.heavy))
            .foregroundStyle(on ? Color.black.opacity(0.9) : LiveTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(on ? LiveTheme.success : LiveTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LiveTheme.border.opacity(0.9), lineWidth: 2)
            )
    }
}
