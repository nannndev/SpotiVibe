import Foundation
import Combine

@MainActor
public class SpotifyPlayerService: ObservableObject {
    public static let shared = SpotifyPlayerService()

    @Published public var currentTrack: Track? = Track.sample
    @Published public var isPolling: Bool = false
    @Published public var lastSyncTime: Date = Date()
    @Published public var basePosition: Double = 45.0

    private var pollTimer: Timer?
    private var auth = SpotifyAuthService.shared

    private init() {
        startPolling()
    }

    public func startPolling() {
        stopPolling()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func poll() {
        guard let token = auth.accessToken, auth.isAuthenticated else {
            // In demo mode without token, keep sample track
            if currentTrack == nil {
                currentTrack = Track.sample
            }
            return
        }

        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    // Nothing currently playing, keep track or show paused
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let item = json["item"] as? [String: Any] {
                    let id = item["id"] as? String ?? UUID().uuidString
                    let title = item["name"] as? String ?? "Unknown"
                    let artists = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown"
                    let albumObj = item["album"] as? [String: Any]
                    let album = albumObj?["name"] as? String ?? ""
                    let images = albumObj?["images"] as? [[String: Any]]
                    let artURLStr = images?.first?["url"] as? String
                    let artURL = artURLStr.flatMap { URL(string: $0) }
                    let durationMs = item["duration_ms"] as? Double ?? 210000
                    let progressMs = json["progress_ms"] as? Double ?? 0
                    let isPlaying = json["is_playing"] as? Bool ?? false

                    let track = Track(
                        id: id,
                        title: title,
                        artist: artists,
                        album: album,
                        artworkURL: artURL,
                        duration: durationMs / 1000.0,
                        isPlaying: isPlaying,
                        progress: progressMs / 1000.0
                    )

                    self.currentTrack = track
                    self.basePosition = progressMs / 1000.0
                    self.lastSyncTime = Date()
                }
            } catch {
                // Ignore network errors or refresh token if 401
            }
        }
    }

    public func currentEstimatedPosition() -> Double {
        guard let track = currentTrack else { return 0 }
        if track.isPlaying {
            let elapsed = Date().timeIntervalSince(lastSyncTime)
            return min(track.duration, basePosition + elapsed)
        }
        return basePosition
    }
}
