extends RefCounted

# M4-03A only. The filename reserves B/C's aggregate location, not their APIs.
# No effect, completion, seal, close, abort, retreat, classifier or summary writer.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")
const Registry = preload("res://scripts/m4/isolated_registry.gd")
const Queue = preload("res://scripts/m4/m403_queue_adapter.gd")
const REQUEST_FIELDS = ["version", "session", "generation", "expected_revision", "queue_id"]
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
	if c.round_id != c.plan[0].round_id or c.active_operation != null:
		return false
	for field in ["authorizations", "action_receipts", "clocks", "outcome", "summary"]:
		if typeof(c[field]) != TYPE_DICTIONARY or not c[field].is_empty():
			return false
	return Queue.valid_queue(c)


# Internal publication gate; never an arbitrary receipt/root import API.
# Validate the entire transition as well as the candidate's own invariants.
func _publish(candidate: Variant, expected_revision: int, resetting: bool = false) -> String:
	if _root.revision != expected_revision:
		return "M403_STALE_REVISION"
	if not _valid_candidate(candidate):
		return "M403_INVALID_CANDIDATE"
	if resetting:
		if candidate.generation != _root.generation + 1 or candidate.revision != 0:
			return "M403_INVALID_CANDIDATE"
	else:
		var before: Dictionary = snapshot()
		if before.queue.is_empty() or before.queue.cursor == before.queue.opportunities.size() \
			or Queue.actionable(before.actors[current_opportunity().actor_id]) \
			or candidate != Queue.unavailable_candidate(before):
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
	c.queue = Queue.build(_session, c.generation, c.round_id, c.initial_party + c.initial_enemies)
	if not _valid_candidate(c):
		return _reply("M403_INVALID_RESTART")
	reason = _publish(c, _root.revision, true)
	return _reply(reason) if not reason.is_empty() else _reply("M403_RESTARTED", "APPLIED")


func advance(request: Variant, authority: Variant) -> Dictionary:
	var reason: String = _protocol(request, authority, false)
	if not reason.is_empty():
		return _reply(reason)
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
