import SwiftUI
import PhotosUI
import Combine

public struct LyricsShareView: View {
    @ObservedObject var player = SpotifyPlayerService.shared
    @ObservedObject var lyricsService = LyricsService.shared
    @ObservedObject var auth = SpotifyAuthService.shared

    // Studio Settings
    @State private var mode: ShareMode = .photo
    @State private var style: LyricCardStyle = .aura
    @State private var aspectRatio: CardAspectRatio = .story
    @State private var selection: ClosedRange<Int> = 0...2

    // Media Customization
    @State private var customBackdrop: UIImage? = nil
    @State private var customCover: UIImage? = nil
    @State private var backdropBlur: Double = 14
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoTarget: PhotoTarget = .backdrop

    // Video Playback & Timeline
    @State private var isPlaying = true
    @State private var previewElapsed: Double = 0
    @State private var duration: Double = 15
    @State private var isRendering = false
    @State private var renderProgress: Double = 0

    // Sheets & Toasts
    @State private var showLinePickerSheet = false
    @State private var showSettingsSheet = false
    @State private var toastMessage: String? = nil

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    enum ShareMode: String, CaseIterable, Identifiable {
        case photo = "Photo"
        case video = "Video"
        var id: String { rawValue }
    }

    enum PhotoTarget {
        case cover, backdrop
    }

    public init() {}

    private var currentTrack: Track {
        player.currentTrack ?? Track.sample
    }

    private var lines: [String] {
        let all = lyricsService.lyrics?.allLines ?? Lyrics.sample.allLines
        return all.isEmpty ? Lyrics.sample.allLines : all
    }

    private var times: [Double?] {
        if let synced = lyricsService.lyrics?.synced, !synced.isEmpty {
            return synced.map { $0.time }
        }
        return Array(repeating: nil, count: lines.count)
    }

    private var chosenLines: [String] {
        let safeLower = max(0, min(selection.lowerBound, lines.count - 1))
        let safeUpper = max(safeLower, min(selection.upperBound, lines.count - 1))
        guard !lines.isEmpty, safeLower <= safeUpper else { return ["Shape of My Heart"] }
        return Array(lines[safeLower...safeUpper])
    }

    private var songStartTime: Double {
        let safeLower = max(0, min(selection.lowerBound, times.count - 1))
        return times.indices.contains(safeLower) ? (times[safeLower] ?? 0) : 0
    }

    private var activeLineOffset: Int {
        guard mode == .video else { return 0 }
        let currentSongTime = songStartTime + previewElapsed
        var best = 0
        var foundAny = false

        for (idx, lineIndex) in Array(selection).enumerated() {
            if lineIndex < times.count, let t = times[lineIndex] {
                foundAny = true
                if t <= currentSongTime { best = idx }
            }
        }

        if !foundAny && !selection.isEmpty && duration > 0 {
            let progress = min(max(previewElapsed / duration, 0), 0.999)
            best = Int(progress * Double(selection.count))
        }
        return best
    }

    private var previewScale: CGFloat {
        switch aspectRatio {
        case .story: return 0.72
        case .portrait: return 0.85
        case .square: return 0.92
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                VStack(spacing: 8) {
                    // Top Bar: Track Meta & Spotify Connect Badge
                    trackHeaderBar

                    // Mode & Aspect Ratio Switchers
                    toolbarRow

                    // Live Card Preview Area
                    cardPreviewSection
                        .frame(maxHeight: .infinity)

                    // Bottom Controls & Action Bar
                    bottomControlsDeck
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.pink)
                            .font(.system(size: 14, weight: .bold))
                        Text("SpotiVibe")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(auth.isAuthenticated ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(auth.isAuthenticated ? "Connected" : "Connect")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                }
            }
            .sheet(isPresented: $showLinePickerSheet) {
                linePickerSheet
            }
            .sheet(isPresented: $showSettingsSheet) {
                spotifySettingsSheet
            }
            .photosPicker(isPresented: .init(get: { selectedPhotoItem != nil }, set: { if !$0 { selectedPhotoItem = nil } }), selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        if photoTarget == .cover {
                            customCover = uiImage
                            showToast("Custom cover art applied!")
                        } else {
                            customBackdrop = uiImage
                            showToast("Custom background applied!")
                        }
                    }
                }
            }
            .onReceive(timer) { _ in
                guard mode == .video, isPlaying, !isRendering else { return }
                previewElapsed += 1.0 / 30.0
                if previewElapsed >= duration {
                    previewElapsed = 0
                }
            }
            .task {
                await lyricsService.fetchLyrics(for: currentTrack)
            }
            .onChange(of: currentTrack) { newTrack in
                Task {
                    await lyricsService.fetchLyrics(for: newTrack)
                }
            }
        }
    }

    // MARK: - Track Header Bar
    private var trackHeaderBar: some View {
        HStack(spacing: 12) {
            Group {
                if let custom = customCover {
                    Image(uiImage: custom).resizable().scaledToFill()
                } else if let url = currentTrack.artworkURL {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() }
                        else { Rectangle().fill(Color.white.opacity(0.1)) }
                    }
                } else {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(currentTrack.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(currentTrack.artist)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showLinePickerSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                    Text("\(selection.count) Lines")
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.pink.opacity(0.2)))
                .overlay(Capsule().stroke(Color.pink.opacity(0.4), lineWidth: 1))
                .foregroundStyle(.white)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Toolbar Row (Photo/Video & Aspect Ratio)
    private var toolbarRow: some View {
        HStack {
            // Mode Pills
            HStack(spacing: 2) {
                ForEach(ShareMode.allCases) { m in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { mode = m }
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(mode == m ? Color.pink : Color.clear))
                            .foregroundStyle(mode == m ? .white : .secondary)
                    }
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.08)))

            Spacer()

            // Ratio Pills
            HStack(spacing: 2) {
                ForEach(CardAspectRatio.allCases) { r in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { aspectRatio = r }
                    } label: {
                        Text(r.label)
                            .font(.system(size: 11, weight: aspectRatio == r ? .bold : .medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(aspectRatio == r ? Color.white.opacity(0.2) : Color.clear))
                            .foregroundStyle(aspectRatio == r ? .white : .secondary)
                    }
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    // MARK: - Card Preview Section
    private var cardPreviewSection: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            LyricCardView(
                track: currentTrack,
                lines: chosenLines,
                times: times,
                aspectRatio: aspectRatio,
                time: songStartTime + previewElapsed,
                duration: duration,
                elapsed: previewElapsed,
                activeLineIndex: mode == .video ? activeLineOffset : nil,
                style: style,
                backdropImage: customBackdrop,
                backdropBlur: backdropBlur,
                customArtwork: customCover
            )
            .scaleEffect(previewScale)
            .frame(width: aspectRatio.size.width * previewScale, height: aspectRatio.size.height * previewScale)
            .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
            .overlay {
                if isRendering {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.85))
                        VStack(spacing: 12) {
                            ProgressView(value: renderProgress, total: 1.0)
                                .tint(.pink)
                                .frame(width: 180)
                            Text("Rendering Video: \(Int(renderProgress * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
                    Text(toast)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.black.opacity(0.9)))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }

            // Video Scrubber Bar
            if mode == .video {
                HStack(spacing: 10) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }

                    Text(formatTime(previewElapsed))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32)

                    Slider(value: $previewElapsed, in: 0...duration)
                        .tint(.pink)

                    Text(formatTime(duration))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .frame(maxWidth: 320)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom Controls Deck
    private var bottomControlsDeck: some View {
        VStack(spacing: 10) {
            // Style Selector Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LyricCardStyle.allCases) { s in
                        let isSelected = style == s
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { style = s }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: s.icon)
                                    .font(.system(size: 11, weight: .bold))
                                Text(s.name)
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isSelected ? Color.pink : Color.white.opacity(0.08)))
                            .foregroundStyle(isSelected ? .white : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Context controls (Photo / Video specifics)
            HStack(spacing: 10) {
                if mode == .video {
                    HStack(spacing: 5) {
                        Text("Duration:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach([10.0, 15.0, 30.0], id: \.self) { d in
                            Button {
                                duration = d
                                if previewElapsed > d { previewElapsed = 0 }
                            } label: {
                                Text("\(Int(d))s")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(duration == d ? Color.pink : Color.white.opacity(0.1)))
                                    .foregroundStyle(duration == d ? .white : .secondary)
                            }
                        }
                    }
                } else {
                    Menu {
                        Button("Choose Custom Cover") {
                            photoTarget = .cover
                            selectedPhotoItem = nil
                        }
                        Button("Choose Custom Background") {
                            photoTarget = .backdrop
                            selectedPhotoItem = nil
                        }
                        if customCover != nil {
                            Button("Reset Cover") { customCover = nil }
                        }
                        if customBackdrop != nil {
                            Button("Reset Background") { customBackdrop = nil }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                            Text("Media")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                        .foregroundStyle(.white)
                    }
                }

                Spacer()

                if customBackdrop != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.halffull").font(.system(size: 10)).foregroundStyle(.secondary)
                        Slider(value: $backdropBlur, in: 0...40)
                            .frame(width: 70)
                            .tint(.pink)
                    }
                }
            }

            // Action Buttons Bar
            HStack(spacing: 8) {
                if mode == .photo {
                    // Instagram Stories Direct Share
                    Button {
                        shareToInstagram()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.circle.fill")
                            Text("Stories")
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [Color(red: 0.98, green: 0.18, blue: 0.44), Color(red: 0.98, green: 0.58, blue: 0.20)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }

                    // Save Image
                    Button {
                        saveImage()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.system(size: 12.5, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    // System Share
                    Button {
                        presentSystemShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .padding(10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                } else {
                    // Export Video Button
                    Button {
                        exportVideo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRendering ? "hourglass" : "film.fill")
                            Text(isRendering ? "Rendering Video…" : "Export Video (MP4)")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .disabled(isRendering)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Actions (Render, Export, Share)
    @MainActor
    private func renderCardImage() -> UIImage? {
        let size = aspectRatio.size
        let view = LyricCardView(
            track: currentTrack,
            lines: chosenLines,
            times: times,
            aspectRatio: aspectRatio,
            time: songStartTime + previewElapsed,
            duration: duration,
            elapsed: previewElapsed,
            activeLineIndex: nil,
            style: style,
            backdropImage: customBackdrop,
            backdropBlur: backdropBlur,
            customArtwork: customCover
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1080.0 / size.width
        return renderer.uiImage
    }

    private func shareToInstagram() {
        guard let img = renderCardImage() else { return }
        let success = DirectShareService.shared.shareToInstagramStories(image: img)
        if !success {
            DirectShareService.shared.copyToClipboard(image: img)
            showToast("Instagram not found; copied to clipboard!")
        }
    }

    private func saveImage() {
        guard let img = renderCardImage() else { return }
        Task {
            do {
                try await DirectShareService.shared.saveToPhotos(image: img)
                showToast("Saved to Camera Roll!")
            } catch {
                showToast("Failed to save: \(error.localizedDescription)")
            }
        }
    }

    private func presentSystemShare() {
        guard let img = renderCardImage() else { return }
        DirectShareService.shared.presentShareSheet(items: [img])
    }

    private func exportVideo() {
        isRendering = true
        renderProgress = 0

        let size = aspectRatio.size
        let totalDur = duration
        let snapTrack = currentTrack
        let snapLines = chosenLines
        let snapTimes = times
        let snapStyle = style
        let snapRatio = aspectRatio
        let snapBg = customBackdrop
        let snapBlur = backdropBlur
        let snapCover = customCover
        let startSongTime = songStartTime
        let snapSelection = selection

        Task { @MainActor in
            do {
                let url = try await LyricVideoGenerator.renderVideo(
                    duration: totalDur,
                    fps: 30,
                    size: size,
                    scale: 3.0,
                    frameBuilder: { elapsed in
                        let currentSongTime = startSongTime + elapsed
                        var activeIdx = 0
                        var foundAny = false
                        for (idx, lineIndex) in Array(snapSelection).enumerated() {
                            if lineIndex < snapTimes.count, let t = snapTimes[lineIndex] {
                                foundAny = true
                                if t <= currentSongTime { activeIdx = idx }
                            }
                        }
                        if !foundAny && !snapSelection.isEmpty && totalDur > 0 {
                            let prog = min(max(elapsed / totalDur, 0), 0.999)
                            activeIdx = Int(prog * Double(snapSelection.count))
                        }

                        return AnyView(
                            LyricCardView(
                                track: snapTrack,
                                lines: snapLines,
                                times: snapTimes,
                                aspectRatio: snapRatio,
                                time: currentSongTime,
                                duration: totalDur,
                                elapsed: elapsed,
                                activeLineIndex: activeIdx,
                                style: snapStyle,
                                backdropImage: snapBg,
                                backdropBlur: snapBlur,
                                customArtwork: snapCover
                            )
                        )
                    },
                    onProgress: { p in
                        self.renderProgress = p
                    }
                )

                self.isRendering = false
                try? await DirectShareService.shared.saveToPhotos(videoURL: url)
                self.showToast("Video saved to Camera Roll!")
                DirectShareService.shared.presentShareSheet(items: [url])
            } catch {
                self.isRendering = false
                self.showToast("Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toastMessage = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }

    private func formatTime(_ sec: Double) -> String {
        let s = max(0, Int(sec))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Line Picker Sheet
    private var linePickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select 1–8 consecutive lines to feature on your lyric card.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let isSelected = selection.contains(index)
                        Button {
                            toggleLine(index)
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.pink : Color.secondary)
                                Text(line)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showLinePickerSheet = false }
                }
            }
        }
    }

    private func toggleLine(_ index: Int) {
        if selection.count > 1, index == selection.lowerBound {
            selection = (index + 1)...selection.upperBound
            return
        }
        if selection.count > 1, index == selection.upperBound {
            selection = selection.lowerBound...(index - 1)
            return
        }
        if selection.contains(index) {
            selection = selection.lowerBound...index
            return
        }
        let stretched = min(index, selection.lowerBound)...max(index, selection.upperBound)
        selection = stretched.count <= 8 ? stretched : index...index

        // Auto update duration
        if selection.lowerBound < times.count, selection.upperBound < times.count,
           let start = times[selection.lowerBound], let end = times[selection.upperBound] {
            duration = max(5.0, min(30.0, (end - start) + 3.5))
        }
    }

    // MARK: - Spotify Settings Sheet
    private var spotifySettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Spotify Status") {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundStyle(.green)
                        Text(auth.isAuthenticated ? "Connected to Spotify" : "Demo Mode (Not Connected)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    if auth.isAuthenticated {
                        Button("Log Out", role: .destructive) {
                            auth.logout()
                        }
                    } else {
                        Button {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let win = scene.windows.first {
                                auth.authorize(from: win)
                            }
                        } label: {
                            Text("Connect Spotify Account")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.green)
                        }
                    }
                }

                Section("About SpotiVibe") {
                    Text("SpotiVibe generates Spotify & TikTok style aesthetic lyric cards and animated MP4 videos for Instagram Stories, TikTok, and WhatsApp.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Spotify Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { showSettingsSheet = false }
                }
            }
        }
    }
}
