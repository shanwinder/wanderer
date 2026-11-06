extends RefCounted

# Pure queue calculations. Only the isolated Encounter publishes authority.
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")


static func queue_id(session: int, generation: int, round_id: int) -> String:
	return "m403/queue/%s/%s/%s" % [session, generation, round_id]


static func build(session: int, generation: int, round_id: int, order: Array) -> Dictionary:
	var id: String = queue_id(session, generation, round_id)
	var opportunities: Array = []
	for i in range(order.size()):
		# Ordinals are issuer-owned; actor names never enter an issuer key.
		opportunities.append({"opportunity_id": "%s/opportunity/%s" % [id, i],
			"slot_id": "%s/slot/%s" % [id, i], "actor_id": order[i]})
	return {"queue_id": id, "phase": "READY", "opportunities": opportunities,
		"cursor": 0, "dispositions": {}}


static func actionable(row: Dictionary) -> bool:
	if row.is_empty():
		return false
	return row.state.can_act if row.membership == "ENEMY" else row.state.eligible


static func eligibility(view: Dictionary, actor_id: Variant) -> Dictionary:
	var exists: bool = typeof(actor_id) == TYPE_STRING and view.actors.has(actor_id)
	var row: Dictionary = view.actors[actor_id] if exists else {}
	var present: bool = exists and (row.membership == "ENEMY" or row.state.participation == "PRESENT")
	var can_act: bool = actionable(row)
	var owns_slot: bool = false
	var is_current: bool = false
	if exists and not view.queue.is_empty():
		for i in range(view.queue.opportunities.size()):
			if view.queue.opportunities[i].actor_id == actor_id:
				owns_slot = i >= view.queue.cursor
				is_current = i == view.queue.cursor
	return {"actor_exists": exists, "actor_present": present, "actor_actionable": can_act,
		"slot_eligible": can_act and owns_slot,
		"queue_opportunity_available": can_act and is_current and view.phase == "OPEN"
			and view.queue.phase == "READY" and view.active_operation == null}


static func valid_queue(view: Dictionary) -> bool:
	var q: Variant = view.queue
	if not PartyState.exact_fields(q, ["queue_id", "phase", "opportunities", "cursor", "dispositions"]) \
		or typeof(q.queue_id) != TYPE_STRING or typeof(q.phase) != TYPE_STRING \
		or typeof(q.opportunities) != TYPE_ARRAY or typeof(q.cursor) != TYPE_INT \
		or typeof(q.dispositions) != TYPE_DICTIONARY:
		return false
	var order: Array = view.initial_party + view.initial_enemies
	var initial: Dictionary = build(view.session, view.generation, view.round_id, order)
	for opportunity in q.opportunities:
		if not PartyState.exact_fields(opportunity, ["opportunity_id", "slot_id", "actor_id"]):
			return false
		for field in ["opportunity_id", "slot_id", "actor_id"]:
			if typeof(opportunity[field]) != TYPE_STRING:
				return false
	if q.queue_id != initial.queue_id or q.opportunities != initial.opportunities \
		or q.cursor < 0 or q.cursor > order.size() or q.dispositions.size() != q.cursor \
		or q.cursor != view.revision \
		or q.phase != ("DRAINED" if q.cursor == order.size() else "READY"):
		return false
	for i in range(q.cursor):
		var opportunity: Dictionary = q.opportunities[i]
		var disposition: Variant = q.dispositions.get(opportunity.opportunity_id)
		if not PartyState.exact_fields(disposition, ["slot_id", "actor_id", "kind", "observed_revision"]) \
			or typeof(disposition.observed_revision) != TYPE_INT \
			or disposition != {"slot_id": opportunity.slot_id, "actor_id": opportunity.actor_id,
				"kind": "UNAVAILABLE", "observed_revision": i} \
			or actionable(view.actors[opportunity.actor_id]):
			return false
	return true


static func unavailable_candidate(view: Dictionary) -> Dictionary:
	var c: Dictionary = view.duplicate(true)
	var q: Dictionary = c.queue
	var opportunity: Dictionary = q.opportunities[q.cursor]
	q.dispositions[opportunity.opportunity_id] = {"slot_id": opportunity.slot_id,
		"actor_id": opportunity.actor_id, "kind": "UNAVAILABLE", "observed_revision": view.revision}
	q.cursor += 1
	q.phase = "DRAINED" if q.cursor == q.opportunities.size() else "READY"
	c.revision += 1
	return c


# Pure future-boundary predicate, NOT a witness, receipt, or publication API.
# CLOSED and nonterminal-drained examples cannot be produced by foundation A.
static func progress_diagnostic(facts: Variant) -> Dictionary:
	var invalid: Dictionary = {"progress_status": "INVALID", "suspension_reason": "M403_INVALID_DIAGNOSTIC"}
	if not PartyState.exact_fields(facts, ["round_phase", "queue_phase", "pending", "completed_actions",
		"active_party", "active_enemies", "has_next_round"]):
		return invalid
	for field in ["round_phase", "queue_phase"]:
		if typeof(facts[field]) != TYPE_STRING:
			return invalid
	for field in ["pending", "has_next_round"]:
		if typeof(facts[field]) != TYPE_BOOL:
			return invalid
	for field in ["completed_actions", "active_party", "active_enemies"]:
		if typeof(facts[field]) != TYPE_INT or facts[field] < 0:
			return invalid
	if facts.round_phase not in ["UNINITIALIZED", "OPEN", "SEALED", "CLOSED", "ABORTED"] \
		or facts.queue_phase not in ["READY", "RUNNING", "WAIT_ACTION", "DRAINED", "STOPPED"]:
		return invalid
	var reason: String = ""
	if facts.active_party > 0 and facts.active_enemies > 0 and not facts.pending:
		if facts.round_phase == "OPEN" and facts.queue_phase == "DRAINED" and facts.completed_actions == 0:
			reason = "M403_NO_REAL_PROGRESS"
		elif facts.round_phase == "CLOSED" and not facts.has_next_round:
			reason = "M403_PLAN_EXHAUSTED"
	return {"progress_status": "SUSPENDED" if not reason.is_empty() else "FOUNDATION_ONLY",
		"suspension_reason": reason}
