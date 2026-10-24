import UIKit
import AVFoundation
import CoreGraphics
import CoreVideo
import SwiftUI

public enum LyricVideoGenerator {

    public enum VideoError: LocalizedError {
        case writerCreationFailed
        case frameExtractionFailed
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .writerCreationFailed: return "Failed to initialize video writer."
            case .frameExtractionFailed: return "Could not generate video frames."
            case .cancelled: return "Export cancelled."
            }
        }
    }

    @MainActor
    public static func renderVideo(
        duration: Double,
        fps: Int = 30,
        size: CGSize,
        scale: CGFloat = 3.0,
        frameBuilder: @escaping (Double) async -> AnyView,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let totalFrames = max(1, Int(duration * Double(fps)))
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)

        let tempFolder = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let outputURL = tempFolder.appendingPathComponent("SpotiVibe_\(formatter.string(from: Date())).mp4")

        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw VideoError.writerCreationFailed
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw VideoError.writerCreationFailed
        }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<totalFrames {
            let currentTime = Double(frameIndex) / Double(fps)
            let presentationTime = CMTime(value: Int64(frameIndex), timescale: Int32(fps))

            let view = await frameBuilder(currentTime)
                .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = scale

            // skipping a frame would shift the rest of the video; fail instead
            guard let renderedCG = renderer.cgImage else { throw VideoError.frameExtractionFailed }

            // wait as long as it takes: giving up and appending anyway silently drops the frame,
            // which shortens the video and pulls every later lyric earlier
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            guard let pixelBuffer = pixelBuffer(from: renderedCG, size: pixelSize),
                  adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw VideoError.frameExtractionFailed
            }

            onProgress(Double(frameIndex + 1) / Double(totalFrames))

            if frameIndex % 5 == 0 {
                await Task.yield()
            }
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        return outputURL
    }

    private static func pixelBuffer(from cgImage: CGImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
