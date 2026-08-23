#!/usr/bin/env python3
"""Remove the flat white background from the 7 map-marker masters, giving
them real alpha transparency so they read as floating icons on the near-
black map (§19b) instead of opaque white boxes.

Operates on the archived full-resolution masters
(tools/art_pipeline/downscale_art.py's masters dir), not art/map/ directly
-- the masters are this pipeline's source of truth for regeneration, so
updating them here is what "clean up the source art" means in this
project's convention (same spirit as §23's "hand-clean in Aseprite: fix
artifacts... palette-snap"). Re-run downscale_art.py afterward to push the
change through to art/map/*.webp.

Two-pass approach, not a naive global chroma-key:
  1. Flood-fill from the four corners to find the region of near-white
     pixels actually CONNECTED to the image border. This is the real
     background. Several of these icons have enclosed white/near-white
     design elements (the incursion glow's bright core, the nadir spiral's
     cut-out) that must stay opaque -- a global "white -> transparent"
     threshold would wrongly punch holes through those too.
  2. Within that connected region only, alpha fades smoothly by distance
     from the background reference color (not a hard cutout), so
     anti-aliased/soft-glow edges (e.g. map_player.png's glow fading into
     white) don't get a jagged cutout line.

Usage:
    python tools/art_pipeline/strip_marker_background.py [--dry-run]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

MASTERS_DIR = Path.home() / "HollowHunter_ArtMasters" / "map"

MARKER_FILES = [
    "map_gate.png",
    "map_player.png",
    "map_sanctuary.png",
    "map_stronghold.png",
    "map_incursion.png",
    "map_nadir.png",
    "map_lorestone.png",
]

FLOOD_THRESHOLD = 18  ## PIL floodfill's per-pixel match tolerance -- generous
## enough to cross faint compression noise in the flat white background,
## tight enough to stop at the icons' saturated colors (all far from white).
SOFT_LOW = 8  ## color-distance from the background reference below which a
## border-connected pixel is fully transparent.
SOFT_HIGH = 60  ## color-distance above which a border-connected pixel stays
## fully opaque -- linear ramp between SOFT_LOW and SOFT_HIGH gives a smooth
## edge instead of a jagged binary cutout.
SENTINEL = (1, 2, 3)  ## a color that won't occur in real source art, used to
## mark flood-filled (border-connected) pixels for the second pass.

## Interior seed points for enclosed near-white regions that should ALSO
## become transparent even though they don't touch the image border --
## a plain border flood-fill leaves these opaque by design (protects
## enclosed highlights like map_incursion.png's bright core), so anything
## that should still be opened up needs an explicit seed here. Confirmed
## per-marker with the user (2026-08-24), not auto-decided -- an enclosed
## near-white area is ambiguous between "background pocket" and "legitimate
## bright highlight" and the two look identical to this script.
EXTRA_SEEDS: dict[str, list[tuple[int, int]]] = {
    "map_gate.png": [(512, 512)],  # the portal ring's interior -- see-through
    "map_nadir.png": [(512, 460)],  # the spiral cut into the pin -- see-through
}


def _background_reference(im: Image.Image) -> tuple[int, int, int]:
    w, h = im.size
    corners = [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]
    r = sum(im.getpixel(c)[0] for c in corners) // 4
    g = sum(im.getpixel(c)[1] for c in corners) // 4
    b = sum(im.getpixel(c)[2] for c in corners) // 4
    return (r, g, b)


def _color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def strip_background(im: Image.Image, extra_seeds: list[tuple[int, int]] | None = None) -> Image.Image:
    im = im.convert("RGB")
    bg_ref = _background_reference(im)
    w, h = im.size

    # Pass 1: flood-fill from the border (plus any confirmed extra_seeds --
    # see EXTRA_SEEDS above) to find which near-white pixels should become
    # transparent, leaving untouched any enclosed near-white design element
    # that isn't explicitly listed.
    flood_source = im.copy()
    seeds = [
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w // 2, 0),
        (w // 2, h - 1),
        (0, h // 2),
        (w - 1, h // 2),
        *(extra_seeds or []),
    ]
    for seed in seeds:
        if flood_source.getpixel(seed) == SENTINEL:
            continue  # already filled by an earlier seed
        ImageDraw.floodfill(flood_source, seed, SENTINEL, thresh=FLOOD_THRESHOLD)

    # Pass 2: within the flood-filled region, alpha fades smoothly by
    # distance from the background reference color.
    result = im.convert("RGBA")
    src_px = im.load()
    flood_px = flood_source.load()
    out_px = result.load()
    for y in range(h):
        for x in range(w):
            if flood_px[x, y] != SENTINEL:
                continue  # not border-connected background -- stays opaque
            dist = _color_distance(src_px[x, y], bg_ref)
            if dist <= SOFT_LOW:
                alpha = 0
            elif dist >= SOFT_HIGH:
                alpha = 255
            else:
                alpha = int(255 * (dist - SOFT_LOW) / (SOFT_HIGH - SOFT_LOW))
            r, g, b = src_px[x, y]
            out_px[x, y] = (r, g, b, alpha)

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Report only, write nothing.")
    args = parser.parse_args()

    for name in MARKER_FILES:
        path = MASTERS_DIR / name
        if not path.exists():
            print(f"SKIP (not found): {path}")
            continue
        with Image.open(path) as im:
            result = strip_background(im, EXTRA_SEEDS.get(name))
        transparent_px = sum(1 for a in result.getdata() if a[3] < 250)
        total_px = result.size[0] * result.size[1]
        print(f"{name}: {transparent_px}/{total_px} px affected ({100 * transparent_px / total_px:.1f}%)")
        if not args.dry_run:
            result.save(path, "PNG")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
