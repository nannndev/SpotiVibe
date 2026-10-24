import SwiftUI
import WidgetKit

/// Written by the app (SpotifyPlayerService) into the App Group; the widget only reads it.
struct NowPlaying: Codable {
    var title: String
    var artist: String
    var artwork: Data?

    static let groupID = "group.com.naneps.spotivibe"
    static let key = "nowPlaying"
    static let placeholder = NowPlaying(title: "Play a song on Spotify", artist: "SpotiVibe", artwork: nil)

    static func load() -> NowPlaying? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NowPlaying.self, from: data)
    }
}

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let song: NowPlaying
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry { NowPlayingEntry(date: .now, song: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(NowPlayingEntry(date: .now, song: NowPlaying.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // the app reloads us when the song changes, so no scheduled refresh is needed
        completion(Timeline(entries: [NowPlayingEntry(date: .now, song: NowPlaying.load() ?? .placeholder)], policy: .never))
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

    var body: some View {
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

        if #available(iOS 17.0, *) {
            content.containerBackground(Color(red: 0.07, green: 0.07, blue: 0.07), for: .widget)
        } else {
            content.padding().background(Color(red: 0.07, green: 0.07, blue: 0.07))
        }
    }
}

@main
struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlaying", provider: NowPlayingProvider()) { entry in
            NowPlayingView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("The song you're playing, one tap from a lyric card.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
