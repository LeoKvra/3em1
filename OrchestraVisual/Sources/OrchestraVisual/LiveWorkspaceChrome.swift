import SwiftUI

// MARK: - Barra de pills

struct LiveSlotPickerBar: View {
    @ObservedObject var vm: OrchestratorViewModel
    @Binding var selectedId: UUID

    private var programCount: Int {
        vm.liveSlots.filter { !$0.isGeneral }.count
    }

    private var canAddLive: Bool {
        programCount < LiveSlot.maxProgramLives
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Lives")
                .font(.caption.weight(.heavy))
                .foregroundStyle(LiveTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.liveSlots) { slot in
                        Button {
                            selectedId = slot.id
                        } label: {
                            HStack(spacing: 8) {
                                LivePillThumbnail(slot: slot, vm: vm)
                                Text(slot.title)
                                    .font(.subheadline.weight(.heavy))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(LivePillButtonStyle(isSelected: slot.id == selectedId))
                        .help(slot.isGeneral ? "Overview / master — conteúdo nas fases seguintes" : "Pré-visualização desta saída · \(slot.title)")
                    }

                    Button {
                        if let id = vm.addProgramLiveSlot() {
                            selectedId = id
                        }
                    } label: {
                        Label("+ Live", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(LiveSecondaryButtonStyle())
                    .disabled(!canAddLive)
                    .help(canAddLive ? "Adiciona Live 3 ou 4 (máx. \(LiveSlot.maxProgramLives) lives de programa)" : "Limite de \(LiveSlot.maxProgramLives) lives de programa atingido")
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LiveTheme.panel.opacity(0.88))
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(LiveTheme.border.opacity(0.35)),
            alignment: .bottom
        )
    }
}

/// Miniatura do que está na saída (ou ícone para «Geral»); cliques ficam no botão da pill.
private struct LivePillThumbnail: View {
    let slot: LiveSlot
    @ObservedObject var vm: OrchestratorViewModel

    private var channel: ChannelState? {
        guard let cid = slot.mappedChannelId else { return nil }
        return vm.channels.first(where: { $0.id == cid })
    }

    private let thumbW: CGFloat = 52
    private let thumbH: CGFloat = 34

    var body: some View {
        Group {
            if slot.isGeneral {
                generalThumb
            } else if let ch = channel {
                ChannelPreviewContent(
                    url: ch.assignedURL,
                    player: vm.player(for: ch.id),
                    isPlaying: ch.isPlaying,
                    effectOn: ch.effectOn,
                    onVideoSingleTap: nil,
                    onVideoDoubleTap: nil
                )
                .frame(width: thumbW, height: thumbH)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ZStack {
                    Color.black.opacity(0.88)
                    Image(systemName: "tv")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LiveTheme.textSecondary.opacity(0.85))
                }
                .frame(width: thumbW, height: thumbH)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private var generalThumb: some View {
        ZStack {
            Color.black.opacity(0.92)
            Image(systemName: "square.grid.3x3.square.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(LiveTheme.border.opacity(0.9))
        }
        .frame(width: thumbW, height: thumbH)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct LivePillButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.black.opacity(0.92) : LiveTheme.textPrimary)
            .background(
                configuration.isPressed
                    ? LiveTheme.border.opacity(isSelected ? 0.85 : 0.15)
                    : (isSelected ? LiveTheme.border : LiveTheme.panel.opacity(0.95))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LiveTheme.border.opacity(isSelected ? 1 : 0.45), lineWidth: isSelected ? 2 : 1)
            )
    }
}

// MARK: - Placeholders Fase 1

struct GeneralLivePlaceholder: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
            VStack(spacing: 14) {
                Text("LIVE GERAL")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(LiveTheme.border)
                Text("Overview / master · mesmo canvas de referência \(LiveCanvasMetrics.displayLabel).")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(LiveTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .aspectRatio(LiveCanvasMetrics.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.55), lineWidth: 2)
        )
    }
}

struct UnassignedProgramLivePlaceholder: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(LiveTheme.border)
            Text("Esta live ainda não tem saída física associada.\nNa Fase 2 o canal projector será ligado aqui.")
                .font(.callout.weight(.medium))
                .foregroundStyle(LiveTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(LiveTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.45), lineWidth: 2)
        )
    }
}

struct LabTabPlaceholder: View {
    let liveTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lab · \(liveTitle)")
                .font(.title2.weight(.heavy))
                .foregroundStyle(LiveTheme.textPrimary)
            Text("Canvas desta live: \(LiveCanvasMetrics.displayLabel). Montagem de timelines em camadas (opacidade, efeitos) — Fase 4+.")
                .font(.callout.weight(.medium))
                .foregroundStyle(LiveTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LiveTheme.background.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.35), lineWidth: 2)
        )
    }
}
