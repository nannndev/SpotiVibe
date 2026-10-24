import { useEffect, useState } from 'react'

const reduceMotion = () =>
  typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches

/**
 * Loops through `count` lines, returning which one is "being sung" and how far into it (0…1),
 * the same playhead the apps use for the karaoke fill.
 */
export function useKaraoke(count, msPerLine = 2600) {
  const [head, setHead] = useState({ index: 0, progress: 0 })

  useEffect(() => {
    if (count <= 0) return
    if (reduceMotion()) {
      // no sweep: show each full line, change slowly
      let i = 0
      setHead({ index: 0, progress: 1 })
      const id = setInterval(() => setHead({ index: (i = (i + 1) % count), progress: 1 }), 4000)
      return () => clearInterval(id)
    }
    let raf
    const start = performance.now()
    const tick = (now) => {
      const t = (now - start) / msPerLine
      setHead({ index: Math.floor(t) % count, progress: t % 1 })
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [count, msPerLine])

  return head
}
