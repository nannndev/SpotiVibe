import Foundation

public struct LyricLine: Identifiable, Equatable, Hashable {
    public let id: String
    public let time: Double?
    public let text: String

    public init(id: String = UUID().uuidString, time: Double?, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public struct Lyrics: Equatable {
    public let synced: [LyricLine]
    public let plain: String?
    public let translations: [String: String]

    public init(synced: [LyricLine] = [], plain: String? = nil, translations: [String: String] = [:]) {
        self.synced = synced
        self.plain = plain
        self.translations = translations
    }

    /// Synced lines with text. LRC files mark instrumental breaks with empty lines; dropping them
    /// here (not just from the text) keeps every line paired with its own timestamp.
    public var sungLines: [LyricLine] {
        synced.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    public var allLines: [String] {
        if !synced.isEmpty {
            return sungLines.map(\.text)
        }
        if let plain = plain {
            return plain.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    public static let sample = Lyrics(
        synced: [
            LyricLine(time: 0.0, text: "Baby, please try to forgive me"),
            LyricLine(time: 4.5, text: "Stay here, don't put out the glow"),
            LyricLine(time: 8.8, text: "Hold me now, don't bother if every minute it makes me weaker"),
            LyricLine(time: 14.2, text: "You can save me from the man that I've become, oh yeah"),
            LyricLine(time: 21.0, text: "Looking back on the things I've done"),
            LyricLine(time: 25.5, text: "I was trying for you, I was trying for you"),
            LyricLine(time: 30.2, text: "I was trying for you, oh yeah"),
            LyricLine(time: 35.0, text: "Tell me why ain't nothin' but a heartache"),
            LyricLine(time: 39.5, text: "Tell me why ain't nothin' but a mistake"),
            LyricLine(time: 44.0, text: "Tell me why, I never wanna hear you say"),
            LyricLine(time: 49.0, text: "I want it that way")
        ]
    )
}
