import SwiftUI

struct ContentView: View {
    @StateObject private var vm = OrchestratorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(LiveTheme.border.opacity(0.35))

            HSplitView {
                MediaLibraryView(vm: vm)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 480)

                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(vm.channels) { ch in
                            ChannelStripView(vm: vm, channel: ch)
                        }
                    }
                    .padding(16)
                }
                .frame(minWidth: 520)
            }

            Divider()
                .background(LiveTheme.border.opacity(0.35))

            AudioControlView(vm: vm)
                .padding(16)
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(LiveTheme.background)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Orquestra visual · painel ao vivo")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(LiveTheme.textPrimary)
                Text("Duas saídas · biblioteca · efeito por canal · áudio")
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
