# ⚠ SUPERSEDED — do not action as written

**This brief assumed a MapLibre/PMTiles pipeline that does not exist.** Verified: `scenes/map_view.gd` is the Phase-1 placeholder (flat `PIXELS_PER_DEGREE` projection, `draw_circle()`), `addons/` holds only `gps_health_bridge` and `gut`, and there is no PMTiles extract or R2 bucket anywhere. Writing a style JSON now would produce a file with nothing to load it.

**Superseded by `prompt_for_code_map_render_spike.md`** — prove vector-tile rendering is viable in Godot first, or fall back to pre-styled raster tiles. The layer/palette guidance below stays valid and gets applied once there's a renderer (at runtime for vector, at tile-generation time for raster).

---

# Task: Map basemap style (§19b)

**Priority: do this before the map-marker art gets finalised.** The basemap palette dictates which marker art actually reads on top of it, so the style has to exist first. Full spec is now in the design doc at **§19b**, and it's listed as a track in the roadmap (§24) — read §19b first, this file is the working brief.

## What this is (and isn't)
The map is a live MapLibre render of real OSM vector data. There is **no image to draw** — the dark-fantasy look comes entirely from a **MapLibre GL style JSON**. This is a config/code task. No art generation is involved.

## The principle that drives every decision
**The basemap must stay visually quiet so the markers pop.**

Cyan is the hunter/interactive colour in this game. If the basemap uses cyan, gate markers stop reading and the screen becomes noise. So the basemap is **desaturated near-blacks, greys and deep blue-greys only** — no cyan, no saturated accent anywhere. It should look almost monochrome. Colour is a signal, and the only things worth signalling on this screen are things the player can act on.

## Layer treatment
| Layer | Treatment |
|---|---|
| Background / land | Near-black (`#03070d`–`#080d14`), flat |
| Water | Slightly darker and cooler than land — reads as void, never bright blue |
| Major roads | Dark grey, faintly lighter than land — street grid legible, no more |
| Minor roads / paths | Barely visible |
| Buildings | Very low contrast fill, no outlines |
| Boundaries | Off or near-invisible |
| POI labels/icons | **Off** — the game supplies its own POIs |
| Place labels | Minimal, dim grey, small — a few major names for orientation |
| Road labels | Off, or sparse on major roads only |

## How to build it

1. **Check the tile schema first.** The style must match the schema of the PMTiles extract being served (§19 — Protomaps basemap on Cloudflare R2). A style written against a different schema (OpenMapTiles vs Protomaps) renders blank or wrong. This is the most common way this task fails — confirm it before writing any style.

2. **Start from an existing open dark style; don't author from scratch.** Protomaps publishes an open basemap style with a dark theme built for their schema. Retinting that is a few hours; writing a full style from zero is days. Check their current style/schema docs — the basemap schema is versioned and may have moved since the doc was written.

3. **Keep the layer count low.** This renders on-device in Godot on mid-range Android. It's the screen players sit on longest, so frame time here matters more than anywhere else.

4. **Test outdoors, in daylight, on a real device.** A near-black map that looks great on a desk monitor can be unreadable on a phone at midday — which is exactly when people are out walking. Verify real contrast before locking the palette.

## Deliverable
- A style JSON committed to the repo (suggest `content/map_style.json`), loaded by `scenes/map_view.gd`.
- **A screenshot of it rendering on-device**, so map-marker art can be chosen against the real background rather than guessed.

## Report back
- Which base style you started from and which tile schema it targets.
- Whether the schema matched the PMTiles extract, and what you changed if not.
- Layer count and any frame-time impact you noticed on device.
- The on-device screenshot.
- Anything in §19b that fought the actual tile data — I'd rather adjust the spec than have you force it.

## Related, not part of this task
Map markers are **7 assets**, not 12 — there's now **one universal gate marker** for all ranks. Rank is no longer conveyed on the map; it must be **stated plainly in the gate encounter panel (§18)** when a gate is tapped ("Rank E Gate"). If that panel doesn't currently show rank, it needs to — flag it and I'll queue it as its own task.
