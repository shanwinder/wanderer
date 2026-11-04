extends SceneTree

const Encounter = preload("res://scripts/combat/full_party_encounter.gd")
const Guided = preload("res://scripts/npc/guided_decision_proof_encounter.gd")
const ProductionGuided = preload("res://scripts/combat/guided_encounter.gd")
const Layer = preload("res://scripts/npc/guidance_decision_layer.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const Main = preload("res://scenes/combat/combat_autonomous_optin.tscn")
const Legacy = preload("res://scenes/combat/combat_prototype.tscn")
var checks: int = 0
var failures: int = 0
var case_failures: Array = []
var observations: Array = []
var cases: Dictionary = {}
var callbacks: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, expected: String, actual: Variant = null) -> void:
	checks += 1
	if not ok:
		failures += 1
		case_failures.append({"expected": expected, "actual": actual})
		print("FAIL: %s / actual %s" % [expected, str(actual)])


func _record(id: String, expected: String) -> void:
	cases[id] = {"expected": expected, "actual": "PASS" if case_failures.is_empty() else "FAIL",
		"failed_assertions": case_failures.duplicate(true), "observations": observations.duplicate(true)}
	print("CASE %s: %s" % [id, cases[id].actual])
	case_failures.clear()
	observations.clear()


func _fixture(hp: Dictionary = {}, maximum: Dictionary = {}) -> Dictionary:
	var fixture: Dictionary = Encounter.prototype_fixture()
	for entry in fixture.actors:
		var id: String = entry.definition.actor_id
		if maximum.has(id):
			entry.definition.base_max_hp = maximum[id]
			entry.initial_hp = maximum[id]
		if hp.has(id):
			entry.initial_hp = hp[id]
	return fixture


func _request(e, kind: String, target: String = "") -> Dictionary:
	var v: Dictionary = e.guidance_snapshot()
	return {"schema_version": 1, "guidance_type": kind, "issuer_player_id": e.snapshot().player_id,
		"preferred_target_id": target, "encounter_id": v.encounter_id, "generation": v.generation,
		"round_id": v.round_id, "expected_guidance_revision": v.guidance_revision}


func _new(kind: String = "NONE", target: String = "", hp: Dictionary = {}, hits: Dictionary = {},
	maximum: Dictionary = {}, guided: bool = true):
	var e = Guided.new() if guided else Encounter.new()
	_check(e.restart(_fixture(hp, maximum)), "valid isolated fixture")
	if not e.snapshot().result.is_empty():
		return e
	_check(e.submit_guidance(_request(e, kind, target)).status == "ACCEPTED", "Guidance accepted")
	_check(e.begin_round("DEFEND", "", hits).status == "STARTED", "round freezes Guidance")
	return e


func _envelope(e, id: String = "npc_01") -> Dictionary:
	var v: Dictionary = e.guidance_snapshot()
	return {"schema_version": 1, "base_context": e.decision_context(), "frozen_guidance": v.active,
		"actor_profile": v.profiles[id], "identity": {"encounter_id": v.encounter_id,
			"generation": v.generation, "round_id": v.round_id, "guidance_revision": v.guidance_revision,
			"snapshot_revision": e.snapshot().snapshot_revision}, "capabilities": Layer.CAPABILITIES.duplicate()}


func _decide(e, id: String = "npc_01", changes: Dictionary = {}) -> Dictionary:
	var envelope: Dictionary = _envelope(e, id)
	for field in changes:
		envelope.actor_profile[field] = changes[field]
	var before: Dictionary = e.snapshot()
	var data: Dictionary = e.guidance_snapshot()
	var copy: Dictionary = envelope.duplicate(true)
	var result: Dictionary = Layer.new().decide_with_guidance(id, envelope)
	_check(result.status == "OK", "valid envelope accepted", result)
	_check(e.snapshot() == before and e.guidance_snapshot() == data and envelope == copy,
		"pure layer changes neither input nor Encounter")
	if result.status == "OK":
		_check(result.baseline_decision == Resolver.new().decide_for_actor(id, envelope.base_context),
			"baseline payload exactly equals original Resolver")
		var changed: bool = result.decision.action != result.baseline_decision.action \
			or result.decision.target_id != result.baseline_decision.target_id
		_check((result.guidance_response.response == "FOLLOWED") == changed,
			"FOLLOWED iff Action or Target actually changed", result)
	observations.append(result.duplicate(true))
	return result


func _expect(result: Dictionary, action: String, target: String, reason: String,
	response: String, response_reason: String) -> void:
	if result.status != "OK":
		return
	var expected: Array = [action, target, reason, response, response_reason]
	var actual: Array = [result.decision.action, result.decision.target_id, result.decision.reason_code,
		result.guidance_response.response, result.guidance_response.reason_code]
	_check(actual == expected, "decision/target/action reason/response/response reason " + str(expected), actual)


func _step(e) -> Dictionary:
	var token: Dictionary = e.begin_next_action()
	_check(token.has("decision"), "slot locks", token)
	if not token.has("decision"):
		return {}
	var effect: Dictionary = e.resolve_action(token)
	_check(effect.status in ["APPLIED", "SKIP"], "effect applied or skipped", effect)
	_check(e.complete_action(token).status == "COMPLETED", "complete exactly once")
	return token


func _drain(e) -> void:
	for slot in range(8):
		if not e.snapshot().round_running:
			break
		_step(e)
	_check(not e.snapshot().round_running, "bounded queue completes or terminates")


func _none_equivalence() -> void:
	for player_hp in [0, 6, 9, 10, 30]:
		for npc_hp in [0, 2, 3, 4, 10]:
			for living in [true, false]:
				for help_use in [0, 1]:
					var e = _new("NONE", "", {"player": 30, "npc_01": npc_hp}, {"enemy_a": "npc_01"})
					var v: Dictionary = _envelope(e)
					v.base_context.actors.player.current_hp = player_hp
					v.base_context.actors.player.can_act = player_hp > 0
					v.base_context.help_uses.npc_01 = help_use
					if not living:
						for id in v.base_context.enemy_order:
							v.base_context.actors[id].current_hp = 0
							v.base_context.actors[id].can_act = false
					var baseline: Dictionary = Resolver.new().decide_for_actor("npc_01", v.base_context)
					var result: Dictionary = Layer.new().decide_with_guidance("npc_01", v)
					_check(result.status == "OK" and result.decision == baseline
						and result.baseline_decision == baseline and result.guidance_response.response == "NONE",
						"NONE exact baseline including reason details/revision/terminal/unavailable", result)
	# Compare actual effects/queue/HP/Guard under the new TYPE with NONE vs production.
	var a = _new()
	var b = _new("NONE", "", {}, {}, {}, false)
	while a.snapshot().round_running:
		var ta: Dictionary = a.begin_next_action()
		var tb: Dictionary = b.begin_next_action()
		_check(ta.decision == tb.decision, "NONE decisions exact in real queue")
		_check(a.resolve_action(ta) == b.resolve_action(tb), "NONE effects exact")
		a.complete_action(ta)
		b.complete_action(tb)
		var sa: Dictionary = a.snapshot()
		var sb: Dictionary = b.snapshot()
		for field in ["encounter_id", "locked_action"]:
			sa.erase(field)
			sb.erase(field)
		_check(sa == sb, "NONE HP/HELP/guards/queue/revision/terminal exact")
	_record("P01", "100 pure NONE contexts and actual full round exactly match baseline")


func _priorities() -> void:
	_expect(_decide(_new("ATTACK")), "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY",
		"MATCHED_INDEPENDENTLY", "BASELINE_ATTACK")
	_record("P02", "ATTACK independently matches")
	_expect(_decide(_new("ATTACK", "", {"npc_01": 3}, {"enemy_a": "npc_01"}, {"npc_01": 5})),
		"DEFEND", "npc_01", "SELF_LETHAL_THREAT", "REFUSED", "SELF_PRESERVATION_PRIORITY")
	_record("P03", "3/5 HP lethal first hit3; above30% still self DEFEND")
	_expect(_decide(_new("ATTACK", "", {"npc_01": 3}, {"enemy_a": "npc_01"})),
		"DEFEND", "npc_01", "SELF_LOW_HP_THREAT", "REFUSED", "SELF_PRESERVATION_PRIORITY")
	_record("P04", "3/10 exactly30% low HP threat")
	_expect(_decide(_new("ATTACK", "", {"player": 9})), "HELP", "player", "PLAYER_LOW_HP_HELP",
		"REFUSED", "URGENT_HELP_PRIORITY")
	_record("P05", "9/30 urgent HELP overrides ATTACK")
	var e = _new("DEFEND", "", {"npc_02": 4}, {"enemy_a": "npc_02"})
	_expect(_decide(e, "npc_02"), "DEFEND", "npc_02", "GUIDANCE_DISCRETIONARY_DEFEND",
		"FOLLOWED", "PROFILE_PERMITTED_COOPERATION")
	_step(e)
	_step(e)
	var t: Dictionary = e.begin_next_action()
	var before: Dictionary = e.snapshot()
	e.resolve_action(t)
	_check(e.snapshot().guards == {"player": true, "npc_02": true}, "self DEFEND gives only self guard")
	_check(e.actor_snapshot("player") == before.actors.player, "NPC DEFEND does not heal or guard whole party")
	e.complete_action(t)
	_drain(e)
	_check(e.actor_snapshot("npc_02").current_hp == 3, "NPC self guard reduces next valid hit3 to1")
	_record("P06", "valid nonlethal threat at4/10 and cautious established NPC follows DEFEND")
	_expect(_decide(_new("DEFEND")), "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY",
		"NOT_APPLICABLE", "NO_VALID_THREAT")
	_expect(_decide(_new("DEFEND", "", {"enemy_a": 0}, {"enemy_a": "npc_01"})),
		"ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY", "NOT_APPLICABLE", "NO_VALID_THREAT")
	# Two3 hits against5HP must not become aggregate lethal6. First hit remains3.
	_expect(_decide(_new("DEFEND", "", {"npc_01": 5}, {"enemy_a": "npc_01", "enemy_b": "npc_01"})),
		"ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY", "REFUSED", "PROFILE_PREFERS_BASELINE")
	_record("P07", "no valid self threat/dead declarer ignored; first-hit3, never aggregate6")
	_expect(_decide(_new("HELP", "", {"player": 9})), "HELP", "player", "PLAYER_LOW_HP_HELP",
		"MATCHED_INDEPENDENTLY", "URGENT_HELP_PRIORITY")
	_record("P08", "HELP at30% already chosen independently")
	for hp in [10, 12, 15, 30]:
		_expect(_decide(_new("HELP", "", {"player": hp})), "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY",
			"NOT_APPLICABLE", "PLAYER_ABOVE_HELP_THRESHOLD")
	_record("P09", "HELP above30%, including40%/50%/full: no heal/resource expansion")
	e = _new("HELP", "", {"player": 6})
	var v: Dictionary = _envelope(e)
	v.base_context.help_uses.npc_01 = 0
	_expect(Layer.new().decide_with_guidance("npc_01", v), "ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK",
		"REFUSED", "RESOURCE_UNAVAILABLE")
	# Priority7 also blocks discretionary Guidance when urgent HELP is unavailable.
	for kind in ["DEFEND", "FOCUS_TARGET"]:
		v.frozen_guidance.guidance_type = kind
		v.frozen_guidance.preferred_target_id = "enemy_b" if kind == "FOCUS_TARGET" else ""
		_expect(Layer.new().decide_with_guidance("npc_01", v), "ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK",
			"REFUSED", "HELP_UNAVAILABLE_BASELINE_PRIORITY")
	_record("P10", "HELP exhausted retains ATTACK fallback; no discretionary override")
	v = _envelope(_new("HELP"))
	v.base_context.actors.player.current_hp = 0
	v.base_context.actors.player.can_act = false
	_expect(Layer.new().decide_with_guidance("npc_01", v), "SKIP", "", "PLAYER_DEFEATED",
		"NOT_APPLICABLE", "PLAYER_DEFEATED")
	_record("P11", "Player HP0 cannot be helped/revived")


func _focus_and_traits() -> void:
	_expect(_decide(_new("FOCUS_TARGET", "enemy_a")), "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY",
		"MATCHED_INDEPENDENTLY", "BASELINE_TARGET")
	_record("P12", "FOCUS A matches independently")
	_expect(_decide(_new("FOCUS_TARGET", "enemy_b")), "ATTACK", "enemy_b", "GUIDANCE_FOCUS_TARGET",
		"FOLLOWED", "PROFILE_PERMITTED_COOPERATION")
	_record("P13", "FOCUS B causally changes NPC target without changing Player target")
	var e = _new("FOCUS_TARGET", "enemy_a", {"enemy_a": 5})
	# Restart while command-ready, then Player kills focused A before NPC slot.
	_check(e.restart(_fixture({"enemy_a": 5})), "fresh focused death fixture")
	e.submit_guidance(_request(e, "FOCUS_TARGET", "enemy_a"))
	e.begin_round("ATTACK", "enemy_a")
	_step(e)
	var t: Dictionary = e.begin_next_action()
	_expect(t.guidance_decision, "ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY",
		"NOT_APPLICABLE", "TARGET_UNAVAILABLE")
	_check(e.resolve_action(t).hp_delta == -1, "live B receives fallback attack")
	e.complete_action(t)
	_record("P14", "focused A killed by Player before NPC slot: reevaluate, attack B")
	e = _new("FOCUS_TARGET", "enemy_b")
	_step(e)
	t = e.begin_next_action()
	var locked: Dictionary = t.duplicate(true)
	e._registry.fixture_damage("enemy_b", 99) # Test-only effect-boundary race, same authority.
	_check(e.resolve_action(t) == {"status": "SKIP", "reason_code": "TARGET_DEAD_BEFORE_RESOLVE", "hp_delta": 0},
		"target dies after lock: SKIP, do not retarget")
	_check(e.snapshot().locked_action.decision == locked.decision
		and e.snapshot().locked_action.guidance_decision == locked.guidance_decision,
		"effect never rewrites locked decision/explanation")
	e.complete_action(t)
	_record("P15", "FOCUS B dies after lock; effect SKIP while FOLLOWED at lock remains true")
	_expect(_decide(_new("FOCUS_TARGET", "enemy_b", {"npc_01": 2}, {"enemy_a": "npc_01"}),
		"npc_01", {"trust": "ESTABLISHED"}), "DEFEND", "npc_01", "SELF_LOW_HP_THREAT",
		"REFUSED", "SELF_PRESERVATION_PRIORITY")
	_record("P16", "high Trust cannot override safety")
	_expect(_decide(_new("DEFEND", "", {"npc_01": 2}, {"enemy_a": "npc_01"})),
		"DEFEND", "npc_01", "SELF_LOW_HP_THREAT", "MATCHED_INDEPENDENTLY", "SELF_PRESERVATION_PRIORITY")
	_expect(_decide(_new("FOCUS_TARGET", "enemy_b", {"player": 6}), "npc_01",
		{"discipline": "PLAN_ORIENTED"}), "HELP", "player", "PLAYER_LOW_HP_HELP", "REFUSED", "URGENT_HELP_PRIORITY")
	_record("P17", "high Discipline cannot override urgent HELP")
	# Exhaustive16 combinations; paired changes isolate each active trait and inert Compassion.
	for discipline in ["FLEXIBLE", "PLAN_ORIENTED"]:
		for trust in ["CAUTIOUS", "ESTABLISHED"]:
			for courage in ["CAUTIOUS", "BOLD"]:
				var paired: Array = []
				for compassion in ["ORDINARY", "HIGH"]:
					var profile: Dictionary = {"discipline": discipline, "trust": trust,
						"courage": courage, "compassion": compassion}
					var cooperate: bool = discipline == "PLAN_ORIENTED" or trust == "ESTABLISHED"
					var r: Dictionary = _decide(_new("FOCUS_TARGET", "enemy_b"), "npc_01", profile)
					_check(r.guidance_response.response == ("FOLLOWED" if cooperate else "REFUSED"),
						"FOCUS truth table Discipline OR Trust", r)
					var d: Dictionary = _decide(_new("DEFEND", "", {}, {"enemy_a": "npc_01"}), "npc_01", profile)
					_check(d.guidance_response.response == ("FOLLOWED" if cooperate and courage == "CAUTIOUS" else "REFUSED"),
						"DEFEND truth table cautious AND (Discipline OR Trust)", d)
					paired.append([r.decision.action, r.decision.target_id, d.decision.action])
				_check(paired[0] == paired[1], "Compassion-only pair has no new policy effect")
	# Same context and actor, change precisely one trait and assert causal variation.
	for spec in [["FOCUS_TARGET", "discipline", "FLEXIBLE", "PLAN_ORIENTED"],
		["FOCUS_TARGET", "trust", "CAUTIOUS", "ESTABLISHED"], ["DEFEND", "courage", "BOLD", "CAUTIOUS"]]:
		e = _new(spec[0], "enemy_b" if spec[0] == "FOCUS_TARGET" else "", {}, {"enemy_a": "npc_01"})
		var v: Dictionary = _envelope(e)
		v.actor_profile.discipline = "FLEXIBLE"
		v.actor_profile.trust = "ESTABLISHED" if spec[1] == "courage" else "CAUTIOUS"
		v.actor_profile.courage = "CAUTIOUS"
		v.actor_profile[spec[1]] = spec[2]
		var a: Dictionary = Layer.new().decide_with_guidance("npc_01", v)
		v.actor_profile[spec[1]] = spec[3]
		var b: Dictionary = Layer.new().decide_with_guidance("npc_01", v)
		_check(a.guidance_response.response == "REFUSED" and b.guidance_response.response == "FOLLOWED",
			"one-trait paired predicate " + spec[1], [a, b])
	_record("P18", "16 profile combinations, explicit one-trait paired fixtures; Compassion deliberately inert")
	e = _new("FOCUS_TARGET", "enemy_b", {"npc_02": 2}, {"enemy_a": "npc_02"})
	_step(e)
	var responses: Array = []
	for id in ["npc_01", "npc_02", "npc_03"]:
		t = _step(e)
		responses.append(t.guidance_decision.guidance_response.response)
		observations.append(t)
	_check(responses == ["FOLLOWED", "REFUSED", "REFUSED"], "independent profile/safety responses", responses)
	_record("P19", "one team FOCUS: NPC1 follows B, NPC2 safety DEFEND, NPC3 retains A")
	e = _new("FOCUS_TARGET", "enemy_b", {"player": 6})
	_step(e)
	var first: Dictionary = _step(e)
	var second: Dictionary = _step(e)
	_expect(first.guidance_decision, "HELP", "player", "PLAYER_LOW_HP_HELP", "REFUSED", "URGENT_HELP_PRIORITY")
	_expect(second.guidance_decision, "ATTACK", "enemy_b", "GUIDANCE_FOCUS_TARGET", "FOLLOWED", "PROFILE_PERMITTED_COOPERATION")
	_check(first.decision.reason_details.player_hp == 6 and second.decision.reason_details.player_hp == 10
		and second.decision.snapshot_revision > first.decision.snapshot_revision, "fresh per-slot HP and revision")
	_record("P20", "NPC1 heals6→10, NPC2 now evaluates discretionary FOCUS from latest state")


func _boundaries() -> void:
	var production = _new("FOCUS_TARGET", "enemy_b", {}, {}, {}, false)
	_step(production)
	var t: Dictionary = production.begin_next_action()
	_check(t.decision == Resolver.new().decide_for_actor("npc_01", production.decision_context())
		and not t.has("guidance_decision") and t.decision.target_id == "enemy_a", "production remains unguided")
	_record("P21", "FullPartyEncounter ignores stored FOCUS; only explicit proof type opts in")
	var context: Dictionary = production.decision_context()
	var baseline: Dictionary = Resolver.new().decide_for_actor("npc_01", context)
	context["frozen_guidance"] = {}
	_check(Resolver.new().decide_for_actor("npc_01", context).status == "INVALID_INPUT", "Legacy context still strict")
	var legacy_context: Dictionary = baseline.reason_details.duplicate(true)
	legacy_context.erase("declared_hits")
	# The old single-NPC API accepts only enemy_a, unlike multi-actor context.
	legacy_context.living_enemy_ids = ["enemy_a"]
	_check(Resolver.new().decide(legacy_context).status == "DECIDED", "original legacy decide works")
	legacy_context["actor_profile"] = {}
	_check(Resolver.new().decide(legacy_context).status == "INVALID_INPUT", "original decide rejects extension")
	_record("P22", "both original API schemas/semantics unchanged")
	var e = _new("FOCUS_TARGET", "enemy_b")
	var v: Dictionary = _envelope(e)
	var result: Dictionary = Layer.new().decide_with_guidance("npc_01", v)
	var saved: Dictionary = result.duplicate(true)
	v.base_context.actors.player.current_hp = 1
	v.actor_profile.trust = "CAUTIOUS"
	v.frozen_guidance.guidance_type = "NONE"
	_check(result == saved, "input edits cannot mutate output")
	result.decision.reason_details.declared_hits.clear()
	result.guidance_response.details.actor_profile.trust = "CAUTIOUS"
	_check(result.baseline_decision == saved.baseline_decision, "decision/baseline/metadata nested copies independent")
	_check(Layer.new().decide_with_guidance("npc_01", _envelope(e)) == saved, "repeat deterministic detached result")
	_step(e)
	t = e.begin_next_action()
	var own: Dictionary = e.snapshot().locked_action
	t.guidance_decision.decision.target_id = "enemy_a"
	t.decision.target_id = "enemy_a"
	_check(e.snapshot().locked_action == own, "returned token metadata cannot mutate lock")
	_check(e.resolve_action(t).hp_delta == -1 and e.actor_snapshot("enemy_b").current_hp == 11,
		"caller token payload cannot redirect effect")
	_record("P23", "immutable-style detached metadata stable through caller edits and impact")
	e = _new("FOCUS_TARGET", "enemy_b")
	var valid: Dictionary = _envelope(e)
	var malformed: Array = [null, [], true, 1, "bad", {}]
	for field in Layer.ENVELOPE_FIELDS:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		malformed.append(missing)
	for path in [["schema_version"], ["identity", "generation"], ["identity", "round_id"],
		["identity", "encounter_id"], ["identity", "guidance_revision"], ["identity", "snapshot_revision"],
		["actor_profile", "trust"], ["frozen_guidance", "guidance_type"], ["capabilities"]]:
		for bad in [null, false, 1.0, [], {}, "BAD", -1, 0]:
			var value: Dictionary = valid.duplicate(true)
			if path.size() == 1:
				value[path[0]] = bad
			else:
				value[path[0]][path[1]] = bad
			# Some fields legitimately accept0 (revision); test only actual invalids.
			if value == valid:
				continue
			malformed.append(value)
	var extra: Dictionary = valid.duplicate(true)
	extra["extra"] = true
	malformed.append(extra)
	for value in malformed:
		var before: Dictionary = e.snapshot()
		var data: Dictionary = e.guidance_snapshot()
		var reply: Dictionary = Layer.new().decide_with_guidance("npc_01", value)
		_check(reply.status == "INVALID_INPUT" and not reply.has("decision"), "malformed envelope rejects, no partial decision", reply)
		_check(e.snapshot() == before and e.guidance_snapshot() == data, "malformed envelope atomic")
	_record("P24", "strict fields/version/types/identity/profile/capabilities; malformed input atomic")
	for field in ["encounter_id", "generation", "round_id", "guidance_revision"]:
		v = valid.duplicate(true)
		v.frozen_guidance[field] += 1
		_check(Layer.new().decide_with_guidance("npc_01", v).status == "INVALID_INPUT", "frozen identity mismatch " + field)
	for path in [["actor_profile", "actor_id", "npc_02"], ["actor_profile", "player_id", "other_player"],
		["frozen_guidance", "issuer_player_id", "other_player"], ["frozen_guidance", "preferred_target_id", "unknown"],
		["identity", "snapshot_revision", 999]]:
		v = valid.duplicate(true)
		v[path[0]][path[1]] = path[2]
		_check(Layer.new().decide_with_guidance("npc_01", v).status == "INVALID_INPUT", "foreign actor/Player/target or stale snapshot")
	# Trust boundary: pure Layer checks internal consistency; Encounter authenticates session.
	var request: Dictionary = _request(e, "ATTACK")
	e.restart(_fixture())
	var before: Dictionary = e.snapshot()
	_check(e.submit_guidance(request).reason_code == "STALE_GENERATION" and e.snapshot() == before,
		"old request after Restart rejected at authority")
	var other = Guided.new()
	request = _request(e, "ATTACK")
	_check(other.submit_guidance(request).reason_code == "FOREIGN_ENCOUNTER", "foreign request rejected")
	_record("P25", "cross-record envelope identity validated; authority rejects stale/foreign requests")


func _lifecycle() -> void:
	var e = _new("HELP", "", {"player": 1}, {}, {"player": 4})
	_step(e)
	var t: Dictionary = e.begin_next_action()
	var saved: Dictionary = t.guidance_decision.duplicate(true)
	_check(e.resolve_action(t) == {"status": "APPLIED", "hp_delta": 3}, "HELP clamps1/4→4/4 actual+3")
	_check(e.snapshot().help_uses.npc_01 == 0, "consume only actual heal once")
	var state: Dictionary = e.snapshot()
	_check(e.resolve_action(t).status == "REJECTED" and e.snapshot() == state, "duplicate impact inert")
	_check(e.snapshot().locked_action.guidance_decision == saved, "actual heal does not rewrite decision")
	e.complete_action(t)
	state = e.snapshot()
	_check(e.complete_action(t).status == "REJECTED" and e.snapshot() == state, "duplicate completion inert")
	# Heal disappears between lock and impact: no resource consumed.
	e = _new("HELP", "", {"player": 9})
	_step(e)
	t = e.begin_next_action()
	e._registry.fixture_heal("player", 99)
	_check(e.resolve_action(t).status == "SKIP" and e.snapshot().help_uses.npc_01 == 1, "zero actual heal consumes nothing")
	_record("P26", "HELP actual delta/clamp, resource exactly once, zero-heal SKIP consumes nothing")
	for impact in [false, true]:
		e = _new("FOCUS_TARGET", "enemy_b")
		_step(e)
		t = e.begin_next_action()
		if impact:
			e.resolve_action(t)
		var stale: Dictionary = t.duplicate(true)
		var old: Dictionary = e.snapshot()
		_check(not e.restart({}) and e.snapshot() == old, "invalid Restart leaves guided lock intact")
		_check(e.restart(_fixture()), "Restart during guided slot")
		e.begin_round("DEFEND")
		var fresh: Dictionary = e.begin_next_action()
		var before: Dictionary = e.snapshot()
		var data: Dictionary = e.guidance_snapshot()
		callbacks.clear()
		get_tree_timer(e, stale)
		await create_timer(0.02).timeout
		_check(callbacks.size() == 2 and callbacks[0].status == "REJECTED" and callbacks[1].status == "REJECTED",
			"delayed stale impact/completion rejected", callbacks)
		_check(e.snapshot() == before and e.guidance_snapshot() == data and fresh.generation != stale.generation,
			"stale callbacks cannot affect new actionID1/HP/Guidance")
	_record("P27", "Restart before/after guided impact; real delayed stale callbacks cannot change new generation")
	for result in ["VICTORY", "DEFEAT"]:
		e = _new("FOCUS_TARGET", "enemy_b")
		_step(e)
		t = e.begin_next_action()
		if result == "VICTORY":
			e._registry.fixture_damage("enemy_a", 99)
			e._registry.fixture_damage("enemy_b", 99)
		else:
			e._registry.fixture_damage("player", 99)
		_check(e.resolve_action(t).status == "SKIP" and e.snapshot().result == result, "terminal result " + result)
		_check(e.guidance_snapshot().active.is_empty(), "terminal clears frozen Guidance")
		e.complete_action(t)
		var before: Dictionary = e.snapshot()
		_check(not before.round_running and before.pending.is_empty() and not before.command_ready,
			"terminal stops queue")
		_check(e.begin_round("ATTACK").status == "TERMINAL" and e.snapshot() == before, "terminal command inert")
	_record("P28", "victory and defeat at impact stop queue, clear Guidance, preserve completion safety")


func get_tree_timer(e, stale: Dictionary) -> void:
	create_timer(0.005).timeout.connect(func():
		callbacks.append(e.resolve_action(stale))
		callbacks.append(e.complete_action(stale)))


func _main_boundaries() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(path == "res://scenes/combat/combat_autonomous_optin.tscn", "F5 configured Autonomous unchanged")
	var scene = Main.instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.encounter is ProductionGuided and not scene.encounter is Guided, "M3A-04 Main uses production Guided type, not test-only subclass")
	_check(scene.encounter.submit_guidance(_request(scene.encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED",
		"Main authority accepts Guidance")
	scene.encounter.begin_round("DEFEND")
	_step(scene.encounter)
	var t: Dictionary = scene.encounter.begin_next_action()
	_check(t.decision.target_id == "enemy_b" and t.guidance_decision.guidance_response.response == "FOLLOWED", "M3A-04 Main FOCUS now intentionally enables approved policy")
	scene.queue_free()
	await process_frame
	_record("P31", "M3A-04 migration: actual Main guided; base remains unguided in P21; NONE equivalence in P01")
	scene = Legacy.instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.session_mode == scene.SessionMode.LEGACY and scene.encounter == null,
		"direct Legacy F6 scene deterministic Legacy authority")
	scene.queue_free()
	await process_frame
	_record("P32", "direct Legacy scene still Legacy, full deterministic regressions mapped separately")


func _run() -> void:
	_none_equivalence()
	_priorities()
	_focus_and_traits()
	_boundaries()
	await _lifecycle()
	await _main_boundaries()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures,
				"focused_cases": cases.size(), "cases": cases}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
