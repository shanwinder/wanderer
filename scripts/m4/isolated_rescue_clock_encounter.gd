extends RefCounted

# Opt-in finite fixture aggregate. No production queue, policy, UI or callbacks.
# Only _publish swaps authority. Candidate actors are detached scratch snapshots;
# the published registry is the sole HP/LifeState/Participation owner.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")
const Registry = preload("res://scripts/m4/isolated_registry.gd")
const REQUEST_FIELDS = ["version", "session", "generation", "operation_id", "kind", "helper_id", "target_id", "window_id"]
const ACTION_FIELDS = ["version", "session", "generation", "operation_id", "kind", "helper_id", "target_id", "window_id", "episode_id", "lock_revision", "authorization_id", "slot_id", "amount"]
const EVENT_FIELDS = ["version", "kind", "issuer_id", "session", "generation", "round_id", "event_id", "witness_id", "sealed_revision", "authorization_id"]
var _authority: RefCounted
var _session: int = get_instance_id()
var _root: Dictionary = {}


func _init(fixture_authority: RefCounted = null) -> void:
	_authority = fixture_authority


func snapshot() -> Dictionary:
	if _root.is_empty():
		return {}
	var view: Dictionary = _root.duplicate(true)
	view.erase("registry")
	view.actors = _root.registry.snapshot()
	return view


func actor_snapshot(id: Variant) -> Dictionary:
	return {} if _root.is_empty() else _root.registry.actor_snapshot(id)


func _authorized(authority: Variant) -> bool:
	return _authority != null and authority == _authority


func _reply(reason: String, status: String = "REJECTED") -> Dictionary:
	return {"status": status, "reason_code": reason, "hp_delta": 0}


func _identity(value: Dictionary) -> String:
	if value.session != _session:
		return "M4_FOREIGN_SESSION"
	if _root.is_empty() or value.generation != _root.generation:
		return "M4_STALE_GENERATION"
	return ""


func _typed(value: Variant, fields: Array, integers: Array) -> bool:
	if not PartyState.exact_fields(value, fields):
		return false
	for field in fields:
		if typeof(value[field]) != (TYPE_INT if field in integers else TYPE_STRING):
			return false
	return value.version == 1


func _registry(rows: Dictionary):
	var registry = Registry.new(_authority)
	for id in rows:
		var row: Variant = rows[id]
		if not PartyState.exact_fields(row, ["definition", "state", "membership"]):
			return null
		var definition = Definition.create(row.definition)
		if definition == null or id != row.definition.actor_id:
			return null
		var state: RefCounted
		if row.definition.role == "ENEMY":
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


func _valid_candidate(c: Dictionary) -> bool:
	if c.phase not in ["OPEN", "SEALED", "CLOSED", "ABORTED"] or c.actors.is_empty() \
		or c.session != _session or c.generation < 1 or c.round_id != c.plan[c.round_index].round_id:
		return false
	var party_ids: Array = []
	for id in c.actors:
		var row: Dictionary = c.actors[id]
		if row.membership != "PARTY":
			continue
		party_ids.append(id)
		if not c.rescue_uses.has(id) or typeof(c.rescue_uses[id]) != TYPE_INT or c.rescue_uses[id] not in [0, 1]:
			return false
		if not c.help_reference.has(id) or typeof(c.help_reference[id]) != TYPE_INT or c.help_reference[id] not in [0, 1]:
			return false
		var e: Dictionary = c.episodes.get(id, {})
		if not e.is_empty() and (not PartyState.exact_fields(e, ["episode_id", "entry_round", "budget", "active"]) \
			or typeof(e.episode_id) != TYPE_STRING or e.episode_id.is_empty() \
			or typeof(e.entry_round) != TYPE_INT or e.entry_round < 1 or e.entry_round > c.round_id \
			or typeof(e.budget) != TYPE_INT or e.budget < 0 or e.budget > 2 or typeof(e.active) != TYPE_BOOL):
			return false
		if row.state.life_state == "DOWN":
			if e.is_empty() or not e.active or e.budget not in [1, 2] \
				or (e.entry_round == c.round_id and e.budget != 2):
				return false
		elif row.state.life_state == "DEAD":
			if e.is_empty() or e.active or e.budget != 0:
				return false
		elif not e.is_empty() and (e.active or e.budget == 0):
			return false
	if c.rescue_uses.size() != party_ids.size() or c.help_reference.size() != party_ids.size():
		return false
	var episode_ids: Dictionary = {}
	for id in c.episodes:
		if id not in party_ids or episode_ids.has(c.episodes[id].episode_id):
			return false
		episode_ids[c.episodes[id].episode_id] = true
	var w: Dictionary = c.witness
	if not PartyState.exact_fields(w, ["session", "generation", "round_id", "witness_id", "expected_slots", "receipts", "outstanding", "aborted", "phase", "revision"]) \
		or w.session != c.session or w.generation != c.generation or w.round_id != c.round_id \
		or w.witness_id != c.window_id or w.phase != c.phase or w.aborted != (c.phase == "ABORTED"):
		return false
	var expected: Array = []
	for slot in c.plan[c.round_index].slots:
		expected.append(slot.slot_id)
	if w.expected_slots != expected:
		return false
	for id in c.actions:
		var a: Dictionary = c.actions[id]
		if not PartyState.exact_fields(a, ["token", "phase", "result"]) \
			or not _typed(a.token, ACTION_FIELDS, ["version", "session", "generation", "lock_revision", "authorization_id", "amount"]) \
			or a.token.session != c.session or a.token.generation != c.generation or a.token.operation_id != id \
			or a.token.authorization_id < 1 or a.token.authorization_id > c.authorization_serial \
			or a.phase not in ["LOCKED", "APPLIED", "SKIPPED", "COMPLETED", "CANCELLED"] \
			or c.action_consumed.has(id) != (a.phase != "LOCKED"):
			return false
		var pending: bool = a.token.window_id == c.window_id and a.phase in ["LOCKED", "APPLIED", "SKIPPED"]
		if w.outstanding.has(id) != pending:
			return false
	for id in c.action_consumed:
		if not c.actions.has(id):
			return false
	for id in w.outstanding:
		if not c.actions.has(id):
			return false
	for slot in w.receipts:
		var operation: String = w.receipts[slot]
		if slot not in expected or not c.actions.has(operation) or c.actions[operation].phase != "COMPLETED" \
			or c.actions[operation].token.slot_id != slot or c.actions[operation].token.window_id != c.window_id:
			return false
	for key in c.events:
		var event: Dictionary = c.events[key]
		if not _typed(event, EVENT_FIELDS, ["version", "session", "generation", "round_id", "sealed_revision", "authorization_id"]) \
			or key != _event_key(event) or event.session != c.session or event.generation != c.generation \
			or event.issuer_id != "M402_FINITE_FIXTURE" or event.kind != "ROUND_CLOSED" \
			or event.authorization_id < 1 or event.authorization_id > c.authorization_serial:
			return false
	for key in c.event_consumed:
		if not c.events.has(key) or not c.semantic_closed.has(_close_key(c.events[key])):
			return false
	for key in c.semantic_closed:
		var found: bool = false
		for event_key in c.event_consumed:
			found = found or _close_key(c.events[event_key]) == key
		if not found:
			return false
	for id in c.abort_grants:
		var token: Dictionary = c.abort_grants[id]
		if not _typed(token, ["version", "session", "generation", "operation_id", "kind", "round_id", "authorization_id"],
			["version", "session", "generation", "round_id", "authorization_id"]) \
			or token.session != c.session or token.generation != c.generation or token.kind != "ABORT" \
			or token.operation_id != id or token.authorization_id < 1 or token.authorization_id > c.authorization_serial:
			return false
	for id in c.abort_consumed:
		if not c.abort_grants.has(id):
			return false
	if c.abort_count != c.abort_consumed.size():
		return false
	if c.phase in ["SEALED", "CLOSED"] and (expected.is_empty() or w.receipts.size() != expected.size() or not w.outstanding.is_empty()):
		return false
	return true


# Virtual diagnostics are inert here; only the test harness overrides them.
func _publication_fault(_candidate: Dictionary) -> String:
	return ""


func _sealed_revision_matches(revision: int) -> bool:
	return revision == _root.revision


func _publish(candidate: Dictionary, expected_revision: int, resetting: bool = false) -> String:
	if not _root.is_empty() and _root.revision != expected_revision:
		return "M4_STALE_REVISION"
	var registry = _registry(candidate.actors)
	if registry == null or not _valid_candidate(candidate):
		return "M4_INVALID_CANDIDATE"
	var fault: String = _publication_fault(candidate)
	if not fault.is_empty():
		return fault
	candidate.erase("actors")
	candidate.registry = registry
	# No signal, await, virtual method or caller callback after validation.
	candidate.revision = 0 if resetting else expected_revision + 1
	_root = candidate
	return ""


func _new_episode(c: Dictionary, id: String, entry: int, budget: int) -> void:
	c.episode_serial += 1
	c.episodes[id] = {"episode_id": "%s/%s/%s" % [_session, c.generation, c.episode_serial],
		"entry_round": entry, "budget": budget, "active": budget > 0}


func restart(fixture: Variant, authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if not PartyState.exact_fields(fixture, ["actors", "round_plan", "clocks", "help_reference"]) \
		or typeof(fixture.actors) != TYPE_ARRAY or fixture.actors.is_empty() \
		or typeof(fixture.round_plan) != TYPE_ARRAY or fixture.round_plan.is_empty() \
		or typeof(fixture.clocks) != TYPE_DICTIONARY or typeof(fixture.help_reference) != TYPE_DICTIONARY:
		return _reply("M4_INVALID_RESTART")
	var c: Dictionary = {"schema_version": 2, "session": _session,
		"generation": _root.get("generation", 0) + 1, "revision": 0, "phase": "OPEN",
		"round_id": 0, "round_index": 0, "window_id": "", "actors": {}, "plan": fixture.round_plan.duplicate(true),
		"episodes": {}, "episode_serial": 0, "rescue_uses": {}, "help_reference": {},
		"actions": {}, "action_consumed": {}, "events": {}, "event_consumed": {}, "semantic_closed": {},
		"authorization_serial": _root.get("authorization_serial", 0), "abort_grants": {}, "abort_consumed": {},
		"abort_count": 0, "witness": {}}
	var players: int = 0
	for entry in fixture.actors:
		if not PartyState.exact_fields(entry, ["definition", "state"]):
			return _reply("M4_INVALID_RESTART")
		var definition = Definition.create(entry.definition)
		if definition == null:
			return _reply("M4_INVALID_RESTART")
		var d: Dictionary = definition.snapshot()
		if c.actors.has(d.actor_id):
			return _reply("M4_INVALID_RESTART")
		var state: RefCounted
		if d.role == "ENEMY":
			if not PartyState.exact_fields(entry.state, ["current_hp"]) or typeof(entry.state.current_hp) != TYPE_INT:
				return _reply("M4_INVALID_RESTART")
			state = EnemyState.create(definition, entry.state.current_hp)
		else:
			state = PartyState.create(definition, entry.state)
			c.rescue_uses[d.actor_id] = 1
			c.help_reference[d.actor_id] = fixture.help_reference.get(d.actor_id, 1)
			players += int(d.role == "PLAYER")
		if state == null:
			return _reply("M4_INVALID_RESTART")
		c.actors[d.actor_id] = {"definition": d, "state": state.snapshot(), "membership": "ENEMY" if d.role == "ENEMY" else "PARTY"}
	if players != 1:
		return _reply("M4_INVALID_RESTART")
	var previous: int = 0
	for plan in c.plan:
		if not PartyState.exact_fields(plan, ["round_id", "slots", "event_ids"]) or typeof(plan.round_id) != TYPE_INT \
			or plan.round_id <= previous or (previous > 0 and plan.round_id != previous + 1) \
			or typeof(plan.slots) != TYPE_ARRAY or typeof(plan.event_ids) != TYPE_ARRAY or plan.event_ids.is_empty():
			return _reply("M4_INVALID_RESTART")
		previous = plan.round_id
		var ids: Dictionary = {}
		for slot in plan.slots:
			if not PartyState.exact_fields(slot, ["slot_id", "helper_id", "target_id", "amount"]) \
				or typeof(slot.slot_id) != TYPE_STRING or not Definition.valid_actor_id(slot.slot_id) or ids.has(slot.slot_id) \
				or typeof(slot.helper_id) != TYPE_STRING or typeof(slot.target_id) != TYPE_STRING \
				or not c.rescue_uses.has(slot.helper_id) or not c.rescue_uses.has(slot.target_id) \
				or typeof(slot.amount) != TYPE_INT or slot.amount < 0:
				return _reply("M4_INVALID_RESTART")
			ids[slot.slot_id] = true
		ids = {}
		for event_id in plan.event_ids:
			if typeof(event_id) != TYPE_STRING or not Definition.valid_actor_id(event_id) or ids.has(event_id):
				return _reply("M4_INVALID_RESTART")
			ids[event_id] = true
	c.round_id = c.plan[0].round_id
	for id in fixture.help_reference:
		if not c.help_reference.has(id):
			return _reply("M4_INVALID_RESTART")
	for id in fixture.clocks:
		if not c.actors.has(id) or c.actors[id].membership != "PARTY" or c.actors[id].state.life_state != "DOWN":
			return _reply("M4_INVALID_RESTART")
	for id in c.rescue_uses:
		var life: String = c.actors[id].state.life_state
		if life == "DOWN":
			var seed: Variant = fixture.clocks.get(id, {"entry_round": c.round_id, "budget": 2})
			if not PartyState.exact_fields(seed, ["entry_round", "budget"]) or typeof(seed.entry_round) != TYPE_INT \
				or seed.entry_round < 1 or seed.entry_round > c.round_id or typeof(seed.budget) != TYPE_INT \
				or seed.budget not in [1, 2] or (seed.entry_round == c.round_id and seed.budget != 2):
				return _reply("M4_INVALID_RESTART")
			_new_episode(c, id, seed.entry_round, seed.budget)
		elif life == "DEAD":
			_new_episode(c, id, c.round_id, 0)
	_new_witness(c)
	c.witness.revision = 0
	if _registry(c.actors) == null or not _valid_candidate(c):
		return _reply("M4_INVALID_RESTART")
	if _root.get("phase", "") == "SEALED":
		return _reply("M4_INVALID_PHASE")
	var reason: String = _publish(c, _root.get("revision", 0), true)
	return _reply(reason) if not reason.is_empty() else _reply("M4_RESTARTED", "APPLIED")


func _new_witness(c: Dictionary) -> void:
	c.window_id = "%s/%s/%s" % [_session, c.generation, c.round_id]
	var expected: Array = []
	for slot in c.plan[c.round_index].slots:
		expected.append(slot.slot_id)
	c.witness = {"session": _session, "generation": c.generation, "round_id": c.round_id,
		"witness_id": c.window_id, "expected_slots": expected, "receipts": {}, "outstanding": {},
		"aborted": false, "phase": "OPEN", "revision": c.revision + 1}


func _commit(c: Dictionary) -> String:
	c.witness.phase = c.phase
	c.witness.revision = _root.revision + 1
	return _publish(c, _root.revision)


func _boundary(c: Dictionary) -> String:
	if c.witness.expected_slots.is_empty():
		return "M4_ROUND_NOT_CLOSABLE"
	var party: bool = false
	var player: bool = false
	var enemy: bool = false
	for row in c.actors.values():
		if row.membership == "ENEMY":
			enemy = enemy or row.state.can_act
		else:
			party = party or row.state.eligible
			player = player or (row.definition.role == "PLAYER" and row.state.eligible)
	return "" if player and party and enemy else "M4_BOUNDARY_DEPENDENCY"


static func rescue_eligibility(view: Dictionary, helper: String, target: String, episode: String = "") -> String:
	var h: Dictionary = view.actors.get(helper, {})
	var t: Dictionary = view.actors.get(target, {})
	if h.is_empty() or h.membership != "PARTY" or not h.state.eligible:
		return "M4_ACTOR_UNAVAILABLE"
	if target == helper or t.is_empty() or t.membership != "PARTY":
		return "M4_INVALID_TARGET"
	if t.state.participation != "PRESENT":
		return "M4_TARGET_NOT_PRESENT"
	if t.state.life_state == "DEAD":
		return "M4_DEAD_NOT_RESCUABLE"
	if t.state.life_state != "DOWN":
		return "M4_TARGET_NOT_DOWN"
	if not view.episodes.has(target) or not view.episodes[target].active \
		or (not episode.is_empty() and view.episodes[target].episode_id != episode):
		return "M4_DOWN_EPISODE_CHANGED"
	if view.rescue_uses[helper] == 0:
		return "M4_RESCUE_EXHAUSTED"
	return ""


func lock_rescue(request: Variant, authority: Variant) -> Dictionary:
	if not _typed(request, REQUEST_FIELDS, ["version", "session", "generation"]):
		return _reply("M4_INVALID_FIELDS")
	var reason: String = _identity(request)
	if not reason.is_empty():
		return _reply(reason)
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.phase != "OPEN" or request.window_id != _root.window_id:
		return _reply("M4_INVALID_PHASE")
	if request.kind != "RESCUE" or not Definition.valid_actor_id(request.operation_id):
		return _reply("M4_INVALID_FIELDS")
	if _root.actions.has(request.operation_id):
		return _reply("M4_DUPLICATE_OPERATION")
	reason = rescue_eligibility(snapshot(), request.helper_id, request.target_id)
	if not reason.is_empty():
		return _reply(reason)
	return _issue_action(request, "", 0)


func _issue_action(request: Dictionary, slot_id: String, amount: int) -> Dictionary:
	var c: Dictionary = snapshot()
	c.authorization_serial += 1
	var token: Dictionary = request.duplicate(true)
	token.merge({"episode_id": c.episodes[request.target_id].episode_id if request.kind == "RESCUE" else "",
		"lock_revision": _root.revision, "authorization_id": c.authorization_serial,
		"slot_id": slot_id, "amount": amount})
	c.actions[token.operation_id] = {"token": token.duplicate(true), "phase": "LOCKED", "result": {}}
	c.witness.outstanding[token.operation_id] = true
	var reason: String = _commit(c)
	if not reason.is_empty():
		return _reply(reason)
	return {"status": "AUTHORIZED", "reason_code": "M4_FIXTURE_AUTHORIZED", "token": token.duplicate(true)}


func lock_fixture_slot(slot_id: Variant, authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.is_empty() or _root.phase != "OPEN":
		return _reply("M4_INVALID_PHASE")
	if typeof(slot_id) != TYPE_STRING:
		return _reply("M4_INVALID_FIELDS")
	for slot in _root.plan[_root.round_index].slots:
		if slot.slot_id == slot_id:
			var operation: String = "slot_%s_%s" % [_root.round_id, slot_id]
			if _root.actions.has(operation):
				return _reply("M4_DUPLICATE_OPERATION")
			if not actor_snapshot(slot.helper_id).state.eligible or not actor_snapshot(slot.target_id).state.eligible:
				return _reply("M4_ACTOR_UNAVAILABLE")
			return _issue_action({"version": 1, "session": _session, "generation": _root.generation,
				"operation_id": operation, "kind": "FIXTURE_DAMAGE", "helper_id": slot.helper_id,
				"target_id": slot.target_id, "window_id": _root.window_id}, slot_id, slot.amount)
	return _reply("M4_UNAUTHORIZED")


func _action_reason(token: Variant) -> String:
	if not _typed(token, ACTION_FIELDS, ["version", "session", "generation", "lock_revision", "authorization_id", "amount"]):
		return "M4_INVALID_FIELDS"
	var reason: String = _identity(token)
	if not reason.is_empty():
		return reason
	if not _root.actions.has(token.operation_id) or _root.actions[token.operation_id].token != token:
		return "M4_UNAUTHORIZED"
	if _root.phase != "OPEN" or token.window_id != _root.window_id:
		return "M4_INVALID_PHASE"
	return ""


func impact(token: Variant) -> Dictionary:
	var reason: String = _action_reason(token)
	if not reason.is_empty():
		return _reply(reason)
	var action: Dictionary = _root.actions[token.operation_id]
	if action.phase == "CANCELLED":
		return _reply("M4_INVALID_PHASE")
	if _root.action_consumed.has(token.operation_id):
		return _reply("M4_DUPLICATE_OPERATION")
	var c: Dictionary = snapshot()
	var before: Dictionary = c.actors[token.target_id].state.duplicate(true)
	var old_clock: Dictionary = c.episodes.get(token.target_id, {}).duplicate(true)
	var old_use: int = c.rescue_uses[token.helper_id]
	if token.kind == "RESCUE":
		reason = rescue_eligibility(c, token.helper_id, token.target_id, token.episode_id)
		if reason.is_empty():
			_set_party(c, token.target_id, 1, "ALIVE")
			c.episodes[token.target_id].active = false
			c.rescue_uses[token.helper_id] -= 1
	else:
		if not c.actors[token.helper_id].state.eligible or not before.eligible:
			reason = "M4_ACTOR_UNAVAILABLE"
		else:
			_damage(c, token.target_id, token.amount)
	var result: Dictionary = {"status": "APPLIED" if reason.is_empty() else "SKIP",
		"reason_code": ("M4_RESCUED" if token.kind == "RESCUE" else "M4_FIXTURE_DAMAGE") if reason.is_empty() else reason,
		"operation_id": token.operation_id, "helper_id": token.helper_id, "target_id": token.target_id,
		"episode_id": token.episode_id, "hp_delta": c.actors[token.target_id].state.current_hp - before.current_hp,
		"life_before": before.life_state, "life_after": c.actors[token.target_id].state.life_state,
		"clock_before": old_clock, "clock_after": c.episodes.get(token.target_id, {}).duplicate(true),
		"rescue_use_delta": c.rescue_uses[token.helper_id] - old_use, "revision": _root.revision + 1}
	c.actions[token.operation_id].phase = "APPLIED" if reason.is_empty() else "SKIPPED"
	c.actions[token.operation_id].result = result.duplicate(true)
	c.action_consumed[token.operation_id] = true
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else result


func _set_party(c: Dictionary, id: String, hp: int, life: String) -> void:
	var definition = Definition.create(c.actors[id].definition)
	c.actors[id].state = PartyState.create(definition, {"current_hp": hp, "life_state": life, "participation": "PRESENT"}).snapshot()


func _damage(c: Dictionary, id: String, amount: int) -> void:
	var hp: int = c.actors[id].state.current_hp - mini(amount, c.actors[id].state.current_hp)
	_set_party(c, id, hp, "DOWN" if hp == 0 else "ALIVE")
	if hp == 0:
		_new_episode(c, id, c.round_id, 2)


func fixture_damage(id: Variant, amount: Variant, authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.is_empty() or _root.phase != "OPEN":
		return _reply("M4_INVALID_PHASE")
	if typeof(id) != TYPE_STRING or typeof(amount) != TYPE_INT or amount < 0:
		return _reply("M4_INVALID_FIELDS")
	var row: Dictionary = actor_snapshot(id)
	if row.is_empty() or row.membership != "PARTY" or not row.state.eligible:
		return _reply("M4_ACTOR_UNAVAILABLE")
	var c: Dictionary = snapshot()
	_damage(c, id, amount)
	var delta: int = c.actors[id].state.current_hp - row.state.current_hp
	var reason: String = _commit(c)
	if not reason.is_empty():
		return _reply(reason)
	return {"status": "APPLIED", "reason_code": "M4_FIXTURE_DAMAGE", "hp_delta": delta}


func complete(token: Variant) -> Dictionary:
	var reason: String = _action_reason(token)
	if not reason.is_empty():
		return _reply(reason)
	if _root.actions[token.operation_id].phase not in ["APPLIED", "SKIPPED"]:
		return _reply("M4_INVALID_PHASE")
	var c: Dictionary = snapshot()
	c.actions[token.operation_id].phase = "COMPLETED"
	c.witness.outstanding.erase(token.operation_id)
	if not token.slot_id.is_empty():
		c.witness.receipts[token.slot_id] = token.operation_id
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else _reply("M4_ACTION_COMPLETED", "APPLIED")


func cancel(token: Variant) -> Dictionary:
	var reason: String = _action_reason(token)
	if not reason.is_empty():
		return _reply(reason)
	if _root.actions[token.operation_id].phase != "LOCKED":
		return _reply("M4_INVALID_PHASE")
	var c: Dictionary = snapshot()
	c.actions[token.operation_id].phase = "CANCELLED"
	c.action_consumed[token.operation_id] = true
	c.witness.outstanding.erase(token.operation_id)
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else _reply("M4_ACTION_CANCELLED", "APPLIED")


func seal(authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.is_empty() or _root.phase != "OPEN":
		return _reply("M4_INVALID_PHASE")
	var c: Dictionary = snapshot()
	var reason: String = _boundary(c)
	if not reason.is_empty():
		return _reply(reason)
	if c.witness.aborted or not c.witness.outstanding.is_empty() \
		or c.witness.receipts.size() != c.witness.expected_slots.size():
		return _reply("M4_ROUND_NOT_CLOSABLE")
	for slot in c.witness.expected_slots:
		if not c.witness.receipts.has(slot):
			return _reply("M4_ROUND_NOT_CLOSABLE")
		var operation: String = c.witness.receipts[slot]
		if not c.actions.has(operation) or c.actions[operation].phase != "COMPLETED" \
			or c.actions[operation].token.slot_id != slot or c.actions[operation].token.window_id != c.window_id:
			return _reply("M4_ROUND_NOT_CLOSABLE")
	c.phase = "SEALED"
	var tokens: Array = []
	for event_id in c.plan[c.round_index].event_ids:
		c.authorization_serial += 1
		var event: Dictionary = {"version": 1, "kind": "ROUND_CLOSED", "issuer_id": "M402_FINITE_FIXTURE",
			"session": _session, "generation": c.generation, "round_id": c.round_id,
			"event_id": event_id, "witness_id": c.witness.witness_id,
			"sealed_revision": _root.revision + 1, "authorization_id": c.authorization_serial}
		c.events[_event_key(event)] = event.duplicate(true)
		tokens.append(event.duplicate(true))
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else {"status": "AUTHORIZED", "reason_code": "M4_ROUND_SEALED", "tokens": tokens}


func _event_key(event: Dictionary) -> String:
	return "%s/%s/%s/%s" % [event.session, event.generation, event.issuer_id, event.event_id]


func _close_key(event: Dictionary) -> String:
	return "%s/%s/%s" % [event.session, event.generation, event.round_id]


func apply_round_closed(event: Variant) -> Dictionary:
	if not _typed(event, EVENT_FIELDS, ["version", "session", "generation", "round_id", "sealed_revision", "authorization_id"]) \
		or event.kind != "ROUND_CLOSED" or event.issuer_id != "M402_FINITE_FIXTURE":
		return _reply("M4_INVALID_EVENT")
	var reason: String = _identity(event)
	if not reason.is_empty():
		return _reply(reason)
	var key: String = _event_key(event)
	if not _root.events.has(key) or _root.events[key] != event:
		return _reply("M4_INVALID_EVENT")
	if _root.event_consumed.has(key) or _root.semantic_closed.has(_close_key(event)):
		return _reply("M4_DUPLICATE_ROUND_CLOSED")
	if event.round_id != _root.round_id:
		return _reply("M4_INVALID_ROUND")
	if _root.phase != "SEALED":
		return _reply("M4_INVALID_PHASE")
	if event.witness_id != _root.witness.witness_id or _root.witness.phase != "SEALED" \
		or _root.witness.revision != event.sealed_revision \
		or not _root.witness.outstanding.is_empty() or _root.witness.aborted:
		return _reply("M4_INVALID_EVENT")
	if not _sealed_revision_matches(event.sealed_revision):
		return _reply("M4_STALE_REVISION")
	var c: Dictionary = snapshot()
	var results: Array = []
	# Read every eligible episode from the same immutable pre-tick root.
	for id in _root.episodes:
		var old: Dictionary = _root.episodes[id]
		if not old.active:
			continue
		var budget: int = old.budget if old.entry_round == c.round_id else maxi(0, old.budget - 1)
		c.episodes[id].budget = budget
		if budget == 0:
			_set_party(c, id, 0, "DEAD")
			c.episodes[id].active = false
		results.append({"actor_id": id, "episode_id": old.episode_id, "budget_before": old.budget,
			"budget_after": budget, "reason_code": "M4_BLED_OUT" if budget == 0 else ("M4_BLEED_GRACE" if old.entry_round == c.round_id else "M4_BLEED_TICK")})
	c.event_consumed[key] = true
	c.semantic_closed[_close_key(event)] = true
	c.phase = "CLOSED"
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else {"status": "APPLIED", "reason_code": "M4_ROUND_CLOSED", "episodes": results, "hp_delta": 0}


func next_round(round_id: Variant, authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.is_empty() or _root.phase != "CLOSED":
		return _reply("M4_INVALID_PHASE")
	if typeof(round_id) != TYPE_INT or _root.round_index + 1 >= _root.plan.size() \
		or _root.plan[_root.round_index + 1].round_id != round_id:
		return _reply("M4_INVALID_ROUND")
	var c: Dictionary = snapshot()
	c.round_index += 1
	c.round_id = round_id
	c.phase = "OPEN"
	_new_witness(c)
	var reason: String = _boundary(c)
	if not reason.is_empty():
		return _reply(reason)
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else _reply("M4_NEXT_ROUND", "APPLIED")


func authorize_abort(operation_id: Variant, authority: Variant) -> Dictionary:
	if not _authorized(authority):
		return _reply("M4_UNAUTHORIZED")
	if _root.is_empty() or _root.phase != "OPEN":
		return _reply("M4_INVALID_PHASE")
	if typeof(operation_id) != TYPE_STRING or not Definition.valid_actor_id(operation_id):
		return _reply("M4_INVALID_FIELDS")
	if _root.abort_grants.has(operation_id):
		return _reply("M4_DUPLICATE_OPERATION")
	var c: Dictionary = snapshot()
	c.authorization_serial += 1
	var token: Dictionary = {"version": 1, "session": _session, "generation": c.generation,
		"operation_id": operation_id, "kind": "ABORT", "round_id": c.round_id, "authorization_id": c.authorization_serial}
	c.abort_grants[operation_id] = token.duplicate(true)
	var reason: String = _commit(c)
	return _reply(reason) if not reason.is_empty() else {"status": "AUTHORIZED", "reason_code": "M4_FIXTURE_AUTHORIZED", "token": token}


func abort_round(token: Variant) -> Dictionary:
	if not _typed(token, ["version", "session", "generation", "operation_id", "kind", "round_id", "authorization_id"],
		["version", "session", "generation", "round_id", "authorization_id"]) or token.kind != "ABORT":
		return _reply("M4_INVALID_FIELDS")
	var reason: String = _identity(token)
	if not reason.is_empty():
		return _reply(reason)
	if not _root.abort_grants.has(token.operation_id) or _root.abort_grants[token.operation_id] != token:
		return _reply("M4_UNAUTHORIZED")
	if _root.abort_consumed.has(token.operation_id):
		return _reply("M4_DUPLICATE_OPERATION")
	if _root.phase not in ["OPEN", "SEALED"] or token.round_id != _root.round_id:
		return _reply("M4_INVALID_PHASE")
	var c: Dictionary = snapshot()
	c.phase = "ABORTED"
	c.witness.aborted = true
	c.abort_consumed[token.operation_id] = true
	c.abort_count += 1
	reason = _commit(c)
	return _reply(reason) if not reason.is_empty() else _reply("M4_ROUND_ABORTED", "APPLIED")


func unsupported_transition(kind: Variant) -> Dictionary:
	if _root.is_empty() or _root.phase != "OPEN":
		return _reply("M4_INVALID_PHASE")
	if typeof(kind) != TYPE_STRING:
		return _reply("M4_INVALID_FIELDS")
	return _reply("M4_EVACUATION_UNSUPPORTED" if kind == "DOWN_TO_RETREATED" else "M4_TRANSITION_UNSUPPORTED")
