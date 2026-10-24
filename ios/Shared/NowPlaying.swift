import Foundation

/// The current song as the widget sees it. Written by the app into the App Group, read by the widget.
struct NowPlaying: Codable, Equatable {
    var title: String
    var artist: String
    var artwork: Data?
    /// Synced lyric lines and their start times in seconds; empty when there are no synced lyrics.
    var lines: [String] = []
    var times: [Double] = []
    /// Wall-clock time the song was at 0:00; nil when paused, so the widget doesn't advance lyrics.
    var songStart: Date?
    var duration: Double = 0

    static let groupID = "group.com.naneps.spotivibe"
    static let key = "nowPlaying"
    static let placeholder = NowPlaying(title: "Play a song on Spotify", artist: "SpotiVibe")

    static func load() -> NowPlaying? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NowPlaying.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.groupID)?.set(data, forKey: Self.key)
    }

    /// Index of the line being sung `position` seconds into the song.
    static func line(at position: Double, times: [Double]) -> Int? {
        times.lastIndex { $0 <= position }
    }

    /// When the widget should switch lines: now, then each upcoming line, then nil at the end of the song.
    func schedule(from now: Date, limit: Int = 120) -> [(date: Date, line: Int?)] {
        guard let songStart, !times.isEmpty else { return [(now, nil)] }
        let position = now.timeIntervalSince(songStart)
        var out: [(date: Date, line: Int?)] = [(now, Self.line(at: position, times: times))]
        for (i, t) in times.enumerated() where t > position && t < duration {
            out.append((songStart.addingTimeInterval(t), i))
        }
        if duration > position { out.append((songStart.addingTimeInterval(duration), nil)) }
        return Array(out.prefix(limit))
    }
}
