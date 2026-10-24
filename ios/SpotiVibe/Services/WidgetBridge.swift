import Foundation
import UIKit
import WidgetKit

/// Hands the current song, its synced lyrics and the playback position to the widget.
@MainActor
enum WidgetBridge {
    private static var last: NowPlaying?
    private static var artwork: (url: URL, data: Data?)?

    /// `lyrics` must belong to `track` (pass nil otherwise) or the widget would show the wrong song's words.
    static func update(track: Track, lyrics: Lyrics?, position: Double, syncedAt: Date) {
        let synced = (lyrics?.sungLines ?? []).filter { $0.time != nil }
        var next = NowPlaying(
            title: track.title,
            artist: track.artist,
            artwork: artwork?.url == track.artworkURL ? artwork?.data : nil,
            lines: synced.map(\.text),
            times: synced.compactMap(\.time),
            songStart: track.isPlaying ? syncedAt.addingTimeInterval(-position) : nil,
            duration: track.duration
        )
        // polls arrive every 2.5s; only reload the widget when something it shows would change
        if let last, last.sameExceptClock(as: next), last.clockDrift(to: next) < 1.5 { return }
        last = next

        Task {
            if let url = track.artworkURL, artwork?.url != url {
                var data: Data?
                if let (raw, _) = try? await URLSession.shared.data(from: url) {
                    // widgets have a tight memory limit; keep the image small
                    data = UIImage(data: raw)?.preparingThumbnail(of: CGSize(width: 220, height: 220))?.jpegData(compressionQuality: 0.85)
                }
                artwork = (url, data)
                next.artwork = data
                guard last?.title == next.title else { return } // song changed while downloading
                last = next
            }
            next.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "NowPlaying")
        }
    }
}

private extension NowPlaying {
    func sameExceptClock(as other: NowPlaying) -> Bool {
        var a = self, b = other
        a.songStart = nil; b.songStart = nil
        a.artwork = nil; b.artwork = nil
        return a == b && (songStart == nil) == (other.songStart == nil)
    }

    func clockDrift(to other: NowPlaying) -> TimeInterval {
        guard let a = songStart, let b = other.songStart else { return 0 }
        return abs(a.timeIntervalSince(b))
    }
}
