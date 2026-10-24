import UIKit
import UniformTypeIdentifiers

/// "Share to SpotiVibe" from Photos: copies the photo/video into the App Group, then opens the main app.
final class ShareViewController: UIViewController {
    static let appGroup = "group.com.naneps.spotivibe"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handOff() }
    }

    private func handOff() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier) })
                ?? providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
              let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
                .appendingPathComponent("Inbox", isDirectory: true)
        else { return finish(error: true) }

        let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        let type = isVideo ? UTType.movie : UTType.image

        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            let name = try await copy(provider, type: type, into: inbox)
            var components = URLComponents()
            components.scheme = "spotivibe"
            components.host = "import"
            components.queryItems = [
                URLQueryItem(name: "file", value: name),
                URLQueryItem(name: "kind", value: isVideo ? "video" : "image")
            ]
            if let url = components.url { openHostApp(url) }
            finish(error: false)
        } catch {
            finish(error: true)
        }
    }

    /// The provider's file is deleted when the callback returns, so copy it inside the callback.
    private func copy(_ provider: NSItemProvider, type: UTType, into dir: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                guard let url else { return cont.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
                let name = UUID().uuidString + "." + (url.pathExtension.isEmpty ? (type == .movie ? "mov" : "jpg") : url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(name))
                    cont.resume(returning: name)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Extensions can't call UIApplication.shared; reach it through the responder chain.
    private func openHostApp(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
    }

    private func finish(error: Bool) {
        if error {
            extensionContext?.cancelRequest(withError: CocoaError(.fileReadUnknown))
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
