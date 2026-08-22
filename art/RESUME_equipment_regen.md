# RESUME — Equipment icons (v3: names in prompts)

## Current state — ALL 40 SUBMITTED ✅
- **10 saved** to Downloads already (list below) — DONE, not regenerated.
- **40 regenerated with names in the prompts** — all dispatched and confirmed submitted.
- Nothing left to generate. Next step is purely picking + saving in the Art Drop Tool.

### Already saved (do NOT regenerate)
`eq_ashplate_cuirass`, `eq_bruiser_gauntlets`, `eq_bulwark_shield`, `eq_cindercore_staff`,
`eq_gravebite_greataxe`, `eq_ironbrow_helm`, `eq_juggernaut_plate`, `eq_killers_band`,
`eq_twin_fangs`, `eq_warcleaver`

## The v3 change that actually fixes identification
**Every prompt now starts with the item's name** — e.g. `Bonemarch Banner, a tall banner-standard, dark pole, pale bone-white cloth…`. The Midjourney feed shows the beginning of the prompt, so each image is now self-labelling. This removes any dependence on ordering to work out what's what.

Submission is in **reverse drop-tool order**, so the newest-first feed reads top-to-bottom in the same order as the tool. Names are the reliable fallback if re-sends scramble that again.

## Two gotchas that cost time — read before resuming
1. **Midjourney caps concurrent queued jobs.** Over the cap, prompts are **silently rejected** ("Too many queued prompts"). The loop checks the queue badge and waits when it's ≥6.
2. **The Midjourney tab degrades badly as images accumulate.** Throughput drops from ~10 submissions/40s on a fresh page to ~1/40s after a few hundred images render. **Fix: reload the tab every ~10 items.** State survives via localStorage.

## How to resume
1. Open/reload `https://www.midjourney.com/imagine`.
2. Re-inject the drain snippet (it reads `__eqQ` from localStorage and continues).
3. Repeat reload + drain in cycles of ~10 until `__eqQ` is empty.
4. Verify by scanning the feed for each item name.

## Prompt recipe
**Suffix appended to every subject:**
```
, anime style game item icon, cel-shaded with clean bold lineart, flat 2D anime artwork, highly detailed and clearly readable, evenly lit, every detail visible, centered and fully isolated on a solid pure white background, clean cutout, sharp silhouette edges, crisp intricate detail, high contrast, dark fantasy RPG icon --style raw --ar 1:1 --no photorealistic, 3d render, realistic, painterly, sci-fi, futuristic, neon, circuitry, violet, purple, magenta, dark shadows, obscured, murky, text, watermark, character, hands, body, background scene, shadow on ground, gradient background
```
**For COMMON items only, also append:** `, no glow, glowing, runes, luminous, neon`

**Design rules:** glow strictly gated by rarity (COMMON = none at all), accent colour varies by item theme — ember/crimson (Warrior), gold/amber/stone (Guardian), cold silver-blue/crimson (Assassin), elemental per-item (Mage), warm gold/bone-white (Support).

## Still outstanding
The **15 armor-set showcases** remain in the old cyan/futuristic style. Decide whether to regenerate them to match once the new equipment icons are picked.
