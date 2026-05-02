import AppKit
import SwiftUI

/// Painel lateral: bibliotecas separadas (vídeo/imagem vs áudio) e recolher para a esquerda.
struct MediaLibraryView: View {
    @ObservedObject var vm: OrchestratorViewModel
    @Binding var collapsed: Bool

    private let visualColumns = [
        GridItem(.adaptive(minimum: 118, maximum: 176), spacing: 10),
    ]

    private let audioColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Biblioteca")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        collapsed = true
                    }
                } label: {
                    Label("Recolher", systemImage: "sidebar.leading")
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(LiveTheme.border)
                        .padding(10)
                        .background(LiveTheme.background.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(LiveTheme.border, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .help("Recolher biblioteca para a esquerda (mais espaço para saídas)")
            }
            .padding(.bottom, 10)

            Text("Inclui amostras no pacote: dois vídeos .mov + três imagens PNG · primeiro arranque sem MOV no pacote regenera só em cache · áudio é separado abaixo.")
                .font(.callout.weight(.medium))
                .foregroundStyle(LiveTheme.textSecondary)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    visualSection
                    Rectangle()
                        .fill(LiveTheme.border.opacity(0.22))
                        .frame(height: 2)

                    audioSection
                }
                .padding(.vertical, 4)
            }

            Divider()
                .background(LiveTheme.border.opacity(0.25))
                .padding(.top, 10)

            shortcutFooter
                .padding(.top, 10)
        }
        .padding(14)
        .background(LiveTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.6), lineWidth: 2)
        )
    }

    private var shortcutFooter: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.title3)
                .foregroundStyle(LiveTheme.accent)

            Text("Ao vivo: alto contraste nos itens selecionados. «Associar seleção» só vale quando o item faz sentido para a ação.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiveTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var visualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vídeo e imagens")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(LiveTheme.border)
                Spacer()
                Button("Adicionar vídeos / imagens…") {
                    vm.addVisualLibraryFilesViaPanel()
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.accent))
            }

            let items = vm.visualLibrary
            if items.isEmpty {
                emptyShelf("Sem ficheiros visuais. Use o botão amarelo.")
            } else {
                LazyVGrid(columns: visualColumns, spacing: 10) {
                    ForEach(items) { item in
                        visualCell(item)
                    }
                }
            }
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Áudio")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(LiveTheme.success)
                Spacer()
                Button("Adicionar sons…") {
                    vm.addAudioLibraryFilesViaPanel()
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.success))
            }

            let items = vm.audioLibrary
            if items.isEmpty {
                emptyShelf("Sem clips de áudio. Use o botão verde.")
            } else {
                LazyVGrid(columns: audioColumns, spacing: 8) {
                    ForEach(items) { item in
                        audioRow(item)
                    }
                }
            }
        }
    }

    private func emptyShelf(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(LiveTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LiveTheme.border.opacity(0.4), lineWidth: 2)
            )
    }

    private func visualCell(_ item: LibraryItem) -> some View {
        let sel = vm.selection == item.id
        return Button {
            vm.selectLibraryItem(item.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .aspectRatio(4 / 3, contentMode: .fit)

                    visualThumbnail(for: item)
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(sel ? LiveTheme.border : LiveTheme.border.opacity(0.25), lineWidth: sel ? 3 : 1)
                )

                Text(item.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LiveTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    visualKindChip(MediaKind.of(url: item.url))
                    Spacer()
                    Button {
                        vm.removeFromLibrary(item)
                    } label: {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(LiveTheme.danger)
                    }
                    .buttonStyle(.plain)
                    .help("Remover da biblioteca")
                }
            }
            .padding(8)
            .background(sel ? LiveTheme.border.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func audioRow(_ item: LibraryItem) -> some View {
        let sel = vm.selection == item.id
        return HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title.weight(.heavy))
                .foregroundStyle(LiveTheme.border)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.bold))
                    .foregroundStyle(LiveTheme.textPrimary)
                    .lineLimit(2)

                Text("Biblioteca · áudio")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(LiveTheme.textSecondary)
            }

            Spacer()

            Button {
                vm.removeFromLibrary(item)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.title3)
                    .foregroundStyle(LiveTheme.danger)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Remover da biblioteca")
        }
        .padding(12)
        .background(sel ? LiveTheme.border.opacity(0.14) : Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(sel ? LiveTheme.border : LiveTheme.border.opacity(0.35), lineWidth: sel ? 3 : 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            vm.selectLibraryItem(item.id)
        }
    }

    @ViewBuilder
    private func visualThumbnail(for item: LibraryItem) -> some View {
        switch MediaKind.of(url: item.url) {
        case .image:
            if let img = NSImage(contentsOf: item.url) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(LiveTheme.textSecondary)
            }
        case .video:
            Image(systemName: "film")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(LiveTheme.accent)
        case .unknown:
            Image(systemName: "questionmark.square")
                .font(.largeTitle)
                .foregroundStyle(LiveTheme.textSecondary)
        }
    }

    private func visualKindChip(_ kind: MediaKind) -> some View {
        let text: String
        switch kind {
        case .image: text = "Imagem"
        case .video: text = "Vídeo"
        case .unknown: text = "?"
        }
        return Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(LiveTheme.border.opacity(0.9))
            .clipShape(Capsule())
    }
}
