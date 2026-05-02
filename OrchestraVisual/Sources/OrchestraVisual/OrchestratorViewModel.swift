import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum LibraryShelf: Equatable {
    /// Vídeos e imagens — destino: saídas visuais.
    case visual
    /// Sons — biblioteca própria; destino leitor / loop.
    case audio

    static func classify(url: URL) -> LibraryShelf {
        let ext = url.pathExtension.lowercased()
        let audio = ["mp3", "wav", "aac", "m4a", "aiff", "aif", "flac", "ogg"]
        return audio.contains(ext) ? .audio : .visual
    }
}

struct LibraryItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let shelf: LibraryShelf
    var name: String { url.lastPathComponent }

    init(url: URL, id: UUID = UUID()) {
        self.id = id
        self.url = url
        self.shelf = LibraryShelf.classify(url: url)
    }
}

enum MediaKind {
    case image
    case video
    case unknown

    static func of(url: URL) -> MediaKind {
        let ext = url.pathExtension.lowercased()
        let image = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "bmp", "webp"]
        let video = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
        if LibraryShelf.classify(url: url) == .audio { return .unknown }
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
    /// Observadores `AVPlayerItemDidPlayToEndTime` por canal para loop local (demos ao vivo).
    private var videoEndObservers: [Int: NSObjectProtocol] = [:]

    // MARK: - Arranque (amostras + previews)

    /// Carrega imagens incluídas no pacote, gera dois `.mov` de teste e preenche a biblioteca quando vazia.
    /// Atribui vídeo distinto por saída e inicia reprodução nos dois previews (decodificadores em paralelo).
    func bootstrapStarterLibraryIfNeeded() async {
        guard library.isEmpty else { return }

        let urls: [URL]
        do {
            urls = try await Task.detached(priority: .userInitiated) {
                try SampleMediaProvisioner.bootstrapVisualURLs()
            }.value
        } catch {
            return
        }

        urls.forEach { _ = $0.startAccessingSecurityScopedResource() }

        let items = urls.map { LibraryItem(url: $0) }
        library = items

        wireStarterAssignments(from: items)
        selection = items.first?.id
    }

    /// Define mídia inicial nas duas saídas: dois vídeos diferentes se existirem; caso só existam imagens, duplica só imagem.
    private func wireStarterAssignments(from items: [LibraryItem]) {
        let videos = items.filter { MediaKind.of(url: $0.url) == .video }
        if !videos.isEmpty {
            let jam = videos.first { $0.url.lastPathComponent.localizedStandardContains("jamaica") }

            let urlA: URL
            let urlB: URL
            if let jam, let other = videos.first(where: { $0.url != jam.url }) {
                urlA = jam.url
                urlB = other.url
            } else if let jam {
                urlA = jam.url
                urlB = jam.url
            } else {
                urlA = videos[0].url
                urlB = (videos.count > 1 ? videos[1] : videos[0]).url
            }

            assignMedia(urlA, to: 0)
            assignMedia(urlB, to: 1)
            start(channelId: 0)
            start(channelId: 1)
            return
        }

        let imgs = items.filter { MediaKind.of(url: $0.url) == .image }
        guard let a = imgs.first else { return }
        let secondURL = imgs[safe: 1]?.url ?? a.url
        assignMedia(a.url, to: 0)
        assignMedia(secondURL, to: 1)
        start(channelId: 0)
        start(channelId: 1)
    }

    // MARK: - Biblioteca

    var visualLibrary: [LibraryItem] { library.filter { $0.shelf == .visual } }
    var audioLibrary: [LibraryItem] { library.filter { $0.shelf == .audio } }

    /// Selecção pode associar-se a uma saída de vídeo.
    var selectionCanAssignToChannel: Bool {
        guard let sid = selection, let item = library.first(where: { $0.id == sid }) else { return false }
        return item.shelf == .visual
    }

    /// Selecção é áudio e pode ir para o leitor.
    var selectionCanAssignToAudioDeck: Bool {
        guard let sid = selection, let item = library.first(where: { $0.id == sid }) else { return false }
        return item.shelf == .audio
    }

    func addVisualLibraryFilesViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie, .video, .mpeg4Movie, .quickTimeMovie, .png, .jpeg, .gif]
        guard panel.runModal() == .OK else { return }
        addURLsToLibrary(panel.urls, expectedShelf: .visual)
    }

    func addAudioLibraryFilesViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        guard panel.runModal() == .OK else { return }
        addURLsToLibrary(panel.urls, expectedShelf: .audio)
    }

    func removeFromLibrary(_ item: LibraryItem) {
        library.removeAll { $0.id == item.id }
        if selection == item.id { selection = nil }
        if item.shelf == .audio, audioURL == item.url {
            stopAudio()
            audioURL = nil
        }
        let touching = channels.filter { $0.assignedURL == item.url }.map(\.id)
        for id in touching {
            clearChannel(channelId: id)
        }
    }

    private func addURLsToLibrary(_ urls: [URL], expectedShelf: LibraryShelf) {
        urls.forEach { _ = $0.startAccessingSecurityScopedResource() }
        let classified = urls.map { LibraryItem(url: $0) }
        let filtered = classified.filter { $0.shelf == expectedShelf }
        library.append(contentsOf: filtered)
        if selection == nil, let first = filtered.first {
            selection = first.id
        }
    }

    func selectLibraryItem(_ id: UUID?) {
        selection = id
    }

    func assignSelectionToChannel(_ channelId: Int) {
        guard selectionCanAssignToChannel,
              let item = library.first(where: { $0.id == selection }) else { return }
        assignMedia(item.url, to: channelId)
    }

    /// Carrega no leitor de áudio o ficheiro atualmente seleccionado na biblioteca de áudio.
    func assignSelectionToAudioDeck() {
        guard selectionCanAssignToAudioDeck,
              let item = library.first(where: { $0.id == selection }) else { return }
        stopAudio()
        _ = item.url.startAccessingSecurityScopedResource()
        audioURL = item.url
    }

    // MARK: - Canais

    func assignMedia(_ url: URL, to channelId: Int) {
        guard LibraryShelf.classify(url: url) == .visual else { return }
        _ = url.startAccessingSecurityScopedResource()
        teardownPlayer(for: channelId)
        switch MediaKind.of(url: url) {
        case .video:
            players[channelId] = AVPlayer(url: url)
            attachVideoLoop(for: channelId)
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
            attachVideoLoop(for: channelId)
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
        detachVideoLoop(for: channelId)
        guard let player = players[channelId] else { return }
        player.pause()
        players.removeValue(forKey: channelId)
    }

    private func detachVideoLoop(for channelId: Int) {
        if let token = videoEndObservers[channelId] {
            NotificationCenter.default.removeObserver(token)
            videoEndObservers[channelId] = nil
        }
    }

    private func attachVideoLoop(for channelId: Int) {
        detachVideoLoop(for: channelId)
        guard let player = players[channelId],
              let item = player.currentItem else { return }

        videoEndObservers[channelId] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] notification in
            guard let notifiedItem = notification.object as? AVPlayerItem else { return }
            guard let p = player, p.currentItem === notifiedItem else { return }
            p.seek(to: .zero)
            p.play()
        }
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
