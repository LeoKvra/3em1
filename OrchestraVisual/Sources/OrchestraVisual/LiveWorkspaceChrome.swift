import SwiftUI

// MARK: - Barra de pills

struct LiveSlotPickerBar: View {
    @Binding var slots: [LiveSlot]
    @Binding var selectedId: UUID

    private var programCount: Int {
        slots.filter { !$0.isGeneral }.count
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
                    ForEach(slots) { slot in
                        Button {
                            selectedId = slot.id
                        } label: {
                            Text(slot.title)
                        }
                        .buttonStyle(LivePillButtonStyle(isSelected: slot.id == selectedId))
                        .help(slot.isGeneral ? "Overview / master — conteúdo nas fases seguintes" : "Saída de programa \(slot.title)")
                    }

                    Button {
                        addProgramLive()
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

    private func addProgramLive() {
        guard canAddLive else { return }
        let nextNum = programCount + 1
        let slot = LiveSlot(
            id: UUID(),
            title: "Live \(nextNum)",
            isGeneral: false,
            mappedChannelId: nil
        )
        slots.append(slot)
        selectedId = slot.id
    }
}

struct LivePillButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
                Text("Placeholder para overview / master.\nDetalhes nas próximas fases.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(LiveTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
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
            Text("Montagem de timelines e camadas (opacidade, efeitos) para esta live.\nConteúdo a partir da Fase 4.")
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
