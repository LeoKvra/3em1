import AppKit
import SwiftUI

struct MediaLibraryView: View {
    @ObservedObject var vm: OrchestratorViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Biblioteca de mídia")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                Spacer()
                Button("Adicionar ficheiros…") {
                    vm.addLibraryFilesViaPanel()
                }
                .buttonStyle(LiveProminentButtonStyle(tint: LiveTheme.accent))
            }

            Text("Selecione um item e use «Associar seleção» na saída desejada.")
                .font(.callout.weight(.medium))
                .foregroundStyle(LiveTheme.textSecondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(vm.library) { item in
                        libraryCell(item)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .background(LiveTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LiveTheme.border.opacity(0.6), lineWidth: 2)
        )
    }

    private func libraryCell(_ item: LibraryItem) -> some View {
        let sel = vm.selection == item.id
        return Button {
            vm.selectLibraryItem(item.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .aspectRatio(4 / 3, contentMode: .fit)

                    thumbnail(for: item)
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
                    kindChip(MediaKind.of(url: item.url))
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

    @ViewBuilder
    private func thumbnail(for item: LibraryItem) -> some View {
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

    private func kindChip(_ kind: MediaKind) -> some View {
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
