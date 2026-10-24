import { forwardRef, useRef, useState } from 'react'
import confetti from 'canvas-confetti'
import { Card } from './Card.jsx'
import { useKaraoke } from './useKaraoke.js'
import { TRACKS, STYLES, RATIOS, FONTS, SWATCHES, APK_URL, APK_SIZE } from './data.js'
import { exportPng } from './exportPng.js'

const HERO_LINES = ['Your song,', 'out loud,', 'on your story.']

export default function App() {
  const [styleId, setStyleId] = useState('aura')
  const studioRef = useRef(null)

  const openInStudio = (id) => {
    setStyleId(id)
    studioRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  return (
    <>
      <a className="skip" href="#studio">Skip to the studio</a>
      <Nav />
      <main>
        <Hero />
        <Studio ref={studioRef} styleId={styleId} setStyleId={setStyleId} />
        <Styles onPick={openInStudio} />
        <HowItWorks />
        <Features />
        <Download />
      </main>
      <Footer />
    </>
  )
}

function Nav() {
  return (
    <header className="nav">
      <a className="brand" href="#top">
        <img src="/logo.png" alt="" width="28" height="28" />
        SpotiVibe
      </a>
      <nav className="nav__links" aria-label="Sections">
        <a href="#studio">Studio</a>
        <a href="#styles">Styles</a>
        <a href="#how">How it works</a>
      </nav>
      <a className="btn btn--small" href="#download">Download</a>
    </header>
  )
}

function Hero() {
  const head = useKaraoke(HERO_LINES.length, 1900)
  const cardHead = useKaraoke(3)
  const track = TRACKS[1]

  return (
    <section className="hero" id="top">
      <div className="hero__copy">
        <p className="now-playing">
          <span className="eq" aria-hidden="true"><i /><i /><i /></span>
          Lyric cards &amp; videos for Spotify
        </p>
        <h1 className="hero__title">
          <span className="sr-only">{HERO_LINES.join(' ')}</span>
          {HERO_LINES.map((line, i) => {
            const state = i === head.index ? 'active' : i < head.index ? 'past' : 'future'
            return (
              <span
                key={line}
                aria-hidden="true"
                className={`hero__line hero__line--${state}`}
                style={state === 'active' ? { '--fill': `${head.progress * 100}%` } : undefined}
              >
                {line}
              </span>
            )
          })}
        </h1>
        <p className="hero__lede">
          SpotiVibe picks up whatever you're playing, pulls the synced lyrics, and turns your favourite lines
          into a card or a karaoke-style video. One tap and it's on your Instagram Story.
        </p>
        <div className="hero__cta">
          <a className="btn" href="#download">Get SpotiVibe, it's free</a>
          <a className="btn btn--ghost" href="#studio">Try it in your browser</a>
        </div>
      </div>

      <div className="hero__visual" aria-hidden="true">
        <div className="phone">
          <Card track={track} lines={track.lyrics.slice(0, 3)} style="aura" playhead={cardHead} />
        </div>
        <div className="sticker">
          <img src={track.art} alt="" />
          <span>
            <b>{track.title}</b>
            {track.artist}
          </span>
          <span className="eq eq--small"><i /><i /><i /></span>
        </div>
      </div>
    </section>
  )
}

const Studio = forwardRef(function Studio({ styleId, setStyleId }, ref) {
  const [trackId, setTrackId] = useState(TRACKS[0].id)
  const [ratio, setRatio] = useState('story')
  const [mode, setMode] = useState('video')
  const [text, setText] = useState({ align: null, font: 'auto', color: null, effect: 'none' })
  const [backdrop, setBackdrop] = useState(null)
  const [edited, setEdited] = useState(null)
  const [status, setStatus] = useState('')
  const exportRef = useRef(null)

  const track = TRACKS.find((t) => t.id === trackId)
  const lines = edited ?? track.lyrics.slice(0, 3)
  const playhead = useKaraoke(lines.length)

  const pickTrack = (id) => {
    setTrackId(id)
    setEdited(null)
  }

  const onBackdrop = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith('image/')) return setStatus('Pick an image file (JPG, PNG or HEIC).')
    setBackdrop(URL.createObjectURL(file))
    setStatus('')
  }

  const download = async () => {
    setStatus('Rendering…')
    try {
      await exportPng(exportRef.current, { track, style: styleId, ratio })
      setStatus('Saved to your downloads.')
      if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        confetti({ particleCount: 70, spread: 60, origin: { y: 0.8 }, colors: ['#FA2E70', '#FA9433', '#F6EFE6'] })
      }
    } catch {
      setStatus("Couldn't render the PNG. Try another style or remove the background photo.")
    }
  }

  const patch = (p) => setText((t) => ({ ...t, ...p }))

  return (
    <section className="studio" id="studio" ref={ref} aria-labelledby="studio-title">
      <div className="section-head">
        <p className="eyebrow">Studio</p>
        <h2 id="studio-title">Make one right here.</h2>
        <p>The same editor that's in the app, minus the Spotify login. Pick a song, a look, and download a PNG.</p>
      </div>

      <div className="studio__grid">
        <div className="studio__stage">
          <div className="stage">
            <Card
              track={track}
              lines={lines}
              style={styleId}
              ratio={ratio}
              text={text}
              backdrop={backdrop}
              playhead={mode === 'video' ? playhead : null}
            />
          </div>
          {/* full-size, static copy that the PNG is rendered from */}
          <div className="export-host" aria-hidden="true">
            <Card ref={exportRef} track={track} lines={lines} style={styleId} ratio={ratio} text={text} backdrop={backdrop} />
          </div>
          <div className="seg" role="radiogroup" aria-label="Preview">
            {['photo', 'video'].map((m) => (
              <button key={m} role="radio" aria-checked={mode === m} onClick={() => setMode(m)}>
                {m === 'photo' ? 'Photo' : 'Video'}
              </button>
            ))}
          </div>
        </div>

        <div className="studio__panel">
          <Field label="Song">
            <div className="songs">
              {TRACKS.map((t) => (
                <button key={t.id} className="song" aria-pressed={t.id === trackId} onClick={() => pickTrack(t.id)}>
                  <img src={t.art} alt="" />
                  <span>
                    <b>{t.title}</b>
                    {t.artist}
                  </span>
                </button>
              ))}
            </div>
          </Field>

          <Field label="Style">
            <div className="chips">
              {STYLES.map((s) => (
                <button key={s.id} className="chip" aria-pressed={s.id === styleId} onClick={() => setStyleId(s.id)}>
                  {s.name}
                </button>
              ))}
            </div>
          </Field>

          <Field label="Size">
            <div className="chips">
              {RATIOS.map((r) => (
                <button key={r.id} className="chip" aria-pressed={r.id === ratio} onClick={() => setRatio(r.id)}>
                  <span className="mono">{r.label}</span> {r.name}
                </button>
              ))}
            </div>
          </Field>

          <Field label="Text">
            <div className="chips">
              {[['left', '⟸'], ['center', '⟺'], ['right', '⟹']].map(([a]) => (
                <button
                  key={a}
                  className="chip chip--icon"
                  aria-pressed={text.align === a}
                  aria-label={`Align ${a}`}
                  onClick={() => patch({ align: text.align === a ? null : a })}
                >
                  <AlignIcon align={a} />
                </button>
              ))}
              {FONTS.map((f) => (
                <button
                  key={f.id}
                  className="chip"
                  style={f.css ? { fontFamily: f.css } : undefined}
                  aria-pressed={text.font === f.id}
                  onClick={() => patch({ font: f.id })}
                >
                  {f.name}
                </button>
              ))}
            </div>
            <div className="swatches">
              <button className="swatch swatch--none" aria-pressed={!text.color} aria-label="Default color" onClick={() => patch({ color: null })} />
              {SWATCHES.map((c) => (
                <button
                  key={c}
                  className="swatch"
                  style={{ background: c }}
                  aria-pressed={text.color === c}
                  aria-label={`Color ${c}`}
                  onClick={() => patch({ color: c })}
                />
              ))}
            </div>
            <div className="chips">
              {['none', 'glow', 'shadow'].map((e) => (
                <button key={e} className="chip" aria-pressed={text.effect === e} onClick={() => patch({ effect: e })}>
                  {e === 'none' ? 'No effect' : e[0].toUpperCase() + e.slice(1)}
                </button>
              ))}
            </div>
          </Field>

          <Field label="Lyrics" hint="One line per row, up to 6.">
            <textarea
              rows={4}
              value={lines.join('\n')}
              onChange={(e) => {
                const next = e.target.value.split('\n').slice(0, 6)
                setEdited(next.some((l) => l.trim()) ? next : [''])
              }}
            />
          </Field>

          <Field label="Background photo">
            <div className="row">
              <label className="btn btn--ghost btn--small file">
                Choose photo
                <input type="file" accept="image/*" onChange={onBackdrop} />
              </label>
              {backdrop && (
                <button className="link" onClick={() => setBackdrop(null)}>Remove</button>
              )}
            </div>
          </Field>

          <button className="btn btn--block" onClick={download}>Download PNG</button>
          <p className="status" role="status">{status}</p>
        </div>
      </div>
    </section>
  )
})

function Field({ label, hint, children }) {
  return (
    <fieldset className="field">
      <legend>
        {label}
        {hint && <span>{hint}</span>}
      </legend>
      {children}
    </fieldset>
  )
}

function AlignIcon({ align }) {
  const rows = { left: [16, 10, 14], center: [16, 10, 14], right: [16, 10, 14] }[align]
  return (
    <svg width="18" height="14" viewBox="0 0 18 14" aria-hidden="true">
      {rows.map((w, i) => {
        const x = align === 'left' ? 1 : align === 'right' ? 17 - w : (18 - w) / 2
        return <rect key={i} x={x} y={1 + i * 5} width={w} height="2" rx="1" fill="currentColor" />
      })}
    </svg>
  )
}

function Styles({ onPick }) {
  const track = TRACKS[0]
  const head = useKaraoke(2, 2200)
  return (
    <section className="styles" id="styles" aria-labelledby="styles-title">
      <div className="section-head">
        <p className="eyebrow">10 styles</p>
        <h2 id="styles-title">Pick a mood, not a template.</h2>
        <p>Every style works for photos and videos. Tap one to open it in the studio.</p>
      </div>
      <ul className="gallery">
        {STYLES.map((s) => (
          <li key={s.id}>
            <button className="gallery__item" onClick={() => onPick(s.id)}>
              <div className="gallery__card" aria-hidden="true">
                <Card track={track} lines={track.lyrics.slice(0, 2)} style={s.id} ratio="portrait" playhead={head} />
              </div>
              <span className="gallery__name">{s.name}</span>
              <span className="gallery__blurb">{s.blurb}</span>
            </button>
          </li>
        ))}
      </ul>
    </section>
  )
}

// a real sequence, so it reads as a tracklist with step timestamps
const STEPS = [
  ['0:00', 'Play a song on Spotify', 'Connect once. SpotiVibe follows what you play, or search any song yourself.'],
  ['0:15', 'Pick the lines', 'Synced lyrics come in automatically. Choose up to 8 lines in a row.'],
  ['0:30', 'Make it yours', 'Choose a style, font, color, and your own photo or video clip behind it.'],
  ['0:45', 'Post it', 'Send straight to Instagram Stories, save to Photos, or share anywhere.'],
]

function HowItWorks() {
  return (
    <section className="how" id="how" aria-labelledby="how-title">
      <div className="section-head">
        <p className="eyebrow">How it works</p>
        <h2 id="how-title">Under a minute, start to story.</h2>
      </div>
      <ol className="tracklist">
        {STEPS.map(([time, title, body], i) => (
          <li key={title}>
            <span className="tracklist__n">{i + 1}</span>
            <div>
              <h3>{title}</h3>
              <p>{body}</p>
            </div>
            <span className="tracklist__time">{time}</span>
          </li>
        ))}
      </ol>
    </section>
  )
}

const FEATURES = [
  ['Karaoke-style video', 'Each line fills in as it’s sung, timed from synced lyrics. Export as MP4.'],
  ['Your clip, trimmed', 'Use a photo or a video behind the lyrics. Trim it like in WhatsApp; short clips loop.'],
  ['Share from Photos', 'Share any photo or video to SpotiVibe from your gallery and start from there.'],
  ['No password, no server', 'Spotify login uses PKCE. Everything renders on your phone.'],
]

function Features() {
  return (
    <section className="features" aria-label="Features">
      {FEATURES.map(([title, body]) => (
        <div key={title} className="feature">
          <h3>{title}</h3>
          <p>{body}</p>
        </div>
      ))}
    </section>
  )
}

function Download() {
  return (
    <section className="download" id="download" aria-labelledby="download-title">
      <h2 id="download-title">
        Put the <em>words</em> on it.
      </h2>
      <p>Free. No account needed to try it; connect Spotify when you want your own songs.</p>
      <div className="download__options">
        <a className="platform" href={APK_URL} download>
          <AndroidIcon />
          <span>
            <b>Android</b>
            APK · {APK_SIZE} · Android 8+
          </span>
          <span className="platform__go" aria-hidden="true">↓</span>
        </a>
        <div className="platform platform--soon">
          <AppleIcon />
          <span>
            <b>iPhone</b>
            iOS 16+ · App Store coming soon
          </span>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="footer">
      <div className="brand">
        <img src="/logo.png" alt="" width="24" height="24" />
        SpotiVibe
      </div>
      <nav aria-label="Credits">
        <a href="https://lrclib.net" target="_blank" rel="noopener noreferrer">Lyrics by LRCLIB</a>
        <a href="https://developer.spotify.com" target="_blank" rel="noopener noreferrer">Spotify Web API</a>
        <a href="https://github.com/nannndev/OpenNotchi" target="_blank" rel="noopener noreferrer">OpenNotchi</a>
      </nav>
      <p>© 2026 SpotiVibe. Not affiliated with Spotify AB.</p>
    </footer>
  )
}

function AndroidIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M17.52 15.34a1 1 0 1 1 0-2 1 1 0 0 1 0 2m-11.04 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2m11.4-6.02 2-3.46a.42.42 0 0 0-.72-.41l-2.03 3.5A12.4 12.4 0 0 0 12 8.12c-1.86 0-3.59.29-5.14 1L4.84 5.45a.42.42 0 0 0-.72.41l2 3.46A11.6 11.6 0 0 0 0 19h24a11.6 11.6 0 0 0-6.12-9.68" />
    </svg>
  )
}

function AppleIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.61-.75 1.04-1.8.92-2.85-.9.04-2 .6-2.65 1.35-.58.66-1.09 1.74-.95 2.76 1.01.08 2.07-.51 2.68-1.26z" />
    </svg>
  )
}
