import SwiftUI

public struct LyricCardView: View {
    public let track: Track
    public let lines: [String]
    public var times: [Double?] = []
    public var aspectRatio: CardAspectRatio = .story
    public var time: Double = 0
    public var duration: Double = 15
    public var elapsed: Double = 0
    public var activeLineIndex: Int? = nil
    /// 0…1 through the active line; drives the karaoke fill in video mode.
    public var lineProgress: Double = 0
    public var textStyle = LyricTextStyle()
    public var style: LyricCardStyle = .aura
    public var backdropImage: UIImage? = nil
    public var backdropBlur: CGFloat = 14
    public var customArtwork: UIImage? = nil
    public var accentColor: Color = Color(red: 0.92, green: 0.28, blue: 0.60) // SpotiVibe Pink/Neon

    public init(
        track: Track,
        lines: [String],
        times: [Double?] = [],
        aspectRatio: CardAspectRatio = .story,
        time: Double = 0,
        duration: Double = 15,
        elapsed: Double = 0,
        activeLineIndex: Int? = nil,
        lineProgress: Double = 0,
        textStyle: LyricTextStyle = LyricTextStyle(),
        style: LyricCardStyle = .aura,
        backdropImage: UIImage? = nil,
        backdropBlur: CGFloat = 14,
        customArtwork: UIImage? = nil,
        accentColor: Color = Color(red: 0.92, green: 0.28, blue: 0.60)
    ) {
        self.track = track
        self.lines = lines
        self.times = times
        self.aspectRatio = aspectRatio
        self.time = time
        self.duration = duration
        self.elapsed = elapsed
        self.activeLineIndex = activeLineIndex
        self.lineProgress = lineProgress
        self.textStyle = textStyle
        self.style = style
        self.backdropImage = backdropImage
        self.backdropBlur = backdropBlur
        self.customArtwork = customArtwork
        self.accentColor = accentColor
    }

    private var cardSize: CGSize { aspectRatio.size }

    private var lyricSize: CGFloat {
        let totalChars = lines.joined().count
        if totalChars > 220 { return 15 }
        if totalChars > 150 { return 18 }
        if totalChars > 80 { return 21 }
        return 24
    }

    public var body: some View {
        ZStack {
            background
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()

            Group {
                switch style {
                case .player: playerLayout
                case .polaroid: polaroidLayout
                case .vhs: vhsLayout
                case .cassette: cassetteLayout
                case .vinyl: vinylLayout
                case .glass: glassLayout
                case .receipt: receiptLayout
                default: defaultLayout
                }
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Backgrounds
    @ViewBuilder private var background: some View {
        if let backdrop = backdropImage {
            ZStack {
                Image(uiImage: backdrop)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardSize.width + backdropBlur * 4, height: cardSize.height + backdropBlur * 4)
                    .blur(radius: backdropBlur)
                LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            }
        } else {
            styleBackground
        }
    }

    @ViewBuilder private var styleBackground: some View {
        switch style {
        case .aura, .player, .glass:
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.16), Color(red: 0.04, green: 0.04, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(
                    colors: [accentColor.opacity(0.35), .clear],
                    center: .init(x: 0.5, y: 0.6),
                    startRadius: 20,
                    endRadius: cardSize.width * 0.75
                )
            }
        case .vhs:
            Color.black
        case .cassette:
            Color(red: 0.09, green: 0.09, blue: 0.11)
        case .vinyl:
            LinearGradient(colors: [Color(red: 0.11, green: 0.10, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.05)], startPoint: .top, endPoint: .bottom)
        case .receipt:
            Color(red: 0.14, green: 0.14, blue: 0.17)
        case .solid:
            ZStack {
                accentColor
                LinearGradient(colors: [Color.white.opacity(0.12), .clear, Color.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .polaroid:
            LinearGradient(colors: [Color(red: 0.93, green: 0.89, blue: 0.83), Color(red: 0.86, green: 0.81, blue: 0.74)], startPoint: .top, endPoint: .bottom)
        case .paper:
            Color(red: 0.96, green: 0.93, blue: 0.87)
        }
    }

    // MARK: - Layout: Default (Aura, Solid, Paper)
    private var defaultLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer()

            if style == .paper {
                Text("“")
                    .font(.system(size: 80, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.15, green: 0.13, blue: 0.12).opacity(0.12))
                    .padding(.bottom, -30)
            }

            lyricsBlock
            Spacer()
            footer
        }
        .padding(24)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            coverImage
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: style == .paper ? 4 : 10))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .bold, design: style == .paper ? .serif : .rounded))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12, weight: .medium, design: style == .paper ? .serif : .rounded))
                    .opacity(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(style == .paper ? Color(red: 0.15, green: 0.13, blue: 0.12) : .white)

            Spacer()
        }
    }

    // MARK: - Lyrics Block
    private var lyricsBlock: some View {
        let align = textStyle.alignment ?? .leading
        return VStack(alignment: align.horizontal, spacing: lyricSize * 0.4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                let textColor: Color = (style == .paper)
                    ? Color(red: 0.15, green: 0.13, blue: 0.12)
                    : .white

                lyricLine(line, index: index, size: lyricSize, design: style == .paper ? .serif : .rounded,
                          color: textColor, glow: style == .paper ? .clear : accentColor, align: align)
                    .padding(.horizontal, style == .paper && isCurrent && activeLineIndex != nil ? 6 : 0)
                    .padding(.vertical, style == .paper && isCurrent && activeLineIndex != nil ? 2 : 0)
                    .background(
                        style == .paper && isCurrent && activeLineIndex != nil
                            ? RoundedRectangle(cornerRadius: 4).fill(Color.yellow.opacity(0.28))
                            : nil
                    )
            }
        }
        .multilineTextAlignment(align)
        .frame(maxWidth: .infinity, alignment: align.frame)
    }

    // MARK: - Animated Lyric Line
    /// One lyric line. Photo: static. Video: past lines dim, the active one pops in and fills left→right
    /// with its progress. Everything is derived from `lineProgress` (no SwiftUI animations) so the
    /// exported frames, rendered one by one, move exactly like the preview.
    @ViewBuilder
    private func lyricLine(_ text: String, index: Int, size: CGFloat, weight: Font.Weight = .bold,
                           design: Font.Design, color: Color, glow: Color, align: TextAlignment) -> some View {
        let font = textStyle.font.font(size: size, weight: weight) ?? .system(size: size, weight: weight, design: design)
        let base = textStyle.color ?? color

        if let active = activeLineIndex {
            let isActive = index == active
            let isPast = index < active
            let t = min(lineProgress * 5, 1)
            let pop = isActive ? 1 - pow(1 - t, 3) : 0 // ease-out over the first ~20% of the line

            Text(text)
                .font(font)
                .foregroundStyle(base.opacity(isPast ? 0.5 : (isActive ? 0.4 : 0.25)))
                .overlay {
                    if isActive {
                        Text(text)
                            .font(font)
                            .foregroundStyle(base)
                            .mask {
                                // soft edge sweeping across the line
                                LinearGradient(stops: [
                                    .init(color: .black, location: max(0, lineProgress - 0.04)),
                                    .init(color: .clear, location: min(1, lineProgress + 0.04))
                                ], startPoint: .leading, endPoint: .trailing)
                            }
                    }
                }
                .scaleEffect(1 + 0.06 * pop, anchor: UnitPoint(x: align == .leading ? 0 : (align == .trailing ? 1 : 0.5), y: 0.5))
                .offset(y: isActive ? 6 * (1 - pop) : 0)
                .modifier(LyricEffectModifier(effect: textStyle.effect, glow: glow, strength: isActive ? pop : 0.4))
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(base)
                .modifier(LyricEffectModifier(effect: textStyle.effect, glow: glow, strength: 1))
        }
    }

    // MARK: - Layout: Player
    private var playerLayout: some View {
        VStack(spacing: 0) {
            coverImage
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                .padding(.top, 16)

            VStack(spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.65)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.top, 12)

            Spacer(minLength: 8)

            let align = textStyle.alignment ?? .center
            VStack(alignment: align.horizontal, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    lyricLine(line, index: index, size: min(lyricSize, 19), design: .rounded,
                              color: .white, glow: .white, align: align)
                }
            }
            .multilineTextAlignment(align)
            .frame(maxWidth: .infinity, alignment: align.frame)

            Spacer(minLength: 12)

            // Progress bar
            let progress = duration > 0 ? min(1.0, max(0.0, (time + elapsed) / duration)) : 0.35
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.white).frame(width: geo.size.width * progress)
                        Circle().fill(Color.white).frame(width: 10, height: 10)
                            .offset(x: max(0, geo.size.width * progress - 5))
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formatTime(time + elapsed))
                    Spacer()
                    Text("-" + formatTime(max(0, duration - (time + elapsed))))
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)

            // Transport controls
            HStack(spacing: 26) {
                Image(systemName: "shuffle").font(.system(size: 12, weight: .semibold)).opacity(0.6)
                Image(systemName: "backward.fill").font(.system(size: 15))
                Image(systemName: "pause.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
                Image(systemName: "forward.fill").font(.system(size: 15))
                Image(systemName: "heart.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.pink)
            }
            .foregroundStyle(.white)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Layout: VHS 90s
    private var vhsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Bar
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(Int(elapsed * 2) % 2 == 0 ? 1 : 0.25)
                    Text("REC")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Text("SP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Spacer()
                Text("AUTO  [■■□]")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)

            // Green Digital Timecode
            Text(formatTimecode(elapsed))
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.7), radius: 6)
                .padding(.top, 6)

            Spacer()

            let align = textStyle.alignment ?? .leading
            VStack(alignment: align.horizontal, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    lyricLine(line.uppercased(), index: index, size: lyricSize, weight: .heavy, design: .monospaced,
                              color: .white, glow: .cyan, align: align)
                }
            }
            .multilineTextAlignment(align)
            .frame(maxWidth: .infinity, alignment: align.frame)

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title.uppercased())
                        .font(.system(size: 11.5, weight: .black, design: .monospaced))
                    Text(track.artist.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .opacity(0.7)
                }
                Spacer()
                Text("PLAY ▶")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
            }
            .foregroundStyle(.white)
        }
        .padding(22)
    }

    // MARK: - Layout: Cassette
    private var cassetteLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 10)

            // Cassette Tape Graphic
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1.5))

                VStack(spacing: 6) {
                    HStack {
                        Text("SIDE A")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                        Text(track.title)
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("C-60")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.85))
                            .frame(height: 44)

                        HStack(spacing: 36) {
                            CassetteSpool(rotation: elapsed * 180)
                            Rectangle().fill(Color(red: 0.35, green: 0.18, blue: 0.12)).frame(width: 32, height: 14)
                            CassetteSpool(rotation: elapsed * 180)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
                .background(Color(red: 0.94, green: 0.92, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(6)
            }
            .frame(height: 105)

            Spacer(minLength: 8)
            lyricsBlock
            Spacer(minLength: 8)
            footer
        }
        .padding(20)
    }

    // MARK: - Layout: Vinyl
    private var vinylLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 12)

            HStack(spacing: -24) {
                coverImage
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.5), radius: 10, x: -4, y: 4)
                    .zIndex(2)

                VinylDisc(artwork: customArtwork, rotation: elapsed * 90)
                    .frame(width: 106, height: 106)
                    .zIndex(1)
            }
            .padding(.vertical, 4)

            Spacer(minLength: 8)
            lyricsBlock
            Spacer(minLength: 8)
            footer
        }
        .padding(20)
    }

    // MARK: - Layout: Glass
    private var glassLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                coverImage
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title).font(.system(size: 11, weight: .bold)).lineLimit(1)
                    Text(track.artist).font(.system(size: 9.5, weight: .medium)).opacity(0.6).lineLimit(1)
                }
                .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 2.5) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(accentColor)
                            .frame(width: 3, height: 6 + CGFloat(sin(elapsed * 6 + Double(i) * 1.5)) * 5)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.black.opacity(0.7)))
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))

            Spacer(minLength: 12)

            let align = textStyle.alignment ?? .leading
            VStack(alignment: align.horizontal, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    lyricLine(line, index: index, size: lyricSize, design: .rounded,
                              color: .white, glow: accentColor, align: align)
                }
            }
            .multilineTextAlignment(align)
            .frame(maxWidth: .infinity, alignment: align.frame)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(colors: [accentColor.opacity(0.8), .purple.opacity(0.6), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5
                            )
                    )
            )

            Spacer(minLength: 12)
            footer
        }
        .padding(20)
    }

    // MARK: - Layout: Polaroid
    private var polaroidLayout: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                coverImage
                    .frame(width: 200, height: 160)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(track.title.uppercased())
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.6))
                            .padding(6)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.prefix(4).enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        let ink = textStyle.color ?? Color(red: 0.15, green: 0.13, blue: 0.12)
                        let size = min(lyricSize * 0.65, 14)
                        let weight: Font.Weight = isCurrent ? .bold : .medium
                        Text(line)
                            .font(textStyle.font.font(size: size, weight: weight) ?? .system(size: size, weight: weight, design: .serif))
                            .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                    }
                    Text("— \(track.artist)")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.15, green: 0.13, blue: 0.12).opacity(0.6))
                        .padding(.top, 2)
                }
                .frame(width: 200, alignment: .topLeading)
            }
            .padding(10)
            .background(Color(red: 0.99, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
            .rotationEffect(.degrees(-2.5))

            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Layout: Receipt
    private var receiptLayout: some View {
        VStack(spacing: 0) {
            ReceiptPerforation()
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 7)

            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("*** SPOTIVIBE ARCHIVE ***")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    HStack {
                        Text("AUDIO #1024")
                        Spacer()
                        Text(activeLineIndex != nil ? "TIME: \(formatTime(elapsed))" : "TRACK CASSETTE")
                            .foregroundStyle(activeLineIndex != nil ? .red : .primary)
                    }
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .opacity(0.7)
                    Text("------------------------------------")
                        .font(.system(size: 8, design: .monospaced)).opacity(0.35)
                    HStack {
                        Text(track.title.uppercased()).font(.system(size: 9.5, weight: .bold, design: .monospaced)).lineLimit(1)
                        Spacer()
                        Text(track.artist.uppercased()).font(.system(size: 8.5, weight: .medium, design: .monospaced)).lineLimit(1)
                    }
                    Text("------------------------------------")
                        .font(.system(size: 8, design: .monospaced)).opacity(0.35)
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        HStack(alignment: .top, spacing: 5) {
                            Text(isCurrent && activeLineIndex != nil ? "►" : String(format: "%02d", index + 1))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(isCurrent && activeLineIndex != nil ? .red : Color.black.opacity(0.45))
                            let ink = textStyle.color ?? .black
                            let size = min(lyricSize, 13)
                            let weight: Font.Weight = isCurrent ? .bold : .regular
                            Text(line)
                                .font(textStyle.font.font(size: size, weight: weight) ?? .system(size: size, weight: weight, design: .monospaced))
                                .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<28) { i in
                            Rectangle()
                                .fill(Color.black.opacity(0.8))
                                .frame(width: (i % 3 == 0) ? 2.5 : ((i % 5 == 0) ? 3.5 : 1.2), height: 22)
                        }
                    }
                    Text("THANK YOU FOR LISTENING")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .padding(14)
            .background(Color(red: 0.96, green: 0.95, blue: 0.92))
            .foregroundStyle(Color.black.opacity(0.85))

            ReceiptPerforation(inverted: true)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 7)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: - Subviews & Helpers
    @ViewBuilder private var coverImage: some View {
        if let custom = customArtwork {
            Image(uiImage: custom).resizable().scaledToFill()
        } else if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.white.opacity(0.15))
                }
            }
        } else {
            Rectangle().fill(Color.white.opacity(0.15))
                .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "quote.bubble.fill").font(.system(size: 9, weight: .bold))
            Text("SpotiVibe").font(.system(size: 10.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(style == .paper ? Color.black.opacity(0.5) : Color.white.opacity(0.6))
    }

    private func formatTime(_ sec: Double) -> String {
        let s = max(0, Int(sec))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func formatTimecode(_ sec: Double) -> String {
        let s = max(0, sec)
        let totalSec = Int(s)
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        let sc = totalSec % 60
        let cs = Int((s - Double(totalSec)) * 100)
        return String(format: "%02d:%02d:%02d.%02d", h, m, sc, cs)
    }
}

// MARK: - Custom Visual Elements
struct CassetteSpool: View {
    let rotation: Double
    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 24, height: 24)
            Circle().fill(Color.black).frame(width: 8, height: 8)
            ForEach(0..<6) { i in
                Rectangle().fill(Color.black.opacity(0.4)).frame(width: 2, height: 7).offset(y: -8)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct VinylDisc: View {
    let artwork: UIImage?
    let rotation: Double
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.08, green: 0.08, blue: 0.09))
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 90, height: 90)
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1).frame(width: 72, height: 72)
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1).frame(width: 54, height: 54)

            if let artwork = artwork {
                Image(uiImage: artwork).resizable().scaledToFill()
                    .frame(width: 32, height: 32).clipShape(Circle())
            } else {
                Circle().fill(Color.pink).frame(width: 32, height: 32)
            }
            Circle().fill(Color.black).frame(width: 6, height: 6)
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct ReceiptPerforation: Shape {
    var inverted = false
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth: CGFloat = 8
        let toothHeight = rect.height
        let count = Int(rect.width / toothWidth)
        path.move(to: CGPoint(x: 0, y: inverted ? 0 : toothHeight))
        for i in 0..<count {
            let x = CGFloat(i) * toothWidth
            let mid = x + toothWidth / 2
            let next = x + toothWidth
            if inverted {
                path.addLine(to: CGPoint(x: mid, y: toothHeight))
                path.addLine(to: CGPoint(x: next, y: 0))
            } else {
                path.addLine(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: next, y: toothHeight))
            }
        }
        return path
    }
}

/// Applies the user's chosen text effect. `strength` lets the active line glow fully while others stay faint.
private struct LyricEffectModifier: ViewModifier {
    let effect: LyricEffect
    let glow: Color
    let strength: Double

    func body(content: Content) -> some View {
        switch effect {
        case .none:
            content
        case .glow:
            content.shadow(color: glow.opacity(0.75 * strength), radius: 12)
        case .shadow:
            // readability on busy photo/video backgrounds
            content.shadow(color: .black.opacity(0.55), radius: 3, y: 2)
        }
    }
}
