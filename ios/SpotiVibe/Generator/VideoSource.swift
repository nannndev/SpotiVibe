import AVFoundation
import SwiftUI
import CoreImage
import UIKit
import UniformTypeIdentifiers

/// A picked or recorded clip used as card background / cover in video mode. Loops to fill the lyric video.
@MainActor
final class VideoSource {
    let thumbnail: UIImage
    private let player: AVPlayer
    private let output: AVPlayerItemVideoOutput
    private let exporter: AVAssetImageGenerator
    private let orientation: CGImagePropertyOrientation
    let length: Double
    /// Trimmed range inside the clip (set by the trimmer). The lyric video loops this range.
    var trimStart: Double = 0
    lazy var trimEnd: Double = length
    private let ciContext = CIContext()
    private var lastFrame: UIImage?

    private init(asset: AVURLAsset, thumbnail: UIImage, length: Double, naturalSize: CGSize, orientation: CGImagePropertyOrientation) {
        self.thumbnail = thumbnail
        self.length = max(length, 0.1)
        self.orientation = orientation

        // decode preview frames at <=720px so 30fps conversion stays cheap
        let scale = min(1, 720 / max(naturalSize.width, naturalSize.height))
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(naturalSize.width * scale),
            kCVPixelBufferHeightKey as String: Int(naturalSize.height * scale)
        ])
        let item = AVPlayerItem(asset: asset)
        item.add(output)
        player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        exporter = AVAssetImageGenerator(asset: asset)
        exporter.appliesPreferredTrackTransform = true
        exporter.maximumSize = CGSize(width: 1920, height: 1920)
        exporter.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        exporter.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
    }

    static func load(url: URL) async throws -> VideoSource {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw URLError(.cannotDecodeContentData) // clip has no video track
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let duration = try await asset.load(.duration).seconds

        let thumbGen = AVAssetImageGenerator(asset: asset)
        thumbGen.appliesPreferredTrackTransform = true
        thumbGen.maximumSize = CGSize(width: 1080, height: 1080)
        let thumb = try await thumbGen.image(at: .zero).image

        return VideoSource(asset: asset, thumbnail: UIImage(cgImage: thumb), length: duration,
                           naturalSize: naturalSize, orientation: orientation(for: transform))
    }

    /// Live preview frame; keeps the muted player in step with the preview timeline.
    func previewFrame(at time: Double, playing: Bool) -> UIImage {
        let target = sourceTime(time)
        if abs(player.currentTime().seconds - target) > 0.25 {
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if playing, player.rate == 0 { player.play() }
        if !playing, player.rate != 0 { player.pause() }

        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: itemTime),
           let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            let image = CIImage(cvPixelBuffer: buffer).oriented(orientation)
            if let cg = ciContext.createCGImage(image, from: image.extent) {
                lastFrame = UIImage(cgImage: cg)
            }
        }
        return lastFrame ?? thumbnail
    }

    func pause() {
        if player.rate != 0 { player.pause() }
    }

    /// Exact frame for export, looping the clip if it's shorter than the lyric video.
    func exportFrame(at time: Double) async -> UIImage {
        let target = CMTime(seconds: sourceTime(time), preferredTimescale: 600)
        guard let cg = try? await exporter.image(at: target).image else { return thumbnail }
        return UIImage(cgImage: cg)
    }

    private func sourceTime(_ time: Double) -> Double {
        let span = max(trimEnd - trimStart, 0.1)
        return trimStart + time.truncatingRemainder(dividingBy: span)
    }

    /// Evenly spaced thumbnails for the trimmer's filmstrip.
    func filmstrip(count: Int) async -> [UIImage] {
        let gen = AVAssetImageGenerator(asset: exporter.asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 160, height: 160)
        var frames: [UIImage] = []
        for i in 0..<count {
            let t = CMTime(seconds: length * (Double(i) + 0.5) / Double(count), preferredTimescale: 600)
            if let cg = try? await gen.image(at: t).image { frames.append(UIImage(cgImage: cg)) }
        }
        return frames
    }

    /// Pixel buffers come unrotated; map the track transform (e.g. portrait iPhone video) to an orientation.
    private static func orientation(for t: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (t.a, t.b, t.c, t.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}

/// Lets PhotosPicker hand us a video file we own (the picker's copy is deleted after the call).
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}
