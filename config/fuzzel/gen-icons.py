#!/usr/bin/env python3
"""Makes single-colour SVG icons from Lucide font glyphs (requires: pip install fonttools).
Usage: gen-icons.py <font.ttf> <name> [<name>...]   → icons/<name>.svg
The colour is Fuzzel's text colour (#aea3b5), same as the top bar icons."""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

COLOR = "#aea3b5"
font = TTFont(sys.argv[1])
glyphs = font.getGlyphSet()
names = set(font.getGlyphOrder())
upm = font["head"].unitsPerEm
out = os.path.join(os.path.dirname(os.path.realpath(__file__)), "icons")
os.makedirs(out, exist_ok=True)
for name in sys.argv[2:]:
    if name not in names:
        sys.exit(f"glyph not found: {name}")
    pen = SVGPathPen(glyphs)
    glyphs[name].draw(pen)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {upm} {upm}" width="64" height="64">'
           f'<path transform="translate(0,{upm}) scale(1,-1)" fill="{COLOR}" d="{pen.getCommands()}"/></svg>\n')
    open(os.path.join(out, name + ".svg"), "w").write(svg)
    print("wrote", name)
