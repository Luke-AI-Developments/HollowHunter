# Handoff: Hollow Hunter — Leaderboard ("The Register")

## Overview
The Leaderboard screen for **Hollow Hunter**, a dark-fantasy fitness RPG. Players are ranked
hunters in tiers E → D → C → B → A → S. The board groups players **by rank tier**, so a player
competes against peers in their own band rather than against the whole world.

It is explicitly a **bragging board**: nothing is gated behind it, there are no rewards, no
seasons, no claim flows. The only jobs the screen has are (a) tell the player where they stand
in under a second, and (b) make twenty near-identical rows feel like a formal hunter-association
registry rather than a spreadsheet or an arcade high-score table.

Portrait phone only, 9:16–9:21. Designed at **390 × 844**.

Target engine: **Godot**. This is a visual-direction mockup.

## About the Design Files
The file in this bundle is a **design reference created in HTML** — a prototype showing intended
look, layout, and behavior. It is **not production code to copy directly.**

The task is to **recreate this design in the target environment** (Godot Control nodes, in this
case) using that environment's established patterns — scene composition, theme resources,
anchors/containers. Read the HTML for exact values, not for structure. Nothing about the DOM,
the flexbox usage, or the inline styling should survive into the engine; only the measurements,
colors, type, copy, and behavior should.

If the project already has a Godot theme resource for this game, the tokens below should be
mapped into it rather than hardcoded per-node.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, hierarchy, and copy. Recreate pixel-faithfully.

The one deliberate exception is the **rank badge**: the game already has shield-shaped rank badge
assets (angular shields, letter inside, cyan on near-black). The mock draws a placeholder
shield via a polygon clip so the row spacing is correct. **Do not rebuild that shape — drop the
existing asset into the same 22 × 26 box.**

## Screens / Views

The HTML file lays out **three phone frames side by side** on a canvas, each labelled with a
mono caption above it (`01 POPULATED REGISTER`, `02 REGISTER UNREACHABLE`, `03 FRIENDS · NO
ALLIES YET`). Those captions and the canvas padding/gap are **presentation scaffolding for
review only** — they are not part of the screen. Each frame is one state of one screen.

---

### 1. Populated Register — the main view

**Purpose:** the player checks their standing against peers in their tier band.

**Layout** — vertical stack, `390 × 844`, `overflow: hidden`, background `--bg`.
A non-interactive radial vignette sits over the whole frame:
`radial-gradient(120% 55% at 50% -12%, rgba(34,211,238,.08), transparent 62%)`.

Regions top to bottom:

| Region | Sizing | Notes |
|---|---|---|
| Top band | fixed (`flex: none`), padding `14px 14px 11px` | information only, **no controls** |
| Column rule | fixed, padding `7px 14px` | header row for the list |
| Ranked list | **flexible** (`flex: 1`, `min-height: 0`), `overflow-y: auto` | the only scrolling region |
| Pinned self row | fixed, padding `9px 14px` | always visible |
| Thumb zone | fixed, padding `11px 14px 12px` | all controls live here |

Bottom border on top band, column rule and thumb zone: `1px solid --line`.
Top band background: `linear-gradient(180deg, --panel, --bg)`.
Thumb zone background: `linear-gradient(180deg, --panel, --panel)`.

#### Top band
- **Title block** (left): an 8 × 8 square with `1px solid --cyan`, rotated 45° (a diamond),
  then `REGISTER` — 17px / 700 / `letter-spacing: .22em` / `--icy`. Gap 7px.
- **Subtitle**, directly under: 9px mono / `.16em` / `--muted`.
  Derived text: `<BOARD> · <SCOPE> · A-RANK` → e.g. `TOTAL POWER · REGIONAL · A-RANK`.
- **Standing block** (right, right-aligned, gap 3px):
  - `YOUR STANDING` — 8px mono / `.18em` / `--muted`
  - position — 22px mono / 700 / `--icy` / `line-height: 1`, zero-padded (`07`)
  - `/ 418` — 10px mono / `--muted`, baseline-aligned with the position
  - movement line — 8px mono / `.12em` / `--muted`, e.g. `▲ 3 SINCE LAST ASCENT`
- **Tier band strip**, `margin-top: 11px`, row, gap 7px:
  - label `TIER BAND` — 8px mono / `.16em` / `--muted`, `flex: none`
  - six equal cells (E D C B A S), gap 3px, each `flex: 1`, centered, padding `3px 0`,
    9px mono / 700 / `.1em`
    - **active tier:** `color: --bg` on `background: --cyan`
    - **inactive:** `color: --muted`, `background: --panel`, `1px solid --line`
  - This strip is **information, not a control.** It tells the player which band they are
    being ranked inside. If it tests as looking tappable, de-emphasise it — do not wire it up.

#### Column rule
Row, gap 10px, `background: --panel`. Three labels, all 8px mono / `.16em` / `--muted`:
`POS` (width 26px) · `HUNTER` (`flex: 1`) · score head (`TOTAL POWER` or `NADIR FLOOR`).

#### The row — the core element
Twenty rows. Row is `position: relative`, row-direction, `align-items: center`, gap 10px.

- padding `9px 14px` (normal), `11px 14px` (the player's own row)
- bottom border `1px solid --line`
- background alternates by parity to give the list texture: odd `--bg`, even `--panel`
- **position** — width 26px, mono / 700, zero-padded two digits
  - top 3 (`p <= 3`): 14px / `--text`
  - rest: 13px / `--muted`
- **rank badge** — 22 × 26, `flex: none`, centered, `background: --bg`,
  `1px solid --muted`, letter 11px mono / 700 / `--muted`.
  Placeholder clip: `polygon(0 0, 100% 0, 100% 66%, 50% 100%, 0 66%)`. **Replace with the
  existing badge asset.**
- **name column** — `flex: 1`, `min-width: 0`, column, gap 2px
  - name: 12.5px / 600 / `.05em` / `--text`, `white-space: nowrap`, `overflow: hidden`,
    `text-overflow: ellipsis`
  - sub-line: 8px mono / `.12em` / `--muted`. On the power board: `LV 61`. On the floor
    board it carries the other metric: `LV 61 · 21,480 PWR`
- **score column** — right-aligned, column, gap 2px
  - value: 13px mono / 700 / `--text`
  - unit: 8px mono / `.14em` / `--muted` — `PWR` or `FLOOR`

**Tier group headers** are injected before positions 1, 4 and 13 — this is what stops the list
reading as a spreadsheet. Each is a full-width band: `background: --panel`, bottom
`1px solid --line`, padding `11px 14px 6px`, containing a label (8px mono / `.2em` / `--icy`),
a `1px` `--line` rule filling the middle, and a count (8px mono / `.14em` / `--muted`).

Content: `S-RANK · APEX / 12 LISTED`, `A-RANK · YOUR BAND / 418 LISTED`,
`B-RANK · ASCENDING / 2,104 LISTED`.

**The player's own row** — the screen's primary problem. Four simultaneous signals:
1. `2px` `--cyan` bar down the full left edge (absolute, `top: 0; left: 0; bottom: 0`)
2. background `rgba(34,211,238,.09)`
3. bottom border becomes `--cyan` instead of `--line`
4. a 14px `--cyan` corner notch, top-right
   (`border-top: 14px solid --cyan; border-left: 14px solid transparent`)

Plus: position and score step up to 15px `--icy`, badge border and letter go `--cyan`, name
goes `--text` at 13px, and ` · YOU` is appended to the name.

List footer, after the last row: padding 13px, centered, 8px mono / `.2em` / `--muted` at
`opacity: .5` — `— A-RANK BAND ENDS · 418 LISTED —`.

#### Pinned self row
The headline solution to "findable in under a second": the player's row is **duplicated as a
fixed bar** above the thumb zone so it stays on screen when they scroll away from their
position. `position: relative`, top border `1px solid --cyan`, background `rgba(13,24,38,.97)`,
padding `9px 14px`, row, gap 10px, plus the same `2px` `--cyan` left bar.

Contents: position (14px mono / 700 / `--icy`, width 26px) · badge (22 × 26, `--cyan` border
and letter) · name block — `ASH-NINE` 13px / 600 / `--text`, then a `YOU` chip (8px mono /
`.16em`, `color: --bg`, `background: --cyan`, padding `1px 4px`) — with a gap line beneath
(8px mono / `.12em` / `--muted`): `LV 61 · 1,180 BEHIND RANK 06` · score (15px mono / 700 /
`--icy`) with its unit beneath (8px mono / `.14em` / `--muted`).

The gap line is the motivating detail — it converts "you are 7th" into "you are 1,180 from 6th".
Keep it. On the floor board it becomes `N FLOORS BEHIND RANK 06`.

#### Thumb zone
All interaction lives in the bottom ~40%. Two labelled sections, each headed by an 8px mono /
`.2em` / `--muted` label followed by a `1px` `--line` rule (`flex: 1`).

- **BOARD** — two cards, row, gap 7px, each `flex: 1`, padding `9px 10px`, left-aligned:
  - title 12px / 700 / `.1em`; sub-label 8px mono / `.12em` / `--muted`, `margin-top: 3px`
  - `TOTAL POWER` / `ALL GEAR + LEVEL` — `NADIR FLOOR` / `DEEPEST DESCENT`
  - selected: `1px solid --cyan`, `background: rgba(34,211,238,.08)`, title `--icy`
  - unselected: `1px solid --line`, `background: --panel2`, title `--muted`
- **SCOPE** — one segmented control, `1px solid --line`, three equal cells
  (`FRIENDS` / `REGIONAL` / `GLOBAL`), 9px mono / `.14em`, padding `9px 6px`, `1px --line`
  divider between cells:
  - selected: `background: rgba(34,211,238,.12)`, `color: --icy`,
    `box-shadow: inset 0 -2px 0 --cyan`
  - unselected: `background: --panel`, `color: --muted`
- **Actions** — row, gap 7px:
  - `JUMP TO ME` (primary, `flex: 1`): `1px solid --cyan`, `background: rgba(34,211,238,.08)`,
    padding 12px, centered, 12px / 700 / `.18em` / `--icy`, preceded by a 7px `--cyan`
    diamond. Scrolls the list to the player's row.
  - `SHARE` (secondary, `flex: none`): padding `12px 14px`, `1px solid --line`,
    `background: --panel2`, 10px mono / `.14em` / `--muted`
- **Privacy line**, `margin-top: 9px`, 9px mono / `.1em` / `--muted` / `line-height: 1.55`:
  `GAME STATS ONLY · LEVEL, POWER, FLOOR. NO HEALTH DATA LEAVES THIS DEVICE.`

---

### 2. Register Unreachable — not signed in / backend unavailable

**Purpose:** explain calmly why there is no board, without an error dump, and without making
the player feel their progress is at risk.

- **Header** is deliberately **de-chromed**: the diamond border and title drop from `--cyan`
  and `--icy` to `--muted`; subtitle reads `STANDING UNAVAILABLE OFFLINE`. The screen looks
  dormant, not broken. Vignette alpha drops from `.08` to `.05`.
- **Body** is centered (`flex: 1`, centered both axes, padding 26px) and holds a
  **bracketed panel** — the recurring device from the Inventory screen: `1px solid --line`,
  `background: rgba(10,20,32,.7)`, padding `26px 20px`, with four 13 × 13 corner brackets
  absolutely positioned at `-1px` offsets, each drawing only its two relevant edges in
  `1px solid --muted`.
- Inside, centered, gap 14px: a 40 × 46 empty shield in `1px solid --muted` (same clip path,
  `background: --panel`) containing a single 14 × 1 `--muted` dash — a badge with no rank;
  then `NO LINK TO THE REGISTER` (15px / 700 / `.16em` / `--text`); then body copy
  (12px / `line-height: 1.6` / `--muted` / `text-wrap: pretty` / `max-width: 250px`):

  > Rankings are kept by the hunter association, not on your device. Sign in — or reconnect —
  > and your standing appears exactly as it was.

- Then a reassurance list above a `1px --line` divider (`padding-top: 13px`), two rows of
  9px mono / `--muted`, each with a 5px rotated square bullet (first `--cyan`, second `--muted`):
  - `Your hunt continues offline — nothing is lost.`
  - `Power and floor sync on next connection.`
- **Amber last-known strip** below the panel, `margin-top: 14px`, full width, row, gap 8px,
  `1px solid --warn`, `background: rgba(240,180,41,.06)`, padding `8px 10px`, 6px `--warn`
  diamond, text 8px mono / `--warn` / `line-height: 1.45`:
  `LAST SYNCED 14 SEP · 09:12 — STANDING SHOWN THEN: 10 / 411`
  This is the difference between a dead screen and a screen that still tells you something.
- **Thumb zone:** `SIGN IN` primary (full width, `1px solid --cyan`,
  `background: rgba(34,211,238,.08)`, padding 13px, 13px / 700 / `.2em` / `--icy`, 8px `--cyan`
  diamond), then two equal secondaries, gap 7px — `RETRY LINK` and `PLAY OFFLINE`
  (`1px solid --line`, `background: --panel2`, 10px mono / `.14em` / `--muted`).
  Footnote: `SIGNING IN SHARES LEVEL, POWER AND FLOOR ONLY.`

---

### 3. Friends · No Allies Yet — the likely new-player state

**Purpose:** the most common first experience of this screen. Must not read as a dead end.

- **Header is fully lit** — this is a *valid* board, not a failure. Subtitle
  `TOTAL POWER · FRIENDS · A-RANK`; standing shows `01 / 1` with the movement line replaced by
  `UNCONTESTED` (8px mono / `--muted`).
- **The player's own row is rendered for real** at the top of the body (padding 14px):
  `1px solid --cyan`, `background: rgba(13,24,38,.95)`, padding `11px 13px`, the `2px --cyan`
  left bar, position `01` at 15px `--icy`, cyan badge, name + `YOU` chip, sub-line
  `LV 61 · NADIR FLOOR 74`, score `21,480`. They are on a leaderboard; it just has one entry.
- **Four ghost slots** beneath (`margin-top: 9px`, column, gap 6px) showing the board's future
  shape: `1px dashed --line`, `background: rgba(10,20,32,.35)`, padding `11px 13px`, row,
  gap 10px — a dim position numeral (14px mono / 700 / `--line`), an empty dashed shield
  (22 × 26), a dashed name bar (7px tall, `repeating-linear-gradient(90deg, --panel2 0 7px,
  transparent 7px 12px)`, per-row `max-width` of 120 / 96 / 134 / 104 px so it doesn't read as
  a uniform stack), and a 52 × 7 `--panel2` score block.
- **Explainer card** pinned to the bottom of the body (`margin-top: auto`, `padding-top: 16px`):
  `1px solid --line` with a `2px --cyan` left border, `background: rgba(10,20,32,.8)`,
  padding `16px 15px`.
  - Heading `A REGISTER OF ONE` — 14px / 700 / `.14em` / `--icy`
  - Body 12px / `line-height: 1.6` / `--muted` / `text-wrap: pretty`:
    > You hold first place among your allies because there are none. Add a hunter by code and
    > both of you appear here — power and floor only, nothing else.
  - **Code strip**, `margin-top: 12px`: `1px solid --line`, `background: --panel`,
    padding `9px 11px`, row, gap 9px — `YOUR CODE` (8px mono / `.16em` / `--muted`),
    `H9-4KQ-207` (14px mono / 700 / `.14em` / `--text`), then `COPY` pushed right
    (`margin-left: auto`, 8px mono / `.14em` / `--cyan`, `border-bottom: 1px solid --cyan`).
- **Thumb zone:** scope segmented control with `FRIENDS` selected, then `ADD A HUNTER` primary,
  then `VIEW REGIONAL BOARD INSTEAD` (full width, `1px solid --line`, `background: --panel2`,
  10px mono / `.14em` / `--muted`) — the escape hatch that keeps this from being a dead end.

## Interactions & Behavior

- **Board toggle** (`TOTAL POWER` ⇄ `NADIR FLOOR`) — changes the score column across every row,
  the column-rule score head, the top-band subtitle, the pinned self row's score and unit, and
  the gap line's phrasing (`1,180 BEHIND RANK 06` ⇄ `3 FLOORS BEHIND RANK 06`). On the floor
  board each row's sub-line gains the power figure so the other metric is still available.
  **Header, pinned row and list must never disagree — they all read from the same state.**
- **Scope toggle** (`FRIENDS` / `REGIONAL` / `GLOBAL`) — repoints the player's standing and the
  list contents. Standing per scope in the mock: Friends `01 / 1` (`UNCONTESTED`),
  Regional `07 / 418` (`▲ 3 SINCE LAST ASCENT`), Global `2142 / 40,318`
  (`▲ 118 SINCE LAST ASCENT`). The list footer count follows the scope total.
- **`JUMP TO ME`** — scrolls the list so the player's row is visible. Not wired in the mock.
  In the engine, animate the scroll (~220ms ease-out) rather than snapping; the row's own
  highlight is enough of an arrival cue, no flash needed.
- **`SHARE`** — opens the OS share sheet with a composed brag string. Must include only
  standing, board, scope, level, power, floor.
- **Row tap** — not designed. If you add a hunter profile panel later it must obey the privacy
  rule below.
- **No hover states** — touch only. Give every control a pressed state (a brief lift in
  background alpha is consistent with the rest of the game).
- **Scrolling** — only the ranked list scrolls. Top band, column rule, pinned row and thumb
  zone are all fixed. Scrollbars are hidden.
- **Empty and failure states are the three frames above** — implement all three, not just the
  happy path. A new player will hit frame 3 first.

## State Management

Minimal. Two enums drive everything:

| State | Values | Default | Drives |
|---|---|---|---|
| `board` | `power` \| `nadir` | `power` | score values + units, score head, subtitle, pinned score, gap phrasing, row sub-lines |
| `scope` | `Friends` \| `Regional` \| `Global` | `Regional` | list contents, standing position/total, movement line, footer count |

Everything else is derived. Do not duplicate the player's standing into separate header and
pinned-row state — derive both from one source, or they will drift (this was a real bug in the
first pass of the mock).

Data needed per row: `position`, `name`, `tier` (E–S), `level`, `power`, `floor`, `isYou`.
Tier group headers need a label and a band total. The player's standing needs position, band
total, movement delta, and the gap to the position above.

Fetching: the board is server-held (frame 2 exists precisely because of this). Cache the last
successful response with its timestamp so frame 2 can show the last-known standing.

## Design Tokens

Exactly nine colors. **No others** — no tints, no extra greys, no decorative hues. If something
needs to sit dimmer than `--muted`, use `opacity` on `--muted` rather than inventing a hex.

| Token | Hex | Use |
|---|---|---|
| `--bg` | `#03070d` | near-black background, odd row band |
| `--panel` | `#0a1420` | panel fill, even row band, group header band |
| `--panel2` | `#0d1826` | raised panel, secondary buttons |
| `--line` | `#16283a` | hairline borders, dividers, dashed ghost outlines |
| `--cyan` | `#22d3ee` | **interactive only** — buttons, selected states, self-row markers |
| `--icy` | `#7ff0ff` | headings, key numerals |
| `--text` | `#dff6ff` | body text, hunter names, badge letters |
| `--muted` | `#7f97a8` | secondary text, all micro-labels |
| `--warn` | `#f0b429` | warnings only (the last-synced strip) |

**Cyan discipline:** cyan marks things the player can act on, plus the player's own identity on
the board. It is never decorative. The active tier-band cell is the one informational exception,
and it earns it by being the screen's orientation device.

Alpha overlays used (all cyan or panel, no new hues):
`rgba(34,211,238,.09)` self row · `rgba(34,211,238,.08)` primary buttons ·
`rgba(34,211,238,.12)` selected segment · `rgba(34,211,238,.05–.08)` vignette ·
`rgba(13,24,38,.95–.97)` pinned row · `rgba(10,20,32,.35–.8)` ghost slots and panels ·
`rgba(240,180,41,.06)` warn strip.

**Typography** — two families:
- **Chakra Petch** (400/500/600/700) — titles, names, buttons. Wide tracking on headings
  (`.14em`–`.22em`).
- **JetBrains Mono** (400/500/700) — every numeral, label, code and status string. Monospace
  numerals are what make the position column scan as a register.

Scale in use: 7 (avoid), 8, 9, 10, 11, 12, 12.5, 13, 14, 15, 17, 22px.
**Floor for label text is 8px, and only at `--muted` or brighter.** An earlier pass used 7px at
a dimmer grey and it measured ~1.9:1 — invisible. Privacy copy sits at 9px for the same reason.

**Spacing:** 2, 3, 4, 6, 7, 8, 9, 10, 11, 13, 14, 16, 26px. Horizontal screen padding is
uniformly **14px**.

**Border radius: zero, everywhere.** Angular only. Corners are expressed with brackets, notches
and clip-path shields, never radii. Shields use
`polygon(0 0, 100% 0, 100% 66%, 50% 100%, 0 66%)`. Decorative diamonds are squares at
`rotate(45deg)`.

**Shadows:** almost none. Only small cyan glows on accent marks
(`0 0 6–7px --cyan`) and a drop shadow on overlay panels.

## Privacy — a hard constraint, not a preference

This is a fitness game, but **only aggregate game stats leave the device: level, power, floor
reached.** No raw health data, no step counts, no workout details, no heart rate, no distance —
ever displayed, ever transmitted, ever implied.

Do not add a row sub-line, tooltip, profile panel, or share string that implies otherwise. There
must never be a "12,400 steps today" next to a hunter's name. The screen states this in its own
footer (`GAME STATS ONLY · LEVEL, POWER, FLOOR. NO HEALTH DATA LEAVES THIS DEVICE.`) and that
promise has to stay true as the screen grows.

## Assets

- **Fonts:** Chakra Petch and JetBrains Mono, loaded from Google Fonts in the mock. Bundle both
  with the game rather than fetching at runtime.
- **Rank badges:** existing in-game assets (angular shields, E/D/C/B/S/A letter, cyan on
  near-black). The mock uses a clip-path placeholder at 22 × 26 (rows, pinned row) and 40 × 46
  (the empty shield in frame 2). Swap both for the real assets.
- **No images, no icons, no SVG.** Every mark in the mock is a CSS primitive — rotated squares,
  clipped polygons, border triangles, gradient bars — and all of it should become native
  drawing or theme styleboxes in the engine.

## Files

- `Hollow Hunter Leaderboard.dc.html` — the design reference. All three frames, side by side.
  Open it in a browser; the board and scope toggles are live, so you can see the derived header
  and pinned row update. The frame captions and canvas padding are review scaffolding, not part
  of the screen.
- `support.js` — runtime for the HTML prototype only. **Irrelevant to the implementation.**

### Not in this bundle
The Equipment Inventory screen this leaderboard was designed to match is not included — it was
delivered separately. The shared vocabulary to keep consistent across both: 14px screen gutters,
`flex: none` top band with diamond + wide-tracked title + mono subtitle, bracketed glass panels,
zero radii, mono for all numerals, cyan strictly for interactive elements, and a fixed thumb
zone holding every control.
