import SwiftUI

struct ContentView: View {
    @StateObject private var vm = OrchestratorViewModel()
    @State private var libraryCollapsed = true

    // MARK: - Lives + abas Live / Lab (slots no ViewModel — Fase 2)

    @State private var selectedLiveSlotId: UUID = LiveSlot.defaultSelectionId
    @State private var workspaceTab: WorkspaceMainTab = .live

    /// Largura fixa alta legibilidade ao vivo quando colapsado.
    private let libraryCollapsedRibbonWidth: CGFloat = 52

    private var selectedLiveSlot: LiveSlot? {
        vm.liveSlots.first { $0.id == selectedLiveSlotId }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(LiveTheme.border.opacity(0.35))

            LiveSlotPickerBar(vm: vm, selectedId: $selectedLiveSlotId)

            Divider()
                .background(LiveTheme.border.opacity(0.28))

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

                mainWorkspaceColumn
                    .frame(minWidth: 480)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.22), value: libraryCollapsed)

            Divider()
                .background(LiveTheme.border.opacity(0.35))

            AudioControlView(vm: vm)
                .padding(16)
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(LiveTheme.background)
        .task {
            await vm.bootstrapStarterLibraryIfNeeded()
        }
        .onChange(of: vm.liveSlots.map(\.id)) { _, _ in
            if !vm.liveSlots.contains(where: { $0.id == selectedLiveSlotId }) {
                selectedLiveSlotId = vm.liveSlots.first?.id ?? selectedLiveSlotId
            }
        }
    }

    // MARK: - Zona principal (Live | Lab)

    private var mainWorkspaceColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(selection: $workspaceTab) {
                ForEach(WorkspaceMainTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            ScrollView {
                Group {
                    if let slot = selectedLiveSlot {
                        switch workspaceTab {
                        case .live:
                            liveTabBody(for: slot)
                        case .lab:
                            LabTabPlaceholder(liveTitle: slot.title)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func liveTabBody(for slot: LiveSlot) -> some View {
        if slot.isGeneral {
            GeneralLiveWorkspaceView(vm: vm)
        } else if let cid = slot.mappedChannelId,
                  let channel = vm.channels.first(where: { $0.id == cid }) {
            ChannelStripView(vm: vm, channel: channel)
                .id(channel.id)
        } else {
            UnassignedProgramLivePlaceholder(title: slot.title)
        }
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
                Text("Fase 3 · canvas \(LiveCanvasMetrics.displayLabel) por live · lives dinâmicos · abas Live/Lab · biblioteca à esquerda")
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
