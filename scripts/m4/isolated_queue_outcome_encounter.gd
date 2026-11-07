extends RefCounted

# Shared isolated authority root. A retains its original public API; the opt-in B
# facade exposes owned RETREAT transactions. No terminal/round/summary producer.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")
const Registry = preload("res://scripts/m4/isolated_registry.gd")
const Queue = preload("res://scripts/m4/m403_queue_adapter.gd")
const REQUEST_FIELDS = ["version", "session", "generation", "expected_revision", "queue_id"]
const RETREAT_FIELDS = REQUEST_FIELDS + ["slot_id", "request_id", "actor_id", "kind"]
const TOKEN_FIELDS = ["version", "session", "generation", "round_id", "queue_id", "slot_id", "action_id",
	"actor_id", "kind", "target_id", "lock_revision", "authorization_id", "window_id", "request_id", "episode_id"]
const TOKEN_INTS = ["version", "session", "generation", "round_id", "action_id", "lock_revision", "authorization_id"]
const ROOT_FIELDS = ["schema_version", "session", "generation", "revision", "phase", "round_id", "round_index",
	"plan", "initial_party", "initial_enemies", "actors", "queue", "active_operation", "authorizations",
	"action_receipts", "clocks", "outcome", "summary"]
var _authority: RefCounted
var _session: int = get_instance_id()
var _root: Dictionary


func _init(authority: RefCounted = null) -> void:
	_authority = authority
	_root = {"schema_version": 1, "session": _session, "generation": 0, "revision": 0,
		"phase": "UNINITIALIZED", "round_id": 0, "round_index": -1, "plan": [],
		"initial_party": [], "initial_enemies": [], "registry": Registry.new(_authority), "queue": {},
		"active_operation": null, "authorizations": {}, "action_receipts": {}, "clocks": {},
		"outcome": {}, "summary": {}}


func snapshot() -> Dictionary:
	var view: Dictionary = _root.duplicate(true)
	view.erase("registry")
	view.actors = _root.registry.snapshot()
	return view


func actor_snapshot(actor_id: Variant) -> Dictionary:
	return _root.registry.actor_snapshot(actor_id)


func eligibility_snapshot(actor_id: Variant) -> Dictionary:
	return Queue.eligibility(snapshot(), actor_id)


func queue_snapshot() -> Dictionary:
	return _root.queue.duplicate(true)


func current_opportunity() -> Dictionary:
	var q: Dictionary = _root.queue
	if q.is_empty() or q.cursor == q.opportunities.size():
		return {}
	return q.opportunities[q.cursor].duplicate(true)


func progress_diagnostic() -> Dictionary:
	var party: int = 0
	var enemies: int = 0
	for id in _root.initial_party:
		party += int(Queue.actionable(actor_snapshot(id)))
	for id in _root.initial_enemies:
		enemies += int(Queue.actionable(actor_snapshot(id)))
	return Queue.progress_diagnostic({"round_phase": _root.phase, "queue_phase": _root.queue.get("phase", "READY"),
		"pending": _root.active_operation != null, "completed_actions": _root.action_receipts.size(),
		"active_party": party, "active_enemies": enemies,
		"has_next_round": _root.round_index + 1 < _root.plan.size()})


func _reply(reason: String, status: String = "REJECTED") -> Dictionary:
	return {"status": status, "reason_code": reason}


func _protocol(request: Variant, authority: Variant, resetting: bool) -> String:
	var fields: Array = REQUEST_FIELDS + (["fixture"] if resetting else [])
	if not PartyState.exact_fields(request, fields):
		return "M403_INVALID_FIELDS"
	for field in REQUEST_FIELDS:
		if typeof(request[field]) != (TYPE_STRING if field == "queue_id" else TYPE_INT):
			return "M403_INVALID_FIELDS"
	if request.version != 1 or (resetting and typeof(request.fixture) != TYPE_DICTIONARY):
		return "M403_INVALID_FIELDS"
	if request.session != _session:
		return "M403_FOREIGN_SESSION"
	if request.generation != _root.generation:
		return "M403_STALE_GENERATION"
	if _authority == null or not authority is RefCounted or authority != _authority:
		return "M403_UNAUTHORIZED"
	if _root.phase not in (["UNINITIALIZED", "OPEN"] if resetting else ["OPEN"]):
		return "M403_INVALID_PHASE"
	if request.queue_id != _root.queue.get("queue_id", ""):
		return "M403_WRONG_QUEUE"
	if request.expected_revision != _root.revision:
		return "M403_STALE_REVISION"
	return ""


func _registry(rows: Variant):
	if typeof(rows) != TYPE_DICTIONARY:
		return null
	var registry = Registry.new(_authority)
	for id in rows:
		var row: Variant = rows[id]
		if typeof(id) != TYPE_STRING or not PartyState.exact_fields(row, ["definition", "state", "membership"]) \
			or typeof(row.membership) != TYPE_STRING:
			return null
		var definition = Definition.create(row.definition)
		if definition == null or definition.snapshot().actor_id != id:
			return null
		var d: Dictionary = definition.snapshot()
		var state: RefCounted
		if d.role == "ENEMY":
			if not PartyState.exact_fields(row.state, ["actor_id", "current_hp", "max_hp", "can_act"]) \
				or typeof(row.state.current_hp) != TYPE_INT:
				return null
			state = EnemyState.create(definition, row.state.current_hp)
			if state == null or state.snapshot() != row.state or row.membership != "ENEMY":
				return null
		else:
			state = PartyState.from_snapshot(definition, row.state)
			if row.membership != "PARTY":
				return null
		if not registry.register_actor(definition, state):
			return null
	return registry


func _valid_candidate(c: Variant) -> bool:
	if not PartyState.exact_fields(c, ROOT_FIELDS):
		return false
	for field in ["schema_version", "session", "generation", "revision", "round_id", "round_index"]:
		if typeof(c[field]) != TYPE_INT:
			return false
	if c.schema_version != 1 or c.session != _session or c.generation < 1 or c.revision < 0 \
		or typeof(c.phase) != TYPE_STRING or c.phase != "OPEN" or c.round_index != 0 \
		or typeof(c.plan) != TYPE_ARRAY or c.plan.is_empty() \
		or typeof(c.initial_party) != TYPE_ARRAY or typeof(c.initial_enemies) != TYPE_ARRAY \
		or c.initial_party.is_empty() or c.initial_enemies.is_empty() or _registry(c.actors) == null:
		return false
	var seen: Dictionary = {}
	for id in c.initial_party + c.initial_enemies:
		if typeof(id) != TYPE_STRING or seen.has(id) or not c.actors.has(id):
			return false
		seen[id] = true
		var role: String = c.actors[id].definition.role
		if role != ("PLAYER" if id == c.initial_party[0] else ("NPC" if id in c.initial_party else "ENEMY")):
			return false
	if seen.size() != c.actors.size():
		return false
	var previous: int = 0
	for round_row in c.plan:
		if not PartyState.exact_fields(round_row, ["round_id", "actor_order"]) \
			or typeof(round_row.round_id) != TYPE_INT or round_row.round_id <= 0 \
			or (previous != 0 and (previous == 9223372036854775807 or round_row.round_id != previous + 1)) \
			or typeof(round_row.actor_order) != TYPE_ARRAY \
			or round_row.actor_order != c.initial_party + c.initial_enemies:
			return false
		previous = round_row.round_id
	if c.round_id != c.plan[0].round_id:
		return false
	for field in ["clocks", "outcome", "summary"]:
		if typeof(c[field]) != TYPE_DICTIONARY or not c[field].is_empty():
			return false
	return _valid_actions(c) and Queue.valid_queue(c)


# Internal publication gate; never an arbitrary receipt/root import API.
# Validate the entire transition as well as the candidate's own invariants.
func _publish(candidate: Variant, expected_revision: int, resetting: bool = false,
	operation: String = "UNAVAILABLE", token: Dictionary = {}) -> String:
	if _root.revision != expected_revision:
		return "M403_STALE_REVISION"
	if not _valid_candidate(candidate):
		return "M403_INVALID_CANDIDATE"
	if resetting:
		if candidate.generation != _root.generation + 1 or candidate.revision != 0:
			return "M403_INVALID_CANDIDATE"
	else:
		var before: Dictionary = snapshot()
		if operation == "UNAVAILABLE":
			if before.queue.is_empty() or before.queue.cursor == before.queue.opportunities.size() \
				or before.active_operation != null or Queue.actionable(before.actors[current_opportunity().actor_id]) \
				or candidate != Queue.unavailable_candidate(before):
				return "M403_INVALID_CANDIDATE"
		else:
			var reason: String = _retreat_transition_reason(before, operation, token)
			if not reason.is_empty():
				return reason
			if candidate != Queue.retreat_candidate(before, operation, token):
				return "M403_INVALID_CANDIDATE"
	var owned: Dictionary = candidate.duplicate(true)
	var registry = _registry(owned.actors)
	owned.erase("actors")
	owned.registry = registry
	# No await, signal, virtual writer or callback between validation and root swap.
	_root = owned
	return ""


func restart(request: Variant, authority: Variant) -> Dictionary:
	var reason: String = _protocol(request, authority, true)
	if not reason.is_empty():
		return _reply(reason)
	var fixture: Dictionary = request.fixture
	if not PartyState.exact_fields(fixture, ["actors", "round_plan"]) \
		or typeof(fixture.actors) != TYPE_ARRAY or typeof(fixture.round_plan) != TYPE_ARRAY \
		or _root.generation == 9223372036854775807:
		return _reply("M403_INVALID_RESTART")
	var c: Dictionary = snapshot()
	c.actors = {}
	var player: Array = []
	var npcs: Array = []
	var enemies: Array = []
	for entry in fixture.actors:
		if not PartyState.exact_fields(entry, ["definition", "state"]):
			return _reply("M403_INVALID_RESTART")
		var definition = Definition.create(entry.definition)
		if definition == null:
			return _reply("M403_INVALID_RESTART")
		var d: Dictionary = definition.snapshot()
		if c.actors.has(d.actor_id):
			return _reply("M403_INVALID_RESTART")
		var state: RefCounted
		if d.role == "ENEMY":
			if not PartyState.exact_fields(entry.state, ["current_hp"]) or typeof(entry.state.current_hp) != TYPE_INT:
				return _reply("M403_INVALID_RESTART")
			state = EnemyState.create(definition, entry.state.current_hp)
			enemies.append(d.actor_id)
		else:
			state = PartyState.create(definition, entry.state)
			if d.role == "PLAYER":
				player.append(d.actor_id)
			else:
				npcs.append(d.actor_id)
		if state == null:
			return _reply("M403_INVALID_RESTART")
		c.actors[d.actor_id] = {"definition": d, "state": state.snapshot(),
			"membership": "ENEMY" if d.role == "ENEMY" else "PARTY"}
	if player.size() != 1 or enemies.is_empty():
		return _reply("M403_INVALID_RESTART")
	c.initial_party = player + npcs
	c.initial_enemies = enemies
	c.generation += 1
	c.revision = 0
	c.phase = "OPEN"
	c.round_index = 0
	c.plan = fixture.round_plan.duplicate(true)
	if c.plan.is_empty() or typeof(c.plan[0]) != TYPE_DICTIONARY \
		or typeof(c.plan[0].get("round_id")) != TYPE_INT:
		return _reply("M403_INVALID_RESTART")
	c.round_id = c.plan[0].round_id
	c.active_operation = null
	c.authorizations = {}
	c.action_receipts = {}
	c.queue = Queue.build(_session, c.generation, c.round_id, c.initial_party + c.initial_enemies)
	if not _valid_candidate(c):
		return _reply("M403_INVALID_RESTART")
	reason = _publish(c, _root.revision, true)
	return _reply(reason) if not reason.is_empty() else _reply("M403_RESTARTED", "APPLIED")


func advance(request: Variant, authority: Variant) -> Dictionary:
	var reason: String = _protocol(request, authority, false)
	if not reason.is_empty():
		return _reply(reason)
	if _root.active_operation != null:
		return _reply("M403_ACTION_IN_PROGRESS")
	var opportunity: Dictionary = current_opportunity()
	if opportunity.is_empty():
		# No seal/open-next-round in A. Draining is never natural ROUND_CLOSED.
		return _reply("M403_BOUNDARY_DEPENDENCY")
	if Queue.actionable(actor_snapshot(opportunity.actor_id)):
		return {"status": "READY", "reason_code": "M403_SLOT_READY", "opportunity": opportunity}
	var c: Dictionary = Queue.unavailable_candidate(snapshot())
	reason = _publish(c, _root.revision)
	return _reply(reason) if not reason.is_empty() else {"status": "APPLIED", "reason_code": "M403_SLOT_UNAVAILABLE",
		"disposition": c.queue.dispositions[opportunity.opportunity_id].duplicate(true)}


static func _typed_token(token: Variant) -> bool:
	if not PartyState.exact_fields(token, TOKEN_FIELDS):
		return false
	for field in TOKEN_FIELDS:
		if typeof(token[field]) != (TYPE_INT if field in TOKEN_INTS else TYPE_STRING):
			return false
	return token.version == 1


static func _reserved(id: String) -> bool:
	# Reserve complete issuer namespaces, including FUTURE slots/rounds.
	return id.begins_with("slot_") or id.begins_with("m403/")


func _valid_actions(c: Dictionary) -> bool:
	if typeof(c.authorizations) != TYPE_DICTIONARY or typeof(c.action_receipts) != TYPE_DICTIONARY \
		or (c.active_operation != null and typeof(c.active_operation) != TYPE_INT) \
		or typeof(c.queue) != TYPE_DICTIONARY or typeof(c.queue.get("opportunities")) != TYPE_ARRAY \
		or typeof(c.queue.get("cursor")) != TYPE_INT or typeof(c.queue.get("dispositions")) != TYPE_DICTIONARY:
		return false
	for opportunity in c.queue.opportunities:
		if not PartyState.exact_fields(opportunity, ["opportunity_id", "slot_id", "actor_id"]):
			return false
		for field in ["opportunity_id", "slot_id", "actor_id"]:
			if typeof(opportunity[field]) != TYPE_STRING:
				return false
	var events: Dictionary = {}
	var requests: Dictionary = {}
	var slots: Dictionary = {}
	var receipts: Dictionary = {}
	var active: Variant = null
	for id in c.authorizations:
		if typeof(id) != TYPE_INT or id < 1 or id > c.authorizations.size():
			return false
		var g: Variant = c.authorizations[id]
		if not PartyState.exact_fields(g, ["token", "phase", "impact_reason", "impact_revision", "disposed_revision"]) \
			or not _typed_token(g.token) or typeof(g.phase) != TYPE_STRING or typeof(g.impact_reason) != TYPE_STRING \
			or typeof(g.impact_revision) != TYPE_INT or typeof(g.disposed_revision) != TYPE_INT:
			return false
		var t: Dictionary = g.token
		if t.session != c.session or t.generation != c.generation or t.round_id != c.round_id \
			or t.queue_id != c.queue.get("queue_id") or t.action_id != id or t.authorization_id != id \
			or t.kind != "RETREAT" or t.target_id != t.actor_id or t.episode_id != "" \
			or t.window_id != t.slot_id + "/retreat" or t.lock_revision < 0 \
			or t.request_id.is_empty() or _reserved(t.request_id) or requests.has(t.request_id) \
			or slots.has(t.slot_id) or not c.initial_party.has(t.actor_id):
			return false
		requests[t.request_id] = true
		slots[t.slot_id] = true
		var index: int = -1
		for i in range(c.queue.opportunities.size()):
			var op: Variant = c.queue.opportunities[i]
			if typeof(op) != TYPE_DICTIONARY:
				return false
			if op.get("slot_id") == t.slot_id and op.get("actor_id") == t.actor_id:
				index = i
		if index == -1 or not _event(events, t.lock_revision + 1, c.revision):
			return false
		if g.phase not in ["LOCKED", "APPLIED", "SKIPPED", "COMPLETED", "CANCELLED"]:
			return false
		if g.phase in ["LOCKED", "CANCELLED"]:
			if g.impact_revision != -1 or g.impact_reason != "":
				return false
		else:
			if g.impact_revision != t.lock_revision + 2 or not _event(events, g.impact_revision, c.revision) \
				or g.impact_reason not in ["M403_RETREATED", "M403_ACTOR_UNAVAILABLE"]:
				return false
			if g.phase == "APPLIED" and g.impact_reason != "M403_RETREATED" \
				or g.phase == "SKIPPED" and g.impact_reason != "M403_ACTOR_UNAVAILABLE":
				return false
			if g.impact_reason == "M403_RETREATED" and c.actors[t.actor_id].state.participation != "RETREATED":
				return false
		if g.phase in ["COMPLETED", "CANCELLED"]:
			if g.disposed_revision != t.lock_revision + (3 if g.phase == "COMPLETED" else 2) \
				or not _event(events, g.disposed_revision, c.revision) or index >= c.queue.cursor:
				return false
			var op: Dictionary = c.queue.opportunities[index]
			var d: Variant = c.queue.dispositions.get(op.opportunity_id)
			if typeof(d) != TYPE_DICTIONARY or d.get("action_id") != id or d.get("kind") != g.phase:
				return false
			if g.phase == "COMPLETED":
				receipts[id] = {"action_id": id, "authorization_id": id, "slot_id": t.slot_id,
					"actor_id": t.actor_id, "queue_id": t.queue_id, "completed_revision": g.disposed_revision,
					"impact_reason": g.impact_reason}
		else:
			if active != null or index != c.queue.cursor or g.disposed_revision != -1:
				return false
			active = id
	for d in c.queue.dispositions.values():
		if typeof(d) != TYPE_DICTIONARY:
			return false
		if d.get("kind") == "UNAVAILABLE":
			if typeof(d.get("observed_revision")) != TYPE_INT or not _event(events, d.observed_revision + 1, c.revision):
				return false
	return active == c.active_operation and receipts == c.action_receipts and events.size() == c.revision


static func _event(events: Dictionary, revision: int, current_revision: int) -> bool:
	if revision < 1 or revision > current_revision or events.has(revision):
		return false
	events[revision] = true
	return true


func _lock_retreat(request: Variant, authority: Variant) -> Dictionary:
	if not PartyState.exact_fields(request, RETREAT_FIELDS):
		return _reply("M403_INVALID_FIELDS")
	for field in RETREAT_FIELDS:
		if typeof(request[field]) != (TYPE_INT if field in ["version", "session", "generation", "expected_revision"] else TYPE_STRING):
			return _reply("M403_INVALID_FIELDS")
	if request.version != 1 or request.kind != "RETREAT" or request.request_id.is_empty():
		return _reply("M403_INVALID_FIELDS")
	if request.session != _session:
		return _reply("M403_FOREIGN_SESSION")
	if request.generation != _root.generation:
		return _reply("M403_STALE_GENERATION")
	if _authority == null or not authority is RefCounted or authority != _authority:
		return _reply("M403_UNAUTHORIZED")
	for g in _root.authorizations.values():
		if g.token.request_id == request.request_id:
			return _reply("M403_DUPLICATE_OPERATION")
	if _root.phase != "OPEN":
		return _reply("M403_INVALID_PHASE")
	if _root.active_operation != null:
		return _reply("M403_ACTION_IN_PROGRESS")
	if request.queue_id != _root.queue.get("queue_id", ""):
		return _reply("M403_WRONG_QUEUE")
	var op: Dictionary = current_opportunity()
	if op.is_empty() or request.slot_id != op.slot_id or request.actor_id != op.actor_id:
		return _reply("M403_WRONG_SLOT")
	if request.expected_revision != _root.revision:
		return _reply("M403_STALE_REVISION")
	if _reserved(request.request_id):
		return _reply("M403_RESERVED_OPERATION_ID")
	var row: Dictionary = actor_snapshot(request.actor_id)
	if row.membership != "PARTY":
		return _reply("M403_PARTY_ONLY")
	if not Queue.actionable(row):
		return _reply("M403_ACTOR_UNAVAILABLE")
	var before: Dictionary = snapshot()
	if Queue.active_party(before) <= 1:
		return _reply("M403_BOUNDARY_DEPENDENCY")
	var token: Dictionary = Queue.retreat_token(before, request)
	var reason: String = _publish_retreat("LOCK", token, before.revision)
	return _reply(reason) if not reason.is_empty() else {"status": "AUTHORIZED", "reason_code": "M403_RETREAT_LOCKED", "token": token.duplicate(true)}


func _token_reason(token: Variant, operation: String) -> String:
	if not _typed_token(token):
		return "M403_INVALID_FIELDS"
	if token.session != _session:
		return "M403_FOREIGN_SESSION"
	if token.generation != _root.generation:
		return "M403_STALE_GENERATION"
	var g: Variant = _root.authorizations.get(token.action_id)
	if typeof(g) != TYPE_DICTIONARY or g.token != token:
		return "M403_UNAUTHORIZED"
	if g.phase == "CANCELLED":
		return "M403_DUPLICATE_OPERATION" if operation == "CANCEL" else "M403_ACTION_CANCELLED"
	if g.phase == "COMPLETED" or (operation == "IMPACT" and g.phase in ["APPLIED", "SKIPPED"]):
		return "M403_DUPLICATE_OPERATION"
	if _root.phase != "OPEN":
		return "M403_INVALID_PHASE"
	var op: Dictionary = current_opportunity()
	if op.is_empty() or token.queue_id != _root.queue.queue_id or token.round_id != _root.round_id \
		or token.slot_id != op.slot_id or token.actor_id != op.actor_id or _root.active_operation != token.action_id \
		or _root.queue.phase != "WAIT_ACTION":
		return "M403_WRONG_SLOT"
	if (operation in ["IMPACT", "CANCEL"] and g.phase != "LOCKED") \
		or (operation == "COMPLETE" and g.phase not in ["APPLIED", "SKIPPED"]):
		return "M403_INVALID_PHASE"
	return ""


func _settle_retreat(token: Variant, operation: String) -> Dictionary:
	var reason: String = _token_reason(token, operation)
	if not reason.is_empty():
		return _reply(reason)
	var before: Dictionary = snapshot()
	if operation == "IMPACT" and Queue.actionable(before.actors[token.actor_id]) and Queue.active_party(before) <= 1:
		return _reply("M403_BOUNDARY_DEPENDENCY")
	reason = _publish_retreat(operation, token, before.revision)
	if not reason.is_empty():
		return _reply(reason)
	if operation == "IMPACT":
		var g: Dictionary = _root.authorizations[token.action_id]
		return _reply(g.impact_reason, g.phase)
	return _reply("M403_ACTION_COMPLETED" if operation == "COMPLETE" else "M403_ACTION_CANCELLED", "APPLIED")


# One publication gate for A and B; this helper never swaps a root.
func _publish_retreat(operation: String, token: Dictionary, expected_revision: int) -> String:
	if _root.revision != expected_revision:
		return "M403_STALE_REVISION"
	var before: Dictionary = snapshot()
	var reason: String = _retreat_transition_reason(before, operation, token)
	if not reason.is_empty():
		return reason
	return _publish(Queue.retreat_candidate(before, operation, token), expected_revision, false, operation, token)


func _retreat_transition_reason(before: Dictionary, operation: String, token: Dictionary) -> String:
	if not _typed_token(token):
		return "M403_INVALID_CANDIDATE"
	if operation == "LOCK":
		var op: Dictionary = current_opportunity()
		if before.phase != "OPEN" or before.active_operation != null or op.is_empty() \
			or token != Queue.retreat_token(before, {"slot_id": op.slot_id, "actor_id": op.actor_id,
				"request_id": token.request_id}) \
			or token.request_id.is_empty() or _reserved(token.request_id) \
			or before.actors[op.actor_id].membership != "PARTY" or not Queue.actionable(before.actors[op.actor_id]) \
			or Queue.active_party(before) <= 1:
			return "M403_INVALID_CANDIDATE"
		for grant in before.authorizations.values():
			if grant.token.request_id == token.request_id:
				return "M403_INVALID_CANDIDATE"
	else:
		if operation not in ["IMPACT", "COMPLETE", "CANCEL"] or not _token_reason(token, operation).is_empty():
			return "M403_INVALID_CANDIDATE"
		if operation == "IMPACT" and Queue.actionable(before.actors[token.actor_id]) and Queue.active_party(before) <= 1:
			return "M403_BOUNDARY_DEPENDENCY"
	return ""
