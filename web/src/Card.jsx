import { forwardRef } from 'react'
import { FONTS } from './data.js'

const SIZES = { story: [360, 640], portrait: [360, 450], square: [360, 360] }
const LIGHT = new Set(['paper', 'polaroid', 'receipt'])

/** Web port of the app's LyricCardView: same 10 styles, same karaoke playhead. */
export const Card = forwardRef(function Card(
  { track, lines, style = 'aura', ratio = 'story', text = {}, playhead = null, backdrop = null },
  ref
) {
  const [w, h] = SIZES[ratio]
  const font = FONTS.find((f) => f.id === text.font)?.css
  const vars = {
    width: w,
    height: h,
    '--art': `url(${track.art})`,
    '--ink': text.color || null,
    '--lyric-font': font || null,
    '--lyric-align': text.align || null,
  }
  const size = lineSize(lines)
  const lyricProps = { lines, playhead, size, effect: text.effect || 'none' }

  return (
    <div ref={ref} className={`card card--${style}`} style={vars} data-light={LIGHT.has(style) || undefined}>
      <div className="card__bg" style={backdrop ? { backgroundImage: `url(${backdrop})` } : undefined} />
      <Layout style={style} track={track} lyricProps={lyricProps} playhead={playhead} />
    </div>
  )
})

function lineSize(lines) {
  const chars = lines.join('').length
  return chars > 220 ? 15 : chars > 150 ? 18 : chars > 80 ? 21 : 24
}

function Layout({ style, track, lyricProps, playhead }) {
  const spinning = playhead ? 'is-playing' : ''
  switch (style) {
    case 'player':
      return (
        <div className="lay lay--player">
          <img className="art art--xl" src={track.art} alt="" crossOrigin="anonymous" />
          <div className="meta meta--center">
            <b>{track.title}</b>
            <span>{track.artist}</span>
          </div>
          <Lyrics {...lyricProps} align="center" />
          <div className="player-bar">
            <div className="player-bar__track">
              <i style={{ width: `${playhead ? 20 + playhead.index * 15 + playhead.progress * 15 : 38}%` }} />
            </div>
            <div className="player-bar__time">
              <span>1:12</span>
              <span>3:50</span>
            </div>
          </div>
          <Footer />
        </div>
      )
    case 'vhs':
      return (
        <div className="lay lay--vhs">
          <div className="vhs-osd">
            <span>PLAY ▶</span>
            <span>SP 0:04:22</span>
          </div>
          <Lyrics {...lyricProps} upper />
          <div className="vhs-foot">
            <span>{track.title.toUpperCase()}</span>
            <span>{track.artist.toUpperCase()}</span>
          </div>
        </div>
      )
    case 'cassette':
      return (
        <div className="lay">
          <Header track={track} />
          <div className="cassette">
            <div className="cassette__label">
              <span className="cassette__side">SIDE A</span>
              <span className="cassette__title">{track.title}</span>
              <span>C-60</span>
            </div>
            <div className="cassette__window">
              <i className={`reel ${spinning}`} />
              <i className="cassette__tape" />
              <i className={`reel ${spinning}`} />
            </div>
          </div>
          <Lyrics {...lyricProps} />
          <Footer />
        </div>
      )
    case 'vinyl':
      return (
        <div className="lay">
          <Header track={track} />
          <div className="vinyl">
            <img className="vinyl__sleeve" src={track.art} alt="" crossOrigin="anonymous" />
            <div className={`vinyl__disc ${spinning}`}>
              <img src={track.art} alt="" crossOrigin="anonymous" />
            </div>
          </div>
          <Lyrics {...lyricProps} />
          <Footer />
        </div>
      )
    case 'glass':
      return (
        <div className="lay lay--glass">
          <div className="glass-pill">
            <img src={track.art} alt="" crossOrigin="anonymous" />
            <span>
              <b>{track.title}</b>
              {track.artist}
            </span>
          </div>
          <div className="glass-panel">
            <Lyrics {...lyricProps} />
          </div>
          <Footer />
        </div>
      )
    case 'polaroid':
      return (
        <div className="lay lay--polaroid">
          <div className="polaroid">
            <img src={track.art} alt="" crossOrigin="anonymous" />
            <Lyrics {...lyricProps} lines={lyricProps.lines.slice(0, 3)} size={Math.min(lyricProps.size * 0.7, 15)} />
            <span className="polaroid__by">— {track.artist}</span>
          </div>
          <Footer />
        </div>
      )
    case 'receipt':
      return (
        <div className="lay lay--receipt">
          <div className="receipt">
            <p className="receipt__head">*** SPOTIVIBE ARCHIVE ***</p>
            <p className="receipt__row">
              <span>{track.title.toUpperCase()}</span>
              <span>{track.artist.toUpperCase()}</span>
            </p>
            <p className="receipt__rule" />
            <Lyrics {...lyricProps} numbered size={Math.min(lyricProps.size, 13)} />
            <p className="receipt__rule" />
            <div className="receipt__barcode" aria-hidden="true">
              {Array.from({ length: 30 }, (_, i) => (
                <i key={i} style={{ width: i % 3 === 0 ? 3 : i % 5 === 0 ? 4 : 1.5 }} />
              ))}
            </div>
            <p className="receipt__thanks">THANK YOU FOR LISTENING</p>
          </div>
        </div>
      )
    default: // aura, paper, solid
      return (
        <div className="lay">
          <Header track={track} />
          {style === 'paper' && <span className="paper-quote">“</span>}
          <Lyrics {...lyricProps} />
          <Footer />
        </div>
      )
  }
}

function Header({ track }) {
  return (
    <div className="card-head">
      <img className="art" src={track.art} alt="" crossOrigin="anonymous" />
      <div className="meta">
        <b>{track.title}</b>
        <span>{track.artist}</span>
      </div>
    </div>
  )
}

function Footer() {
  return <div className="card-foot">SpotiVibe</div>
}

/** Photo: static lines. Video: past lines dim, the active one pops in and fills left→right. */
function Lyrics({ lines, playhead, size, effect, align, upper, numbered }) {
  return (
    <div className={`lyrics fx-${effect}`} style={{ fontSize: size, '--lyric-default-align': align }}>
      {lines.map((line, i) => {
        const text = upper ? line.toUpperCase() : line
        let state = 'static'
        let style
        if (playhead) {
          state = i === playhead.index ? 'active' : i < playhead.index ? 'past' : 'future'
          if (state === 'active') {
            const pop = 1 - Math.pow(1 - Math.min(playhead.progress * 5, 1), 3)
            style = {
              '--fill': `${playhead.progress * 100}%`,
              transform: `translateY(${6 * (1 - pop)}px) scale(${1 + 0.06 * pop})`,
            }
          }
        }
        return (
          <p key={i} className={`line line--${state}`} style={style}>
            {numbered && <span className="line__num">{state === 'active' ? '►' : String(i + 1).padStart(2, '0')}</span>}
            <span className="line__text">{text}</span>
          </p>
        )
      })}
    </div>
  )
}
