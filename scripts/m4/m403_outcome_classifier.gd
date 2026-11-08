extends RefCounted

# Pure D10-A. No queue filtering, mutations, or production lifecycle mapping.
const State = preload("res://scripts/m4/isolated_actor_state.gd")
const Queue = preload("res://scripts/m4/m403_queue_adapter.gd")


static func valid_roster(v: Variant) -> bool:
	if typeof(v) != TYPE_DICTIONARY or typeof(v.get("initial_party")) != TYPE_ARRAY \
		or typeof(v.get("initial_enemies")) != TYPE_ARRAY or typeof(v.get("actors")) != TYPE_DICTIONARY \
		or v.initial_party.is_empty() or v.initial_enemies.is_empty():
		return false
	var seen: Dictionary = {}
	for id in v.initial_party + v.initial_enemies:
		if typeof(id) != TYPE_STRING or seen.has(id) or not v.actors.has(id) \
			or not Queue.valid_observation(v.actors[id], id):
			return false
		seen[id] = true
		var role: String = "PLAYER" if id == v.initial_party[0] else ("NPC" if id in v.initial_party else "ENEMY")
		if v.actors[id].definition.role != role:
			return false
	return seen.size() == v.actors.size()


static func classify(v: Variant) -> Dictionary:
	if not valid_roster(v):
		return {"status": "REJECTED", "reason_code": "M403_INVALID_ROSTER"}
	var p: int = 0
	var e: int = 0
	var r: int = 0
	for id in v.initial_party:
		var s: Dictionary = v.actors[id].state
		p += int(s.life_state == "ALIVE" and s.participation == "PRESENT")
		r += int(s.life_state == "ALIVE" and s.participation == "RETREATED")
	for id in v.initial_enemies:
		e += int(v.actors[id].state.current_hp > 0)
	var outcome: String
	var reason: String
	if p > 0:
		outcome = "ACTIVE" if e > 0 else "VICTORY"
		reason = "M403_CONTINUE" if e > 0 else "M403_ENEMIES_UNAVAILABLE"
	elif r == v.initial_party.size():
		outcome = "PARTY_RETREAT"
		reason = "M403_ALL_PARTY_RETREATED"
	elif r > 0:
		outcome = "MIXED_WITHDRAWAL"
		reason = "M403_ESCAPED_WITH_LEFT_BEHIND"
	else:
		outcome = "DEFEAT"
		reason = "M403_MUTUAL_INCAPACITATION" if e == 0 else "M403_NO_ACTIVE_PARTY"
	return {"status": "CLASSIFIED", "encounter_outcome": outcome, "reason_code": reason}
