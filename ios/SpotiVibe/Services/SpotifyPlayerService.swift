import Foundation
import Combine

@MainActor
public class SpotifyPlayerService: ObservableObject {
    public static let shared = SpotifyPlayerService()

    @Published public var currentTrack: Track? = Track.sample
    @Published public var isPolling: Bool = false
    @Published public var lastSyncTime: Date = Date()
    @Published public var basePosition: Double = 45.0
    /// True while the user picked a song via search; polling then stops overriding it.
    @Published public var isPinned: Bool = false

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
        guard !isPinned else { return }
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
                if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    // token expired (~1h); refresh so the next poll keeps following Spotify
                    await auth.refreshAccessToken()
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    // Nothing currently playing, keep track or show paused
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let item = json["item"] as? [String: Any],
                   !self.isPinned {
                    let progressMs = json["progress_ms"] as? Double ?? 0
                    let track = Self.parseTrack(item, isPlaying: json["is_playing"] as? Bool ?? false, progress: progressMs / 1000.0)
                    self.currentTrack = track
                    self.basePosition = progressMs / 1000.0
                    self.lastSyncTime = Date()
                }
            } catch {
                // Ignore network errors or refresh token if 401
            }
        }
    }

    /// Use a searched song instead of whatever Spotify is playing.
    public func pin(_ track: Track) {
        isPinned = true
        currentTrack = track
        basePosition = 0
        lastSyncTime = Date()
    }

    public func unpin() {
        isPinned = false
        poll()
    }

    /// Starts the track on the user's active Spotify device. Needs Premium + an active device.
    public func play(_ track: Track) async throws {
        guard let token = auth.accessToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            throw URLError(.userAuthenticationRequired)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["uris": ["spotify:track:\(track.id)"]])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        if http.statusCode == 401 { await auth.refreshAccessToken() }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(http.statusCode)"
        throw NSError(domain: "SpotifyPlay", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }

    public func search(_ query: String) async throws -> [Track] {
        guard let token = auth.accessToken else { return [] }
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "10") // dev-mode apps reject larger limits
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            await auth.refreshAccessToken()
            throw URLError(.userAuthenticationRequired)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (json?["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "SpotifySearch", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Spotify: \(message) (\(http.statusCode))"])
        }
        let items = (json?["tracks"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
        return items.map { Self.parseTrack($0, isPlaying: false, progress: 0) }
    }

    private static func parseTrack(_ item: [String: Any], isPlaying: Bool, progress: Double) -> Track {
        let albumObj = item["album"] as? [String: Any]
        let images = albumObj?["images"] as? [[String: Any]]
        return Track(
            id: item["id"] as? String ?? UUID().uuidString,
            title: item["name"] as? String ?? "Unknown",
            artist: (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown",
            album: albumObj?["name"] as? String ?? "",
            artworkURL: (images?.first?["url"] as? String).flatMap { URL(string: $0) },
            duration: (item["duration_ms"] as? Double ?? 210000) / 1000.0,
            isPlaying: isPlaying,
            progress: progress
        )
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
