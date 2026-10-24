import Foundation

@MainActor
public class LyricsService: ObservableObject {
    public static let shared = LyricsService()

    @Published public var lyrics: Lyrics? = Lyrics.sample
    @Published public var isLoading: Bool = false

    private var cache: [String: Lyrics] = [:]
    /// Song key the current `lyrics` were fetched for; nil while showing the sample fallback.
    public private(set) var loadedKey: String?

    public static func key(for track: Track) -> String { "\(track.title)\u{0000}\(track.artist)" }

    private init() {}

    public func fetchLyrics(for track: Track) async {
        let key = Self.key(for: track)
        if let cached = cache[key] {
            self.loadedKey = key
            self.lyrics = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        // 1. Try exact match from LRCLIB
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration)))
        ]

        if let url = components.url,
           let record = await requestLRC(url: url) {
            let result = parseRecord(record)
            cache[key] = result
            self.loadedKey = key
            self.lyrics = result
            return
        }

        // 2. Try looser search from LRCLIB
        let clean = cleanTitle(track.title)
        var searchComponents = URLComponents(string: "https://lrclib.net/api/search")!
        searchComponents.queryItems = [
            URLQueryItem(name: "track_name", value: clean),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]

        if let searchURL = searchComponents.url,
           let records = await requestLRCSearch(url: searchURL),
           let best = records.first(where: { $0.syncedLyrics != nil }) ?? records.first {
            let result = parseRecord(best)
            cache[key] = result
            self.loadedKey = key
            self.lyrics = result
            return
        }

        // Fallback to sample if nothing found
        self.loadedKey = nil
        self.lyrics = Lyrics.sample
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        if let dash = cleaned.range(of: " - ") {
            let suffix = String(cleaned[dash.upperBound...])
            if suffix.range(of: "remaster|live|version|deluxe|edit|mix", options: .regularExpression) != nil {
                cleaned = String(cleaned[..<dash.lowerBound])
            }
        }
        return cleaned.replacingOccurrences(of: #"\s*[([](feat|ft|with)\.?[^)\]]*[)\]]"#, with: "", options: .regularExpression)
    }

    private struct LrcRecord: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    private func requestLRC(url: URL) async -> LrcRecord? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(LrcRecord.self, from: data)
    }

    private func requestLRCSearch(url: URL) async -> [LrcRecord]? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode([LrcRecord].self, from: data)
    }

    private func parseRecord(_ record: LrcRecord) -> Lyrics {
        var lines: [LyricLine] = []
        if let synced = record.syncedLyrics {
            let rawLines = synced.components(separatedBy: .newlines)
            let regex = try? NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)

            for line in rawLines {
                let range = NSRange(location: 0, length: line.utf16.count)
                guard let matches = regex?.matches(in: line, range: range), !matches.isEmpty else { continue }
                let lastMatch = matches.last!
                let textIndex = line.index(line.startIndex, offsetBy: lastMatch.range.location + lastMatch.range.length)
                let lyricText = String(line[textIndex...]).trimmingCharacters(in: .whitespaces)

                for match in matches {
                    if let mRange = Range(match.range(at: 1), in: line),
                       let sRange = Range(match.range(at: 2), in: line),
                       let m = Double(line[mRange]),
                       let s = Double(line[sRange]) {
                        lines.append(LyricLine(time: m * 60.0 + s, text: lyricText))
                    }
                }
            }
            lines.sort { ($0.time ?? 0) < ($1.time ?? 0) }
        }

        return Lyrics(synced: lines, plain: record.plainLyrics)
    }
}
