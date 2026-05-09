import Foundation

/// Biblioteca inicial: apenas dois vídeos em `Resources/SampleMedia/UserSamples/`.
enum SampleMediaProvisioner {

    private static let starterMovieNames = [
        "amostra_demo_curta_480p_30s.mov",
        "amostra_surfe_720p_3min.mov",
    ]

    nonisolated static func bootstrapVisualURLs() throws -> [URL] {
        guard let root = Bundle.module.resourceURL else {
            throw URLError(.fileDoesNotExist)
        }
        let dir = root.appendingPathComponent("SampleMedia/UserSamples", isDirectory: true)

        var ordered: [URL] = []
        for name in starterMovieNames {
            let url = dir.appendingPathComponent(name, isDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw URLError(.fileDoesNotExist)
            }
            ordered.append(url)
        }
        return ordered
    }
}
