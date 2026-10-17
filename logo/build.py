"""Builds the Nightdrive logo and icon SVGs with the glyphs outlined (no font needed to view them).
Needs fonttools (pip install fonttools) and the JetBrains Mono fonts; writes next to this file: python3 build.py"""
import os
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONTS = "/usr/share/fonts/jetbrains-mono-fonts/"
out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))


def outline(font_file, text, size, tracking, x0, baseline):
    """Path data for text at size px, letter-spacing tracking em; returns (d, advance incl. trailing spacing)."""
    f = TTFont(FONTS + font_file)
    gs = f.getGlyphSet()
    cmap = f.getBestCmap()
    upm = f["head"].unitsPerEm
    s = size / upm
    pen = SVGPathPen(gs, lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
    x = x0
    for ch in text:
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline)))
        x += gs[g].width * s + tracking * size
    return pen.getCommands(), x - x0


def line_box(font_file, size):
    """CSS line-height: 1 → the em box's top relative to the baseline (negative = above)."""
    f = TTFont(FONTS + font_file)
    upm, a, d = f["head"].unitsPerEm, f["hhea"].ascent, f["hhea"].descent
    half = (upm - (a - d)) / 2
    return -(a + half) / upm * size


# --- Wordmark: A on the canvas (the website's logo, big) ---
size, pad = 112, 16
top = line_box("JetBrainsMono-Bold.otf", size)      # em box top vs baseline
baseline = pad - top
d, adv = outline("JetBrainsMono-Bold.otf", "Nightdrive", size, -0.04, pad, baseline)
cx = pad + adv + 0.12 * size
cw, ch = 0.55 * size, size
W, H = cx + cw + pad, size + 2 * pad
gradient = f'''
  <defs>
    <linearGradient id="t" gradientUnits="userSpaceOnUse" x1="{pad}" y1="0" x2="{pad + adv:.1f}" y2="0">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="0.4" stop-color="#e0bff2"/>
      <stop offset="1" stop-color="#c071eb"/>
    </linearGradient>
  </defs>'''


def wordmark(name, text_fill, cursor_fill, defs=""):
    open(f"{out}/{name}", "w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" width="{W:.0f}" height="{H:.0f}" role="img" aria-label="Nightdrive">{defs}
  <path fill="{text_fill}" d="{d}"/>
  <rect x="{cx:.1f}" y="{pad}" width="{cw:.1f}" height="{ch:.1f}" fill="{cursor_fill}"/>
</svg>
''')


wordmark("nightdrive-logo.svg", "url(#t)", "#c071eb", gradient)   # on dark backgrounds
wordmark("nightdrive-logo-white.svg", "#ffffff", "#ffffff")       # on photos and colour
wordmark("nightdrive-logo-ink.svg", "#120c24", "#a54fd6")         # on light backgrounds


# --- Icon: E on the canvas, N + cursor in a rounded square ---
def icon(name, box, radius, border, size, font_file, gap, cur_w, cur_h, n_fill, flat):
    top = line_box(font_file, size)
    f = TTFont(FONTS + font_file)
    gs, cmap = f.getGlyphSet(), f.getBestCmap()
    n_adv = gs[cmap[ord("N")]].width * size / f["head"].unitsPerEm
    group_w = n_adv + gap * size + cur_w * size
    x0 = (box - group_w) / 2
    y0 = (box - size) / 2                       # em box top, centred
    d, _ = outline(font_file, "N", size, 0, x0, y0 - top)
    cx = x0 + n_adv + gap * size
    cy = y0 + (size - cur_h * size) / 2
    bg = '"#161028"' if flat else '"url(#bg)"'
    defs = "" if flat else f'''
    <linearGradient id="bg" x1="0.33" y1="0.03" x2="0.67" y2="0.97">
      <stop offset="0" stop-color="#1d1533"/>
      <stop offset="1" stop-color="#120c24"/>
    </linearGradient>
    <linearGradient id="n" gradientUnits="userSpaceOnUse" x1="{x0:.1f}" y1="0" x2="{x0 + n_adv:.1f}" y2="0">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#e0bff2"/>
    </linearGradient>'''
    b = border / 2
    open(f"{out}/{name}", "w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box} {box}" width="{box}" height="{box}" role="img" aria-label="Nightdrive">
  <defs>{defs}
  </defs>
  <rect x="{b}" y="{b}" width="{box - border}" height="{box - border}" rx="{radius - b}" fill={bg} stroke="#2c2242" stroke-width="{border}"/>
  <path fill="{n_fill}" d="{d}"/>
  <rect x="{cx:.1f}" y="{cy:.1f}" width="{cur_w * size:.1f}" height="{cur_h * size:.1f}" fill="#c071eb"/>
</svg>
''')


icon("nightdrive-icon.svg", 200, 46, 2, 120, "JetBrainsMono-Bold.otf", 0.06, 0.42, 0.74, "url(#n)", False)
# Full-bleed square for platforms that round the corners themselves (apple-touch-icon): no corners, no border
icon("nightdrive-icon-square.svg", 200, 0, 0, 120, "JetBrainsMono-Bold.otf", 0.06, 0.42, 0.74, "url(#n)", False)
# Small sizes (favicon, ≤ 32 px): heavier N, flat colours
icon("nightdrive-icon-small.svg", 32, 8, 1, 19, "JetBrainsMono-ExtraBold.otf", 0.06, 0.42, 0.74, "#ece6f5", True)


# --- GIFs: the wordmarks with a blinking cursor (need ImageMagick; skipped without it) ---
# The gradient one sits on Night; white and ink are transparent, to go on any background they suit
# (GIF transparency is on/off, so their edges are hard where the PNGs' are smooth).
import shutil
import subprocess


def gif(name, cursor_fill, bg):
    svg = open(f"{out}/{name}.svg").read()
    off = svg.replace(f'fill="{cursor_fill}"/>\n</svg>', 'fill="none"/>\n</svg>')   # the same logo, cursor off
    assert off != svg
    open(f"{out}/.logo-off.svg", "w").write(off)
    frames = []
    for state, src in (("on", f"{name}.svg"), ("off", ".logo-off.svg")):
        frames.append(f"{out}/.logo-{state}.png")
        subprocess.run(["magick", "-background", bg, "-density", "192", f"{out}/{src}",
                        "-bordercolor", bg, "-compose", "Copy", "-border", "48", frames[-1]], check=True)
    # The website's 1.1 s blink: half on, half off
    subprocess.run(["magick", "-delay", "55", "-loop", "0", "-dispose", "Background", *frames,
                    "-layers", "Optimize", f"{out}/{name}.gif"], check=True)
    for f in frames + [f"{out}/.logo-off.svg"]:
        os.remove(f)


if shutil.which("magick"):
    gif("nightdrive-logo", "#c071eb", "#0a0716")
    gif("nightdrive-logo-white", "#ffffff", "none")
    gif("nightdrive-logo-ink", "#a54fd6", "none")
