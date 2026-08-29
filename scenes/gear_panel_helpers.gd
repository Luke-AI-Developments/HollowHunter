class_name GearPanelHelpers
## Shared node-building + display-formatting helpers for HunterGearView and
## ShadowGearView -- both panels build an identical 7-row (Equip.SLOTS)
## gear grid and render the same "active sets"/"equipped item" text, just
## against different equipped dicts (the hunter's vs whichever shadow is
## selected). Static, holds no state of its own -- engine-dependent (Node
## construction), so this lives in scenes/ rather than core/.


## Creates one row (slot label + Equip Best + Unequip + Enhance buttons) per
## Equip.SLOTS under `parent`, stacked from `y_start`. Placeholder art --
## plain Label/Button, no icons/paper-doll art yet.
static func build_gear_rows(parent: Node2D, y_start: float) -> Array:
	var rows := []
	var y := y_start
	for slot in Equip.SLOTS:
		var row_label := Label.new()
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(340, 40)
		parent.add_child(row_label)

		var equip_btn := Button.new()
		equip_btn.position = Vector2(390, y)
		equip_btn.size = Vector2(150, 40)
		equip_btn.text = "Equip Best"
		parent.add_child(equip_btn)

		var unequip_btn := Button.new()
		unequip_btn.position = Vector2(550, y)
		unequip_btn.size = Vector2(130, 40)
		unequip_btn.text = "Unequip"
		parent.add_child(unequip_btn)

		var enhance_btn := Button.new()
		enhance_btn.position = Vector2(690, y)
		enhance_btn.size = Vector2(160, 40)
		enhance_btn.text = "Enhance"
		parent.add_child(enhance_btn)

		var browse_btn := Button.new()
		browse_btn.position = Vector2(860, y)
		browse_btn.size = Vector2(130, 40)
		browse_btn.text = "Browse"
		parent.add_child(browse_btn)

		(
			rows
			. append(
				{
					"slot": slot,
					"label": row_label,
					"equip_btn": equip_btn,
					"unequip_btn": unequip_btn,
					"enhance_btn": enhance_btn,
					"browse_btn": browse_btn,
				}
			)
		)
		y += 50
	return rows


## Resolves an inventory instance_id to a display string via `inventory` +
## `equipment`.
static func equipped_item_display(
	instance_id: String, inventory: Array, equipment: Dictionary
) -> String:
	if instance_id == "":
		return "(empty)"
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
			if not def.is_empty():
				var level: int = item.get("enhancement_level", 0)
				var effective := Equip.enhanced_def(def, level)
				return "%s +%d (Lv%d)" % [def["name"], effective["power_bonus"], level]
	return "(unknown)"


## Renders ArmorSets.active_set_bonuses() for a given equipped dict (the
## hunter's or a shadow's) into display text. bonus_2pc/4pc text is shown
## verbatim -- see core/armor_sets.gd for which parts are mechanical
## (stat text + any "N% power" token) vs pure flavor.
static func active_sets_display(
	equipped: Dictionary, inventory: Array, equipment: Dictionary
) -> String:
	var active := ArmorSets.active_set_bonuses(equipped, inventory, equipment)
	if active.is_empty():
		return "Active sets: (none)"
	var lines := ["Active sets:"]
	for set_bonus: Dictionary in active:
		var pieces: int = set_bonus["pieces_equipped"]
		lines.append(" - %s (%d/4 pieces)" % [set_bonus["name"], pieces])
		lines.append("     2pc: %s" % set_bonus["bonus_2pc_text"])
		if set_bonus["active_4pc"]:
			lines.append("     4pc: %s" % set_bonus["bonus_4pc_text"])
	return "\n".join(lines)
