# Handoff: Hollow Hunter — Equipment Inventory

## Overview
Portrait-only mobile game screen for **Hollow Hunter**, a dark-fantasy fitness RPG. The screen is the player's equipment inventory: a scrollable grid of owned gear that must communicate **rarity** and **equipped/locked state at a glance**, plus a thumb-zone bulk-scrap flow that previews the Essence currency yield before the player confirms. A second tab lists armour sets with owned/total progress and tier bonuses.

Target: **Godot** (the user's stated engine). The HTML in this bundle is a visual-direction mockup only.

## About the Design Files
The file in this bundle (`Hollow Hunter Inventory.dc.html`) is a **design reference created in HTML** — a prototype showing intended look, hierarchy, and interaction, not production code to port. The task is to **recreate this design in the target environment** (Godot 4 — `Control` nodes, `GridContainer`, `NinePatchRect`/`StyleBoxFlat` or shaders for the glow) using that project's established scene and theme patterns. Nothing about the HTML structure, CSS, or JS should be treated as prescriptive; only the visual and behavioural spec below is.

If the project does not yet have UI conventions, establish a `Theme` resource holding the tokens in *Design Tokens* below and build the screen from it.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and state treatments are final-intent. Recreate the visual result pixel-closely at a 390×844 logical portrait canvas (9:19.5). The screen must tolerate 9:16 through 9:21 — see *Responsive behavior*.

The **item icons are placeholders**: simple clipped polygon silhouettes standing in for real art. See *Assets*.

---

## Screens / Views

### 1. Items tab (primary view)

**Purpose:** Browse owned gear, judge rarity/upgrade potential instantly, and bulk-scrap junk into Essence without fear of destroying equipped or locked pieces.

**Canvas:** 390 × 844 logical px. Root is a vertical stack; background `#03070d` with a subtle radial lift at the top (`radial-gradient(120% 80% at 50% 0%, #071019 0%, #03070d 60%)`). A 1px border `#16283a` frames the device in the mock only — not needed in-engine.

**Global overlay:** a full-screen non-interactive CRT scanline wash — horizontal 1px lines of `rgba(127,240,255,0.028)` repeating every 3px, drawn above all content. In Godot: a `ColorRect` with a tiny tiling shader, `mouse_filter = IGNORE`.

**Vertical structure (top → bottom):**

| Band | Height | Scroll |
|---|---|---|
| Top info band | ~118px | fixed |
| Tabs | 40px | fixed |
| Filter/sort bar | ~66px | fixed (pinned) |
| Item grid | fills remainder | **scrolls vertically** |
| Thumb zone | ~250px (≈30% of 844; the grid + thumb zone together own the bottom ~40%) | fixed |

#### 1a. Top info band — information only, no controls
- Padding `16px 16px 12px`. Background `linear-gradient(180deg, rgba(13,24,38,.9), transparent)`, bottom hairline `1px #16283a`.
- **Left:** screen title `EQUIPMENT` — Chakra Petch 700, 24px, letter-spacing `.14em`, color `#7ff0ff`, glow `text-shadow: 0 0 18px rgba(127,240,255,.28)`, line-height 1.
- **Right:** label `ESSENCE` — JetBrains Mono, 8px, letter-spacing `.24em`, `#7f97a8`. Below it, a 9×9px `#7ff0ff` square rotated 45° (diamond) with `box-shadow: 0 0 10px rgba(127,240,255,.7)`, gap 6px, then the value `12,480` — JetBrains Mono 700, 17px, `#dff6ff`.
- **Capacity bar** (12px below): a 4px-tall row-flex bar, `flex:1`, fill `#0a1420`, border `1px #16283a`.
  - Fill track: `linear-gradient(90deg, #16283a, #7f97a8)` at 100% width (the player is at/over cap).
  - **Overflow segment**: from 83% → 100%, amber diagonal hatch — `repeating-linear-gradient(135deg, #f0b429 0 2px, transparent 2px 5px)`.
  - Right of the bar, gap 10px: `128` in `#f0b429` / `/120` in `#7f97a8` — JetBrains Mono 10px.
- **Warning line** (5px below): `▲ STORAGE CAPACITY EXCEEDED — ESSENCE −15%` — JetBrains Mono 8px, letter-spacing `.1em`, `#f0b429`, opacity `.85`.
  - **This is a soft cap.** It never blocks pickup or any action. Its only mechanical effect is the −15% Essence multiplier, which is restated in the scrap-queue breakdown (1e).

#### 1b. Tabs
- Two equal-width tabs, `ITEMS 128` and `SETS 11`. Container: background `#03070d`, bottom hairline `1px #16283a`.
- Tab label: Chakra Petch 600, 12px, letter-spacing `.22em`, centered, padding `11px 0 9px`. The trailing count is JetBrains Mono 9px at 0.6 opacity.
- **Active:** color `#22d3ee`, bottom border `2px solid #22d3ee`, background `linear-gradient(180deg, rgba(34,211,238,0), rgba(34,211,238,.1))`.
- **Inactive:** color `#7f97a8`, transparent 2px bottom border (reserve the space so labels don't shift).

#### 1c. Filter / sort bar (pinned)
Padding `10px 0 9px`, background `linear-gradient(180deg, #070e17, #03070d)`, bottom hairline `1px #16283a`. Two rows, both **fixed grids — no horizontal scrolling anywhere in this bar.**

**Row 1 — class filter.** `grid-template-columns: repeat(6, 1fr)`, gap 4px, side padding 16px. Options: `ALL`, `WARRIOR`, `GUARDIAN`, `ASSASSIN`, `MAGE`, `SUPPORT`. Single-select; default `ALL`.
- Pill: padding `5px 2px`, centered, JetBrains Mono 7.5px, letter-spacing `.04em`. Notched corner: `clip-path: polygon(0 0, 100% 0, 100% calc(100% - 6px), calc(100% - 6px) 100%, 0 100%)` (bottom-right corner cut 6px).
- **Inactive:** border `1px #16283a`, background `rgba(13,24,38,.5)`, text `#7f97a8`.
- **Active:** border `1px #22d3ee`, background `rgba(34,211,238,.14)`, text `#22d3ee`, plus `inset 0 0 14px rgba(34,211,238,.18)`.

**Row 2 — facets + sort.** `grid-template-columns: repeat(5, 1fr)`, gap 4px, side padding 16px, 6px below row 1.
- Four facet chips: `SLOT ▾`, `RARITY ▾`, `SET ▾`, `EQUIP ▾`. Each: centered flex, padding `5px 2px`, border `1px #16283a`, background `rgba(13,24,38,.5)`, text `#dff6ff` JetBrains Mono 7.5px; the `▾` caret is `#7f97a8` with 3px left margin. Square corners. Each opens a picker (not designed yet — see *Not yet designed*).
  - Facet value sets: **Slot** = Weapon / Head / Chest / Off-hand / Accessory. **Rarity** = the five-step ladder. **Set** = the set names in 2. **Equip** = All / Equipped / Unequipped.
- Fifth cell is the **sort control** — the only cyan-bordered thing in the bar, because it's the one that acts immediately: `⇅ NEWEST`, border `1px rgba(34,211,238,.45)`, background `rgba(34,211,238,.08)`, text `#22d3ee`, same 6px bottom-right notch as the class pills. Tapping **cycles** through `NEWEST → POWER → RARITY → SLOT → NEWEST`. (In production this should probably open a menu rather than cycle; cycling is a mock affordance.)

#### 1d. Item grid — the core of the screen
- Scroll container: padding `12px 14px 16px`, vertical scroll only, scrollbar hidden.
- **Header row** above the grid, 9px below: left `UNEQUIPPED CACHE · 20 SHOWN` in `#7f97a8`, right `3 LOCKED` in `#f0b429`. Both JetBrains Mono 8px, letter-spacing `.18em`.
- Grid: `repeat(4, 1fr)`, gap 8px. Cell aspect ratio **0.84** (taller than wide).

**Cell construction** (two nested layers so the rarity frame reads as a hairline of colored metal):
1. **Outer** = the frame. Filled entirely with the frame color, clipped with the house notch: `polygon(0 0, calc(100% - 9px) 0, 100% 9px, 100% 100%, 9px 100%, 0 calc(100% - 9px))` — 9px cuts on the **top-right and bottom-left**, giving the whole screen its angular signature.
2. **Inner** = `inset: 1px`, same clip-path, background `linear-gradient(165deg, #0d1826 0%, #070e17 60%, #050a11 100%)`, `overflow: hidden`. The 1px of outer showing through *is* the rarity border.

**Cell contents, in z-order:**
- **Theme glow** (behind the icon): `radial-gradient(58% 46% at 50% 40%, <themeColor>, transparent 70%)`, `mix-blend-mode: screen`, opacity = the rarity's glow value. Absent entirely for Commons.
- **Lock hatch** (locked only): full-cell `repeating-linear-gradient(135deg, rgba(240,180,41,.09) 0 1px, transparent 1px 6px)`.
- **Icon**: 34×34px, centered, vertical stack with the name. Fill `linear-gradient(160deg, #2a3a4a 0%, #13202e 45%, <themeColor> 120%)` and `box-shadow: 0 0 <6 + rarityIndex*4>px <themeColor>`. Commons get `linear-gradient(160deg, #243140, #121c27)` and **no shadow**. Locked items render the icon at `opacity: .6`.
- **Name**: JetBrains Mono 6.5px, line-height 1.25, letter-spacing `.04em`, centered, `#dff6ff` at `.82` opacity, wraps to 2 lines. Container padding `6px 3px 9px` leaves room for the pip bar.
- **Power number**: top-right, 4px/5px inset, JetBrains Mono 7px. Color = rarity color for Rare and above, else `#7f97a8`.

##### Rarity — four redundant signals (this is the load-bearing part)
Rarity must survive at 85px-wide thumbnail size, so it is encoded **four times over**. Index, name, frame/accent color, glow opacity:

| # | Rarity | Color | Glow opacity | Corner brackets | Frame color used |
|---|---|---|---|---|---|
| 0 | Common | `#64757f` | **0 (none)** | none | `#16283a` (plain hairline) |
| 1 | Uncommon | `#7fa88c` | 0.14 | none | `rgba(127,168,140,.5)` |
| 2 | Rare | `#4d86d8` | 0.26 | top-left only | `#4d86d8` |
| 3 | Epic | `#9a6ad8` | 0.40 | top-left + bottom-right | `#9a6ad8` |
| 4 | Legendary | `#ffb545` | 0.58 | both, top-left **pulsing** | `#ffb545` |

1. **Frame color** — the 1px outer edge (see table).
2. **Corner brackets** — 9×9px L-shapes drawn *inside* the cell in the rarity color. Top-left bracket at `top:3px; left:3px` (`border-top` + `border-left`, 1px). Bottom-right bracket at `bottom:7px; right:3px` (`border-bottom` + `border-right`, 1px, opacity `.8`) — it sits at 7px to clear the pip bar. Legendary's top-left bracket animates `opacity .45 → .9 → .45` over 2.6s, ease-in-out, infinite.
3. **Pip bar** — five equal segments flush along the bottom edge, 3px tall, 1px gaps, 2px side/bottom padding. Segments `0..rarityIndex` are filled with the rarity color; the rest are `rgba(22,40,58,.9)`. Common's single lit pip renders at `.55` opacity so it reads as "one, barely".
4. **Icon glow strength** — the radial glow and the icon's own `box-shadow` both scale with rarity (blur = `6 + index*4` px). **Commons have no glow at all** — they are dead metal, which is the fastest scrap signal in the grid.
5. Legendary cells additionally get an outer `drop-shadow(0 0 10px rgba(255,181,69,.28))` on the whole cell.

**Critical:** glow *hue* comes from the item's **theme**, never from rarity and never from cyan. Themes: ember `#ff7a3c`, gold `#ffc85c`, crimson `#ff4d5e`, silver-blue `#9fc6e0`, arcane `#6f8cff`, and `none` for Commons. Rarity controls **intensity**; theme controls **color**. A Legendary gold item and a Legendary arcane item are equally bright and differently colored.

##### Equipped / locked / selected — mutually exclusive, all unmistakable
- **Equipped:** cyan `EQ` tag on the **left edge** at `top: 22px` — background `#22d3ee`, text `#03070d` JetBrains Mono 7px/700, letter-spacing `.1em`, padding `2px 4px 2px 3px`, right edge angled via `polygon(0 0, 100% 0, calc(100% - 4px) 100%, 0 100%)`. Frame color overridden to `rgba(34,211,238,.75)` and the cell gets `drop-shadow(0 0 8px rgba(34,211,238,.22))`. This is the **only** place cyan appears on a cell, and it means "this is live on a shadow right now."
- **Locked:** amber. Frame `rgba(240,180,41,.5)`, the diagonal hatch wash across the cell, icon dimmed to `.6`, and a small padlock glyph at `left:5px; top:5px` — a 5×5px `#f0b429` 1px-stroke shackle (top-rounded, no bottom border) above an 8×5px solid `#f0b429` body.
- **Selected:** `linear-gradient(180deg, rgba(34,211,238,.1), rgba(34,211,238,.22))` wash plus `inset 0 0 0 1px rgba(34,211,238,.5)`.
- **Equipped and locked items cannot be selected or scrapped.** Tapping one in multi-select mode must not add it to the queue, and the yield math must exclude it. The legend at the very bottom of the thumb zone states both exclusions before the player tries.

#### 1e. Thumb zone (bottom, fixed)
Top hairline `1px #16283a`, background `linear-gradient(180deg, rgba(10,20,32,.96), rgba(3,7,13,.99))` with a 6px backdrop blur, padding `12px 16px 18px`.

- **Row 1:** `◈ MULTI-SELECT ON` (flex:1) + `CLEAR` (auto width).
  - Multi-select toggle: padding `9px 11px`, JetBrains Mono 10px, letter-spacing `.14em`, notch `polygon(0 0, calc(100% - 8px) 0, 100% 8px, 100% 100%, 8px 100%, 0 calc(100% - 8px))`. **On:** border `1px #22d3ee`, background `rgba(34,211,238,.12)`, text `#22d3ee`. **Off:** border `1px #16283a`, background `rgba(13,24,38,.6)`, text `#7f97a8`.
  - `CLEAR`: padding `7px 10px`, border `1px #16283a`, text `#7f97a8` JetBrains Mono 9px. Empties the selection.
- **Scrap queue panel** (11px below): border `1px #16283a`, background `rgba(13,24,38,.7)`, padding `11px 12px`, notch `polygon(0 0, calc(100% - 12px) 0, 100% 12px, 100% 100%, 12px 100%, 0 calc(100% - 12px))`.
  - Header row: `SCRAP QUEUE` (JetBrains Mono 9px, `.18em`, `#7f97a8`) ↔ `04 SELECTED` (JetBrains Mono 9px, `#dff6ff`, count **zero-padded to 2**).
  - 1px `#16283a` divider, 9px margins.
  - Body row, space-between:
    - Left: label `ESSENCE YIELD` (8px, `.18em`, `#7f97a8`), then an 8×8px `#7ff0ff` 45° diamond with `0 0 8px rgba(127,240,255,.6)` and the net figure `+10,610` — JetBrains Mono 700, **21px**, `#7ff0ff`.
    - Right, right-aligned, JetBrains Mono 8px, line-height 1.7: `BASE 12,483` in `#7f97a8`, `CAP PENALTY −15%` in `#f0b429`.
  - **The yield must always be shown before confirmation**, and must recompute live as the selection changes.
- **Primary action:** `SCRAP SELECTED` — full width, padding `15px 0`, centered, Chakra Petch 700, 14px, letter-spacing `.24em`. Notch `polygon(0 0, calc(100% - 14px) 0, 100% 14px, 100% 100%, 14px 100%, 0 calc(100% - 14px))`.
  - **Enabled (selection non-empty):** border `1px #22d3ee`, background `linear-gradient(180deg, rgba(34,211,238,.22), rgba(34,211,238,.08))`, text `#7ff0ff`, `box-shadow: 0 0 26px rgba(34,211,238,.18)`.
  - **Disabled (empty selection):** border `1px #16283a`, background `rgba(13,24,38,.5)`, text `#7f97a8`, no shadow, default cursor.
- **Legend** (8px below): centered, JetBrains Mono 7.5px, letter-spacing `.1em`, `#7f97a8` — `EQ` in `#22d3ee`, `▮` in `#f0b429`, reading `EQ EQUIPPED · ▮ LOCKED — CANNOT BE SCRAPPED`.
- Home indicator: 120×3px `#16283a`, centered, 14px above the bottom.

### 2. Sets tab

**Purpose:** Show set-collection progress and what each completion tier grants, so the player knows which piece to chase.

- Scroll container: padding `14px 16px 24px`, vertical flex, gap 10px. (The filter bar and thumb zone are **not** present on this tab — set browsing has no bulk actions.)
- **Set card:** border `1px #16283a`, background `linear-gradient(160deg, rgba(13,24,38,.85), rgba(3,7,13,.85))`, padding `12px 13px`, notch `polygon(0 0, calc(100% - 12px) 0, 100% 12px, 100% 100%, 12px 100%, 0 calc(100% - 12px))`.
  - **Header:** set name — Chakra Petch 600, 14px, letter-spacing `.06em`, `#dff6ff`; right-aligned count `3/4` — JetBrains Mono 700, 13px, letter-spacing `.06em`. Count color: **complete** `#7ff0ff`, **one piece short** `#22d3ee`, **otherwise** `#7f97a8`.
  - **Slot pips** (8px below): one equal-width 5px-tall segment per set slot, gap 3px. Owned: background `#22d3ee`, border `1px rgba(34,211,238,.6)`, `0 0 8px rgba(34,211,238,.35)`. Unowned: `#0d1826`, border `1px #16283a`, no glow.
  - **Bonus rows** (10px below, gap 5px): each row is a tier badge + description, gap 9px, top-aligned.
    - Badge: fixed 30px wide, centered, padding `2px 0`, JetBrains Mono 8px, letter-spacing `.06em`, text `2PC` / `4PC` / `5PC`. **Active** (owned ≥ tier): border `1px rgba(34,211,238,.5)`, text `#22d3ee`, background `rgba(34,211,238,.1)`. **Inactive:** border `1px #16283a`, text `#7f97a8`, transparent.
    - Description: Chakra Petch 11px, line-height 1.4, `text-wrap: pretty`. Active `#dff6ff`, inactive `#7f97a8`.
- Home indicator as on the Items tab.

---

## Content (exact copy)

### Items — 20 entries
Columns: name · class · slot · rarity index (0–4) · power · glow theme · equipped-by (empty = not equipped) · locked · set.

| Name | Class | Slot | Rarity | Power | Theme | Equipped by | Locked | Set |
|---|---|---|---|---|---|---|---|---|
| Warcleaver | Warrior | weapon | 2 Rare | 412 | ember | — | — | — |
| Gravebite Greataxe | Warrior | weapon | 3 Epic | 688 | crimson | Vorne the Ashbound | — | Bonemarch Warplate |
| Ironbrow Helm | Warrior | armor | 1 Uncommon | 210 | silver | — | — | Bonemarch Warplate |
| Ashplate Cuirass | Warrior | armor | 2 Rare | 455 | ember | — | — | Bonemarch Warplate |
| Juggernaut Plate | Guardian | armor | 4 Legendary | 940 | gold | — | **locked** | Immovable Creed |
| Bulwark Shield | Guardian | shield | 0 Common | 120 | none | — | — | — |
| Aegis Wall | Guardian | shield | 3 Epic | 702 | silver | Mareth Iron-Vow | — | Immovable Creed |
| Immovable Plate | Guardian | armor | 2 Rare | 498 | silver | — | — | Immovable Creed |
| Shadowfang Dagger | Assassin | weapon | 3 Epic | 664 | arcane | — | — | Umbral Pact |
| Twin Fangs | Assassin | weapon | 2 Rare | 431 | crimson | — | — | — |
| Phantom Leathers | Assassin | armor | 1 Uncommon | 244 | arcane | — | — | Umbral Pact |
| Umbral Pendant | Assassin | accessory | 4 Legendary | 905 | arcane | Nyx of the Ninth | — | Umbral Pact |
| Blightwood Wand | Mage | weapon | 0 Common | 98 | none | — | — | — |
| Cindercore Staff | Mage | weapon | 3 Epic | 671 | ember | — | — | Cinder Archon |
| Archon Vestments | Mage | armor | 2 Rare | 470 | arcane | — | — | Cinder Archon |
| Oracle's Eye | Mage | accessory | 2 Rare | 505 | arcane | — | **locked** | — |
| Rally Totem | Support | weapon | 1 Uncommon | 232 | gold | — | — | Hierophant Rite |
| Bonemarch Banner | Support | accessory | 3 Epic | 690 | gold | — | **locked** | Bonemarch Warplate |
| Hierophant Vestments | Support | armor | 4 Legendary | 928 | gold | — | — | Hierophant Rite |
| Aegis of the Host | Support | shield | 2 Rare | 512 | silver | — | — | Hierophant Rite |

Default selection in the mock: Warcleaver, Shadowfang Dagger, Blightwood Wand, Oracle's Eye — but Oracle's Eye is locked, so it is **excluded from the queue and the yield**, leaving 3 selected. (Useful as a test case for the exclusion rule.)

"Equipped by" names are **shadows** — the player's summoned servants. Copy pattern: `CURRENTLY EQUIPPED BY <SHADOW NAME>`.

### Sets — 5 entries

| Set | Owned/Total | Tier bonuses |
|---|---|---|
| Bonemarch Warplate | 3/4 | **2pc** +8% Physical Power · **4pc** Killing blows restore 4% Vigour — 6s cooldown |
| Immovable Creed | 3/4 | **2pc** +12% Block Threshold · **4pc** Guard break grants a 3s Aegis shell |
| Umbral Pact | 3/4 | **2pc** +10% Crit from stealth · **4pc** First strike after a dodge cannot be resisted |
| Cinder Archon | 2/5 | **2pc** +9% Burn duration · **4pc** Overcast leaves a cinder field · **5pc** Ignition chains to 2 nearby foes |
| Hierophant Rite | 3/3 | **2pc** +14% Rally radius · **3pc** Allies in radius gain 6% damage reduction |

### Other literal strings
`EQUIPMENT` · `ESSENCE` · `12,480` · `128/120` · `▲ STORAGE CAPACITY EXCEEDED — ESSENCE −15%` · `ITEMS 128` · `SETS 11` · `UNEQUIPPED CACHE · 20 SHOWN` · `3 LOCKED` · `◈ MULTI-SELECT ON` · `CLEAR` · `SCRAP QUEUE` · `04 SELECTED` · `ESSENCE YIELD` · `BASE …` · `CAP PENALTY −15%` · `SCRAP SELECTED` · `EQ EQUIPPED · ▮ LOCKED — CANNOT BE SCRAPPED`

---

## Interactions & Behavior

- **Tab switch** — `ITEMS` / `SETS`. Instant, no transition in the mock. The filter bar and thumb zone belong to the Items tab only.
- **Class pill tap** — single-select filter over the grid; `ALL` clears it. Filtering also re-scopes the scrap queue: only *visible* selected items count toward the yield.
- **Sort tap** — cycles the four modes and re-labels itself. Order: newest first (the table order above), power desc, rarity desc, slot grouped.
- **Cell tap** — toggles selection when multi-select is on. **No-op for equipped and locked items.** When multi-select is off, a tap should open the item detail sheet (designed next — see *Not yet designed*); long-press is the natural gesture for entering multi-select from a cold start.
- **Multi-select toggle** — switches the grid between "tap = inspect" and "tap = select". Leaving multi-select should clear the queue.
- **CLEAR** — empties the selection; the scrap button drops to its disabled style.
- **SCRAP SELECTED** — enabled only with a non-empty queue. Should raise a confirm step that restates the count and the net yield; destruction of locked/equipped gear must be impossible by construction, not by warning.
- **Yield recompute** — live on every selection change (see *State Management* for the formula).
- **Animations** — only one: the Legendary corner-bracket pulse (2.6s ease-in-out, infinite, opacity `.45 ↔ .9`). Nothing else moves. The restraint is deliberate: motion is reserved for "rarest thing on screen." A CRT scanline drift exists as a keyframe in the mock but is intentionally unused.
- **Hover states** — none; touch-only screen. Add press states in-engine: a 1-frame scale-down (≈0.97) or a brief inner cyan flash on cells and buttons.
- **Scroll** — the grid is the only scrolling region. Scrollbars hidden.

## State Management
- `activeTab: 'items' | 'sets'` — default `items`.
- `classFilter: 'ALL' | 'WARRIOR' | 'GUARDIAN' | 'ASSASSIN' | 'MAGE' | 'SUPPORT'` — default `ALL`.
- `slotFilter`, `rarityFilter`, `setFilter`, `equipFilter` — present as chips, pickers not yet designed.
- `sortMode: 0..3` → `NEWEST | POWER | RARITY | SLOT` — default `0`.
- `multiSelect: boolean` — default `true` in the mock (so the flow is visible); production should probably default `false`.
- `selection: Set<itemId>` — must reject equipped and locked ids on insert.
- **Derived:** `visibleItems` = items passing all filters, ordered by `sortMode`. `queue` = `visibleItems ∩ selection`, minus equipped and locked. `baseYield = Σ round(power * 0.9 + rarityGlow * 400)` — a mock stand-in; **replace with the real scrap economy.** `netYield = round(baseYield * 0.85)` when over the soft cap, else `baseYield`. `overCapacity = itemCount > softCap`.
- **Data needed:** the item list with the columns above (id, name, class, slot, rarity, power, glow theme, equippedBy, locked, set); item count and soft cap; Essence balance; set definitions with owned/total and tier bonuses.

## Responsive behavior
Designed at 390×844. The band heights are fixed; the grid absorbs the difference, so 9:16 shows roughly 3 rows and 9:21 roughly 5. Constraints to hold:
- The thumb zone must stay bottom-anchored and never scroll — it is the reachable third of the phone.
- The filter bar must stay pinned and must **never scroll horizontally**; both rows are fixed grids sized to fit the narrowest supported width.
- 4 columns is fixed. Cell width flexes; the 8px gap and 14px side padding are constant.
- Cell aspect ratio stays 0.84. If cells get small enough that the 6.5px name is illegible, drop the name before dropping any rarity signal.

## Design Tokens

**Palette** (exact, as specified by the user)
| Token | Hex | Use |
|---|---|---|
| `bg` | `#03070d` | near-black background |
| `panel` | `#0a1420` | panel fill |
| `panel2` | `#0d1826` | raised panel |
| `line` | `#16283a` | hairline borders |
| `cyan` | `#22d3ee` | **interactive / primary accent only** |
| `icy` | `#7ff0ff` | headings, key numerals |
| `text` | `#dff6ff` | body text |
| `muted` | `#7f97a8` | secondary text |
| `warn` | `#f0b429` | warnings and locks only |

**Rule:** cyan marks things the player can act on — tabs, filters, sort, multi-select, scrap, and the `EQ` tag. Never decorative.

**Rarity colors** — Common `#64757f`, Uncommon `#7fa88c`, Rare `#4d86d8`, Epic `#9a6ad8`, Legendary `#ffb545`.
**Glow themes** — ember `#ff7a3c`, gold `#ffc85c`, crimson `#ff4d5e`, silver-blue `#9fc6e0`, arcane `#6f8cff`, none (Common).

**Typography** — two families, both Google Fonts.
- **Chakra Petch** (400/500/600/700) — titles, tab labels, set names, bonus text, the scrap button.
- **JetBrains Mono** (400/500/700) — every number, every label, every system-voice string. The "system window" feel depends on numerals being monospaced.
- Scale in use: 24/700/.14em (screen title) · 21/700 (yield) · 17/700 (Essence) · 14/700/.24em (primary button) · 14/600/.06em (set name) · 13/700 (set count) · 12/600/.22em (tabs) · 11/400 (bonus text) · 10 (multi-select, capacity) · 9 (chips, queue labels) · 8 (micro-labels, warning) · 7.5 (pills, facets, legend) · 7 (power, EQ tag) · 6.5 (item names).

**Spacing** — 2 / 3 / 4 / 5 / 6 / 8 / 9 / 10 / 11 / 12 / 14 / 16 / 18px. Grid gap 8px; grid side padding 14px; band side padding 16px.

**Corners — zero radius anywhere.** Angularity comes from clip-path notches, in three sizes: **6px** (bottom-right only, on pills and sort), **8–9px** (top-right + bottom-left, on cells and the multi-select toggle), **12–14px** (top-right + bottom-left, on panels and the primary button). The only rounded thing in the entire design is the 3px top of the padlock shackle.

**Shadows / glows**
- Title: `0 0 18px rgba(127,240,255,.28)` text glow.
- Essence diamond: `0 0 10px rgba(127,240,255,.7)`.
- Active pill: `inset 0 0 14px rgba(34,211,238,.18)`.
- Enabled primary button: `0 0 26px rgba(34,211,238,.18)`.
- Legendary cell: `drop-shadow(0 0 10px rgba(255,181,69,.28))`.
- Equipped cell: `drop-shadow(0 0 8px rgba(34,211,238,.22))`.
- Item icon: `0 0 (6 + rarityIndex*4)px <themeColor>`.
- Owned set pip: `0 0 8px rgba(34,211,238,.35)`.

## Assets
- **Fonts:** Chakra Petch and JetBrains Mono, both from Google Fonts (SIL Open Font License). Bundle them with the Godot project rather than fetching at runtime.
- **Item icons: placeholders.** In the mock each is a 34×34 polygon silhouette clipped by slot — weapon `polygon(50% 0, 62% 26%, 58% 100%, 42% 100%, 38% 26%)` (blade), armor `polygon(18% 8%, 82% 8%, 94% 30%, 78% 100%, 22% 100%, 6% 30%)` (cuirass), shield `polygon(12% 6%, 88% 6%, 88% 55%, 50% 100%, 12% 55%)`, accessory `polygon(50% 2%, 86% 50%, 50% 98%, 14% 50%)` (pendant). **Replace with real art.** Per the brief the real icons are dark metal/leather objects on transparent backgrounds; the cell's theme glow and icon `box-shadow` are the layers that carry the accent color, so the art itself should stay dark and unglowing — the frame supplies the light.
- **No image files, no icon font, no SVG.** Every glyph is either a text character (`▲ ◈ ⇅ ▾ ▮ ·`) or a CSS-drawn primitive (rotated-square diamond, padlock, corner brackets, pips).

## Files
- `Hollow Hunter Inventory.dc.html` — the full mockup: Items grid + Sets tab, interactive (tabs, class filter, sort cycle, cell selection, live yield).
- `support.js` — runtime for the mockup's component format. Not part of the design; needed only to open the HTML locally.

## Not yet designed
Three states from the original brief are specified but not yet built. They should be treated as part of this feature:
1. **Item detail sheet** — full stats, rarity, set membership, and the `CURRENTLY EQUIPPED BY <SHADOW NAME>` line.
2. **Comparison view** — candidate item vs. the piece currently in that slot, with green/red per-stat deltas, so the player never has to do the arithmetic.
3. **Facet pickers** — the dropdowns behind SLOT / RARITY / SET / EQUIP.
