extends SceneTree

const Encounter = preload("res://scripts/m4/isolated_rescue_clock_encounter.gd")
const Diagnostic = preload("res://tests/actors/m4_02_diagnostic_encounter.gd")
var checks: int = 0
var failures: int = 0
var cases: Array = []
var current: Dictionary = {}
var start_checks: int = 0
var start_failures: int = 0
var authority := RefCounted.new()


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: %s %s" % [current.get("id", "setup"), message])


func begin(id: String, preconditions: String) -> void:
	start_checks = checks
	start_failures = failures
	current = {"id": id, "preconditions": preconditions, "steps": []}


func end() -> void:
	current.assertion_count = checks - start_checks
	current.failure_count = failures - start_failures
	current.actual = "PASS" if current.failure_count == 0 else "FAIL"
	cases.append(current)
	print("CASE %s: %s" % [current.id, current.actual])


func fixture() -> Dictionary:
	var actors: Array = []
	for id in ["p", "h", "j", "t", "enemy"]:
		var role: String = "PLAYER" if id == "p" else ("ENEMY" if id == "enemy" else "NPC")
		actors.append({"definition": {"actor_id": id, "display_name": id, "role": role, "base_max_hp": 10},
			"state": {"current_hp": 10} if id == "enemy" else {"current_hp": 0 if id == "t" else 10,
			"life_state": "DOWN" if id == "t" else "ALIVE", "participation": "PRESENT"}})
	var plan: Array = []
	for round_id in range(3, 8):
		# Real finite fixture damage operation, impact and completion. No mock receipt.
		plan.append({"round_id": round_id, "slots": [{"slot_id": "damage_p", "helper_id": "p", "target_id": "p", "amount": 1}],
			"event_ids": ["c%s" % round_id, "alternate_c%s" % round_id]})
	return {"actors": actors, "round_plan": plan, "clocks": {}, "help_reference": {}}


func state(f: Dictionary, id: String, life: String, hp: int, participation: String = "PRESENT") -> void:
	for row in f.actors:
		if row.definition.actor_id == id:
			row.state = {"current_hp": hp, "life_state": life, "participation": participation}


func fresh(f: Dictionary = fixture()):
	var e = Diagnostic.new(authority)
	check(e.restart(f, authority).reason_code == "M4_RESTARTED", "fixture reconstructed")
	return e


func request(e, operation: String = "r1", helper: String = "h", target: String = "t") -> Dictionary:
	var s: Dictionary = e.snapshot()
	return {"version": 1, "session": s.session, "generation": s.generation, "operation_id": operation,
		"kind": "RESCUE", "helper_id": helper, "target_id": target, "window_id": s.window_id}


func lock(e, operation: String = "r1", helper: String = "h", target: String = "t") -> Dictionary:
	var result: Dictionary = observe(e, "lock_rescue", [request(e, operation, helper, target), authority], "M4_FIXTURE_AUTHORIZED")
	return result.get("token", {})


func observe(e, method: String, args: Array, reason: String, invariant: String = "", status: String = "") -> Dictionary:
	var before: Dictionary = e.snapshot()
	var result: Dictionary = e.callv(method, args)
	var after: Dictionary = e.snapshot()
	check(result.reason_code == reason, "%s expected %s got %s" % [method, reason, result])
	if not status.is_empty():
		check(result.status == status, "exact outcome " + status)
	if result.reason_code == "M4_RESCUED":
		check(result.hp_delta == 1 and result.rescue_use_delta == -1, "actual rescue deltas +1/-1")
		check(result.life_before == "DOWN" and result.life_after == "ALIVE", "actual life transition")
	if result.status == "SKIP":
		check(result.hp_delta == 0 and result.rescue_use_delta == 0, "actual SKIP deltas zero")
	if invariant == "N-all":
		check(after == before, "entire root unchanged")
	elif invariant == "N-effect":
		for field in ["actors", "episodes", "rescue_uses", "help_reference", "event_consumed", "semantic_closed"]:
			check(after[field] == before[field], "N-effect " + field)
	if result.status != "REJECTED":
		check(after.revision == before.revision + 1 if method != "restart" else after.revision == 0, "one revision per publication")
	# Capability objects are described, never serialized; every token/input stays exact.
	var exact: Array = []
	for arg in args:
		exact.append("<owned fixture capability>" if arg is RefCounted else arg)
	current.steps.append({"method": method, "exact_input": exact.duplicate(true), "expected_reason": reason,
		"expected_invariant": invariant, "actual_result": result.duplicate(true), "before": before, "after": after})
	return result


func slots(e) -> void:
	for slot in e.snapshot().plan[e.snapshot().round_index].slots:
		var issued: Dictionary = observe(e, "lock_fixture_slot", [slot.slot_id, authority], "M4_FIXTURE_AUTHORIZED")
		var token: Dictionary = issued.get("token", {})
		observe(e, "impact", [token], "M4_FIXTURE_DAMAGE", "", "APPLIED")
		observe(e, "complete", [token], "M4_ACTION_COMPLETED")


func sealed(e) -> Array:
	slots(e)
	return observe(e, "seal", [authority], "M4_ROUND_SEALED").get("tokens", [])


func close(e) -> Dictionary:
	var events: Array = sealed(e)
	return observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")


func advance(e, round_id: int) -> void:
	observe(e, "next_round", [round_id, authority], "M4_NEXT_ROUND")


func rescue(e, operation: String = "r1", helper: String = "h", target: String = "t") -> Dictionary:
	var token: Dictionary = lock(e, operation, helper, target)
	observe(e, "impact", [token], "M4_RESCUED", "", "APPLIED")
	observe(e, "complete", [token], "M4_ACTION_COMPLETED")
	return token


func _rescue_cases() -> void:
	begin("M402-01", "default DOWN target; independent HELP reference1")
	var e = fresh()
	var before: Dictionary = e.snapshot()
	var token: Dictionary = rescue(e)
	var s: Dictionary = e.snapshot()
	check(s.actors.t.state.current_hp == 1 and s.actors.t.state.life_state == "ALIVE", "HP1/ALIVE")
	check(not s.episodes.t.active and s.rescue_uses.h == 0, "clock retired/use consumed")
	check(s.help_reference == before.help_reference and s.witness.expected_slots == before.witness.expected_slots, "HELP and slots preserved")
	end()
	begin("M402-02", "Player DOWN fixture; no command/queue integration")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	e = fresh(f)
	rescue(e, "r1", "h", "p")
	check(e.actor_snapshot("p").state.current_hp == 1, "Player recovery HP1")
	end()
	begin("M402-03", "successful helper use exhausted; target downs again")
	e = fresh()
	rescue(e)
	observe(e, "fixture_damage", ["t", 1, authority], "M4_FIXTURE_DAMAGE")
	observe(e, "lock_rescue", [request(e), authority], "M4_DUPLICATE_OPERATION", "N-all")
	observe(e, "lock_rescue", [request(e, "r2"), authority], "M4_RESCUE_EXHAUSTED", "N-all")
	end()
	begin("M402-04", "HELP sentinel0, separate rescue use1")
	f = fixture()
	f.help_reference.h = 0
	e = fresh(f)
	rescue(e)
	check(e.snapshot().help_reference.h == 0, "HELP unchanged")
	end()
	begin("M402-05", "consumed impact/completion replay")
	e = fresh()
	token = rescue(e)
	observe(e, "impact", [token], "M4_DUPLICATE_OPERATION", "N-all")
	observe(e, "complete", [token], "M4_INVALID_PHASE", "N-all")
	end()
	begin("M402-06-validator-only", "detached DEAD input; integration BLOCKED")
	f = fixture()
	state(f, "t", "DEAD", 0)
	e = fresh(f)
	s = e.snapshot()
	check(Encounter.rescue_eligibility(s, "h", "t") == "M4_DEAD_NOT_RESCUABLE", "pure DEAD eligibility")
	check(e.snapshot() == s, "pure check no writes")
	current.exact_input = s
	current.expected = "M4_DEAD_NOT_RESCUABLE; no mutation; NOT death-before-pending-impact integration"
	end()
	begin("M402-07", "initial DEAD target")
	e = fresh(f)
	observe(e, "lock_rescue", [request(e), authority], "M4_DEAD_NOT_RESCUABLE", "N-all")
	end()
	for mode in [8, 9, 10, 11, 45]:
		begin("M402-%02d" % mode, "owned locks before legitimate OPEN interleaving")
		f = fixture()
		if mode == 45:
			state(f, "j", "DOWN", 0)
		e = fresh(f)
		token = lock(e)
		if mode == 11:
			observe(e, "fixture_damage", ["h", 10, authority], "M4_FIXTURE_DAMAGE")
		elif mode == 45:
			rescue(e, "r2", "h", "j")
		else:
			rescue(e, "r2", "j")
			if mode == 9:
				observe(e, "fixture_damage", ["t", 1, authority], "M4_FIXTURE_DAMAGE")
		var why: String = "M4_ACTOR_UNAVAILABLE" if mode == 11 else ("M4_DOWN_EPISODE_CHANGED" if mode == 9 else ("M4_RESCUE_EXHAUSTED" if mode == 45 else "M4_TARGET_NOT_DOWN"))
		observe(e, "impact", [token], why, "N-effect", "SKIP")
		observe(e, "complete", [token], "M4_ACTION_COMPLETED")
		check(e.snapshot().rescue_uses.h == (0 if mode == 45 else 1), "no charge for SKIP")
		if mode == 10:
			e = fresh()
			var other: Dictionary = lock(e, "r2", "j")
			rescue(e)
			observe(e, "impact", [other], "M4_TARGET_NOT_DOWN", "N-effect", "SKIP")
		end()
	for spec in [["DOWN", 0, "PRESENT"], ["DEAD", 0, "PRESENT"], ["ALIVE", 7, "RETREATED"]]:
		begin("M402-12-" + spec[0] + spec[2], "helper unavailable seed")
		f = fixture()
		state(f, "h", spec[0], spec[1], spec[2])
		e = fresh(f)
		observe(e, "lock_rescue", [request(e), authority], "M4_ACTOR_UNAVAILABLE", "N-all")
		end()
	begin("M402-13", "missing/enemy/self targets")
	e = fresh()
	for target in ["missing", "enemy", "h"]:
		observe(e, "lock_rescue", [request(e, "r1", "h", target), authority], "M4_INVALID_TARGET", "N-all")
	end()
	for spec in [[14, "RETREATED", "M4_TARGET_NOT_PRESENT"], [15, "PRESENT", "M4_TARGET_NOT_DOWN"]]:
		begin("M402-%02d" % spec[0], "ALIVE target " + spec[1])
		f = fixture()
		state(f, "t", "ALIVE", 4, spec[1])
		e = fresh(f)
		observe(e, "lock_rescue", [request(e), authority], spec[2], "N-all")
		end()
	begin("M402-16", "owned unused grant; malformed/unissued/altered inputs")
	e = fresh()
	token = lock(e)
	for field in Encounter.ACTION_FIELDS:
		var altered: Dictionary = token.duplicate(true)
		altered.erase(field)
		observe(e, "impact", [altered], "M4_INVALID_FIELDS", "N-all")
		altered = token.duplicate(true)
		altered[field] = true
		observe(e, "impact", [altered], "M4_INVALID_FIELDS", "N-all")
	for field in ["target_id", "helper_id", "episode_id", "operation_id", "authorization_id", "window_id", "lock_revision", "kind", "amount", "slot_id"]:
		var altered: Dictionary = token.duplicate(true)
		altered[field] = altered[field] + 1 if typeof(altered[field]) == TYPE_INT else altered[field] + "_forged"
		observe(e, "impact", [altered], "M4_UNAUTHORIZED", "N-all")
	var extra: Dictionary = token.duplicate(true)
	extra.completed = true
	observe(e, "impact", [extra], "M4_INVALID_FIELDS", "N-all")
	observe(e, "lock_rescue", [request(e, "r2"), RefCounted.new()], "M4_UNAUTHORIZED", "N-all")
	for field in Encounter.REQUEST_FIELDS:
		var bad: Dictionary = request(e, "r2")
		bad.erase(field)
		observe(e, "lock_rescue", [bad, authority], "M4_INVALID_FIELDS", "N-all")
		bad = request(e, "r2")
		bad[field] = true
		observe(e, "lock_rescue", [bad, authority], "M4_INVALID_FIELDS", "N-all")
	var bad_request: Dictionary = request(e, "r2")
	bad_request.extra = 1
	observe(e, "lock_rescue", [bad_request, authority], "M4_INVALID_FIELDS", "N-all")
	observe(e, "impact", [token], "M4_RESCUED")
	end()
	begin("M402-17", "foreign session and stale generation")
	e = fresh()
	token = lock(e)
	var foreign: Dictionary = token.duplicate(true)
	foreign.session += 1
	observe(e, "impact", [foreign], "M4_FOREIGN_SESSION", "N-all")
	observe(e, "restart", [fixture(), authority], "M4_RESTARTED")
	observe(e, "impact", [token], "M4_STALE_GENERATION", "N-all")
	observe(e, "complete", [token], "M4_STALE_GENERATION", "N-all")
	end()
	begin("M402-18", "cancel before impact")
	e = fresh()
	token = lock(e)
	observe(e, "cancel", [token], "M4_ACTION_CANCELLED", "N-effect")
	observe(e, "impact", [token], "M4_INVALID_PHASE", "N-all")
	end()
	begin("M402-19", "test-only candidate validation rejection")
	e = fresh()
	token = lock(e)
	e.fault = "M4_INVALID_CANDIDATE"
	observe(e, "impact", [token], "M4_INVALID_CANDIDATE", "N-all")
	e.fault = ""
	observe(e, "impact", [token], "M4_RESCUED")
	end()
	begin("M402-20", "published snapshots before/after single synchronous effect")
	e = fresh()
	token = lock(e)
	before = e.snapshot()
	observe(e, "impact", [token], "M4_RESCUED")
	s = e.snapshot()
	check(before.actors.t.state.current_hp == 0 and before.rescue_uses.h == 1 and before.episodes.t.active, "before complete tuple")
	check(s.actors.t.state.current_hp == 1 and s.rescue_uses.h == 0 and not s.episodes.t.active, "after complete tuple")
	check(s.revision == before.revision + 1, "single publication")
	end()


func _clock_cases() -> void:
	begin("M402-21", "entry round3 grace and consumed replay")
	var e = fresh()
	var events: Array = sealed(e)
	var result: Dictionary = observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
	check(result.episodes[0].reason_code == "M4_BLEED_GRACE" and e.snapshot().episodes.t.budget == 2, "entry grace")
	observe(e, "apply_round_closed", [events[0]], "M4_DUPLICATE_ROUND_CLOSED", "N-all")
	end()
	begin("M402-22", "finite actual rounds3/4/5 close B2/B1/DEAD0")
	e = fresh()
	close(e)
	advance(e, 4)
	result = close(e)
	check(result.episodes[0].reason_code == "M4_BLEED_TICK" and e.snapshot().episodes.t.budget == 1, "one eligible tick")
	advance(e, 5)
	result = close(e)
	check(result.episodes[0].reason_code == "M4_BLED_OUT" and e.actor_snapshot("t").state.life_state == "DEAD", "natural death")
	check(e.snapshot().episodes.t.budget == 0 and not e.snapshot().episodes.t.active, "inactive B0")
	end()
	begin("M402-23", "two owned event IDs for same semantic round; forged new ID")
	e = fresh()
	close(e)
	advance(e, 4)
	events = sealed(e)
	observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
	observe(e, "apply_round_closed", [events[0]], "M4_DUPLICATE_ROUND_CLOSED", "N-all")
	observe(e, "apply_round_closed", [events[1]], "M4_DUPLICATE_ROUND_CLOSED", "N-all")
	var forged: Dictionary = events[0].duplicate(true)
	forged.event_id = "unissued"
	observe(e, "apply_round_closed", [forged], "M4_INVALID_EVENT", "N-all")
	end()
	begin("M402-24", "malformed/wrong issuer/witness/round events; no authorized wrong-round issuance")
	e = fresh()
	events = sealed(e)
	for field in Encounter.EVENT_FIELDS:
		for mode in ["missing", "type", "altered"]:
			forged = events[0].duplicate(true)
			if mode == "missing":
				forged.erase(field)
			elif mode == "type":
				forged[field] = true
			else:
				forged[field] = forged[field] + 1 if typeof(forged[field]) == TYPE_INT else forged[field] + "_forged"
			var why: String = "M4_FOREIGN_SESSION" if field == "session" and mode == "altered" else ("M4_STALE_GENERATION" if field == "generation" and mode == "altered" else "M4_INVALID_EVENT")
			observe(e, "apply_round_closed", [forged], why, "N-all")
	forged = events[0].duplicate(true)
	forged.extra = true
	observe(e, "apply_round_closed", [forged], "M4_INVALID_EVENT", "N-all")
	current.limitation = "Authenticated unconsumed wrong-round event cannot be issued by strict finite authority; malformed round returns INVALID_EVENT before domain gate. No bypass."
	end()
	for number in [25, 44]:
		begin("M402-%02d" % number, "SEALED valid event; test diagnostic never writes root")
		var death_fixture: Dictionary = fixture()
		state(death_fixture, "j", "DOWN", 0)
		death_fixture.clocks.j = {"entry_round": 2, "budget": 1}
		death_fixture.clocks.t = {"entry_round": 2, "budget": 1}
		e = fresh(death_fixture)
		var abort: Dictionary = e.authorize_abort("abort", authority).token
		events = sealed(e)
		if number == 25:
			e.stale_seal = true
		else:
			e.fault = "M4_STALE_REVISION"
		observe(e, "apply_round_closed", [events[0]], "M4_STALE_REVISION", "N-all")
		observe(e, "seal", [authority], "M4_INVALID_PHASE", "N-all")
		check(e.snapshot().phase == "SEALED", "remains SEALED")
		# Recovery follows Abort->Restart; diagnostic flags are not published state.
		e.stale_seal = false
		e.fault = ""
		observe(e, "abort_round", [abort], "M4_ROUND_ABORTED", "N-effect")
		observe(e, "restart", [fixture(), authority], "M4_RESTARTED")
		end()
	begin("M402-26", "B1 prior-entry rescue settled before close")
	var f: Dictionary = fixture()
	f.clocks.t = {"entry_round": 2, "budget": 1}
	e = fresh(f)
	rescue(e)
	result = close(e)
	check(result.episodes.is_empty() and e.actor_snapshot("t").state.life_state == "ALIVE", "no tick after rescue")
	end()
	begin("M402-27", "natural B1 death then fresh lock only in next OPEN")
	e = fresh(f)
	close(e)
	observe(e, "lock_rescue", [request(e), authority], "M4_INVALID_PHASE", "N-all")
	advance(e, 4)
	observe(e, "lock_rescue", [request(e), authority], "M4_DEAD_NOT_RESCUABLE", "N-all")
	end()
	begin("M402-28", "DEAD retains roster/HP0; no negative clock or raw death API")
	e = fresh(f)
	close(e)
	advance(e, 4)
	result = close(e)
	check(result.episodes.is_empty() and e.snapshot().episodes.t.budget == 0 and e.snapshot().actors.has("t"), "dead excluded and retained")
	advance(e, 5)
	observe(e, "lock_rescue", [{"actor_id": "t", "current_hp": 0}, authority], "M4_INVALID_FIELDS", "N-all")
	end()
	for inject in [false, true]:
		begin("M402-29-" + str(inject), "two eligible actors J B1/T B2 entry2; candidate validation failure after second eligible row T")
		f = fixture()
		state(f, "j", "DOWN", 0)
		f.clocks.j = {"entry_round": 2, "budget": 1}
		f.clocks.t = {"entry_round": 2, "budget": 2}
		e = fresh(f)
		events = sealed(e)
		if inject:
			e.fail_actor = "t"
			observe(e, "apply_round_closed", [events[0]], "M4_INVALID_CANDIDATE", "N-all")
		else:
			observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
			check(e.snapshot().episodes.t.budget == 1 and e.actor_snapshot("j").state.life_state == "DEAD", "entire batch")
		end()
	begin("M402-30", "rescued e1 then down e2 round4; old consumed token")
	e = fresh()
	var old: Dictionary = e.snapshot().episodes.t.duplicate(true)
	close(e)
	advance(e, 4)
	var token: Dictionary = rescue(e)
	observe(e, "fixture_damage", ["t", 1, authority], "M4_FIXTURE_DAMAGE")
	observe(e, "impact", [token], "M4_DUPLICATE_OPERATION", "N-all")
	check(e.snapshot().episodes.t.episode_id != old.episode_id and e.snapshot().episodes.t.entry_round == 4, "new episode")
	close(e)
	check(e.snapshot().episodes.t.budget == 2, "new entry grace")
	advance(e, 5)
	observe(e, "impact", [token], "M4_INVALID_PHASE", "N-all")
	close(e)
	check(e.snapshot().episodes.t.budget == 1 and e.snapshot().rescue_uses.h == 0, "new tick/no refund")
	end()


func _boundary_cases() -> void:
	begin("M402-31", "OPEN restart invalidates actions; SEALED reset requires Abort")
	var e = fresh()
	var token: Dictionary = lock(e)
	var old: Dictionary = e.snapshot()
	observe(e, "restart", [fixture(), authority], "M4_RESTARTED")
	check(e.snapshot().generation == old.generation + 1 and e.snapshot().episodes.t.episode_id != old.episodes.t.episode_id, "generation/episode identity")
	observe(e, "impact", [token], "M4_STALE_GENERATION", "N-all")
	var abort: Dictionary = observe(e, "authorize_abort", ["abort", authority], "M4_FIXTURE_AUTHORIZED").token
	var events: Array = sealed(e)
	observe(e, "restart", [fixture(), authority], "M4_INVALID_PHASE", "N-all")
	observe(e, "abort_round", [abort], "M4_ROUND_ABORTED", "N-effect")
	observe(e, "restart", [fixture(), authority], "M4_RESTARTED")
	observe(e, "apply_round_closed", [events[0]], "M4_STALE_GENERATION", "N-all")
	observe(e, "abort_round", [abort], "M4_STALE_GENERATION", "N-all")
	observe(e, "complete", [token], "M4_STALE_GENERATION", "N-all")
	end()
	for phase in ["OPEN", "SEALED"]:
		begin("M402-32-" + phase, "invalid restart must preserve pending legitimate operation")
		e = fresh()
		token = lock(e) if phase == "OPEN" else {}
		events = sealed(e) if phase == "SEALED" else []
		for malformed in ["duplicate", "last_row", "pair", "clock", "budget_type", "extra", "slot", "help", "event_id"]:
			var f: Dictionary = fixture()
			match malformed:
				"duplicate": f.actors.append(f.actors[0].duplicate(true))
				"last_row": f.actors[-1].state.current_hp = "10"
				"pair": state(f, "t", "DOWN", 0, "RETREATED")
				"clock": f.clocks.t = {"entry_round": 3, "budget": 1}
				"budget_type": f.clocks.t = {"entry_round": 2, "budget": true}
				"extra": f.actors[0].state.extra = true
				"slot": f.round_plan[0].slots.append(f.round_plan[0].slots[0].duplicate(true))
				"help": f.help_reference.h = true
				"event_id": f.round_plan[1].event_ids[0] = f.round_plan[0].event_ids[0]
			observe(e, "restart", [f, authority], "M4_INVALID_RESTART", "N-all")
		observe(e, "impact" if phase == "OPEN" else "apply_round_closed", [token if phase == "OPEN" else events[0]], "M4_RESCUED" if phase == "OPEN" else "M4_ROUND_CLOSED")
		end()
	begin("M402-33", "fresh generation reconstructs all state/uses; serial never reused")
	e = fresh()
	token = rescue(e)
	close(e)
	old = e.snapshot()
	observe(e, "restart", [fixture(), authority], "M4_RESTARTED")
	check(e.snapshot().rescue_uses.h == 1 and e.snapshot().revision == 0, "fresh uses/revision")
	var new_token: Dictionary = rescue(e)
	check(new_token.authorization_id > token.authorization_id and new_token.generation > token.generation, "serial/generation grow")
	close(e)
	check(old.actors.t.state.current_hp == 1, "old detached snapshot retained")
	end()
	for phase in ["OPEN", "SEALED"]:
		begin("M402-34-" + phase, "explicit pre-issued Abort no tick/fake completion")
		e = fresh()
		abort = observe(e, "authorize_abort", ["abort", authority], "M4_FIXTURE_AUTHORIZED").token
		token = lock(e) if phase == "OPEN" else {}
		events = sealed(e) if phase == "SEALED" else []
		var bad_abort: Dictionary = abort.duplicate(true)
		bad_abort.session += 1
		observe(e, "abort_round", [bad_abort], "M4_FOREIGN_SESSION", "N-all")
		bad_abort = abort.duplicate(true)
		bad_abort.authorization_id += 1
		observe(e, "abort_round", [bad_abort], "M4_UNAUTHORIZED", "N-all")
		observe(e, "abort_round", [abort], "M4_ROUND_ABORTED", "N-effect")
		observe(e, "abort_round", [abort], "M4_DUPLICATE_OPERATION", "N-all")
		observe(e, "impact" if phase == "OPEN" else "apply_round_closed", [token if phase == "OPEN" else events[0]], "M4_INVALID_PHASE", "N-all")
		observe(e, "next_round", [4, authority], "M4_INVALID_PHASE", "N-all")
		end()
	begin("M402-35", "incomplete witness, pending impact/completion, strict SEALED operations")
	e = fresh()
	observe(e, "seal", [authority], "M4_ROUND_NOT_CLOSABLE", "N-all")
	token = lock(e)
	slots(e)
	observe(e, "seal", [authority], "M4_ROUND_NOT_CLOSABLE", "N-all")
	observe(e, "impact", [token], "M4_RESCUED")
	observe(e, "seal", [authority], "M4_ROUND_NOT_CLOSABLE", "N-all")
	observe(e, "complete", [token], "M4_ACTION_COMPLETED")
	observe(e, "complete", [token], "M4_INVALID_PHASE", "N-all")
	observe(e, "lock_fixture_slot", ["damage_p", authority], "M4_DUPLICATE_OPERATION", "N-all")
	observe(e, "seal", [authority], "M4_ROUND_SEALED")
	observe(e, "lock_rescue", [request(e, "r2"), authority], "M4_INVALID_PHASE", "N-all")
	observe(e, "fixture_damage", ["h", 1, authority], "M4_INVALID_PHASE", "N-all")
	observe(e, "complete", [token], "M4_INVALID_PHASE", "N-all")
	observe(e, "cancel", [token], "M4_INVALID_PHASE", "N-all")
	observe(e, "impact", [token], "M4_INVALID_PHASE", "N-all")
	observe(e, "seal", [authority], "M4_INVALID_PHASE", "N-all")
	observe(e, "authorize_abort", ["late", authority], "M4_INVALID_PHASE", "N-all")
	observe(e, "unsupported_transition", ["DOWN_TO_RETREATED"], "M4_INVALID_PHASE", "N-all")
	end()
	for mode in ["empty", "all_down", "no_enemy", "player_down"]:
		begin("M402-36-" + mode, "conservative boundary rejection; bounded attempts")
		var f: Dictionary = fixture()
		if mode == "empty":
			f.round_plan[0].slots = []
		elif mode == "all_down":
			for id in ["p", "h", "j"]:
				state(f, id, "DOWN", 0)
		elif mode == "no_enemy":
			f.actors[-1].state.current_hp = 0
		else:
			state(f, "p", "DOWN", 0)
		e = fresh(f)
		for attempt in range(2):
			observe(e, "seal", [authority], "M4_ROUND_NOT_CLOSABLE" if mode == "empty" else "M4_BOUNDARY_DEPENDENCY", "N-all")
		end()
	begin("M402-36-finite-boundary", "next round empty or beyond finite script rejects without implicit rounds")
	var bounded: Dictionary = fixture()
	bounded.round_plan[1].slots = []
	e = fresh(bounded)
	close(e)
	observe(e, "next_round", [4, authority], "M4_ROUND_NOT_CLOSABLE", "N-all")
	bounded.round_plan.resize(1)
	e = fresh(bounded)
	close(e)
	observe(e, "next_round", [4, authority], "M4_INVALID_ROUND", "N-all")
	end()
	begin("M402-37", "OPEN unsupported evacuation before legitimate grace close; retreated excluded")
	var f: Dictionary = fixture()
	state(f, "j", "ALIVE", 7, "RETREATED")
	e = fresh(f)
	slots(e)
	observe(e, "unsupported_transition", ["DOWN_TO_RETREATED"], "M4_EVACUATION_UNSUPPORTED", "N-all")
	events = observe(e, "seal", [authority], "M4_ROUND_SEALED").tokens
	var result: Dictionary = observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
	check(result.episodes.size() == 1 and result.episodes[0].actor_id == "t" and result.episodes[0].reason_code == "M4_BLEED_GRACE", "only DOWN grace")
	check(e.actor_snapshot("j").state.participation == "RETREATED", "retreated preserved")
	end()
	for life in ["DOWN", "DEAD"]:
		begin("M402-38-" + life, "unsupported heal/attack-down/stabilize/aftercare/revive")
		f = fixture()
		state(f, "t", life, 0)
		e = fresh(f)
		for kind in ["HEAL", "ATTACK_DOWN", "STABILIZE", "AFTERCARE", "REVIVE"]:
			observe(e, "unsupported_transition", [kind], "M4_TRANSITION_UNSUPPORTED", "N-all")
		end()
	begin("M402-39-copy", "all nested read views detached; unchanged M4-01 regression is external evidence")
	var owned_fixture: Dictionary = fixture()
	e = fresh(owned_fixture)
	token = lock(e)
	old = e.snapshot()
	owned_fixture.actors.clear()
	owned_fixture.round_plan.clear()
	check(e.snapshot() == old, "fixture copied at entry")
	check(not e.has_method("heal") and not e.has_method("revive") and not e.has_method("unregister_actor"), "no raw lifecycle bypass API")
	var changed: Dictionary = e.snapshot()
	changed.actors.t.state.current_hp = 10
	changed.episodes.t.budget = 0
	changed.rescue_uses.h = 0
	changed.actions.clear()
	changed.witness.expected_slots.clear()
	check(e.snapshot() == old, "nested snapshot writes cannot publish")
	changed = e.actor_snapshot("t")
	changed.state.current_hp = 10
	check(e.snapshot() == old, "actor view detached")
	observe(e, "impact", [token], "M4_RESCUED")
	end()
	begin("M402-42", "no DOWN; semantic close still consumed")
	f = fixture()
	state(f, "t", "ALIVE", 10)
	e = fresh(f)
	events = sealed(e)
	result = observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
	check(result.episodes.is_empty(), "empty episode result")
	observe(e, "apply_round_closed", [events[1]], "M4_DUPLICATE_ROUND_CLOSED", "N-all")
	end()
	begin("M402-43", "old window grant and action/event cross-use")
	e = fresh()
	token = rescue(e)
	events = sealed(e)
	observe(e, "apply_round_closed", [token], "M4_INVALID_EVENT", "N-all")
	observe(e, "impact", [events[0]], "M4_INVALID_FIELDS", "N-all")
	observe(e, "apply_round_closed", [events[0]], "M4_ROUND_CLOSED")
	observe(e, "next_round", [3, authority], "M4_INVALID_ROUND", "N-all")
	observe(e, "next_round", [5, authority], "M4_INVALID_ROUND", "N-all")
	advance(e, 4)
	observe(e, "impact", [token], "M4_INVALID_PHASE", "N-all")
	observe(e, "next_round", [4, authority], "M4_INVALID_PHASE", "N-all")
	end()


func _run() -> void:
	_rescue_cases()
	_clock_cases()
	_boundary_cases()
	var report: Dictionary = {"cases": cases, "independent_cases": cases.size(), "assertion_checks": checks,
		"per_frame_checks": 0, "failures": failures,
		"blocked": [{"id": "M402-06", "status": "BLOCKED", "reason": "Natural close forbids pending impact; validator-only case separate"},
			{"id": "M402-D01", "status": "BLOCKED"}, {"id": "M402-D02", "status": "BLOCKED"},
			{"id": "M402-D03", "status": "DEFERRED"}, {"id": "M402-D04", "status": "BLOCKED"}, {"id": "M402-D05", "status": "DEFERRED"}],
		"external_verification": ["M402-39 unchanged M4-01 78 cases/525 checks", "M402-40 full regression/differential", "M402-41 Guidance regression/protected source hashes"]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
