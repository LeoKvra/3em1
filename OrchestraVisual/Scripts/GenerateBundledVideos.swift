#!/usr/bin/env swift
/// Gera `amostra_video_magenta.mov` e `amostra_video_ciano.mov` em Resources/SampleMedia (executar desde o repo quando precisares regenerar).
/// Uso: `swift Scripts/GenerateBundledVideos.swift` ( cwd = pasta OrchestraVisual )
import AVFoundation
import CoreVideo
import Foundation

enum BundledMOVWriter {
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

        let w = max(64, Int(size.width))
        let h = max(64, Int(size.height))

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 350_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
            ],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)

        guard writer.canAdd(input) else { throw URLError(.cannotCreateFile) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? URLError(.cannotCreateFile) }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        let totalFrames = max(2, Int64(durationSeconds * Double(fps)))

        let br = UInt8(max(0, min(255, Int(rgb.b * 255))))
        let gg = UInt8(max(0, min(255, Int(rgb.g * 255))))
        let rr = UInt8(max(0, min(255, Int(rgb.r * 255))))

        for frameIdx in Int64(0) ..< totalFrames {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            var pb: CVPixelBuffer?
            let cvStatus = CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
            guard cvStatus == kCVReturnSuccess, let px = pb else { break }

            CVPixelBufferLockBaseAddress(px, [])
            defer { CVPixelBufferUnlockBaseAddress(px, []) }

            guard let ptr = CVPixelBufferGetBaseAddress(px) else { continue }
            let rowBytes = CVPixelBufferGetBytesPerRow(px)
            for y in 0 ..< h {
                let row = ptr.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0 ..< w {
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

let scriptURL = URL(fileURLWithPath: #filePath)
let orchestraPkgRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sampleMediaDir = orchestraPkgRoot
    .appendingPathComponent("Sources/OrchestraVisual/Resources/SampleMedia", isDirectory: true)

try FileManager.default.createDirectory(at: sampleMediaDir, withIntermediateDirectories: true)

let magentaOut = sampleMediaDir.appendingPathComponent("amostra_video_magenta.mov")
let cianoOut = sampleMediaDir.appendingPathComponent("amostra_video_ciano.mov")

try BundledMOVWriter.encodeSolidColorMOV(
    to: magentaOut,
    size: CGSize(width: 640, height: 360),
    durationSeconds: 4,
    fps: 24,
    rgb: (r: 0.92, g: 0.12, b: 0.74)
)
print("✓ \(magentaOut.path)")

try BundledMOVWriter.encodeSolidColorMOV(
    to: cianoOut,
    size: CGSize(width: 640, height: 360),
    durationSeconds: 4,
    fps: 24,
    rgb: (r: 0.05, g: 0.76, b: 0.95)
)
print("✓ \(cianoOut.path)")
