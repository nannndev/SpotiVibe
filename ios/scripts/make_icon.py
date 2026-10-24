"""Generate SpotiVibe app icons (light, dark, tinted) into AppIcon.appiconset.
Run: python3 ios/scripts/make_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "SpotiVibe/Resources/Assets.xcassets/AppIcon.appiconset"
S = 1024
SS = 4  # supersample for antialiasing
N = S * SS

PINK = (250, 46, 112)    # Color(0.98, 0.18, 0.44)
ORANGE = (250, 148, 51)  # Color(0.98, 0.58, 0.20)
INK = (13, 13, 18)       # app background


def gradient(a, b):
    """Diagonal gradient top-left -> bottom-right."""
    # rotate an oversized square and crop its inscribed centre so no corners are empty
    g = Image.linear_gradient("L").resize((363, 363)).rotate(45, Image.BICUBIC).crop((53, 53, 309, 309)).resize((N, N))
    return Image.composite(Image.new("RGB", (N, N), b), Image.new("RGB", (N, N), a), g)


def glyph(fill, cutout):
    """Speech bubble with equalizer bars: 'lyrics' + 'vibe'. Returns RGBA layer."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    u = N / 1024
    # bubble body + tail
    d.rounded_rectangle([212 * u, 232 * u, 812 * u, 712 * u], radius=150 * u, fill=fill)
    d.polygon([(300 * u, 660 * u), (276 * u, 830 * u), (450 * u, 700 * u)], fill=fill)
    # equalizer bars cut out of the bubble
    heights = [120, 230, 300, 190, 260]
    bw, gap = 54, 30
    x0 = 512 - (len(heights) * bw + (len(heights) - 1) * gap) / 2
    for i, h in enumerate(heights):
        x = x0 + i * (bw + gap)
        d.rounded_rectangle([x * u, (472 - h / 2) * u, (x + bw) * u, (472 + h / 2) * u],
                            radius=bw / 2 * u, fill=cutout)
    return layer


def save(img, name):
    img.resize((S, S), Image.LANCZOS).save(OUT / name)


mask = glyph((255, 255, 255, 255), (0, 0, 0, 0)).getchannel("A")

# Light: brand gradient bg, white bubble, bars show the gradient through
light = gradient(PINK, ORANGE)
light.paste((255, 255, 255), (0, 0), mask)
save(light, "AppIcon.png")

# Dark: ink bg, gradient bubble, ink bars
dark = Image.new("RGB", (N, N), INK)
dark.paste(gradient(PINK, ORANGE), (0, 0), mask)
save(dark, "AppIcon-Dark.png")

# Tinted: grayscale glyph on black, iOS applies the tint
tint = Image.new("RGB", (N, N), (0, 0, 0))
tint.paste((255, 255, 255), (0, 0), mask)
save(tint, "AppIcon-Tinted.png")

print("wrote icons to", OUT)
