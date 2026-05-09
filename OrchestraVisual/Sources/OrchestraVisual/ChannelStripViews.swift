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

            Text("Canvas programa · \(LiveCanvasMetrics.displayLabel) · pré-visualização à escala reduzida")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiveTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Look da live")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                Text("Escolhe como o preview desta saída é mostrado (independente do botão «Alto contraste»).")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LiveTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Look da live", selection: Binding(
                    get: { channel.visualEffectMode },
                    set: { vm.setVisualEffectMode(channelId: channel.id, mode: $0) }
                )) {
                    ForEach(LiveVisualEffectMode.allCases) { mode in
                        Text(mode.segmentLabel)
                            .tag(mode)
                            .help(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Look da live")
                .accessibilityHint("Sem efeito, mundo pixel ou falha aleatória.")
            }

            HStack {
                Spacer(minLength: 0)
                LiveProjectionPreviewFrame(
                    focused: channel.isPlaying && channel.assignedURL != nil
                ) {
                    ChannelPreviewContent(
                        url: channel.assignedURL,
                        player: vm.player(for: channel.id),
                        isPlaying: channel.isPlaying,
                        effectOn: channel.effectOn,
                        visualEffectMode: channel.visualEffectMode,
                        onVideoSingleTap: isAssignedVideo
                            ? {
                                if channel.isPlaying {
                                    vm.pause(channelId: channel.id)
                                } else {
                                    vm.start(channelId: channel.id)
                                }
                            }
                            : nil,
                        onVideoDoubleTap: isAssignedVideo
                            ? { vm.restartFromBeginning(channelId: channel.id) }
                            : nil
                    )
                    .aspectRatio(LiveCanvasMetrics.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: LiveCanvasMetrics.previewPanelMaxWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .masterIlluminator(vm.masterIlluminator)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            if isAssignedVideo {
                ChannelVideoProgressRow(vm: vm, channelId: channel.id)
                    .id("playback-\(channel.id)")
            }

            HStack(spacing: 10) {
                Button("Reproduzir") {
                    vm.start(channelId: channel.id)
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.success))
                .disabled(!hasAssignedMedia || channel.isPlaying)
                .help("Inicia ou retoma (vídeo) a partir do ponto actual; em imagem, mostra a pré-visualização em destaque.")

                Button("Pausa") {
                    vm.pause(channelId: channel.id)
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.danger))
                .disabled(!hasAssignedMedia || !channel.isPlaying)
                .help("Pausa sem voltar ao primeiro frame.")

                Button("Do início") {
                    vm.restartFromBeginning(channelId: channel.id)
                }
                .buttonStyle(LiveSecondaryButtonStyle())
                .disabled(!hasAssignedMedia || !isAssignedVideo)
                .help("Salta para o início do vídeo e fica em pausa até carregar em Reproduzir.")

                Button("Alto contraste") {
                    vm.toggleEffect(channelId: channel.id)
                }
                .buttonStyle(LiveToggleButtonStyle(isOn: channel.effectOn))
                .help("Filtro forte no vídeo/imagem — não confundir com «Look da live» acima.")

                Button("Som original") {
                    vm.toggleVideoAudioMute(channelId: channel.id)
                }
                .buttonStyle(LiveToggleButtonStyle(isOn: !channel.videoAudioMuted))
                .disabled(!canMuteEmbeddedVideoAudio)
                .help("Áudio embutido no ficheiro de vídeo. Cinzento = sem som nesta saída; verde = a ouvir. É independente do leitor «Áudio» em baixo.")

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

    /// Só faz sentido mutar o som embutido quando há vídeo (não imagem estática).
    private var canMuteEmbeddedVideoAudio: Bool {
        guard let u = channel.assignedURL else { return false }
        return MediaKind.of(url: u) == .video
    }

    private var hasAssignedMedia: Bool { channel.assignedURL != nil }

    private var isAssignedVideo: Bool {
        guard let u = channel.assignedURL else { return false }
        return MediaKind.of(url: u) == .video
    }
}

// MARK: - Moldura de projeção (preview à escala reduzida)

/// Bezel em torno do vídeo para ler como «janela de projeção»; o canvas lógico continua Full HD.
private struct LiveProjectionPreviewFrame<Content: View>: View {
    let focused: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            Text("Projeção")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(LiveTheme.border.opacity(0.9))
                .textCase(.uppercase)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.02, blue: 0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(LiveTheme.border.opacity(0.42), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)

                content()
                    .padding(14)
            }
            .liveOutline(focused: focused)
        }
    }
}
