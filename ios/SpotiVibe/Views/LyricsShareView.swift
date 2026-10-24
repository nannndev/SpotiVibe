import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

public struct LyricsShareView: View {
    @ObservedObject var player = SpotifyPlayerService.shared
    @ObservedObject var lyricsService = LyricsService.shared
    @ObservedObject var auth = SpotifyAuthService.shared
    @Environment(\.scenePhase) private var scenePhase

    // Studio Settings
    // remembered between launches
    @AppStorage("studio.mode") private var mode: ShareMode = .photo
    @AppStorage("studio.style") private var style: LyricCardStyle = .aura
    @AppStorage("studio.ratio") private var aspectRatio: CardAspectRatio = .story
    @State private var selection: ClosedRange<Int> = 0...2

    // Media Customization
    @State private var customBackdrop: UIImage? = nil
    @State private var customCover: UIImage? = nil
    @AppStorage("studio.blur") private var backdropBlur: Double = 14
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoTarget: PhotoTarget = .backdrop
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    // video-mode media: thumbnails live in customCover/customBackdrop, frames below track the timeline
    @State private var coverVideo: VideoSource? = nil
    @State private var backdropVideo: VideoSource? = nil
    @State private var coverFrame: UIImage? = nil
    @State private var backdropFrame: UIImage? = nil
    @State private var deckExpanded = true
    @AppStorage("studio.text") private var textStyle = LyricTextStyle()
    @State private var deckTab: DeckTab = .style

    enum DeckTab: String, CaseIterable { case style = "Style", text = "Text" }
    @GestureState private var deckDrag: CGFloat = 0

    // Video Playback & Timeline
    @State private var isPlaying = true
    @State private var previewElapsed: Double = 0
    @AppStorage("studio.duration") private var duration: Double = 15
    @State private var isRendering = false
    @State private var renderProgress: Double = 0

    // Sheets & Toasts
    @State private var showLinePickerSheet = false
    @State private var showSettingsSheet = false
    @State private var showSearchSheet = false
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

    private var playhead: LyricPlayhead {
        LyricPlayhead.at(songTime: songStartTime + previewElapsed, elapsed: previewElapsed,
                         duration: duration, selection: selection, times: times)
    }

    /// Largest scale that fits the card into the space the preview area actually has.
    private func previewScale(in space: CGSize) -> CGFloat {
        let size = aspectRatio.size
        return max(0.1, min(space.width / size.width, space.height / size.height, 1))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg
                    // Spotify-style ambient glow pulled from the artwork; in overlay so it never affects layout width
                    .overlay(alignment: .top) {
                        artworkView
                            .frame(width: 520, height: 520)
                            .blur(radius: 90)
                            .opacity(0.45)
                            .offset(y: -260)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    appBar

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
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLinePickerSheet) {
                linePickerSheet
            }
            .sheet(isPresented: $showSearchSheet) {
                TrackSearchSheet(isConnected: auth.isAuthenticated) { track in
                    player.pin(track)
                    showSearchSheet = false
                    playOnSpotify(track)
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                spotifySettingsSheet
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem,
                          matching: mode == .video ? .any(of: [.images, .videos]) : .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(allowsVideo: mode == .video, onImage: { applyMedia($0) }, onVideo: { applyVideo($0) })
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if newItem.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        if let movie = try? await newItem.loadTransferable(type: PickedMovie.self) {
                            applyVideo(movie.url)
                        } else {
                            showToast("Couldn't load that video")
                        }
                    } else if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        applyMedia(uiImage)
                    } else {
                        showToast("Couldn't load that photo")
                    }
                    // reset so picking the same photo again still triggers onChange
                    selectedPhotoItem = nil
                }
            }
            .onReceive(timer) { _ in
                guard mode == .video, !isRendering else {
                    backdropVideo?.pause(); coverVideo?.pause()
                    return
                }
                if isPlaying {
                    previewElapsed += 1.0 / 30.0
                    if previewElapsed >= duration {
                        previewElapsed = 0
                    }
                }
                // runs while paused too, so scrubbing updates the clip frame
                backdropFrame = backdropVideo?.previewFrame(at: previewElapsed, playing: isPlaying)
                coverFrame = coverVideo?.previewFrame(at: previewElapsed, playing: isPlaying)
            }
            .task {
                await lyricsService.fetchLyrics(for: currentTrack)
            }
            .onOpenURL { url in
                importShared(url)
            }
            .onChange(of: scenePhase) { phase in
                // catch up immediately when returning from the Spotify app
                if phase == .active { player.poll() }
            }
            .onChange(of: currentTrack.id) { _ in
                // new song: old line range / custom cover belong to the previous track
                selection = 0...2
                previewElapsed = 0
                customCover = nil
                coverVideo = nil
                coverFrame = nil
                let newTrack = currentTrack
                Task {
                    await lyricsService.fetchLyrics(for: newTrack)
                }
            }
        }
    }

    // MARK: - App Bar
    private var appBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble.fill")
                .foregroundStyle(Theme.brand)
                .font(.system(size: 20, weight: .bold))
            Text("SpotiVibe")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(.white)
            Spacer()
            Button {
                showSettingsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(auth.isAuthenticated ? Theme.online : Theme.textSecondary)
                        .frame(width: 8, height: 8)
                    Text(auth.isAuthenticated ? "Connected" : "Connect")
                }
                .chip(selected: false)
            }
            .accessibilityLabel(auth.isAuthenticated ? "Spotify connected, open settings" : "Connect Spotify")
        }
        .padding(.top, 4)
    }

    // MARK: - Track Header Bar
    private var artworkView: some View {
        Group {
            if let custom = customCover {
                Image(uiImage: custom).resizable().scaledToFill()
            } else if let url = currentTrack.artworkURL {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { Theme.elevated }
                }
            } else {
                Theme.elevated
            }
        }
    }

    private var trackHeaderBar: some View {
        HStack(spacing: 12) {
            Button {
                showSearchSheet = true
            } label: {
                HStack(spacing: 12) {
                    artworkView
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentTrack.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if player.isPinned {
                                Image(systemName: "pin.fill").foregroundStyle(Theme.accent)
                            } else if auth.isAuthenticated {
                                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Theme.online)
                            }
                            Text(currentTrack.artist)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .accessibilityLabel("\(currentTrack.title) by \(currentTrack.artist). Change song")

            Spacer()

            if player.isPinned {
                Button {
                    player.unpin()
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().stroke(Theme.outline, lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Back to Now Playing")
            }

            Button {
                showLinePickerSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "text.quote")
                    Text("\(selection.count) lines")
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().stroke(Theme.outline, lineWidth: 1))
                .foregroundStyle(.white)
            }
            .accessibilityLabel("Choose lyric lines, \(selection.count) selected")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Toolbar Row (Photo/Video & Aspect Ratio)
    private var toolbarRow: some View {
        HStack(spacing: 8) {
            ForEach(ShareMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { mode = m }
                } label: {
                    Label(m.rawValue, systemImage: m == .photo ? "photo" : "play.rectangle")
                        .chip(selected: mode == m)
                }
            }

            Spacer()

            Menu {
                Picker("Aspect Ratio", selection: $aspectRatio.animation(.spring(response: 0.25, dampingFraction: 0.75))) {
                    ForEach(CardAspectRatio.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                    Text(aspectRatio.label)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .chip(selected: false)
            }
            .accessibilityLabel("Aspect ratio \(aspectRatio.label)")
        }
    }

    // MARK: - Card Preview Section
    private var cardPreviewSection: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let scale = previewScale(in: geo.size)
                    LyricCardView(
                        track: currentTrack,
                        lines: chosenLines,
                        times: times,
                        aspectRatio: aspectRatio,
                        time: songStartTime + previewElapsed,
                        duration: duration,
                        elapsed: previewElapsed,
                        activeLineIndex: mode == .video ? playhead.index : nil,
                        lineProgress: playhead.progress,
                        textStyle: textStyle,
                        style: style,
                        backdropImage: mode == .video ? (backdropFrame ?? customBackdrop) : customBackdrop,
                        backdropBlur: backdropBlur,
                        customArtwork: mode == .video ? (coverFrame ?? customCover) : customCover
                    )
                    .scaleEffect(scale)
                    .frame(width: aspectRatio.size.width * scale, height: aspectRatio.size.height * scale)
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
                    .overlay {
                        if isRendering {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.85))
                                VStack(spacing: 12) {
                                    ProgressView(value: renderProgress, total: 1.0)
                                        .tint(Theme.accent)
                                        .frame(width: 180)
                                    Text("Rendering \(Int(renderProgress * 100))%")
                                        .font(.system(size: 14, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if let toast = toastMessage {
                            Text(toast)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                                .foregroundStyle(.black)
                                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Video Scrubber Bar
            if mode == .video {
                HStack(spacing: 12) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white))
                    }
                    .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")

                    VStack(spacing: 2) {
                        Slider(value: $previewElapsed, in: 0...duration)
                            .tint(.white)
                        HStack {
                            Text(formatTime(previewElapsed))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: 340)
            }
        }
    }

    // MARK: - Bottom Controls Deck
    private var bottomControlsDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            deckHandle

            if deckExpanded {
                deckOptions
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        // follow the finger a little (rubber-banded), then snap
        .offset(y: deckExpanded ? max(0, deckDrag) * 0.5 : min(0, deckDrag) * 0.3)
        .gesture(
            DragGesture(minimumDistance: 10)
                .updating($deckDrag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let dy = value.predictedEndTranslation.height
                    if dy > 60 { setDeck(expanded: false) } else if dy < -60 { setDeck(expanded: true) }
                }
        )
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: deckDrag)
    }

    private func setDeck(expanded: Bool) {
        guard expanded != deckExpanded else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { deckExpanded = expanded }
    }

    private var deckHandle: some View {
        Button {
            setDeck(expanded: !deckExpanded)
        } label: {
            VStack(spacing: 6) {
                Capsule()
                    .fill(Theme.outline)
                    .frame(width: 36, height: 5)
                if !deckExpanded {
                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                        Text(style.name)
                        Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(deckExpanded ? "Hide controls" : "Show controls")
    }

    private var deckOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ForEach(DeckTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { deckTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(deckTab == tab ? .white : Theme.textSecondary)
                            .padding(.bottom, 4)
                            .overlay(alignment: .bottom) {
                                if deckTab == tab { Capsule().fill(Theme.brand).frame(height: 3) }
                            }
                    }
                    .accessibilityAddTraits(deckTab == tab ? .isSelected : [])
                }
            }

            if deckTab == .text {
                textControls
            } else {
                styleControls
            }
        }
    }

    // MARK: - Text Controls
    private static let swatches: [Color] = [
        .white, Color(red: 1, green: 0.84, blue: 0.2), Theme.accent, Theme.accentEnd,
        Color(red: 0.3, green: 0.9, blue: 0.6), Color(red: 0.35, green: 0.75, blue: 1),
        Color(red: 0.72, green: 0.55, blue: 1), .black
    ]

    private var textControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach([TextAlignment.leading, .center, .trailing], id: \.self) { a in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            textStyle.alignment = textStyle.alignment == a ? nil : a
                        }
                    } label: {
                        Image(systemName: a == .leading ? "text.alignleft" : (a == .center ? "text.aligncenter" : "text.alignright"))
                            .frame(width: 22)
                            .chip(selected: textStyle.alignment == a)
                    }
                    .accessibilityLabel(a == .leading ? "Align left" : (a == .center ? "Align center" : "Align right"))
                }
                Spacer()
                if textStyle != LyricTextStyle() {
                    Button("Reset") {
                        withAnimation { textStyle = LyricTextStyle() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LyricFont.allCases) { f in
                        Button {
                            textStyle.font = f
                        } label: {
                            Text(f.name)
                                .font(f.font(size: 14, weight: .semibold) ?? .system(size: 14, weight: .semibold))
                                .chip(selected: textStyle.font == f)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Effect")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(LyricEffect.allCases) { e in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { textStyle.effect = e }
                    } label: {
                        Text(e.name).chip(selected: textStyle.effect == e)
                    }
                }
            }

            // scrolls: 10 swatches don't fit on narrow phones
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    textStyle.color = nil
                } label: {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 16))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.white)
                        .overlay(Circle().stroke(textStyle.color == nil ? Color.white : .clear, lineWidth: 2).padding(-3))
                }
                .accessibilityLabel("Default color")

                ForEach(Self.swatches.indices, id: \.self) { i in
                    let c = Self.swatches[i]
                    Button {
                        textStyle.color = c
                    } label: {
                        Circle()
                            .fill(c)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .overlay(Circle().stroke(textStyle.color == c ? Color.white : .clear, lineWidth: 2).padding(-3))
                    }
                    .accessibilityLabel("Color \(i + 1)")
                }

                ColorPicker("Custom color", selection: Binding(get: { textStyle.color ?? .white }, set: { textStyle.color = $0 }))
                    .labelsHidden()
            }
            .padding(4)
            }
        }
    }

    // MARK: - Style Controls
    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 14) {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LyricCardStyle.allCases) { s in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { style = s }
                        } label: {
                            Label(s.name, systemImage: s.icon)
                                .chip(selected: style == s)
                        }
                    }
                }
            }

            // Context controls (Photo / Video specifics)
            HStack(spacing: 8) {
                if mode == .video {
                    ForEach([10.0, 15.0, 30.0], id: \.self) { d in
                        Button {
                            duration = d
                            if previewElapsed > d { previewElapsed = 0 }
                        } label: {
                            Text("\(Int(d))s")
                                .chip(selected: duration == d)
                        }
                        .accessibilityLabel("\(Int(d)) second video")
                    }
                }

                // cover/background apply to both photo cards and exported videos
                Menu {
                        Section("Cover") {
                            Button {
                                photoTarget = .cover
                                showPhotoPicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    photoTarget = .cover
                                    showCamera = true
                                } label: {
                                    Label(mode == .video ? "Camera (Photo/Video)" : "Take Photo", systemImage: "camera")
                                }
                            }
                        }
                        Section("Background") {
                            Button {
                                photoTarget = .backdrop
                                showPhotoPicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    photoTarget = .backdrop
                                    showCamera = true
                                } label: {
                                    Label(mode == .video ? "Camera (Photo/Video)" : "Take Photo", systemImage: "camera")
                                }
                            }
                        }
                        if customCover != nil {
                            Button("Reset Cover", role: .destructive) { customCover = nil; coverVideo = nil; coverFrame = nil }
                        }
                        if customBackdrop != nil {
                            Button("Reset Background", role: .destructive) { customBackdrop = nil; backdropVideo = nil; backdropFrame = nil }
                        }
                    } label: {
                        // icon-only in video mode so it fits next to the duration chips
                        Group {
                            if mode == .video {
                                Image(systemName: "photo.badge.plus")
                            } else {
                                Label("Media", systemImage: "photo.badge.plus")
                            }
                        }
                        .chip(selected: customCover != nil || customBackdrop != nil)
                    }
                    .accessibilityLabel("Media: custom cover and background")

                Spacer()
            }

            if mode == .video {
                if let backdropVideo {
                    ClipTrimmer(title: "Background clip", source: backdropVideo) { previewElapsed = 0 }
                        .id(ObjectIdentifier(backdropVideo))
                }
                if let coverVideo {
                    ClipTrimmer(title: "Cover clip", source: coverVideo) { previewElapsed = 0 }
                        .id(ObjectIdentifier(coverVideo))
                }
            }

            // own row so it never crowds the chips above on narrow phones
            if customBackdrop != nil {
                HStack(spacing: 10) {
                    Image(systemName: "drop.halffull")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Slider(value: $backdropBlur, in: 0...40)
                        .tint(.white)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Background blur")
            }
        }
    }

    // MARK: - Action Buttons Bar
    private var actionButtons: some View {
        HStack(spacing: 10) {
            if mode == .photo {
                Button {
                    shareToInstagram()
                } label: {
                    Label("Share to Stories", systemImage: "camera.circle.fill")
                        .primaryPill()
                }

                Button {
                    saveImage()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .circleIcon()
                }
                .accessibilityLabel("Save to Photos")

                Button {
                    presentSystemShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .circleIcon()
                }
                .accessibilityLabel("Share")
            } else {
                Button {
                    exportVideo()
                } label: {
                    Label(isRendering ? "Rendering…" : "Export Video", systemImage: isRendering ? "hourglass" : "film.fill")
                        .primaryPill()
                        .opacity(isRendering ? 0.6 : 1)
                }
                .disabled(isRendering)
            }
        }
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
            textStyle: textStyle,
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
        let snapBgVideo = backdropVideo
        let snapCoverVideo = coverVideo
        let startSongTime = songStartTime
        let snapSelection = selection
        let snapTextStyle = textStyle

        Task { @MainActor in
            do {
                let url = try await LyricVideoGenerator.renderVideo(
                    duration: totalDur,
                    fps: 30,
                    size: size,
                    scale: 3.0,
                    frameBuilder: { elapsed in
                        let currentSongTime = startSongTime + elapsed
                        let head = LyricPlayhead.at(songTime: currentSongTime, elapsed: elapsed, duration: totalDur,
                                                    selection: snapSelection, times: snapTimes)

                        var bgFrame = snapBg
                        if let snapBgVideo { bgFrame = await snapBgVideo.exportFrame(at: elapsed) }
                        var coverFrame = snapCover
                        if let snapCoverVideo { coverFrame = await snapCoverVideo.exportFrame(at: elapsed) }

                        return AnyView(
                            LyricCardView(
                                track: snapTrack,
                                lines: snapLines,
                                times: snapTimes,
                                aspectRatio: snapRatio,
                                time: currentSongTime,
                                duration: totalDur,
                                elapsed: elapsed,
                                activeLineIndex: head.index,
                                lineProgress: head.progress,
                                textStyle: snapTextStyle,
                                style: snapStyle,
                                backdropImage: bgFrame,
                                backdropBlur: snapBlur,
                                customArtwork: coverFrame
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

    private func playOnSpotify(_ track: Track) {
        Task {
            do {
                try await player.play(track)
                showToast("Playing on Spotify")
                // give Spotify a moment to report the new song before following it again
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if player.currentTrack?.id == track.id { player.unpin() }
            } catch {
                let message = error.localizedDescription.lowercased()
                if message.contains("scope") {
                    showToast("Reconnect Spotify to enable playback")
                } else if let url = URL(string: "spotify:track:\(track.id)"), await UIApplication.shared.open(url) {
                    // no Premium / no active device: let the Spotify app handle it
                } else {
                    showToast("Couldn't play: \(error.localizedDescription)")
                }
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
                                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
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
                if let err = auth.errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Spotify Auth Error")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button {
                                    auth.errorMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)

                            Text("💡 Tip: If you see 'Invalid client' or 'User not registered', Spotify requires accounts to either be added to the app's User Management in Developer Dashboard, or you can paste your own Spotify Client ID below.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Connection Status") {
                    HStack {
                        Image(systemName: auth.isAuthenticated ? "checkmark.circle.fill" : "music.note")
                            .foregroundStyle(auth.isAuthenticated ? Theme.online : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.isAuthenticated ? "Connected to Spotify" : "Demo Mode (Sample Data)")
                                .font(.system(size: 14, weight: .semibold))
                            Text(auth.isAuthenticated ? "Live sync active with currently playing song" : "Tap Connect to link your Spotify account")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if auth.isAuthenticated {
                        Button {
                            SpotifyPlayerService.shared.poll()
                            showToast("Refreshed currently playing track!")
                        } label: {
                            Label("Refresh Currently Playing", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                        }

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
                            HStack {
                                Image(systemName: "waveform")
                                Text(auth.isAuthenticating ? "Connecting..." : "Connect Spotify Account")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.online)
                        }
                        .disabled(auth.isAuthenticating)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        TextField("Enter Spotify Client ID", text: $auth.clientID)
                            .font(.system(size: 13, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(8)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack(spacing: 12) {
                            Button {
                                if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
                                    auth.clientID = pasted
                                    showToast("Client ID pasted!")
                                }
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                                    .font(.system(size: 12, weight: .semibold))
                            }

                            Spacer()

                            Button {
                                auth.resetToDefaults()
                                showToast("Reset to default Client ID!")
                            } label: {
                                Text("Reset to Default")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Redirect URI")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(auth.redirectURI)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = auth.redirectURI
                                showToast("Redirect URI copied!")
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 13))
                            }
                        }
                    }
                } header: {
                    Text("Spotify API Credentials")
                } footer: {
                    Text("SpotiVibe uses Spotify Authorization Code with PKCE (secure, no client secret required).")
                        .font(.system(size: 11))
                }

                Section("Using Your Own Spotify Developer App") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("If default login gives 'User not registered' or quota limits:")
                            .font(.system(size: 12, weight: .semibold))
                        Text("1. Open developer.spotify.com/dashboard on your browser")
                        Text("2. Click 'Create app' and enter any name (e.g. SpotiVibe)")
                        Text("3. Add Redirect URI: opennotchi://spotify-callback")
                        Text("4. Select 'Web API' check box, then click Save")
                        Text("5. Copy your Client ID and paste it above!")
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                }

                Section("About SpotiVibe") {
                    Text("SpotiVibe is a dedicated iOS lyric video and card studio inspired by OpenNotchi. Generate 10+ aesthetic card styles, 30/60 FPS animated MP4 lyric videos, and share directly to Instagram Stories and your Camera Roll.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Spotify Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettingsSheet = false }
                }
            }
        }
    }
}

private extension LyricsShareView {
    /// Handles spotivibe://import?file=…&kind=… from the Share Extension: shared media becomes the background.
    func importShared(_ url: URL) {
        guard url.host == "import",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let name = items.first(where: { $0.name == "file" })?.value,
              // file name only: never let the URL point outside our inbox
              !name.contains("/"), !name.contains(".."),
              let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.naneps.spotivibe")?
                .appendingPathComponent("Inbox", isDirectory: true)
        else { return }

        let shared = inbox.appendingPathComponent(name)
        // move out of the shared inbox so it doesn't pile up there
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.moveItem(at: shared, to: local)) != nil else {
            showToast("Couldn't open shared media")
            return
        }

        photoTarget = .backdrop
        if items.first(where: { $0.name == "kind" })?.value == "video" {
            mode = .video
            applyVideo(local)
        } else if let image = UIImage(contentsOfFile: local.path) {
            applyMedia(image)
        } else {
            showToast("Couldn't open shared media")
        }
    }

    func applyMedia(_ image: UIImage) {
        if photoTarget == .cover {
            customCover = image
            showToast("Custom cover art applied!")
        } else {
            customBackdrop = image
            showToast("Custom background applied!")
        }
        // a still replaces any clip on the same slot
        if photoTarget == .cover { coverVideo = nil; coverFrame = nil } else { backdropVideo = nil; backdropFrame = nil }
    }

    func applyVideo(_ url: URL) {
        let target = photoTarget
        Task {
            do {
                let source = try await VideoSource.load(url: url)
                if target == .cover {
                    coverVideo = source
                    coverFrame = nil
                    customCover = source.thumbnail
                    showToast("Video cover applied!")
                } else {
                    backdropVideo = source
                    backdropFrame = nil
                    customBackdrop = source.thumbnail
                    showToast("Video background applied!")
                }
            } catch {
                showToast("Couldn't load that video")
            }
        }
    }
}

/// System camera UI; PhotosPicker can't capture, so this wraps UIImagePickerController.
private struct CameraPicker: UIViewControllerRepresentable {
    let allowsVideo: Bool
    let onImage: (UIImage) -> Void
    let onVideo: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if allowsVideo {
            picker.mediaTypes = ["public.image", "public.movie"]
            picker.videoMaximumDuration = 30
            picker.videoQuality = .typeHigh
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.onVideo(url)
            } else if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Theme
/// Spotify-like dark neutrals, but SpotiVibe's own pink→orange accent instead of Spotify green.
enum Theme {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.07)            // #121212
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.10)       // #1A1A1A
    static let elevated = Color(red: 0.16, green: 0.16, blue: 0.16)      // #2A2A2A
    static let outline = Color.white.opacity(0.28)
    static let textSecondary = Color(red: 0.70, green: 0.70, blue: 0.70) // #B3B3B3
    static let accent = Color(red: 0.98, green: 0.18, blue: 0.44)        // #FA2E70, matches app icon
    static let accentEnd = Color(red: 0.98, green: 0.58, blue: 0.20)
    static let online = Color(red: 0.18, green: 0.85, blue: 0.55)
    static let brand = LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private extension View {
    /// Filter chip: white when selected (Spotify-ish), dark grey otherwise.
    func chip(selected: Bool) -> some View {
        font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Capsule().fill(selected ? Color.white : Theme.elevated))
            .foregroundStyle(selected ? Color.black : Color.white)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func primaryPill() -> some View {
        font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(Theme.brand))
            .foregroundStyle(.white)
    }

    func circleIcon() -> some View {
        font(.system(size: 17, weight: .bold))
            .frame(width: 50, height: 50)
            .background(Circle().fill(Theme.elevated))
            .foregroundStyle(.white)
    }
}

// MARK: - Clip Trimmer
/// WhatsApp-style trimmer: drag either handle to set the range, drag the middle to move it.
/// Any length works; the lyric video loops the trimmed range.
private struct ClipTrimmer: View {
    let title: String
    let source: VideoSource
    let onChange: () -> Void

    @State private var frames: [UIImage] = []
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var drag: (kind: Handle, start: Double, end: Double)? = nil

    private enum Handle { case start, end, body }
    private let minSpan = 1.0
    private let handleWidth: CGFloat = 16
    private let height: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(clock(start)) – \(clock(end))  ·  \(String(format: "%.1fs", end - start))")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            GeometryReader { geo in
                let track = geo.size.width - handleWidth * 2
                let x0 = handleWidth + track * start / source.length
                let x1 = handleWidth + track * end / source.length

                ZStack(alignment: .topLeading) {
                    filmstrip
                        .frame(width: track, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(x: handleWidth)

                    // dim outside the range
                    Color.black.opacity(0.6)
                        .frame(width: max(0, x0 - handleWidth), height: height)
                        .offset(x: handleWidth)
                    Color.black.opacity(0.6)
                        .frame(width: max(0, geo.size.width - handleWidth - x1), height: height)
                        .offset(x: x1)

                    // frame around the selection with grab handles
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.accent, lineWidth: 3)
                        .frame(width: x1 - x0 + handleWidth * 2, height: height)
                        .offset(x: x0 - handleWidth)
                    handle.offset(x: x0 - handleWidth)
                    handle.offset(x: x1)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let perPoint = source.length / Double(max(track, 1))
                            if drag == nil {
                                // grab whichever part is under the finger
                                let x = value.startLocation.x
                                let kind: Handle = abs(x - x0) < 28 && x <= (x0 + x1) / 2 ? .start
                                    : abs(x - x1) < 28 ? .end : .body
                                drag = (kind, start, end)
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            guard let d = drag else { return }
                            let delta = Double(value.translation.width) * perPoint
                            switch d.kind {
                            case .start: start = min(max(0, d.start + delta), end - minSpan)
                            case .end: end = max(min(source.length, d.end + delta), start + minSpan)
                            case .body:
                                let span = d.end - d.start
                                start = min(max(0, d.start + delta), source.length - span)
                                end = start + span
                            }
                            commit()
                        }
                        .onEnded { _ in drag = nil }
                )
            }
            .frame(height: height)
        }
        .task { frames = await source.filmstrip(count: 10) }
        .onAppear {
            start = source.trimStart
            end = min(source.trimEnd, source.length)
        }
        .accessibilityElement()
        .accessibilityLabel("\(title), \(clock(start)) to \(clock(end))")
        .accessibilityHint("Swipe up or down to move the clip")
        .accessibilityAdjustableAction { dir in
            let span = end - start
            start = min(max(0, start + (dir == .increment ? 1 : -1)), source.length - span)
            end = start + span
            commit()
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.accent)
            .frame(width: handleWidth, height: height)
            .overlay(Capsule().fill(.white).frame(width: 3, height: 16))
    }

    private var filmstrip: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(frames.indices, id: \.self) { i in
                    Image(uiImage: frames[i])
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width / CGFloat(max(frames.count, 1)), height: height)
                        .clipped()
                }
            }
        }
        .background(Theme.elevated)
    }

    private func commit() {
        source.trimStart = start
        source.trimEnd = end
        onChange()
    }

    private func clock(_ s: Double) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - Track Search
private struct TrackSearchSheet: View {
    let isConnected: Bool
    let onPick: (Track) -> Void

    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !isConnected {
                    Text("Connect Spotify to search songs.")
                        .foregroundStyle(Theme.textSecondary)
                } else if let errorText {
                    Text(errorText).foregroundStyle(Theme.textSecondary)
                } else if results.isEmpty && !query.isEmpty && !isSearching {
                    Text("No results for “\(query)”").foregroundStyle(Theme.textSecondary)
                }

                ForEach(results) { track in
                    Button {
                        onPick(track)
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: track.artworkURL) { phase in
                                if let img = phase.image { img.resizable().scaledToFill() } else { Theme.elevated }
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("\(track.artist) · \(track.album)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listRowBackground(Theme.bg)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .overlay { if isSearching { ProgressView() } }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs or artists")
            .task(id: query) {
                // debounce: cancelled automatically when the user keeps typing
                let q = query.trimmingCharacters(in: .whitespaces)
                errorText = nil
                guard isConnected, !q.isEmpty else { results = []; return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                isSearching = true
                defer { isSearching = false }
                do {
                    let found = try await SpotifyPlayerService.shared.search(q)
                    guard !Task.isCancelled else { return }
                    results = found
                    errorText = nil
                } catch is CancellationError {
                } catch {
                    if !Task.isCancelled { errorText = error.localizedDescription }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
