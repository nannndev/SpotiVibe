# SpotiVibe

Lyric cards and karaoke-style lyric videos from the song you're playing on Spotify, ready for Instagram Stories, TikTok and your camera roll.

The repo holds three apps:

| | Stack | State |
|---|---|---|
| `ios/` | SwiftUI, iOS 16+ | Main app, all features below |
| `android/` | Jetpack Compose, Android 8+ | Earlier feature set (see [Android](#android)) |
| `web/` | React + Vite | Landing page with an in-browser card studio |

## Features (iOS)

**Songs and lyrics**
- Follows what you're playing on Spotify (OAuth PKCE, no password, no server).
- Search any song; picking one plays it on Spotify (Premium) or opens it in the Spotify app.
- Synced lyrics from [LRCLIB](https://lrclib.net); choose up to 8 consecutive lines.
- Demo mode with sample songs when you're not connected.

**10 card styles**
- **Aura**: soft bloom in a color taken from the album art.
- **Player**: big artwork, centered lyrics, progress bar and transport buttons.
- **VHS 90s**: `PLAY ▶` on-screen display, timecode, all-caps mono.
- **Cassette**: Side A label and spinning reels.
- **Vinyl**: sleeve and a record that turns while the video plays.
- **Glass**: lyrics on a frosted panel over blurred artwork.
- **Polaroid**: tilted instant photo with the line written underneath.
- **Paper**: editorial serif, large quote mark, highlighter on the active line.
- **Receipt**: thermal-printed track log with barcode.
- **Solid**: one bold color, heavy type.

**Make it yours**
- Text: alignment, 15 built-in fonts, color (presets or any color), optional glow or shadow.
- Accent color taken from the cover automatically; can be turned off.
- Custom cover and background from your photo library or camera, as a photo or a video.
- Trim video clips by dragging either edge, like in WhatsApp; clips shorter than the lyric video loop.
- SpotiVibe watermark can be turned off.
- Settings are remembered between launches.

**Video**
- 10, 15 or 30 second MP4 at 30 fps.
- Line animations: karaoke fill, word by word, typewriter, or fade.
- Keeps the sound of a background video clip (trimmed and looped).

**Sharing**
- Straight to Instagram Stories, save to Photos, or the system share sheet.
- Share a photo or video from the Photos app to SpotiVibe to start a card with it.
- History of shared cards, with favorites, to reopen and edit.
- Now Playing home screen widget (small and medium) with a shortcut into the studio.

**Sizes:** 9:16 Story (1080 × 1920), 4:5 Post (1080 × 1350), 1:1 Square (1080 × 1080).

## Run it

### iOS

Requires Xcode 16 and an iOS 16+ device or simulator.

```bash
cd ios
xcodegen generate    # only after editing project.yml
open SpotiVibe.xcodeproj
```

Pick the **SpotiVibe** scheme and run. The project has three targets (app, share extension, widget) that share the App Group `group.com.naneps.spotivibe`. To build under your own Apple team, change `DEVELOPMENT_TEAM`, the bundle IDs and the App Group in `ios/project.yml`.

**Spotify login.** The app uses a built-in Client ID. If login says *User not registered*, either add your account under *User Management* in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard), or create your own app there and paste its Client ID in SpotiVibe's Settings. Add `opennotchi://spotify-callback` as the redirect URI and enable Web API.

Debug builds run small self-checks on launch (lyric timing, settings encoding, audio looping, history). A failure stops the app with an assertion message.

### Android

```bash
cd android
./gradlew assembleDebug    # APK in app/build/outputs/apk/debug/
```

Android currently has the 10 styles, photo and video modes, aspect ratios, custom photo cover and background, Spotify login and sharing. Search, video backgrounds, trimming, text styling, line animations, history and the widget are iOS-only for now.

### Web

```bash
cd web
npm install
npm run dev      # http://localhost:5173
npm run build    # static site in dist/
```

The landing page serves the Android APK from `web/public/spotivibe.apk`. Replace that file by hand after building a new APK; `*.apk` is git-ignored at the root.

## Repository layout

```
ios/
  project.yml              XcodeGen spec (source of truth for the Xcode project)
  SpotiVibe/
    App/                   entry point
    Models/                Track, Lyrics, card style, aspect ratio, text style
    Services/              Spotify auth and player, lyrics, sharing, history, widget bridge
    Generator/             MP4 renderer, video clip source
    Views/                 studio screen, card view
  SpotiVibeShare/          share extension ("Share to SpotiVibe" from Photos)
  SpotiVibeWidget/         Now Playing widget
  scripts/make_icon.py     regenerates the app icon set
android/                   Jetpack Compose app
web/                       React landing page
```

## Credits

Lyrics by [LRCLIB](https://lrclib.net). Song data from the [Spotify Web API](https://developer.spotify.com). Inspired by [OpenNotchi](https://github.com/nannndev/OpenNotchi).

SpotiVibe is not affiliated with or endorsed by Spotify AB.
