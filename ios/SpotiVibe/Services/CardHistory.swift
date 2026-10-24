import Foundation
import UIKit

/// A card the user shared, saved or exported; enough to reopen it in the studio.
struct CardRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var duration: Double
    var lineStart: Int
    var lineEnd: Int
    var style: String
    var ratio: String
    var text: String // LyricTextStyle.rawValue
    var isFavorite = false

    var track: Track {
        Track(id: trackID, title: title, artist: artist, album: album, artworkURL: artworkURL, duration: duration)
    }
}

/// Recent cards, stored as JSON + JPEG thumbnails in Documents/History.
@MainActor
final class CardHistory: ObservableObject {
    static let shared = CardHistory()
    private static let limit = 60 // favorites are never trimmed

    @Published private(set) var records: [CardRecord] = []
    private let dir: URL

    init(directory: URL? = nil) {
        dir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("History", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL) {
            records = (try? JSONDecoder().decode([CardRecord].self, from: data)) ?? []
        }
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    func thumbnailURL(for id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).jpg") }

    func add(_ record: CardRecord, thumbnail: UIImage?) {
        // same song + lines + look replaces the older entry instead of duplicating it
        var record = record
        if let old = records.firstIndex(where: { $0.sameCard(as: record) }) {
            record.isFavorite = records[old].isFavorite
            remove(records[old])
        }
        if let data = thumbnail?.preparingThumbnail(of: CGSize(width: 270, height: 480))?.jpegData(compressionQuality: 0.8) {
            try? data.write(to: thumbnailURL(for: record.id))
        }
        records.insert(record, at: 0)

        // drop the oldest non-favorites beyond the limit
        while records.count > Self.limit, let last = records.lastIndex(where: { !$0.isFavorite }) {
            remove(records[last])
        }
        save()
    }

    func toggleFavorite(_ record: CardRecord) {
        guard let i = records.firstIndex(of: record) else { return }
        records[i].isFavorite.toggle()
        save()
    }

    func delete(_ record: CardRecord) {
        remove(record)
        save()
    }

    private func remove(_ record: CardRecord) {
        try? FileManager.default.removeItem(at: thumbnailURL(for: record.id))
        records.removeAll { $0.id == record.id }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

private extension CardRecord {
    func sameCard(as other: CardRecord) -> Bool {
        trackID == other.trackID && lineStart == other.lineStart && lineEnd == other.lineEnd
            && style == other.style && ratio == other.ratio && text == other.text
    }
}

#if DEBUG
enum CardHistorySelfCheck {
    @MainActor static func run() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("history-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let rec = { (line: Int) in
            CardRecord(trackID: "t", title: "T", artist: "A", album: "", artworkURL: nil, duration: 200,
                       lineStart: line, lineEnd: line + 1, style: "aura", ratio: "9:16", text: "")
        }
        let h = CardHistory(directory: dir)
        h.add(rec(0), thumbnail: nil)
        h.add(rec(0), thumbnail: nil)
        assert(h.records.count == 1, "same card is not duplicated")
        h.toggleFavorite(h.records[0])
        for i in 1...70 { h.add(rec(i), thumbnail: nil) }
        assert(h.records.count == 60, "history is capped")
        assert(h.records.contains { $0.lineStart == 0 && $0.isFavorite }, "favorite survives the cap")
        assert(CardHistory(directory: dir).records.count == 60, "persists to disk")
    }
}
#endif
