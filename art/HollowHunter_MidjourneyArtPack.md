# HOLLOW HUNTER — Midjourney Art Production Pack
*Goal: subscribe to Midjourney for ONE month, generate EVERYTHING in a tight blitz, download it all, cancel. All the thinking is done here for free — the paid month is pure execution.*

---

## 0. The cost strategy (read first)

**The whole point:** the subscription clock only matters while you're generating. Every prompt is pre-written below, so you paste → generate → upscale → download, with zero thinking time. Do it over 2–3 focused sessions in one month, then cancel.

**Which tier:**
- **Standard (~$30/mo)** is the right pick for a bulk blitz, because it includes **unlimited "Relax" generations** (slow queue, but you're not paying per image). 57 monsters × a few rolls each = hundreds of jobs — Relax mode makes that effectively free within the month.
- **Basic (~$10/mo)** only gives ~3.3 "fast hours" and **no Relax mode**. You'd burn through it before finishing the monsters. Only worth it if you're doing *just* the hero art.
- *(Check current pricing/tier names when you subscribe — Midjourney changes these.)*

**Recommendation:** one month of **Standard**, do everything in Relax mode, cancel. Even at $30 that's your entire game's art for the price of two takeaways.

**Full scope, one pass:** hero key art (3) + promotional variants (4) + 12 preset playable-hunter portraits + 36 rank-progression variants (12 presets × 3 stages) + all 57 monster portraits + all 50 equipment icons + all 15 armor-set showcases + 15 UI/store assets (incl. the System UI frame, §9c) = **192 images total.** All prompts below — nothing left to decide mid-session.

**Order of work in the paid month:**
1. Lock the **style anchor** (§2) — 30 min, gets you an `--sref` code that makes everything look like one cohesive game.
2. **Hero key art + promo variants** (§3) — the flagship + social-content variety, 7 images.
3. **12 preset hunter portraits** (§3b) — the playable characters, face-visible, 6F/6M.
4. **36 rank-progression variants** (§3c) — same 12 presets, 3 power-stages each.
5. **All 57 monsters** (§4) — the big batch, in Relax.
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
  - `--sref CODE` = **style reference** — the key to consistency. Lock one code (§2), append it to every monster so they all match.
- **Don't** use a wall of negatives like Leonardo — MJ needs far fewer. The `--no` list below is enough.

---

## 2. STEP ONE — lock the style anchor (do this first in the paid month)

Generate this once, pick the version whose *look* you love most, then grab its style code to reuse everywhere.

**Prompt:**
```
dark fantasy creature concept art, a single monstrous creature centered on a plain near-black background, frost-cyan and icy-white glow, electric cyan energy accents, deep blacks, dramatic cyan rim lighting, high contrast, crisp clean linework, anime dark-fantasy illustration, Solo Leveling and Octopath Traveler mood, ominous --style raw --ar 1:1 --no text, watermark, signature, blur
```

**Then:** upscale your favourite → click it → **"..." / Use → Style Reference**, or copy its job and note the `--sref` number MJ assigns. From here on, **append `--sref <that code>` to every monster prompt.** That's what keeps all 57 looking like one game.

*(If you'd rather not use --sref, MJ 6+ is consistent enough from the shared style text alone — but --sref is stronger.)*

---

## THE MASTER SUFFIX (append to EVERY monster prompt below)

```
dark fantasy creature concept art, single creature centered on a plain near-black background, frost-cyan and icy-white glow, electric cyan accents, deep blacks, dramatic rim lighting, high contrast, crisp clean linework, anime dark-fantasy illustration, Solo Leveling mood --style raw --ar 1:1 --no text, watermark, signature, extra limbs, blurry --sref <YOUR_CODE>
```

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

## 3b. PRESET HUNTER PORTRAITS (12) — the playable character

Different job from the hero key art: this is what the *player* actually plays as — face visible, not the mysterious silhouette. §9b: "curated preset hunters — generate many, hand-pick ~8–12 most on-style; the player picks one." These 12 are the roster to choose from at onboarding, shown on the Hunter screen (§21) with equipped gear/rank glow layered on later in-engine. Class-agnostic (class is chosen separately via the training question, §25) — plain hunter gear here, not class-specific. Filename: **`preset_hunter_<id>.png`**.

**PRESET MASTER SUFFIX** (append to every subject below):
```
dark fantasy near-future hunter character portrait, bust / three-quarter view, face clearly visible, confident intense expression, modern techwear blended with plate/leather armor, frost-cyan glowing accents, dramatic single-source cyan rim lighting, deep near-black background, high contrast, crisp clean linework, anime dark-fantasy illustration --style raw --ar 3:4 --no text, watermark, hood covering face, mask, extra limbs --sref <YOUR_CODE>
```

### Female (6)
1. **f1** — short silver-white hair, sharp angular features, lean athletic build, scar over one eyebrow.
2. **f2** — long black hair in a high ponytail, striking dark eyes, toned build, calm composed expression.
3. **f3** — shoulder-length auburn/red hair, freckled, wiry athletic build, sharp confident smirk.
4. **f4** — undercut with a long blue-black braid, muscular powerful build, intense hard stare.
5. **f5** — short blonde bob, soft features but hard eyes, lean build, faint battle scar on the jaw.
6. **f6** — dark teal-streaked black hair half-shaved, angular tattoo-like cyan markings on one side of the face, lean build.

### Male (6)
7. **m1** — buzzcut dark hair, heavy jaw, broad muscular build, weathered scarred face.
8. **m2** — long dark hair tied back, lean sharp features, calm focused expression.
9. **m3** — shaved head, thick beard, hulking muscular build, intense glare.
10. **m4** — short tousled brown hair, clean-shaven, athletic build, youthful determined expression.
11. **m5** — silver-grey hair swept back, angular scarred features, powerfully built, veteran presence.
12. **m6** — dark curly hair, light stubble, lean wiry build, confident half-smile.

---

## 3c. PRESET RANK-PROGRESSION VARIANTS (36) — same 12 hunters, visibly stronger over time

§9b: *"the avatar visibly evolves with rank: E-rank ragged and plain → S-rank glowing with shadow aura."* These 36 are that progression for each of the 12 presets above — shown on the **Hunter screen (§21)** as the player ranks up, not the onboarding picker (that stays the base §3b portrait). 3 checkpoint stages per preset, bucketed so every rank has a look: **early** (E–D), **mid** (C–B), **late** (A–S). Filename: **`preset_hunter_<id>_<stage>.png`** (e.g. `preset_hunter_f1_early.png`).

**How to generate:** for each of the 12 base descriptors in §3b, run it 3 times — once with each stage suffix below appended (keep the preset's own hair/feature description each time, so it's recognizably the same person, just changing gear/aura).

**EARLY stage suffix** (ragged, plain, no glow — E/D rank):
```
, ragged worn clothing, plain scuffed gear, dirt and wear, tired but determined expression, no glow, desaturated, dark fantasy near-future hunter portrait, bust / three-quarter view, face clearly visible, deep near-black background, high contrast, crisp clean linework, anime dark-fantasy illustration --style raw --ar 3:4 --no text, watermark, hood covering face, mask, extra limbs, glowing aura --sref <YOUR_CODE>
```

**MID stage suffix** (geared, confident, moderate glow — C/B rank):
```
, solid well-fitted techwear-plate armor, moderate glowing cyan accents on the gear, confident composed expression, dark fantasy near-future hunter portrait, bust / three-quarter view, face clearly visible, deep near-black background, high contrast, crisp clean linework, anime dark-fantasy illustration --style raw --ar 3:4 --no text, watermark, hood covering face, mask, extra limbs --sref <YOUR_CODE>
```

**LATE stage suffix** (radiant, commanding, full aura — A/S rank):
```
, ornate radiant armor, intense glowing cyan aura surrounding the figure, faint cyan energy particles, commanding powerful presence, dark fantasy near-future hunter portrait, bust / three-quarter view, face clearly visible, deep near-black background, high contrast, crisp clean linework, anime dark-fantasy illustration --style raw --ar 3:4 --no text, watermark, hood covering face, mask, extra limbs --sref <YOUR_CODE>
```

*Practical tip: paste each preset's base descriptor (e.g. "f1 — short silver-white hair, sharp angular features, lean athletic build, scar over one eyebrow") directly before the stage suffix — don't use the §3b MASTER SUFFIX for these, the stage suffixes above already include the full framing.*

---

## 4. THE 57 MONSTERS (paste subject + MASTER SUFFIX)

**Power should read visually, not just in the name.** Rank escalation is already baked into every subject line below — small/weak (E) → hulking/armored (D) → elite (C) → towering/regal/named (B) → grand/imposing (A) → colossal/epic (S). Keep those size and presence words when you paste; don't trim them for length. That's what makes a C-rank actually *look* weaker than an S-rank in the finished image, not just read that way on paper. Two extra techniques that help scale come through in a single square icon: for S-rank, add "vast scale, dwarfing everything" if it feels too tame after generating; for E-rank, it's fine if the creature reads small/tucked in the frame rather than filling it.

Grouped by rank. Filename each download to match: **`por_<id>.png`** (id shown in brackets).

### E-rank — small, weak minions (10)
1. **Grubmaw** [mon_grubmaw] — a small hollow chitinous grub-creature with a gaping toothed maw, insectoid brood minion, glowing cyan cracks in its carapace, weak and low.
2. **Runtclaw** [mon_runtclaw] — a small feral bone-and-sinew scavenger beast with oversized claws, lithe assassin build, grave-dirt and bone.
3. **Tarling** [mon_tarling] — a small living-tar blob creature, dripping black ooze with a glowing cyan core, crude limbs.
4. **Grublet** [mon_grublet] — a fat armored insect grub, hollow-brood minion, small chitin plates, cyan underglow.
5. **Cindergnat** [mon_cindergnat] — a tiny winged insect wreathed in cold cyan cinder-flame, hollow-brood caster mite.
6. **Gloamwing** [mon_gloamwing] — a small winged shadow-creature with tattered misty wings, lithe assassin, wisps of dark fog.
7. **Bonerat** [mon_bonerat] — a skeletal rat-creature of ash and bone, quick assassin vermin, cyan eye-glow.
8. **Mirewisp** [mon_mirewisp] — a small floating swamp-wisp spirit, pale caster mote, cyan glow over dark mire.
9. **Mudtusk** [mon_mudtusk] — a small tusked grave-boar beast, stocky warrior minion, caked in dark mud.
10. **Nipclaw** [mon_nipclaw] — a small snapping crab-like grave-scavenger with pincers, warrior minion.

### D-rank — soldiers / bigger minions (13)
11. **Tuskrend** [mon_tuskrend] — a hulking tusked grave-boar warrior beast, heavier and scarred.
12. **Carapax** [mon_carapax] — a heavily armored beetle-guardian with a massive domed chitin shell, tanky, cyan seams.
13. **Gravemarch Footman** [mon_gravemarch_footman] — an undead ashen soldier in tattered grey plate with a spear, hollow cyan eyes, warrior.
14. **Tarhulk** [mon_tarhulk] — a large hulking tar-golem guardian, dense dripping black mass, glowing cyan core.
15. **Beetlback** [mon_beetlback] — a broad armored beetle-guardian, low and wide, thick carapace plating.
16. **Sporebloat** [mon_sporebloat] — a bloated fungal brood-caster releasing cyan spore clouds, mage.
17. **Duskmaw** [mon_duskmaw] — a winged shadow-panther assassin with a fanged maw, tattered gloam wings.
18. **Rotknight** [mon_rotknight] — a decayed undead warden-knight in corroded ashen armor, warrior, cyan eye-glow.
19. **Cryptrat Swarm** [mon_cryptrat] — a seething swarm of skeletal crypt-rats forming one shape, assassin swarm, cyan eyes.
20. **Palewisp** [mon_palewisp] — a pale drifting wraith-wisp caster, ghostly ashen mage, cyan light.
21. **Boartusk** [mon_boartusk] — a large armored grave-boar warrior with jagged tusks and bone plating.
22. **Gnollpike** [mon_gnollpike] — a gaunt gnoll-beast warrior wielding a crude pike, grave-scavenger.
23. **Grimhound** [mon_grimhound] — a lean spectral hound assassin, smoke-wreathed, glowing cyan eyes.

### C-rank — elites (12)
24. **Ashen Warden** [mon_ashen_warden] — an elite undead warden in full ashen plate with a greatsword, hollow cyan gaze, warrior.
25. **Bonegnasher** [mon_bonegnasher] — a hunched bone-armored grave-fiend assassin with elongated jaws and claws.
26. **Glacewisp** [mon_glacewisp] — a crystalline ice-sylph mage, floating shards of pale-blue frost, cyan glow.
27. **Ashwing** [mon_ashwing] — a sleek cinder-drake assassin with cold cyan flame trailing its wings.
28. **Sporelord** [mon_sporelord] — a towering fungal brood-lord mage crowned with cyan spore-caps.
29. **Broodlancer** [mon_broodlancer] — a chitinous insectoid assassin with bladed lance-limbs, hollow brood.
30. **Direwarden** [mon_direwarden] — a massive ashen warden warrior in heavy plate with a warhammer.
31. **Snarlpack Alpha** [mon_snarlpack] — an alpha grave-beast pack-leader howling, support commander, cyan war-aura.
32. **Frostbite Sylph** [mon_frostbite_sylph] — an elegant ice-sylph mage wreathed in freezing cyan mist.
33. **Emberling** [mon_emberling] — a lithe cinder-drake assassin whelp with cyan-hot flame claws.
34. **Grinlet** [mon_grinlet] — a grinning abyssal imp-mage, wide manic grin, void-cyan energy.
35. **Cindercreep** [mon_cindercreep] — a creeping abyssal fiend mage of dark tendrils and cold cyan embers.

### B-rank — formidable named (10)
36. **Frostquill** [mon_frostquill] — a bladed ice-sylph assassin bristling with frozen cyan quills.
37. **Hivewarden** [mon_hivewarden] — a towering armored brood-warrior guarding a hive, thick chitin, cyan cracks.
38. **Warhowl** [mon_warhowl] — a colossal armored dire-bear war-chief rearing mid-roar, shaggy matted fur over a bone-and-iron war harness, thick clawed forelimbs, broad fanged muzzle, support commander, cyan battle-aura.
39. **Sepulcher Knight** [mon_sepulcher_knight] — a grand undead guardian in ornate ashen tomb-armor with a tower shield.
40. **Cindermaw Drake** [mon_cindermaw_drake] — a large cinder-drake mage breathing cold cyan fire, ash-scaled.
41. **Hollowhorn** [mon_hollowhorn] — a massive horned abyssal guardian, dark hide, glowing cyan hollow eyes.
42. **Broodqueen Vassal** [mon_broodqueen_vassal] — a regal insectoid brood-matron support, elegant chitin, cyan glow.
43. **Ashen Cataphract** [mon_ashen_cataphract] — a heavily armored undead cavalry guardian in full ashen barding.
44. **Glacial Revenant** [mon_glacial_revenant] — a frozen undead warrior revenant encased in cracked cyan ice.
45. **Fiendlord** [mon_fiendlord] — a commanding abyssal fiend mage, dark regal horns, void-cyan corona.

### A-rank — grand mini-bosses, named (7)
46. **Cindervane** [mon_cindervane] — an imposing elite cinder-drake assassin, sweeping ash wings, cold cyan flame, grand and menacing.
47. **Hoarfrost Matron** [mon_hoarfrost_matron] — a towering regal ice-sylph mage-queen wreathed in a blizzard of cyan frost, ornate crystalline crown.
48. **Kaeric, the First Warden** [mon_kaeric] — a legendary ashen warden-lord warrior in ancient ornate plate with a massive blade, hollow cyan eyes, heroic scale.
49. **Voidcaller** [mon_voidcaller] — a sinister abyssal fiend mage tearing open void-rifts, dark robes, void-cyan energy, grand.
50. **Broodmother** [mon_broodmother] — a colossal insectoid brood-matron support, swollen chitin throne-body, radiant cyan glow.
51. **Rimewarden Sovereign** [mon_rimewarden_sovereign] — a majestic ice-sylph sovereign mage on a throne of frost, cyan crystalline regalia.
52. **Ashen Lord Commander** [mon_ashen_lord_commander] — a commanding undead ashen war-lord support raising a banner, cyan command-aura, regal armor.

### S-rank — colossal bosses, epic (5)
53. **Xir'Vok, Brood Sovereign** [mon_xirvok] — a regal insectoid hive-monarch, crowned chitin skull, spined crest, four bladed limbs, tattered royal shroud, orbiting drones, immense cyan glow, terrifying boss scale, epic key-art quality.
54. **Vharun, the Cinder Wyrm** [mon_vharun] — a colossal serpentine cinder-wyrm dragon exhaling cold cyan fire, vast ash-scaled coils, epic boss, cinematic.
55. **The Pale Sovereign** [mon_pale_sovereign] — a towering pale crowned abyssal demon-king wreathed in cold cyan flame, hollow radiant eyes, throne of the abyss, epic final-boss grandeur, cinematic.
56. **Ur-Grakh, the Bonemarch King** [mon_ur_grakh] — a giant bone-armored grave-warlord king warrior with a colossal cleaver, crown of tusks, mountainous, epic boss.
57. **Nyxaris, the Hollow Star** [mon_nyxaris] — a vast cosmic-horror abyssal entity of dark matter and a collapsing cyan star-core, countless glowing eyes, void tendrils, epic apocalyptic boss, cinematic.

---

## 5. EQUIPMENT — 50 base pieces (icon style)

Different composition from monsters/hero: a single **item icon**, centered, no character, on a plain dark background — built for an inventory grid. Filename: **`spr_<id>.png`**.

**EQUIPMENT MASTER SUFFIX** (append to every item subject below):
```
game item icon, centered on a plain near-black background, frost-cyan glow accents, crisp clean linework, high contrast, dark fantasy near-future RPG icon, dramatic single-source rim glow --style raw --ar 1:1 --no text, watermark, character, hands, body, background scene --sref <YOUR_CODE>
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
full character armor showcase, front three-quarter view, dark fantasy near-future RPG armor set, modern techwear blended with plate/leather, frost-cyan glowing accents, plain near-black background, crisp clean linework, dramatic rim lighting, high contrast, anime dark-fantasy illustration --style raw --ar 2:3 --no text, watermark, weapon in hand, background clutter, mask --sref <YOUR_CODE>
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

**Class icons (5)** — simple emblem badges, one per subclass:
- [ui_class_warrior]: `a minimalist glowing cyan emblem icon of crossed blades, centered on a plain near-black circular badge, crisp bold iconography, high contrast --style raw --ar 1:1 --no text, watermark, character`
- [ui_class_guardian]: `a minimalist glowing cyan emblem icon of a shield, centered on a plain near-black circular badge, crisp bold iconography, high contrast --style raw --ar 1:1 --no text, watermark, character`
- [ui_class_assassin]: `a minimalist glowing cyan emblem icon of twin curved blades, centered on a plain near-black circular badge, crisp bold iconography, high contrast --style raw --ar 1:1 --no text, watermark, character`
- [ui_class_mage]: `a minimalist glowing cyan emblem icon of an arcane rune circle, centered on a plain near-black circular badge, crisp bold iconography, high contrast --style raw --ar 1:1 --no text, watermark, character`
- [ui_class_support]: `a minimalist glowing cyan emblem icon of a banner and ward-sigil, centered on a plain near-black circular badge, crisp bold iconography, high contrast --style raw --ar 1:1 --no text, watermark, character`

**System UI frame** [ui_system_frame] — the reusable "status window" pop-up border (§9c of the design bible), for level-up/CLAIM/rank-up/floor-clear notifications:
```
a dark glass UI panel border frame, angular geometric cyan corner-brackets, thin glowing electric-cyan rune-etched border lines, mostly transparent dark center, sci-fi RPG "system status window" style, crisp, high contrast, symmetrical, clean vector-like linework --style raw --ar 1:1 --no text, watermark, character, gradient noise
```
*Note: pick a version with a clean, mostly-empty center — that's where text/rewards get overlaid later in-engine.*

**Rank badges (6)** — E through S, one per rank:
```
a minimalist glowing cyan badge icon displaying the bold stylized letter "<RANK>", centered on a plain near-black shield-shaped badge, dark fantasy RPG rank insignia, crisp, high contrast, dramatic glow --style raw --ar 1:1 --no watermark, no character
```
Swap `<RANK>` for **E, D, C, B, A, S** → filenames [ui_rank_e] … [ui_rank_s].
*Note: Midjourney can be inconsistent rendering single clean letters. If any come out garbled, that's the one case worth trying **Ideogram** instead (free tier, built for accurate text-in-image) — or just recreate the 6 badges quickly in Canva using the same cyan/black palette.*

---

## 8. Download + organise (as you go)

Folders (the Art Drop Tool creates these automatically as you drop images in):
- `HollowHunter/art/hero` — 3 hero formats
- `HollowHunter/art/promo` — 4 social variants
- `HollowHunter/art/presets` — 12 preset hunter portraits, `preset_hunter_<id>.png`
- `HollowHunter/art/monsters` — 57 portraits, `por_<id>.png`
- `HollowHunter/art/equipment` — 50 item icons, `spr_<id>.png`
- `HollowHunter/art/sets` — 15 set showcases, `<id>.png`
- `HollowHunter/art/ui` — 14 store/UI assets, `<id>.png`

All these filenames match the ids already in **monsters.json** / **equipment.json**, so wiring the final art into the game later is drag-and-drop, no renaming.

- Upscale the keeper before downloading (MJ's Upscale = higher res).
- Use the **HollowHunter_ArtDropTool.html** to drag each download onto its labeled slot — it auto-saves with the correct filename into the correct folder.
- On the MJ web app you can also bulk-select your creations and download in batches if you'd rather sort after.

---

## 9. Still lower-priority / not in this pass
- **Shadow-army composite sprites, gate/map art, background textures, VFX** — later, once the core visual identity (this pass) is proven and you're closer to the real art-polish milestone (§23 of the design bible).

---

*Prep is done. The expensive part (deciding) cost nothing. Subscribe, blitz, cancel.*
