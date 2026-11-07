extends SceneTree

const Encounter = preload("res://scripts/m4/m403_terminal_encounter.gd")
const A = preload("res://scripts/m4/isolated_queue_outcome_encounter.gd")
const B = preload("res://scripts/m4/m403_effect_candidates.gd")
const Rules = preload("res://scripts/m4/m403_terminal_rules.gd")
const Classifier = preload("res://scripts/m4/m403_outcome_classifier.gd")
const Summary = preload("res://scripts/m4/m403_summary.gd")

# Faults reject a fully calculated candidate; they never mutate the live root.
class FaultEncounter:
	extends "res://scripts/m4/m403_terminal_encounter.gd"
	var fault: String = ""

	func _valid_candidate(c: Variant) -> bool:
		if fault.is_empty(): return super._valid_candidate(c)
		var bad: Dictionary = c.duplicate(true)
		match fault:
			"missing": bad.summary.party_lifecycle_rows.pop_back()
			"duplicate": bad.summary.enemy_combat_rows[0].actor_id = bad.initial_party[0]
			"generation": bad.summary.generation += 1
			"freeze": bad.outcome.freeze_revision += 1
			"clock": bad.clocks.p.budget = 2
			"receipt": bad.action_receipts.fake = {}
		return super._valid_candidate(bad)

# Diagnostic final revision-gate fault, not a live mutation/concurrent writer.
class StaleCloseEncounter:
	extends "res://scripts/m4/m403_terminal_encounter.gd"
	var stale_close: bool = false

	func _publish(candidate: Variant, expected_revision: int, resetting: bool = false,
		operation: String = "UNAVAILABLE", payload: Dictionary = {}) -> String:
		return super._publish(candidate, expected_revision - int(stale_close and operation == "CLOSE"), resetting, operation, payload)

var authority := RefCounted.new()
var cases: Array = []
var checks: int = 0
var failures: int = 0
var current: Dictionary = {}
var start_checks: int = 0
var start_failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	current.assertions.append({"description": description, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL: %s %s" % [current.id, description])


func begin(description: String) -> void:
	start_checks = checks
	start_failures = failures
	current = {"id": "M403C-%02d" % (cases.size() + 1), "expected": description, "steps": [], "assertions": []}


func end() -> void:
	current.assertion_count = checks - start_checks
	current.failure_count = failures - start_failures
	current.actual = "PASS" if current.failure_count == 0 else "FAIL"
	cases.append(current)
	print("CASE %s: %s" % [current.id, current.actual])


func fixture(rounds: int = 3, ids: Array = ["p", "n", "t", "a"]) -> Dictionary:
	var rows: Array = []
	for id in ids:
		var role: String = "PLAYER" if id == "p" else ("ENEMY" if id.begins_with("a") else "NPC")
		rows.append({"definition": {"actor_id": id, "display_name": id, "role": role, "base_max_hp": 100},
			"state": {"current_hp": 100} if role == "ENEMY" else {"current_hp": 100, "life_state": "ALIVE", "participation": "PRESENT"}})
	var plan: Array = []
	for i in range(rounds): plan.append({"round_id": 3 + i, "actor_order": ids.duplicate()})
	return {"actors": rows, "round_plan": plan, "clocks": {}}


func state(f: Dictionary, id: String, life: String, hp: int, participation: String = "PRESENT") -> void:
	for row in f.actors:
		if row.definition.actor_id == id:
			row.state = {"current_hp": hp} if row.definition.role == "ENEMY" else \
				{"current_hp": hp, "life_state": life, "participation": participation}


func request(e, round_request: bool = false, next: bool = false) -> Dictionary:
	var s: Dictionary = e.snapshot()
	var r: Dictionary = {"version": 1, "session": s.session, "generation": s.generation,
		"expected_revision": s.revision, "queue_id": s.queue.get("queue_id", "")}
	if round_request: r.round_id = s.round_id + int(next)
	return r


func reset_request(e, f: Dictionary) -> Dictionary:
	var r: Dictionary = request(e)
	r.fixture = f.duplicate(true)
	return r


func call_checked(e, method: String, input: Variant, reason: String, status: String = "REJECTED",
	cap: Variant = null, no_delta: bool = true) -> Dictionary:
	var before: Dictionary = e.snapshot()
	var with_cap: bool = method in ["restart", "open_round", "advance", "seal", "authorize_abort",
		"lock_self_retreat", "lock_fixture_attack", "lock_fixture_rescue"]
	var result: Dictionary = e.call(method, input, cap) if with_cap else e.call(method, input)
	var after: Dictionary = e.snapshot()
	check(result.reason_code == reason, "%s reason expected %s actual %s" % [method, reason, result])
	check(result.status == status, "exact status " + status)
	if no_delta: check(before == after, "N-all entire root incl journal/serial/resources/summary")
	else:
		check(after.revision == (0 if method == "restart" else before.revision + 1), "at most one root publication")
		check(after.generation == before.generation + int(method == "restart"), "generation changes only on Restart")
		check(e._valid_candidate(after), "all domains + global revision/event replay validate")
		check(after.journal.size() == after.revision, "global event count independent of cursor/action ledger")
		if method in ["complete", "cancel", "seal", "open_round", "authorize_abort", "abort"]:
			check(after.actors == before.actors, "N-effect actor state for accounting/boundary")
		if not before.outcome.is_empty() and method != "restart":
			check(after.outcome == before.outcome and after.summary == before.summary, "frozen result and freeze revision immutable")
	current.steps.append({"method": method, "input": input.duplicate(true) if input is Dictionary else input,
		"expected_reason": reason, "expected_status": status, "N_all": no_delta, "actual": result,
		"before": before, "after": after})
	return result


func fresh(f: Dictionary = fixture(), admitted: bool = true, e = null):
	if e == null: e = Encounter.new(authority)
	call_checked(e, "restart", reset_request(e, f), "M403_RESTARTED", "APPLIED", authority, false)
	if admitted:
		call_checked(e, "open_round", request(e, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	return e


func lock_request(e, kind: String, target: String = "", amount: int = 1, id: String = "") -> Dictionary:
	var r: Dictionary = request(e)
	var slot: Dictionary = e.current_opportunity()
	r.merge({"actor_id": slot.get("actor_id", ""), "slot_id": slot.get("slot_id", ""), "kind": kind,
		"request_id": id if not id.is_empty() else "request_%s" % r.expected_revision})
	if kind != "RETREAT": r.target_id = target
	if kind == "ATTACK": r.amount = amount
	return r


func lock(e, kind: String, target: String = "", amount: int = 1) -> Dictionary:
	var method: String = "lock_self_retreat" if kind == "RETREAT" else "lock_fixture_" + kind.to_lower()
	var result: Dictionary = call_checked(e, method, lock_request(e, kind, target, amount),
		"M403_RETREAT_LOCKED" if kind == "RETREAT" else "M403_ACTION_LOCKED", "AUTHORIZED", authority, false)
	return result.get("token", {})


func impact_complete(e, token: Dictionary, reason: String = "M403_FIXTURE_DAMAGE", status: String = "APPLIED") -> void:
	call_checked(e, "impact", token, reason, status, null, false)
	call_checked(e, "complete", token, "M403_ACTION_COMPLETED", "APPLIED", null, false)


func advance(e) -> void:
	call_checked(e, "advance", request(e), "M403_SLOT_UNAVAILABLE", "APPLIED", authority, false)


func drain(e, real: bool = true) -> void:
	# Bounded by initial roster, never auto-generates rounds or inserts a Player command.
	var count: int = e.snapshot().initial_party.size() + e.snapshot().initial_enemies.size()
	for _i in range(count):
		var slot: Dictionary = e.current_opportunity()
		if slot.is_empty(): break
		var v: Dictionary = e.snapshot()
		if not Rules.Queue.actionable(v.actors[slot.actor_id]):
			advance(e)
			continue
		var target: String = v.initial_enemies[0] if slot.actor_id in v.initial_party else v.declarations[slot.actor_id]
		var token: Dictionary = lock(e, "ATTACK", target)
		if real:
			var reason: String = "M403_FIXTURE_DAMAGE" if Rules.Queue.actionable(v.actors[target]) else "M403_TARGET_UNAVAILABLE"
			impact_complete(e, token, reason, "APPLIED" if reason == "M403_FIXTURE_DAMAGE" else "SKIPPED")
		else: call_checked(e, "cancel", token, "M403_ACTION_CANCELLED", "APPLIED", null, false)
	check(e.queue_snapshot().phase == "DRAINED", "finite queue drained through owned work/dispositions")


func seal_close(e) -> Dictionary:
	var result: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false)
	return call_checked(e, "close", result.get("event", {}), "M403_ROUND_CLOSED", "APPLIED", null, false)


func abort_grant(e) -> Dictionary:
	var r: Dictionary = request(e, true)
	r.merge({"kind": "ABORT", "request_id": "abort_%s" % r.expected_revision})
	return call_checked(e, "authorize_abort", r, "M403_ABORT_AUTHORIZED", "AUTHORIZED", authority, false).get("token", {})


func identity(e) -> Dictionary:
	var v: Dictionary = e.snapshot()
	return {"version": 1, "session": v.session, "generation": v.generation, "outcome_id": v.outcome.get("outcome_id", "")}


func _architecture() -> void:
	begin("C51-ARCH-01 opt-in surface; initial identity preparation is not admission")
	var e = fresh(fixture(), false)
	check(not A.new(authority).has_method("seal") and not B.new(authority).has_method("open_round"), "no C API leak into A/B")
	check(not e.eligibility_snapshot("p").queue_opportunity_available, "prepared Player slot cannot issue a command")
	call_checked(e, "lock_fixture_attack", lock_request(e, "ATTACK", "a"), "M403_INVALID_PHASE", "REJECTED", authority)
	call_checked(e, "open_round", request(e, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	check(e.eligibility_snapshot("p").queue_opportunity_available, "actual admission grants only current opportunity")
	var token: Dictionary = lock(e, "ATTACK", "a")
	var grant: Dictionary = abort_grant_attempt(e)
	check(grant.status == "REJECTED", "pending action blocks grant issuance")
	impact_complete(e, token)
	check(e.snapshot().revision > e.queue_snapshot().cursor, "global revision distinct from action/cursor")
	end()
	for phase in ["SUSPENDED", "CLOSED", "SEALED", "ABORTED", "BROKEN"]:
		begin("C51-ARCH-01 forged phase " + phase + " rejects whole candidate")
		e = fresh()
		var before: Dictionary = e.snapshot()
		var bad: Dictionary = before.duplicate(true)
		bad.phase = phase
		check(not e._valid_candidate(bad), "unwitnessed phase rejected by full replay")
		check(e._publish(bad, before.revision, false, "ADVANCE", request(e)) == "M403_INVALID_CANDIDATE", "publication refuses phase import")
		check(e.snapshot() == before, "whole root unchanged")
		end()
	begin("C51-ARCH-01 larger finite roster is not capped to production example")
	var ids: Array = ["p", "n", "n_two", "n_three", "n_four", "a", "a_two", "a_three"]
	e = fresh(fixture(1, ids))
	check(e.queue_snapshot().opportunities.size() == ids.size(), "all larger-roster opportunities retained")
	drain(e)
	seal_close(e)
	check(e.snapshot().round_index == 0 and e.snapshot().phase == "CLOSED", "legitimate multi-actor close")
	end()


func abort_grant_attempt(e) -> Dictionary:
	var r: Dictionary = request(e, true)
	r.merge({"kind": "ABORT", "request_id": "pending_abort"})
	return call_checked(e, "authorize_abort", r, "M403_ACTION_IN_PROGRESS", "REJECTED", authority)


func _classifier() -> void:
	var branches: Array = [
		["ACTIVE", "M403_CONTINUE", "DOWN", "PRESENT", 100],
		["VICTORY", "M403_ENEMIES_UNAVAILABLE", "DOWN", "PRESENT", 0],
		["PARTY_RETREAT", "M403_ALL_PARTY_RETREATED", "ALIVE", "RETREATED", 100],
		["MIXED_WITHDRAWAL", "M403_ESCAPED_WITH_LEFT_BEHIND", "DOWN", "RETREATED", 100],
		["DEFEAT", "M403_MUTUAL_INCAPACITATION", "DOWN", "PRESENT", 0],
		["DEFEAT", "M403_NO_ACTIVE_PARTY", "DOWN", "PRESENT", 100]]
	for i in range(branches.size()):
		begin("D10-A pure precedence branch %s plus legal initial admission boundary" % (i + 1))
		var spec: Array = branches[i]
		var f: Dictionary = fixture()
		if i == 0: state(f, "p", "DOWN", 0)
		elif i == 1: state(f, "n", "DOWN", 0)
		elif i == 2:
			for id in ["p", "n", "t"]: state(f, id, "ALIVE", 10, "RETREATED")
		else:
			for id in ["p", "n", "t"]: state(f, id, "DOWN", 0)
			if i == 3: state(f, "p", "ALIVE", 10, "RETREATED")
		state(f, "a", "", spec[4])
		var e = fresh(f, false)
		var before: Dictionary = e.snapshot()
		var classified: Dictionary = Classifier.classify(before)
		check(classified == {"status": "CLASSIFIED", "encounter_outcome": spec[0], "reason_code": spec[1]}, "exact six-branch outcome/reason")
		check(e.snapshot() == before, "pure classification N-all")
		current.steps.append({"kind": "DETACHED_CLASSIFIER_NOT_SIMULTANEOUS_DAMAGE", "input": before, "actual": classified})
		call_checked(e, "open_round", request(e, true), "M403_ROUND_OPENED" if i == 0 else "M403_OUTCOME_FROZEN", "APPLIED", authority, false)
		if i > 0:
			check(e.snapshot().phase == "ABORTED" and e.snapshot().summary == Summary.build(e.snapshot()), "initial terminal freeze has complete same-root summary")
			check(e.snapshot().actors == before.actors and e.snapshot().clocks == before.clocks, "no auto rescue/death/tick")
		end()
	for kind in ["PARTY_RETREAT", "MIXED_WITHDRAWAL", "ALL_DEAD"]:
		begin("Detached/seeded terminal precedence edge " + kind + "; no simultaneous damage claim")
		var f: Dictionary = fixture()
		for id in ["p", "n", "t"]:
			state(f, id, "DEAD" if kind == "ALL_DEAD" else "ALIVE", 0 if kind == "ALL_DEAD" else 10, "PRESENT" if kind == "ALL_DEAD" else "RETREATED")
		if kind == "MIXED_WITHDRAWAL":
			state(f, "n", "DOWN", 0)
			state(f, "t", "DEAD", 0)
		if kind != "ALL_DEAD": state(f, "a", "", 0)
		var e = fresh(f, false)
		var classified: Dictionary = Classifier.classify(e.snapshot())
		check(classified.encounter_outcome == ("DEFEAT" if kind == "ALL_DEAD" else kind), "withdrawal beats mutual even E0; all-DEAD is no-active defeat")
		call_checked(e, "open_round", request(e, true), "M403_OUTCOME_FROZEN", "APPLIED", authority, false)
		check(e.snapshot().summary == Summary.build(e.snapshot()), "all initial DOWN/DEAD/RETREATED rows retained")
		end()

	for variant in range(8):
		begin("Malformed complete classifier roster rejected variant %s" % variant)
		var e = fresh()
		var bad: Dictionary = e.snapshot()
		match variant:
			0: bad.initial_party = []
			1: bad.initial_enemies = []
			2: bad.initial_party.append("p")
			3: bad.actors.erase("t")
			4: bad.actors.a.state.life_state = "DEAD"
			5: bad.actors.n.state.current_hp = -1
			6: bad.initial_enemies.append("p")
			7: bad.actors.p.definition.role = "NPC"
		var before: Dictionary = e.snapshot()
		check(Classifier.classify(bad) == {"status": "REJECTED", "reason_code": "M403_INVALID_ROSTER"}, "empty/malformed is never victory")
		check(e.snapshot() == before, "pure invalid input cannot publish")
		end()


func terminal_setup(kind: String, e = null) -> Dictionary:
	var f: Dictionary = fixture()
	var t: Dictionary
	if kind == "VICTORY":
		state(f, "n", "DOWN", 0)
		state(f, "t", "DEAD", 0)
		state(f, "a", "", 1)
		e = fresh(f, true, e)
		t = lock(e, "ATTACK", "a", 5)
	elif kind == "MIXED_WITHDRAWAL":
		state(f, "n", "DOWN", 0)
		state(f, "t", "DEAD", 0)
		e = fresh(f, true, e)
		t = lock(e, "RETREAT")
	elif kind == "PARTY_RETREAT":
		e = fresh(f, true, e)
		for _i in range(2): impact_complete(e, lock(e, "RETREAT"), "M403_RETREATED")
		t = lock(e, "RETREAT")
	else:
		state(f, "p", "DOWN", 0)
		state(f, "t", "DOWN", 0)
		e = fresh(f, true, e)
		advance(e)
		impact_complete(e, lock(e, "ATTACK", "a"))
		advance(e)
		t = lock(e, "ATTACK", "n", 100)
	return {"encounter": e, "token": t}


func _atomic_terminal() -> void:
	for kind in ["VICTORY", "MIXED_WITHDRAWAL", "PARTY_RETREAT", "DEFEAT"]:
		begin("Legal effect-triggered " + kind + ": atomic freeze and one causal settlement")
		var setup: Dictionary = terminal_setup(kind)
		var e = setup.encounter
		var t: Dictionary = setup.token
		var before: Dictionary = e.snapshot()
		call_checked(e, "complete", t, "M403_INVALID_PHASE")
		call_checked(e, "impact", t, "M403_FIXTURE_DAMAGE" if kind == "VICTORY" else ("M403_DOWN_ENTERED" if kind == "DEFEAT" else "M403_RETREATED"), "APPLIED", null, false)
		var frozen: Dictionary = e.snapshot()
		check(frozen.outcome.encounter_outcome == kind and frozen.outcome.cause == "IMPACT", "effect producer determines expected terminal")
		check(frozen.outcome.freeze_revision == before.revision + 1 and frozen.summary.freeze_revision == frozen.outcome.freeze_revision,
			"effect/outcome/summary same single publication revision")
		check(frozen.phase == "ABORTED" and frozen.queue.phase == "TERMINAL_SETTLING", "OPEN terminal is ABORTED with settlement lane")
		check(frozen.event_consumed.is_empty() and frozen.clocks == before.clocks if kind != "DEFEAT" else frozen.event_consumed.is_empty(), "no natural close or bleed tick on terminal impact")
		check(frozen.summary.party_lifecycle_rows.size() == frozen.initial_party.size() and frozen.summary.enemy_combat_rows.size() == frozen.initial_enemies.size(), "full separate initial roster summary")
		check(frozen.summary.size() == 11 and frozen.summary.domain == "M403_ISOLATED_SUMMARY", "exact summary envelope11")
		for row in frozen.summary.party_lifecycle_rows:
			check(row.size() == 7 and row.final_down == frozen.clocks.get(row.actor_id, {}), "Party row7 retains matching final episode")
		for row in frozen.summary.enemy_combat_rows:
			check(row.size() == 4 and row.availability == ("AVAILABLE" if row.current_hp > 0 else "UNAVAILABLE"), "Enemy row4 HP availability; no lifecycle/death mapping")
		check(frozen.terminal_stops.size() == frozen.queue.opportunities.size() - frozen.queue.cursor - 1, "remainder stopped as terminal accounting, no fake completion")

		call_checked(e, "impact", t, "M403_DUPLICATE_OPERATION")
		call_checked(e, "cancel", t, "M403_OUTCOME_FROZEN")
		call_checked(e, "seal", request(e, true), "M403_OUTCOME_FROZEN", "REJECTED", authority)
		call_checked(e, "lock_self_retreat", lock_request(e, "RETREAT"), "M403_OUTCOME_FROZEN", "REJECTED", authority)
		call_checked(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED", null, false)
		check(e.snapshot().active_operation == null and e.queue_snapshot().phase == "STOPPED", "causal completion clears outstanding once")
		check(e.snapshot().action_receipts.has(t.action_id) and e.snapshot().action_receipts.size() == frozen.action_receipts.size() + 1, "one genuine receipt")
		check(e.snapshot().summary == frozen.summary and e.snapshot().outcome == frozen.outcome, "live revision advances; freeze identity/reason/summary unchanged")
		call_checked(e, "complete", t, "M403_DUPLICATE_OPERATION")
		var result: Dictionary = call_checked(e, "summary_snapshot", identity(e), "M403_OUTCOME_FROZEN", "FROZEN")
		result.summary.party_lifecycle_rows[0].current_hp = -5
		result.summary.party_lifecycle_rows.reverse()
		result.outcome.freeze_revision = -1
		check(e.summary_snapshot(identity(e)).summary == frozen.summary, "deep-copy result mutation cannot change frozen record")
		call_checked(e, "summary_snapshot", identity(e), "M403_OUTCOME_FROZEN", "FROZEN")
		var bad_fixture: Dictionary = fixture()
		bad_fixture.actors[-1].state.current_hp = -1
		call_checked(e, "restart", reset_request(e, bad_fixture), "M403_INVALID_RESTART", "REJECTED", authority)
		var old_identity: Dictionary = identity(e)
		call_checked(e, "restart", reset_request(e, fixture()), "M403_RESTARTED", "APPLIED", authority, false)
		call_checked(e, "summary_snapshot", old_identity, "M403_STALE_GENERATION")
		for method in ["impact", "complete", "cancel"]: call_checked(e, method, t, "M403_STALE_GENERATION")
		call_checked(e, "summary_snapshot", identity(e), "M403_SUMMARY_NOT_FROZEN", "ABSENT")
		end()
	for fault in ["missing", "duplicate", "generation", "freeze"]:
		begin("Invalid terminal summary/outcome candidate " + fault + " rejects effect and freeze atomically")
		var setup: Dictionary = terminal_setup("VICTORY", FaultEncounter.new(authority))
		var e = setup.encounter
		e.fault = fault
		call_checked(e, "impact", setup.token, "M403_INVALID_CANDIDATE")
		e.fault = ""
		check(e.snapshot().outcome.is_empty() and e.actor_snapshot("a").state.current_hp == 1, "no partial HP/outcome/summary visibility")
		impact_complete(e, setup.token)
		end()
	begin("B-only last-active and zero-enemy restrictions remain; C terminal seeds cannot issue actions")
	for boundary in ["last", "zero"]:
		var f: Dictionary = fixture()
		f.erase("clocks")
		if boundary == "last":
			state(f, "n", "DOWN", 0)
			state(f, "t", "DEAD", 0)
		else: state(f, "a", "", 0)
		var e = B.new(authority)
		# Original B root is intentionally checked through its own unchanged API.
		var before: Dictionary = e.snapshot()
		var result: Dictionary = e.restart(reset_request(e, f), authority)
		check(result.reason_code == "M403_RESTARTED", "original B fixture valid")
		before = e.snapshot()
		result = e.lock_self_retreat(lock_request(e, "RETREAT"), authority)
		check(result.reason_code == "M403_BOUNDARY_DEPENDENCY" and e.snapshot() == before, "original R51-01/last-active gate N-all")
	end()


func _continuation() -> void:
	begin("Player DOWN before admission: NPC RESCUE; no duplicate Player opportunity; next finite round only")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	var e = fresh(f)
	check(not e.eligibility_snapshot("p").actor_actionable, "Player DOWN has no slot/command eligibility")
	call_checked(e, "lock_fixture_attack", lock_request(e, "ATTACK", "a"), "M403_ACTOR_UNAVAILABLE", "REJECTED", authority)
	call_checked(e, "summary_snapshot", identity(e), "M403_SUMMARY_NOT_FROZEN", "ABSENT")
	advance(e)
	var historical: Dictionary = e.queue_snapshot().dispositions.duplicate(true)
	var t: Dictionary = lock(e, "RESCUE", "p")
	check(t.episode_id == e.snapshot().clocks.p.episode_id, "RESCUE binds exact live episode")
	call_checked(e, "seal", request(e, true), "M403_ROUND_NOT_CLOSABLE", "REJECTED", authority)
	call_checked(e, "lock_fixture_attack", lock_request(e, "ATTACK", "a"), "M403_ACTION_IN_PROGRESS", "REJECTED", authority)
	impact_complete(e, t, "M403_RESCUED")
	check(e.actor_snapshot("p").state.current_hp == 1 and e.actor_snapshot("p").state.life_state == "ALIVE", "legitimate HP0→1 rescue")
	check(not e.snapshot().clocks.p.active and e.snapshot().rescue_uses.n == 0, "episode retired and separate helper use consumed once")
	check(not e.eligibility_snapshot("p").slot_eligible and e.current_opportunity().actor_id == "t", "old Player slot never reinserted")
	for id in historical: check(e.queue_snapshot().dispositions[id] == historical[id], "unavailable historical observation retained after revival")
	# Avoid hitting the newly rescued HP1 Player: cancel the legitimate declared Enemy slot.
	impact_complete(e, lock(e, "ATTACK", "a"))
	call_checked(e, "cancel", lock(e, "ATTACK", "n"), "M403_ACTION_CANCELLED", "APPLIED", null, false)
	seal_close(e)
	check(e.actor_snapshot("p").state.current_hp == 1 and not e.snapshot().clocks.p.active, "retired episode never ticks on close")
	call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	check(e.current_opportunity().actor_id == "p" and e.eligibility_snapshot("p").queue_opportunity_available, "Player next chance only newly admitted Q4")
	check(e.snapshot().rescue_uses.n == 0, "opening round never resets rescue uses")
	check(e.snapshot().round_history[0].queue.dispositions.values()[0].observed_actor.state.life_state == "DOWN", "prior-round DOWN observation survives current ALIVE")
	end()
	begin("Enemy causes Player DOWN during its real slot; eligible NPC acts next round without Player proxy")
	e = fresh()
	# Real party effects first, followed by Enemy lethal Player impact.
	for _i in range(3): impact_complete(e, lock(e, "ATTACK", "a"))
	impact_complete(e, lock(e, "ATTACK", "p", 100), "M403_DOWN_ENTERED")
	check(e.snapshot().outcome.is_empty() and e.actor_snapshot("p").state.life_state == "DOWN", "Player DOWN alone is nonterminal")
	seal_close(e)
	check(e.snapshot().clocks.p.budget == 2, "entry round grace retained")
	call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	advance(e)
	check(e.current_opportunity().actor_id == "n", "NPC own slot continues without Player command")
	impact_complete(e, lock(e, "ATTACK", "a"))
	check(e.actor_snapshot("p").state.life_state == "DOWN" and e.snapshot().action_receipts.size() == 5, "actual NPC receipt with Player still DOWN")
	end()
	begin("Admission Enemy declaration stays fixed; unavailable declared target produces owned SKIPPED completion")
	e = fresh()
	var declared: Dictionary = e.snapshot().declarations.duplicate(true)
	impact_complete(e, lock(e, "RETREAT"), "M403_RETREATED")
	for _i in range(2): impact_complete(e, lock(e, "ATTACK", "a"))
	check(e.current_opportunity().actor_id == "a" and e.snapshot().declarations == declared and declared.a == "p", "no mid-round Enemy target fallback")
	call_checked(e, "lock_fixture_attack", lock_request(e, "ATTACK", "n"), "M403_INVALID_TARGET", "REJECTED", authority)
	t = lock(e, "ATTACK", "p")
	var before: Dictionary = e.snapshot()
	call_checked(e, "impact", t, "M403_TARGET_UNAVAILABLE", "SKIPPED", null, false)
	check(e.snapshot().actors == before.actors, "SKIPPED effect cannot fake a hit")
	call_checked(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED", null, false)
	check(e.snapshot().action_receipts[t.action_id].impact_reason == "M403_TARGET_UNAVAILABLE", "real completed skip receipt; not a fake DEFEND")
	seal_close(e)
	end()


func _rounds_clocks() -> void:
	begin("Strict seal witness exact12 from real receipts/dispositions; close exact11 one batch per round")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	state(f, "t", "DOWN", 0)
	var e = fresh(f)
	for round_number in range(3):
		drain(e)
		var before: Dictionary = e.snapshot()
		var event: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false).event
		var sealed: Dictionary = e.snapshot()
		check(sealed.witness.size() == 12 and event.size() == 11, "exact approved witness12/event11")
		check(sealed.witness.action_receipts == Rules.receipt_set(before) and sealed.witness.dispositions == before.queue.dispositions, "only owned real ledger populates witness")
		check(sealed.actors == before.actors and sealed.clocks == before.clocks, "seal never ticks/effects")
		call_checked(e, "seal", request(e, true), "M403_INVALID_PHASE", "REJECTED", authority)
		call_checked(e, "open_round", request(e, true), "M403_INVALID_PHASE", "REJECTED", authority)
		call_checked(e, "advance", request(e), "M403_INVALID_PHASE", "REJECTED", authority)
		call_checked(e, "lock_fixture_attack", lock_request(e, "ATTACK", "a"), "M403_INVALID_PHASE", "REJECTED", authority)
		call_checked(e, "restart", reset_request(e, fixture()), "M403_INVALID_PHASE", "REJECTED", authority)
		var closed: Dictionary = call_checked(e, "close", event, "M403_ROUND_CLOSED", "APPLIED", null, false)
		check(closed.episodes.size() == 2, "both active episodes calculated in same batch")
		var expected: int = 2 - round_number
		check(e.snapshot().clocks.p.budget == expected and e.snapshot().clocks.t.budget == expected, "grace2 then tick1 then death0")
		check(e.snapshot().outcome.is_empty() and Classifier.classify(e.snapshot()).encounter_outcome == "ACTIVE", "post-close classifier consistency guard remains nonterminal")
		call_checked(e, "close", event, "M403_DUPLICATE_ROUND_CLOSED")
		if round_number < 2:
			call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	check(e.actor_snapshot("p").state.life_state == "DEAD" and e.actor_snapshot("t").state.life_state == "DEAD", "death retains both IDs HP0/PRESENT")
	check(not e.snapshot().clocks.p.active and e.snapshot().clocks.p.budget == 0, "dead episode inactive at zero")
	end()
	begin("Different episode budgets batch atomically; fresh DEAD rescue rejected; no repeated death")
	f = fixture(2)
	state(f, "p", "DOWN", 0)
	state(f, "t", "DOWN", 0)
	f.clocks = {"p": {"entry_round": 2, "budget": 1}, "t": {"entry_round": 2, "budget": 2}}
	e = fresh(f)
	drain(e)
	seal_close(e)
	check(e.snapshot().clocks.p.budget == 0 and e.snapshot().clocks.t.budget == 1, "one death and one tick in same close")
	call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	advance(e)
	call_checked(e, "lock_fixture_rescue", lock_request(e, "RESCUE", "p"), "M403_DEAD_NOT_RESCUABLE", "REJECTED", authority)
	impact_complete(e, lock(e, "RESCUE", "t"), "M403_RESCUED")
	# Rescued t was not skipped yet, so its original still-pending slot is legal.
	check(e.current_opportunity().actor_id == "t", "rescue never invents extra slot; undisposed original remains")
	impact_complete(e, lock(e, "ATTACK", "a"))
	impact_complete(e, lock(e, "ATTACK", "n"))
	var old_dead: Dictionary = e.snapshot().clocks.p.duplicate(true)
	var closed: Dictionary = seal_close(e)
	check(closed.episodes.is_empty() and e.snapshot().clocks.p == old_dead, "retired rescue/dead episodes do not tick or repeat death")
	end()
	begin("Rejected final batch candidate has N-all for every episode/event/phase")
	f = fixture()
	state(f, "p", "DOWN", 0)
	state(f, "t", "DOWN", 0)
	f.clocks = {"p": {"entry_round": 2, "budget": 2}, "t": {"entry_round": 2, "budget": 1}}
	e = fresh(f, true, FaultEncounter.new(authority))
	drain(e)
	var event: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false).event
	e.fault = "clock"
	call_checked(e, "close", event, "M403_INVALID_CANDIDATE")
	e.fault = ""
	check(e.snapshot().phase == "SEALED" and e.snapshot().event_consumed.is_empty(), "no partial batch publication or event consumption")
	call_checked(e, "close", event, "M403_ROUND_CLOSED", "APPLIED", null, false)
	end()
	begin("RESCUE use not refunded by new DOWN episode or new round")
	f = fixture()
	state(f, "p", "DOWN", 0)
	e = fresh(f)
	advance(e)
	impact_complete(e, lock(e, "RESCUE", "p"), "M403_RESCUED")
	var old_episode: String = e.snapshot().clocks.p.episode_id
	impact_complete(e, lock(e, "ATTACK", "a"))
	impact_complete(e, lock(e, "ATTACK", "n"))
	seal_close(e)
	call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	for _i in range(3): impact_complete(e, lock(e, "ATTACK", "a"))
	impact_complete(e, lock(e, "ATTACK", "p"), "M403_DOWN_ENTERED")
	check(e.snapshot().clocks.p.episode_id != old_episode and e.snapshot().clocks.p.budget == 2, "fresh DOWN episode with new issuer identity")
	seal_close(e)
	call_checked(e, "open_round", request(e, true, true), "M403_ROUND_OPENED", "APPLIED", authority, false)
	advance(e)
	call_checked(e, "lock_fixture_rescue", lock_request(e, "RESCUE", "p"), "M403_RESCUE_EXHAUSTED", "REJECTED", authority)
	end()

	begin("DIAGNOSTIC ONLY final close revision-gate failure discards complete batch; no reseal")
	f = fixture()
	state(f, "p", "DOWN", 0)
	e = fresh(f, true, StaleCloseEncounter.new(authority))
	var ab: Dictionary = abort_grant(e)
	drain(e)
	var stale_event: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false).event
	e.stale_close = true
	call_checked(e, "close", stale_event, "M403_STALE_REVISION")
	e.stale_close = false
	call_checked(e, "seal", request(e, true), "M403_INVALID_PHASE", "REJECTED", authority)
	call_checked(e, "abort", ab, "M403_ABORTED", "APPLIED", null, false)
	call_checked(e, "restart", reset_request(e, fixture()), "M403_RESTARTED", "APPLIED", authority, false)
	end()


func _r49() -> void:
	begin("M403-44 V1 actual OPEN/DRAINED/nonterminal/zero completions: retry/diagnostic/stale all N-all")
	var e = fresh(fixture(1))
	drain(e, false)
	check(e.snapshot().action_receipts.is_empty() and e.snapshot().phase == "OPEN", "only real cancellations, no fabricated receipt")
	var r: Dictionary = request(e, true)
	for _i in range(2): call_checked(e, "seal", r, "M403_NO_REAL_PROGRESS", "REJECTED", authority)
	var before: Dictionary = e.snapshot()
	for _i in range(2):
		check(e.progress_diagnostic() == {"progress_status": "SUSPENDED", "suspension_reason": "M403_NO_REAL_PROGRESS"}, "read-only no-progress projection")
	check(e.snapshot() == before and e.queue_snapshot().phase == "DRAINED", "SUSPENDED never stored or published")
	var ab: Dictionary = abort_grant(e)
	call_checked(e, "seal", r, "M403_STALE_REVISION", "REJECTED", authority)
	check(e.snapshot().events.is_empty() and e.snapshot().event_consumed.is_empty(), "no fake seal/event/tick")
	call_checked(e, "abort", ab, "M403_ABORTED", "APPLIED", null, false)
	end()
	begin("M403-44 V2 actual final CLOSED/nonterminal/finite exhaustion: retry/diagnostic/stale all N-all")
	e = fresh(fixture(1))
	drain(e)
	var sealed: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false)
	var stale: Dictionary = request(e, true, true)
	call_checked(e, "close", sealed.event, "M403_ROUND_CLOSED", "APPLIED", null, false)
	r = request(e, true, true)
	for _i in range(2): call_checked(e, "open_round", r, "M403_PLAN_EXHAUSTED", "REJECTED", authority)
	before = e.snapshot()
	for _i in range(2):
		check(e.progress_diagnostic() == {"progress_status": "SUSPENDED", "suspension_reason": "M403_PLAN_EXHAUSTED"}, "read-only exhausted projection")
	check(e.snapshot() == before and e.snapshot().round_id == 3 and e.snapshot().semantic_closed.size() == 1, "no fake next-round identity/opportunity/clock")
	call_checked(e, "open_round", stale, "M403_STALE_REVISION", "REJECTED", authority)
	end()


func _abort_restart() -> void:
	for order in ["abort_first", "close_first"]:
		begin("SEALED owned Abort/Close serial ordering " + order)
		var e = fresh()
		var ab: Dictionary = abort_grant(e)
		drain(e)
		var event: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false).event
		call_checked(e, "authorize_abort", request(e, true), "M403_INVALID_FIELDS", "REJECTED", authority)
		call_checked(e, "restart", reset_request(e, fixture()), "M403_INVALID_PHASE", "REJECTED", authority)
		if order == "abort_first":
			var before: Dictionary = e.snapshot()
			call_checked(e, "abort", ab, "M403_ABORTED", "APPLIED", null, false)
			check(e.snapshot().phase == "ABORTED" and e.snapshot().queue.phase == "STOPPED", "Abort makes administrative frozen result")
			check(e.snapshot().clocks == before.clocks and e.snapshot().action_receipts == before.action_receipts and e.snapshot().event_consumed.is_empty(), "Abort never ticks or invents completion")
			call_checked(e, "close", event, "M403_INVALID_PHASE")
			call_checked(e, "abort", ab, "M403_DUPLICATE_OPERATION")
		else:
			call_checked(e, "close", event, "M403_ROUND_CLOSED", "APPLIED", null, false)
			call_checked(e, "abort", ab, "M403_INVALID_PHASE")
		call_checked(e, "restart", reset_request(e, fixture()), "M403_RESTARTED", "APPLIED", authority, false)
		call_checked(e, "abort", ab, "M403_STALE_GENERATION")
		call_checked(e, "close", event, "M403_STALE_GENERATION")
		end()
	for action_phase in ["LOCKED", "APPLIED", "SKIPPED"]:
		begin("Restart from genuine " + action_phase + " makes old callbacks stale; invalid restart preserves legitimate action")
		var e = fresh()
		var t: Dictionary
		if action_phase == "SKIPPED":
			impact_complete(e, lock(e, "RETREAT"), "M403_RETREATED")
			for _i in range(2): impact_complete(e, lock(e, "ATTACK", "a"))
			t = lock(e, "ATTACK", "p")
			call_checked(e, "impact", t, "M403_TARGET_UNAVAILABLE", "SKIPPED", null, false)
		else:
			t = lock(e, "ATTACK", "a")
			if action_phase == "APPLIED": call_checked(e, "impact", t, "M403_FIXTURE_DAMAGE", "APPLIED", null, false)
		var bad: Dictionary = fixture()
		bad.actors[-1].state.current_hp = -1
		call_checked(e, "restart", reset_request(e, bad), "M403_INVALID_RESTART", "REJECTED", authority)
		if action_phase == "LOCKED": call_checked(e, "impact", t, "M403_FIXTURE_DAMAGE", "APPLIED", null, false)
		call_checked(e, "restart", reset_request(e, fixture()), "M403_RESTARTED", "APPLIED", authority, false)
		for method in ["impact", "complete", "cancel"]: call_checked(e, method, t, "M403_STALE_GENERATION")
		end()
	begin("OPEN Abort with unimpacted LOCKED token cannot forge terminal completion")
	var e = fresh()
	var ab: Dictionary = abort_grant(e)
	var token: Dictionary = lock(e, "ATTACK", "a")
	var before: Dictionary = e.snapshot()
	call_checked(e, "abort", ab, "M403_ABORTED", "APPLIED", null, false)
	check(e.snapshot().action_receipts == before.action_receipts and e.snapshot().active_operation == null, "Abort invalidates outstanding token without receipt")
	for method in ["impact", "complete", "cancel"]: call_checked(e, method, token, "M403_OUTCOME_FROZEN")
	end()


func _security() -> void:
	for variant in range(15):
		begin("Exact request/authentication/domain rejection N-all variant %s" % variant)
		var e = fresh()
		var r: Dictionary = lock_request(e, "ATTACK", "a")
		var cap: Variant = authority
		var reason: String = "M403_INVALID_FIELDS"
		match variant:
			0: r.extra = true
			1: r.erase("actor_id")
			2: r.version = true
			3: r.version = 2
			4:
				r.session += 1
				reason = "M403_FOREIGN_SESSION"
			5:
				r.generation -= 1
				reason = "M403_STALE_GENERATION"
			6:
				cap = RefCounted.new()
				reason = "M403_UNAUTHORIZED"
			7:
				r.queue_id = "foreign"
				reason = "M403_WRONG_QUEUE"
			8:
				r.actor_id = "n"
				reason = "M403_WRONG_SLOT"
			9:
				r.expected_revision -= 1
				reason = "M403_STALE_REVISION"
			10:
				r.request_id = "slot_999_future"
				reason = "M403_RESERVED_OPERATION_ID"
			11:
				r.request_id = "m403/queue/future"
				reason = "M403_RESERVED_OPERATION_ID"
			12:
				r.target_id = "n"
				reason = "M403_INVALID_TARGET"
			13:
				r.amount = 0
				reason = "M403_INVALID_AMOUNT"
			14:
				r.amount = 9223372036854775807
				reason = "M403_INVALID_AMOUNT"
		call_checked(e, "lock_fixture_attack", r, reason, "REJECTED", cap)
		var t: Dictionary = lock(e, "ATTACK", "a")
		check(t.action_id == 1 and t.lock_revision == 1, "denial allocates no grant/id/ledger/revision")
		end()
	for variant in range(9):
		begin("Exact owned action token rejects forged/stale/replayed identity variant %s" % variant)
		var e = fresh()
		var r: Dictionary = lock_request(e, "ATTACK", "a")
		var t: Dictionary = call_checked(e, "lock_fixture_attack", r, "M403_ACTION_LOCKED", "AUTHORIZED", authority, false).token
		call_checked(e, "lock_fixture_attack", r, "M403_DUPLICATE_OPERATION", "REJECTED", authority)
		var bad: Dictionary = t.duplicate(true)
		var reason: String = "M403_UNAUTHORIZED"
		match variant:
			0: bad.target_id = "n"
			1: bad.action_id += 1
			2: bad.authorization_id += 1
			3: bad.lock_revision += 1
			4: bad.window_id = "m403/future"
			5: bad.amount += 1
			6:
				bad.session += 1
				reason = "M403_FOREIGN_SESSION"
			7:
				bad.extra = true
				reason = "M403_INVALID_FIELDS"
			8:
				bad.generation += 1
				reason = "M403_STALE_GENERATION"
		for method in ["impact", "complete", "cancel"]: call_checked(e, method, bad, reason)
		impact_complete(e, t)
		call_checked(e, "impact", t, "M403_DUPLICATE_OPERATION")
		end()
	for variant in range(9):
		begin("Strict close event/issuer/semantic identity rejects forgery variant %s" % variant)
		var e = fresh()
		drain(e)
		var event: Dictionary = call_checked(e, "seal", request(e, true), "M403_ROUND_SEALED", "AUTHORIZED", authority, false).event
		var bad: Dictionary = event.duplicate(true)
		var reason: String = "M403_INVALID_EVENT"
		match variant:
			0: bad.issuer_id = "M402_FINITE_FIXTURE"
			1: bad.round_id += 1
			2: bad.queue_id = "foreign"
			3: bad.witness_id += "forged"
			4: bad.sealed_revision -= 1
			5: bad.event_id += "fresh"
			6:
				bad.session += 1
				reason = "M403_FOREIGN_SESSION"
			7:
				bad.generation -= 1
				reason = "M403_STALE_GENERATION"
			8: bad.extra = true
		call_checked(e, "close", bad, reason)
		call_checked(e, "close", event, "M403_ROUND_CLOSED", "APPLIED", null, false)
		call_checked(e, "close", event, "M403_DUPLICATE_ROUND_CLOSED")
		if variant == 5:
			call_checked(e, "close", bad, "M403_INVALID_EVENT")
			check(e.snapshot().semantic_closed.size() == 1, "new unissued event ID cannot bypass semantic close key")
		end()
	for variant in range(9):
		begin("Restart rejects complete malformed fixture variant %s atomically" % variant)
		var e = fresh()
		var t: Dictionary = lock(e, "ATTACK", "a")
		var f: Dictionary = fixture()
		match variant:
			0: f.actors[-1].state.current_hp = -1
			1: f.actors.append(f.actors[0].duplicate(true))
			2: f.actors.pop_back()
			3: f.actors[0].state.life_state = "DOWN"
			4: f.round_plan = []
			5: f.round_plan[1].round_id += 1
			6: f.round_plan[0].actor_order.reverse()
			7: f.clocks.a = {"entry_round": 3, "budget": 2}
			8:
				state(f, "p", "DOWN", 0)
				f.clocks.p = {"entry_round": 3, "budget": 1}
		call_checked(e, "restart", reset_request(e, f), "M403_INVALID_RESTART", "REJECTED", authority)
		impact_complete(e, t)
		end()
	begin("Internal whole-root import/receipt/journal forgery rejected without partial publication")
	var e = fresh()
	var before: Dictionary = e.snapshot()
	for field in ["action_receipts", "summary", "clocks", "journal"]:
		var bad: Dictionary = before.duplicate(true)
		if field == "journal": bad.journal.append({"operation": "CLOSE", "payload": {}, "revision": bad.revision + 1})
		else: bad[field].fake = true
		check(not e._valid_candidate(bad), "global reconstruction rejects forged " + field)
		check(e._publish(bad, before.revision, false, "ADVANCE", request(e)) == "M403_INVALID_CANDIDATE", "publish rejects all affected domains")
	check(e.snapshot() == before, "forgery N-all")
	var detached: Dictionary = e.snapshot()
	detached.seed.actors[0].state.current_hp = 3
	detached.actors.p.state.current_hp = 3
	detached.queue.opportunities.clear()
	check(e.snapshot() == before, "seed/journal/queue snapshot edits cannot change authority")
	end()
	begin("Enemy RETREAT at own eligible slot rejects Party-only without lifecycle coercion")
	e = fresh()
	for _i in range(3): impact_complete(e, lock(e, "ATTACK", "a"))
	call_checked(e, "lock_self_retreat", lock_request(e, "RETREAT"), "M403_PARTY_ONLY", "REJECTED", authority)
	check(not e.actor_snapshot("a").state.has("life_state"), "Enemy unchanged HP/availability model")
	end()


func _diagnostics() -> void:
	begin("DIAGNOSTIC ONLY M403-10/14/15: no legal mid-action opposing producer in serial C")
	var e = fresh()
	var t: Dictionary = lock(e, "RETREAT")
	var before: Dictionary = e.snapshot()
	var observed: Dictionary = before.duplicate(true)
	Rules.set_party(observed, "p", 0, "DOWN")
	Rules.new_episode(observed, "p", observed.round_id, 2)
	var candidate: Dictionary = observed.duplicate(true)
	candidate.revision += 1
	var result: Dictionary = Rules.action_candidate(observed, candidate, "IMPACT", t)
	check(result.status == "SKIPPED" and result.reason_code == "M403_ACTOR_UNAVAILABLE", "pure live-state revalidation skips unavailable actor")
	check(not e._valid_candidate(candidate), "synthetic observation cannot pass owned history/publication")
	var complete: Dictionary = candidate.duplicate(true)
	complete.revision += 1
	result = Rules.action_candidate(candidate, complete, "COMPLETE", t)
	check(result.reason_code == "M403_ACTION_COMPLETED" and complete.actors == candidate.actors, "pure settlement has no second effect")
	check(e.snapshot() == before, "all diagnostic observations detached, no claimed live damage")
	current.steps.append({"kind": "DIAGNOSTIC_ONLY_NO_LEGAL_MID_ACTION_PRODUCER", "input": observed,
		"pure_impact": candidate, "pure_completion": complete, "live_before": before, "live_after": e.snapshot()})
	call_checked(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED", null, false)
	end()
	for timing in ["PLAYER_AFTER_IMPACT", "NPC_LOCKED"]:
		begin("DIAGNOSTIC ONLY " + timing + ": detached Player DOWN revalidation, no live interleaving")
		var observed_e = fresh()
		var player_token: Dictionary = lock(observed_e, "ATTACK", "a")
		call_checked(observed_e, "impact", player_token, "M403_FIXTURE_DAMAGE", "APPLIED", null, false)
		var owned_token: Dictionary = player_token
		if timing == "NPC_LOCKED":
			call_checked(observed_e, "complete", player_token, "M403_ACTION_COMPLETED", "APPLIED", null, false)
			owned_token = lock(observed_e, "ATTACK", "a")
		var live: Dictionary = observed_e.snapshot()
		var scratch: Dictionary = live.duplicate(true)
		Rules.set_party(scratch, "p", 0, "DOWN")
		Rules.new_episode(scratch, "p", scratch.round_id, 2)
		var next_candidate: Dictionary = scratch.duplicate(true)
		next_candidate.revision += 1
		var outcome: Dictionary = Rules.action_candidate(scratch, next_candidate, "IMPACT" if timing == "NPC_LOCKED" else "COMPLETE", owned_token)
		check(outcome.status == "APPLIED" and next_candidate.actors.p == scratch.actors.p, "prior Player completion/NPC impact does not undo Player DOWN")
		check(not observed_e._valid_candidate(next_candidate) and observed_e.snapshot() == live, "diagnostic history cannot publish fabricated Player damage")
		current.steps.append({"kind": "DIAGNOSTIC_ONLY_M403_14_OR_15", "input": scratch, "candidate": next_candidate, "before": live, "after": observed_e.snapshot()})
		end()

	begin("UNREACHABLE BY DESIGN: close cannot remove last active Party/Enemy; final planned Enemy cannot kill opposing Enemy")
	var e2 = fresh()
	drain(e2)
	seal_close(e2)
	check(Rules.Queue.active_party(e2.snapshot()) > 0 and Rules.Queue.active_enemies(e2.snapshot()) > 0, "strict seal requires active sides; ticks affect only prior DOWN")
	check(e2.snapshot().outcome.is_empty(), "no invented clock-caused terminal")
	check(e2.snapshot().plan[0].actor_order[-1] in e2.snapshot().initial_enemies, "last planned slot is opposing Enemy, cannot deliver final-Enemy hit")
	current.steps.append({"kind": "REACHABILITY_ARGUMENT", "argument": "Seal P>0/E>0; close changes only DOWN rows, so P/E unchanged. Stable final Enemy slot cannot ATTACK its own domain. No simultaneous damage producer."})
	end()


func _run() -> void:
	_architecture()
	_classifier()
	_atomic_terminal()
	_continuation()
	_rounds_clocks()
	_r49()
	_abort_restart()
	_security()
	_diagnostics()
	var report: Dictionary = {"suite": "M4-03C terminal summary continuation", "independent_cases": cases.size(),
		"assertion_checks": checks, "failures": failures, "per_frame_checks": 0, "cases": cases,
		"deferred": ["D08/D16/full D09/production integration", "M402-06 BLOCKED and M402-24 PARTIAL unchanged",
			"M403-10/14/15 mid-action unavailability DIAGNOSTIC ONLY; no serial legal producer",
			"clock-caused terminal and final planned Enemy killing last Enemy UNREACHABLE BY DESIGN",
			"manual GUI/F5/F6/keyboard/visual NOT RUN", "no NPC autonomous policy or concurrent security claim"]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file == null:
				quit(1)
				return
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RESULT: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
