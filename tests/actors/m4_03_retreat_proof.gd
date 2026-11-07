extends SceneTree

const Encounter = preload("res://scripts/m4/isolated_queue_outcome_encounter.gd")
const Retreat = preload("res://scripts/m4/m403_effect_candidates.gd")
const Adapter = preload("res://scripts/m4/m403_queue_adapter.gd")
# Test-only rejection of an otherwise legal candidate; no new state producer.
class RejectingEncounter:
	extends "res://scripts/m4/m403_effect_candidates.gd"
	var reject_candidate: bool = false

	func _valid_candidate(c: Variant) -> bool:
		return false if reject_candidate else super._valid_candidate(c)


# Detached observation overlay only. Used exclusively for a rejected pre-impact
# boundary call, never published, never a legal damage/RESCUE producer.
class BoundaryObservation:
	extends "res://scripts/m4/m403_effect_candidates.gd"
	var observe_last_active: bool = false
	var observe_no_enemies: bool = false

	func snapshot() -> Dictionary:
		var c: Dictionary = super.snapshot()
		if observe_last_active:
			for id in ["n1", "n2", "n3"]:
				c.actors[id].state.current_hp = 0
				c.actors[id].state.life_state = "DOWN"
				c.actors[id].state.eligible = false
		if observe_no_enemies:
			for id in c.initial_enemies:
				c.actors[id].state.current_hp = 0
				c.actors[id].state.can_act = false
		return c


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
	current = {"id": "M403B-%02d" % (cases.size() + 1), "expected": description, "steps": [], "assertions": []}


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
	if not no_delta and method == "lock_self_retreat":
		var unrelated: Dictionary = after.duplicate(true)
		for field in ["revision", "active_operation", "authorizations", "queue"]: unrelated[field] = before[field]
		check(unrelated == before, "lock protects every unrelated root domain")
		check(after.queue.cursor == before.queue.cursor and after.action_receipts == before.action_receipts,
			"lock cannot dispose or mint receipts")
		check(e._valid_candidate(after), "published lock complete candidate valid")
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


func bfresh(f: Dictionary = fixture()):
	var e = Retreat.new(authority)
	observe(e, "restart", reset_request(e, f), authority, "M403_RESTARTED", "APPLIED", false)
	return e


func lock_request(e, id: String = "retreat-request") -> Dictionary:
	var r: Dictionary = request(e)
	r.slot_id = e.current_opportunity().get("slot_id", "")
	r.actor_id = e.current_opportunity().get("actor_id", "")
	r.kind = "RETREAT"
	r.request_id = id
	return r


func lock(e, id: String = "retreat-request") -> Dictionary:
	return observe(e, "lock_self_retreat", lock_request(e, id), authority, "M403_RETREAT_LOCKED", "AUTHORIZED", false).token


func settle(e, method: String, token: Variant, reason: String, status: String, no_delta: bool = false) -> Dictionary:
	var before: Dictionary = e.snapshot()
	var result: Dictionary = e.call(method, token)
	var after: Dictionary = e.snapshot()
	check(result == {"status": status, "reason_code": reason}, "exact owned settlement result %s %s" % [method, reason])
	check(after == before if no_delta else after.revision == before.revision + 1, "N-all or one publication")
	if not no_delta:
		check(after.generation == before.generation and after.session == before.session, "identity stable")
		check(after.initial_party == before.initial_party and after.initial_enemies == before.initial_enemies,
			"complete original roster retained")
		check(after.clocks == before.clocks and after.plan == before.plan and after.phase == before.phase,
			"no clock/round effects")
		check(after.outcome.is_empty() and after.summary.is_empty(), "no terminal/outcome/summary implementation")
		if method != "impact":
			check(after.actors == before.actors, "completion/cancel N-effect entire actor domain")
		else:
			for id in before.actors:
				if id != token.actor_id:
					check(after.actors[id] == before.actors[id], "unrelated actor unchanged " + id)
	if not no_delta:
		var unrelated: Dictionary = after.duplicate(true)
		for field in ["revision", "active_operation", "authorizations", "action_receipts", "queue", "actors"]:
			unrelated[field] = before[field]
		check(unrelated == before, "every unrelated published root domain unchanged")
		for id in before.authorizations:
			if id != token.action_id: check(after.authorizations[id] == before.authorizations[id], "unrelated grant immutable")
		check(after.authorizations[token.action_id].token == token, "token audit identity immutable")
		check(e._valid_candidate(after), "full root accounting valid after settlement")
		if method == "impact":
			var expected_actor: Dictionary = before.actors[token.actor_id].duplicate(true)
			expected_actor.state.participation = "RETREATED"
			expected_actor.state.eligible = false
			check(after.actors[token.actor_id] == expected_actor, "exact participation effect preserves definition/HP/all other fields")
			check(after.queue == before.queue and after.action_receipts == before.action_receipts, "impact N-queue and N-receipt")
		else:
			check(after.queue.cursor == before.queue.cursor + 1, "disposal advances cursor once")
	current.steps.append({"method": method, "input": token.duplicate(true) if token is Dictionary else token,
		"expected_reason": reason, "expected_status": status, "N_all": no_delta,
		"actual": result, "before": before, "after": after})
	return result


func _compatibility() -> void:
	begin("N50-INT-01A pure structural revision independent of cursor; legal A skip revision")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	state(f, "n1", "DOWN", 0)
	var e = fresh(f)
	advance(e)
	var before: Dictionary = e.snapshot()
	var c: Dictionary = before.duplicate(true)
	c.revision += 2
	check(Adapter.valid_queue(c), "structural revisions may include future authorized action publications")
	var skip: Dictionary = Adapter.unavailable_candidate(c)
	check(skip.queue.dispositions[skip.queue.opportunities[1].opportunity_id].observed_revision == 3,
		"historical observed revision is actual input revision, not index1")
	check(Adapter.valid_queue(skip), "interleaved global revision history valid structurally")
	check(e._publish(skip, before.revision) == "M403_INVALID_CANDIDATE", "synthetic history cannot publish")
	check(e.snapshot() == before, "synthetic diagnostic N-all")
	current.steps.append({"kind": "PURE_STRUCTURAL_NOT_ACTION", "input": c, "actual": skip,
		"before": before, "after": e.snapshot()})
	end()
	begin("N50-INT-01B historical unavailability independent of future restored eligibility, no reinsertion")
	e = fresh(f)
	advance(e)
	before = e.snapshot()
	c = before.duplicate(true)
	c.actors.p.state.current_hp = 1
	c.actors.p.state.life_state = "ALIVE"
	c.actors.p.state.eligible = true
	check(Adapter.valid_queue(c), "historical DOWN observation survives pure future ALIVE structural model")
	check(c.queue.cursor == 1 and c.queue.opportunities == before.queue.opportunities,
		"structural restoration cannot add/rewind opportunity")
	check(not Adapter.eligibility(c, "p").slot_eligible, "restored past actor has no opportunity")
	check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "no legal RESCUE producer in B; synthetic import denied")
	check(e.snapshot() == before, "pure diagnostic never mutates authority")
	current.steps.append({"kind": "PURE_STRUCTURAL_NOT_RESCUE", "input": c, "before": before, "after": e.snapshot()})
	end()
	for variant in range(7):
		begin("Forged historical disposition %s rejected structurally and N-all" % variant)
		e = fresh(f)
		before = e.snapshot()
		c = Adapter.unavailable_candidate(before)
		var d: Dictionary = c.queue.dispositions[c.queue.opportunities[0].opportunity_id]
		match variant:
			0: d.issuer_id = "foreign"
			1: d.observed_revision = 1
			2: d.observed_revision = -1
			3: d.observed_actor = before.actors.n2
			4: d.observed_actor.state.eligible = true
			5: d.actor_id = "n1"
			6: d.extra = true
		check(not Adapter.valid_queue(c), "forged structural history rejected")
		check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "exact publication rejects forged history")
		check(e.snapshot() == before, "full root N-all")
		current.steps.append({"kind": "INVALID_CANDIDATE", "input": c, "before": before, "after": e.snapshot()})
		end()


func _real_compatibility() -> void:
	begin("N50-INT-01A real lock/impact/completion interleaved unavailable skip uses actual revision")
	var f: Dictionary = fixture()
	state(f, "n1", "DOWN", 0)
	var e = bfresh(f)
	var initial: Dictionary = e.snapshot()
	var token: Dictionary = lock(e)
	check(e.snapshot().revision == 1 and e.queue_snapshot().cursor == 0, "lock revision1 cursor0")
	check(e.snapshot().actors == initial.actors and e.queue_snapshot().phase == "WAIT_ACTION", "lock N-effect; WAIT_ACTION")
	advance(e, "M403_ACTION_IN_PROGRESS", "REJECTED", true)
	settle(e, "impact", token, "M403_RETREATED", "APPLIED")
	check(e.snapshot().revision == 2 and e.queue_snapshot().cursor == 0, "impact revision2 cursor0")
	check(e.actor_snapshot("p").state.current_hp == 10 and e.actor_snapshot("p").state.participation == "RETREATED",
		"retreat keeps HP, only participation/derived eligibility change")
	check(not e.eligibility_snapshot("p").queue_opportunity_available, "retreated actor cannot lock another opportunity")
	settle(e, "complete", token, "M403_ACTION_COMPLETED", "APPLIED")
	check(e.snapshot().revision == 3 and e.queue_snapshot().cursor == 1, "completion revision3 cursor1")
	advance(e)
	var q: Dictionary = e.queue_snapshot()
	check(q.cursor == 2 and e.snapshot().revision == 4, "skip after completion uses one opportunity")
	check(q.dispositions[q.opportunities[1].opportunity_id].observed_revision == 3,
		"skip actual observed revision3 differs from slot index1")
	token = lock(e, "npc-retreat")
	settle(e, "impact", token, "M403_RETREATED", "APPLIED")
	settle(e, "complete", token, "M403_ACTION_COMPLETED", "APPLIED")
	check(e.snapshot().revision == 7 and e.queue_snapshot().cursor == 3, "interleaved real publications monotonic")
	check(e.snapshot().action_receipts.size() == 2 and e.snapshot().authorizations.size() == 2,
		"two owned completions and one unavailable history")
	check(e._valid_candidate(e.snapshot()), "all action accounting validates after every publication")
	end()
	begin("N50-INT-01A cancellation revision2 cursor1 followed by unavailable skip")
	f = fixture()
	state(f, "n1", "DOWN", 0)
	e = bfresh(f)
	token = lock(e)
	settle(e, "cancel", token, "M403_ACTION_CANCELLED", "APPLIED")
	check(e.snapshot().revision == 2 and e.queue_snapshot().cursor == 1, "cancel advances exactly once")
	advance(e)
	check(e.snapshot().revision == 3 and e.queue_snapshot().cursor == 2, "skip observed revision2 not index1")
	check(e.snapshot().action_receipts.is_empty(), "cancel and unavailable are never completed receipts")
	end()


func _retreat_success() -> void:
	for actor in ["p", "n1"]:
		begin("Valid %s self-retreat has immutable exact15 token, retained ID/HP and one owned receipt" % actor)
		var e = bfresh()
		if actor == "n1":
			var first: Dictionary = lock(e, "first-cancel")
			settle(e, "cancel", first, "M403_ACTION_CANCELLED", "APPLIED")
		var before: Dictionary = e.snapshot()
		var t: Dictionary = lock(e)
		check(t.size() == 15 and t.target_id == actor and t.actor_id == actor and t.episode_id == "", "exact self identity")
		check(e.snapshot().actors == before.actors, "lock N-effect")
		settle(e, "complete", t, "M403_INVALID_PHASE", "REJECTED", true)
		settle(e, "impact", t, "M403_RETREATED", "APPLIED")
		var impacted: Dictionary = e.snapshot()
		check(impacted.actors[actor].state.current_hp == before.actors[actor].state.current_hp, "HP unchanged")
		check(impacted.actors[actor].definition == before.actors[actor].definition, "ID/role/maxHP retained")
		check(impacted.authorizations[t.action_id].token == t, "immutable lock_revision and full token unchanged")
		check(impacted.queue.cursor == before.queue.cursor, "impact does not consume opportunity")
		settle(e, "impact", t, "M403_DUPLICATE_OPERATION", "REJECTED", true)
		settle(e, "cancel", t, "M403_INVALID_PHASE", "REJECTED", true)
		settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
		settle(e, "complete", t, "M403_DUPLICATE_OPERATION", "REJECTED", true)
		settle(e, "impact", t, "M403_DUPLICATE_OPERATION", "REJECTED", true)
		settle(e, "cancel", t, "M403_DUPLICATE_OPERATION", "REJECTED", true)
		check(e.queue_snapshot().cursor == before.queue.cursor + 1, "no duplicate slot disposal")
		check(e.snapshot().action_receipts.size() == 1, "one actual receipt only")
		check(e.snapshot().actors.keys() == before.actors.keys(), "registry membership retained")
		end()
	begin("Player DOWN skipped; eligible NPC owns real retreat and completion without Player command")
	var down_fixture: Dictionary = fixture()
	state(down_fixture, "p", "DOWN", 0)
	var npc_encounter = bfresh(down_fixture)
	advance(npc_encounter)
	var npc_token: Dictionary = lock(npc_encounter, "npc-after-down")
	settle(npc_encounter, "impact", npc_token, "M403_RETREATED", "APPLIED")
	settle(npc_encounter, "complete", npc_token, "M403_ACTION_COMPLETED", "APPLIED")
	check(npc_encounter.actor_snapshot("p").state.life_state == "DOWN" and npc_encounter.queue_snapshot().cursor == 2,
		"Player unchanged and no reinsert/automatic defeat/clock tick")
	end()
	begin("Pre-impact cancellation consumes one slot; replay reason precedence is exact")
	var e = bfresh()
	var t: Dictionary = lock(e)
	settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
	settle(e, "impact", t, "M403_ACTION_CANCELLED", "REJECTED", true)
	settle(e, "complete", t, "M403_ACTION_CANCELLED", "REJECTED", true)
	settle(e, "cancel", t, "M403_DUPLICATE_OPERATION", "REJECTED", true)
	var r: Dictionary = lock_request(e, "new")
	r.actor_id = "p"
	r.slot_id = t.slot_id
	observe(e, "lock_self_retreat", r, authority, "M403_WRONG_SLOT", "REJECTED", true)
	check(e.snapshot().action_receipts.is_empty() and e.queue_snapshot().cursor == 1, "no refund/free action or receipt")
	end()
	begin("Nonterminal all-cancel Party queue skips unavailable enemy then stops at living enemy")
	var f: Dictionary = fixture()
	state(f, "a", "", 0)
	e = bfresh(f)
	for i in range(4):
		t = lock(e, "cancel-%s" % i)
		settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
	advance(e)
	advance(e, "M403_SLOT_READY", "READY", true)
	check(e.queue_snapshot().cursor == 5 and e.queue_snapshot().phase == "READY", "finite traversal stops at living Enemy B")
	check(e.current_opportunity().actor_id == "b", "no fake Enemy action/receipt or artificial drain")
	check(e.snapshot().phase == "OPEN" and e.snapshot().action_receipts.is_empty(), "no fake completion/round")
	for method in ["seal", "close", "open_round", "abort", "classify", "import_receipt", "lock_rescue"]:
		check(not e.has_method(method), "C/other producers absent " + method)
	end()


func _lock_rejections() -> void:
	for field in Encounter.RETREAT_FIELDS:
		begin("Lock exact schema rejects missing or wrong-type field " + field)
		var e = bfresh()
		var r: Dictionary = lock_request(e)
		r.erase(field)
		observe(e, "lock_self_retreat", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
		r = lock_request(e)
		r[field] = []
		observe(e, "lock_self_retreat", r, authority, "M403_INVALID_FIELDS", "REJECTED", true)
		end()
	for variant in range(16):
		begin("Lock protocol/authentication/domain precedence variant%s is N-all" % variant)
		var e = bfresh()
		var r: Dictionary = lock_request(e)
		var cap: Variant = authority
		var reason: String = "M403_INVALID_FIELDS"
		match variant:
			0: r.target_id = "n1"
			1: r.kind = "RESCUE"
			2: r.version = 2
			3: r.request_id = ""
			4:
				r.session += 1
				cap = null
				reason = "M403_FOREIGN_SESSION"
			5:
				r.generation += 1
				cap = null
				reason = "M403_STALE_GENERATION"
			6:
				cap = null
				reason = "M403_UNAUTHORIZED"
			7:
				cap = RefCounted.new()
				reason = "M403_UNAUTHORIZED"
			8:
				r.queue_id = "wrong"
				r.expected_revision = -1
				reason = "M403_WRONG_QUEUE"
			9:
				r.slot_id = "wrong"
				r.expected_revision = -1
				reason = "M403_WRONG_SLOT"
			10:
				r.actor_id = "unknown"
				reason = "M403_WRONG_SLOT"
			11:
				r.actor_id = "n1"
				reason = "M403_WRONG_SLOT"
			12:
				r.expected_revision = -1
				reason = "M403_STALE_REVISION"
			13: r.expected_revision = true
			14: r.expected_revision = 0.0
			15: r.actor_id = 1
		observe(e, "lock_self_retreat", r, cap, reason, "REJECTED", true)
		end()
	for id in ["slot_3_p", "slot_4_p", "slot_999_future", "m403/queue/foreign/slot/99"]:
		begin("Reserved current/future namespace cannot be preempted by " + id)
		var e = bfresh()
		observe(e, "lock_self_retreat", lock_request(e, id), authority, "M403_RESERVED_OPERATION_ID", "REJECTED", true)
		var t: Dictionary = lock(e, "legal")
		check(t.action_id == 1 and t.authorization_id == 1, "invalid reservation does not consume counters")
		end()
	for spec in [["DOWN", 0, "PRESENT"], ["DEAD", 0, "PRESENT"], ["ALIVE", 10, "RETREATED"]]:
		begin("Unavailable actor %s/%s lock rejects without effect" % [spec[0], spec[2]])
		var f: Dictionary = fixture()
		state(f, "p", spec[0], spec[1], spec[2])
		var e = bfresh(f)
		observe(e, "lock_self_retreat", lock_request(e), authority, "M403_ACTOR_UNAVAILABLE", "REJECTED", true)
		end()
	begin("Enemy current slot cannot RETREAT; D14 HP state remains original")
	var f: Dictionary = fixture()
	for id in ["p", "n1", "n2", "n3"]: state(f, id, "DOWN", 0)
	var e = bfresh(f)
	for i in range(4): advance(e)
	observe(e, "lock_self_retreat", lock_request(e), authority, "M403_PARTY_ONLY", "REJECTED", true)
	end()
	begin("Duplicate request checked before phase/current revision; active action blocks second grant and skip")
	e = bfresh()
	var r: Dictionary = lock_request(e)
	var t: Dictionary = lock(e)
	observe(e, "lock_self_retreat", r, authority, "M403_DUPLICATE_OPERATION", "REJECTED", true)
	observe(e, "lock_self_retreat", lock_request(e, "second"), authority, "M403_ACTION_IN_PROGRESS", "REJECTED", true)
	advance(e, "M403_ACTION_IN_PROGRESS", "REJECTED", true)
	settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
	observe(e, "lock_self_retreat", lock_request(e), authority, "M403_DUPLICATE_OPERATION", "REJECTED", true)
	end()
	begin("Last-active Party retreat rejects before lock with complete N-all and no terminal producer")
	f = fixture()
	for id in ["n1", "n2", "n3"]: state(f, id, "DOWN", 0)
	e = bfresh(f)
	observe(e, "lock_self_retreat", lock_request(e), authority, "M403_BOUNDARY_DEPENDENCY", "REJECTED", true)
	check(e.snapshot().authorizations.is_empty() and e.queue_snapshot().cursor == 0, "no partial lock/effect")
	end()


func _token_rejections() -> void:
	for field in Encounter.TOKEN_FIELDS:
		begin("Owned token field " + field + " cannot be removed, mistyped or altered")
		var e = bfresh()
		var t: Dictionary = lock(e)
		for variant in range(3):
			var invalid: Dictionary = t.duplicate(true)
			var reason: String = "M403_INVALID_FIELDS"
			match variant:
				0: invalid.erase(field)
				1: invalid[field] = []
				2:
					invalid[field] = t[field] + (1 if field in Encounter.TOKEN_INTS else "-forged")
					reason = "M403_FOREIGN_SESSION" if field == "session" else ("M403_STALE_GENERATION" if field == "generation" else "M403_UNAUTHORIZED")
					if field == "version": reason = "M403_INVALID_FIELDS"
			for method in ["impact", "complete", "cancel"]:
				settle(e, method, invalid, reason, "REJECTED", true)
		end()
	begin("Foreign encounter and malformed root tokens reject without exposing domain")
	var e = bfresh()
	var t: Dictionary = lock(e)
	var other = bfresh()
	for method in ["impact", "complete", "cancel"]:
		settle(other, method, t, "M403_FOREIGN_SESSION", "REJECTED", true)
		for bad in [null, [], 1, {}, true]: settle(e, method, bad, "M403_INVALID_FIELDS", "REJECTED", true)
	var before: Dictionary = e.snapshot()
	t.actor_id = "n1"
	check(e.snapshot() == before, "returned token detached from immutable owned record")
	end()


func _restart_actions() -> void:
	for phase in ["LOCKED", "APPLIED", "COMPLETED", "CANCELLED"]:
		begin("Restart from " + phase + " clears all accounting and stales every old callback")
		var e = bfresh()
		var t: Dictionary = lock(e)
		if phase in ["APPLIED", "COMPLETED"]: settle(e, "impact", t, "M403_RETREATED", "APPLIED")
		if phase == "COMPLETED": settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
		if phase == "CANCELLED": settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
		var before: Dictionary = e.snapshot()
		var invalid: Dictionary = fixture()
		invalid.actors[-1].state.current_hp = -1
		observe(e, "restart", reset_request(e, invalid), authority, "M403_INVALID_RESTART", "REJECTED", true)
		observe(e, "restart", reset_request(e, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
		var after: Dictionary = e.snapshot()
		check(after.generation == before.generation + 1 and after.revision == 0 and after.queue.cursor == 0, "new generation revision0 cursor0")
		check(after.active_operation == null and after.authorizations.is_empty() and after.action_receipts.is_empty(), "old grants/active/receipts gone")
		check(after.queue.queue_id != before.queue.queue_id and after.queue.opportunities[0].slot_id != t.slot_id, "new queue/slot identities")
		for method in ["impact", "complete", "cancel"]: settle(e, method, t, "M403_STALE_GENERATION", "REJECTED", true)
		var new: Dictionary = lock(e)
		check(new.action_id == 1 and new.generation != t.generation, "generation binds reused serial/actor/request ID")
		end()
	begin("Invalid restart retains pending legitimate token through impact/completion")
	var e = bfresh()
	var t: Dictionary = lock(e)
	observe(e, "restart", reset_request(e, {}), authority, "M403_INVALID_RESTART", "REJECTED", true)
	settle(e, "impact", t, "M403_RETREATED", "APPLIED")
	settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
	end()


func _candidate_integrity() -> void:
	for phase in ["LOCKED", "APPLIED", "COMPLETED", "CANCELLED"]:
		for variant in range(10):
			begin("Candidate accounting integrity %s fault%s rejects whole root" % [phase, variant])
			var e = bfresh()
			var t: Dictionary = lock(e)
			if phase in ["APPLIED", "COMPLETED"]: settle(e, "impact", t, "M403_RETREATED", "APPLIED")
			if phase == "COMPLETED": settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
			if phase == "CANCELLED": settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
			var before: Dictionary = e.snapshot()
			var c: Dictionary = before.duplicate(true)
			match variant:
				0: c.revision += 1
				1: c.queue.cursor = 6
				2: c.authorizations[1].token.target_id = "n1"
				3: c.authorizations[1].token.lock_revision += 1
				4: c.authorizations[1].phase = "FORGED"
				5: c.action_receipts.fake = {"completed": true}
				6: c.active_operation = 99
				7: c.queue.phase = "READY" if c.queue.phase == "WAIT_ACTION" else "WAIT_ACTION"
				8: c.authorizations[1].disposed_revision = 99
				9: c.authorizations[1].impact_revision = 99
			check(not e._valid_candidate(c), "full structural action/cursor/receipt accounting rejects")
			check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "original publication rejects arbitrary action import")
			check(e.snapshot() == before, "invalid candidate N-all")
			current.steps.append({"kind": "INVALID_CANDIDATE", "input": c, "before": before, "after": e.snapshot()})
			end()
	for variant in range(15):
		begin("Malformed candidate with owned action fault%s fails closed without engine error" % variant)
		var e = bfresh()
		var t: Dictionary = lock(e)
		var before: Dictionary = e.snapshot()
		var c: Dictionary = before.duplicate(true)
		match variant:
			0: c.queue.opportunities[0] = null
			1: c.queue.opportunities[0] = {}
			2: c.queue.opportunities[0].actor_id = 1
			3: c.queue.opportunities[0].slot_id = false
			4: c.authorizations[1] = null
			5: c.authorizations[1].token = []
			6: c.authorizations[1].token.action_id = 1.0
			7: c.authorizations[1].impact_revision = true
			8: c.action_receipts = []
			9: c.active_operation = true
			10: c.queue.dispositions = []
			11: c.queue.opportunities = {}
			12: c.queue.cursor = 0.0
			13: c.authorizations = []
			14: c.authorizations[1].phase = 1
		check(not e._valid_candidate(c), "malformed full candidate rejected")
		check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "publication fail closed")
		check(e.snapshot() == before, "whole root N-all")
		current.steps.append({"kind": "MALFORMED_CANDIDATE", "input": c, "before": before, "after": e.snapshot()})
		end()
	begin("Forged plausible historical observation cannot rewrite authentic prior history")
	var f: Dictionary = fixture()
	state(f, "p", "DOWN", 0)
	state(f, "n1", "DOWN", 0)
	var e = bfresh(f)
	advance(e)
	var before: Dictionary = e.snapshot()
	var c: Dictionary = Adapter.unavailable_candidate(before)
	c.queue.dispositions[c.queue.opportunities[0].opportunity_id].observed_actor.state.life_state = "DEAD"
	check(e._valid_candidate(c), "plausible history can be structurally valid without being owned")
	check(e._publish(c, before.revision) == "M403_INVALID_CANDIDATE", "exact transition forbids replacing historical facts")
	check(e.snapshot() == before, "forged history N-all")
	end()


func _publication_failures() -> void:
	for operation in ["LOCK", "IMPACT", "COMPLETE", "CANCEL"]:
		begin("Candidate-validation failure during " + operation + " is N-all; legitimate retry still works")
		var e = RejectingEncounter.new(authority)
		observe(e, "restart", reset_request(e, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
		var t: Dictionary = {}
		if operation != "LOCK": t = lock(e)
		if operation == "COMPLETE": settle(e, "impact", t, "M403_RETREATED", "APPLIED")
		e.reject_candidate = true
		if operation == "LOCK":
			observe(e, "lock_self_retreat", lock_request(e), authority, "M403_INVALID_CANDIDATE", "REJECTED", true)
		else:
			settle(e, operation.to_lower(), t, "M403_INVALID_CANDIDATE", "REJECTED", true)
		e.reject_candidate = false
		match operation:
			"LOCK":
				t = lock(e)
				check(t.action_id == 1, "failed publication never consumes serial/namespace")
			"IMPACT": settle(e, "impact", t, "M403_RETREATED", "APPLIED")
			"COMPLETE": settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
			"CANCEL": settle(e, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
		end()
	begin("Detached snapshots/grants/receipts cannot mutate published authority")
	var e = bfresh()
	var t: Dictionary = lock(e)
	settle(e, "impact", t, "M403_RETREATED", "APPLIED")
	settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
	var before: Dictionary = e.snapshot()
	var copy: Dictionary = e.snapshot()
	copy.authorizations[1].token.actor_id = "n1"
	copy.action_receipts[1].completed_revision = 99
	copy.queue.dispositions.clear()
	copy.actors.p.state.participation = "PRESENT"
	check(e.snapshot() == before, "all nested accessors detached")
	end()


func _bounded_diagnostics() -> void:
	for spec in [["DOWN", 0, "PRESENT"], ["DEAD", 0, "PRESENT"], ["ALIVE", 10, "RETREATED"]]:
		begin("DIAGNOSTIC-ONLY impact revalidation %s/%s; no legal damage producer claimed" % [spec[0], spec[2]])
		var e = bfresh()
		var t: Dictionary = lock(e)
		var before: Dictionary = e.snapshot()
		var scratch: Dictionary = before.duplicate(true)
		scratch.actors.p.state.current_hp = spec[1]
		scratch.actors.p.state.life_state = spec[0]
		scratch.actors.p.state.participation = spec[2]
		scratch.actors.p.state.eligible = false
		check(e._valid_candidate(scratch), "pure bounded observation structurally valid")
		var impacted: Dictionary = Adapter.retreat_candidate(scratch, "IMPACT", t)
		check(impacted.authorizations[1].phase == "SKIPPED" and impacted.authorizations[1].impact_reason == "M403_ACTOR_UNAVAILABLE",
			"pure semantic revalidation records SKIPPED/N-effect")
		check(impacted.actors == scratch.actors and impacted.queue.cursor == 0, "skip changes no actor and does not complete")
		check(e._valid_candidate(impacted), "skipped candidate full validation")
		var completed: Dictionary = Adapter.retreat_candidate(impacted, "COMPLETE", t)
		check(e._valid_candidate(completed) and completed.queue.cursor == 1 and completed.action_receipts.size() == 1,
			"pure skipped completion has one receipt and one disposition")
		check(completed.actors == scratch.actors and e.snapshot() == before, "all diagnostic work stays detached; live N-all")
		current.steps.append({"kind": "PURE_BOUNDED_NO_DAMAGE_PRODUCER", "input": scratch, "actual": completed,
			"before": before, "after": e.snapshot()})
		end()
	begin("DIAGNOSTIC-ONLY last-active pre-impact dependency after legal lock; no concurrent producer")
	var e = bfresh()
	var t: Dictionary = lock(e)
	var before: Dictionary = e.snapshot()
	var scratch: Dictionary = before.duplicate(true)
	for id in ["n1", "n2", "n3"]:
		scratch.actors[id].state.current_hp = 0
		scratch.actors[id].state.life_state = "DOWN"
		scratch.actors[id].state.eligible = false
	check(e._valid_candidate(scratch) and Adapter.active_party(scratch) == 1, "last-active condition structurally expressible")
	check(e.snapshot() == before, "cannot legally reach changed availability inside serial B; no synthetic effect publication")
	current.steps.append({"kind": "PURE_BOUNDARY_PREDICATE_ONLY", "input": scratch, "before": before, "after": e.snapshot()})
	end()

	begin("DIAGNOSTIC-ONLY actual pre-impact boundary rejection with detached last-active observation")
	var observed = BoundaryObservation.new(authority)
	observe(observed, "restart", reset_request(observed, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
	t = lock(observed)
	before = observed.snapshot()
	observed.observe_last_active = true
	settle(observed, "impact", t, "M403_BOUNDARY_DEPENDENCY", "REJECTED", true)
	observed.observe_last_active = false
	check(observed.snapshot() == before, "authoritative root remains LOCKED/PRESENT with original HP/roster")
	settle(observed, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
	end()


func _r51_nonterminal_gate() -> void:
	begin("R51-01 all Enemy HP0: identical RETREAT requests reject N-all without grants or serial consumption")
	var f: Dictionary = fixture()
	for id in ["a", "b"]: state(f, id, "", 0)
	var e = bfresh(f)
	var before: Dictionary = e.snapshot()
	var r: Dictionary = lock_request(e)
	for i in range(3):
		observe(e, "lock_self_retreat", r, authority, "M403_BOUNDARY_DEPENDENCY", "REJECTED", true)
	check(e.snapshot() == before and before.revision == 0 and before.queue.cursor == 0, "entire root including revision/cursor unchanged")
	check(e.snapshot().authorizations.is_empty() and e.snapshot().action_receipts.is_empty()
		and e.snapshot().active_operation == null, "no grant/receipt/active token or derived serial allocation")
	check(e.snapshot().outcome.is_empty() and e.snapshot().summary.is_empty(), "no fake terminal classification/freeze")
	observe(e, "restart", reset_request(e, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
	var t: Dictionary = lock(e)
	check(t.action_id == 1 and t.authorization_id == 1, "corrected legal fixture starts at first owned serial")
	settle(e, "impact", t, "M403_RETREATED", "APPLIED")
	settle(e, "complete", t, "M403_ACTION_COMPLETED", "APPLIED")
	end()
	for variant in range(7):
		begin("R51-01 zero Enemy precedence variant%s beats boundary dependency" % variant)
		e = bfresh(f)
		r = lock_request(e)
		var cap: Variant = authority
		var reason: String = "M403_INVALID_FIELDS"
		match variant:
			0: r.target_id = "p"
			1:
				cap = null
				reason = "M403_UNAUTHORIZED"
			2:
				r.queue_id = "wrong"
				reason = "M403_WRONG_QUEUE"
			3:
				r.expected_revision = -1
				reason = "M403_STALE_REVISION"
			4:
				r.session += 1
				reason = "M403_FOREIGN_SESSION"
			5:
				r.slot_id = "wrong"
				reason = "M403_WRONG_SLOT"
			6:
				r.request_id = "slot_4_future"
				reason = "M403_RESERVED_OPERATION_ID"
		observe(e, "lock_self_retreat", r, cap, reason, "REJECTED", true)
		end()
	begin("R51-01 authoritative LOCK publication rejects zero Enemy dependency without candidate import")
	e = bfresh(f)
	before = e.snapshot()
	t = Adapter.retreat_token(before, lock_request(e))
	check(e._retreat_transition_reason(before, "LOCK", t) == "M403_BOUNDARY_DEPENDENCY", "owned publication boundary rejects zero Enemy LOCK")
	check(e._publish_retreat("LOCK", t, before.revision) == "M403_BOUNDARY_DEPENDENCY", "private publication gate also checks boundary")
	check(e.snapshot() == before, "publication gate refusal full N-all")
	current.steps.append({"kind": "AUTHORITATIVE_LOCK_GATE", "input": t, "before": before, "after": e.snapshot()})
	end()
	begin("R51-01 DIAGNOSTIC-ONLY zero Enemy observation before impact blocks effect and publication")
	var observed = BoundaryObservation.new(authority)
	observe(observed, "restart", reset_request(observed, fixture()), authority, "M403_RESTARTED", "APPLIED", false)
	t = lock(observed)
	before = observed.snapshot()
	observed.observe_no_enemies = true
	var scratch: Dictionary = observed.snapshot()
	settle(observed, "impact", t, "M403_BOUNDARY_DEPENDENCY", "REJECTED", true)
	check(observed._retreat_transition_reason(scratch, "IMPACT", t) == "M403_BOUNDARY_DEPENDENCY", "publication revalidation denies effect")
	check(observed._publish_retreat("IMPACT", t, before.revision) == "M403_BOUNDARY_DEPENDENCY", "authoritative publication cannot bypass zero Enemy check")
	observed.observe_no_enemies = false
	check(observed.snapshot() == before, "real root unchanged; no Enemy damage producer or partial retreat")
	current.steps.append({"kind": "DETACHED_ZERO_ENEMY_OBSERVATION_NOT_DAMAGE", "input": scratch, "before": before, "after": observed.snapshot()})
	settle(observed, "cancel", t, "M403_ACTION_CANCELLED", "APPLIED")
	end()
	for method in ["COMPLETE", "CANCEL"]:
		begin("R51-01 DIAGNOSTIC-ONLY zero Enemy boundary does not revoke owned " + method)
		e = bfresh()
		t = lock(e)
		if method == "COMPLETE": settle(e, "impact", t, "M403_RETREATED", "APPLIED")
		before = e.snapshot()
		scratch = before.duplicate(true)
		for id in scratch.initial_enemies:
			scratch.actors[id].state.current_hp = 0
			scratch.actors[id].state.can_act = false
		check(e._token_reason(t, method) == "", "legal owned settlement token still authorized")
		check(e._retreat_transition_reason(scratch, method, t) == "", "boundary gate applies only to new Lock/Impact")
		check(e.snapshot() == before, "pure settlement diagnostic cannot publish Enemy state")
		current.steps.append({"kind": "PURE_SETTLEMENT_ADMISSION_NOT_DAMAGE", "input": scratch, "before": before, "after": e.snapshot()})
		settle(e, method.to_lower(), t, "M403_ACTION_COMPLETED" if method == "COMPLETE" else "M403_ACTION_CANCELLED", "APPLIED")
		end()


func _run() -> void:
	_compatibility()
	_real_compatibility()
	_retreat_success()
	_lock_rejections()
	_token_rejections()
	_restart_actions()
	_candidate_integrity()
	_bounded_diagnostics()
	_publication_failures()
	_r51_nonterminal_gate()
	var report: Dictionary = {"suite": "M4-03B retreat transaction", "independent_cases": cases.size(),
		"assertion_checks": checks, "failures": failures, "per_frame_checks": 0, "cases": cases,
		"deferred": ["RESCUE live interleaving", "M4-03C terminal/round integration"]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file == null:
				quit(1)
				return
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RESULT: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
