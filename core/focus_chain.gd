class_name FocusChain
## Spec §7.2/§7.3: the cross-class focus-fire chain counter and the free
## Focus target lever. State (chain_target_id / chain_count /
## _last_chainer_class / focus_target_id) lives on the Battle instance;
## these static helpers are the logic, split out of core/battle.gd to keep
## it under the file-length lint. Pure -- no engine deps.


## Spec §7.2: the damage multiplier for a party hit whose first target is
## `first_target_id`, from the CURRENT chain_count. 1.0 for a fresh chain
## (count 0). advance() does the state transition afterwards.
static func chain_multiplier(battle: Battle, first_target_id: String) -> float:
	if first_target_id != battle.chain_target_id:
		return 1.0
	return 1.0 + battle.CHAIN_DAMAGE_STEP * float(mini(battle.chain_count, battle.CHAIN_COUNT_CAP))


## Spec §7.2 state transition after a party member damages an enemy.
static func advance(battle: Battle, actor_class: String, damaged_target_id: String) -> void:
	if damaged_target_id == battle.chain_target_id and actor_class != battle._last_chainer_class:
		battle.chain_count = mini(battle.chain_count + 1, battle.CHAIN_COUNT_CAP)
	else:
		battle.chain_target_id = damaged_target_id
		battle.chain_count = 0
	battle._last_chainer_class = actor_class


## Spec §7.2: a party turn that dealt no damage to chain_target_id keeps the
## target but drops the count and the last-chainer lock.
static func reset_keep_target(battle: Battle) -> void:
	battle.chain_count = 0
	battle._last_chainer_class = ""


## Spec §7.3: set the focus-fire target. Free -- no turn consumed, queue
## untouched. Ignored unless `enemy_id` names a living enemy.
static func set_focus(battle: Battle, enemy_id: String) -> void:
	var e := battle._combatant_by_id(enemy_id)
	if e.is_empty() or e.get("is_enemy", false) == false or int(e.get("hp", 0)) <= 0:
		return
	battle.focus_target_id = enemy_id
	battle.log.append({"type": "focus", "target_id": enemy_id})


## Spec §7.3: clear the focus-fire target.
static func clear_focus(battle: Battle) -> void:
	battle.focus_target_id = ""
	battle.log.append({"type": "focus", "target_id": ""})


## Drop a stale Focus when its enemy is gone. Cheap; called from
## Battle._finish_check so every resolution path covers it.
static func clear_if_dead(battle: Battle) -> void:
	if battle.focus_target_id == "":
		return
	var e := battle._combatant_by_id(battle.focus_target_id)
	if e.is_empty() or int(e.get("hp", 0)) <= 0:
		battle.focus_target_id = ""
