#!/usr/bin/env python3
"""Fetch OSM road/water geometry for a bounding box and convert it to the
compact binary format scenes/map_view.gd loads at runtime (§19b/§19c).

No dependencies beyond the Python 3 standard library -- this is a one-off/
occasional dev-time tool, not something that ships or runs on-device.

Usage:
    python fetch_and_convert.py --bbox 54.5006,-1.5943,54.5464,-1.5155 \
        --out ../../content/map_data/darlington.bin

Bbox order is (south, west, north, east) -- same order Overpass itself uses.
Re-running against the same bbox re-fetches from the live Overpass API each
time (no caching) -- deliberate, since OSM data drifts and this is meant to
be re-run occasionally, not on every build.

## Binary format (little-endian throughout)

Header:
    magic          4 bytes  b"HHMD"
    version        uint8    1
    bbox           4x float32  (south, west, north, east), degrees -- kept
                   for reference/debugging, not read by the renderer
    origin_x       float32  Web Mercator X (metres) of the bbox centre
    origin_y       float32  Web Mercator Y (metres) of the bbox centre
    way_count      uint32

Per way, `way_count` times:
    class_id       uint8    see WayClass below
    point_count    uint16
    points         point_count * (float32 x, float32 y) -- Web Mercator
                   metres, RELATIVE TO origin_x/origin_y (not absolute --
                   absolute Web Mercator values at this latitude are in the
                   millions of metres, which would blow float32's usable
                   precision at the sub-metre scale roads need; relative
                   coordinates here stay within a few km of zero, well
                   inside float32's precision budget).

water_area ways are closed rings (first point == last point) meant to be
filled; every other class is an open polyline meant to be stroked.
"""

import argparse
import json
import math
import struct
import sys
import urllib.parse
import urllib.request
from pathlib import Path

MAGIC = b"HHMD"
VERSION = 1

# Web Mercator (EPSG:3857) uses the WGS84 semi-major axis as its sphere radius.
EARTH_RADIUS_M = 6378137.0

# Bucket OSM's much finer highway/waterway/natural tag vocabulary down to
# the handful of classes the renderer actually treats differently (width,
# colour -- see §19b's layer table). Anything not listed here is dropped:
# building outlines, boundaries, etc. were never fetched by the Overpass
# query in the first place, but a handful of stray highway values (bus
# stops tagged as ways, proposed roads, etc.) can still show up and aren't
# worth a rendering tier.
WAY_CLASSES = {
    "major_road": 0,
    "minor_road": 1,
    "path": 2,
    "water_line": 3,
    "water_area": 4,
}

HIGHWAY_TO_CLASS = {
    "motorway": "major_road",
    "motorway_link": "major_road",
    "trunk": "major_road",
    "trunk_link": "major_road",
    "primary": "major_road",
    "primary_link": "major_road",
    "secondary": "major_road",
    "secondary_link": "major_road",
    "tertiary": "minor_road",
    "tertiary_link": "minor_road",
    "unclassified": "minor_road",
    "residential": "minor_road",
    "living_street": "minor_road",
    "service": "minor_road",
    "construction": "minor_road",
    "track": "minor_road",
    "footway": "path",
    "cycleway": "path",
    "path": "path",
    "pedestrian": "path",
    "steps": "path",
    "corridor": "path",
    "bridleway": "path",
}


def classify(tags: dict) -> str | None:
    if "natural" in tags and tags["natural"] == "water":
        return "water_area"
    if "waterway" in tags:
        return "water_line"
    if "highway" in tags:
        return HIGHWAY_TO_CLASS.get(tags["highway"])
    return None


def lonlat_to_mercator(lon: float, lat: float) -> tuple[float, float]:
    x = math.radians(lon) * EARTH_RADIUS_M
    y = math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)) * EARTH_RADIUS_M
    return x, y


def fetch_overpass(south: float, west: float, north: float, east: float) -> dict:
    query = f"""[out:json][timeout:120];
(
  way["highway"]({south},{west},{north},{east});
  way["waterway"]({south},{west},{north},{east});
  way["natural"="water"]({south},{west},{north},{east});
);
out geom;
"""
    print(f"Fetching from Overpass API for bbox ({south},{west},{north},{east})...", file=sys.stderr)
    data = urllib.request.urlopen(
        "https://overpass-api.de/api/interpreter",
        data=f"data={urllib.parse.quote(query)}".encode("utf-8"),
        timeout=120,
    ).read()
    return json.loads(data)


def convert(overpass_json: dict, south: float, west: float, north: float, east: float) -> bytes:
    origin_x, origin_y = lonlat_to_mercator((west + east) / 2, (south + north) / 2)

    ways: list[tuple[int, list[tuple[float, float]]]] = []
    skipped = 0
    for element in overpass_json.get("elements", []):
        if element.get("type") != "way" or not element.get("geometry"):
            continue
        cls_name = classify(element.get("tags", {}))
        if cls_name is None:
            skipped += 1
            continue
        points = []
        for pt in element["geometry"]:
            x, y = lonlat_to_mercator(pt["lon"], pt["lat"])
            points.append((x - origin_x, y - origin_y))
        ways.append((WAY_CLASSES[cls_name], points))

    print(f"Classified {len(ways)} ways, skipped {skipped} (untagged/unmapped highway value)", file=sys.stderr)

    body = bytearray()
    body += struct.pack(
        "<4sBffffffI", MAGIC, VERSION, south, west, north, east, origin_x, origin_y, len(ways)
    )
    total_points = 0
    for class_id, points in ways:
        body += struct.pack("<BH", class_id, len(points))
        for x, y in points:
            body += struct.pack("<ff", x, y)
        total_points += len(points)

    print(f"Total points: {total_points}", file=sys.stderr)
    print(f"Binary size: {len(body)} bytes ({len(body) / 1024:.1f} KB)", file=sys.stderr)
    return bytes(body)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--bbox", required=True, help="south,west,north,east")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument(
        "--raw-json",
        type=Path,
        default=None,
        help="Skip the live Overpass fetch and convert this previously-saved raw JSON instead (dev convenience).",
    )
    args = parser.parse_args()

    south, west, north, east = (float(v) for v in args.bbox.split(","))

    if args.raw_json:
        overpass_json = json.loads(args.raw_json.read_text(encoding="utf-8"))
    else:
        overpass_json = fetch_overpass(south, west, north, east)

    binary = convert(overpass_json, south, west, north, east)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(binary)
    print(f"Wrote {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
