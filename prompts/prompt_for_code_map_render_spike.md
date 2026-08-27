# Task: Map rendering — build the vector-line prototype (decision made)

You were right to stop and check the previous brief; it assumed infrastructure that doesn't exist. That's resolved. **The decision is made: no tiles, no MapLibre plugin, no PMTiles, no R2 bucket.** Don't build any of that.

## The approach

**Draw the real street network directly as vector lines in Godot.**

Pull simplified road and water geometry from OSM for a bounded area, ship it as a data file, and render it with Godot's own draw calls in our palette. `scenes/map_view.gd` already draws primitives — this extends that rather than replacing it with a tile pipeline.

**Why this and not tiles:**
- No native plugin, no GDExtension, no Android cross-compilation — the entire integration risk that made the previous plan a multi-week gamble disappears.
- No bucket, no hosting, no tile generation, nothing for me to provision.
- Total palette control. No style JSON fighting a tile schema; colours are just constants in code, so iteration is seconds not hours.
- The data is **tiny** (numbers below) — small enough to bundle in the APK.
- We lose buildings and landuse detail. For a deliberately near-monochrome map whose entire job is staying quiet so markers pop (§19b), that's arguably an improvement.

## Test area — Darlington

Build and test against a bounded box around Darlington town centre (54.5235, -1.5549).

**Bounding box (S, W, N, E):**
```
54.5006, -1.5943, 54.5464, -1.5155
```
That's ~10 sq miles / ~26 km², about 5.1 km per side. If it feels tight once running, the roomier option is `54.4837, -1.6235, 54.5633, -1.4863` (~78 km²).

**Expected data size** (my estimate — correct me with real numbers):
- ~500 km of road → ~50k points after simplification
- **~0.4 MB binary**, ~2 MB raw GeoJSON before compression

Small enough to bundle. No hosting needed for the prototype.

**Fetching it:** Overpass API is fine for a one-off extract. Roughly:
```
[out:json][timeout:120];
(
  way["highway"](54.5006,-1.5943,54.5464,-1.5155);
  way["waterway"](54.5006,-1.5943,54.5464,-1.5155);
  way["natural"="water"](54.5006,-1.5943,54.5464,-1.5155);
);
out geom;
```
Convert to whatever compact format suits Godot best — a binary blob of projected floats will load faster than parsing GeoJSON at runtime. Your call.

## Rendering requirements

**Palette (from §19b) — the map stays quiet so markers pop.** Cyan is the interactive colour; the basemap must not use it.
- Background: near-black `#03070d`–`#080d14`
- Water: slightly darker and cooler than land — reads as void, never bright blue
- Major roads: dark grey, faintly lighter than background — grid legible, no more
- Minor roads/paths: barely visible
- No labels at all — the game supplies its own POIs

**Also needs:**
- Correct projection so real GPS lat/lon maps to screen properly (Web Mercator is the sane choice; the current `PIXELS_PER_DEGREE` flat approximation is fine at small scale but will distort — use your judgement on whether it matters at this zoom).
- Road width by class (motorway/primary/residential/footpath), scaled with zoom.
- Pan and pinch-zoom.
- Player position from the existing GPS bridge, centred.
- Existing gate markers drawn on top, unchanged.
- Portrait only (§10a), primary actions in the lower ~40%.

## Performance
This is the screen players sit on longest, on mid-range Android. Simplify geometry aggressively at low zoom, cull off-screen segments, and don't redraw static geometry every frame if you can cache it. Tell me the frame cost on device.

## Deliverable
- Working map in `scenes/map_view.gd` rendering real Darlington streets in our palette.
- The extract committed (or a documented script that regenerates it).
- **An on-device screenshot** — I need to pick map-marker art against the real background.

## Report back
- Actual data size vs my ~0.4 MB estimate.
- Frame cost on device, and what you had to do to keep it acceptable.
- Whether Web Mercator vs flat projection made a visible difference at this scale.
- What it'd take to widen coverage beyond one bbox later (fetch-per-region? bundle several? this matters for launch geography but not now).

## Don't
- Don't add MapLibre, PMTiles, tile servers, or any hosting dependency.
- Don't ask me to provision anything — the prototype should need nothing from me.
- Don't treat §19/§19b as fact where they conflict with this; they describe the older tile-based intent and I'll update them once this proves out.
