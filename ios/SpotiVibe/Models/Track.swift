import Foundation
import SwiftUI

public struct Track: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public let duration: Double // in seconds
    public let isPlaying: Bool
    public let progress: Double // current playback position in seconds

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String = "",
        artworkURL: URL? = nil,
        duration: Double = 210,
        isPlaying: Bool = false,
        progress: Double = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.isPlaying = isPlaying
        self.progress = progress
    }

    public static let sample = Track(
        id: "sample-1",
        title: "Shape of My Heart",
        artist: "Backstreet Boys",
        album: "Black & Blue",
        artworkURL: URL(string: "https://i.scdn.co/image/ab67616d0000b273cf871e6326e334bfa92cff20"),
        duration: 230,
        isPlaying: true,
        progress: 45
    )

    public static let sampleGoldenHour = Track(
        id: "sample-2",
        title: "golden hour",
        artist: "JVKE",
        album: "this is what ____ feels like (Vol. 1-4)",
        artworkURL: URL(string: "https://i.scdn.co/image/ab67616d0000b273c2504e80ba2f258697ab2954"),
        duration: 209,
        isPlaying: true,
        progress: 68
    )
}
