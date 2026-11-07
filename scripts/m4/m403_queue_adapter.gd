extends RefCounted

# Pure queue calculations. Only the isolated Encounter publishes authority.
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")


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
		or q.cursor > view.revision \
		or q.phase != ("DRAINED" if q.cursor == order.size() else ("WAIT_ACTION" if view.active_operation != null else "READY")):
		return false
	var last_revision: int = -1
	for i in range(q.cursor):
		var opportunity: Dictionary = q.opportunities[i]
		var disposition: Variant = q.dispositions.get(opportunity.opportunity_id)
		if typeof(disposition) != TYPE_DICTIONARY or typeof(disposition.get("kind")) != TYPE_STRING:
			return false
		var fields: Array = ["slot_id", "actor_id", "kind", "observed_revision", "issuer_id"] + \
			(["observed_actor"] if disposition.kind == "UNAVAILABLE" else ["action_id"])
		if not PartyState.exact_fields(disposition, fields) or typeof(disposition.observed_revision) != TYPE_INT:
			return false
		for field in ["slot_id", "actor_id", "kind", "issuer_id"]:
			if typeof(disposition[field]) != TYPE_STRING:
				return false
		if disposition.slot_id != opportunity.slot_id or disposition.actor_id != opportunity.actor_id \
			or disposition.issuer_id != "M403_ISOLATED_QUEUE" \
			or disposition.observed_revision <= last_revision or disposition.observed_revision >= view.revision:
			return false
		if disposition.kind == "UNAVAILABLE":
			if not valid_observation(disposition.observed_actor, opportunity.actor_id) or actionable(disposition.observed_actor):
				return false
			if disposition.observed_actor.definition != view.actors[opportunity.actor_id].definition \
				or disposition.observed_actor.membership != view.actors[opportunity.actor_id].membership:
				return false
		elif disposition.kind in ["COMPLETED", "CANCELLED"]:
			if typeof(disposition.action_id) != TYPE_INT or not view.authorizations.has(disposition.action_id):
				return false
			var grant: Dictionary = view.authorizations[disposition.action_id]
			if grant.phase != disposition.kind or grant.token.slot_id != opportunity.slot_id \
				or grant.disposed_revision != disposition.observed_revision + 1:
				return false
		else:
			return false
		last_revision = disposition.observed_revision
	return true


# Historical facts are validated independently of present eligibility. Only the
# Encounter can publish them, by exact transition equality against the live root.
static func valid_observation(row: Variant, actor_id: String) -> bool:
	if not PartyState.exact_fields(row, ["definition", "state", "membership"]):
		return false
	var definition = Definition.create(row.definition)
	if definition == null or definition.snapshot().actor_id != actor_id:
		return false
	if definition.snapshot().role == "ENEMY":
		if row.membership != "ENEMY" or not PartyState.exact_fields(row.state,
			["actor_id", "current_hp", "max_hp", "can_act"]) or typeof(row.state.current_hp) != TYPE_INT:
			return false
		var state = EnemyState.create(definition, row.state.current_hp)
		return state != null and state.snapshot() == row.state
	return row.membership == "PARTY" and PartyState.from_snapshot(definition, row.state) != null


static func unavailable_candidate(view: Dictionary) -> Dictionary:
	var c: Dictionary = view.duplicate(true)
	var q: Dictionary = c.queue
	var opportunity: Dictionary = q.opportunities[q.cursor]
	q.dispositions[opportunity.opportunity_id] = {"slot_id": opportunity.slot_id,
		"actor_id": opportunity.actor_id, "kind": "UNAVAILABLE", "observed_revision": view.revision,
		"issuer_id": "M403_ISOLATED_QUEUE", "observed_actor": view.actors[opportunity.actor_id].duplicate(true)}
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


static func active_party(view: Dictionary) -> int:
	var count: int = 0
	for id in view.initial_party:
		count += int(actionable(view.actors[id]))
	return count


static func active_enemies(view: Dictionary) -> int:
	var count: int = 0
	for id in view.initial_enemies:
		count += int(actionable(view.actors[id]))
	return count


static func retreat_token(view: Dictionary, request: Dictionary) -> Dictionary:
	var id: int = view.authorizations.size() + 1
	return {"version": 1, "session": view.session, "generation": view.generation,
		"round_id": view.round_id, "queue_id": view.queue.queue_id, "slot_id": request.slot_id,
		"action_id": id, "actor_id": request.actor_id, "kind": "RETREAT", "target_id": request.actor_id,
		"lock_revision": view.revision, "authorization_id": id,
		"window_id": request.slot_id + "/retreat", "request_id": request.request_id, "episode_id": ""}


# Pure full-root calculation, never a live writer. The Encounter checks authority
# and legal phase/domain before invoking this, then validates the entire result.
static func retreat_candidate(view: Dictionary, operation: String, token: Dictionary) -> Dictionary:
	var c: Dictionary = view.duplicate(true)
	var q: Dictionary = c.queue
	if operation == "LOCK":
		c.authorizations[token.action_id] = {"token": token.duplicate(true), "phase": "LOCKED",
			"impact_reason": "", "impact_revision": -1, "disposed_revision": -1}
		c.active_operation = token.action_id
		q.phase = "WAIT_ACTION"
	else:
		var grant: Dictionary = c.authorizations[token.action_id]
		if operation == "IMPACT":
			var available: bool = actionable(c.actors[token.actor_id])
			grant.phase = "APPLIED" if available else "SKIPPED"
			grant.impact_reason = "M403_RETREATED" if available else "M403_ACTOR_UNAVAILABLE"
			grant.impact_revision = view.revision + 1
			if available:
				c.actors[token.actor_id].state.participation = "RETREATED"
				c.actors[token.actor_id].state.eligible = false
		else:
			grant.phase = "COMPLETED" if operation == "COMPLETE" else "CANCELLED"
			grant.disposed_revision = view.revision + 1
			var opportunity: Dictionary = q.opportunities[q.cursor]
			q.dispositions[opportunity.opportunity_id] = {"slot_id": token.slot_id, "actor_id": token.actor_id,
				"kind": grant.phase, "observed_revision": view.revision, "issuer_id": "M403_ISOLATED_QUEUE",
				"action_id": token.action_id}
			if operation == "COMPLETE":
				c.action_receipts[token.action_id] = {"action_id": token.action_id, "authorization_id": token.authorization_id,
					"slot_id": token.slot_id, "actor_id": token.actor_id, "queue_id": token.queue_id,
					"completed_revision": view.revision + 1, "impact_reason": grant.impact_reason}
			c.active_operation = null
			q.cursor += 1
			q.phase = "DRAINED" if q.cursor == q.opportunities.size() else "READY"
	c.revision += 1
	return c
