import SwiftUI

struct ContentView: View {
    @StateObject private var vm = OrchestratorViewModel()
    @State private var libraryCollapsed = false

    /// Largura fixa alta legibilidade ao vivo quando colapsado.
    private let libraryCollapsedRibbonWidth: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(LiveTheme.border.opacity(0.35))

            HStack(alignment: .top, spacing: 0) {
                if libraryCollapsed {
                    sidebarExpandRibbon
                        .frame(width: libraryCollapsedRibbonWidth)
                } else {
                    MediaLibraryView(vm: vm, collapsed: $libraryCollapsed)
                        .frame(minWidth: 300, idealWidth: 356, maxWidth: 492)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(LiveTheme.border.opacity(0.28))
                        .frame(width: 2)
                }

                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(vm.channels) { ch in
                            ChannelStripView(vm: vm, channel: ch)
                        }
                    }
                    .padding(16)
                }
                .frame(minWidth: 480)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.22), value: libraryCollapsed)

            Divider()
                .background(LiveTheme.border.opacity(0.35))

            AudioControlView(vm: vm)
                .padding(16)
        }
        .frame(minWidth: 840, minHeight: 640)
        .background(LiveTheme.background)
    }

    private var sidebarExpandRibbon: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                libraryCollapsed = false
            }
        } label: {
            VStack {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Image(systemName: "sidebar.squares.leading")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)

                    Text("MOSTRAR\nBIBLIO.")
                        .font(.caption.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LiveTheme.border)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }
            .frame(width: libraryCollapsedRibbonWidth)
            .frame(maxHeight: .infinity)
            .background(LiveTheme.panel)
            .overlay(
                Rectangle()
                    .strokeBorder(LiveTheme.border.opacity(0.95), lineWidth: 3)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("b", modifiers: .command)
        .help("Mostrar novamente o painel da biblioteca (⌘B)")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Orquestra visual · painel ao vivo")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                Text("Duas saídas · bibliotecas vídeo/imagem · áudio separado · efeitos por canal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiveTheme.textSecondary)
            }
            Spacer()
            Text("ALTO CONTRASTE")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LiveTheme.border)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 2)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(LiveTheme.panel.opacity(0.92))
    }
}
