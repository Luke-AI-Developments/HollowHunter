class_name DebugGrant
## Debug-only: give a HunterState one of every shadow (monsters.json) and one
## of every base equipment def (equipment.json), for auditing all art in a
## single pass on device. Idempotent -- skips monster_ids already in the army
## and equipment_def_ids already in the inventory, so re-running on a later
## launch grants nothing new. The CALLER gates this to
## OS.is_debug_build() + the `debug/grant_all_content` project flag; nothing
## here is reachable in a release build.


static func grant_all(state: HunterState, monsters: Array, equipment: Dictionary) -> Dictionary:
	var owned_monsters := {}
	for shadow: Dictionary in state.army:
		owned_monsters[String(shadow.get("monster_id", ""))] = true
	var shadows_added := 0
	for m: Dictionary in monsters:
		if not owned_monsters.has(String(m["id"])):
			state.claim_shadow(String(m["id"]), String(m["rank"]))
			shadows_added += 1

	var owned_defs := {}
	for item: Dictionary in state.inventory:
		owned_defs[String(item.get("equipment_def_id", ""))] = true
	var items_added := 0
	for d: Dictionary in equipment.get("base_equipment", []):
		if not owned_defs.has(String(d["id"])):
			state.add_to_inventory(String(d["id"]))
			items_added += 1

	return {"shadows_added": shadows_added, "items_added": items_added}
