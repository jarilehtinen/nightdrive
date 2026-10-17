#!/usr/bin/env python3
"""Builds lucide.ttf with thinner strokes: lucide-thin.ttf (1.25, Icons.familyThin), lucide-light.ttf (1.5,
Icons.familyLight: the launcher's list icons and chevrons) and lucide-medium.ttf (1.75, Icons.familyMedium: its player buttons).

The Lucide font has the stroke (2) baked in, so this redraws every glyph from the same lucide-static release's SVGs with
another stroke width. The code points, glyph names and metrics are copied from lucide.ttf, so Icons.g() works for both.
Glyphs without an SVG keep their original outline. It also rewrites lucide.ttf itself with the bearings fixed (below).

    python3 -m venv /tmp/v && /tmp/v/bin/pip install picosvg fonttools
    /tmp/v/bin/python3 fonts/build-lucide-strokes.py            # → fonts/lucide-{thin,light,medium}.ttf

Use the lucide-static version of lucide.ttf (Icons.qml says which); update both fonts together.
"""
import io, json, re, tarfile, urllib.request
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from picosvg.svg import SVG

VERSION = "1.57.0"
FONTS = [(None, "lucide", "lucide.ttf"), ("1.25", "lucide thin", "lucide-thin.ttf"), ("1.5", "lucide light", "lucide-light.ttf"),
         # stroke (None: keep the outlines), family, file
         ("1.75", "lucide medium", "lucide-medium.ttf")]
here = Path(__file__).resolve().parent

url = f"https://registry.npmjs.org/lucide-static/-/lucide-static-{VERSION}.tgz"
tar = tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(url).read()))
read = lambda p: tar.extractfile(f"package/{p}").read()
svgs = {Path(m.name).stem: m.name for m in tar.getmembers() if m.name.startswith("package/icons/") and m.name.endswith(".svg")}
names = {}                                                   # code point → icon name (aliases share a code point)
for name, v in json.loads(read("font/info.json")).items():
    if name in svgs:
        names.setdefault(int(v["unicode"][2:-1]), name)

for STROKE, FAMILY, OUT in FONTS:
    font = TTFont(io.BytesIO(read("font/lucide.ttf")))
    glyf = font["glyf"]
    S = 1000 / 24                                                # 24×24 viewBox → 1000 units, y up
    done = 0
    for cp, gname in font.getBestCmap().items():
        if STROKE is None or cp not in names:
            continue
        src = tar.extractfile(svgs[names[cp]]).read().decode()
        src = re.sub(r"<!--.*?-->", "", src, flags=re.S).replace('stroke-width="2"', f'stroke-width="{STROKE}"')
        tt = TTGlyphPen(None)
        pen = TransformPen(Cu2QuPen(tt, max_err=0.5, reverse_direction=True), (S, 0, 0, -S, 0, 1000))
        for el in SVG.fromstring(src).topicosvg().xpath("//svg:path"):   # picosvg turns the strokes into filled outlines
            parse_path(el.get("d"), pen)
        glyf[gname] = tt.glyph()
        glyf[gname].recalcBounds(glyf)
        done += 1

    # lucide-static's font has every left side bearing at 0, so FreeType moves each glyph left by its xMin: narrow
    # icons (bluetooth) sat further left than wide ones. The real bearing centres them all in their 1000-unit advance.
    for gname in font.getGlyphOrder():
        adv, _ = font["hmtx"][gname]
        glyf[gname].recalcBounds(glyf)                        # lucide-static's glyph headers say xMin 0 too: measure the outline
        font["hmtx"][gname] = (adv, getattr(glyf[gname], "xMin", 0))

    for rec in font["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = FAMILY
        elif rec.nameID == 6:
            rec.string = FAMILY.replace(" ", "-")
    font["maxp"].recalc(font)
    font.save(here / OUT)
    print(f"{OUT}: {done} glyphs redrawn at stroke {STROKE}")
