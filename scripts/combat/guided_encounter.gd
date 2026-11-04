extends "res://scripts/combat/full_party_encounter.gd"

# Production M3A-04 adapter. Internal subclass seam; UI only uses Encounter APIs.
# All HP/Guard/HELP/queue/effects/tokens/completion remain inherited authority.
const Layer = preload("res://scripts/npc/guidance_decision_layer.gd")
var _guidance_layer = Layer.new()
var _slot_report: Dictionary = {}


func _npc_decision_for_slot(id: String) -> Dictionary:
	_slot_report = _guidance_layer.decide_with_guidance(id, {
		"schema_version": 1, "base_context": decision_context(),
		"frozen_guidance": _guidance_active.duplicate(true),
		"actor_profile": _guidance_profiles[id].duplicate(true),
		"identity": {"encounter_id": _encounter_id, "generation": _generation,
			"round_id": _round, "guidance_revision": _guidance_revision, "snapshot_revision": _revision},
		"capabilities": Layer.CAPABILITIES.duplicate()})
	# Internal envelope only: malformed external requests never reach this seam.
	if _slot_report.status != "OK":
		return _make_decision(id, "SKIP", "", "INVALID_GUIDED_ENVELOPE")
	return _slot_report.decision.duplicate(true)


func begin_next_action() -> Dictionary:
	_slot_report.clear()
	var token: Dictionary = super.begin_next_action()
	if token.has("decision") and _party_order.has(token.actor_id) and _slot_report.is_empty():
		# Base short-circuits unavailable actors before the policy seam. Explain the
		# skipped slot through the same Layer while preserving the base decision payload.
		_npc_decision_for_slot(token.actor_id)
		if _slot_report.get("status") == "OK":
			_slot_report.decision = token.decision.duplicate(true)
			_slot_report.baseline_decision = token.decision.duplicate(true)
	if token.has("decision") and not _slot_report.is_empty():
		# Metadata is locked beside decision, never fed back from actual impact.
		_locked["guidance_decision"] = _slot_report.duplicate(true)
		token = _locked.duplicate(true)
	return token
