import Foundation

/// Separador principal da zona de trabalho.
enum WorkspaceMainTab: String, CaseIterable {
    case live = "Live"
    case lab = "Lab"
}

/// Uma “caixinha” no topo: Live geral ou uma live de programa.
struct LiveSlot: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isGeneral: Bool
    /// Mapa para `OrchestratorViewModel.channels[].id` (`nil` só em «Geral»).
    var mappedChannelId: Int?

    /// Máximo de lives de programa (exclui «Geral»).
    static let maxProgramLives = 4

    static let phase1Initial: [LiveSlot] = [
        LiveSlot(
            id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
            title: "Geral",
            isGeneral: true,
            mappedChannelId: nil
        ),
        LiveSlot(
            id: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
            title: "Live 1",
            isGeneral: false,
            mappedChannelId: 0
        ),
        LiveSlot(
            id: UUID(uuidString: "10000000-0000-4000-8000-000000000003")!,
            title: "Live 2",
            isGeneral: false,
            mappedChannelId: 1
        ),
    ]

    static var defaultSelectionId: UUID { phase1Initial[0].id }
}
