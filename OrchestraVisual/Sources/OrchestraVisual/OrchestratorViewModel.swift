import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct LibraryItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
}

enum MediaKind {
    case image
    case video
    case unknown

    static func of(url: URL) -> MediaKind {
        let ext = url.pathExtension.lowercased()
        let image = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "bmp", "webp"]
        let video = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
        if image.contains(ext) { return .image }
        if video.contains(ext) { return .video }
        return .unknown
    }
}

struct ChannelState: Identifiable, Equatable {
    let id: Int
    /// Rótulo exibido (Saída 1 / projetor vertical, etc.)
    var title: String
    var assignedURL: URL?
    var isPlaying: Bool
    /// Efeito em tempo real no preview (alto contraste / mono simplificado visual)
    var effectOn: Bool
}

@MainActor
final class OrchestratorViewModel: ObservableObject {

    private static let defaultChannels = [
        ChannelState(id: 0, title: "Saída 1 · Fundo widescreen", assignedURL: nil, isPlaying: false, effectOn: false),
        ChannelState(id: 1, title: "Saída 2 · Pano / músico", assignedURL: nil, isPlaying: false, effectOn: false),
    ]

    @Published private(set) var channels: [ChannelState] = defaultChannels
    @Published private(set) var library: [LibraryItem] = []
    @Published var selection: UUID?
    @Published private(set) var audioURL: URL?
    @Published private(set) var audioIsPlaying = false

    private var players: [Int: AVPlayer] = [:]
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Biblioteca

    func addLibraryFilesViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie, .video, .mpeg4Movie, .quickTimeMovie, .png, .jpeg, .gif]
        guard panel.runModal() == .OK else { return }
        addToLibrary(panel.urls)
    }

    func removeFromLibrary(_ item: LibraryItem) {
        library.removeAll { $0.id == item.id }
        if selection == item.id { selection = nil }
        let touching = channels.filter { $0.assignedURL == item.url }.map(\.id)
        for id in touching {
            clearChannel(channelId: id)
        }
    }

    func addToLibrary(_ urls: [URL]) {
        urls.forEach { _ = $0.startAccessingSecurityScopedResource() }
        let newItems = urls.map { LibraryItem(url: $0) }
        library.append(contentsOf: newItems)
        if selection == nil { selection = newItems.first?.id }
    }

    func selectLibraryItem(_ id: UUID?) {
        selection = id
    }

    func assignSelectionToChannel(_ channelId: Int) {
        guard let sel = selection, let item = library.first(where: { $0.id == sel }) else { return }
        assignMedia(item.url, to: channelId)
    }

    // MARK: - Canais

    func assignMedia(_ url: URL, to channelId: Int) {
        _ = url.startAccessingSecurityScopedResource()
        teardownPlayer(for: channelId)
        switch MediaKind.of(url: url) {
        case .video:
            players[channelId] = AVPlayer(url: url)
            updateChannel(channelId) { ch in
                ch.assignedURL = url
                ch.isPlaying = false
            }
        case .image, .unknown:
            updateChannel(channelId) { ch in
                ch.assignedURL = url
                ch.isPlaying = true
            }
        }
    }

    func start(channelId: Int) {
        guard let url = channels.first(where: { $0.id == channelId })?.assignedURL else { return }
        switch MediaKind.of(url: url) {
        case .video:
            let player = players[channelId] ?? AVPlayer(url: url)
            players[channelId] = player
            player.play()
            updateChannel(channelId) { $0.isPlaying = true }
        case .image, .unknown:
            updateChannel(channelId) { $0.isPlaying = true }
        }
    }

    func stop(channelId: Int) {
        if let url = channels.first(where: { $0.id == channelId })?.assignedURL,
           MediaKind.of(url: url) == .video {
            players[channelId]?.pause()
            players[channelId]?.seek(to: .zero)
        }
        updateChannel(channelId) { $0.isPlaying = false }
    }

    func toggleEffect(channelId: Int) {
        updateChannel(channelId) { $0.effectOn.toggle() }
    }

    func clearChannel(channelId: Int) {
        stop(channelId: channelId)
        teardownPlayer(for: channelId)
        updateChannel(channelId) { ch in
            ch.assignedURL = nil
            ch.effectOn = false
        }
    }

    private func updateChannel(_ channelId: Int, _ mutate: (inout ChannelState) -> Void) {
        guard let idx = channels.firstIndex(where: { $0.id == channelId }) else { return }
        var ch = channels[idx]
        mutate(&ch)
        channels[idx] = ch
    }

    private func teardownPlayer(for channelId: Int) {
        guard let player = players[channelId] else { return }
        player.pause()
        players.removeValue(forKey: channelId)
    }

    func player(for channelId: Int) -> AVPlayer? {
        players[channelId]
    }

    // MARK: - Áudio

    func pickAudioViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = url.startAccessingSecurityScopedResource()
        stopAudio()
        audioURL = url
    }

    func playAudio() {
        guard let url = audioURL else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.prepareToPlay()
            p.play()
            audioPlayer = p
            audioIsPlaying = true
        } catch {
            audioPlayer = nil
            audioIsPlaying = false
        }
    }

    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioIsPlaying = false
    }
}
