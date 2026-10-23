import Foundation
import CoreGraphics

public enum CardAspectRatio: String, CaseIterable, Identifiable {
    case story = "9:16"
    case portrait = "4:5"
    case square = "1:1"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .story: return "9:16 Story"
        case .portrait: return "4:5 Post"
        case .square: return "1:1 Square"
        }
    }

    public var size: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)
        case .portrait: return CGSize(width: 360, height: 450)
        case .square: return CGSize(width: 360, height: 360)
        }
    }

    public var exportPixelSize: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}
