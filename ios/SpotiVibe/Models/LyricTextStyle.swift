import SwiftUI

/// User overrides for how lyric lines look. `nil` / `.auto` keeps the card style's own look.
public struct LyricTextStyle: Equatable {
    public var alignment: TextAlignment? = nil
    public var font: LyricFont = .auto
    public var color: Color? = nil
    public var effect: LyricEffect = .none

    public init() {}
}

/// "align|font|#RRGGBBAA|effect" so it fits in @AppStorage; unknown parts fall back to defaults.
extension LyricTextStyle: RawRepresentable {
    public init?(rawValue: String) {
        let p = rawValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 4 else { return nil }
        alignment = ["leading": .leading, "center": .center, "trailing": .trailing][p[0]]
        font = LyricFont(rawValue: p[1]) ?? .auto
        color = Self.color(hex: p[2])
        effect = LyricEffect(rawValue: p[3]) ?? .none
    }

    public var rawValue: String {
        let align = alignment.map { $0 == .leading ? "leading" : ($0 == .center ? "center" : "trailing") } ?? ""
        return [align, font.rawValue, color.map(Self.hex) ?? "", effect.rawValue].joined(separator: "|")
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
    public var index: Int
    public var progress: Double

    /// `times` are song timestamps for every lyric line; `selection` indexes into them.
    public static func at(songTime: Double, elapsed: Double, duration: Double,
                          selection: ClosedRange<Int>, times: [Double?]) -> LyricPlayhead {
        let lines = Array(selection)
        let stamps = lines.map { $0 < times.count ? times[$0] : nil }

        guard stamps.contains(where: { $0 != nil }) else {
            // unsynced lyrics: split the video evenly across lines
            let slot = duration / Double(max(lines.count, 1))
            let pos = min(max(elapsed, 0), duration * 0.999)
            let idx = min(Int(pos / max(slot, 0.001)), max(lines.count - 1, 0))
            return LyricPlayhead(index: idx, progress: min(1, (pos - Double(idx) * slot) / max(slot, 0.001)))
        }

        var idx = 0
        for (i, t) in stamps.enumerated() { if let t, t <= songTime { idx = i } }
        let start = stamps[idx] ?? songTime
        // line ends where the next timed line starts (falls back to ~3.5s for the last line)
        let next = stamps.dropFirst(idx + 1).compactMap { $0 }.first
            ?? (selection.upperBound + 1 < times.count ? times[selection.upperBound + 1] : nil)
            ?? start + 3.5
        let progress = (songTime - start) / max(next - start, 0.001)
        return LyricPlayhead(index: idx, progress: min(max(progress, 0), 1))
    }
}

#if DEBUG
enum LyricPlayheadSelfCheck {
    static func run() {
        let times: [Double?] = [10, 12, 15, 20]
        let a = LyricPlayhead.at(songTime: 13.5, elapsed: 3.5, duration: 10, selection: 0...2, times: times)
        assert(a.index == 1 && abs(a.progress - 0.5) < 0.001, "synced midpoint")
        let b = LyricPlayhead.at(songTime: 0, elapsed: 7.5, duration: 10, selection: 0...1, times: [nil, nil])
        assert(b.index == 1 && abs(b.progress - 0.5) < 0.001, "unsynced split")

        var style = LyricTextStyle()
        style.alignment = .center
        style.font = .didot
        style.color = Color(.sRGB, red: 1, green: 0.2, blue: 0.4, opacity: 1)
        style.effect = .shadow
        let back = LyricTextStyle(rawValue: style.rawValue)
        assert(back?.rawValue == style.rawValue, "text style round-trip")
        assert(LyricTextStyle(rawValue: LyricTextStyle().rawValue)?.rawValue == LyricTextStyle().rawValue, "default round-trip")
        assert(LyricTextStyle(rawValue: "garbage") == nil, "rejects bad input")
    }
}
#endif
