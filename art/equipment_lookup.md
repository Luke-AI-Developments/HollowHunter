# Equipment lookup — Midjourney feed → drop-tool slot

The v2 prompts start with a *description* rather than the item name, so the feed no longer shows "Warcleaver…". Use this to match. The same descriptions now also appear **on each slot in the Art Drop Tool**, so you can match in either direction.

Feed order is newest-first: **Support → Mage → Assassin → Guardian → Warrior**.

## WARRIOR — ember / crimson / iron
| What you see in the feed | Slot |
|---|---|
| plain heavy cleaver-axe | `spr_eq_warcleaver` *(already saved, old art)* |
| double-bladed greataxe, crimson rune edge | `spr_eq_gravebite_greataxe` |
| steel helm, heavy brow ridge, amber visor slit | `spr_eq_ironbrow_helm` |
| ash-grey plate chestpiece, ember glow in the seams | `spr_eq_ashplate_cuirass` |
| massive plate, molten orange-gold engravings | `spr_eq_juggernaut_plate` |
| knuckle gauntlets, scuffed iron — **no glow** | `spr_eq_bruiser_gauntlets` |
| armored boots, thick treads, crimson rune trim | `spr_eq_trampling_sabatons` |
| shin greaves, brass rivets, faint brass sheen | `spr_eq_marching_greaves` |
| heavy iron war-ring, blood-red glow | `spr_eq_berserker_signet` |
| neck-torc, gold filigree, warm gold light | `spr_eq_warlord_torc` |

## GUARDIAN — gold / amber / stone
| What you see in the feed | Slot |
|---|---|
| plain round steel shield — **no glow** | `spr_eq_bulwark_shield` |
| rectangular tower shield, gold rune border | `spr_eq_aegis_wall` |
| barbute helm, faint steel-blue sheen on crest | `spr_eq_wardens_barbute` |
| plate cuirass, brass buckles, faint brass edging | `spr_eq_sentinel_cuirass` |
| colossal plate, deep amber engraved channels | `spr_eq_immovable_plate` |
| plate gauntlets, thick leather cuffs — **no glow** | `spr_eq_ramguard_gauntlets` |
| greaves wrapped in root growth, mossy green trim | `spr_eq_rootstep_greaves` |
| armored boots, dull bronze tone | `spr_eq_anchor_sabatons` |
| stone pendant bound in iron, amber light inside | `spr_eq_stoneheart_charm` |
| shield-shaped sigil pendant, brilliant gold crest | `spr_eq_bastion_sigil` |

## ASSASSIN — cold silver-blue / crimson
| What you see in the feed | Slot |
|---|---|
| single curved dagger, leather grip — **no glow** | `spr_eq_shadowfang_dagger` |
| twin curved daggers, silver-blue edges | `spr_eq_twin_fangs` **← take the SECOND version; the first has no coloured glow** |
| dark cloth hood, cold silver-blue hem | `spr_eq_gloamhood` |
| sleek dark leather vest, faint silver stitching | `spr_eq_nightweave_vest` |
| layered leather, ghost-white stitched patterns | `spr_eq_phantom_leathers` |
| leather hand-wraps — **no glow** | `spr_eq_silent_grips` |
| leather boots, pale blue rune sole seams | `spr_eq_gloamstep_boots` |
| light running shoes, faint silver sheen | `spr_eq_fleetfoot_shoes` |
| slim dark ring, thin crimson line | `spr_eq_killers_band` |
| dark pendant, cold silver-white engraving | `spr_eq_umbral_pendant` |

## MAGE — elemental per item
| What you see in the feed | Slot |
|---|---|
| gnarled dark wooden wand, bark still on — **no glow** | `spr_eq_blightwood_wand` |
| dark staff, burning ember-orange orb | `spr_eq_cindercore_staff` |
| pale grey hooded cowl, cool pale blue edge | `spr_eq_seers_cowl` |
| dark robe, warm gold rune-stitching | `spr_eq_runespun_robe` |
| charcoal vestments, white-gold glowing runes | `spr_eq_archon_vestments` |
| fingerless cloth gloves — **no glow** | `spr_eq_channelers_gloves` |
| gossamer pale slippers, ghost-green trim | `spr_eq_wraithsilk_slippers` |
| leather sandals, dusty and travelled | `spr_eq_wanderers_sandals` |
| sigil ring, deep arcane blue crystal | `spr_eq_mana_sigil` |
| eye-shaped amulet, luminous pale gold iris | `spr_eq_oracles_eye` |

## SUPPORT — warm gold / bone-white
| What you see in the feed | Slot |
|---|---|
| carved wooden totem, unpainted — **no glow** | `spr_eq_rally_totem` |
| banner, bone-white cloth, pale gold runes | `spr_eq_bonemarch_banner` |
| undyed linen hood, faint warm gold trim | `spr_eq_chaplains_hood` |
| layered dark robe, warm gold seams | `spr_eq_wardenpriest_robe` |
| ornate cream-and-gold vestments, radiant | `spr_eq_hierophant_vestments` |
| soft linen gloves — **no glow** | `spr_eq_blessing_gloves` |
| travelling boots, amber rune trim on the welt | `spr_eq_shepherds_treads` |
| simple sandals, light leather straps | `spr_eq_acolyte_sandals` |
| chime-shaped charm, soft silver light | `spr_eq_wardsong_charm` |
| shield-and-banner pendant, brilliant gold | `spr_eq_aegis_of_the_host` |

---

**Tip for the ambiguous ones:** several pieces are visually similar (three pairs of sandals/shoes, several plain gloves). Distinguish by *material and colour*, not shape — e.g. `wanderers_sandals` are leather and dusty, `acolyte_sandals` are lighter with fine straps; `channelers_gloves` are grey and fingerless, `blessing_gloves` are undyed linen and full-fingered.
