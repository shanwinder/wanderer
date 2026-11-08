extends SceneTree

const Facade = preload("res://scripts/m4/m404_decision_facade.gd")
const Context = preload("res://scripts/m4/m404_decision_context.gd")
const Policy = preload("res://scripts/m4/m404_autonomous_decision_policy.gd")
const OrderProjection = preload("res://scripts/m4/m404_episode_order_projection.gd")
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const Guided = preload("res://scripts/combat/guided_encounter.gd")
var authority := RefCounted.new()
var cases: Array = []
var current: Dictionary = {}
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func begin(expected: String, classification: String = "EXECUTABLE PURE POLICY") -> void:
	current = {"id": "M404-%03d" % (cases.size() + 1), "expected": expected, "classification": classification,
		"assertions": [], "steps": [], "assertion_count": 0, "failure_count": 0, "actual": "PASS"}

func check(ok: bool, description: String) -> void:
	checks += 1
	current.assertions.append({"description": description, "passed": ok})
	if not ok:
		failures += 1
		current.failure_count += 1
		print("FAIL: %s %s" % [current.id, description])

func end() -> void:
	current.assertion_count = current.assertions.size()
	current.actual = "PASS" if current.failure_count == 0 else "FAIL"
	cases.append(current)
	print("CASE %s: %s" % [current.id, current.actual])

func reason(result: Dictionary, expected: String) -> void:
	check(result.reason_code == expected, "reason expected %s actual %s" % [expected, result])
	current.steps.append({"expected_reason": expected, "actual_reason": result.reason_code})

func fixture() -> Dictionary:
	var rows: Array = []
	for id in ["p", "n", "j", "t", "a", "b"]:
		var role: String = "PLAYER" if id == "p" else ("ENEMY" if id in ["a", "b"] else "NPC")
		rows.append({"definition": {"actor_id": id, "display_name": id, "role": role, "base_max_hp": 100},
			"state": {"current_hp": 100} if role == "ENEMY" else {"current_hp": 100, "life_state": "ALIVE", "participation": "PRESENT"}})
	var plan: Array = []
	for r in range(3, 7): plan.append({"round_id": r, "actor_order": ["p", "n", "j", "t", "a", "b"]})
	return {"actors": rows, "round_plan": plan, "clocks": {}}

func state(f: Dictionary, id: String, hp: int, life: String = "ALIVE") -> void:
	for row in f.actors:
		if row.definition.actor_id == id: row.state = {"current_hp": hp, "life_state": life, "participation": "PRESENT"}

func request(e, round_request: bool = false) -> Dictionary:
	var v: Dictionary = e.snapshot()
	var r: Dictionary = {"version": 1, "session": v.session, "generation": v.generation, "expected_revision": v.revision, "queue_id": v.queue.get("queue_id", "")}
	if round_request: r.round_id = v.round_id + int(v.phase == "CLOSED")
	return r

func reset(e, f: Dictionary) -> void:
	var r: Dictionary = request(e)
	r.fixture = f
	reason(e.restart(r, authority), "M403_RESTARTED")
	reason(e.open_round(request(e, true), authority), "M403_ROUND_OPENED")

func lock(e, kind: String, target: String = "a", amount: int = 1) -> Dictionary:
	var r: Dictionary = request(e)
	var slot: Dictionary = e.current_opportunity()
	r.merge({"slot_id": slot.slot_id, "actor_id": slot.actor_id, "request_id": "fixture_%s" % r.expected_revision, "kind": kind})
	if kind != "RETREAT": r.target_id = target
	if kind == "ATTACK": r.amount = amount
	return e.call("lock_self_retreat" if kind == "RETREAT" else ("lock_fixture_rescue" if kind == "RESCUE" else "lock_fixture_attack"), r, authority)

func finish(e, token: Dictionary) -> void:
	var result: Dictionary = e.impact(token)
	check(result.status == "APPLIED", "actual owned impact " + str(result))
	reason(e.complete(token), "M403_ACTION_COMPLETED")
	check(e.snapshot().action_receipts.has(token.action_id), "genuine owned completion receipt")

func fresh(f: Dictionary = fixture()):
	var e = Facade.new(authority)
	reset(e, f)
	# Only owner may dispose the actual Player slot; never synthetic receipt.
	if e.actor_snapshot("p").state.eligible:
		var grant: Dictionary = lock(e, "ATTACK")
		finish(e, grant.token)
	else: reason(e.advance(request(e), authority), "M403_SLOT_UNAVAILABLE")
	return e

func pure() -> Dictionary:
	var e = fresh()
	var c: Dictionary = e.decision_context()
	check(not c.is_empty(), "owner context acquired before labelled fixture derivation")
	c.source.observation_id = "LABELLED_PURE_FIXTURE"
	for p in c.party:
		if p.role == "NPC": p.help_uses = 1
	return c

func party(c: Dictionary, id: String) -> Dictionary:
	for p in c.party:
		if p.actor_id == id: return p
	return {}

func down(c: Dictionary, id: String, budget: int = 1, entry: int = 2, ordinal: int = 1) -> void:
	var p: Dictionary = party(c, id)
	p.current_hp = 0
	p.life_state = "DOWN"
	p.eligible = false
	p.episode = {"episode_id": "labelled_" + id + str(ordinal), "entry_round": entry, "budget": budget, "active": true, "entry_order": ordinal}

func expect(c: Dictionary, action: String, code: String, target: String = "") -> Dictionary:
	var before: Dictionary = c.duplicate(true)
	var r: Dictionary = Policy.decide(c)
	check(r.selected != null and r.selected.action == action, "expected candidate " + action + " actual " + str(r))
	check(r.decision_reason.code == code, "decision reason expected " + code)
	if not target.is_empty(): check(r.selected != null and r.selected.target_id == target, "exact target " + target)
	check(c == before and r.legal_effect.status == "CANDIDATE_ONLY", "pure N-all, candidate only")
	current.steps.append({"expected_reason": code, "actual_reason": r.decision_reason.code})
	return r

func guidance(c: Dictionary, kind: String, target: String = "") -> void:
	var i: Dictionary = {"encounter_id": 123, "generation": c.identity.generation, "round_id": c.identity.round_id,
		"guidance_revision": 2, "snapshot_revision": c.identity.snapshot_revision}
	c.frozen_guidance = {"identity": i, "record": {"guidance_type": kind, "issuer_player_id": c.player_id,
		"preferred_target_id": target, "encounter_id": 123, "generation": i.generation, "round_id": i.round_id, "guidance_revision": 2}}
	c.profile = Data.fixed_profile(c.actor_id, c.player_id)
	c.profile.discipline = "PLAN_ORIENTED"
	c.profile.courage = "CAUTIOUS"

func _priority() -> void:
	begin("Safety first versus urgent rescue; no active recipient refusal")
	var c: Dictionary = pure()
	down(c, "p")
	party(c, "n").current_hp = 3
	c.declared_hits[0].target_id = "n"
	var r: Dictionary = expect(c, "DEFEND", "SELF_LOW_HP_THREAT", "n")
	check(r.refusal_type == "HELPER_PRIORITY", "helper agency distinct from recipient refusal")
	party(c, "n").current_hp = 100
	expect(c, "RESCUE", "M404_URGENT_RESCUE", "p")
	end()
	begin("First valid hit, never aggregate or forecast")
	c = pure()
	party(c, "n").max_hp = 10
	party(c, "n").current_hp = 5
	c.declared_hits[0].target_id = "n"
	c.declared_hits[1].target_id = "n"
	expect(c, "ATTACK", "ATTACK_AVAILABLE_ENEMY")
	party(c, "n").current_hp = 3
	c.enemies[0].current_hp = 0
	c.enemies[0].available = false
	expect(c, "DEFEND", "SELF_LOW_HP_THREAT")
	c.enemies[1].current_hp = 0
	c.enemies[1].available = false
	check(Policy.decide(c).selected == null, "no enemies no fake attack/defend")
	end()
	begin("Lethal-hit Safety reason when not low HP")
	c = pure()
	party(c, "n").max_hp = 5
	party(c, "n").current_hp = 3
	c.declared_hits[0].target_id = "n"
	expect(c, "DEFEND", "SELF_LETHAL_THREAT")
	end()

	begin("Urgent vs HELP vs nonurgent changes one budget")
	c = pure()
	party(c, "p").current_hp = 30
	down(c, "t")
	expect(c, "RESCUE", "M404_URGENT_RESCUE", "t")
	party(c, "t").episode.budget = 2
	expect(c, "HELP", "PLAYER_LOW_HP_HELP", "p")
	party(c, "p").current_hp = 100
	expect(c, "RESCUE", "M404_NONURGENT_RESCUE", "t")
	end()
	for sample in [[1, 2, "M404_URGENT_RESCUE"], [2, 2, "M404_NONURGENT_RESCUE"], [2, 3, "M404_NONURGENT_RESCUE"], [1, 3, "INVALID"]]:
		begin("Grace boundary " + str(sample))
		c = pure()
		down(c, "t", sample[0], sample[1])
		if sample[2] == "INVALID": check(Policy.decide(c).selected == null, "B1/grace invalid")
		else: expect(c, "RESCUE", sample[2], "t")
		end()
	begin("Multiple DOWN budget/age/stable comparator, no Player favoritism")
	c = pure()
	down(c, "p", 1, 2, 2)
	down(c, "t", 1, 2, 1)
	expect(c, "RESCUE", "M404_URGENT_RESCUE", "t")
	party(c, "p").episode.budget = 2
	expect(c, "RESCUE", "M404_URGENT_RESCUE", "t")
	party(c, "t").episode.entry_order = 2
	check(Policy.decide(c).selected == null, "duplicate live ordinal rejects")
	check(Policy.less({"budget": 1, "entry_order": 1, "stable_party_index": 0}, {"budget": 1, "entry_order": 1, "stable_party_index": 1}), "comparator-only equal ordinal stable tie")
	end()
	begin("No resource is inability, not helper or recipient refusal")
	c = pure()
	down(c, "t")
	party(c, "n").rescue_uses = 0
	var no_use: Dictionary = expect(c, "ATTACK", "ATTACK_AVAILABLE_ENEMY")
	check(no_use.refusal_type == "NONE" and no_use.decision_reason.excluded[0].code == "NO_RESCUE_USE", "explicit no use reason")
	end()
	for hp in [30, 31]:
		begin("O3 exact threshold " + str(hp))
		c = pure()
		party(c, "n").current_hp = hp
		expect(c, "RETREAT" if hp == 30 else "ATTACK", "M404_SELF_PRESERVATION_RETREAT" if hp == 30 else "ATTACK_AVAILABLE_ENEMY", "n" if hp == 30 else "a")
		end()
	begin("RETREAT loses to every higher priority")
	c = pure()
	party(c, "n").current_hp = 30
	down(c, "t")
	expect(c, "RESCUE", "M404_URGENT_RESCUE")
	party(c, "t").episode.budget = 2
	expect(c, "RESCUE", "M404_NONURGENT_RESCUE")
	party(c, "p").current_hp = 30
	expect(c, "HELP", "PLAYER_LOW_HP_HELP")
	c.declared_hits[0].target_id = "n"
	expect(c, "DEFEND", "SELF_LOW_HP_THREAT")
	end()

func _schema() -> void:
	begin("Acquire schema test context")
	var c: Dictionary = pure()
	check(Context.validate(c).is_empty(), "valid exact recursive context")
	end()
	for key in Context.TOP:
		for mutation in ["missing", "wrong_type"]:
			begin("Top schema " + key + " " + mutation)
			var bad: Dictionary = c.duplicate(true)
			if mutation == "missing": bad.erase(key)
			else: bad[key] = false
			check(Policy.decide(bad).selected == null, "invalid top field no action/no error")
			end()
	for spec in [["identity", Context.IDENTITY], ["source", Context.SOURCE], ["queue", Context.QUEUE], ["party", Context.PARTY], ["enemies", Context.ENEMY], ["declared_hits", ["actor_id", "target_id", "damage"]]]:
		for key in spec[1] + ["extra"]:
			begin("Nested exact schema " + spec[0] + " " + key)
			var bad: Dictionary = c.duplicate(true)
			var row: Dictionary = bad[spec[0]][0] if bad[spec[0]] is Array else bad[spec[0]]
			if key == "extra": row.extra = 0
			else: row.erase(key)
			check(Policy.decide(bad).selected == null, "nested field rejected")
			end()
	for change in ["float", "bool", "consent", "episode", "profile", "frozen"]:
		begin("Strict type/consent/identity adversary " + change)
		var bad: Dictionary = c.duplicate(true)
		match change:
			"float": bad.identity.generation = 1.0
			"bool": bad.party[1].rescue_uses = true
			"consent": bad.party[1].consent = false
			"episode": down(bad, "t", 0)
			"profile": guidance(bad, "ATTACK"); bad.profile.actor_id = "other"
			"frozen": guidance(bad, "ATTACK"); bad.frozen_guidance.record.round_id += 1
		check(Policy.decide(bad).selected == null, "invalid input no decision")
		end()

func _extra_adversaries() -> void:
	begin("Prepare episode/frozen exact nested fixtures")
	var c: Dictionary = pure()
	down(c, "t")
	guidance(c, "FOCUS_TARGET", "b")
	check(Context.validate(c).is_empty(), "fully nested labelled fixture valid")
	end()
	for name in ["episode", "binding", "guidance_identity", "frozen_record", "profile"]:
		var spec: Array
		match name:
			"episode": spec = Context.EPISODE
			"binding": spec = ["identity", "record"]
			"guidance_identity": spec = Context.GI
			"frozen_record": spec = Context.FROZEN
			_: spec = Data.PROFILE_FIELDS
		for key in spec + ["extra"]:
			begin("Exact nested " + name + "/" + key)
			var bad: Dictionary = c.duplicate(true)
			var row: Dictionary
			match name:
				"episode": row = party(bad, "t").episode
				"binding": row = bad.frozen_guidance
				"guidance_identity": row = bad.frozen_guidance.identity
				"frozen_record": row = bad.frozen_guidance.record
				_: row = bad.profile
			if key == "extra": row.extra = false
			else: row.erase(key)
			check(Policy.decide(bad).selected == null, "missing/extra nested field safely rejected")
			end()
	begin("Owner compares full context, not an observation label", "EXECUTABLE OWNED TRANSACTION")
	var e = fresh()
	c = e.decision_context()
	var before: Dictionary = e.snapshot()
	for field in Context.QUEUE:
		var bad: Dictionary = c.duplicate(true)
		bad.queue[field] = 42 if field == "cursor" else "fake"
		check(e.decide_current(bad).selected == null and e.snapshot() == before, "forged queue field " + field)
	var injected: Dictionary = c.duplicate(true)
	party(injected, "n").help_uses = 1
	check(e.decide_current(injected).selected == null, "caller HELP resource not authority")
	guidance(injected, "ATTACK")
	check(e.decide_current(injected).selected == null and e.snapshot() == before, "caller Frozen/Profile cannot bind to live owner")
	reason(e.lock_decision(c, "unauthorized", RefCounted.new()), "M403_UNAUTHORIZED")
	check(e.snapshot() == before, "wrong capability no token/action")
	var f: Dictionary = fixture()
	state(f, "n", 0, "DOWN")
	reset(e, f)
	check(e.decision_context().is_empty(), "current Player slot is not fake NPC opportunity")
	end()


func _guidance() -> void:
	for kind in ["NONE", "ATTACK", "HELP", "FOCUS_TARGET"]:
		begin("Frozen suggestion during Player DOWN " + kind)
		var c: Dictionary = pure()
		down(c, "p")
		guidance(c, kind, "b" if kind == "FOCUS_TARGET" else "")
		var before: Dictionary = c.duplicate(true)
		var r: Dictionary = expect(c, "RESCUE", "M404_URGENT_RESCUE")
		check(r.guidance_relation.response == ("NONE" if kind == "NONE" else "REFUSED") and not r.guidance_relation.behavior_changed, "independent rescue never FOLLOWED HELP")
		check(c == before, "Frozen immutable, no fake HP")
		end()
	for target in ["a", "b"]:
		begin("Genuine existing Layer causality focus " + target)
		var c: Dictionary = pure()
		guidance(c, "FOCUS_TARGET", target)
		var r: Dictionary = Policy.decide(c)
		check(r.guidance_relation.response == ("MATCHED_INDEPENDENTLY" if target == "a" else "FOLLOWED"), "exact v1 response")
		check(r.guidance_relation.behavior_changed == (target == "b"), "causal target change")
		check(r.baseline.target_id == "a" and r.selected.target_id == target, "baseline/selected distinct")
		end()
	begin("Unsupported Player DOWN context does not delegate into v1")
	var unsupported: Dictionary = pure()
	down(unsupported, "p")
	party(unsupported, "n").rescue_uses = 0
	guidance(unsupported, "FOCUS_TARGET", "b")
	var unsupported_reply: Dictionary = expect(unsupported, "ATTACK", "ATTACK_AVAILABLE_ENEMY", "a")
	check(unsupported_reply.guidance_relation.response == "NOT_APPLICABLE", "unsupported v1 delegation explicitly not applicable")
	end()

	begin("D09 exceptional boundary has no executable action", "DIAGNOSTIC-ONLY")
	var c: Dictionary = pure()
	c.boundary = "ISOLATED_EXCEPTION"
	check(Policy.decide(c).selected == null, "same-identity exceptional lifecycle no re-arm")
	end()

func _owned() -> void:
	begin("Real ATTACK, owner binding and forged/stale input", "EXECUTABLE OWNED TRANSACTION")
	var e = fresh()
	var c: Dictionary = e.decision_context()
	var before: Dictionary = e.snapshot()
	check(e.decide_current(c).selected.action == "ATTACK", "owner-bound attack candidate")
	check(e.snapshot() == before, "reads N-all")
	for field in ["session", "generation", "round_id", "snapshot_revision"]:
		var bad: Dictionary = c.duplicate(true)
		bad.identity[field] += 1
		check(e.decide_current(bad).selected == null and e.snapshot() == before, "foreign/stale identity " + field)
	for field in ["observation_id", "owner_kind", "owner_revision"]:
		var bad: Dictionary = c.duplicate(true)
		bad.source[field] = "forged" if field != "owner_revision" else 42
		check(e.decide_current(bad).selected == null and e.snapshot() == before, "forged source " + field)
	var grant: Dictionary = e.lock_decision(c, "owned_attack", authority)
	reason(grant, "M403_ACTION_LOCKED")
	check(e.decide_current(c).selected == null, "old context after lock rejects")
	finish(e, grant.token)
	reason(e.impact(grant.token), "M403_DUPLICATE_OPERATION")
	end()
	begin("Real urgent rescue and next NPC fresh target, resource exactly once", "EXECUTABLE OWNED TRANSACTION")
	var f: Dictionary = fixture()
	state(f, "p", 0, "DOWN")
	state(f, "t", 0, "DOWN")
	f.clocks = {"p": {"entry_round": 2, "budget": 1}, "t": {"entry_round": 2, "budget": 1}}
	e = fresh(f)
	c = e.decision_context()
	check(e.decide_current(c).selected.target_id == "p", "older owner creation, not arbitrary ID")
	grant = e.lock_decision(c, "rescue_p", authority)
	finish(e, grant.token)
	check(e.actor_snapshot("p").state.current_hp == 1 and e.snapshot().rescue_uses.n == 0, "real HP1 and consumed helper use")
	c = e.decision_context()
	check(c.actor_id == "j" and e.decide_current(c).selected.target_id == "t", "next NPC sees actual latest state")
	grant = e.lock_decision(c, "rescue_t", authority)
	finish(e, grant.token)
	check(e.snapshot().rescue_uses.j == 0, "separate real resource")
	end()
	begin("Real O3 RETREAT and immutable owned completion", "EXECUTABLE OWNED TRANSACTION")
	f = fixture()
	state(f, "n", 30)
	e = fresh(f)
	c = e.decision_context()
	check(e.decide_current(c).selected.action == "RETREAT", "approved self-preservation")
	grant = e.lock_decision(c, "retreat_n", authority)
	finish(e, grant.token)
	check(e.actor_snapshot("n").state.participation == "RETREATED", "real retained-ID retreat")
	before = e.snapshot()
	reason(e.complete(grant.token), "M403_DUPLICATE_OPERATION")
	check(e.snapshot() == before, "duplicate N-all")
	end()
	begin("HELP absent authority blocks rather than spending fake resource", "BLOCKED DEPENDENCY")
	f = fixture()
	state(f, "p", 30)
	e = fresh(f)
	c = e.decision_context()
	before = e.snapshot()
	check(e.decide_current(c).legal_effect.status == "DESIGN_BLOCKED", "HELP execution O6 dependency explicit")
	check(e.lock_decision(c, "no_help", authority).status == "REJECTED" and e.snapshot() == before, "no receipt/HP/resource write")
	end()
	begin("Seed/journal projection and Restart stale authority", "EXECUTABLE OWNED TRANSACTION")
	f = fixture()
	state(f, "p", 0, "DOWN")
	e = fresh(f)
	var first: Dictionary = OrderProjection.project(e.snapshot())
	check(first.episodes.p.entry_order == 1, "seeded DOWN derives from actual preparation")
	c = e.decision_context()
	grant = e.lock_decision(c, "first_rescue", authority)
	finish(e, grant.token)
	# Complete other slots by real cancellation, then opposing actual damage producer.
	for id in ["j", "t"]:
		grant = lock(e, "ATTACK")
		reason(e.cancel(grant.token), "M403_ACTION_CANCELLED")
	grant = lock(e, "ATTACK", "n", 100)
	finish(e, grant.token)
	var later: Dictionary = OrderProjection.project(e.snapshot())
	check(later.episodes.n.entry_order == 2, "new DOWN ordinal from authenticated impact journal")
	grant = lock(e, "ATTACK", "n", 1)
	var skipped: Dictionary = e.impact(grant.token)
	reason(skipped, "M403_TARGET_UNAVAILABLE")
	check(skipped.status == "SKIPPED", "real serial Enemy second hit sees prior DOWN, no fabricated interleaving")
	reason(e.complete(grant.token), "M403_ACTION_COMPLETED")
	var sealed: Dictionary = e.seal(request(e), authority)
	reason(sealed, "M403_ROUND_SEALED")
	reason(e.close(sealed.event), "M403_ROUND_CLOSED")
	reason(e.open_round(request(e, true), authority), "M403_ROUND_OPENED")
	# Recovered Player now owns the ordinary round4 slot. Dispose it by real cancel.
	grant = lock(e, "ATTACK")
	reason(e.cancel(grant.token), "M403_ACTION_CANCELLED")
	reason(e.advance(request(e), authority), "M403_SLOT_UNAVAILABLE")
	for id in ["j", "t"]:
		grant = lock(e, "ATTACK")
		reason(e.cancel(grant.token), "M403_ACTION_CANCELLED")
	grant = lock(e, "ATTACK", "p", 1)
	finish(e, grant.token)
	var redown: Dictionary = OrderProjection.project(e.snapshot())
	check(redown.episodes.p.entry_order == 3 and redown.episodes.p.episode_id != first.episodes.p.episode_id, "same actor re-DOWN new global ordinal, no ID decoding")

	before = e.snapshot()
	var forged: Dictionary = before.duplicate(true)
	forged.clocks.n.budget = 1
	check(OrderProjection.project(forged).is_empty() and e.snapshot() == before, "forged root cannot masquerade as replay")
	reset(e, f)
	check(e.snapshot().generation == before.generation + 1 and OrderProjection.project(e.snapshot()).episodes.p.entry_order == 1, "Restart resets ordinal generation")
	check(e.decide_current(c).selected == null, "old-generation context cannot authorize")
	reason(e.impact(grant.token), "M403_STALE_GENERATION")
	end()

func _run() -> void:
	_priority()
	_schema()
	_extra_adversaries()
	_guidance()
	_owned()
	var hashes: Dictionary = {}
	for path in ["scripts/m4/m404_decision_context.gd", "scripts/m4/m404_episode_order_projection.gd", "scripts/m4/m404_autonomous_decision_policy.gd", "scripts/m4/m404_decision_facade.gd", "tests/actors/m4_04_autonomous_decision_proof.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var report: Dictionary = {"suite": "M4-04 autonomous decision", "independent_cases": cases.size(), "assertion_checks": checks,
		"failures": failures, "per_frame_checks": 0, "cases": cases, "source_sha256": hashes,
		"deferred": ["O4 conscious consent/recipient refusal", "O6 real DEFEND/HELP bridge BLOCKED DEPENDENCY", "O7 mid-action changed-state SKIP DIAGNOSTIC ONLY", "production D09 Pending/R1 tested in unchanged Guidance suite, not M403 executor", "manual GUI/F5/F6/visual NOT RUN"]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file == null: quit(1); return
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("RESULT: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
