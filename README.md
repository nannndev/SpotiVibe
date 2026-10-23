# 🎵 SpotiVibe

> **Aesthetic Lyric Card & Story Studio for Spotify** — Built with native SwiftUI for iOS.

SpotiVibe connects to your Spotify account in real-time, synchronizes per-second lyrics using LRCLIB, and renders high-resolution aesthetic lyric cards & animated 30/60 FPS MP4 videos ready for **Instagram Stories**, **TikTok**, and **Camera Roll**.

---

## 📱 Features

- **10 Aesthetic Lyric Card Styles**:
  - ✨ **Aura** — Ambient glow from album art & accent color.
  - 🎵 **Player** — Classic Now Playing card with progress scrubber & transport buttons.
  - 📼 **VHS 90s** — Camcorder aesthetic with blinking `REC`, digital green timecode (`00:00:00.00`), scanlines, and cyan neon glow.
  - 📻 **Cassette** — Vintage cassette tape shell with red "SIDE A" badge, handwritten title, and dual spinning spools.
  - 💿 **Vinyl** — Spinning record disc with groove lines and album center label sliding out of its jacket.
  - 🧊 **Glass** — Frosted glassmorphism card with multi-color neon gradient border and bouncing audio equalizer bars.
  - 📷 **Polaroid** — Tilted instant photo frame (-2.5°) with handwritten font, tag, and signature.
  - 📜 **Paper** — Warm editorial parchment with classic serif typography, giant quote mark `“`, and highlighter on active lyric.
  - 🧾 **Receipt** — Vintage thermal receipt with zigzag perforated tear edges, monospace audio metadata, and barcode.
  - 🎨 **Solid** — High-contrast bold color block matching album palette.

- **Photo & Video Modes**:
  - **Photo**: Instant high-res export (PNG) for social feeds and stories.
  - **Video**: 30 FPS hardware-accelerated MP4 generator with real-time active lyric karaoke tracking, rotating vinyl/cassette spools, and playback scrubber.

- **Aspect Ratios**:
  - `9:16 Story` (1080 × 1920) for Instagram Stories, Reels, TikTok.
  - `4:5 Post` (1080 × 1350) for Instagram Feed posts.
  - `1:1 Square` (1080 × 1080) for album art and avatars.

- **Direct Native Sharing**:
  - 📸 **Direct to Instagram Stories**: One-tap share using iOS pasteboard sticker integration (`instagram-stories://share`).
  - 💾 **Save to Camera Roll**: Native `PHPhotoLibrary` saving for images and videos.
  - 🔗 **System Share**: AirDrop, Messages, WhatsApp, and more.

- **Spotify & Lyrics Integration**:
  - Spotify OAuth 2.0 PKCE authentication (`user-read-currently-playing`).
  - Synchronized lyrics fetched automatically from [LRCLIB](https://lrclib.net).
  - Built-in Demo Mode when offline or not logged in.

---

## 🚀 Getting Started

### Requirements
- macOS with Xcode 15+ installed.
- iOS 16.0+ target device or Simulator.

### Open and Run
1. Open the project in Xcode:
   ```bash
   open ios/SpotiVibe.xcodeproj
   ```
2. Select your target device or iPhone Simulator (e.g., iPhone 15 Pro).
3. Press **Cmd + R** to Build & Run!

---

## 📂 Repository Structure

```
SpotiVibe/
├── ios/
│   ├── SpotiVibe.xcodeproj
│   ├── project.yml
│   └── SpotiVibe/
│       ├── App/
│       │   └── SpotiVibeApp.swift
│       ├── Models/
│       │   ├── Track.swift
│       │   ├── Lyrics.swift
│       │   ├── LyricCardStyle.swift
│       │   └── CardAspectRatio.swift
│       ├── Services/
│       │   ├── SpotifyAuthService.swift
│       │   ├── SpotifyPlayerService.swift
│       │   ├── LyricsService.swift
│       │   └── DirectShareService.swift
│       ├── Generator/
│       │   └── LyricVideoGenerator.swift
│       ├── Views/
│       │   ├── LyricsShareView.swift
│       │   └── LyricCardView.swift
│       └── Resources/
│           ├── Info.plist
│           └── Assets.xcassets/
└── android/ (Planned: Jetpack Compose version)
```
