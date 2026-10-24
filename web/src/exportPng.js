import { toPng } from 'html-to-image'
import { RATIOS } from './data.js'

/** Renders the hidden full-size card node to a 1080px-wide PNG and downloads it. */
export async function exportPng(node, { track, style, ratio }) {
  const { w } = RATIOS.find((r) => r.id === ratio)
  const url = await toPng(node, { pixelRatio: w / node.offsetWidth, cacheBust: true })
  const a = document.createElement('a')
  a.download = `SpotiVibe_${track.title.replace(/\W+/g, '_')}_${style}.png`
  a.href = url
  a.click()
}
