extends RefCounted

# Pure transition/reconstruction. These detached candidates are never live owners.
const C = preload("res://scripts/m4/playable_contract.gd")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const Adapter = preload("res://scripts/m4/playable_decision_adapter.gd")
const EffectRules = preload("res://scripts/m4/playable_effect_rules.gd")
const Guidance = preload("res://scripts/m4/playable_guidance_adapter.gd")
const Presentation = preload("res://scripts/m4/playable_presentation_projection.gd")
const MAX_COUNTER: int = 9223372036854775807

static func identity(r: Dictionary) -> Dictionary:
	return {"session": r.session, "generation": r.generation, "round_id": r.round_id, "state_revision": r.revision}

static func prefix(r: Dictionary) -> String:
	return "m405/%s/%s" % [r.session, r.generation]

static func initial(fixture_id: String, session: int, generation: int = 1, fixture_version: int = 1) -> Dictionary:
	if session == 0 or generation < 1 or Catalog.fixture(fixture_id, fixture_version).is_empty(): return {}
	return {"domain": "M4_PLAYABLE", "version": 1, "session": session, "generation": generation,
		"revision": 0, "seed": Catalog.seed_reference_snapshot(fixture_id, fixture_version), "phase": "PREPARED", "round_id": 1,
		"closed_rounds": 0, "party": Catalog.initial_party(fixture_id, session, generation, fixture_version),
		"enemies": Catalog.initial_enemies(fixture_id, fixture_version), "guidance": {"encounter_id": session,
			"generation": generation, "round_id": 1, "guidance_revision": 0, "pending": null,
			"active": null, "profiles": Catalog.content(fixture_version).profiles},
		"command": null, "queue": null, "declarations": [], "actions": [], "receipts": [],
		"requests": [], "close": null, "round_history": [], "outcome": null, "diagnostic": null, "journal": []}

static func classify(r: Dictionary) -> Dictionary:
	var active: int = 0
	var escaped: int = 0
	var enemies: int = 0
	for p in r.party:
		active += int(p.eligible)
		escaped += int(p.participation == "RETREATED")
	for e in r.enemies: enemies += int(e.available)
	if active > 0: return {"result": "ACTIVE" if enemies > 0 else "VICTORY", "reason": "M403_CONTINUE" if enemies > 0 else "M403_ENEMIES_UNAVAILABLE"}
	if escaped == r.party.size(): return {"result": "PARTY_RETREAT", "reason": "M403_ALL_PARTY_RETREATED"}
	if escaped > 0: return {"result": "MIXED_WITHDRAWAL", "reason": "M403_ESCAPED_WITH_LEFT_BEHIND"}
	return {"result": "DEFEAT", "reason": "M403_MUTUAL_INCAPACITATION" if enemies == 0 else "M403_NO_ACTIVE_PARTY"}

static func fresh(r: Dictionary) -> bool:
	if r.phase != "PREPARED" or r.outcome != null or r.closed_rounds >= 6 or classify(r).result != "ACTIVE" or not r.party[0].eligible or r.command == null: return false
	var cmd: Dictionary = r.command
	if cmd.actor_id != "player" or cmd.accepted_round != r.round_id or cmd.accepted_revision > r.revision: return false
	for j in r.journal:
		if j.operation == "COMMAND" and j.post_revision == cmd.accepted_revision and j.request.request_id == cmd.request_id:
			return j.request.payload == {"actor_id": cmd.actor_id, "action": cmd.action, "target_id": cmd.target_id}
	return false

static func active_grant(r: Dictionary) -> Dictionary:
	for a in r.actions:
		if a.phase in ["LOCKED", "APPLIED", "SKIPPED"]: return a
	return {}

static func view(r: Dictionary) -> Dictionary:
	var a: Dictionary = active_grant(r)
	var accepted: bool = fresh(r)
	return {"identity": identity(r), "phase": r.phase, "queue_phase": "ABSENT" if r.queue == null else r.queue.phase,
		"queue_id": null if r.queue == null else r.queue.queue_id,
		"command_ready": r.phase == "PREPARED" and r.outcome == null and r.closed_rounds < 6 and classify(r).result == "ACTIVE" and r.party[0].eligible and not accepted,
		"has_accepted_fresh_command": accepted, "guidance": r.guidance.duplicate(true), "party": r.party.duplicate(true),
		"enemies": r.enemies.duplicate(true), "decision": locked_decision(r), "outcome": r.outcome.duplicate(true) if r.outcome != null else null,
		"diagnostic": r.diagnostic, "active_token": a.token.duplicate(true) if not a.is_empty() else null, "boundary_changes": boundary_changes(r)}

static func response(r: Dictionary, status: String, reason: String, token: Variant = null, effect: Variant = null, receipt: Variant = null) -> Dictionary:
	return {"domain": "M4_PLAYABLE", "version": 1, "status": status, "reason": "M405_" + reason,
		"identity": identity(r), "token": token, "effect": effect, "receipt": receipt,
		"view": null if status == "REJECTED" else view(r), "guidance_reason": ""}

static func slot(r: Dictionary) -> Dictionary:
	if r.queue == null or r.queue.cursor >= r.queue.opportunities.size(): return {}
	return r.queue.opportunities[r.queue.cursor].duplicate(true)

static func actor(r: Dictionary, id: String) -> Dictionary:
	for row in r.party + r.enemies:
		if row.actor_id == id: return row
	return {}

static func observation(r: Dictionary) -> Dictionary:
	var s: Dictionary = slot(r)
	if r.phase != "OPEN" or r.queue == null or r.queue.phase != "READY" or s.is_empty() or not active_grant(r).is_empty(): return {}
	var p: Dictionary = actor(r, s.actor_id)
	if p.get("role") != "NPC" or not p.eligible: return {}
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": identity(r),
		"source": {"owner_id": "m405/owner/%s" % r.session, "owner_revision": r.revision,
			"observation_id": "%s/observation/%s" % [prefix(r), r.revision]},
		"slot": {"queue_id": r.queue.queue_id, "slot_id": s.slot_id, "opportunity_id": s.opportunity_id,
			"actor_id": s.actor_id, "cursor": r.queue.cursor, "phase": "READY"},
		"party": r.party.duplicate(true), "enemies": r.enemies.duplicate(true),
		"hits": r.declarations.duplicate(true), "guidance": r.guidance.duplicate(true)}

static func weakest(r: Dictionary) -> String:
	var best: Dictionary = {}
	for p in r.party:
		if not p.eligible: continue
		if best.is_empty() or p.hp * best.max_hp < best.hp * p.max_hp or (p.hp * best.max_hp == best.hp * p.max_hp and p.hp < best.hp): best = p
	return best.get("actor_id", "")

static func damage(id: String) -> int:
	return 5 if id == "player" else (1 if id in Catalog.PARTY else 3)

static func gate(r: Dictionary, req: Variant) -> String:
	var invalid: String = C.request_error(req)
	if not invalid.is_empty(): return invalid
	if req.identity.session != r.session: return "FOREIGN_SESSION"
	if req.identity.generation != r.generation: return "STALE_GENERATION"
	var allowed: Array = ["INPUT"] if req.operation in ["COMMAND", "GUIDANCE"] else (["INPUT", "DRIVER"] if req.operation == "RESTART" else (["PRESENTER", "DRIVER"] if req.operation in ["IMPACT", "COMPLETE"] else ["DRIVER"]))
	if req.issuer not in allowed: return "UNAUTHORIZED"
	var grant: Dictionary = {}
	if req.operation in ["IMPACT", "COMPLETE", "CANCEL"]:
		for a in r.actions:
			if a.token == req.payload.token: grant = a
		if grant.is_empty(): return "INVALID_TOKEN"
	for previous in r.requests:
		if previous.request_id == req.request_id: return "DUPLICATE_REQUEST"
	if not grant.is_empty():
		if (req.operation in ["IMPACT", "CANCEL"] and grant.phase != "LOCKED") or (req.operation == "COMPLETE" and grant.phase not in ["APPLIED", "SKIPPED"]): return "INVALID_TOKEN_PHASE"
	if req.identity.round_id != r.round_id: return "WRONG_ROUND"
	if req.queue_id != (null if r.queue == null else r.queue.queue_id): return "WRONG_QUEUE"
	if r.phase == "SEALED" and req.operation == "RESTART": return "SEALED_RESTART"
	if r.phase == "TERMINAL" and req.operation not in ["COMPLETE", "RESTART"]: return "TERMINAL"
	if req.operation == "CLOSE_ROUND":
		if r.phase != "OPEN" or r.queue == null or r.queue.phase != "DRAINED" or not active_grant(r).is_empty(): return "INVALID_PHASE"
		if classify(r).result != "ACTIVE": return "TERMINAL"
	if req.operation in ["COMMAND", "GUIDANCE"]:
		if r.phase != "PREPARED" or not view(r).command_ready: return "COMMAND_LOCKED"
	elif req.operation == "ADMIT":
		if r.phase != "PREPARED": return "INVALID_PHASE"
	elif req.operation in ["ADVANCE", "DECIDE_LOCK", "PLAYER_LOCK", "ENEMY_LOCK"]:
		if r.phase != "OPEN" or r.queue == null or r.queue.phase != "READY" or not active_grant(r).is_empty(): return "INVALID_PHASE"
	elif req.operation in ["IMPACT", "COMPLETE", "CANCEL"]:
		if r.phase not in ["OPEN", "TERMINAL"]: return "INVALID_PHASE"
		if r.queue == null or r.queue.phase != "WAIT_ACTION" or active_grant(r) != grant: return "INVALID_TOKEN"
		if r.phase == "TERMINAL" and req.operation != "COMPLETE": return "TERMINAL"
	if req.identity.state_revision != r.revision: return "STALE_REVISION"
	if (r.generation if req.operation == "RESTART" else r.revision) == MAX_COUNTER: return "COUNTER_OVERFLOW"
	return ""

static func freeze(r: Dictionary) -> void:
	var result: Dictionary = classify(r)
	if result.result == "ACTIVE": return
	var party: Array = []
	var enemies: Array = []
	for p in r.party:
		party.append({"actor_id": p.actor_id, "life": p.life, "participation": p.participation, "hp": p.hp, "final_episode": p.episode.duplicate(true) if p.episode != null else null})
	for e in r.enemies: enemies.append({"actor_id": e.actor_id, "hp": e.hp, "available": e.available})
	r.outcome = {"outcome_id": "%s/outcome/%s" % [prefix(r), r.revision], "freeze_revision": r.revision,
		"result": result.result, "reason": result.reason, "party": party, "enemies": enemies}
	r.phase = "TERMINAL"
	r.guidance.pending = null
	r.guidance.active = null
	if r.queue != null:
		for i in range(r.queue.cursor + 1, r.queue.opportunities.size()):
			r.queue.dispositions.append(disposition(r.queue.opportunities[i], "TERMINAL_STOP", null, r.revision))

static func dispose(r: Dictionary, kind: String, action_id: Variant) -> void:
	var s: Dictionary = slot(r)
	var row: Dictionary = disposition(s, kind, action_id, r.revision)
	if r.phase == "TERMINAL":
		r.queue.dispositions.insert(r.queue.cursor, row)
		r.queue.cursor = r.queue.opportunities.size()
		r.queue.phase = "STOPPED"
		return
	r.queue.dispositions.append(row)
	r.queue.cursor += 1
	r.queue.phase = "DRAINED" if r.queue.cursor == r.queue.opportunities.size() else "READY"

static func apply(r: Dictionary, req: Dictionary) -> Dictionary:
	# Caller supplies detached r. Reject discards it; owner never passes its live root.
	var op: String = req.operation
	var token: Variant = null
	var effect: Variant = null
	var receipt: Variant = null
	var status: String = "APPLIED"
	var reason: String = ""
	if op in ["CLOSE_ROUND", "RESTART"]:
		# Boundary operations have dedicated publication paths.
		return response(r, "REJECTED", "INVALID_PHASE")
	if op == "GUIDANCE":
		var invalid: String = Guidance.rejection(r, req.payload.request)
		if not invalid.is_empty():
			var rejected: Dictionary = response(r, "REJECTED", "GUIDANCE_REJECTED")
			rejected.guidance_reason = invalid
			return rejected
		if r.guidance.guidance_revision == MAX_COUNTER: return response(r, "REJECTED", "COUNTER_OVERFLOW")
		r.guidance.guidance_revision += 1
		r.guidance.pending = Guidance.record(r, req.payload.request.guidance_type, req.payload.request.preferred_target_id)
		status = "ACCEPTED"; reason = "GUIDANCE_ACCEPTED"
	elif op == "COMMAND":
		var p: Dictionary = req.payload
		if p.actor_id != "player": return response(r, "REJECTED", "UNAUTHORIZED")
		if (p.action == "DEFEND" and p.target_id != "player") or (p.action == "ATTACK" and p.target_id not in Catalog.ENEMIES): return response(r, "REJECTED", "INVALID_TARGET")
		r.command = {"request_id": req.request_id, "actor_id": p.actor_id, "action": p.action, "target_id": p.target_id,
			"accepted_round": r.round_id, "accepted_revision": r.revision + 1}
		status = "ACCEPTED"; reason = "COMMAND_ACCEPTED"
	elif op == "ADMIT":
		if classify(r).result != "ACTIVE":
			r.revision += 1
			freeze(r)
			return response(r, "STOPPED", "OUTCOME_FROZEN")
		if r.party[0].eligible and not fresh(r): return response(r, "REJECTED", "COMMAND_REQUIRED")
		if not r.party[0].eligible and r.command != null: return response(r, "REJECTED", "INVALID_BINDING")
		var qid: String = "%s/round/%s" % [prefix(r), r.round_id]
		var opportunities: Array = []
		for id in Catalog.PARTY + Catalog.ENEMIES:
			opportunities.append({"opportunity_id": qid + "/opportunity/" + id, "slot_id": qid + "/slot/" + id, "actor_id": id})
		r.queue = {"queue_id": qid, "phase": "READY", "cursor": 0, "opportunities": opportunities, "dispositions": []}
		r.phase = "OPEN"
		for e in r.enemies:
			if e.available: r.declarations.append({"actor_id": e.actor_id, "target_id": weakest(r), "damage": 3})
		r.guidance.active = r.guidance.pending.duplicate(true) if r.party[0].eligible and r.guidance.pending != null else Guidance.record(r)
		r.guidance.pending = null
		reason = "ROUND_ADMITTED"
	elif op == "ADVANCE":
		var s: Dictionary = slot(r)
		var p: Dictionary = actor(r, s.actor_id)
		var eligible: bool = p.get("eligible", p.get("available", false))
		if eligible and not (s.actor_id == "player" and r.command == null):
			return response(r, "READY", "SLOT_READY")
		r.revision += 1
		dispose(r, "NO_PLAYER_COMMAND" if eligible else "UNAVAILABLE", null)
		return response(r, "APPLIED", "SLOT_DISPOSED")
	elif op in ["PLAYER_LOCK", "ENEMY_LOCK", "DECIDE_LOCK"]:
		var s: Dictionary = slot(r)
		var p: Dictionary = actor(r, s.actor_id)
		if not p.get("eligible", p.get("available", false)): return response(r, "REJECTED", "ACTOR_UNAVAILABLE")
		var kind: String = "ATTACK"
		var target: String = ""
		var episode: Variant = null
		if op == "PLAYER_LOCK":
			if s.actor_id != "player" or req.payload.slot_id != s.slot_id: return response(r, "REJECTED", "WRONG_SLOT")
			if r.command == null: return response(r, "REJECTED", "COMMAND_REQUIRED")
			kind = r.command.action
			target = r.command.target_id
			if kind == "ATTACK" and not actor(r, target).available:
				for e in r.enemies:
					if e.available: target = e.actor_id; break
		elif op == "ENEMY_LOCK":
			if s.actor_id not in Catalog.ENEMIES or req.payload.slot_id != s.slot_id: return response(r, "REJECTED", "WRONG_SLOT")
			for h in r.declarations:
				if h.actor_id == s.actor_id: target = h.target_id
		else:
			var observed: Dictionary = observation(r)
			if observed.is_empty() or observed != req.payload.observation: return response(r, "REJECTED", "INVALID_BINDING")
			var d: Dictionary = Adapter.decide(observed)
			if not C.valid("Decision", d) or d.legal_effect.status != "CANDIDATE_ONLY": return response(r, "REJECTED", "INVALID_CANDIDATE")
			kind = d.selected.action; target = d.selected.target_id; episode = d.selected.episode_id
		if target.is_empty(): return response(r, "REJECTED", "INVALID_TARGET")
		var action_id: int = r.actions.size() + 1
		var lock_identity: Dictionary = identity(r)
		lock_identity.state_revision += 1
		token = {"domain": "M4_PLAYABLE", "version": 1, "identity": lock_identity, "queue_id": r.queue.queue_id,
			"slot_id": s.slot_id, "opportunity_id": s.opportunity_id, "action_id": action_id,
			"authorization_id": "%s/authorization/%s" % [prefix(r), action_id], "actor_id": s.actor_id,
			"target_id": target, "kind": kind, "episode_id": episode, "amount": damage(s.actor_id) if kind == "ATTACK" else 0, "request_id": req.request_id}
		r.actions.append({"token": token.duplicate(true), "phase": "LOCKED", "effect": null, "impact_revision": null, "disposed_revision": null})
		r.queue.phase = "WAIT_ACTION"
		status = "AUTHORIZED"; reason = "ACTION_LOCKED"
	elif op in ["IMPACT", "COMPLETE", "CANCEL"]:
		var a: Dictionary = active_grant(r)
		token = a.token
		if op == "IMPACT":
			var projection: Dictionary = EffectRules.project(r, token)
			if projection.is_empty(): return response(r, "REJECTED", "INVALID_TARGET")
			r.party = projection.party
			r.enemies = projection.enemies
			effect = projection.effect
			a.phase = effect.status
			a.effect = effect.duplicate(true)
			a.impact_revision = r.revision + 1
			status = effect.status
			reason = effect.reason.trim_prefix("M405_")
			token = null
		elif op == "COMPLETE":
			receipt = {"receipt_id": "%s/receipt/%s" % [prefix(r), token.action_id], "action_id": token.action_id,
				"session": r.session, "authorization_id": token.authorization_id, "generation": r.generation, "round_id": r.round_id,
				"queue_id": token.queue_id, "slot_id": token.slot_id, "impact_revision": a.impact_revision,
				"completion_revision": r.revision + 1, "effect_status": a.effect.status}
			r.receipts.append(receipt.duplicate(true)); a.phase = "COMPLETED"; a.disposed_revision = r.revision + 1
			r.revision += 1; dispose(r, "COMPLETED", token.action_id)
			return response(r, "COMPLETED", "ACTION_COMPLETED", null, null, receipt)
		else:
			a.phase = "CANCELLED"; a.disposed_revision = r.revision + 1
			r.revision += 1; dispose(r, "CANCELLED", token.action_id)
			return response(r, "APPLIED", "ACTION_CANCELLED")
	else: return response(r, "REJECTED", "INVALID_PHASE")
	r.revision += 1
	if op == "IMPACT" and effect.status == "APPLIED": freeze(r)
	return response(r, status, reason, token, effect, receipt)

static func step(prior: Dictionary, req: Variant) -> Dictionary:
	var invalid: String = gate(prior, req)
	if not invalid.is_empty(): return {"root": {}, "response": response(prior, "REJECTED", invalid)}
	var candidate: Dictionary = prior.duplicate(true)
	var reply: Dictionary = apply(candidate, req)
	if reply.status == "REJECTED" or reply.status == "READY": return {"root": {}, "response": reply}
	candidate.requests.append({"request_id": req.request_id, "operation": req.operation, "accepted_revision": candidate.revision, "result_status": reply.status})
	# View/freshness needs the accepted COMMAND's actual journal provenance.
	var entry: Dictionary = {"sequence": prior.journal.size() + 1, "operation": req.operation, "request": req.duplicate(true),
		"internal": null, "pre_revision": prior.revision, "post_revision": candidate.revision, "result_digest": "pending"}
	candidate.journal.append(entry)
	reply.view = view(candidate)
	reply.identity = identity(candidate)
	entry.result_digest = Catalog.canonical(reply).sha256_text()
	return {"root": candidate, "response": reply}

static func impact_projection_valid(prior: Dictionary, candidate: Dictionary, req: Dictionary, reply: Dictionary) -> bool:
	# Validate the authorized effect against the pre-impact root and the actual
	# published HP, resources, Guard, lifecycle and grant. Full reply binding
	# and replay cover the remaining root and journal fields.
	if req.get("operation") != "IMPACT" or not gate(prior, req).is_empty(): return false
	if not C.response_valid("IMPACT", reply) or not C.valid("Root", candidate): return false
	var token: Dictionary = req.payload.token
	var opportunity: Dictionary = slot(prior)
	if opportunity.is_empty() or token.actor_id != opportunity.actor_id or token.slot_id != opportunity.slot_id or token.opportunity_id != opportunity.opportunity_id: return false
	if token.identity.session != prior.session or token.identity.generation != prior.generation or token.identity.round_id != prior.round_id or token.identity.state_revision != prior.revision or token.queue_id != prior.queue.queue_id: return false
	if token.kind == "ATTACK" and token.amount != damage(token.actor_id): return false
	var expected: Dictionary = EffectRules.project(prior, token)
	if expected.is_empty(): return false
	var published: Dictionary = active_grant(candidate)
	return (reply.effect == expected.effect and candidate.party == expected.party
		and candidate.enemies == expected.enemies and candidate.receipts == prior.receipts
		and not published.is_empty() and published.token == token and published.effect == expected.effect
		and published.phase == expected.effect.status and published.impact_revision == candidate.revision)

static func candidate_valid(prior: Dictionary, req: Dictionary, result: Dictionary) -> bool:
	if not C.exact(result, ["root", "response"]): return false
	if not C.response_valid(req.operation, result.response) or not C.valid("Root", result.root): return false
	if result.response.view != view(result.root) or result.response.identity != identity(result.root): return false
	if req.operation == "IMPACT" and not impact_projection_valid(prior, result.root, req, result.response): return false
	# Root reconstruction alone cannot authenticate an outbound token/receipt.
	# Bind the entire reply and candidate to the same exact authorized operation.
	# step() is pure and does not call candidate_valid(), so replay stays finite.
	return result == step(prior, req)

static func restart(prior: Dictionary, request: Dictionary) -> Dictionary:
	var rejection: String = gate(prior, request)
	if not rejection.is_empty():
		return {"root": {}, "response": response(prior, "REJECTED", rejection)}
	var candidate: Dictionary = initial(request.payload.fixture_id, prior.session, prior.generation + 1, request.payload.fixture_version)
	if candidate.is_empty():
		return {"root": {}, "response": response(prior, "REJECTED", "UNKNOWN_FIXTURE")}
	return {"root": candidate, "response": response(candidate, "APPLIED", "RESTARTED")}

static func replay(seed: Dictionary, session: int, generation: int, journal: Variant, events: Variant = null) -> Dictionary:
	if not C.valid("SeedReference", seed) or not C.valid("[]JournalEntry", journal): return {}
	if seed != Catalog.seed_reference_snapshot(seed.fixture_id, seed.fixture_version): return {}
	var r: Dictionary = initial(seed.fixture_id, session, generation, seed.fixture_version)
	if r.is_empty(): return {}
	var projected: Array = []
	for entry in journal:
		var next: Dictionary
		if entry.internal != null:
			next = close_step(r, entry.internal.origin, entry.operation)
			if next.root.is_empty() or not C.response_valid(entry.operation, next.response): return {}
		else:
			if entry.request == null or entry.operation != entry.request.operation: return {}
			next = step(r, entry.request)
			if next.root.is_empty() or not candidate_valid(r, entry.request, next): return {}
		if next.root.journal.back() != entry: return {}
		if events != null:
			projected.append_array(Presentation.project(entry.operation, next.response, entry.request))
		r = next.root
	if events != null:
		events.append_array(projected)
	return r

static func root_valid(r: Variant) -> bool:
	if not C.valid("Root", r) or r.round_id > 6 or r.closed_rounds > 6 or r.revision != r.journal.size(): return false
	if r.seed != Catalog.seed_reference_snapshot(r.seed.fixture_id, r.seed.fixture_version) or Catalog.fixture(r.seed.fixture_id, r.seed.fixture_version).is_empty(): return false
	if r.party.size() != 4 or r.enemies.size() != 2: return false
	var orders: Array = []
	var episodes: Array = []
	for i in range(4):
		var p: Dictionary = r.party[i]
		if p.actor_id != Catalog.PARTY[i] or p.role != ("PLAYER" if i == 0 else "NPC") or p.max_hp != Catalog.MAX_HP[i] or not C.party_valid(p, r.round_id): return false
		if p.episode != null:
			if p.episode.entry_order in orders or p.episode.episode_id in episodes: return false
			orders.append(p.episode.entry_order); episodes.append(p.episode.episode_id)
	for i in range(2):
		var e: Dictionary = r.enemies[i]
		if e.actor_id != Catalog.ENEMIES[i] or e.max_hp != Catalog.MAX_HP[i + 4] or e.hp > e.max_hp or e.available != (e.hp > 0): return false
	if r.guidance.encounter_id != r.session or r.guidance.generation != r.generation or r.guidance.round_id != r.round_id or r.guidance.profiles != Catalog.content(r.seed.fixture_version).profiles: return false
	if r.phase in ["OPEN", "SEALED"] and r.queue == null: return false
	if r.queue != null:
		if r.queue.opportunities.size() != 6 or r.queue.cursor > 6: return false
		if not queue_relation_valid(r): return false
		for i in range(6):
			if r.queue.opportunities[i].actor_id != (Catalog.PARTY + Catalog.ENEMIES)[i]: return false
	var rebuilt: Dictionary = replay(r.seed, r.session, r.generation, r.journal)
	return not rebuilt.is_empty() and rebuilt == r

static func disposition(opportunity: Dictionary, kind: String, action_id: Variant, revision: int) -> Dictionary:
	return {"opportunity_id": opportunity.opportunity_id, "slot_id": opportunity.slot_id,
		"actor_id": opportunity.actor_id, "kind": kind, "action_id": action_id, "observed_revision": revision}

static func locked_decision(r: Dictionary) -> Variant:
	var grant: Dictionary = active_grant(r)
	if grant.is_empty(): return null
	for entry in r.journal:
		if entry.operation == "DECIDE_LOCK" and entry.request.request_id == grant.token.request_id:
			return Adapter.decide(entry.request.payload.observation)
	return null

static func boundary_changes(r: Dictionary) -> Variant:
	if r.journal.is_empty() or r.journal.back().operation != "COMMIT_CLOSE": return null
	return r.round_history.back().close.changes.duplicate(true)

static func queue_relation_valid(r: Dictionary) -> bool:
	var q: Dictionary = r.queue
	var grant: Dictionary = active_grant(r)
	if r.phase == "TERMINAL" and q.phase == "WAIT_ACTION":
		if r.outcome == null or grant.is_empty() or grant.phase != "APPLIED": return false
		if grant.impact_revision != r.outcome.freeze_revision or q.cursor >= 6 or q.dispositions.size() != 5: return false
		if grant.token.opportunity_id != q.opportunities[q.cursor].opportunity_id: return false
		for i in range(6):
			if i == q.cursor: continue
			var d: Dictionary = q.dispositions[i if i < q.cursor else i - 1]
			var opportunity: Dictionary = q.opportunities[i]
			if d.opportunity_id != opportunity.opportunity_id or d.actor_id != opportunity.actor_id or d.slot_id != opportunity.slot_id: return false
			if i > q.cursor and d != disposition(opportunity, "TERMINAL_STOP", null, r.outcome.freeze_revision): return false
		return true
	if r.phase == "TERMINAL" and (q.phase != "STOPPED" or q.cursor != 6 or not grant.is_empty()): return false
	if q.dispositions.size() != q.cursor: return false
	for i in range(q.cursor):
		var d: Dictionary = q.dispositions[i]
		var opportunity: Dictionary = q.opportunities[i]
		if d.opportunity_id != opportunity.opportunity_id or d.actor_id != opportunity.actor_id or d.slot_id != opportunity.slot_id: return false
		if r.phase != "TERMINAL" and d.kind == "TERMINAL_STOP": return false
	return true

static func close_step(prior: Dictionary, origin: Dictionary, kind: String) -> Dictionary:
	# Pure internal producer. External callers cannot submit SEAL/COMMIT_CLOSE.
	var rejection: String = ""
	if kind == "SEAL":
		rejection = gate(prior, origin)
		if rejection.is_empty() and origin.operation != "CLOSE_ROUND": rejection = "INVALID_PHASE"
		if rejection.is_empty():
			var progress: bool = false
			for receipt in prior.receipts:
				if receipt.queue_id == prior.queue.queue_id: progress = true
			if not progress: rejection = "NO_REAL_PROGRESS"
	elif kind == "COMMIT_CLOSE":
		if prior.phase != "SEALED" or prior.close == null or prior.close.consumed or prior.journal.is_empty(): rejection = "INVALID_PHASE"
		elif prior.journal.back().operation != "SEAL" or prior.journal.back().internal.origin != origin: rejection = "INVALID_BINDING"
	else: rejection = "INVALID_PHASE"
	if not rejection.is_empty(): return {"root": {}, "response": response(prior, "REJECTED", rejection)}
	if prior.revision == MAX_COUNTER: return {"root": {}, "response": response(prior, "REJECTED", "COUNTER_OVERFLOW")}
	var r: Dictionary = prior.duplicate(true)
	r.revision += 1
	var status: String = "AUTHORIZED"
	var reason: String = "ROUND_SEALED"
	var internal: Dictionary
	if kind == "SEAL":
		var expected: Array = []
		var receipt_ids: Array = []
		for opportunity in r.queue.opportunities: expected.append(opportunity.opportunity_id)
		for receipt in r.receipts:
			if receipt.queue_id == r.queue.queue_id: receipt_ids.append(receipt.receipt_id)
		var witness: Dictionary = {"session": r.session, "generation": r.generation, "round_id": r.round_id,
			"queue_id": r.queue.queue_id, "witness_id": r.queue.queue_id + "/witness", "expected_opportunities": expected,
			"receipt_ids": receipt_ids, "dispositions": r.queue.dispositions.duplicate(true), "outstanding": 0, "sealed_revision": r.revision}
		var event: Dictionary = {"domain": "M4_PLAYABLE", "version": 1, "session": r.session, "generation": r.generation,
			"round_id": r.round_id, "queue_id": r.queue.queue_id, "event_id": r.queue.queue_id + "/close",
			"witness_id": witness.witness_id, "sealed_revision": r.revision, "authorization_id": r.queue.queue_id + "/close-authorization"}
		r.close = {"witness": witness, "event": event, "consumed": false, "close_revision": null, "changes": null}
		r.phase = "SEALED"
		r.requests.append({"request_id": origin.request_id, "operation": "CLOSE_ROUND", "accepted_revision": r.revision, "result_status": "AUTHORIZED"})
		internal = {"kind": kind, "witness": witness.duplicate(true), "event": event.duplicate(true), "origin": origin.duplicate(true)}
	else:
		internal = {"kind": kind, "witness": r.close.witness.duplicate(true), "event": r.close.event.duplicate(true), "origin": origin.duplicate(true)}
		var changes: Dictionary = {"guards": [], "lifecycle": [], "clocks": []}
		for p in r.party:
			if p.guard != null:
				changes.guards.append({"actor_id": p.actor_id, "before": p.guard.duplicate(true), "after": null, "cause": "ROUND_CLOSE"})
				p.guard = null
			if p.life != "DOWN": continue
			var before: int = p.episode.budget
			var clock_reason: String = "GRACE"
			if p.episode.entry_round < r.round_id:
				p.episode.budget -= 1
				clock_reason = "TICK"
				if p.episode.budget == 0:
					clock_reason = "BLED_OUT"
					p.life = "DEAD"
					p.episode.active = false
					changes.lifecycle.append({"actor_id": p.actor_id, "before_life": "DOWN", "after_life": "DEAD",
						"before_participation": "PRESENT", "after_participation": "PRESENT"})
			changes.clocks.append({"actor_id": p.actor_id, "episode_id": p.episode.episode_id,
				"before_budget": before, "after_budget": p.episode.budget, "reason": clock_reason})
		if classify(r).result != "ACTIVE": return {"root": {}, "response": response(prior, "REJECTED", "CLOSE_FAILED")}
		r.close.consumed = true
		r.close.close_revision = r.revision
		r.close.changes = changes
		r.round_history.append({"round_id": r.round_id, "queue": r.queue.duplicate(true),
			"declarations": r.declarations.duplicate(true), "close": r.close.duplicate(true)})
		r.closed_rounds += 1
		r.command = null
		r.guidance.active = null
		if r.closed_rounds == r.seed.capacity:
			r.phase = "CLOSED"
			r.guidance.pending = null
			r.diagnostic = "DEMO_LIMIT_REACHED"
			status = "STOPPED"; reason = "DEMO_LIMIT_REACHED"
		else:
			r.phase = "PREPARED"
			r.round_id += 1
			r.queue = null
			r.close = null
			r.declarations.clear()
			r.guidance.round_id = r.round_id
			r.guidance.pending = Guidance.record(r)
			status = "APPLIED"; reason = "ROUND_CLOSED"
	var entry: Dictionary = {"sequence": r.journal.size() + 1, "operation": kind, "request": null,
		"internal": internal, "pre_revision": prior.revision, "post_revision": r.revision, "result_digest": "pending"}
	r.journal.append(entry)
	var reply: Dictionary = response(r, status, reason)
	entry.result_digest = Catalog.canonical(reply).sha256_text()
	return {"root": r, "response": reply}
