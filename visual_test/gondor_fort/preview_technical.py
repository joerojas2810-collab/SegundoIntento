#!/usr/bin/env python3
"""Technical previews for the converted Gondor Fort.

These images are NOT game screenshots.  They are orthographic projections and
cutaways drawn from the converted .mts, using the real Mineclonia textures.
They exist to make the geometry reviewable while a real Luanti client is not
available in this environment.

The preview intentionally renders stairs/slabs as full blocks and omits
non-cube decoration (torches, ladders, fences).  It is a geometry/material
aid, not an in-game lighting or collision test.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import convert_gondor_fort as conv

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent

TEX = {
    "mcl_core:stonebrick": "mods/ITEMS/mcl_core/textures/default_stone_brick.png",
    "mcl_core:stonebrickcracked": "mods/ITEMS/mcl_core/textures/mcl_core_stonebrick_cracked.png",
    "mcl_core:stonebrickmossy": "mods/ITEMS/mcl_core/textures/mcl_core_stonebrick_mossy.png",
    "mcl_core:stonebrickcarved": "mods/ITEMS/mcl_core/textures/mcl_core_stonebrick_carved.png",
    "mcl_core:cobble": "mods/ITEMS/mcl_core/textures/default_cobble.png",
    "mcl_core:wood": "mods/ITEMS/mcl_core/textures/default_wood.png",
    "mcl_trees:wood_oak": "mods/ITEMS/mcl_core/textures/default_wood.png",
    "mcl_stairs:stair_stonebrick": "mods/ITEMS/mcl_core/textures/default_stone_brick.png",
    "mcl_stairs:slab_stonebrick": "mods/ITEMS/mcl_core/textures/default_stone_brick.png",
    "mcl_beds:bed_blue_bottom": "mods/ITEMS/mcl_beds/textures/mcl_beds_bed_blue.png",
    "mcl_beds:bed_blue_top": "mods/ITEMS/mcl_beds/textures/mcl_beds_bed_blue.png",
    "mcl_beds:bed_red_bottom": "mods/ITEMS/mcl_beds/textures/mcl_beds_bed_red.png",
    "mcl_beds:bed_red_top": "mods/ITEMS/mcl_beds/textures/mcl_beds_bed_red.png",
    "mcl_chests:chest_small": "mods/ITEMS/mcl_chests/textures/mcl_chests_normal.png",
    "mcl_furnaces:furnace": "mods/ITEMS/mcl_furnaces/textures/default_furnace_front.png",
    "mcl_cauldrons:cauldron": "mods/ITEMS/mcl_cauldrons/textures/mcl_cauldrons_cauldron_side.png",
    "mcl_brewing:stand_000": "mods/ITEMS/mcl_brewing/textures/mcl_brewing_stand.png",
    "mcl_core:water_source": "mods/ITEMS/mcl_core/textures/default_water_source_animated.png",
}

# Decoration that is not a full cube; omitted from the preview (documented).
SKIP = {
    "mcl_core:ladder",
    "mcl_fences:oak_fence",
    "mcl_torches:torch_wall",
    "mcl_torches:torch",
}

def load_font(size, bold=False):
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else ""),
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


FONT = load_font(16)
FONT_SMALL = load_font(13)
FONT_TITLE = load_font(23, bold=True)
FONT_LABEL = load_font(14, bold=True)

SKY_TOP = (32, 45, 62)
SKY_BOTTOM = (118, 142, 163)
BAND = (20, 22, 26)
INK = (238, 232, 220)
ACCENT = (196, 156, 87)


def load_structure(path: Path):
    data = conv.read_mts(path)
    sx, sy, sz = data["size"]
    palette = data["palette"]
    grid = {}
    for i, cid in enumerate(data["cids"]):
        name = palette[cid]
        if name == "air" or name in SKIP:
            continue
        x = i % sx
        y = (i // sx) % sy
        z = i // (sx * sy)
        grid[(x, y, z)] = name
    return (sx, sy, sz), grid


def texture_for(name: str, size: int) -> Image.Image:
    path = TEX.get(name)
    if path:
        p = REPO / path
        if p.exists():
            im = Image.open(p).convert("RGBA")
            return im.resize((size, size), Image.Resampling.LANCZOS)
    # Fallback: a flat neutral colour, so a missing texture is obvious but not fatal.
    im = Image.new("RGBA", (size, size), (128, 120, 110, 255))
    return im


def shade(im: Image.Image, factor: float) -> Image.Image:
    if factor >= 0.999:
        return im
    r, g, b, a = im.split()
    r = r.point(lambda v: min(255, int(v * factor)))
    g = g.point(lambda v: min(255, int(v * factor)))
    b = b.point(lambda v: min(255, int(v * factor)))
    return Image.merge("RGBA", (r, g, b, a))


def sky(size, top=SKY_TOP, bottom=SKY_BOTTOM) -> Image.Image:
    w, h = size
    im = Image.new("RGB", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return im.convert("RGBA")


def add_frame(im: Image.Image, title: str, subtitle: str) -> Image.Image:
    import textwrap

    w, h = im.size
    margin = 28
    band_h = 118
    text_w = 620
    canvas_w = max(w + margin * 2, text_w + margin * 2, 760)
    out = Image.new("RGBA", (canvas_w, h + band_h + margin * 2 + 34), BAND)
    img_x = (canvas_w - w) // 2
    out.paste(im, (img_x, margin + 34))
    d = ImageDraw.Draw(out)
    d.text((margin, 10), title, font=FONT_TITLE, fill=INK)
    lines = textwrap.wrap(subtitle, width=88)
    for i, line in enumerate(lines[:2]):
        d.text((margin, 44 + i * 18), line, font=FONT_SMALL, fill=ACCENT)
    y0 = margin + 34 + h + 12
    d.text((margin, y0), "PREVISUALIZACION TECNICA - NO ES UNA CAPTURA DE LUANTI",
           font=FONT, fill=ACCENT)
    note = ("Geometria del .mts convertido + texturas reales de Mineclonia. "
            "Escaleras/losas como bloques; antorchas, escaleras de mano y vallas omitidas.")
    for i, line in enumerate(textwrap.wrap(note, width=100)[:2]):
        d.text((margin, y0 + 24 + i * 16), line, font=FONT_SMALL, fill=INK)
    return out


def elevation(size, grid, axis: str, scale=24, cut_min=None, annotate_gate=True):
    sx, sy, sz = size
    if axis == "front":
        w, h = sx * scale, sy * scale
        depth = sz
        def uv(a, b): return a, sy - 1 - b
        def key(d, a, b): return (a, b, d)
    elif axis == "back":
        w, h = sx * scale, sy * scale
        depth = sz
        def uv(a, b): return sx - 1 - a, sy - 1 - b
        def key(d, a, b): return (a, b, sz - 1 - d)
    elif axis == "side":
        w, h = sz * scale, sy * scale
        depth = sx
        def uv(a, b): return a, sy - 1 - b
        def key(d, a, b): return (a, b, d)
    else:
        w, h = sx * scale, sz * scale
        depth = sy
        def uv(a, b): return a, b
        def key(d, a, b): return (a, b, d)

    im = sky((w, h))
    draw = ImageDraw.Draw(im)
    for d in reversed(range(depth)):
        for a in range(sx if axis in ("front", "back") else sz):
            for b in range(sy if axis != "top" else sz):
                if axis == "front":
                    pos = (a, b, d)
                elif axis == "back":
                    pos = (a, b, sz - 1 - d)
                elif axis == "side":
                    pos = (d, b, a)
                else:
                    pos = (a, sy - 1 - d, b)
                name = grid.get(pos)
                if not name:
                    continue
                u, v = uv(a, b)
                tex = texture_for(name, scale)
                if axis in ("front", "back"):
                    tex = shade(tex, 1.0 - min(0.55, d * 0.075))
                elif axis == "side":
                    tex = shade(tex, 1.0 - min(0.42, d * 0.045))
                else:
                    tex = shade(tex, 1.12)
                im.alpha_composite(tex, (u * scale, v * scale))
    if axis == "front" and annotate_gate:
        d = ImageDraw.Draw(im)
        gx0, gx1 = 8 * scale, 11 * scale
        gy0 = (sy - 7) * scale
        gy1 = (sy - 3) * scale
        d.rectangle([gx0, gy0, gx1, gy1], outline=(255, 220, 120, 255), width=2)
        d.text((gx0 + 3, gy0 - 18), "PUERTA 3x3", font=FONT_LABEL, fill=(255, 220, 120))
    return im


def isometric_cutaway(size, grid, scale=15, z_cut=6, x_cut=0, y_max=20):
    sx, sy, sz = size
    ex = (math.cos(math.radians(30)) * scale, math.sin(math.radians(30)) * scale)
    ez = (-math.cos(math.radians(30)) * scale, math.sin(math.radians(30)) * scale)
    ey = (0, -scale)
    # Bounds
    pts = []
    for x, z in [(0, 0), (sx, 0), (0, sz), (sx, sz)]:
        for y in (0, y_max):
            px = x * ex[0] + z * ez[0]
            py = x * ex[1] + z * ez[1] + y * ey[1]
            pts.append((px, py))
    minx = min(p[0] for p in pts) - 24
    maxx = max(p[0] for p in pts) + 24
    miny = min(p[1] for p in pts) - 24
    maxy = max(p[1] for p in pts) + 24
    w, h = int(maxx - minx), int(maxy - miny)
    im = sky((w, h), (24, 28, 34), (48, 54, 62))
    ox, oy = -minx, -miny

    # Only show the part behind the cut, and below the roof line.
    cells = [
        (pos, name) for pos, name in grid.items()
        if pos[2] >= z_cut and pos[0] >= x_cut and pos[1] <= y_max
    ]
    # Painter order: far (large x+z) first; lower y first within a column.
    cells.sort(key=lambda item: (-(item[0][0] + item[0][2]), item[0][1]))

    for (x, y, z), name in cells:
        base = (
            ox + x * ex[0] + z * ez[0],
            oy + x * ex[1] + z * ez[1] + y * ey[1],
        )
        top = [
            base,
            (base[0] + ex[0], base[1] + ex[1]),
            (base[0] + ex[0] + ez[0], base[1] + ex[1] + ez[1]),
            (base[0] + ez[0], base[1] + ez[1]),
        ]
        left = [
            base,
            (base[0], base[1] + scale),
            (base[0] + ez[0], base[1] + ez[1] + scale),
            (base[0] + ez[0], base[1] + ez[1]),
        ]
        right = [
            (base[0] + ex[0], base[1] + ex[1]),
            (base[0] + ex[0], base[1] + ex[1] + scale),
            (base[0] + ex[0] + ez[0], base[1] + ex[1] + ez[1] + scale),
            (base[0] + ex[0] + ez[0], base[1] + ex[1] + ez[1]),
        ]
        tex = texture_for(name, scale)
        avg = tex.resize((1, 1), Image.Resampling.LANCZOS).getpixel((0, 0))
        def col(f):
            return (min(255, int(avg[0] * f)), min(255, int(avg[1] * f)),
                    min(255, int(avg[2] * f)), 255)
        d = ImageDraw.Draw(im)
        d.polygon(top, fill=col(1.15))
        d.polygon(left, fill=col(0.78))
        d.polygon(right, fill=col(0.92))
        d.line(top + [top[0]], fill=(28, 30, 34, 90), width=1)
    return im


def plan(size, grid, y_top=13, scale=26):
    sx, sy, sz = size
    w, h = sx * scale, sz * scale
    im = Image.new("RGBA", (w, h), (30, 32, 34, 255))
    d = ImageDraw.Draw(im)

    tops = {}
    for (x, y, z), name in grid.items():
        if y <= y_top:
            if (x, z) not in tops or y > tops[(x, z)][0]:
                tops[(x, z)] = (y, name)

    # A height-tinted material map: low floors dark, high walls/towers light.
    for (x, z), (y, name) in tops.items():
        tex = texture_for(name, scale)
        avg = tex.resize((1, 1), Image.Resampling.LANCZOS).getpixel((0, 0))
        t = max(0.0, min(1.0, y / max(1, y_top)))
        f = 0.65 + 0.65 * t
        col = (min(255, int(avg[0] * f)), min(255, int(avg[1] * f)),
               min(255, int(avg[2] * f)), 255)
        d.rectangle([x * scale, z * scale, (x + 1) * scale - 1, (z + 1) * scale - 1],
                    fill=col)

    # Grid and contours where the height changes sharply.
    for x in range(sx + 1):
        d.line([(x * scale, 0), (x * scale, h)], fill=(20, 22, 24, 120), width=1)
    for z in range(sz + 1):
        d.line([(0, z * scale), (w, z * scale)], fill=(20, 22, 24, 120), width=1)
    for (x, z), (y, _) in tops.items():
        for dx, dz in ((1, 0), (0, 1)):
            q = (x + dx, z + dz)
            if q in tops and abs(tops[q][0] - y) >= 3:
                px, pz = (x + 1) * scale, (z + 1) * scale
                d.line([(px, z * scale), (px, (z + 1) * scale)],
                       fill=(12, 14, 16, 180), width=2 if abs(tops[q][0] - y) >= 6 else 1)
                d.line([(x * scale, pz), ((x + 1) * scale, pz)],
                       fill=(12, 14, 16, 180), width=2 if abs(tops[q][0] - y) >= 6 else 1)

    # Gate outline: the passage is at x=8..10, z=0..4 (opened in the ruin pass).
    d.rectangle([8 * scale, 0, 11 * scale, 4 * scale],
                outline=(255, 220, 120, 255), width=2)

    # Readability labels (structure coordinates are stable for this asset).
    labels = [
        (9.0, 0.4, "PUERTA / N", (255, 228, 150)),
        (9.0, 5.2, "PATIO", (240, 240, 240)),
        (12.0, 12.0, "TORRE", (255, 228, 150)),
        (6.0, 13.0, "SALAS", (240, 240, 240)),
    ]
    for lx, lz, text, color in labels:
        if lx < sx and lz < sz:
            d.text((lx * scale + 3, lz * scale + 2), text, font=FONT_LABEL, fill=color)

    # North arrow.
    d.polygon([(w - 44, 28), (w - 28, 28), (w - 36, 10)], fill=(255, 228, 150))
    d.text((w - 50, 32), "N", font=FONT_LABEL, fill=(255, 228, 150))

    # Height legend.
    d.rectangle([6, h - 34, 6 + 18, h - 16], fill=(70, 70, 70, 255))
    d.rectangle([24, h - 34, 6 + 36, h - 16], fill=(150, 150, 150, 255))
    d.rectangle([42, h - 34, 6 + 54, h - 16], fill=(230, 230, 230, 255))
    d.text((6, h - 54), "altura y: 0 (oscuro) -> %d (claro)" % y_top,
           font=FONT_SMALL, fill=(235, 235, 235))
    return im


def main():
    size, grid = load_structure(ROOT / "gondor_fort_ruined.mts")
    out = ROOT / "evidence"
    out.mkdir(exist_ok=True)

    front = elevation(size, grid, "front")
    add_frame(front, "FACHADA NORTE (entrada)",
              "Gondor Fort adaptado — vista ortográfica desde z<0; el hueco central es la puerta.").save(
        out / "01_front_technical.png")

    side = elevation(size, grid, "side")
    add_frame(side, "LADO OESTE",
              "Vista ortográfica desde x<0; se ven los contrafuertes y las torres esquineras.").save(
        out / "02_side_technical.png")

    back = elevation(size, grid, "back")
    add_frame(back, "LADO SUR (dorso)",
              "Vista ortográfica desde z>0; el torreón central y la corona rota.").save(
        out / "03_back_technical.png")

    top = plan(size, grid, y_top=29, scale=24)
    add_frame(top, "PLANTA DE CUBIERTA (vista superior)",
              "Bloque más alto de cada columna: se lee la planta completa, no el interior.").save(
        out / "04_top_roof_technical.png")

    cut = plan(size, grid, y_top=13, scale=26)
    add_frame(cut, "PLANTA BAJA — CORTE A y=13",
              "Corte horizontal: se retiró la cubierta para leer patio, salas y circulaciones.").save(
        out / "05_plan_cut_y13_technical.png")

    iso = isometric_cutaway(size, grid, scale=22, z_cut=12, x_cut=8, y_max=16)
    add_frame(iso, "CORTE DE ESQUINA — INTERIORES",
              "Se retiraron las paredes norte (z<12) y oeste (x<8) y la parte alta (y>16); se ve el interior del torreón.").save(
        out / "06_interior_cutaway_technical.png")

    ground = plan(size, grid, y_top=5, scale=30)
    add_frame(ground, "PLANTA DE SALAS — CORTE A y=5",
              "Corte bajo: puerta, patio, salas, camas, cofres y circulaciones a la altura del suelo.").save(
        out / "07_plan_cut_y5_technical.png")

    (out / "README.txt").write_text(
        "AVISO: estas imágenes son previsualizaciones técnicas generadas a partir del .mts.\n"
        "NO son capturas de Luanti. No demuestran iluminación, colisiones, escaleras ni\n"
        "comportamiento en juego. La verificación real requiere abrir test_world en Luanti 5.17.\n",
        encoding="utf-8")
    print("wrote", sorted(p.name for p in out.glob("*.png")))


if __name__ == "__main__":
    main()
