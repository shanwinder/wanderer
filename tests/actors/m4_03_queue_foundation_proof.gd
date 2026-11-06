extends SceneTree

const Encounter = preload("res://scripts/m4/isolated_queue_outcome_encounter.gd")
const Adapter = preload("res://scripts/m4/m403_queue_adapter.gd")
var authority := RefCounted.new()
var cases: Array = []
var checks: int = 0
var failures: int = 0
var current: Dictionary = {}
var start_checks: int = 0
var start_failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	current.assertions.append({"description": message, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL: %s %s" % [current.get("id", "setup"), message])


func begin(description: String) -> void:
	start_checks = checks
	start_failures = failures
	current = {"id": "M403A-%02d" % (cases.size() + 1), "expected": description, "steps": [], "assertions": []}


func end() -> void:
	current.assertion_count = checks - start_checks
	current.failure_count = failures - start_failures
	current.actual = "PASS" if current.failure_count == 0 else "FAIL"
	cases.append(current)
	print("CASE %s: %s" % [current.id, current.actual])


func fixture() -> Dictionary:
	var actors: Array = []
	for id in ["p", "n1", "n2", "n3", "a", "b"]:
		var role: String = "PLAYER" if id == "p" else ("ENEMY" if id in ["a", "b"] else "NPC")
		actors.append({"definition": {"actor_id": id, "display_name": id, "role": role, "base_max_hp": 10},
			"state": {"current_hp": 10} if role == "ENEMY" else
				{"current_hp": 10, "life_state": "ALIVE", "participation": "PRESENT"}})
	return {"actors": actors, "round_plan": [
		{"round_id": 3, "actor_order": ["p", "n1", "n2", "n3", "a", "b"]},
		{"round_id": 4, "actor_order": ["p", "n1", "n2", "n3", "a", "b"]}]}


func state(f: Dictionary, id: String, life: String, hp: int, participation: String = "PRESENT") -> void:
	for row in f.actors:
		if row.definition.actor_id == id:
			row.state = {"current_hp": hp} if row.definition.role == "ENEMY" else \
				{"current_hp": hp, "life_state": life, "participation": participation}


func request(e) -> Dictionary:
	var s: Dictionary = e.snapshot()
	return {"version": 1, "session": s.session, "generation": s.generation,
		"expected_revision": s.revision, "queue_id": s.queue.get("queue_id", "")}


func reset_request(e, f: Dictionary) -> Dictionary:
	var r: Dictionary = request(e)
	r.fixture = f.duplicate(true)
	return r


func observe(e, method: String, input: Variant, cap: Variant, reason: String, status: String, no_delta: bool) -> Dictionary:
	var before: Dictionary = e.snapshot()
	var result: Dictionary = e.call(method, input, cap)
	var after: Dictionary = e.snapshot()
	check(result.reason_code == reason, "%s expected %s got %s" % [method, reason, result])
	check(result.status == status, "exact status " + status)
	if no_delta:
		check(after == before, "N-all: entire published root unchanged")
	else:
		check(after.revision == (0 if method == "restart" else before.revision + 1), "one publication revision")
		check(after.generation == before.generation + (1 if method == "restart" else 0), "generation boundary")
	current.steps.append({"method": method, "input": input.duplicate(true) if input is Dictionary else input,
		"capability": "owned" if cap is RefCounted and cap == authority else ("missing" if cap == null else "foreign"),
		"expected_reason": reason, "expected_status": status, "N_all": no_delta,
		"actual": result.duplicate(true), "before": before, "after": after})
	return result


func fresh(f: Dictionary = fixture()):
	var e = Encounter.new(authority)
	observe(e, "restart", reset_request(e, f), authority, "M403_RESTARTED", "APPLIED", false)
	return e


func advance(e, reason: String = "M403_SLOT_UNAVAILABLE", status: String = "APPLIED", no_delta: bool = false) -> Dictionary:
	return observe(e, "advance", request(e), authority, reason, status, no_delta)


func _eligibility() -> void:
	for role_id in ["p", "n1"]:
		for spec in [["ALIVE", 10, "PRESENT", true], ["DOWN", 0, "PRESENT", false],
			["DEAD", 0, "PRESENT", false], ["ALIVE", 7, "RETREATED", false]]:
			begin("Party %s %s/%s has derived eligibility and is retained" % [role_id, spec[0], spec[2]])
			var f: Dictionary = fixture()
			state(f, role_id, spec[0], spec[1], spec[2])
			var e = fresh(f)
			var v: Dictionary = e.eligibility_snapshot(role_id)
			check(v.actor_exists and v.actor_present == (spec[2] == "PRESENT"), "existence separate from presence")
			check(v.actor_actionable == spec[3] and v.slot_eligible == spec[3], "state and undisposed slot")
			check(v.queue_opportunity_available == (spec[3] and role_id == "p"), "only current actionable opportunity available")
			check(e.snapshot().initial_party.has(role_id) and e.snapshot().actors.has(role_id), "unavailable retained, never unregister")
			end()
	for hp in [10, 0]:
		begin("Enemy HP%s retains original HP availability without DEAD" % hp)
		var f: Dictionary = fixture()
		state(f, "a", "", hp)
		var e = fresh(f)
		check(e.eligibility_snapshot("a").actor_actionable == (hp > 0), "enemy HP eligibility")
		check(e.eligibility_snapshot("a").actor_present, "enemy roster presence independent of HP")
		check(not e.actor_snapshot("a").state.has("life_state"), "no invented Enemy lifecycle")
		end()
	begin("Wrong actor IDs return absent eligibility and cannot mutate authority")
	var e = fresh()
	var before: Dictionary = e.snapshot()
	for id in ["unknown", "", 1, null, [], {}]:
		check(e.actor_snapshot(id).is_empty(), "unknown actor accessor empty")
		check(e.eligibility_snapshot(id) == {"actor_exists": false, "actor_present": false,
			"actor_actionable": false, "slot_eligible": false, "queue_opportunity_available": false}, "all absence predicates false")
	check(e.snapshot() == before, "absence reads N-all")
	end()
	begin("Every accessor and caller fixture is detached from the single owner")
	var f: Dictionary = fixture()
	e = fresh(f)
	before = e.snapshot()
	f.actors[0].state.current_hp = 0
	f.round_plan[0].actor_order.reverse()
	var s: Dictionary = e.snapshot()
	s.actors.p.state.current_hp = 0
	s.actors.p.state.eligible = false
	s.initial_party.reverse()
	s.plan[0].actor_order.clear()
	s.queue.cursor = 6
	s.action_receipts.fake = {"completed": true}
	var actor: Dictionary = e.actor_snapshot("p")
	actor.definition.role = "ENEMY"
	actor.state.eligible = false
	var q: Dictionary = e.queue_snapshot()
	q.opportunities[0].actor_id = "a"
	q.dispositions.fake = true
	var opportunity: Dictionary = e.current_opportunity()
	opportunity.slot_id = "fake"
	var eligibility: Dictionary = e.eligibility_snapshot("p")
	eligibility.actor_actionable = false
	check(e.snapshot() == before and e.eligibility_snapshot("p").actor_actionable, "nested copies cannot change authority/eligibility")
	end()


func _identity_cursor() -> void:
	begin("Stable roster order and internally assigned unique queue/slot/opportunity identities")
	var f: Dictionary = fixture()
	# Interleaved definitions do not move Player from first or change NPC/Enemy relative order.
	f.actors = [f.actors[4], f.actors[1], f.actors[5], f.actors[2], f.actors[0], f.actors[3]]
	var e = fresh(f)
	var before: Dictionary = e.snapshot()
	check(before.initial_party == ["p", "n1", "n2", "n3"] and before.initial_enemies == ["a", "b"], "stable domain orders")
	var ids: Dictionary = {}
	var slots: Dictionary = {}
	var order: Array = []
	for op in e.queue_snapshot().opportunities:
		check(not ids.has(op.opportunity_id) and not slots.has(op.slot_id), "unique identity")
		ids[op.opportunity_id] = true
		slots[op.slot_id] = true
		order.append(op.actor_id)
	check(order == f.round_plan[0].actor_order, "one opportunity per actor in stable order")
	for i in range(4):
		check(e.current_opportunity() == before.queue.opportunities[0], "repeat read identical")
		advance(e, "M403_SLOT_READY", "READY", true)
	check(e.snapshot() == before and e.snapshot().authorizations.is_empty(), "eligible reads consume nothing and mint no token")
	end()
	begin("Consecutive unavailable slots dispose one each and stop at first eligible NPC")
	f = fixture()
	state(f, "p", "DOWN", 0)
	state(f, "n1", "DEAD", 0)
	state(f, "n2", "ALIVE", 7, "RETREATED")
	e = fresh(f)
	var original: Dictionary = e.snapshot()
	var old_request: Dictionary = request(e)
	for i in range(3):
		check(e.queue_snapshot().cursor == i, "monotonic cursor before advance")
		advance(e)
		check(e.queue_snapshot().cursor == i + 1 and e.snapshot().revision == i + 1, "exactly one disposition/publication")
	observe(e, "advance", old_request, authority, "M403_STALE_REVISION", "REJECTED", true)
	check(e.current_opportunity().actor_id == "n3", "next eligible NPC never skipped")
	check(e.eligibility_snapshot("n3").queue_opportunity_available, "D15 foundation does not require Player command")
	advance(e, "M403_SLOT_READY", "READY", true)
	check(e.snapshot().actors == original.actors and e.snapshot().plan == original.plan, "only cursor/disposition/revision changed")
	check(e.snapshot().action_receipts.is_empty() and e.snapshot().authorizations.is_empty(), "dispositions are not receipts or actions")
	end()
	begin("All-unavailable finite traversal drains once and never invents round close/outcome")
	f = fixture()
	for id in ["p", "n1", "n2", "n3"]:
		state(f, id, "DOWN", 0)
	for id in ["a", "b"]:
		state(f, id, "", 0)
	e = fresh(f)
	original = e.snapshot()
	for i in range(6):
		advance(e)
	check(e.current_opportunity().is_empty() and e.queue_snapshot().phase == "DRAINED", "finite bound equals initial roster count")
	check(e.queue_snapshot().dispositions.size() == 6, "each unavailable accounted exactly once")
	for i in range(3):
		advance(e, "M403_BOUNDARY_DEPENDENCY", "REJECTED", true)
	check(e.snapshot().round_id == 3 and e.snapshot().round_index == 0 and e.snapshot().phase == "OPEN", "no auto next-round/close")
	check(e.snapshot().outcome.is_empty() and e.snapshot().summary.is_empty(), "no terminal classification")
	check(e.snapshot().action_receipts.is_empty() and e.snapshot().clocks.is_empty(), "no fabricated receipt or clock")
	check(e.snapshot().actors == original.actors, "queue alone cannot cause gameplay effects")
	var drained: Dictionary = e.snapshot()
	check(e.progress_diagnostic().progress_status == "FOUNDATION_ONLY", "no false nonterminal suspension when both sides unavailable")
	check(e.snapshot() == drained, "diagnostic cannot publish")
	end()
	begin("Actor names cannot collide with current/future issuer namespaces")
	f = fixture()
	f.actors[1].definition.actor_id = "slot_3_p"
	f.actors[2].definition.actor_id = "slot_4_p"
	for row in f.round_plan:
		row.actor_order[1] = "slot_3_p"
		row.actor_order[2] = "slot_4_p"
	e = fresh(f)
	var q: Dictionary = e.queue_snapshot()
	for op in q.opportunities:
		check(op.slot_id != op.actor_id and op.opportunity_id != op.actor_id, "typed namespaces never use actor-named map keys")
	var future: Dictionary = Adapter.build(e.snapshot().session, 1, 4, f.round_plan[1].actor_order)
	check(q.queue_id != future.queue_id and q.opportunities[0].slot_id != future.opportunities[0].slot_id, "future-round identity distinct")
	end()
	begin("M402 validators have no small roster caps; A preserves that while requiring an Enemy")
	f = fixture()
	var extra: Dictionary = f.actors[1].duplicate(true)
	extra.definition.actor_id = "n4"
	f.actors.insert(4, extra)
	extra = f.actors[-1].duplicate(true)
	extra.definition.actor_id = "c"
	f.actors.append(extra)
	for row in f.round_plan:
		row.actor_order = ["p", "n1", "n2", "n3", "n4", "a", "b", "c"]
	e = fresh(f)
	check(e.queue_snapshot().opportunities.size() == 8, "finite roster-derived bound, no invented cap")
	end()
	begin("Minimum roster Player plus one Enemy, no NPC, is valid")
	f = fixture()
	f.actors = [f.actors[0], f.actors[4]]
	for row in f.round_plan:
		row.actor_order = ["p", "a"]
	e = fresh(f)
	check(e.queue_snapshot().opportunities.size() == 2, "minimum exact roster")
	end()


func _protocol() -> void:
	for field in Encounter.REQUEST_FIELDS:
		begin("Advance exact schema: missing " + field)
		var e = fresh()
		var r: Dictionary = request(e)
		r.erase(field)
		observe(e, "advance", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
		end()
	for field in Encounter.REQUEST_FIELDS:
		begin("Strict scalar types without bool/float/StringName coercion: " + field)
		var e = fresh()
		for bad in [null, true, 1.0, [], {}, &"name"]:
			var r: Dictionary = request(e)
			r[field] = bad
			observe(e, "advance", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
		end()
	for spec in [["extra", true, "M403_INVALID_FIELDS"], ["actor_id", "missing", "M403_INVALID_FIELDS"],
		["version", 2, "M403_INVALID_FIELDS"], ["session", 0, "M403_FOREIGN_SESSION"],
		["generation", 0, "M403_STALE_GENERATION"], ["queue_id", "wrong", "M403_WRONG_QUEUE"],
		["expected_revision", -1, "M403_STALE_REVISION"]]:
		begin("Protocol precedence and whole-root rejection: " + spec[0])
		var e = fresh()
		var r: Dictionary = request(e)
		r[spec[0]] = spec[1]
		observe(e, "advance", r, authority, spec[2], "REJECTED", true)
		end()
	for cap in [null, RefCounted.new(), true, 1, "cap", [], {}]:
		begin("Missing/foreign capability rejected before queue/revision domain")
		var e = fresh()
		var r: Dictionary = request(e)
		r.queue_id = "wrong"
		r.expected_revision = -1
		observe(e, "advance", r, cap, "M403_UNAUTHORIZED", "REJECTED", true)
		observe(e, "restart", reset_request(e, fixture()), cap, "M403_UNAUTHORIZED", "REJECTED", true)
		end()
	begin("Earlier gates dominate combinations deterministically; foreign instance cannot authorize")
	var e = fresh()
	var other = fresh()
	observe(e, "advance", request(other), authority, "M403_FOREIGN_SESSION", "REJECTED", true)
	var r: Dictionary = request(e)
	r.generation = 0
	r.queue_id = "wrong"
	observe(e, "advance", r, null, "M403_STALE_GENERATION", "REJECTED", true)
	r = request(e)
	r.queue_id = "wrong"
	r.expected_revision = -1
	observe(e, "advance", r, authority, "M403_WRONG_QUEUE", "REJECTED", true)
	end()
	begin("Uninitialized/absent owner fails closed")
	e = Encounter.new(authority)
	observe(e, "advance", request(e), authority, "M403_INVALID_PHASE", "REJECTED", true)
	e = Encounter.new()
	observe(e, "restart", reset_request(e, fixture()), null, "M403_UNAUTHORIZED", "REJECTED", true)
	end()


func _restart() -> void:
	begin("Atomic restart creates generation-bound identities, clears dispositions, preserves old detached history")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	var e = fresh(f)
	advance(e)
	var before: Dictionary = e.snapshot()
	var old_request: Dictionary = request(e)
	observe(e, "restart", reset_request(e, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
	var after: Dictionary = e.snapshot()
	check(after.session == before.session and after.generation == 2 and after.revision == 0, "session stable generation+1 revision0")
	check(after.queue.cursor == 0 and after.queue.dispositions.is_empty(), "fresh initial queue")
	check(after.queue.queue_id != before.queue.queue_id and after.queue.opportunities[0].slot_id != before.queue.opportunities[0].slot_id, "generation-bound queue/slot identity")
	observe(e, "advance", old_request, authority, "M403_STALE_GENERATION", "REJECTED", true)
	var old_reset: Dictionary = old_request.duplicate(true)
	old_reset.fixture = fixture()
	observe(e, "restart", old_reset, authority, "M403_STALE_GENERATION", "REJECTED", true)
	before.actors.p.state.current_hp = 9
	before.queue.dispositions.clear()
	check(e.snapshot() == after, "old copy cannot attach to reused actor IDs")
	end()
	for variant in range(25):
		begin("Invalid Restart variant%s retains complete root and legitimate queue opportunity" % variant)
		var seed: Dictionary = fixture()
		state(seed, "p", "DOWN", 0)
		e = fresh(seed)
		var invalid: Dictionary = fixture()
		match variant:
			0: invalid.extra = true
			1: invalid.erase("actors")
			2: invalid.actors = []
			3: invalid.actors.append(invalid.actors[0].duplicate(true))
			4: invalid.actors[0].definition.role = "NPC"
			5:
				invalid.actors = invalid.actors.slice(0, 4)
				for row in invalid.round_plan: row.actor_order = ["p", "n1", "n2", "n3"]
			6: invalid.actors[-1].state.current_hp = -1
			7: state(invalid, "n3", "ALIVE", 0)
			8: state(invalid, "n3", "DOWN", 1)
			9: state(invalid, "n3", "DOWN", 0, "RETREATED")
			10: invalid.round_plan = []
			11: invalid.round_plan[0].actor_order.append("p")
			12: invalid.round_plan[1].actor_order.reverse()
			13: invalid.round_plan[0].actor_order[0] = "unregistered"
			14: invalid.round_plan[1].round_id = 3
			15: invalid.round_plan[1].round_id = 5
			16: invalid.round_plan[0].round_id = 3.0
			17: invalid.actors[-1].definition.actor_id = "n3"
			18: invalid.actors[-1].definition.actor_id = "m403/queue/forged"
			19: invalid.actors[-1].definition.base_max_hp = true
			20: invalid.actors[-1].state.current_hp = 1.0
			21: invalid.actors[-1].state.life_state = "DEAD"
			22: invalid.round_plan[-1] = "bad final plan row"
			23: invalid.actors[1].definition.role = "PLAYER"
			24:
				invalid.round_plan[0].erase("actor_order")
				invalid.round_plan[0].unknown = []
		var unchanged: Dictionary = invalid.duplicate(true)
		observe(e, "restart", reset_request(e, invalid), authority, "M403_INVALID_RESTART", "REJECTED", true)
		check(invalid == unchanged, "rejected fixture input unchanged")
		advance(e)
		check(e.current_opportunity().actor_id == "n1", "original valid advance still works")
		end()
	begin("Restart envelope obeys strict schema/type/revision before fixture validation")
	e = fresh()
	for field in Encounter.REQUEST_FIELDS + ["fixture"]:
		var r: Dictionary = reset_request(e, fixture())
		r.erase(field)
		observe(e, "restart", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
	var r: Dictionary = reset_request(e, fixture())
	r.fixture = []
	observe(e, "restart", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
	r = reset_request(e, {})
	r.expected_revision = -1
	observe(e, "restart", r, authority, "M403_STALE_REVISION", "REJECTED", true)
	end()


func _candidate_receipts() -> void:
	for variant in range(18):
		begin("Detached candidate validator/publication fault%s is N-all; no test receipt producer" % variant)
		var f: Dictionary = fixture()
		state(f, "p", "DOWN", 0)
		var e = fresh(f)
		var before: Dictionary = e.snapshot()
		var c: Dictionary = Adapter.unavailable_candidate(before)
		match variant:
			0: c.queue.opportunities.append(c.queue.opportunities[0].duplicate(true))
			1: c.queue.cursor = -1
			2: c.queue.cursor = 7
			3: c.queue.cursor = 1.0
			4: c.queue.opportunities[0].actor_id = "unknown"
			5: c.initial_party.reverse()
			6: c.action_receipts.fake = {"completed": true}
			7: c.active_operation = {"action_id": 1}
			8: c.phase = "SEALED"
			9: c.phase = "CLOSED"
			10: c.queue.phase = "SUSPENDED"
			11: c.actors.p.state.eligible = true
			12: c.queue.dispositions[c.queue.opportunities[0].opportunity_id].kind = "COMPLETED"
			13: c.queue.dispositions[c.queue.opportunities[0].opportunity_id].observed_revision = true
			14: c.actors.p.membership = 3
			15: c.queue.opportunities[0].actor_id = 1
			16: c.queue.opportunities[0] = null
			17: c.initial_enemies = [true]
		check(not e._valid_candidate(c), "complete candidate rejected by defensive validator")
		check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "internal final publication gate rejects")
		check(e.snapshot() == before, "candidate failure N-all")
		advance(e)
		end()
	begin("Valid-shaped candidate cannot bypass monotonic transition or mutate live actors/roster")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	var e = fresh(f)
	var before: Dictionary = e.snapshot()
	var c: Dictionary = Adapter.unavailable_candidate(before)
	c.actors.n1.state.current_hp = 7
	check(e._valid_candidate(c), "structurally valid actor state for transition test")
	check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "transition forbids unrelated actor delta")
	check(e.snapshot() == before, "unrelated actor change N-all")
	advance(e)
	check(e._publish(before, 1) == "M403_INVALID_CANDIDATE", "no rewind by importing earlier candidate")
	check(e._publish(Adapter.unavailable_candidate(before), 0) == "M403_STALE_REVISION", "final stale gate before candidate checks")
	end()
	begin("Caller fake receipt/action/slot keys rejected without reserving current/future names")
	e = fresh()
	for key in ["receipt", "action_receipts", "completion", "operation_id", "slot_id", "cursor"]:
		var r: Dictionary = request(e)
		r[key] = {"slot_3_p": true, "slot_4_p": true}
		observe(e, "advance", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
	advance(e, "M403_SLOT_READY", "READY", true)
	for method in ["impact", "complete", "seal", "close", "open_round", "next_round", "abort", "lock_self_retreat", "import_receipt", "classify"]:
		check(not e.has_method(method), "deferred API absent: " + method)
	check(e.snapshot().action_receipts.is_empty() and e.snapshot().authorizations.is_empty(), "no fake receipt/grant even after denied import")
	end()


func _diagnostics() -> void:
	for reason in ["M403_NO_REAL_PROGRESS", "M403_PLAN_EXHAUSTED"]:
		begin("Pure diagnostic predicate only: " + reason + "; full M403-44 deferred")
		var e = fresh()
		var before: Dictionary = e.snapshot()
		var facts: Dictionary = {"round_phase": "OPEN" if reason == "M403_NO_REAL_PROGRESS" else "CLOSED",
			"queue_phase": "DRAINED", "pending": false, "completed_actions": 0,
			"active_party": 1, "active_enemies": 1, "has_next_round": false}
		var input: Dictionary = facts.duplicate(true)
		for i in range(3):
			check(Adapter.progress_diagnostic(facts) == {"progress_status": "SUSPENDED", "suspension_reason": reason}, "repeat pure predicate result")
		check(facts == input and e.snapshot() == before, "synthetic facts never imported into authority")
		facts.pending = true
		check(Adapter.progress_diagnostic(facts).progress_status == "FOUNDATION_ONLY", "legitimate pending work is not suspended")
		facts.pending = false
		facts.active_party = 0
		check(Adapter.progress_diagnostic(facts).progress_status == "FOUNDATION_ONLY", "does not diagnose terminal-looking data as nonterminal")
		current.steps.append({"kind": "PURE_PREDICATE_NOT_GAMEPLAY", "input": input, "expected_reason": reason,
			"actual": Adapter.progress_diagnostic(input), "before": before, "after": e.snapshot()})
		end()
	begin("Progress diagnostic validation, legitimate pending opportunity and repeated reads never publish")
	var e = fresh()
	var before: Dictionary = e.snapshot()
	for i in range(3):
		check(e.progress_diagnostic() == {"progress_status": "FOUNDATION_ONLY", "suspension_reason": ""}, "ready eligible actor is legitimate work")
	check(Adapter.progress_diagnostic({}).progress_status == "INVALID", "malformed diagnostic rejected")
	check(e.snapshot() == before and e.queue_snapshot().phase == "READY", "diagnostics are never stored phases/revisions")
	end()


func _run() -> void:
	_eligibility()
	_identity_cursor()
	_protocol()
	_restart()
	_candidate_receipts()
	_diagnostics()
	var report: Dictionary = {"suite": "M4-03A queue foundation", "independent_cases": cases.size(),
		"assertion_checks": checks, "failures": failures, "per_frame_checks": 0, "cases": cases,
		"deferred": ["M403-44 seal/open-next end-to-end", "legal SEALED Abort/Restart", "actual completion producer B/C",
			"effect/action callbacks", "terminal/outcome/summary", "M402-06 end-to-end", "M402-24 full integration"]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file == null:
				print("FAIL: cannot write report")
				quit(1)
				return
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RESULT: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
