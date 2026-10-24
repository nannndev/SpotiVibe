import Foundation
import UIKit
import WidgetKit

/// Hands the current song to the Now Playing widget through the shared App Group.
enum WidgetBridge {
    private static let groupID = "group.com.naneps.spotivibe"

    /// Same shape as `NowPlaying` in the widget target.
    private struct Payload: Codable {
        var title: String
        var artist: String
        var artwork: Data?
    }

    static func publish(_ track: Track) {
        Task.detached(priority: .utility) {
            var art: Data?
            if let url = track.artworkURL, let (data, _) = try? await URLSession.shared.data(from: url) {
                // widgets have a tight memory limit; keep the image small
                art = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 220, height: 220))?.jpegData(compressionQuality: 0.85)
            }
            let payload = Payload(title: track.title, artist: track.artist, artwork: art)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            UserDefaults(suiteName: groupID)?.set(data, forKey: "nowPlaying")
            WidgetCenter.shared.reloadTimelines(ofKind: "NowPlaying")
        }
    }
}
