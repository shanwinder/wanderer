extends "res://scripts/m4/isolated_queue_outcome_encounter.gd"

# Opt-in C facade: one inherited authority root/Registry, no wrapped Encounter.
# A/B source and API surfaces are unchanged. Rules only calculate detached data.
const Rules = preload("res://scripts/m4/m403_terminal_rules.gd")


func _valid_candidate(candidate: Variant) -> bool:
	return Rules.valid(candidate) and candidate.session == _session and _registry(candidate.actors) != null


func _publish(candidate: Variant, expected_revision: int, resetting: bool = false,
	operation: String = "UNAVAILABLE", payload: Dictionary = {}) -> String:
	if _root.revision != expected_revision: return "M403_STALE_REVISION"
	if not _valid_candidate(candidate): return "M403_INVALID_CANDIDATE"
	if resetting:
		if candidate.generation != _root.generation + 1 or candidate.revision != 0 \
			or candidate != Rules.prepare(_session, candidate.generation, payload): return "M403_INVALID_CANDIDATE"
	else:
		var expected: Dictionary = Rules.apply(snapshot(), operation, payload)
		if not expected.has("candidate") or expected.candidate != candidate: return "M403_INVALID_CANDIDATE"
	var owned: Dictionary = candidate.duplicate(true)
	var registry = _registry(owned.actors)
	owned.erase("actors")
	owned.registry = registry
	# No callback, await, signal or virtual writer after validation and before swap.
	_root = owned
	return ""


func restart(request: Variant, capability: Variant) -> Dictionary:
	if not PartyState.exact_fields(request, Rules.BASE + ["fixture"]): return _reply("M403_INVALID_FIELDS")
	var envelope: Dictionary = request.duplicate(true)
	envelope.erase("fixture")
	if not Rules.typed(envelope, Rules.BASE) or typeof(request.fixture) != TYPE_DICTIONARY: return _reply("M403_INVALID_FIELDS")
	if request.session != _session: return _reply("M403_FOREIGN_SESSION")
	if request.generation != _root.generation: return _reply("M403_STALE_GENERATION")
	if _authority == null or capability != _authority: return _reply("M403_UNAUTHORIZED")
	if request.queue_id != _root.queue.get("queue_id", ""): return _reply("M403_WRONG_QUEUE")
	if request.expected_revision != _root.revision: return _reply("M403_STALE_REVISION")
	if _root.generation == 9223372036854775807: return _reply("M403_INVALID_RESTART")
	var c: Dictionary = Rules.prepare(_session, _root.generation + 1, request.fixture)
	if c.is_empty(): return _reply("M403_INVALID_RESTART")
	if _root.phase == "SEALED": return _reply("M403_INVALID_PHASE")
	var reason: String = _publish(c, _root.revision, true, "RESTART", request.fixture)
	return _reply(reason) if not reason.is_empty() else _reply("M403_RESTARTED", "APPLIED")


func _execute(operation: String, payload: Variant, capability: Variant = null) -> Dictionary:
	var before: Dictionary = snapshot()
	var reason: String = Rules.protocol(before, operation, payload)
	if not reason.is_empty(): return _reply(reason)
	if operation in Rules.REQUEST_OPS and (_authority == null or capability != _authority): return _reply("M403_UNAUTHORIZED")
	if _root.generation == 0: return _reply("M403_INVALID_PHASE")
	var result: Dictionary = Rules.apply(before, operation, payload)
	if not result.has("candidate"): return result
	reason = _publish(result.candidate, before.revision, false, operation, payload)
	result.erase("candidate")
	return _reply(reason) if not reason.is_empty() else result


func open_round(request: Variant, capability: Variant) -> Dictionary:
	return _execute("OPEN", request, capability)


func advance(request: Variant, capability: Variant) -> Dictionary:
	return _execute("ADVANCE", request, capability)


func lock_self_retreat(request: Variant, capability: Variant) -> Dictionary:
	return _execute("RETREAT", request, capability)


func lock_fixture_attack(request: Variant, capability: Variant) -> Dictionary:
	return _execute("ATTACK", request, capability)


func lock_fixture_rescue(request: Variant, capability: Variant) -> Dictionary:
	return _execute("RESCUE", request, capability)


func impact(token: Variant) -> Dictionary:
	return _execute("IMPACT", token)


func complete(token: Variant) -> Dictionary:
	return _execute("COMPLETE", token)


func cancel(token: Variant) -> Dictionary:
	return _execute("CANCEL", token)


func seal(request: Variant, capability: Variant) -> Dictionary:
	return _execute("SEAL", request, capability)


func close(event: Variant) -> Dictionary:
	return _execute("CLOSE", event)


func authorize_abort(request: Variant, capability: Variant) -> Dictionary:
	return _execute("AUTHORIZE_ABORT", request, capability)


func abort(token: Variant) -> Dictionary:
	return _execute("ABORT", token)


func progress_diagnostic() -> Dictionary:
	if _root.generation == 0: return {"progress_status": "INVALID", "suspension_reason": "M403_INVALID_DIAGNOSTIC"}
	var v: Dictionary = snapshot()
	return Queue.progress_diagnostic({"round_phase": v.phase, "queue_phase": v.queue.phase,
		"pending": v.active_operation != null, "completed_actions": Rules.receipt_set(v).size(),
		"active_party": Queue.active_party(v), "active_enemies": Queue.active_enemies(v),
		"has_next_round": v.round_index + 1 < v.plan.size()})


func eligibility_snapshot(actor_id: Variant) -> Dictionary:
	var result: Dictionary = super.eligibility_snapshot(actor_id)
	result.queue_opportunity_available = result.queue_opportunity_available and _root.get("admitted", false) and _root.outcome.is_empty()
	return result


func summary_snapshot(identity: Variant) -> Dictionary:
	if not Rules.typed(identity, ["version", "session", "generation", "outcome_id"]): return _reply("M403_INVALID_FIELDS")
	if identity.session != _session: return _reply("M403_FOREIGN_SESSION")
	if identity.generation != _root.generation: return _reply("M403_STALE_GENERATION")
	if _root.outcome.is_empty(): return _reply("M403_SUMMARY_NOT_FROZEN", "ABSENT")
	if identity.outcome_id != _root.outcome.outcome_id: return _reply("M403_UNAUTHORIZED")
	return {"status": "FROZEN", "reason_code": "M403_OUTCOME_FROZEN", "outcome": _root.outcome.duplicate(true),
		"summary": _root.summary.duplicate(true)}
