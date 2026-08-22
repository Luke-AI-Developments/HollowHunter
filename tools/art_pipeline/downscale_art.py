#!/usr/bin/env python3
"""Import pipeline: downscale + convert the raw art pack before shipping.

Section 23a of HollowHunter_Concept.md (REQUIRED). Midjourney/generator
output is full-resolution PNG (~1024px+, ~750 KB-1.4 MB each) -- far bigger
than anything a phone screen needs. This script is the scripted, repeatable
step that fixes that: it archives a full-resolution copy of every source
PNG to an external masters directory (never shipped, never in the repo --
needed later for store listings / a higher-DPI pass), then overwrites art/
in place with resized WebP at the target dimension for that asset's
category, preserving alpha where the source has it.

Safe to re-run any time art is re-rolled or a new asset is added -- once a
file has been converted to .webp, re-running resizes again from the
archived master (never from the already-downscaled .webp), so quality
never compounds across repeated runs.

Usage:
    python tools/art_pipeline/downscale_art.py [--dry-run] [--masters-dir PATH]
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
ART_DIR = REPO_ROOT / "art"
DEFAULT_MASTERS_DIR = Path.home() / "HollowHunter_ArtMasters"

# Per-file overrides, checked before the directory-wide rules below. Key is
# the path relative to art/, using forward slashes. Value is
# (max_dimension, output_format); output_format is "WEBP" or "PNG".
EXACT_RULES: dict[str, tuple[int, str]] = {
    # Google Play spec: exactly 512x512 32-bit PNG. Not a WebP candidate --
    # the store console itself dictates the format.
    "ui/ui_icon_playstore.png": (512, "PNG"),
    # Lives in art/ui/ but belongs to the hero/promo tier (23a), not the
    # 256px icon tier -- it's store-listing marketing art, same as hero key
    # art and promo shots, just filed alongside the other UI assets.
    "ui/ui_feature_graphic.png": (1024, "WEBP"),
}

# (directory name directly under art/, max_dimension, output_format) --
# applies to every *.png in that directory not already covered by
# EXACT_RULES above.
DIR_RULES: list[tuple[str, int, str]] = [
    ("monsters", 512, "WEBP"),
    ("presets", 512, "WEBP"),
    ("sets", 512, "WEBP"),
    ("equipment", 256, "WEBP"),
    ("ui", 256, "WEBP"),
    ("hero", 1024, "WEBP"),
    ("promo", 1024, "WEBP"),
    ("map", 256, "WEBP"),
]

# Photographic/painterly assets compress fine lossy at this quality with no
# visible loss at phone display sizes. Small flat-color icons (UI/equipment/
# map markers) go lossless instead -- they're cheap at 256px regardless, and
# lossy WebP's ringing artifacts are far more visible on hard icon edges and
# alpha boundaries (e.g. the rank badges -- 23a: "preserve transparency").
LOSSLESS_DIRS = {"ui", "equipment", "map"}
LOSSY_QUALITY = 88


def top_level_dir(rel_path: Path) -> str:
    return rel_path.parts[0] if len(rel_path.parts) > 1 else ""


def rules_for(rel_path: Path) -> tuple[int, str] | None:
    key = str(rel_path).replace("\\", "/")
    if key in EXACT_RULES:
        return EXACT_RULES[key]
    parent_dir = top_level_dir(rel_path)
    for dir_name, max_dim, fmt in DIR_RULES:
        if parent_dir == dir_name:
            return (max_dim, fmt)
    return None


def convert_one(png_path: Path, max_dim: int, fmt: str, masters_dir: Path, dry_run: bool) -> tuple[str, int, int]:
    rel = png_path.relative_to(ART_DIR)
    master_path = masters_dir / rel
    master_path.parent.mkdir(parents=True, exist_ok=True)

    if not master_path.exists():
        if not dry_run:
            shutil.copy2(png_path, master_path)
        source = png_path
    else:
        # Already archived by a previous run -- resize from the untouched
        # master, not from art/'s (possibly already-downscaled) copy.
        source = master_path
    # Captured now, before conversion deletes png_path out from under us --
    # `source` and `png_path` can be the same file on a first run.
    before_bytes = source.stat().st_size if source.exists() else 0

    with Image.open(source) as im:
        original_size = im.size
        im.load()
        if "A" in im.getbands():
            im = im.convert("RGBA")
        elif im.mode != "RGB":
            im = im.convert("RGB")
        im.thumbnail((max_dim, max_dim), Image.LANCZOS)
        result_size = im.size

        if fmt == "WEBP":
            out_path = png_path.with_suffix(".webp")
            if not dry_run:
                lossless = top_level_dir(rel) in LOSSLESS_DIRS
                if lossless:
                    im.save(out_path, "WEBP", lossless=True)
                else:
                    im.save(out_path, "WEBP", quality=LOSSY_QUALITY)
                if out_path != png_path and png_path.exists():
                    png_path.unlink()
                stale_import = png_path.with_suffix(".png.import")
                if stale_import.exists():
                    stale_import.unlink()
        else:  # PNG, in place
            out_path = png_path
            if not dry_run:
                im.save(out_path, "PNG")

    after_bytes = out_path.stat().st_size if (not dry_run and out_path.exists()) else 0
    line = (
        f"{rel}: {original_size} -> {result_size}, "
        f"{before_bytes / 1024:.0f}KB -> {after_bytes / 1024:.0f}KB [{out_path.name}]"
    )
    return line, before_bytes, after_bytes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Report what would happen, change nothing.")
    parser.add_argument(
        "--masters-dir",
        type=Path,
        default=DEFAULT_MASTERS_DIR,
        help=f"Where full-resolution originals are archived (default: {DEFAULT_MASTERS_DIR}).",
    )
    args = parser.parse_args()

    if not args.dry_run:
        args.masters_dir.mkdir(parents=True, exist_ok=True)

    total_before = 0
    total_after = 0
    count = 0
    for png_path in sorted(ART_DIR.rglob("*.png")):
        rel = png_path.relative_to(ART_DIR)
        rule = rules_for(rel)
        if rule is None:
            print(f"SKIP (no rule): {rel}", file=sys.stderr)
            continue
        max_dim, fmt = rule
        line, before_bytes, after_bytes = convert_one(png_path, max_dim, fmt, args.masters_dir, args.dry_run)
        print(line)
        total_before += before_bytes
        total_after += after_bytes
        count += 1

    print(f"\n{count} images processed.")
    print(f"Total: {total_before / 1024 / 1024:.1f} MB -> {total_after / 1024 / 1024:.1f} MB")
    print(f"Masters archived to: {args.masters_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
