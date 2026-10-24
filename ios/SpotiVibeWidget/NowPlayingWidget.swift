import SwiftUI
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let song: NowPlaying
    var line: Int? = nil
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry { NowPlayingEntry(date: .now, song: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(NowPlayingEntry(date: .now, song: NowPlaying.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // one entry per upcoming lyric line; the app reloads us on song change, pause or seek
        let song = NowPlaying.load() ?? .placeholder
        let entries = song.schedule(from: .now).map { NowPlayingEntry(date: $0.date, song: song, line: $0.line) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct NowPlayingView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) private var family

    private var art: some View {
        Group {
            if let data = entry.song.artwork, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.98, green: 0.18, blue: 0.44), Color(red: 0.98, green: 0.58, blue: 0.20)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "music.note").font(.title2).foregroundStyle(.white))
            }
        }
    }

    private var lyric: (current: String, next: String?)? {
        guard let i = entry.line, entry.song.lines.indices.contains(i) else { return nil }
        let next = entry.song.lines.indices.contains(i + 1) ? entry.song.lines[i + 1] : nil
        return (entry.song.lines[i], next)
    }

    var body: some View {
        if let lyric {
            lyricBody(lyric)
        } else {
            songBody
        }
    }

    private func lyricBody(_ lyric: (current: String, next: String?)) -> some View {
        let content = HStack(alignment: .top, spacing: 12) {
            if family == .systemMedium {
                art.frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.song.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(lyric.current)
                    .font(.system(size: family == .systemSmall ? 17 : 19, weight: .heavy))
                    .lineLimit(family == .systemSmall ? 4 : 3)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                if let next = lyric.next {
                    Text(next)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(family == .systemSmall ? 1 : 2)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .widgetURL(URL(string: "spotivibe://studio"))
        return background(content)
    }

    @ViewBuilder
    private func background(_ content: some View) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(Color(red: 0.07, green: 0.07, blue: 0.07), for: .widget)
        } else {
            content.padding().background(Color(red: 0.07, green: 0.07, blue: 0.07))
        }
    }

    private var songBody: some View {
        let content = HStack(spacing: 12) {
            if family == .systemMedium {
                art.frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                if family == .systemSmall {
                    art.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer(minLength: 0)
                }
                Text(entry.song.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
                Text(entry.song.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if family == .systemMedium { Spacer(minLength: 0) }
                Label("Make a card", systemImage: "quote.bubble.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.18, blue: 0.44))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .widgetURL(URL(string: "spotivibe://studio"))
        return background(content)
    }
}

@main
struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlaying", provider: NowPlayingProvider()) { entry in
            NowPlayingView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("The song you're playing with its lyrics, one tap from a lyric card.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
