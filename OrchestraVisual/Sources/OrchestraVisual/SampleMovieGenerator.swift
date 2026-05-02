import AVFoundation
import CoreVideo
import Foundation

/// Gera `.mov` H.264 de demonstração — dimensões múltiplas de **16×16** para evitar ecrã vazio em alguns decoders.
enum SampleMovieGenerator {

    /// 848×480: ambos divisíveis por 16 (16×53 e 16×30).
    static let outputSize = CGSize(width: 848, height: 480)

    /// Cores aproximadas da bandeira da Jamaica (alternância no tempo via `encodeJamaicaPulseMOV`).
    static let jamaicaGreen = (r: CGFloat(0) / 255, g: CGFloat(155) / 255, b: CGFloat(58) / 255) // #009B3A ≈ verde oficial
    static let jamaicaGold = (r: CGFloat(254) / 255, g: CGFloat(221) / 255, b: CGFloat(0) / 255) // #FEDD00
    /// Preto “leve”: preto verdadeiro + H264 às vezes esmagava no preview.
    static let jamaicaBlackVideo = (r: CGFloat(0.08), g: CGFloat(0.08), b: CGFloat(0.085))

    private static var defaultVideoCompression: [String: Any] {
        [
            AVVideoAverageBitRateKey: 950_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
        ]
    }

    /// Vídeo de exemplo **Jamaica**: alterna verde → ouro → preto (cicla ao longo de `durationSeconds`).
    static func encodeJamaicaPulseMOV(
        to url: URL,
        size: CGSize,
        durationSeconds: Double,
        fps: Int32
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let w = aligned16(max(96, Int(size.width)))
        let h = aligned16(max(96, Int(size.height)))

        var videoCompression = defaultVideoCompression
        videoCompression[AVVideoAverageBitRateKey] = 1_400_000

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: videoCompression,
        ]

        try encodePixelBufferMovie(
            to: writer,
            videoSettings: videoSettings,
            width: w,
            height: h,
            durationSeconds: durationSeconds,
            fps: fps,
            rgbForFrameIndex: { frameIdx in
                let t = Double(frameIdx) / Double(fps)
                let cycleDuration = Swift.max(durationSeconds, 9.0 / Swift.max(Double(fps), 1))
                let slice = cycleDuration / 3
                let u = t.truncatingRemainder(dividingBy: cycleDuration)
                let phase = min(2, max(0, Int(u / slice)))
                switch phase {
                case 0: return jamaicaGreen
                case 1: return jamaicaGold
                default: return jamaicaBlackVideo
                }
            }
        )
    }

    static func encodeSolidColorMOV(
        to url: URL,
        size: CGSize,
        durationSeconds: Double,
        fps: Int32,
        rgb: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let w = aligned16(max(96, Int(size.width)))
        let h = aligned16(max(96, Int(size.height)))

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: defaultVideoCompression,
        ]

        try encodePixelBufferMovie(
            to: writer,
            videoSettings: videoSettings,
            width: w,
            height: h,
            durationSeconds: durationSeconds,
            fps: fps,
            rgbForFrameIndex: { _ in rgb }
        )
    }

    private static func aligned16(_ v: Int) -> Int { max(16, (v / 16) * 16) }

    private static func encodePixelBufferMovie(
        to writer: AVAssetWriter,
        videoSettings: [String: Any],
        width: Int,
        height: Int,
        durationSeconds: Double,
        fps: Int32,
        rgbForFrameIndex: (_ frameIdx: Int64) -> (r: CGFloat, g: CGFloat, b: CGFloat)
    ) throws {
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)

        guard writer.canAdd(input) else { throw URLError(.cannotCreateFile) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? URLError(.cannotCreateFile) }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        let totalFrames = max(2, Int64(durationSeconds * Double(fps)))

        for frameIdx in Int64(0) ..< totalFrames {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            let rgb = rgbForFrameIndex(frameIdx)

            let br = UInt8(max(0, min(255, Int(rgb.b * 255))))
            let gg = UInt8(max(0, min(255, Int(rgb.g * 255))))
            let rr = UInt8(max(0, min(255, Int(rgb.r * 255))))

            var pb: CVPixelBuffer?
            let cvStatus = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
            guard cvStatus == kCVReturnSuccess, let px = pb else { break }

            CVPixelBufferLockBaseAddress(px, [])
            defer { CVPixelBufferUnlockBaseAddress(px, []) }

            guard let ptr = CVPixelBufferGetBaseAddress(px) else { continue }
            let rowBytes = CVPixelBufferGetBytesPerRow(px)
            for y in 0 ..< height {
                let row = ptr.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0 ..< width {
                    let o = x * 4
                    row[o] = br
                    row[o + 1] = gg
                    row[o + 2] = rr
                    row[o + 3] = 255
                }
            }

            let t = CMTimeMultiply(frameDuration, multiplier: Int32(frameIdx))
            if !adaptor.append(px, withPresentationTime: t) {
                break
            }
        }

        input.markAsFinished()

        let group = DispatchGroup()
        group.enter()
        writer.finishWriting {
            group.leave()
        }
        group.wait()

        guard writer.status == .completed else {
            throw writer.error ?? URLError(.cannotWriteToFile)
        }
    }
}
