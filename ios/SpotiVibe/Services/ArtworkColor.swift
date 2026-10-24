import CoreImage
import SwiftUI
import UIKit

/// Picks an accent color from album art so each song's card gets its own tint.
enum ArtworkColor {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// Average color of the image, pushed to a usable accent (dark/grey covers would otherwise give mud).
    static func accent(of image: UIImage) -> Color? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: input,
                  kCIInputExtentKey: CIVector(cgRect: input.extent)
              ]),
              let output = filter.outputImage
        else { return nil }

        var px = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255, alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: max(s, 0.45), brightness: max(b, 0.75))
    }
}
