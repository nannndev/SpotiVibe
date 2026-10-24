import SwiftUI

/// User overrides for how lyric lines look. `nil` / `.auto` keeps the card style's own look.
public struct LyricTextStyle: Equatable {
    public var alignment: TextAlignment? = nil
    public var font: LyricFont = .auto
    public var color: Color? = nil
    public var effect: LyricEffect = .none
    public var animation: LyricAnimation = .highlight
    public var showWatermark = true

    public init() {}
}

/// How the active line enters in video mode.
public enum LyricAnimation: String, CaseIterable, Identifiable {
    /// OpenNotchi style: the sung line switches to bold at its timestamp, the rest stay dim. Default.
    case highlight, karaoke, words, typewriter, fade

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .highlight: return "Highlight"
        case .karaoke: return "Karaoke"
        case .words: return "Word by word"
        case .typewriter: return "Typewriter"
        case .fade: return "Fade"
        }
    }
}

/// "align|font|#RRGGBBAA|effect|animation|watermark" so it fits in @AppStorage.
/// Unknown parts fall back to defaults; 4-part strings from older builds still load.
extension LyricTextStyle: RawRepresentable {
    public init?(rawValue: String) {
        let p = rawValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 4 || p.count == 6 else { return nil }
        alignment = ["leading": .leading, "center": .center, "trailing": .trailing][p[0]]
        font = LyricFont(rawValue: p[1]) ?? .auto
        color = Self.color(hex: p[2])
        effect = LyricEffect(rawValue: p[3]) ?? .none
        if p.count == 6 {
            animation = LyricAnimation(rawValue: p[4]) ?? .highlight
            showWatermark = p[5] != "0"
        }
    }

    public var rawValue: String {
        let align = alignment.map { $0 == .leading ? "leading" : ($0 == .center ? "center" : "trailing") } ?? ""
        return [align, font.rawValue, color.map(Self.hex) ?? "", effect.rawValue,
                animation.rawValue, showWatermark ? "1" : "0"].joined(separator: "|")
    }

    private static func hex(_ c: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", clamp(r), clamp(g), clamp(b), clamp(a))
    }

    private static func color(hex: String) -> Color? {
        guard hex.hasPrefix("#"), hex.count == 9, let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return Color(.sRGB, red: Double(v >> 24 & 0xFF) / 255, green: Double(v >> 16 & 0xFF) / 255,
                     blue: Double(v >> 8 & 0xFF) / 255, opacity: Double(v & 0xFF) / 255)
    }
}

/// Optional text effect; off by default so lines only animate.
public enum LyricEffect: String, CaseIterable, Identifiable {
    case none, glow, shadow

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .none: return "None"
        case .glow: return "Glow"
        case .shadow: return "Shadow"
        }
    }
}

extension TextAlignment {
    var frame: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Fonts that ship with iOS, so nothing has to be bundled.
public enum LyricFont: String, CaseIterable, Identifiable {
    case auto, system, rounded, serif, mono
    case avenir, futura, didot, bodoni, georgia, typewriter, marker, chalkboard, noteworthy, snell

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .auto: return "Auto"
        case .system: return "Sans"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        case .avenir: return "Avenir"
        case .futura: return "Futura"
        case .didot: return "Didot"
        case .bodoni: return "Bodoni"
        case .georgia: return "Georgia"
        case .typewriter: return "Typewriter"
        case .marker: return "Marker"
        case .chalkboard: return "Chalk"
        case .noteworthy: return "Note"
        case .snell: return "Script"
        }
    }

    /// nil for `.auto`: caller falls back to the card style's font.
    func font(size: CGFloat, weight: Font.Weight) -> Font? {
        switch self {
        case .auto: return nil
        case .system: return .system(size: size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .avenir: return .custom("AvenirNext-Regular", size: size).weight(weight)
        case .futura: return .custom("Futura-Medium", size: size).weight(weight)
        case .didot: return .custom("Didot", size: size).weight(weight)
        case .bodoni: return .custom("BodoniSvtyTwoITCTT-Book", size: size).weight(weight)
        case .georgia: return .custom("Georgia", size: size).weight(weight)
        case .typewriter: return .custom("AmericanTypewriter", size: size).weight(weight)
        case .marker: return .custom("MarkerFelt-Wide", size: size)
        case .chalkboard: return .custom("ChalkboardSE-Regular", size: size).weight(weight)
        case .noteworthy: return .custom("Noteworthy-Bold", size: size)
        case .snell: return .custom("SnellRoundhand-Bold", size: size * 1.15)
        }
    }
}

/// Where playback is inside the selected lines: which line is being sung and how far into it.
public struct LyricPlayhead: Equatable {
    /// Line being sung; nil before the first line and during a melody/instrumental gap.
    public var index: Int?
    public var progress: Double
    /// Index of the most recent line that has started (for dimming already-sung lines during a gap).
    public var lastStarted: Int = -1

    /// A line is "sung" for about this many seconds per character, capped, so its animation follows
    /// the singer instead of stretching across a long melody before the next line.
    static func singingTime(for text: String) -> Double {
        min(max(Double(text.count) * 0.09, 1.2), 6)
    }

    /// `times` are song timestamps for every lyric line; `selection` indexes into them.
    /// `texts` (same indexing as `times`) sets how long each line takes to sing.
    public static func at(songTime: Double, elapsed: Double, duration: Double,
                          selection: ClosedRange<Int>, times: [Double?], texts: [String] = []) -> LyricPlayhead {
        let lines = Array(selection)
        let stamps = lines.map { $0 < times.count ? times[$0] : nil }

        guard stamps.contains(where: { $0 != nil }) else {
            // unsynced lyrics: split the video evenly across lines
            let slot = duration / Double(max(lines.count, 1))
            let pos = min(max(elapsed, 0), duration * 0.999)
            let idx = min(Int(pos / max(slot, 0.001)), max(lines.count - 1, 0))
            return LyricPlayhead(index: idx, progress: min(1, (pos - Double(idx) * slot) / max(slot, 0.001)), lastStarted: idx)
        }

        var started = -1
        for (i, t) in stamps.enumerated() { if let t, t <= songTime { started = i } }
        guard started >= 0, let start = stamps[started] else { return LyricPlayhead(index: nil, progress: 0) }

        // next timestamp after this line, including the line just past the selection
        let next = stamps.dropFirst(started + 1).compactMap { $0 }.first
            ?? (selection.upperBound + 1 < times.count ? times[selection.upperBound + 1] : nil)
        let lineIndex = lines[started]
        let sung = singingTime(for: lineIndex < texts.count ? texts[lineIndex] : "")
        // the fill takes as long as the line is sung, never longer than the gap to the next line
        let fillTime = min(sung, (next ?? start + sung) - start)
        // after the fill, the line stays lit briefly; then a long gap is a melody break with nothing lit
        let holdUntil = start + max(fillTime + 1.5, min((next ?? .infinity) - start, fillTime + 1.5))
        if let next, next - start > fillTime + 3, songTime > holdUntil {
            return LyricPlayhead(index: nil, progress: 0, lastStarted: started)
        }
        let progress = (songTime - start) / max(fillTime, 0.001)
        return LyricPlayhead(index: started, progress: min(max(progress, 0), 1), lastStarted: started)
    }
}

#if DEBUG
enum LyricPlayheadSelfCheck {
    static func run() {
        let times: [Double?] = [10, 12, 15, 20]
        let texts = ["short", "a line of about twenty", "x", "y"]
        let a = LyricPlayhead.at(songTime: 13, elapsed: 3, duration: 10, selection: 0...2, times: times, texts: texts)
        assert(a.index == 1 && abs(a.progress - 0.5) < 0.01, "synced: fill follows the 2s singing time, not the 3s gap")
        let pre = LyricPlayhead.at(songTime: 9, elapsed: 0, duration: 10, selection: 0...2, times: times, texts: texts)
        assert(pre.index == nil, "nothing lit before the first line")
        // 4s line then a 30s melody break before the next line
        let gapTimes: [Double?] = [10, 40]
        let mid = LyricPlayhead.at(songTime: 25, elapsed: 15, duration: 30, selection: 0...1, times: gapTimes, texts: ["sing this", "next"])
        assert(mid.index == nil && mid.lastStarted == 0, "melody break: no line lit")
        let held = LyricPlayhead.at(songTime: 11.5, elapsed: 1.5, duration: 30, selection: 0...1, times: gapTimes, texts: ["sing this", "next"])
        assert(held.index == 0, "line stays lit while sung")
        let b = LyricPlayhead.at(songTime: 0, elapsed: 7.5, duration: 10, selection: 0...1, times: [nil, nil])
        assert(b.index == 1 && abs(b.progress - 0.5) < 0.001, "unsynced split")

        var style = LyricTextStyle()
        style.alignment = .center
        style.font = .didot
        style.color = Color(.sRGB, red: 1, green: 0.2, blue: 0.4, opacity: 1)
        style.effect = .shadow
        style.animation = .typewriter
        style.showWatermark = false
        let back = LyricTextStyle(rawValue: style.rawValue)
        assert(back?.rawValue == style.rawValue, "text style round-trip")
        assert(LyricTextStyle(rawValue: LyricTextStyle().rawValue)?.rawValue == LyricTextStyle().rawValue, "default round-trip")
        assert(LyricTextStyle(rawValue: "garbage") == nil, "rejects bad input")
        let legacy = LyricTextStyle(rawValue: "center|serif||glow")
        assert(legacy?.effect == .glow && legacy?.animation == .highlight && legacy?.showWatermark == true, "loads old 4-part string")

        // typewriter/words reveal counts
        assert(LyricCardView.revealCount(of: 10, progress: 0) == 0, "reveal start")
        assert(LyricCardView.revealCount(of: 10, progress: 0.4) == 5, "reveal mid (done at 80%)")
        assert(LyricCardView.revealCount(of: 10, progress: 1) == 10, "reveal end")

        // an instrumental break (empty LRC line) must not shift later lines onto earlier timestamps
        let withBreak = Lyrics(synced: [LyricLine(time: 1, text: "one"), LyricLine(time: 5, text: ""),
                                        LyricLine(time: 20, text: "two")])
        assert(withBreak.allLines == ["one", "two"] && withBreak.sungLines.map(\.time) == [1, 20], "lines and times stay paired")

        // lyric version closest to the Spotify length wins, even when it isn't first
        let picks = [LyricsService.LrcRecord(syncedLyrics: "[00:01]a", plainLyrics: nil, duration: 260),
                     LyricsService.LrcRecord(syncedLyrics: nil, plainLyrics: "a", duration: 231),
                     LyricsService.LrcRecord(syncedLyrics: "[00:02]a", plainLyrics: nil, duration: 232)]
        assert(LyricsService.bestMatch(picks, trackDuration: 231)?.duration == 232, "closest synced version")

        // widget schedule: 5s into a 12s song with lines at 0/4/9 → line 1 now, line 2 in 4s, end in 7s
        let now = Date()
        let song = NowPlaying(title: "", artist: "", lines: ["a", "b", "c"], times: [0, 4, 9],
                              songStart: now.addingTimeInterval(-5), duration: 12)
        let plan = song.schedule(from: now)
        assert(plan.map(\.line) == [1, 2, nil], "widget lines")
        assert(plan.map { Int($0.date.timeIntervalSince(now).rounded()) } == [0, 4, 7], "widget timing")
        var paused = song
        paused.songStart = nil
        assert(paused.schedule(from: now).map(\.line) == [nil], "paused shows no lyric")

        // 4s trim looped under a 10s video: 4 + 4 + 2
        let loop = VideoSource.loopSegments(trimStart: 2, trimEnd: 6, audioEnd: 20, total: 10)
        assert(loop.map(\.at) == [0, 4, 8] && loop.map(\.length) == [4, 4, 2] && loop.allSatisfy { $0.source == 2 }, "audio loop")
        // trim past the end of the audio track is clamped
        let clamped = VideoSource.loopSegments(trimStart: 0, trimEnd: 30, audioEnd: 5, total: 12)
        assert(clamped.map(\.length) == [5, 5, 2], "audio clamp")
    }
}
#endif
