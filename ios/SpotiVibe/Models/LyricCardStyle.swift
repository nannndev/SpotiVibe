import Foundation
import SwiftUI

public enum LyricCardStyle: String, CaseIterable, Identifiable {
    case aura
    case player
    case vhs
    case cassette
    case vinyl
    case glass
    case polaroid
    case paper
    case receipt
    case solid

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .aura: return "Aura"
        case .player: return "Player"
        case .vhs: return "VHS 90s"
        case .cassette: return "Cassette"
        case .vinyl: return "Vinyl"
        case .glass: return "Glass"
        case .polaroid: return "Polaroid"
        case .paper: return "Paper"
        case .receipt: return "Receipt"
        case .solid: return "Solid"
        }
    }

    public var icon: String {
        switch self {
        case .aura: return "sparkles"
        case .player: return "play.circle.fill"
        case .vhs: return "video.badge.waveform"
        case .cassette: return "opticaldisc"
        case .vinyl: return "record.circle"
        case .glass: return "cube.transparent"
        case .polaroid: return "camera.fill"
        case .paper: return "doc.text.fill"
        case .receipt: return "newspaper.fill"
        case .solid: return "square.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .aura: return "Blurred ambient glow"
        case .player: return "Now Playing card"
        case .vhs: return "Camcorder retro vibes"
        case .cassette: return "Vintage cassette tape"
        case .vinyl: return "Spinning record album"
        case .glass: return "Frosted glassmorphism"
        case .polaroid: return "Vintage retro frame"
        case .paper: return "Editorial serif parchment"
        case .receipt: return "Archive printed receipt"
        case .solid: return "Vibrant album color"
        }
    }
}
