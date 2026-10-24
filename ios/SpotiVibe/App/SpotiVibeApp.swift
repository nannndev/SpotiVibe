import SwiftUI

@main
struct SpotiVibeApp: App {
    init() {
        #if DEBUG
        LyricPlayheadSelfCheck.run()
        MainActor.assumeIsolated { CardHistorySelfCheck.run() }
        #endif
        // Dark theme navigation bar & appearance setup
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bg)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            LyricsShareView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
