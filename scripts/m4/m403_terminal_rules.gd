extends RefCounted

# Pure finite transition/replay model. Only the C Encounter swaps the live root.
# Seed + journal are immutable historical provenance, never live Registry objects.
const State = preload("res://scripts/m4/isolated_actor_state.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const Enemy = preload("res://scripts/actors/actor_runtime_state.gd")
const Queue = preload("res://scripts/m4/m403_queue_adapter.gd")
const Classifier = preload("res://scripts/m4/m403_outcome_classifier.gd")
const Summary = preload("res://scripts/m4/m403_summary.gd")
const BASE = ["version", "session", "generation", "expected_revision", "queue_id"]
const ROUND = BASE + ["round_id"]
const LOCK = BASE + ["slot_id", "request_id", "actor_id", "kind"]
const TOKEN = ["version", "session", "generation", "round_id", "queue_id", "slot_id", "action_id",
	"actor_id", "kind", "target_id", "lock_revision", "authorization_id", "window_id", "request_id", "episode_id"]
const EVENT = ["version", "kind", "issuer_id", "session", "generation", "round_id", "event_id", "witness_id",
	"sealed_revision", "authorization_id", "queue_id"]
const ABORT = ["version", "kind", "issuer_id", "session", "generation", "round_id", "queue_id",
	"authorization_id", "request_id", "issued_revision"]
const INTS = ["version", "session", "generation", "expected_revision", "round_id", "action_id",
	"lock_revision", "authorization_id", "sealed_revision", "issued_revision", "amount"]
const REQUEST_OPS = ["OPEN", "ADVANCE", "RETREAT", "ATTACK", "RESCUE", "SEAL", "AUTHORIZE_ABORT"]
const TOKEN_OPS = ["IMPACT", "COMPLETE", "CANCEL"]


static func reply(reason: String, status: String = "REJECTED") -> Dictionary:
	return {"status": status, "reason_code": reason}


static func typed(v: Variant, fields: Array) -> bool:
	if not State.exact_fields(v, fields): return false
	for f in fields:
		if typeof(v[f]) != (TYPE_INT if f in INTS else TYPE_STRING): return false
	return v.version == 1


static func reserved(id: String) -> bool:
	return id.begins_with("m403/") or id.begins_with("slot_")


static func protocol(v: Dictionary, op: String, p: Variant) -> String:
	var fields: Array
	if op == "OPEN": fields = ROUND
	elif op in ["ADVANCE", "SEAL"]: fields = BASE
	elif op in ["RETREAT", "ATTACK", "RESCUE"]:
		fields = LOCK + (["target_id", "amount"] if op == "ATTACK" else (["target_id"] if op == "RESCUE" else []))
	elif op in TOKEN_OPS:
		if typeof(p) != TYPE_DICTIONARY: return "M403_INVALID_FIELDS"
		fields = TOKEN + (["amount"] if p.get("kind") == "ATTACK" else [])
	elif op == "CLOSE": fields = EVENT
	elif op == "AUTHORIZE_ABORT": fields = BASE + ["request_id"]
	elif op == "ABORT": fields = ABORT
	else: return "M403_INVALID_FIELDS"
	if not typed(p, fields): return "M403_INVALID_EVENT" if op == "CLOSE" else "M403_INVALID_FIELDS"
	if op in ["RETREAT", "ATTACK", "RESCUE"] and (p.kind != op or p.request_id.is_empty()):
		return "M403_INVALID_FIELDS"
	if op == "AUTHORIZE_ABORT" and p.request_id.is_empty(): return "M403_INVALID_FIELDS"
	if op == "CLOSE" and (p.kind != "ROUND_CLOSED" or p.issuer_id != "M403_ISOLATED_QUEUE"): return "M403_INVALID_EVENT"
	if op == "ABORT" and (p.kind != "ABORT" or p.issuer_id != "M403_ISOLATED_ABORT"): return "M403_INVALID_FIELDS"
	if p.session != v.session: return "M403_FOREIGN_SESSION"
	if p.generation != v.generation: return "M403_STALE_GENERATION"
	return ""


static func new_episode(c: Dictionary, id: String, entry: int, budget: int) -> void:
	c.episode_serial += 1
	c.clocks[id] = {"episode_id": "m403/episode/%s/%s/%s" % [c.session, c.generation, c.episode_serial],
		"entry_round": entry, "budget": budget, "active": budget > 0}


static func prepare(session: int, generation: int, fixture: Variant) -> Dictionary:
	if generation < 1 or not State.exact_fields(fixture, ["actors", "round_plan", "clocks"]) \
		or typeof(fixture.actors) != TYPE_ARRAY or typeof(fixture.round_plan) != TYPE_ARRAY \
		or fixture.round_plan.is_empty() or typeof(fixture.clocks) != TYPE_DICTIONARY: return {}
	var c: Dictionary = {"schema_version": 3, "session": session, "generation": generation, "revision": 0,
		"phase": "OPEN", "round_id": 0, "round_index": 0, "admitted": false,
		"plan": fixture.round_plan.duplicate(true), "initial_party": [], "initial_enemies": [], "actors": {},
		"queue": {}, "active_operation": null, "authorizations": {}, "action_receipts": {},
		"clocks": {}, "episode_serial": 0, "rescue_uses": {}, "outcome": {}, "summary": {},
		"declarations": {}, "witness": {}, "events": {}, "event_consumed": {}, "semantic_closed": {},
		"abort_grants": {}, "abort_consumed": {}, "terminal_stops": {}, "round_history": [],
		"seed": fixture.duplicate(true), "journal": []}
	var players: Array = []
	var npcs: Array = []
	for row in fixture.actors:
		if not State.exact_fields(row, ["definition", "state"]): return {}
		var d = Definition.create(row.definition)
		if d == null: return {}
		var def: Dictionary = d.snapshot()
		var id: String = def.actor_id
		if c.actors.has(id): return {}
		var state: RefCounted
		if def.role == "ENEMY":
			if not State.exact_fields(row.state, ["current_hp"]) or typeof(row.state.current_hp) != TYPE_INT: return {}
			state = Enemy.create(d, row.state.current_hp)
			c.initial_enemies.append(id)
		else:
			state = State.create(d, row.state)
			if def.role == "PLAYER": players.append(id)
			else: npcs.append(id)
			c.rescue_uses[id] = 1
		if state == null: return {}
		c.actors[id] = {"definition": def, "state": state.snapshot(), "membership": "ENEMY" if def.role == "ENEMY" else "PARTY"}
	if players.size() != 1 or c.initial_enemies.is_empty(): return {}
	c.initial_party = players + npcs
	var previous: int = 0
	for row in c.plan:
		if not State.exact_fields(row, ["round_id", "actor_order"]) or typeof(row.round_id) != TYPE_INT \
			or row.round_id < 1 or (previous > 0 and (previous == 9223372036854775807 or row.round_id != previous + 1)) \
			or typeof(row.actor_order) != TYPE_ARRAY or row.actor_order != c.initial_party + c.initial_enemies: return {}
		previous = row.round_id
	c.round_id = c.plan[0].round_id
	for id in fixture.clocks:
		if id not in c.initial_party or c.actors[id].state.life_state != "DOWN": return {}
	for id in c.initial_party:
		var life: String = c.actors[id].state.life_state
		if life == "DOWN":
			var seed: Variant = fixture.clocks.get(id, {"entry_round": c.round_id, "budget": 2})
			if not State.exact_fields(seed, ["entry_round", "budget"]) or typeof(seed.entry_round) != TYPE_INT \
				or typeof(seed.budget) != TYPE_INT or seed.entry_round < 1 or seed.entry_round > c.round_id \
				or seed.budget not in [1, 2] or (seed.entry_round == c.round_id and seed.budget != 2): return {}
			new_episode(c, id, seed.entry_round, seed.budget)
		elif life == "DEAD": new_episode(c, id, c.round_id, 0)
	c.queue = Queue.build(session, generation, c.round_id, c.initial_party + c.initial_enemies)
	return c


# Reconstruct every domain from actual authenticated operations, independently of
# action-only L+2/L+3 assumptions. No caller root/summary/receipt is a replay input.
static func valid(c: Variant) -> bool:
	if typeof(c) != TYPE_DICTIONARY or typeof(c.get("session")) != TYPE_INT \
		or typeof(c.get("generation")) != TYPE_INT or typeof(c.get("journal")) != TYPE_ARRAY: return false
	var replay: Dictionary = prepare(c.session, c.generation, c.get("seed"))
	if replay.is_empty(): return false
	for event in c.journal:
		if not State.exact_fields(event, ["operation", "payload", "revision"]) \
			or typeof(event.operation) != TYPE_STRING or typeof(event.revision) != TYPE_INT \
			or event.revision != replay.revision + 1: return false
		var result: Dictionary = apply(replay, event.operation, event.payload)
		if not result.has("candidate"): return false
		replay = result.candidate
	return replay == c


static func opportunity(v: Dictionary) -> Dictionary:
	return {} if v.queue.cursor >= v.queue.opportunities.size() else v.queue.opportunities[v.queue.cursor]


static func phase_reason(v: Dictionary, p: Dictionary, require_admitted: bool = true) -> String:
	if not v.outcome.is_empty(): return "M403_OUTCOME_FROZEN"
	if v.phase != "OPEN" or (require_admitted and not v.admitted): return "M403_INVALID_PHASE"
	if p.queue_id != v.queue.queue_id: return "M403_WRONG_QUEUE"
	return ""


static func request_reason(v: Dictionary, p: Dictionary, op: String) -> String:
	var reason: String = phase_reason(v, p)
	if not reason.is_empty(): return reason
	if op in ["RETREAT", "ATTACK", "RESCUE", "ADVANCE"] and v.active_operation != null:
		return "M403_ACTION_IN_PROGRESS"
	if op in ["RETREAT", "ATTACK", "RESCUE"]:
		var slot: Dictionary = opportunity(v)
		if slot.is_empty() or slot.slot_id != p.slot_id or slot.actor_id != p.actor_id: return "M403_WRONG_SLOT"
	if p.has("round_id") and p.round_id != v.round_id: return "M403_INVALID_ROUND"
	if p.expected_revision != v.revision: return "M403_STALE_REVISION"
	return ""


static func freeze(c: Dictionary, classification: Dictionary, cause: String, causal: Variant = null) -> void:
	if classification.encounter_outcome == "ACTIVE": return
	c.outcome = {"outcome_id": "m403/outcome/%s/%s" % [c.session, c.generation], "session": c.session,
		"generation": c.generation, "round_id": c.round_id, "freeze_revision": c.revision,
		"encounter_outcome": classification.encounter_outcome, "reason_code": classification.reason_code,
		"cause": cause, "causal_action": causal}
	if c.phase == "OPEN": c.phase = "ABORTED"
	c.queue.phase = "TERMINAL_SETTLING" if causal != null else "STOPPED"
	for i in range(c.queue.cursor, c.queue.opportunities.size()):
		if causal != null and i == c.queue.cursor: continue
		var slot: Dictionary = c.queue.opportunities[i]
		c.terminal_stops[slot.opportunity_id] = {"slot_id": slot.slot_id, "actor_id": slot.actor_id,
			"kind": "TERMINAL_STOP", "revision": c.revision}
	c.summary = Summary.build(c)


static func rescue_reason(v: Dictionary, actor: String, target: String, episode: String = "") -> String:
	if not Queue.actionable(v.actors[actor]): return "M403_ACTOR_UNAVAILABLE"
	if actor not in v.initial_party or target not in v.initial_party or target == actor: return "M403_INVALID_TARGET"
	var s: Dictionary = v.actors[target].state
	if s.participation != "PRESENT": return "M403_TARGET_NOT_PRESENT"
	if s.life_state == "DEAD": return "M403_DEAD_NOT_RESCUABLE"
	if s.life_state != "DOWN": return "M403_TARGET_NOT_DOWN"
	if not v.clocks.has(target) or not v.clocks[target].active \
		or (not episode.is_empty() and v.clocks[target].episode_id != episode): return "M403_DOWN_EPISODE_CHANGED"
	if v.rescue_uses[actor] == 0: return "M403_RESCUE_EXHAUSTED"
	return ""


static func token_reason(v: Dictionary, op: String, t: Dictionary) -> String:
	var g: Variant = v.authorizations.get(t.action_id)
	if typeof(g) != TYPE_DICTIONARY or g.token != t: return "M403_UNAUTHORIZED"
	if g.phase == "CANCELLED": return "M403_DUPLICATE_OPERATION" if op == "CANCEL" else "M403_ACTION_CANCELLED"
	if g.phase == "COMPLETED" or (op == "IMPACT" and g.phase in ["APPLIED", "SKIPPED"]): return "M403_DUPLICATE_OPERATION"
	if not v.outcome.is_empty():
		if op != "COMPLETE" or v.outcome.causal_action != t.action_id \
			or g.phase not in ["APPLIED", "SKIPPED"] or v.queue.phase != "TERMINAL_SETTLING": return "M403_OUTCOME_FROZEN"
	elif v.phase != "OPEN" or not v.admitted: return "M403_INVALID_PHASE"
	var slot: Dictionary = opportunity(v)
	if slot.is_empty() or t.queue_id != v.queue.queue_id or t.round_id != v.round_id \
		or t.slot_id != slot.slot_id or t.actor_id != slot.actor_id or v.active_operation != t.action_id: return "M403_WRONG_SLOT"
	if (op in ["IMPACT", "CANCEL"] and g.phase != "LOCKED") \
		or (op == "COMPLETE" and g.phase not in ["APPLIED", "SKIPPED"]): return "M403_INVALID_PHASE"
	return ""


static func receipt_set(v: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in v.action_receipts:
		if v.action_receipts[id].queue_id == v.queue.queue_id: result[id] = v.action_receipts[id].duplicate(true)
	return result


static func apply(v: Dictionary, op: String, p: Variant) -> Dictionary:
	var reason: String = protocol(v, op, p)
	if not reason.is_empty(): return reply(reason)
	# Owned equality/duplicate gates precede phase and revision.
	if op in TOKEN_OPS:
		reason = token_reason(v, op, p)
	elif op in ["RETREAT", "ATTACK", "RESCUE"]:
		for grant in v.authorizations.values():
			if grant.token.request_id == p.request_id: return reply("M403_DUPLICATE_OPERATION")
	elif op == "AUTHORIZE_ABORT" and v.abort_grants.has(p.request_id): return reply("M403_DUPLICATE_OPERATION")
	elif op == "CLOSE":
		if v.events.get(p.event_id) != p: return reply("M403_INVALID_EVENT")
		if v.event_consumed.has(p.event_id) or v.semantic_closed.has(p.queue_id): return reply("M403_DUPLICATE_ROUND_CLOSED")
		if v.phase != "SEALED": return reply("M403_INVALID_PHASE")
		if p.round_id != v.round_id or p.queue_id != v.queue.queue_id: return reply("M403_INVALID_ROUND")
		if p.sealed_revision != v.revision or v.witness.revision != p.sealed_revision: return reply("M403_STALE_REVISION")
		if p.witness_id != v.witness.witness_id or not v.witness.outstanding.is_empty(): return reply("M403_INVALID_EVENT")
	elif op == "ABORT":
		if v.abort_grants.get(p.request_id) != p: return reply("M403_UNAUTHORIZED")
		if v.abort_consumed.has(p.request_id): return reply("M403_DUPLICATE_OPERATION")
		if not v.outcome.is_empty(): return reply("M403_OUTCOME_FROZEN")
		if v.phase not in ["OPEN", "SEALED"]: return reply("M403_INVALID_PHASE")
		if p.round_id != v.round_id or p.queue_id != v.queue.queue_id: return reply("M403_INVALID_ROUND")
	elif op == "OPEN":
		if not v.outcome.is_empty(): return reply("M403_OUTCOME_FROZEN")
		if not ((v.phase == "OPEN" and not v.admitted) or v.phase == "CLOSED"): return reply("M403_INVALID_PHASE")
		if p.queue_id != v.queue.queue_id: return reply("M403_WRONG_QUEUE")
		if p.expected_revision != v.revision: return reply("M403_STALE_REVISION")
		var next: int = v.round_index + int(v.admitted)
		if next >= v.plan.size(): return reply("M403_PLAN_EXHAUSTED")
		if p.round_id != v.plan[next].round_id: return reply("M403_INVALID_ROUND")
	if not reason.is_empty(): return reply(reason)
	if op in REQUEST_OPS and op != "OPEN":
		reason = request_reason(v, p, op)
		if not reason.is_empty(): return reply(reason)
	if v.revision == 9223372036854775807: return reply("M403_INVALID_CANDIDATE")
	var c: Dictionary = v.duplicate(true)
	c.revision += 1
	var result: Dictionary
	match op:
		"OPEN": result = open_candidate(v, c)
		"ADVANCE":
			var slot: Dictionary = opportunity(v)
			if slot.is_empty(): return reply("M403_ROUND_NOT_CLOSABLE")
			if Queue.actionable(v.actors[slot.actor_id]):
				return {"status": "READY", "reason_code": "M403_SLOT_READY", "opportunity": slot.duplicate(true)}
			c.queue.dispositions[slot.opportunity_id] = {"slot_id": slot.slot_id, "actor_id": slot.actor_id,
				"kind": "UNAVAILABLE", "observed_revision": v.revision, "issuer_id": "M403_ISOLATED_QUEUE",
				"observed_actor": v.actors[slot.actor_id].duplicate(true)}
			c.queue.cursor += 1
			c.queue.phase = "DRAINED" if c.queue.cursor == c.queue.opportunities.size() else "READY"
			result = reply("M403_SLOT_UNAVAILABLE", "APPLIED")
		"RETREAT", "ATTACK", "RESCUE": result = lock_candidate(v, c, op, p)
		"IMPACT", "COMPLETE", "CANCEL": result = action_candidate(v, c, op, p)
		"SEAL": result = seal_candidate(v, c)
		"CLOSE": result = close_candidate(v, c, p)
		"AUTHORIZE_ABORT":
			if v.active_operation != null: return reply("M403_ACTION_IN_PROGRESS")
			if reserved(p.request_id): return reply("M403_RESERVED_OPERATION_ID")
			var grant: Dictionary = {"version": 1, "kind": "ABORT", "issuer_id": "M403_ISOLATED_ABORT",
				"session": v.session, "generation": v.generation, "round_id": v.round_id, "queue_id": v.queue.queue_id,
				"authorization_id": v.abort_grants.size() + 1, "request_id": p.request_id, "issued_revision": c.revision}
			c.abort_grants[p.request_id] = grant
			result = reply("M403_ABORT_AUTHORIZED", "AUTHORIZED")
			result.token = grant.duplicate(true)
		"ABORT":
			c.abort_consumed[p.request_id] = c.revision
			c.phase = "ABORTED"
			c.active_operation = null
			freeze(c, {"encounter_outcome": "ABORTED", "reason_code": "M403_ABORTED"}, "ABORT")
			result = reply("M403_ABORTED", "APPLIED")
		_: return reply("M403_INVALID_FIELDS")
	if result.status == "REJECTED": return result
	c.journal.append({"operation": op, "payload": p.duplicate(true), "revision": c.revision})
	result.candidate = c
	return result


static func open_candidate(v: Dictionary, c: Dictionary) -> Dictionary:
	if v.admitted:
		c.round_history.append({"round_id": v.round_id, "queue": v.queue.duplicate(true),
			"witness": v.witness.duplicate(true), "declarations": v.declarations.duplicate(true)})
		c.round_index += 1
		c.round_id = c.plan[c.round_index].round_id
		c.queue = Queue.build(c.session, c.generation, c.round_id, c.initial_party + c.initial_enemies)
	c.phase = "OPEN"
	c.admitted = true
	c.witness = {}
	c.declarations = {}
	var declared: String = ""
	for id in c.initial_party:
		if Queue.actionable(c.actors[id]):
			declared = id
			break
	for id in c.initial_enemies:
		if Queue.actionable(c.actors[id]): c.declarations[id] = declared
	freeze(c, Classifier.classify(c), "ADMISSION")
	return reply("M403_ROUND_OPENED" if c.outcome.is_empty() else "M403_OUTCOME_FROZEN", "APPLIED")


static func lock_candidate(v: Dictionary, c: Dictionary, kind: String, p: Dictionary) -> Dictionary:
	if reserved(p.request_id): return reply("M403_RESERVED_OPERATION_ID")
	var row: Dictionary = v.actors[p.actor_id]
	if kind in ["RETREAT", "RESCUE"] and row.membership != "PARTY": return reply("M403_PARTY_ONLY")
	if not Queue.actionable(row): return reply("M403_ACTOR_UNAVAILABLE")
	# C can replace B's last-Party dependency only with complete atomic freeze.
	if Classifier.classify(v).encounter_outcome != "ACTIVE": return reply("M403_BOUNDARY_DEPENDENCY")
	var target: String = p.actor_id if kind == "RETREAT" else p.target_id
	if kind == "ATTACK":
		if not v.actors.has(target) or v.actors[target].membership == row.membership: return reply("M403_INVALID_TARGET")
		if p.amount < 1 or p.amount > v.actors[target].state.max_hp: return reply("M403_INVALID_AMOUNT")
		if row.membership == "ENEMY":
			if v.declarations.get(p.actor_id) != target: return reply("M403_INVALID_TARGET")
		elif not Queue.actionable(v.actors[target]): return reply("M403_TARGET_UNAVAILABLE")
	elif kind == "RESCUE":
		var reason: String = rescue_reason(v, p.actor_id, target)
		if not reason.is_empty(): return reply(reason)
	var id: int = v.authorizations.size() + 1
	var token: Dictionary = {"version": 1, "session": v.session, "generation": v.generation,
		"round_id": v.round_id, "queue_id": v.queue.queue_id, "slot_id": p.slot_id, "action_id": id,
		"actor_id": p.actor_id, "kind": kind, "target_id": target, "lock_revision": v.revision,
		"authorization_id": id, "window_id": p.slot_id + "/" + kind.to_lower(), "request_id": p.request_id,
		"episode_id": v.clocks[target].episode_id if kind == "RESCUE" else ""}
	if kind == "ATTACK": token.amount = p.amount
	c.authorizations[id] = {"token": token.duplicate(true), "phase": "LOCKED", "impact_reason": "",
		"impact_revision": -1, "disposed_revision": -1}
	c.active_operation = id
	c.queue.phase = "WAIT_ACTION"
	var result: Dictionary = reply("M403_RETREAT_LOCKED" if kind == "RETREAT" else "M403_ACTION_LOCKED", "AUTHORIZED")
	result.token = token
	return result


static func set_party(c: Dictionary, id: String, hp: int, life: String, participation: String = "PRESENT") -> void:
	c.actors[id].state = State.create(Definition.create(c.actors[id].definition),
		{"current_hp": hp, "life_state": life, "participation": participation}).snapshot()


static func action_candidate(v: Dictionary, c: Dictionary, op: String, t: Dictionary) -> Dictionary:
	var g: Dictionary = c.authorizations[t.action_id]
	if op == "IMPACT":
		var reason: String = ""
		if not Queue.actionable(v.actors[t.actor_id]): reason = "M403_ACTOR_UNAVAILABLE"
		elif t.kind == "RESCUE": reason = rescue_reason(v, t.actor_id, t.target_id, t.episode_id)
		elif t.kind == "ATTACK" and not Queue.actionable(v.actors[t.target_id]): reason = "M403_TARGET_UNAVAILABLE"
		if reason.is_empty():
			match t.kind:
				"RETREAT":
					set_party(c, t.actor_id, c.actors[t.actor_id].state.current_hp, "ALIVE", "RETREATED")
					reason = "M403_RETREATED"
				"RESCUE":
					set_party(c, t.target_id, 1, "ALIVE")
					c.clocks[t.target_id].active = false
					c.rescue_uses[t.actor_id] -= 1
					reason = "M403_RESCUED"
				"ATTACK":
					var hp: int = v.actors[t.target_id].state.current_hp - mini(t.amount, v.actors[t.target_id].state.current_hp)
					if t.target_id in c.initial_enemies:
						c.actors[t.target_id].state = Enemy.create(Definition.create(c.actors[t.target_id].definition), hp).snapshot()
					else:
						set_party(c, t.target_id, hp, "DOWN" if hp == 0 else "ALIVE")
						if hp == 0: new_episode(c, t.target_id, c.round_id, 2)
					reason = "M403_DOWN_ENTERED" if hp == 0 and t.target_id in c.initial_party else "M403_FIXTURE_DAMAGE"
			g.phase = "APPLIED"
		else: g.phase = "SKIPPED"
		g.impact_reason = reason
		g.impact_revision = c.revision
		freeze(c, Classifier.classify(c), "IMPACT", t.action_id)
		return reply(reason, g.phase)
	g.phase = "COMPLETED" if op == "COMPLETE" else "CANCELLED"
	g.disposed_revision = c.revision
	var slot: Dictionary = opportunity(v)
	c.queue.dispositions[slot.opportunity_id] = {"slot_id": t.slot_id, "actor_id": t.actor_id,
		"kind": g.phase, "observed_revision": v.revision, "issuer_id": "M403_ISOLATED_QUEUE", "action_id": t.action_id}
	if op == "COMPLETE":
		c.action_receipts[t.action_id] = {"action_id": t.action_id, "authorization_id": t.authorization_id,
			"slot_id": t.slot_id, "actor_id": t.actor_id, "queue_id": t.queue_id,
			"completed_revision": c.revision, "impact_reason": g.impact_reason}
	c.active_operation = null
	c.queue.cursor += 1
	c.queue.phase = "STOPPED" if not c.outcome.is_empty() else ("DRAINED" if c.queue.cursor == c.queue.opportunities.size() else "READY")
	return reply("M403_ACTION_COMPLETED" if op == "COMPLETE" else "M403_ACTION_CANCELLED", "APPLIED")


static func seal_candidate(v: Dictionary, c: Dictionary) -> Dictionary:
	if v.queue.phase != "DRAINED" or v.active_operation != null \
		or v.queue.dispositions.size() != v.queue.opportunities.size(): return reply("M403_ROUND_NOT_CLOSABLE")
	var receipts: Dictionary = receipt_set(v)
	if receipts.is_empty(): return reply("M403_NO_REAL_PROGRESS")
	if Classifier.classify(v).encounter_outcome != "ACTIVE": return reply("M403_BOUNDARY_DEPENDENCY")
	var expected: Array = []
	for slot in v.queue.opportunities: expected.append(slot.opportunity_id)
	c.phase = "SEALED"
	c.witness = {"session": v.session, "generation": v.generation, "round_id": v.round_id,
		"queue_id": v.queue.queue_id, "witness_id": v.queue.queue_id + "/witness",
		"expected_opportunities": expected, "action_receipts": receipts,
		"dispositions": v.queue.dispositions.duplicate(true), "outstanding": [], "aborted": false,
		"phase": "SEALED", "revision": c.revision}
	var event: Dictionary = {"version": 1, "kind": "ROUND_CLOSED", "issuer_id": "M403_ISOLATED_QUEUE",
		"session": v.session, "generation": v.generation, "round_id": v.round_id,
		"event_id": v.queue.queue_id + "/close", "witness_id": c.witness.witness_id,
		"sealed_revision": c.revision, "authorization_id": v.events.size() + 1, "queue_id": v.queue.queue_id}
	c.events[event.event_id] = event.duplicate(true)
	var result: Dictionary = reply("M403_ROUND_SEALED", "AUTHORIZED")
	result.event = event
	return result


static func close_candidate(v: Dictionary, c: Dictionary, p: Dictionary) -> Dictionary:
	var ticks: Array = []
	# Every budget reads the same pre-close root, never the previous actor's commit.
	for id in v.clocks:
		var old: Dictionary = v.clocks[id]
		if not old.active: continue
		var budget: int = old.budget if old.entry_round == v.round_id else maxi(0, old.budget - 1)
		c.clocks[id].budget = budget
		if budget == 0:
			set_party(c, id, 0, "DEAD")
			c.clocks[id].active = false
		ticks.append({"actor_id": id, "episode_id": old.episode_id, "before": old.budget, "after": budget,
			"reason_code": "M403_BLED_OUT" if budget == 0 else ("M403_BLEED_GRACE" if old.entry_round == v.round_id else "M403_BLEED_TICK")})
	c.phase = "CLOSED"
	c.event_consumed[p.event_id] = c.revision
	c.semantic_closed[p.queue_id] = c.revision
	# Unreachable terminal under today's seal/tick rules; retain the consistency gate.
	freeze(c, Classifier.classify(c), "ROUND_CLOSED")
	var result: Dictionary = reply("M403_ROUND_CLOSED", "APPLIED")
	result.episodes = ticks
	return result
