import CoreGraphics
import Foundation

/// Vídeos e imagens de amostra: primeiro `Bundle.module` (`Resources/SampleMedia`), depois gera em cache se faltar algum recurso.
enum SampleMediaProvisioner {

    nonisolated static func bootstrapVisualURLs() throws -> [URL] {
        var ordered: [URL] = []

        let jamaicaURL = try resolveJamaicaSample()
        ordered.append(jamaicaURL)

        let magentaURL = try resolveVideo(
            bundledBase: "amostra_video_magenta",
            cacheFileName: "amostra_video_magenta.mov",
            rgb: (r: 0.92, g: 0.12, b: 0.74)
        )
        ordered.append(magentaURL)

        let cianoURL = try resolveVideo(
            bundledBase: "amostra_video_ciano",
            cacheFileName: "amostra_video_ciano.mov",
            rgb: (r: 0.05, g: 0.76, b: 0.95)
        )
        ordered.append(cianoURL)

        let pngBases = ["amostra_laranja", "amostra_oceano", "amostra_roxo"]
        for base in pngBases {
            if let u = Bundle.module.url(forResource: base, withExtension: "png", subdirectory: "SampleMedia") {
                ordered.append(u)
            }
        }

        guard !ordered.isEmpty else {
            throw URLError(.fileDoesNotExist)
        }

        return ordered
    }

    private nonisolated static func resolveJamaicaSample() throws -> URL {
        if let bundled = Bundle.module.url(forResource: "amostra_jamaica", withExtension: "mov", subdirectory: "SampleMedia") {
            return bundled
        }

        let cacheRoot = try cacheDirectory()
        let cached = cacheRoot.appendingPathComponent("amostra_jamaica.mov", isDirectory: false)
        if !FileManager.default.fileExists(atPath: cached.path) {
            try SampleMovieGenerator.encodeJamaicaPulseMOV(
                to: cached,
                size: SampleMovieGenerator.outputSize,
                durationSeconds: 12,
                fps: 30
            )
        }
        return cached
    }

    private nonisolated static func resolveVideo(
        bundledBase: String,
        cacheFileName: String,
        rgb: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) throws -> URL {
        if let bundled = Bundle.module.url(forResource: bundledBase, withExtension: "mov", subdirectory: "SampleMedia") {
            return bundled
        }

        let cacheRoot = try cacheDirectory()
        let cached = cacheRoot.appendingPathComponent(cacheFileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: cached.path) {
            try SampleMovieGenerator.encodeSolidColorMOV(
                to: cached,
                size: SampleMovieGenerator.outputSize,
                durationSeconds: 5,
                fps: 30,
                rgb: rgb
            )
        }
        return cached
    }

    nonisolated private static func cacheDirectory() throws -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OrchestraVisual", isDirectory: true)
            .appendingPathComponent("GeneratedSamples", isDirectory: true)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
