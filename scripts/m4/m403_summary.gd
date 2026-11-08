extends RefCounted

# Frozen result projection; never a second live actor/clock owner.
const Classifier = preload("res://scripts/m4/m403_outcome_classifier.gd")


static func build(v: Dictionary) -> Dictionary:
	if not Classifier.valid_roster(v) or v.outcome.is_empty():
		return {}
	var o: Dictionary = v.outcome
	var party: Array = []
	var enemies: Array = []
	for id in v.initial_party:
		var s: Dictionary = v.actors[id].state
		var relation: String = "PRESENT_ALIVE_AT_END"
		if s.participation == "RETREATED": relation = "SELF_RETREATED"
		elif s.life_state == "DOWN": relation = "DOWN_AT_END"
		elif s.life_state == "DEAD": relation = "DEAD_AT_END"
		party.append({"actor_id": id, "role": s.role, "current_hp": s.current_hp,
			"life_state": s.life_state, "participation": s.participation,
			"final_down": v.clocks.get(id, {}).duplicate(true), "outcome_relation": relation})
	for id in v.initial_enemies:
		var hp: int = v.actors[id].state.current_hp
		enemies.append({"actor_id": id, "current_hp": hp, "availability": "AVAILABLE" if hp > 0 else "UNAVAILABLE",
			"combat_result": "ACTIVE_AT_END" if hp > 0 else "UNAVAILABLE_AT_END"})
	return {"schema_version": 1, "domain": "M403_ISOLATED_SUMMARY", "session": v.session,
		"generation": v.generation, "round_id": v.round_id, "outcome_id": o.outcome_id,
		"freeze_revision": o.freeze_revision, "encounter_outcome": o.encounter_outcome,
		"reason_code": o.reason_code, "party_lifecycle_rows": party, "enemy_combat_rows": enemies}
