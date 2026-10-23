import UIKit
import Photos

@MainActor
public class DirectShareService {
    public static let shared = DirectShareService()

    private init() {}

    /// Direct Share to Instagram Stories
    public func shareToInstagramStories(image: UIImage? = nil, videoURL: URL? = nil) -> Bool {
        guard let url = URL(string: "instagram-stories://share?source_application=io.github.spotivibe") else { return false }
        guard UIApplication.shared.canOpenURL(url) else {
            return false
        }

        var pasteboardItems: [String: Any] = [:]

        if let image = image, let imageData = image.pngData() {
            pasteboardItems["com.instagram.sharedSticker.backgroundImage"] = imageData
        } else if let videoURL = videoURL, let videoData = try? Data(contentsOf: videoURL) {
            pasteboardItems["com.instagram.sharedSticker.backgroundVideo"] = videoData
        } else {
            return false
        }

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(300)
        ]

        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    /// Saves image or video to Photos Camera Roll
    public func saveToPhotos(image: UIImage? = nil, videoURL: URL? = nil) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "SpotiVibe", code: 403, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied."])
        }

        try await PHPhotoLibrary.shared().performChanges {
            if let image = image {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } else if let videoURL = videoURL {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
        }
    }

    /// Copies image to system clipboard
    public func copyToClipboard(image: UIImage) {
        UIPasteboard.general.image = image
    }

    /// Presents standard iOS UIActivityViewController share sheet
    public func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        rootVC.present(activityVC, animated: true)
    }
}
