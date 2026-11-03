extends RefCounted

# M2A-01 D1-D9: approved prototype rules, not final game balance.
# Pure data in/out. Legacy validation stays strict; multi-actor input is separate.
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
	return _policy(snapshot, "npc", "player", "enemy_a")


func _policy(snapshot: Dictionary, self_id: String, player_id: String, enemy_id: String) -> Dictionary:
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
		return _decision("DEFEND", self_id, "SELF_LOW_HP_THREAT", details)
	if threatened and snapshot.incoming_damage >= snapshot.npc_hp:
		return _decision("DEFEND", self_id, "SELF_LETHAL_THREAT", details)
	if _low_hp(snapshot.player_hp, snapshot.player_max_hp):
		if snapshot.help_enabled and snapshot.help_uses_remaining > 0:
			return _decision("HELP", player_id, "PLAYER_LOW_HP_HELP", details)
		details["help_unavailable_reason"] = (
			"HELP_DISABLED" if not snapshot.help_enabled else "NO_HELP_USES"
		)
		return _decision("ATTACK", enemy_id, "HELP_UNAVAILABLE_ATTACK", details)
	return _decision("ATTACK", enemy_id, "ATTACK_AVAILABLE_ENEMY", details)


func _low_hp(hp: int, maximum: int) -> bool:
	# Integer comparison includes exactly 30%, without rounding ambiguity.
	return hp * 100 <= maximum * 30


func _decision(action: String, target: String, reason: String, details: Dictionary) -> Dictionary:
	return {"status": "SKIP" if action == "SKIP" else "DECIDED",
		"action": action, "target_id": target, "reason_code": reason, "reason_details": details}


# Deliberately separate schema: never loosen validate_snapshot() for legacy callers.
func decide_for_actor(actor_id: Variant, context: Variant) -> Dictionary:
	var invalid: String = _validate_context(actor_id, context)
	if not invalid.is_empty():
		return {"status": "INVALID_INPUT", "action": "INVALID", "target_id": "",
			"reason_code": invalid, "reason_details": {}}
	var actor: Dictionary = context.actors[actor_id]
	var player: Dictionary = context.actors[context.player_id]
	var living: Array = []
	for id in context.enemy_order:
		if context.actors[id].can_act:
			living.append(id)
	# D12: first still-valid declared hit targeting this NPC, not aggregate damage.
	var incoming: int = 0
	for hit in context.declared_hits:
		if hit.target_id == actor_id and context.actors[hit.actor_id].can_act:
			incoming = hit.damage
			break
	var situation: Dictionary = {"player_hp": player.current_hp, "player_max_hp": player.max_hp,
		"npc_hp": actor.current_hp, "npc_max_hp": actor.max_hp, "living_enemy_ids": living,
		"incoming_target_id": "npc" if incoming > 0 else "", "incoming_damage": incoming,
		"help_enabled": true, "help_uses_remaining": context.help_uses[actor_id], "guidance": "NONE"}
	var decision: Dictionary = _policy(situation, actor_id, context.player_id,
		"" if living.is_empty() else living[0])
	decision["actor_id"] = actor_id
	decision["snapshot_revision"] = context.snapshot_revision
	decision.reason_details["declared_hits"] = context.declared_hits.duplicate(true)
	return decision


func _fields(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for key in fields:
		if not value.has(key):
			return false
	return true


func _validate_context(actor_id: Variant, context: Variant) -> String:
	if not _fields(context, ["actors", "player_id", "party_order", "enemy_order",
		"help_uses", "declared_hits", "snapshot_revision"]):
		return "INVALID_CONTEXT"
	if typeof(actor_id) != TYPE_STRING or typeof(context.player_id) != TYPE_STRING \
		or typeof(context.actors) != TYPE_DICTIONARY or typeof(context.party_order) != TYPE_ARRAY \
		or typeof(context.enemy_order) != TYPE_ARRAY or typeof(context.help_uses) != TYPE_DICTIONARY \
		or typeof(context.declared_hits) != TYPE_ARRAY or typeof(context.snapshot_revision) != TYPE_INT \
		or context.snapshot_revision < 0:
		return "INVALID_CONTEXT_TYPE"
	if context.party_order.size() > 3 or context.enemy_order.size() not in [1, 2] \
		or not context.party_order.has(actor_id):
		return "INVALID_ACTOR_MEMBERSHIP"
	var seen: Dictionary = {}
	for group in [[[context.player_id], "PLAYER", "PARTY"],
		[context.party_order, "NPC", "PARTY"], [context.enemy_order, "ENEMY", "ENEMY"]]:
		for id in group[0]:
			if typeof(id) != TYPE_STRING or seen.has(id) or not context.actors.has(id):
				return "INVALID_ROSTER"
			seen[id] = true
			var actor: Variant = context.actors[id]
			if not _fields(actor, ["actor_id", "display_name", "role", "base_max_hp",
				"current_hp", "max_hp", "can_act", "membership"]):
				return "INVALID_ACTOR"
			var definition = preload("res://scripts/actors/actor_definition.gd").create({
				"actor_id": actor.actor_id, "display_name": actor.display_name,
				"role": actor.role, "base_max_hp": actor.base_max_hp})
			if definition == null or actor.actor_id != id or actor.role != group[1] \
				or actor.membership != group[2] or typeof(actor.current_hp) != TYPE_INT \
				or typeof(actor.max_hp) != TYPE_INT or actor.max_hp != actor.base_max_hp \
				or actor.current_hp < 0 or actor.current_hp > actor.max_hp \
				or typeof(actor.can_act) != TYPE_BOOL or actor.can_act != (actor.current_hp > 0):
				return "INVALID_ACTOR_STATE"
	if seen.size() != context.actors.size() or context.help_uses.size() != context.party_order.size():
		return "INVALID_ROSTER"
	for id in context.party_order:
		if not context.help_uses.has(id) or typeof(context.help_uses[id]) != TYPE_INT \
			or context.help_uses[id] not in [0, 1]:
			return "INVALID_HELP_USES"
	if context.declared_hits.size() != context.enemy_order.size():
		return "INVALID_DECLARED_HITS"
	for i in range(context.enemy_order.size()):
		var hit: Variant = context.declared_hits[i]
		if not _fields(hit, ["actor_id", "target_id", "damage"]):
			return "INVALID_DECLARED_HIT"
		if hit.actor_id != context.enemy_order[i] or typeof(hit.target_id) != TYPE_STRING \
			or not ([context.player_id] + context.party_order).has(hit.target_id) \
			or typeof(hit.damage) != TYPE_INT or hit.damage != 3:
			return "INVALID_DECLARED_HIT"
	return ""
