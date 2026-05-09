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
    /// Áudio embutido no vídeo (independente do leitor da barra inferior). Por defeito começa mutado.
    var videoAudioMuted: Bool
    /// Efeito visual da live (pixel / falha); independente do botão «Efeito» (alto contraste).
    var visualEffectMode: LiveVisualEffectMode = .none
}

@MainActor
final class OrchestratorViewModel: ObservableObject {

    /// Saídas de vídeo (uma por live de programa; cresce com «+ Live», até `LiveSlot.maxProgramLives`).
    @Published private(set) var channels: [ChannelState] = OrchestratorViewModel.makeInitialChannels()

    /// Pills no topo (Geral + Live 1…n); cada live de programa referencia `channels` por `mappedChannelId`.
    @Published private(set) var liveSlots: [LiveSlot] = LiveSlot.phase1Initial
    @Published private(set) var library: [LibraryItem] = []
    @Published var selection: UUID?
    @Published private(set) var audioURL: URL?
    @Published private(set) var audioIsPlaying = false

    /// Linha de tempo por canal (só vídeo); actualizado ~4×/s durante reprodução.
    @Published private(set) var videoPlaybackByChannel: [Int: VideoPlaybackInfo] = [:]

    private var players: [Int: AVPlayer] = [:]
    private var audioPlayer: AVAudioPlayer?
    /// Observadores `AVPlayerItemDidPlayToEndTime` por canal para loop local (demos ao vivo).
    private var videoEndObservers: [Int: NSObjectProtocol] = [:]
    private var playbackTimeObservers: [Int: Any] = [:]
    /// Evita que o temporizador sobrescreva o slider durante o arrastar.
    private var scrubbingChannels: Set<Int> = []

    private static func makeInitialChannels() -> [ChannelState] {
        [
            ChannelState(id: 0, title: "Saída 1 · Fundo widescreen", assignedURL: nil, isPlaying: false, effectOn: false, videoAudioMuted: true),
            ChannelState(id: 1, title: "Saída 2 · Pano / músico", assignedURL: nil, isPlaying: false, effectOn: false, videoAudioMuted: true),
        ]
    }

    /// Adiciona um canal de programa e o pill correspondente (Live 3 / 4…).
    @discardableResult
    func addProgramLiveSlot() -> UUID? {
        let programCount = liveSlots.filter { !$0.isGeneral }.count
        guard programCount < LiveSlot.maxProgramLives else { return nil }

        let nextChannelId = (channels.map(\.id).max() ?? -1) + 1
        let ordinal = channels.count

        let channelTitle: String
        switch ordinal {
        case 0: channelTitle = "Saída 1 · Fundo widescreen"
        case 1: channelTitle = "Saída 2 · Pano / músico"
        default: channelTitle = "Saída \(ordinal + 1) · programa"
        }

        let newChannel = ChannelState(
            id: nextChannelId,
            title: channelTitle,
            assignedURL: nil,
            isPlaying: false,
            effectOn: false,
            videoAudioMuted: true,
            visualEffectMode: .none
        )

        let slot = LiveSlot(
            id: UUID(),
            title: "Live \(programCount + 1)",
            isGeneral: false,
            mappedChannelId: nextChannelId
        )

        channels.append(newChannel)
        liveSlots.append(slot)
        return slot.id
    }

    // MARK: - Arranque (amostras + previews)

    /// Carrega os dois vídeos de amostra (`UserSamples`) e preenche a biblioteca quando vazia.
    /// Atribui um vídeo por saída e inicia reprodução nos dois previews (decodificadores em paralelo).
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

    /// Define mídia inicial nas duas saídas: primeiro vídeo na saída 1, segundo na saída 2 (ou duplica se só houver um).
    private func wireStarterAssignments(from items: [LibraryItem]) {
        let videos = items.filter { MediaKind.of(url: $0.url) == .video }
        if !videos.isEmpty {
            let urlA = videos[0].url
            let urlB = videos.count > 1 ? videos[1].url : videos[0].url
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
            let muted = channels.first(where: { $0.id == channelId })?.videoAudioMuted ?? true
            let player = AVPlayer(url: url)
            player.isMuted = muted
            players[channelId] = player
            attachVideoLoop(for: channelId)
            installPlaybackTracking(for: channelId)
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
            let muted = channels.first(where: { $0.id == channelId })?.videoAudioMuted ?? true
            let player = players[channelId] ?? AVPlayer(url: url)
            player.isMuted = muted
            players[channelId] = player
            attachVideoLoop(for: channelId)
            installPlaybackTracking(for: channelId)
            player.play()
            updateChannel(channelId) { $0.isPlaying = true }
        case .image, .unknown:
            updateChannel(channelId) { $0.isPlaying = true }
        }
    }

    /// Pausa sem mudar a posição na linha de tempo (vídeo ou estado visual da imagem).
    func pause(channelId: Int) {
        guard let url = channels.first(where: { $0.id == channelId })?.assignedURL else { return }
        switch MediaKind.of(url: url) {
        case .video:
            players[channelId]?.pause()
            updateChannel(channelId) { $0.isPlaying = false }
        case .image, .unknown:
            updateChannel(channelId) { $0.isPlaying = false }
        }
    }

    /// Volta ao primeiro frame e mantém em pausa até «Reproduzir» (só vídeo).
    func restartFromBeginning(channelId: Int) {
        guard let url = channels.first(where: { $0.id == channelId })?.assignedURL else { return }
        guard MediaKind.of(url: url) == .video else { return }
        players[channelId]?.pause()
        players[channelId]?.seek(to: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                self?.updatePlaybackProgress(for: channelId)
            }
        }
        updateChannel(channelId) { $0.isPlaying = false }
    }

    func toggleEffect(channelId: Int) {
        updateChannel(channelId) { $0.effectOn.toggle() }
    }

    func setVisualEffectMode(channelId: Int, mode: LiveVisualEffectMode) {
        updateChannel(channelId) { $0.visualEffectMode = mode }
    }

    func toggleVideoAudioMute(channelId: Int) {
        guard let url = channels.first(where: { $0.id == channelId })?.assignedURL,
              MediaKind.of(url: url) == .video else { return }
        updateChannel(channelId) { $0.videoAudioMuted.toggle() }
        syncVideoAudioMute(for: channelId)
    }

    /// Som embutido em todos os canais (prepara saídas com vídeo; ao atribuir vídeo novo, herda o estado).
    func setAllVideoEmbeddedAudioMuted(_ muted: Bool) {
        for id in channels.map(\.id) {
            updateChannel(id) { $0.videoAudioMuted = muted }
            syncVideoAudioMute(for: id)
        }
    }

    func clearChannel(channelId: Int) {
        pause(channelId: channelId)
        teardownPlayer(for: channelId)
        updateChannel(channelId) { ch in
            ch.assignedURL = nil
            ch.effectOn = false
            ch.videoAudioMuted = true
            ch.visualEffectMode = .none
        }
    }

    private func syncVideoAudioMute(for channelId: Int) {
        guard let muted = channels.first(where: { $0.id == channelId })?.videoAudioMuted else { return }
        players[channelId]?.isMuted = muted
    }

    private func updateChannel(_ channelId: Int, _ mutate: (inout ChannelState) -> Void) {
        guard let idx = channels.firstIndex(where: { $0.id == channelId }) else { return }
        var ch = channels[idx]
        mutate(&ch)
        channels[idx] = ch
    }

    private func teardownPlayer(for channelId: Int) {
        detachVideoLoop(for: channelId)
        removePlaybackTracking(for: channelId)
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

    func videoPlayback(for channelId: Int) -> VideoPlaybackInfo? {
        videoPlaybackByChannel[channelId]
    }

    func seekVideo(channelId: Int, fraction: Double) {
        guard let player = players[channelId],
              let item = player.currentItem else { return }
        let dur = CMTimeGetSeconds(item.duration)
        guard dur.isFinite, dur > 0, !dur.isNaN else { return }
        let clamped = min(1, max(0, fraction))
        let t = CMTime(seconds: clamped * dur, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                self?.updatePlaybackProgress(for: channelId)
            }
        }
    }

    func setVideoScrubbing(_ channelId: Int, _ active: Bool) {
        if active {
            scrubbingChannels.insert(channelId)
        } else {
            scrubbingChannels.remove(channelId)
            updatePlaybackProgress(for: channelId)
        }
    }

    private func installPlaybackTracking(for channelId: Int) {
        removePlaybackTracking(for: channelId)
        guard let player = players[channelId] else { return }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        let token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackProgress(for: channelId)
            }
        }
        playbackTimeObservers[channelId] = token
        updatePlaybackProgress(for: channelId)
    }

    private func removePlaybackTracking(for channelId: Int) {
        if let token = playbackTimeObservers[channelId],
           let player = players[channelId] {
            player.removeTimeObserver(token)
        }
        playbackTimeObservers.removeValue(forKey: channelId)
        scrubbingChannels.remove(channelId)
        var next = videoPlaybackByChannel
        next.removeValue(forKey: channelId)
        videoPlaybackByChannel = next
    }

    private func updatePlaybackProgress(for channelId: Int) {
        guard !scrubbingChannels.contains(channelId),
              let player = players[channelId],
              let item = player.currentItem else { return }

        let cur = CMTimeGetSeconds(player.currentTime())
        let dur = CMTimeGetSeconds(item.duration)
        let validDur = dur.isFinite && !dur.isNaN && dur > 0 ? dur : 0
        let validCur = cur.isFinite && !cur.isNaN && cur >= 0 ? cur : 0

        let info = VideoPlaybackInfo(currentSeconds: validCur, durationSeconds: validDur)
        var next = videoPlaybackByChannel
        next[channelId] = info
        videoPlaybackByChannel = next
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
