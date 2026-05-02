import SwiftUI

struct ChannelStripView: View {
    @ObservedObject var vm: OrchestratorViewModel
    let channel: ChannelState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(channel.title.uppercased())
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                Spacer()
                playbackBadge
            }

            ChannelPreviewContent(
                url: channel.assignedURL,
                player: vm.player(for: channel.id),
                isPlaying: channel.isPlaying,
                effectOn: channel.effectOn
            )
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .liveOutline(focused: channel.isPlaying && channel.assignedURL != nil)

            HStack(spacing: 10) {
                Button("Iniciar") {
                    vm.start(channelId: channel.id)
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.success))

                Button("Parar") {
                    vm.stop(channelId: channel.id)
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.danger))

                Button("Efeito") {
                    vm.toggleEffect(channelId: channel.id)
                }
                .buttonStyle(LiveToggleButtonStyle(isOn: channel.effectOn))

                Button("Limpar canal") {
                    vm.clearChannel(channelId: channel.id)
                }
                .buttonStyle(LiveSecondaryButtonStyle())

                Spacer()

                Button("Associar seleção") {
                    vm.assignSelectionToChannel(channel.id)
                }
                .buttonStyle(LiveSecondaryButtonStyle())
                .disabled(!vm.selectionCanAssignToChannel)
                .help("Selecione um vídeo ou imagem na biblioteca antes de associar.")
            }

            Rectangle()
                .fill(LiveTheme.border.opacity(0.25))
                .frame(height: 2)

            HStack {
                Text(fileLabel())
                    .font(.callout.weight(.medium))
                    .foregroundStyle(channel.assignedURL == nil ? LiveTheme.textSecondary : LiveTheme.border)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding(16)
        .background(LiveTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.65), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var playbackBadge: some View {
        let on = channel.isPlaying && channel.assignedURL != nil
        Text(on ? "NO AR" : "PARADO")
            .font(.caption.weight(.heavy))
            .foregroundStyle(on ? Color.black.opacity(0.9) : LiveTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(on ? LiveTheme.border : LiveTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LiveTheme.border.opacity(0.95), lineWidth: 2)
            )
    }

    private func fileLabel() -> String {
        guard let u = channel.assignedURL else { return "Sem ficheiro" }
        return u.lastPathComponent
    }
}
