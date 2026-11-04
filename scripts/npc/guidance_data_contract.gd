extends RefCounted

# M3A-02: value validation only. No NPC policy, effects or persistent relationships.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const SCHEMA_VERSION: int = 1
const TYPES: Array[String] = ["NONE", "ATTACK", "DEFEND", "HELP", "FOCUS_TARGET"]
const REQUEST_FIELDS: Array[String] = ["schema_version", "guidance_type", "issuer_player_id",
	"preferred_target_id", "encounter_id", "generation", "round_id", "expected_guidance_revision"]
const PROFILE_FIELDS: Array[String] = ["schema_version", "actor_id", "player_id",
	"discipline", "trust", "compassion", "courage"]


static func _fields(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func validate_request(request: Variant) -> String:
	if not _fields(request, REQUEST_FIELDS):
		return "INVALID_GUIDANCE_FIELDS"
	if typeof(request.schema_version) != TYPE_INT or request.schema_version != SCHEMA_VERSION:
		return "INVALID_GUIDANCE_VERSION"
	if typeof(request.guidance_type) != TYPE_STRING or request.guidance_type not in TYPES:
		return "INVALID_GUIDANCE_TYPE"
	for field in ["issuer_player_id", "preferred_target_id"]:
		if typeof(request[field]) != TYPE_STRING:
			return "INVALID_GUIDANCE_ID"
	if not Definition.valid_actor_id(request.issuer_player_id):
		return "INVALID_GUIDANCE_ID"
	# The key is required; an empty string represents an absent preference.
	if request.guidance_type == "FOCUS_TARGET":
		if not Definition.valid_actor_id(request.preferred_target_id):
			return "INVALID_GUIDANCE_TARGET"
	elif not request.preferred_target_id.is_empty():
		return "INVALID_GUIDANCE_TARGET"
	for field in ["encounter_id", "generation", "round_id", "expected_guidance_revision"]:
		if typeof(request[field]) != TYPE_INT:
			return "INVALID_GUIDANCE_IDENTITY"
		# RefCounted instance IDs can be negative signed ints; preserve Encounter's ID.
		if field == "encounter_id":
			if request[field] == 0:
				return "INVALID_GUIDANCE_IDENTITY"
		elif request[field] < (0 if field == "expected_guidance_revision" else 1):
			return "INVALID_GUIDANCE_IDENTITY"
	return ""


static func validate_profile(profile: Variant) -> String:
	if not _fields(profile, PROFILE_FIELDS):
		return "INVALID_PROFILE_FIELDS"
	if typeof(profile.schema_version) != TYPE_INT or profile.schema_version != SCHEMA_VERSION:
		return "INVALID_PROFILE_VERSION"
	for field in ["actor_id", "player_id"]:
		if typeof(profile[field]) != TYPE_STRING or not Definition.valid_actor_id(profile[field]):
			return "INVALID_PROFILE_ID"
	if profile.actor_id == profile.player_id:
		return "INVALID_PROFILE_ID"
	for spec in [["discipline", ["FLEXIBLE", "PLAN_ORIENTED"]],
		["trust", ["CAUTIOUS", "ESTABLISHED"]], ["compassion", ["ORDINARY", "HIGH"]],
		["courage", ["CAUTIOUS", "BOLD"]]]:
		if typeof(profile[spec[0]]) != TYPE_STRING or profile[spec[0]] not in spec[1]:
			return "INVALID_PROFILE_TRAIT"
	return ""


static func fixed_profile(actor_id: String, player_id: String) -> Dictionary:
	# Explicit stable-ID fixtures, never party-slot personality or gameplay balance.
	var traits: Array = {
		"npc_01": ["PLAN_ORIENTED", "ESTABLISHED", "ORDINARY", "BOLD"],
		"npc_02": ["FLEXIBLE", "ESTABLISHED", "HIGH", "CAUTIOUS"],
		"npc_03": ["FLEXIBLE", "CAUTIOUS", "ORDINARY", "BOLD"]
	}.get(actor_id, ["FLEXIBLE", "CAUTIOUS", "ORDINARY", "CAUTIOUS"])
	var profile: Dictionary = {"schema_version": SCHEMA_VERSION, "actor_id": actor_id,
		"player_id": player_id, "discipline": traits[0], "trust": traits[1],
		"compassion": traits[2], "courage": traits[3]}
	return profile if validate_profile(profile).is_empty() else {}
