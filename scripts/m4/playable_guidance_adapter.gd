extends RefCounted

# Pure value adapter. Owner storage and capability checks remain in Encounter.
const Data = preload("res://scripts/npc/guidance_data_contract.gd")

static func record(root: Dictionary, kind: String = "NONE", target: String = "") -> Dictionary:
	return {"guidance_type": kind, "issuer_player_id": "player", "preferred_target_id": target,
		"encounter_id": root.session, "generation": root.generation, "round_id": root.round_id,
		"guidance_revision": root.guidance.guidance_revision}

static func rejection(root: Dictionary, request: Variant) -> String:
	var invalid: String = Data.validate_request(request)
	if not invalid.is_empty(): return invalid
	for spec in [["encounter_id", root.session, "FOREIGN_ENCOUNTER"],
		["generation", root.generation, "STALE_GENERATION"], ["round_id", root.round_id, "WRONG_ROUND"],
		["issuer_player_id", "player", "INVALID_ISSUER"],
		["expected_guidance_revision", root.guidance.guidance_revision, "STALE_GUIDANCE_REVISION"]]:
		if request[spec[0]] != spec[1]: return spec[2]
	if request.guidance_type == "FOCUS_TARGET":
		var found: bool = false
		for enemy in root.enemies:
			if enemy.actor_id == request.preferred_target_id: found = true
		if not found: return "UNKNOWN_GUIDANCE_TARGET"
	return ""
