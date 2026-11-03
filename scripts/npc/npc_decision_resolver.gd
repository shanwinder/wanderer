extends RefCounted

# M2A-01 D1-D9: approved prototype rules, not final game balance.
# Pure data in/out. This proof knows exactly one enemy, not scene nodes.
const FIELDS: Array[String] = [
	"player_hp", "player_max_hp", "npc_hp", "npc_max_hp", "living_enemy_ids",
	"incoming_target_id", "incoming_damage", "help_enabled", "help_uses_remaining", "guidance"
]


func validate_snapshot(snapshot: Dictionary) -> String:
	for key in FIELDS:
		if not snapshot.has(key):
			return "MISSING_FIELD:" + key
	for key in snapshot:
		if key not in FIELDS:
			return "UNKNOWN_FIELD"
	for key in ["player_hp", "player_max_hp", "npc_hp", "npc_max_hp",
		"incoming_damage", "help_uses_remaining"]:
		if typeof(snapshot[key]) != TYPE_INT:
			return "INVALID_TYPE:" + key
	for actor in ["player", "npc"]:
		if snapshot[actor + "_max_hp"] <= 0 or snapshot[actor + "_hp"] < 0 \
			or snapshot[actor + "_hp"] > snapshot[actor + "_max_hp"]:
			return "INVALID_HP:" + actor
	if typeof(snapshot.help_enabled) != TYPE_BOOL:
		return "INVALID_TYPE:help_enabled"
	if snapshot.help_uses_remaining < 0 or snapshot.help_uses_remaining > 1:
		return "INVALID_HELP_USES"
	if typeof(snapshot.living_enemy_ids) != TYPE_ARRAY:
		return "INVALID_TYPE:living_enemy_ids"
	if snapshot.living_enemy_ids != [] and snapshot.living_enemy_ids != ["enemy_a"]:
		return "INVALID_ENEMY_IDS"
	if typeof(snapshot.incoming_target_id) != TYPE_STRING \
		or snapshot.incoming_target_id not in ["", "player", "npc"]:
		return "INVALID_INCOMING_TARGET"
	if snapshot.incoming_damage < 0 \
		or (snapshot.incoming_target_id == "" and snapshot.incoming_damage != 0):
		return "INVALID_INCOMING_DAMAGE"
	if typeof(snapshot.guidance) != TYPE_STRING or snapshot.guidance not in ["NONE", "ATTACK"]:
		return "INVALID_GUIDANCE"
	return ""


func decide(snapshot: Dictionary) -> Dictionary:
	var invalid: String = validate_snapshot(snapshot)
	if not invalid.is_empty():
		return {"status": "INVALID_INPUT", "action": "INVALID", "target_id": "",
			"reason_code": invalid, "reason_details": {}}
	# A copied explanation records what the NPC knew at the start of its slot.
	var details: Dictionary = snapshot.duplicate(true)
	if snapshot.player_hp == 0:
		return _decision("SKIP", "", "PLAYER_DEFEATED", details)
	if snapshot.living_enemy_ids.is_empty():
		return _decision("SKIP", "", "NO_LIVING_ENEMY", details)
	if snapshot.npc_hp == 0:
		return _decision("SKIP", "", "ACTOR_UNAVAILABLE", details)
	var threatened: bool = snapshot.incoming_target_id == "npc" and snapshot.incoming_damage > 0
	if threatened and _low_hp(snapshot.npc_hp, snapshot.npc_max_hp):
		return _decision("DEFEND", "npc", "SELF_LOW_HP_THREAT", details)
	if threatened and snapshot.incoming_damage >= snapshot.npc_hp:
		return _decision("DEFEND", "npc", "SELF_LETHAL_THREAT", details)
	if _low_hp(snapshot.player_hp, snapshot.player_max_hp):
		if snapshot.help_enabled and snapshot.help_uses_remaining > 0:
			return _decision("HELP", "player", "PLAYER_LOW_HP_HELP", details)
		details["help_unavailable_reason"] = (
			"HELP_DISABLED" if not snapshot.help_enabled else "NO_HELP_USES"
		)
		return _decision("ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK", details)
	return _decision("ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY", details)


func _low_hp(hp: int, maximum: int) -> bool:
	# Integer comparison includes exactly 30%, without rounding ambiguity.
	return hp * 100 <= maximum * 30


func _decision(action: String, target: String, reason: String, details: Dictionary) -> Dictionary:
	return {"status": "SKIP" if action == "SKIP" else "DECIDED",
		"action": action, "target_id": target, "reason_code": reason, "reason_details": details}
