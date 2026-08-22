# HOLLOW HUNTER — Midjourney Art Production Pack
*Goal: subscribe to Midjourney for ONE month, generate EVERYTHING in a tight blitz, download it all, cancel. All the thinking is done here for free — the paid month is pure execution.*

---

## 0. The cost strategy (read first)

**The whole point:** the subscription clock only matters while you're generating. Every prompt is pre-written below, so you paste → generate → upscale → download, with zero thinking time. Do it over 2–3 focused sessions in one month, then cancel.

**Which tier:**
- **Standard (~$30/mo)** is the right pick for a bulk blitz, because it includes **unlimited "Relax" generations** (slow queue, but you're not paying per image). 54 monsters × a few rolls each = hundreds of jobs — Relax mode makes that effectively free within the month.
- **Basic (~$10/mo)** only gives ~3.3 "fast hours" and **no Relax mode**. You'd burn through it before finishing the monsters. Only worth it if you're doing *just* the hero art.
- *(Check current pricing/tier names when you subscribe — Midjourney changes these.)*

**Recommendation:** one month of **Standard**, do everything in Relax mode, cancel. Even at $30 that's your entire game's art for the price of two takeaways.

**Full scope, one pass:** hero key art (3) + promotional variants (4) + 36 rank-progression variants (12 presets × 3 stages; the early one doubles as the character-select portrait) + all 54 monster portraits + all 50 equipment icons + all 15 armor-set showcases + 9 UI/store assets (incl. the System UI frame, §9c; the 6 rank badges are code-generated, not MJ) = **171 images total** (+6 code-generated rank badges = 180 assets). All prompts below — nothing left to decide mid-session.

**Order of work in the paid month:**
1. **Style is already locked** (§2) — tested and approved, no setup step needed. Just use the master suffix as written.
2. **Hero key art + promo variants** (§3) — the flagship + social-content variety, 7 images.
3. **36 rank-progression variants** (§3c) — the 12 presets × 3 power-stages; the *early* image is also the character-select portrait.
5. **All 54 monsters** (§4) — the big batch, in Relax.
6. **All 50 equipment pieces** (§5) — icon-style, in Relax.
7. **All 15 armor sets** (§6) — full-set showcases, in Relax.
8. **UI / store assets** (§7) — app icon, store banner, class icons, rank badges.
9. Download + organise (§8), then **cancel**.

**Time expectation, honestly:** 196 jobs in Relax mode isn't instant — Relax queues behind paid-priority jobs, so each can take a few minutes. Expect this to span several sittings over a few days rather than one hour, even though it's unattended once queued. You can queue several jobs at once (Standard allows 3 simultaneous Fast/Relax) and batch-download while others render.

---

## 1. Midjourney basics (the 60-second version)

- Generate on the **web app** (midjourney.com) — easier than Discord for batching. Type prompt → 4 images appear → click the best → **Upscale** → download.
- **Parameters** go at the END of the prompt:
  - `--ar 1:1` aspect ratio (monsters = square; hero = `--ar 9:16` vertical and `--ar 16:9` wide).
  - `--style raw` = less "Midjourney beautification," more literal to your prompt = **crisper, more controlled** (fixes your Leonardo complaint).
  - `--no text, watermark` = MJ's negative prompt (what to exclude).
  - `--sref CODE` = style reference. **Not used** — see §2; the shared style text holds consistency on its own.
- **Don't** use a wall of negatives like Leonardo — MJ needs far fewer. The `--no` list below is enough.

---

## 2. STYLE — LOCKED (tested and approved 11 Aug 2026)

**No `--sref` needed.** Tested in practice: the shared style text below holds the look on its own, and skipping the style-reference code is one less thing to manage. If monsters start visibly drifting apart after 10–15, revisit then using a real approved monster image as the `--sref`.

**Two hard-won lessons baked into the wording below — don't undo these:**
1. **Never say "frost-cyan" / "icy-white" as a palette description.** Midjourney reads it literally and builds creatures *out of ice*. Say "dark charcoal creature with electric cyan glowing accents" instead — cyan is a *glow on* the creature, not the material it's made of. `ice, crystal` are in the negatives for the same reason.
2. **Explicit 2D language is required or you get painterly semi-realism.** "anime style, cel-shaded, clean bold lineart, flat 2D artwork, manhwa illustration style" + negatives `photorealistic, 3d render, realistic, painterly`. Without these, MJ defaults to rendered concept-art realism, which is the wrong look.

**No named-IP references in prompts.** Earlier drafts said "Solo Leveling / Octopath Traveler mood" — removed. Given Midjourney's active copyright litigation, prompts stay generic-descriptive. The look is achieved through description, never by naming someone else's work.

---

## THE MASTER SUFFIX (append to EVERY monster prompt below)

```
anime style creature illustration, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, single creature centered and fully isolated on a solid pure white background, clean cutout, sharp silhouette edges, grim dark creature with sickly glowing violet eyes and violet energy accents, high contrast, ominous --style raw --ar 1:1 --no photorealistic, 3d render, realistic, painterly, ice, crystal, cyan, teal, turquoise, text, watermark, shadow on ground, gradient background, scenery
```

**3. Solid WHITE background, not dark.** Tested both: the creature art renders *identically* either way, but a white backdrop makes background-removal trivial later (game sprites need transparency). Dark-on-dark is the worst case for auto-cutout tools. White beats chroma-green here because these creatures are dark charcoal — white already gives maximum luminance contrast, with zero risk of green colour-spill on edges. `shadow on ground, gradient background, scenery` are in the negatives to keep the backdrop perfectly flat and keyable.

**4. LIVING monsters are VIOLET, not cyan — this is critical.** Cyan is the *hunter's* colour and the mark of a **claimed shadow**. In-game, the shadow shader (§23 of the design bible) recolours a defeated monster from violet to inky-black-and-cyan — that colour flip *is* the CLAIM payoff. If the source art is already black-and-cyan, the shader produces no visible change and the game's biggest moment falls flat. So: **living monster art = grim dark creature + sickly violet glow**, with `cyan, teal, turquoise` in the negatives. Only the hero/gate/UI art uses cyan.

**5. GEAR is cyan and CLEARLY LIT — the opposite of the monsters.** Equipment and armour sets are *yours*, so they use the hunter's cyan, never violet (`violet, purple, magenta` in the negatives). And unlike creatures, they're **inventory icons that must read clearly at small size** — so drop the moody darkness entirely: "highly detailed and clearly readable, evenly lit, every detail visible", with `dark shadows, obscured, murky` in the negatives. Atmosphere is for monsters; legibility is for gear.

**Midjourney settings:** Speed **Relax** · Raw **on** · Model 8.2 · Aspect per-prompt via `--ar`.

Each monster line below is just the **subject** — paste `[subject] + MASTER SUFFIX`.

---

## 3. HERO KEY ART (the flagship — do these before the monsters)

Your locked look: lone hooded caped hunter, black silhouette from behind, facing a glowing cyan portal, near-total darkness. Three formats so you're covered everywhere.

**Vertical (9:16) — PRIMARY, for TikTok / Reels / Stories:**
```
Ultra-minimalist dark fantasy key art, vertical. A lone hooded hunter in a dramatic flowing cape, a pure black silhouette seen from behind, standing low in the frame, facing a single large glowing circular cyan portal above — a clean luminous ring of electric-cyan light. Vast empty near-black darkness, a faint dark ground plane, the portal the only light source casting a soft cyan rim on the figure. Broad-shouldered powerful build. Cinematic, moody, high contrast, crisp, almost monochrome black with one electric-cyan accent, empty dark space at the top for a title --style raw --ar 9:16 --no text, watermark, clutter, bright, washed out
```

**Wide (16:9) — for YouTube, store banner, website:** same prompt, change `--ar 9:16` → `--ar 16:9`, and "standing low in the frame" → "standing small, centered".

**Square (1:1) — for feed posts + profile:** same prompt, change to `--ar 1:1`.

### Promotional / social variants (4) — for ongoing TikTok/Reddit/X content, not just launch
Same hunter, same world, different shots — so posts don't all look identical.

**Close-up bust (thumbnail / profile-pic ready):**
```
Ultra-minimalist dark cinematic portrait, close-up bust shot from behind/three-quarter, a hooded hunter in a flowing cape, pure black silhouette, cyan rim light on the hood edge only, faint glow of a portal reflected in the darkness behind, extremely dark, high contrast, crisp linework, anime dark-fantasy --style raw --ar 1:1 --no text, watermark, face, mask
```

**Action pose (mid-fight energy, for "gameplay" teaser posts):**
```
Ultra-minimalist dark cinematic key art, a hooded hunter silhouette in a dynamic action pose mid-strike, cape flowing, a glowing cyan energy blade, sparks of cyan light, deep black background, dramatic single-source cyan lighting, high contrast, crisp linework, anime dark-fantasy --style raw --ar 9:16 --no text, watermark, clutter, mask
```

**The shadow army (wide, for "CLAIM" / army-building posts):**
```
Ultra-minimalist dark cinematic key art, wide shot, a hooded hunter silhouette standing before a small group of monstrous shadow-soldiers silhouettes behind them, all facing forward, deep black background, faint cyan glow outlining each figure, ominous, high contrast, crisp linework, anime dark-fantasy --style raw --ar 16:9 --no text, watermark, clutter, bright
```

**Title card (portal only, no figure — background plate for logo overlays):**
```
Ultra-minimalist dark cinematic background plate, a single large glowing circular cyan portal centered in vast near-total darkness, no figures, faint dark ground plane, soft cyan rim glow, huge empty negative space all around for a logo and title, high contrast, crisp, anime dark-fantasy --style raw --ar 16:9 --no text, watermark, character, clutter
```

---

## 3b. PRESET HUNTER DESCRIPTORS (12) — the playable character

> **These 12 are descriptors only — do NOT render them as standalone portraits.** Character select uses each hunter's **early-stage** image from §3c (`preset_hunter_<id>_early.png`), so the player sees themselves as the ragged E-rank nobody they actually start as. The descriptors below feed into the three stage prompts in §3c.

Different job from the hero key art: this is what the *player* actually plays as — face visible, not the mysterious silhouette. §9b: "curated preset hunters — generate many, hand-pick ~8–12 most on-style; the player picks one." These 12 are the roster to choose from at onboarding, shown on the Hunter screen (§21) with equipped gear/rank glow layered on later in-engine. Class-agnostic (class is chosen separately via the training question, §25) — plain hunter gear here, not class-specific. Filename: **`preset_hunter_<id>.png`**.

**PRESET MASTER SUFFIX** (append to every subject below):
```
anime style character portrait, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, dark fantasy near-future hunter, bust / three-quarter view, face clearly visible, confident intense expression, modern techwear blended with plate/leather armor, dark clothing with electric cyan glowing accents, dramatic single-source cyan rim lighting, deep near-black background, high contrast --style raw --ar 3:4 --no photorealistic, 3d render, realistic, painterly, ice, crystal, text, watermark, hood covering face, mask, extra limbs
```

### Female (6)
> **Gotcha (learned the hard way):** the descriptors below don't state gender, and MJ read f1 and f4 as *male* — "sharp angular features / muscular powerful build / hard stare" skews masculine on its own. For any female preset, lead with **"a young woman, female hunter,"** and append **`male, man, beard, stubble, masculine`** to the `--no` list. f1 and f4 already have this baked in below.

1. **f1** — *a young woman, female hunter,* short silver-white hair, sharp angular **feminine** features, lean athletic build, scar over one eyebrow.
2. **f2** — long black hair in a high ponytail, striking dark eyes, toned build, calm composed expression.
3. **f3** — shoulder-length auburn/red hair, freckled, wiry athletic build, sharp confident smirk.
4. **f4** — *a young woman, female hunter,* undercut with a long blue-black braid, strong muscular athletic build, **feminine face**, intense hard stare.
5. **f5** — short blonde bob, soft features but hard eyes, lean build, faint battle scar on the jaw.
6. **f6** — dark teal-streaked black hair half-shaved, angular tattoo-like cyan markings on one side of the face, lean build.

### Male (6)
> **Same gotcha in reverse:** m2 (long hair, lean, clean-shaven, no beard cue) rendered *female*. Any male preset without a beard/heavy-build cue needs **"a young man, male hunter,"** up front and **`female, woman, girl, feminine, breasts`** in the `--no` list. m2 has this baked in below.

7. **m1** — buzzcut dark hair, heavy jaw, broad muscular build, weathered scarred face.
8. **m2** — *a young man, male hunter,* long dark hair tied back, lean sharp **masculine** features, **strong male jawline**, calm focused expression.
9. **m3** — shaved head, thick beard, hulking muscular build, intense glare.
10. **m4** — short tousled brown hair, clean-shaven, athletic build, youthful determined expression.
11. **m5** — silver-grey hair swept back, angular scarred features, powerfully built, veteran presence.
12. **m6** — dark curly hair, light stubble, lean wiry build, confident half-smile.

---

## 3c. PRESET RANK-PROGRESSION VARIANTS (36) — includes the character-select art — same 12 hunters, visibly stronger over time

§9b: *"the avatar visibly evolves with rank: E-rank ragged and plain → S-rank glowing with shadow aura."* These 36 are that progression for each of the 12 presets above — shown on the **Hunter screen (§21)** as the player ranks up, not the onboarding picker (that stays the base §3b portrait). 3 checkpoint stages per preset, bucketed so every rank has a look: **early** (E–D), **mid** (C–B), **late** (A–S). Filename: **`preset_hunter_<id>_<stage>.png`** (e.g. `preset_hunter_f1_early.png`).

**How to generate:** for each of the 12 base descriptors in §3b, run it 3 times — once with each stage suffix below appended (keep the preset's own hair/feature description each time, so it's recognizably the same person, just changing gear/aura).

**EARLY stage suffix** (ragged, plain, no glow — E/D rank):
```
, ragged worn clothing, plain scuffed gear, dirt and wear, tired but determined expression, no glow, desaturated, anime style character portrait, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, dark fantasy near-future hunter, bust / three-quarter view, face clearly visible, deep near-black background, high contrast --style raw --ar 3:4 --no photorealistic, 3d render, realistic, painterly, text, watermark, hood covering face, mask, extra limbs, glowing aura
```

**MID stage suffix** (geared, confident, moderate glow — C/B rank):
```
, solid well-fitted techwear-plate armor, moderate glowing cyan accents on the gear, confident composed expression, anime style character portrait, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, dark fantasy near-future hunter, bust / three-quarter view, face clearly visible, deep near-black background, high contrast --style raw --ar 3:4 --no photorealistic, 3d render, realistic, painterly, text, watermark, hood covering face, mask, extra limbs
```

**LATE stage suffix** (radiant, commanding, full aura — A/S rank):
```
, ornate radiant armor, intense glowing cyan aura surrounding the figure, faint cyan energy particles, commanding powerful presence, anime style character portrait, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, dark fantasy near-future hunter, bust / three-quarter view, face clearly visible, deep near-black background, high contrast --style raw --ar 3:4 --no photorealistic, 3d render, realistic, painterly, text, watermark, hood covering face, mask, extra limbs
```

*Practical tip: paste each preset's base descriptor (e.g. "f1 — short silver-white hair, sharp angular features, lean athletic build, scar over one eyebrow") directly before the stage suffix — don't use the §3b MASTER SUFFIX for these, the stage suffixes above already include the full framing.*

---

## 4. THE 54 MONSTERS (paste subject + MASTER SUFFIX)

**Power should read visually, not just in the name.** Rank escalation is already baked into every subject line below — small/weak (E) → hulking/armored (D) → elite (C) → towering/regal/named (B) → grand/imposing (A) → colossal/epic (S). Keep those size and presence words when you paste; don't trim them for length. That's what makes a C-rank actually *look* weaker than an S-rank in the finished image, not just read that way on paper. Two extra techniques that help scale come through in a single square icon: for S-rank, add "vast scale, dwarfing everything" if it feels too tame after generating; for E-rank, it's fine if the creature reads small/tucked in the frame rather than filling it.

Grouped by rank. Filename each download to match: **`por_<id>.png`** (id shown in brackets).

### E-rank — small, weak minions (9)
1. **Grubmaw** [mon_grubmaw] — a small hollow chitinous grub-creature with a gaping toothed maw, insectoid brood minion, glowing cyan cracks in its carapace, weak and low.
2. **Runtclaw** [mon_runtclaw] — a small feral bone-and-sinew scavenger beast with oversized claws, lithe assassin build, grave-dirt and bone.
3. **Tarling** [mon_tarling] — a small living-tar blob creature, dripping black ooze with a glowing cyan core, crude limbs.
4. **Grublet** [mon_grublet] — a fat armored insect grub, hollow-brood minion, small chitin plates, cyan underglow.
5. **Cindergnat** [mon_cindergnat] — a tiny winged insect wreathed in cold cyan cinder-flame, hollow-brood caster mite.
6. **Gloamwing** [mon_gloamwing] — a small winged shadow-creature with tattered misty wings, lithe assassin, wisps of dark fog.
7. **Bonerat** [mon_bonerat] — a skeletal rat-creature of ash and bone, quick assassin vermin, cyan eye-glow.
8. **Mirewisp** [mon_mirewisp] — a small floating swamp-wisp spirit, pale caster mote, cyan glow over dark mire.
9. **Nipclaw** [mon_nipclaw] — a small snapping crab-like grave-scavenger with pincers, warrior minion.

### D-rank — soldiers / bigger minions (12)
10. **Tuskrend** [mon_tuskrend] — a hulking tusked grave-boar warrior beast, heavier and scarred.
11. **Carapax** [mon_carapax] — a heavily armored beetle-guardian with a massive domed chitin shell, tanky, cyan seams.
12. **Gravemarch Footman** [mon_gravemarch_footman] — an undead ashen soldier in tattered grey plate with a spear, hollow cyan eyes, warrior.
13. **Tarhulk** [mon_tarhulk] — a large hulking tar-golem guardian, dense dripping black mass, glowing cyan core.
14. **Beetlback** [mon_beetlback] — a broad armored beetle-guardian, low and wide, thick carapace plating.
15. **Sporebloat** [mon_sporebloat] — a bloated fungal brood-caster releasing cyan spore clouds, mage.
16. **Duskmaw** [mon_duskmaw] — a winged shadow-panther assassin with a fanged maw, tattered gloam wings.
17. **Rotknight** [mon_rotknight] — a decayed undead warden-knight in corroded ashen armor, warrior, cyan eye-glow.
18. **Cryptrat Swarm** [mon_cryptrat] — a seething swarm of skeletal crypt-rats forming one shape, assassin swarm, cyan eyes.
19. **Palewisp** [mon_palewisp] — a pale drifting wraith-wisp caster, ghostly ashen mage, cyan light.
20. **Gnollpike** [mon_gnollpike] — a gaunt gnoll-beast warrior wielding a crude pike, grave-scavenger.
21. **Grimhound** [mon_grimhound] — a lean spectral hound assassin, smoke-wreathed, glowing cyan eyes.

### C-rank — elites (12)
22. **Ashen Warden** [mon_ashen_warden] — an elite undead warden in full ashen plate with a greatsword, hollow cyan gaze, warrior.
23. **Bonegnasher** [mon_bonegnasher] — a hunched bone-armored grave-fiend assassin with elongated jaws and claws.
24. **Glacewisp** [mon_glacewisp] — a crystalline ice-sylph mage, floating shards of pale-blue frost, cyan glow.
25. **Ashwing** [mon_ashwing] — a sleek cinder-drake assassin with cold cyan flame trailing its wings.
26. **Sporelord** [mon_sporelord] — a towering fungal brood-lord mage crowned with cyan spore-caps.
27. **Broodlancer** [mon_broodlancer] — a chitinous insectoid assassin with bladed lance-limbs, hollow brood.
28. **Direwarden** [mon_direwarden] — a massive ashen warden warrior in heavy plate with a warhammer.
29. **Snarlpack Alpha** [mon_snarlpack] — an alpha grave-beast pack-leader howling, support commander, cyan war-aura.
30. **Frostbite Sylph** [mon_frostbite_sylph] — an elegant ice-sylph mage wreathed in freezing cyan mist.
31. **Emberling** [mon_emberling] — a lithe cinder-drake assassin whelp with cyan-hot flame claws.
32. **Grinlet** [mon_grinlet] — a grinning abyssal imp-mage, wide manic grin, void-cyan energy.
33. **Cindercreep** [mon_cindercreep] — a creeping abyssal fiend mage of dark tendrils and cold cyan embers.

### B-rank — formidable named (10)
34. **Frostquill** [mon_frostquill] — a bladed ice-sylph assassin bristling with frozen cyan quills.
35. **Hivewarden** [mon_hivewarden] — a towering armored brood-warrior guarding a hive, thick chitin, cyan cracks.
36. **Warhowl** [mon_warhowl] — a colossal armored dire-bear war-chief rearing up on hind legs mid-roar, shaggy matted fur over heavy bone-and-iron war harness, thick clawed forelimbs raised, broad fanged snarling muzzle, a commanding beast warlord.
37. **Sepulcher Knight** [mon_sepulcher_knight] — a grand undead guardian in ornate ashen tomb-armor with a tower shield.
38. **Cindermaw Drake** [mon_cindermaw_drake] — a large cinder-drake mage breathing cold cyan fire, ash-scaled.
39. **Hollowhorn** [mon_hollowhorn] — a massive horned abyssal guardian, dark hide, glowing cyan hollow eyes.
40. **Broodqueen Vassal** [mon_broodqueen_vassal] — a regal insectoid brood-matron support, elegant chitin, cyan glow.
41. **Ashen Cataphract** [mon_ashen_cataphract] — a heavily armored undead cavalry guardian in full ashen barding.
42. **Glacial Revenant** [mon_glacial_revenant] — a frozen undead warrior revenant encased in cracked cyan ice.
43. **Fiendlord** [mon_fiendlord] — a commanding abyssal fiend mage, dark regal horns, void-cyan corona.

### A-rank — grand mini-bosses, named (6)
44. **Cindervane** [mon_cindervane] — an imposing elite cinder-drake assassin, sweeping ash wings, cold cyan flame, grand and menacing.
45. **Hoarfrost Matron** [mon_hoarfrost_matron] — a towering regal ice-sylph mage-queen wreathed in a blizzard of cyan frost, ornate crystalline crown.
46. **Kaeric, the First Warden** [mon_kaeric] — a legendary ashen warden-lord warrior in ancient ornate plate with a massive blade, hollow cyan eyes, heroic scale.
47. **Voidcaller** [mon_voidcaller] — a sinister abyssal fiend mage tearing open void-rifts, dark robes, void-cyan energy, grand.
48. **Rimewarden Sovereign** [mon_rimewarden_sovereign] — a majestic ice-sylph sovereign mage on a throne of frost, cyan crystalline regalia.
49. **Ashen Lord Commander** [mon_ashen_lord_commander] — a commanding undead ashen war-lord support raising a banner, cyan command-aura, regal armor.

### S-rank — colossal bosses, epic (5)
50. **Xir'Vok, Brood Sovereign** [mon_xirvok] — a towering regal insectoid hive-monarch, elongated crowned chitin skull with a spined crest, four segmented bladed limbs spread wide, heavy ridged carapace draped in a tattered royal shroud, swarm of tiny drones orbiting close, imperious and terrifying, epic key-art quality.
51. **Vharun, the Cinder Wyrm** [mon_vharun] — a colossal serpentine cinder-wyrm dragon exhaling cold cyan fire, vast ash-scaled coils, epic boss, cinematic.
52. **The Pale Sovereign** [mon_pale_sovereign] — a towering pale crowned abyssal demon-king wreathed in cold cyan flame, hollow radiant eyes, throne of the abyss, epic final-boss grandeur, cinematic.
53. **Ur-Grakh, the Bonemarch King** [mon_ur_grakh] — a giant bone-armored grave-warlord king warrior with a colossal cleaver, crown of tusks, mountainous, epic boss.
54. **Nyxaris, the Hollow Star** [mon_nyxaris] — a vast cosmic-horror abyssal entity of dark matter and a collapsing cyan star-core, countless glowing eyes, void tendrils, epic apocalyptic boss, cinematic.

---

## 5. EQUIPMENT — 50 base pieces (icon style)

Different composition from monsters/hero: a single **item icon**, centered, no character, on a plain dark background — built for an inventory grid. Filename: **`spr_<id>.png`**.

**EQUIPMENT MASTER SUFFIX** (append to every item subject below):
```
anime style game item icon, cel-shaded with clean bold lineart, flat 2D anime artwork, highly detailed and clearly readable, evenly lit, every detail visible, centered and fully isolated on a solid pure white background, clean cutout, sharp silhouette edges, dark steel and leather materials with electric cyan glowing accents, crisp intricate detail, high contrast, dark fantasy near-future RPG icon --style raw --ar 1:1 --no photorealistic, 3d render, realistic, painterly, ice, crystal, violet, purple, magenta, dark shadows, obscured, murky, text, watermark, character, hands, body, background scene, shadow on ground, gradient background
```

Rarity → render intensity: COMMON = plain/utilitarian, UNCOMMON = faint cyan trim, RARE = glowing cyan runes, EPIC = intricate glowing engravings, LEGENDARY = radiant, ornate, commanding presence.

### Warrior (10)
1. **Warcleaver** [eq_warcleaver] — a plain heavy cleaver-axe, COMMON, utilitarian steel.
2. **Gravebite Greataxe** [eq_gravebite_greataxe] — a brutal double-bladed greataxe with glowing cyan rune-etched edge, RARE.
3. **Ironbrow Helm** [eq_ironbrow_helm] — a sturdy plain steel warrior helm with a faint cyan visor-slit glow, UNCOMMON.
4. **Ashplate Cuirass** [eq_ashplate_cuirass] — a solid ash-grey plate chestpiece, UNCOMMON, faint cyan seams.
5. **Juggernaut Plate** [eq_juggernaut_plate] — a massive ornate plate chestpiece with intricate glowing cyan engravings, EPIC.
6. **Bruiser's Gauntlets** [eq_bruiser_gauntlets] — plain reinforced knuckle gauntlets, COMMON.
7. **Trampling Sabatons** [eq_trampling_sabatons] — heavy armored boots with glowing cyan rune trim, RARE.
8. **Marching Greaves** [eq_marching_greaves] — sturdy plain shin greaves, UNCOMMON, faint glow.
9. **Berserker's Signet** [eq_berserker_signet] — a glowing cyan-runed war-ring, RARE.
10. **Warlord's Torc** [eq_warlord_torc] — an ornate glowing cyan neck-torc with intricate engravings, EPIC.

### Guardian (10)
11. **Bulwark Shield** [eq_bulwark_shield] — a plain round steel shield, COMMON.
12. **Aegis Wall** [eq_aegis_wall] — a large tower shield with glowing cyan rune border, RARE.
13. **Warden's Barbute** [eq_wardens_barbute] — a sturdy plain barbute helm, UNCOMMON, faint glow.
14. **Sentinel Cuirass** [eq_sentinel_cuirass] — a solid plate cuirass, UNCOMMON.
15. **Immovable Plate** [eq_immovable_plate] — a colossal ornate plate chestpiece glowing with intricate cyan circuitry-like engravings, EPIC.
16. **Ramguard Gauntlets** [eq_ramguard_gauntlets] — plain reinforced plate gauntlets, COMMON.
17. **Rootstep Greaves** [eq_rootstep_greaves] — heavy plated greaves with glowing cyan rune trim, RARE.
18. **Anchor Sabatons** [eq_anchor_sabatons] — sturdy plain armored boots, UNCOMMON.
19. **Stoneheart Charm** [eq_stoneheart_charm] — a glowing cyan crystal pendant charm, RARE.
20. **Bastion Sigil** [eq_bastion_sigil] — an ornate glowing cyan shield-shaped sigil pendant, EPIC.

### Assassin (10)
21. **Shadowfang Dagger** [eq_shadowfang_dagger] — a plain curved dagger, COMMON.
22. **Twin Fangs** [eq_twin_fangs] — a pair of glowing cyan-edged twin daggers, RARE.
23. **Gloamhood** [eq_gloamhood] — a light hood with faint cyan trim, UNCOMMON.
24. **Nightweave Vest** [eq_nightweave_vest] — a sleek leather vest, UNCOMMON, faint glow.
25. **Phantom Leathers** [eq_phantom_leathers] — ornate dark leather armor with intricate glowing cyan stitched patterns, EPIC.
26. **Silent Grips** [eq_silent_grips] — plain leather hand-wraps, COMMON.
27. **Gloamstep Boots** [eq_gloamstep_boots] — light boots with glowing cyan rune soles, RARE.
28. **Fleetfoot Shoes** [eq_fleetfoot_shoes] — plain light shoes, UNCOMMON, faint glow.
29. **Killer's Band** [eq_killers_band] — a glowing cyan-edged ring, RARE.
30. **Umbral Pendant** [eq_umbral_pendant] — an ornate dark pendant glowing with intricate cyan energy, EPIC.

### Mage (10)
31. **Blightwood Wand** [eq_blightwood_wand] — a plain gnarled wooden wand, COMMON.
32. **Cindercore Staff** [eq_cindercore_staff] — a tall staff topped with a glowing cyan crystal orb, RARE.
33. **Seer's Cowl** [eq_seers_cowl] — a light hooded cowl with faint cyan glow, UNCOMMON.
34. **Runespun Robe** [eq_runespun_robe] — a flowing robe with faint glowing rune-stitching, UNCOMMON.
35. **Archon Vestments** [eq_archon_vestments] — an ornate flowing robe covered in intricate glowing cyan runes, EPIC.
36. **Channeler's Gloves** [eq_channelers_gloves] — plain fingerless cloth gloves, COMMON.
37. **Wraithsilk Slippers** [eq_wraithsilk_slippers] — light cloth slippers with glowing cyan trim, RARE.
38. **Wanderer's Sandals** [eq_wanderers_sandals] — plain simple sandals, UNCOMMON, faint glow.
39. **Mana Sigil** [eq_mana_sigil] — a glowing cyan crystalline sigil ring, RARE.
40. **Oracle's Eye** [eq_oracles_eye] — an ornate glowing cyan eye-shaped amulet, EPIC.

### Support (10)
41. **Rally Totem** [eq_rally_totem] — a plain carved wooden totem, COMMON.
42. **Bonemarch Banner** [eq_bonemarch_banner] — a tall banner-standard with glowing cyan rune-cloth, RARE.
43. **Chaplain's Hood** [eq_chaplains_hood] — a simple hood with faint cyan trim, UNCOMMON.
44. **Warden-Priest Robe** [eq_wardenpriest_robe] — a sturdy robe with faint glowing seams, UNCOMMON.
45. **Hierophant Vestments** [eq_hierophant_vestments] — ornate ceremonial vestments glowing with intricate cyan patterns, EPIC.
46. **Blessing Gloves** [eq_blessing_gloves] — plain soft cloth gloves, COMMON.
47. **Shepherd's Treads** [eq_shepherds_treads] — sturdy boots with glowing cyan rune trim, RARE.
48. **Acolyte Sandals** [eq_acolyte_sandals] — plain simple sandals, UNCOMMON, faint glow.
49. **Wardsong Charm** [eq_wardsong_charm] — a glowing cyan chime-shaped charm, RARE.
50. **Aegis of the Host** [eq_aegis_of_the_host] — an ornate glowing cyan shield-and-banner pendant, EPIC.

---

## 6. ARMOR SETS — 15 sets (full showcase)

A character wearing the complete 4-piece set (head/body/hands/feet), front three-quarter view — gear needs to read clearly, so **not** a silhouette this time. Filename: **`<id>.png`** (id already includes `set_`).

**SET MASTER SUFFIX:**
```
full character armor showcase, front three-quarter view, anime style illustration, cel-shaded with clean bold lineart, flat 2D anime artwork, manhwa illustration style, highly detailed and clearly readable, evenly lit, every piece of the armor clearly visible, dark fantasy near-future RPG armor set, modern techwear blended with plate/leather, dark steel and leather with electric cyan glowing accents, fully isolated on a solid pure white background, clean cutout, crisp intricate detail, high contrast --style raw --ar 2:3 --no photorealistic, 3d render, realistic, painterly, ice, crystal, violet, purple, magenta, dark shadows, obscured, murky, text, watermark, weapon in hand, background clutter, mask, shadow on ground, gradient background
```

Tier → intensity: **D (Rare)** = grounded, functional, modest glow. **B (Epic)** = more ornate, stronger glow, small elemental fx per set flavor. **S (Legendary)** = radiant, commanding, boss-tier grandeur.

### Warrior
1. **Ashen Vanguard Plate** [set_ashen_vanguard_plate] — D-tier heavy ash-grey plate armor, a broad-shouldered warrior, modest cyan glow at the joints.
2. **Emberforged Regalia** [set_emberforged_regalia] — B-tier ornate ember-forged plate armor, a powerful warrior, glowing cyan-orange ember cracks across the armor.
3. **Bonemarch Warplate** [set_bonemarch_warplate] — S-tier legendary bone-and-steel warplate, a colossal warrior, radiant cyan runes across heavy ornate armor, commanding presence.

### Guardian
4. **Warden's Eternal Guard** [set_wardens_eternal_guard] — D-tier sturdy defensive plate armor with a shield, modest cyan glow.
5. **Rimefell Aegis** [set_rimefell_aegis] — B-tier ornate frost-touched plate armor, glowing cyan ice-crystal accents, a shield rimmed in frost.
6. **Obsidian Bastion** [set_obsidian_bastion] — S-tier legendary obsidian-black plate armor, radiant cyan glowing cracks, a massive imposing tower shield, commanding presence.

### Assassin
7. **Gloamstalker Garb** [set_gloamstalker_garb] — D-tier light dark leather armor, a lithe assassin, modest cyan glow at the seams.
8. **Voidcreep Shroud** [set_voidcreep_shroud] — B-tier ornate dark shrouded leather armor, glowing cyan void-tendril accents, an assassin wreathed in dark mist.
9. **Cinderdance Leathers** [set_cinderdance_leathers] — S-tier legendary flowing leather armor, radiant cyan energy trailing from every movement, commanding assassin presence.

### Mage
10. **Broodcaller Vestments** [set_broodcaller_vestments] — D-tier simple fungal-touched robes, modest cyan glow, a mage.
11. **Hoarfrost Weave** [set_hoarfrost_weave] — B-tier ornate frost-woven robes, glowing cyan ice-crystal patterns, a mage wreathed in cold mist.
12. **Sovereign's Regalia** [set_sovereigns_regalia] — S-tier legendary radiant ceremonial robes, glowing intricate cyan runes across the whole garment, commanding sovereign mage presence.

### Support
13. **Sanctified Ward** [set_sanctified_ward] — D-tier simple ceremonial robes, modest cyan glow, a support caster.
14. **Warhowl's Standard** [set_warhowls_standard] — B-tier ornate banner-bearer's armor, glowing cyan war-standard held aloft, a commanding support figure.
15. **Hive-Sovereign Raiment** [set_hive_sovereign_raiment] — S-tier legendary radiant insectoid-inspired ceremonial armor, glowing intricate cyan chitin patterns, commanding presence.

---

## 7. UI / STORE ASSETS (15)

Different job each — read the note per item. Filename: **`<id>.png`**.

**App icon** [ui_icon_playstore] — for the Google Play Store listing:
```
minimalist app icon, a glowing electric-cyan circular portal rune symbol centered on a near-black rounded-square background, bold simple iconography, high contrast, crisp, clean, no small details --style raw --ar 1:1 --no text, watermark, character
```
*Note: crop/resize to exact 512×512 in any image editor after download — MJ won't hit the exact spec.*

**Store feature graphic** [ui_feature_graphic] — Play Store banner (crop to 1024×500 after):
```
wide promotional game banner, a hooded hunter silhouette facing a glowing cyan circular portal, dark minimalist, vast empty negative space on both sides for logo and text overlay, cinematic, high contrast, crisp --style raw --ar 2:1 --no text, watermark, clutter
```

**Essence currency icon** [ui_icon_essence]:
```
a glowing electric-cyan crystal shard, small faceted gem, centered on a plain near-black background, crisp clean game currency icon, high contrast, dramatic glow --style raw --ar 1:1 --no text, watermark, character
```

**Class icons (5) + Essence icon** — *v2: weapon-symbol emblems on solid WHITE.*

> **Why v2:** the original icons sat on near-black circular badges, so they can't be cleanly keyed out for compositing onto other UI. v2 drops the badge container, uses a plain weapon symbol per class (instantly readable at small size, and it echoes that class's equipment art), and renders on **solid pure white** for a trivial background removal.

**ICON SUFFIX** (append to every subject below):
```
, bold simple symbolic emblem, minimal clean shapes, clearly readable at small size, anime style game UI icon, cel-shaded with clean bold lineart, flat 2D anime artwork, evenly lit, every detail visible, centered and fully isolated on a solid pure white background, clean cutout, sharp silhouette edges, dark steel and leather materials with electric cyan glowing accents, high contrast, dark fantasy near-future RPG icon --style raw --ar 1:1 --no photorealistic, 3d render, realistic, painterly, ice, crystal, violet, purple, magenta, dark shadows, obscured, murky, text, letters, watermark, character, face, hands, body, background scene, shadow on ground, gradient background, clutter
```

- [ui_class_warrior]: `a single heavy two-handed greatsword pointing upward, warrior class emblem`
- [ui_class_guardian]: `a single sturdy tower shield facing forward, guardian class emblem`
- [ui_class_assassin]: `two crossed curved daggers forming an X, assassin class emblem`
- [ui_class_mage]: `a single tall wizard staff topped with a glowing orb, pointing upward, mage class emblem`
- [ui_class_support]: `a single carved totem standard banner on a pole, support class emblem`
- [ui_icon_essence]: `a single faceted glowing energy shard floating, essence currency emblem`

**System UI frame** [ui_system_frame] — the reusable "status window" pop-up border (§9c of the design bible), for level-up/CLAIM/rank-up/floor-clear notifications:
```
a dark glass UI panel border frame, angular geometric cyan corner-brackets, thin glowing electric-cyan rune-etched border lines, mostly transparent dark center, sci-fi RPG "system status window" style, crisp, high contrast, symmetrical, clean vector-like linework --style raw --ar 1:1 --no text, watermark, character, gradient noise
```
*Note: pick a version with a clean, mostly-empty center — that's where text/rewards get overlaid later in-engine.*

**Rank badges (6)** — E through S — **NOT generated in Midjourney.**

> **Decided:** MJ treats every job as an independent roll, so six separately-generated letters come out in six different fonts — exactly the non-uniformity we hit on the first pass. Re-rolling can't fix it; it's a limitation, not a prompt problem.
>
> These are now **generated deterministically in code**: identical shield geometry, one font (Liberation Sans Bold), identical letter size and optical centring, cyan-on-near-black with a soft glow, exported at 512×512 with a **transparent** background (no cutout step needed).
>
> Script: `ui_generated/_rank_badge_generator.py` · Output: `ui_generated/ui_rank_{e,d,c,b,a,s}.png` — already done, no MJ generations required. Re-run the script to restyle all six at once if the palette ever changes.

---

## 8. Download + organise (as you go)

Folders (the Art Drop Tool creates these automatically as you drop images in):
- `HollowHunter/art/hero` — 3 hero formats
- `HollowHunter/art/promo` — 4 social variants
- `HollowHunter/art/presets` — 36 rank-stage variants, `preset_hunter_<id>_<stage>.png` (the `_early` image doubles as the character-select portrait; there is no separate base portrait — §3b/§10a)
- `HollowHunter/art/monsters` — 54 portraits, `por_<id>.png`
- `HollowHunter/art/equipment` — 50 item icons, `spr_<id>.png`
- `HollowHunter/art/sets` — 15 set showcases, `<id>.png`
- `HollowHunter/art/ui` — 9 store/UI assets from Midjourney, `<id>.png` — **plus 6 code-generated rank badges** (`ui_rank_*.png`, see §7) that are already finished and do not come from MJ

All these filenames match the ids already in **monsters.json** / **equipment.json**, so wiring the final art into the game later is drag-and-drop, no renaming.

- Upscale the keeper before downloading (MJ's Upscale = higher res).
- Use the **HollowHunter_ArtDropTool.html** to drag each download onto its labeled slot — it auto-saves with the correct filename into the correct folder.
- On the MJ web app you can also bulk-select your creations and download in batches if you'd rather sort after.

---

## 9. Still lower-priority / not in this pass
- **Shadow-army composite sprites, gate/map art, background textures, VFX** — later, once the core visual identity (this pass) is proven and you're closer to the real art-polish milestone (§23 of the design bible).

---

*Prep is done. The expensive part (deciding) cost nothing. Subscribe, blitz, cancel.*

---

## 9. MAP MARKERS (7) — the live map's iconography

The overworld map (§19) **is** the home screen, and it is *not* generated art — it's a live MapLibre render of real OSM vector data. The map's look comes from a **style JSON** (dark roads, hidden labels, muted land), which is a code/config job, not a Midjourney one. What *is* art is the marker set drawn on top.

**Different brief from equipment icons:** these sit at roughly 40px over constantly-changing terrain, so they need a bold silhouette, a heavy outline and almost no internal detail. Legibility beats richness.

**MARKER SUFFIX** (append to every subject below):
```
, map marker icon for a mobile game, bold simple silhouette, thick clean outline, minimal internal detail, high legibility at very small size, symmetrical, centered and fully isolated on a solid pure white background, clean cutout, sharp edges, anime dark-fantasy game UI, cel-shaded with clean bold lineart, flat 2D artwork, high contrast --style raw --ar 1:1 --no photorealistic, 3d render, realistic, painterly, sci-fi, futuristic, neon, circuitry, text, letters, watermark, character, face, hands, body, background scene, map, terrain, roads, shadow on ground, gradient background, clutter, fine detail
```

**One universal gate marker — rank is NOT shown on the map.** *(Revised: an earlier pass generated six rank-coloured markers; they came out visually inconsistent with each other, and rank-at-a-glance turned out not to matter because gates have no proximity requirement and are rank-matched to ±1 anyway. Rank is stated plainly in the gate encounter panel on tap, §18.)*

| id | Subject |
|---|---|
| `map_gate` | Gate Marker, a single oval portal rift torn in the air, clean bright cyan glow spilling from the opening, dark torn edges, one universal marker used for every gate rank |

> If rank-at-a-glance is ever wanted back, **tint this one asset programmatically per rank in-engine** rather than generating six — guaranteed consistent, zero extra art.

**Other map POIs:**

| id | Subject |
|---|---|
| `map_player` | Hunter Position Marker, a bold arrowhead chevron pointing forward inside a clean ring, cool cyan glow, the player's own location pin |
| `map_sanctuary` | Sanctuary Marker, a small calm shrine archway with a soft warm gold glow inside, peaceful and welcoming |
| `map_stronghold` | Stronghold Marker, a compact fortified keep tower with battlements, dark stone, faint warm gold windows |
| `map_incursion` | Incursion Marker, a violent jagged spreading crack in reality, angry red-violet glow bleeding from the fracture |
| `map_nadir` | Nadir Entrance Marker, a deep dark descending spiral stairwell shaft seen from above, cold pale light far below |
| `map_lorestone` | Lore Stone Marker, a small upright carved standing stone monolith with faint glowing engraved runes |

Filename: **`<id>.png`** → saves to `HollowHunter/art/map`.

> **Note on the incursion marker:** it uses red-violet deliberately — violet is the *monster* colour in this game's language (§4 of this pack), which is exactly right for a hostile breach, and distinguishes it from the player-aligned cyan/gold markers.

