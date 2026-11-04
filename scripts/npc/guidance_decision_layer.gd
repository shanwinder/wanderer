extends RefCounted

# M3A-03 Strategy B. Pure, versioned extension; never changes Legacy schemas.
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const CAPABILITIES: Array[String] = ["ATTACK", "DEFEND", "HELP", "FOCUS_TARGET"]
const ENVELOPE_FIELDS: Array[String] = ["schema_version", "base_context", "frozen_guidance",
	"actor_profile", "identity", "capabilities"]
const IDENTITY_FIELDS: Array[String] = ["encounter_id", "generation", "round_id",
	"guidance_revision", "snapshot_revision"]
const FROZEN_FIELDS: Array[String] = ["guidance_type", "issuer_player_id", "preferred_target_id",
	"encounter_id", "generation", "round_id", "guidance_revision"]
var _baseline = Resolver.new()


func decide_with_guidance(actor_id: Variant, envelope_v1: Variant) -> Dictionary:
	var invalid: String = _validate(actor_id, envelope_v1)
	if not invalid.is_empty():
		return {"status": "INVALID_INPUT", "reason_code": invalid}
	var baseline: Dictionary = _baseline.decide_for_actor(actor_id, envelope_v1.base_context)
	if baseline.status == "INVALID_INPUT":
		return {"status": "INVALID_INPUT", "reason_code": baseline.reason_code}
	var kind: String = envelope_v1.frozen_guidance.guidance_type
	if kind == "NONE":
		return _reply(baseline, baseline, "NONE", "NO_GUIDANCE", envelope_v1)
	if baseline.status == "SKIP":
		return _reply(baseline, baseline, "NOT_APPLICABLE", baseline.reason_code, envelope_v1)
	# Independent matches stay independent even at safety/urgent priority.
	if baseline.action == "DEFEND":
		return _reply(baseline, baseline, "MATCHED_INDEPENDENTLY" if kind == "DEFEND" else "REFUSED",
			"SELF_PRESERVATION_PRIORITY", envelope_v1)
	if baseline.action == "HELP":
		return _reply(baseline, baseline, "MATCHED_INDEPENDENTLY" if kind == "HELP" else "REFUSED",
			"URGENT_HELP_PRIORITY", envelope_v1)
	# Preserve priority7: low Player HP with exhausted HELP stays baseline ATTACK.
	if baseline.reason_code == "HELP_UNAVAILABLE_ATTACK":
		return _reply(baseline, baseline, "MATCHED_INDEPENDENTLY" if kind == "ATTACK" else "REFUSED",
			"RESOURCE_UNAVAILABLE" if kind == "HELP" else "HELP_UNAVAILABLE_BASELINE_PRIORITY", envelope_v1)
	if kind == "ATTACK":
		return _reply(baseline, baseline, "MATCHED_INDEPENDENTLY", "BASELINE_ATTACK", envelope_v1)
	if kind == "HELP":
		return _reply(baseline, baseline, "NOT_APPLICABLE", "PLAYER_ABOVE_HELP_THRESHOLD", envelope_v1)
	var profile: Dictionary = envelope_v1.actor_profile
	# Owner-approved isolated-proof predicate (5 November 2026), not final AI/balance.
	var cooperates: bool = profile.discipline == "PLAN_ORIENTED" or profile.trust == "ESTABLISHED"
	var decision: Dictionary = baseline.duplicate(true)
	if kind == "DEFEND":
		if baseline.reason_details.incoming_damage == 0:
			return _reply(baseline, baseline, "NOT_APPLICABLE", "NO_VALID_THREAT", envelope_v1)
		if not cooperates or profile.courage != "CAUTIOUS":
			return _reply(baseline, baseline, "REFUSED", "PROFILE_PREFERS_BASELINE", envelope_v1)
		decision.action = "DEFEND"
		decision.target_id = actor_id
		decision.reason_code = "GUIDANCE_DISCRETIONARY_DEFEND"
	else: # FOCUS_TARGET: target preference, evaluated from the current slot snapshot.
		var target: String = envelope_v1.frozen_guidance.preferred_target_id
		if not envelope_v1.base_context.actors[target].can_act:
			return _reply(baseline, baseline, "NOT_APPLICABLE", "TARGET_UNAVAILABLE", envelope_v1)
		if baseline.target_id == target:
			return _reply(baseline, baseline, "MATCHED_INDEPENDENTLY", "BASELINE_TARGET", envelope_v1)
		if not cooperates:
			return _reply(baseline, baseline, "REFUSED", "PROFILE_PREFERS_BASELINE", envelope_v1)
		decision.target_id = target
		decision.reason_code = "GUIDANCE_FOCUS_TARGET"
	return _reply(baseline, decision, "FOLLOWED", "PROFILE_PERMITTED_COOPERATION", envelope_v1)


func _reply(baseline: Dictionary, decision: Dictionary, response: String, reason: String,
	envelope: Dictionary) -> Dictionary:
	# Metadata lives beside the unchanged decision payload. Copies share no nested data.
	return {"status": "OK", "baseline_decision": baseline.duplicate(true),
		"decision": decision.duplicate(true), "guidance_response": {
			"response": response, "reason_code": reason,
			"details": {"frozen_guidance": envelope.frozen_guidance.duplicate(true),
				"actor_profile": envelope.actor_profile.duplicate(true),
				"identity": envelope.identity.duplicate(true),
				"behavior_changed": decision.action != baseline.action or decision.target_id != baseline.target_id}}}


func _validate(actor_id: Variant, envelope: Variant) -> String:
	if not Data._fields(envelope, ENVELOPE_FIELDS):
		return "INVALID_ENVELOPE_FIELDS"
	if typeof(envelope.schema_version) != TYPE_INT or envelope.schema_version != 1:
		return "INVALID_ENVELOPE_VERSION"
	if not Data._fields(envelope.identity, IDENTITY_FIELDS):
		return "INVALID_IDENTITY_FIELDS"
	for field in IDENTITY_FIELDS:
		if typeof(envelope.identity[field]) != TYPE_INT:
			return "INVALID_IDENTITY_TYPE"
		if field == "encounter_id":
			if envelope.identity[field] == 0:
				return "INVALID_IDENTITY_RANGE"
		elif envelope.identity[field] < (1 if field in ["generation", "round_id"] else 0):
			return "INVALID_IDENTITY_RANGE"
	if typeof(envelope.capabilities) != TYPE_ARRAY or envelope.capabilities != CAPABILITIES:
		return "UNSUPPORTED_CAPABILITIES"
	var invalid: String = _baseline._validate_context(actor_id, envelope.base_context)
	if not invalid.is_empty():
		return invalid
	if envelope.base_context.snapshot_revision != envelope.identity.snapshot_revision:
		return "STALE_SNAPSHOT_REVISION"
	invalid = Data.validate_profile(envelope.actor_profile)
	if not invalid.is_empty():
		return invalid
	if envelope.actor_profile.actor_id != actor_id \
		or envelope.actor_profile.player_id != envelope.base_context.player_id:
		return "FOREIGN_PROFILE"
	if not Data._fields(envelope.frozen_guidance, FROZEN_FIELDS):
		return "INVALID_FROZEN_FIELDS"
	var guidance: Dictionary = envelope.frozen_guidance
	# Reuse data-contract validation without adding fields to Legacy decide_for_actor.
	invalid = Data.validate_request({"schema_version": 1, "guidance_type": guidance.guidance_type,
		"issuer_player_id": guidance.issuer_player_id, "preferred_target_id": guidance.preferred_target_id,
		"encounter_id": guidance.encounter_id, "generation": guidance.generation,
		"round_id": guidance.round_id, "expected_guidance_revision": guidance.guidance_revision})
	if not invalid.is_empty():
		return invalid
	for field in ["encounter_id", "generation", "round_id", "guidance_revision"]:
		if guidance[field] != envelope.identity[field]:
			return "FROZEN_IDENTITY_MISMATCH:" + field
	if guidance.issuer_player_id != envelope.base_context.player_id:
		return "FOREIGN_ISSUER"
	if guidance.guidance_type == "FOCUS_TARGET" \
		and not envelope.base_context.enemy_order.has(guidance.preferred_target_id):
		return "UNKNOWN_FOCUS_TARGET"
	return ""
