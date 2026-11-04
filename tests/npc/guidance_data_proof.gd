extends SceneTree

const Encounter = preload("res://scripts/combat/full_party_encounter.gd")
const Contract = preload("res://scripts/npc/guidance_data_contract.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const Runtime = preload("res://scripts/actors/actor_runtime_state.gd")
var checks: int = 0
var failures: int = 0
var case_start: int = 0
var check_start: int = 0
var case_failures: Array = []
var cases: Dictionary = {}
var callbacks: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, expected: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		case_failures.append({"expected": expected, "actual": false})
		print("FAIL: " + expected)


func _record(id: String, expected: String, evidence: Dictionary = {}) -> void:
	cases[id] = {"expected": expected, "actual": "PASS" if failures == case_start else "FAIL",
		"checks": checks - check_start, "failures": failures - case_start,
		"failed_assertions": case_failures.duplicate(true), "evidence": evidence.duplicate(true)}
	print("CASE %s: %s" % [id, cases[id].actual])
	case_start = failures
	check_start = checks
	case_failures.clear()


func _fixture(hp: Dictionary = {}) -> Dictionary:
	var fixture: Dictionary = Encounter.prototype_fixture()
	for entry in fixture.actors:
		if hp.has(entry.definition.actor_id):
			entry.initial_hp = hp[entry.definition.actor_id]
	return fixture


func _new(hp: Dictionary = {}):
	var encounter = Encounter.new()
	_check(encounter.restart(_fixture(hp)), "valid fixture Restart")
	return encounter


func _request(encounter, kind: String = "ATTACK", target: String = "") -> Dictionary:
	var view: Dictionary = encounter.guidance_snapshot()
	return {"schema_version": 1, "guidance_type": kind, "issuer_player_id": encounter.snapshot().player_id,
		"preferred_target_id": target, "encounter_id": view.encounter_id, "generation": view.generation,
		"round_id": view.round_id, "expected_guidance_revision": view.guidance_revision}


func _reject(encounter, request: Variant, reason: String = "", status: String = "REJECTED") -> void:
	var before: Dictionary = encounter.snapshot()
	var data: Dictionary = encounter.guidance_snapshot()
	var reply: Dictionary = encounter.submit_guidance(request)
	_check(reply.status == status and (reason.is_empty() or reply.reason_code == reason),
		"request expected %s / %s actual %s" % [status, reason, str(reply)])
	_check(encounter.snapshot() == before and encounter.guidance_snapshot() == data,
		"rejection leaves combat and all Guidance/profile/revision state unchanged")


func _step(encounter) -> Dictionary:
	var token: Dictionary = encounter.begin_next_action()
	_check(token.has("decision"), "one action locks")
	if not token.has("decision"):
		return {}
	var effect: Dictionary = encounter.resolve_action(token)
	_check(effect.status in ["APPLIED", "SKIP"], "effect completes or safely skips")
	_check(encounter.complete_action(token).status == "COMPLETED", "completion accepted once")
	return token


func _drain(encounter) -> void:
	for slot in range(8):
		if not encounter.snapshot().round_running:
			break
		_step(encounter)
	_check(not encounter.snapshot().round_running, "round drains without hanging")


func _initial_and_valid() -> void:
	var encounter = _new()
	var view: Dictionary = encounter.guidance_snapshot()
	_check(view.schema_version == 1 and view.guidance_revision == 0, "initial version1/revision0")
	_check(view.pending.guidance_type == "NONE" and view.active.is_empty(), "initial pending NONE / no active")
	_check(view.pending.generation == view.generation and view.pending.round_id == 1
		and view.pending.issuer_player_id == "player", "pending session identity")
	_check(not encounter.snapshot().has("guidance") and not encounter.decision_context().has("guidance"),
		"existing snapshot and strict decision context have no new Guidance fields")
	_record("D01", "Initial NONE, no frozen Guidance, revision0; existing schemas unchanged", view)
	for row in [["D02", "ATTACK", [""]], ["D03", "DEFEND", [""]],
		["D04", "HELP", [""]], ["D05", "FOCUS_TARGET", ["enemy_a", "enemy_b"]]]:
		for target in row[2]:
			var before: Dictionary = encounter.snapshot()
			var request: Dictionary = _request(encounter, row[1], target)
			var revision: int = request.expected_guidance_revision
			_check(encounter.submit_guidance(request).status == "ACCEPTED", "valid " + row[1] + target)
			view = encounter.guidance_snapshot()
			_check(view.guidance_revision == revision + 1 and view.pending.guidance_type == row[1]
				and view.pending.preferred_target_id == target, "accepted Guidance increments revision once")
			request.guidance_type = "FORGED"
			request.preferred_target_id = "unknown"
			_check(encounter.guidance_snapshot() == view and encounter.snapshot() == before,
				"request mutation detached; submission changes no combat state")
		_record(row[0], "Accept " + row[1] + " as data only; request detached; revision increments", view)


func _invalid_requests() -> void:
	var encounter = _new()
	for value in ["UNKNOWN", "attack", "", null, true, 1, 1.0, [], {}]:
		var request: Dictionary = _request(encounter)
		request.guidance_type = value
		_reject(encounter, request, "INVALID_GUIDANCE_TYPE")
	_record("D06", "Unknown/wrong-type enums rejected without writes")
	for value in [0, 2, -1, 1.0, true, null, "1", []]:
		var request: Dictionary = _request(encounter)
		request.schema_version = value
		_reject(encounter, request, "INVALID_GUIDANCE_VERSION")
	_record("D07", "Only integer schema_version1 accepted")
	for value in [null, true, [], 1, "request"]:
		_reject(encounter, value, "INVALID_GUIDANCE_FIELDS")
	for field in Contract.REQUEST_FIELDS:
		var missing: Dictionary = _request(encounter)
		missing.erase(field)
		_reject(encounter, missing, "INVALID_GUIDANCE_FIELDS")
		for value in [null, [], {}, true, 1.5]:
			var wrong: Dictionary = _request(encounter)
			wrong[field] = value
			_reject(encounter, wrong)
	var extra: Dictionary = _request(encounter)
	extra.extra = 1
	_reject(encounter, extra, "INVALID_GUIDANCE_FIELDS")
	for field in ["encounter_id", "generation", "round_id", "expected_guidance_revision"]:
		var bad: Dictionary = _request(encounter)
		bad[field] = 0 if field == "encounter_id" else -1
		_reject(encounter, bad, "INVALID_GUIDANCE_IDENTITY")
	_record("D08", "Exact eight fields, strict types and identity bounds; missing/extra rejected")
	for issuer in ["npc_01", "enemy_a", "other_player", "", "Player", "bad id"]:
		var request: Dictionary = _request(encounter)
		request.issuer_player_id = issuer
		_reject(encounter, request)
	for target in ["player", "npc_01", "unknown", "", "Enemy B"]:
		_reject(encounter, _request(encounter, "FOCUS_TARGET", target))
	for kind in ["NONE", "ATTACK", "DEFEND", "HELP"]:
		_reject(encounter, _request(encounter, kind, "enemy_a"), "INVALID_GUIDANCE_TARGET")
	var foreign = _new()
	_reject(encounter, _request(foreign), "FOREIGN_ENCOUNTER")
	_record("D09", "Issuer must be current Player; only FOCUS has a known enemy preference; foreign encounter rejected")
	var request: Dictionary = _request(encounter)
	request.generation += 1
	_reject(encounter, request, "STALE_GENERATION")
	_record("D10", "Wrong generation rejected")
	request = _request(encounter)
	request.round_id += 1
	_reject(encounter, request, "WRONG_ROUND")
	_record("D11", "Wrong round rejected")
	request = _request(encounter)
	request.expected_guidance_revision += 1
	_reject(encounter, request, "STALE_GUIDANCE_REVISION")
	_record("D12", "Future/unmatched Guidance revision rejected")
	request = _request(encounter)
	_check(encounter.submit_guidance(request).status == "ACCEPTED", "first request accepted")
	_reject(encounter, request, "STALE_GUIDANCE_REVISION")
	var stale_change: Dictionary = request.duplicate(true)
	stale_change.guidance_type = "DEFEND"
	_reject(encounter, stale_change, "STALE_GUIDANCE_REVISION")
	_check(encounter.submit_guidance(_request(encounter, "NONE")).status == "ACCEPTED",
		"explicit NONE clears pending at a fresh revision")
	_record("D13", "Exact replay and stale competing edit rejected; fresh NONE accepted", encounter.guidance_snapshot())


func _profiles_and_isolation() -> void:
	var encounter = _new()
	_check(encounter.submit_guidance(_request(encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "scenario Guidance accepted")
	var pristine: Dictionary = encounter.guidance_snapshot()
	var view: Dictionary = encounter.guidance_snapshot()
	view.pending.guidance_type = "FORGED"
	view.pending.preferred_target_id = "player"
	view.active.fake = true
	view.profiles.clear()
	view.guidance_revision = 999
	_check(encounter.guidance_snapshot() == pristine, "nested pending/profile snapshot does not alias owner")
	encounter.begin_round("DEFEND")
	pristine = encounter.guidance_snapshot()
	view = encounter.guidance_snapshot()
	view.active.guidance_type = "NONE"
	view.active.generation = -1
	view.pending.fake = true
	_check(encounter.guidance_snapshot() == pristine, "frozen snapshot also detached")
	_record("D14", "Mutating outer/nested pending/active snapshots cannot change owner", pristine)
	for actor in pristine.profiles:
		_check(Contract.validate_profile(pristine.profiles[actor]) == "", "stored profile validates " + actor)
		_check(pristine.profiles[actor].player_id == "player", "Trust bound to current Player")
	for field in Contract.PROFILE_FIELDS:
		var profile: Dictionary = Contract.fixed_profile("npc_01", "player")
		profile.erase(field)
		_check(not Contract.validate_profile(profile).is_empty(), "missing profile field " + field)
		for value in [null, true, 1.0, [], {}, "UNKNOWN"]:
			profile = Contract.fixed_profile("npc_01", "player")
			profile[field] = value
			_check(not Contract.validate_profile(profile).is_empty(), "wrong profile value " + field)
	var profile: Dictionary = Contract.fixed_profile("npc_01", "player")
	profile.extra = 1
	_check(Contract.validate_profile(profile) == "INVALID_PROFILE_FIELDS", "no arbitrary profile fields")
	_check(Contract.fixed_profile("player", "player").is_empty(), "NPC and Player identity cannot coincide")
	for discipline in ["FLEXIBLE", "PLAN_ORIENTED"]:
		for trust in ["CAUTIOUS", "ESTABLISHED"]:
			for compassion in ["ORDINARY", "HIGH"]:
				for courage in ["CAUTIOUS", "BOLD"]:
					profile = Contract.fixed_profile("companion_z", "adventurer")
					profile.merge({"discipline": discipline, "trust": trust, "compassion": compassion, "courage": courage}, true)
					_check(Contract.validate_profile(profile).is_empty(), "all approved enum combinations valid")
	_record("D15", "Profiles use exact versioned fields and four approved trait enums; no self-preservation score", pristine.profiles)
	encounter = _new()
	pristine = encounter.guidance_snapshot()
	view = encounter.guidance_snapshot()
	view.profiles.npc_02.trust = "FORGED"
	profile = Contract.fixed_profile("npc_02", "player")
	profile.compassion = "FORGED"
	_check(encounter.guidance_snapshot() == pristine, "external profile dictionaries cannot change stored profile")
	encounter.reorder_party(["npc_03", "npc_01", "npc_02"])
	_check(encounter.guidance_snapshot().profiles == pristine.profiles, "profiles follow stable IDs, not slots")
	encounter.unregister_actor("npc_02")
	_check(not encounter.guidance_snapshot().profiles.has("npc_02"), "removed NPC profile removed")
	var definition = Definition.create({"actor_id": "companion_z", "display_name": "Companion Z", "role": "NPC", "base_max_hp": 10})
	_check(encounter.register_actor(definition, Runtime.create(definition), "PARTY"), "register custom stable NPC")
	_check(encounter.guidance_snapshot().profiles.companion_z == Contract.fixed_profile("companion_z", "player"), "new NPC receives fixed profile")
	var fixture: Dictionary = _fixture()
	fixture.player_id = "adventurer"
	fixture.actors[0].definition.actor_id = "adventurer"
	_check(encounter.restart(fixture), "Restart with a different Player ID")
	for stored in encounter.guidance_snapshot().profiles.values():
		_check(stored.player_id == "adventurer", "Trust rebound; previous Player relationship not inherited")
	fixture.actors[1].definition.actor_id = "forged"
	_check(encounter.guidance_snapshot().profiles.has("npc_01"), "Restart input detached")
	_record("D16", "Profile isolation, stable-ID reorder/register/remove and current Player binding", encounter.guidance_snapshot())


func _lifecycle() -> void:
	var encounter = _new()
	_check(encounter.submit_guidance(_request(encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "scenario Guidance accepted")
	var pending: Dictionary = encounter.guidance_snapshot().pending
	_check(encounter.begin_round("DEFEND").status == "STARTED", "valid Player command starts round")
	_check(encounter.guidance_snapshot().active == pending and encounter.guidance_snapshot().pending.is_empty(),
		"successful begin_round freezes exact accepted record and empties pending")
	_check(encounter.guidance_snapshot().active.round_id == encounter.snapshot().round_id, "frozen round identity")
	_record("D17", "Atomic freeze only after valid Player command", encounter.guidance_snapshot())
	encounter = _new()
	_check(encounter.submit_guidance(_request(encounter, "HELP")).status == "ACCEPTED", "scenario Guidance accepted")
	for args in [["HELP", "", {}], ["ATTACK", "unknown", {}], ["DEFEND", "enemy_a", {}],
		["ATTACK", "", {"enemy_a": "enemy_b"}], [null, "", {}]]:
		var before: Dictionary = encounter.snapshot()
		var data: Dictionary = encounter.guidance_snapshot()
		_check(encounter.begin_round(args[0], args[1], args[2]).status == "REJECTED", "bad Player command rejected")
		_check(encounter.snapshot() == before and encounter.guidance_snapshot() == data, "rejected command preserves pending and revision")
	_record("D18", "Rejected Player commands never freeze or lose pending Guidance")
	encounter.begin_round("DEFEND")
	var request: Dictionary = _request(encounter)
	_reject(encounter, request, "COMMAND_LOCKED")
	var token: Dictionary = encounter.begin_next_action()
	_reject(encounter, request, "COMMAND_LOCKED")
	encounter.resolve_action(token)
	_reject(encounter, request, "COMMAND_LOCKED")
	encounter.complete_action(token)
	_reject(encounter, request, "COMMAND_LOCKED")
	_check(not encounter.set_lifecycle(true, false), "fixture lifecycle cannot unlock running round")
	_record("D19", "Submission rejected before/during/after impact and between queued slots")
	var revision: int = encounter.guidance_snapshot().guidance_revision
	_drain(encounter)
	var data: Dictionary = encounter.guidance_snapshot()
	_check(data.active.is_empty() and data.pending.guidance_type == "NONE" and data.pending.round_id == 2,
		"round completion clears active and restores next-round NONE")
	_check(data.guidance_revision == revision and encounter.snapshot().round_completions == 1,
		"revision counts accepted submissions only; round completes once")
	_reject(encounter, request, "WRONG_ROUND")
	encounter.begin_round("DEFEND")
	_check(encounter.guidance_snapshot().active.guidance_type == "NONE", "Guidance does not cross rounds")
	_drain(encounter)
	_record("D20", "Next command-ready round starts NONE; old round requests rejected", encounter.guidance_snapshot())
	for hp in [{"player": 0}, {"enemy_a": 0, "enemy_b": 0}]:
		encounter = _new(hp)
		data = encounter.guidance_snapshot()
		_check(data.pending.is_empty() and data.active.is_empty(), "terminal Restart has no usable Guidance")
		_reject(encounter, _request(encounter), "", "TERMINAL")
	for hp in [{"enemy_a": 5, "enemy_b": 0}, {"player": 1, "npc_01": 0, "npc_02": 0, "npc_03": 0}]:
		encounter = _new(hp)
		_check(encounter.submit_guidance(_request(encounter, "ATTACK")).status == "ACCEPTED", "scenario Guidance accepted")
		encounter.begin_round("ATTACK", "enemy_a")
		while encounter.snapshot().round_running:
			token = encounter.begin_next_action()
			_check(token.has("decision"), "terminal scenario locks next action")
			if not token.has("decision"):
				break
			encounter.resolve_action(token)
			if not encounter.snapshot().result.is_empty():
				_check(encounter.guidance_snapshot().active.is_empty() and encounter.guidance_snapshot().pending.is_empty(),
					"terminal clears Guidance at impact, before return/completion")
				_reject(encounter, _request(encounter), "", "TERMINAL")
			encounter.complete_action(token)
		_check(not encounter.snapshot().result.is_empty() and not encounter.snapshot().round_running, "terminal queue drained")
	_record("D21", "Victory/defeat reject Guidance and clear active immediately without blocking completion")


func _old_callback(encounter, token: Dictionary, request: Dictionary) -> void:
	callbacks.append(encounter.submit_guidance(request))
	callbacks.append(encounter.resolve_action(token))
	callbacks.append(encounter.complete_action(token))


func _restarts() -> void:
	var scenarios: int = 0
	for actor in ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"]:
		for after_effect in [false, true]:
			var encounter = _new({"player": 6})
			_check(encounter.submit_guidance(_request(encounter, "HELP")).status == "ACCEPTED", "scenario Guidance accepted")
			var request: Dictionary = _request(encounter, "DEFEND")
			encounter.begin_round("DEFEND")
			while encounter.snapshot().pending[0] != actor:
				_step(encounter)
			var token: Dictionary = encounter.begin_next_action()
			if after_effect:
				encounter.resolve_action(token)
			callbacks.clear()
			create_timer(0.01).timeout.connect(_old_callback.bind(encounter, token, request))
			_check(encounter.restart(_fixture()), "valid Restart at " + actor)
			var data: Dictionary = encounter.guidance_snapshot()
			_check(data.generation == token.generation + 1 and data.guidance_revision == 0
				and data.active.is_empty() and data.pending.guidance_type == "NONE", "Restart resets Guidance under new generation")
			_reject(encounter, request, "STALE_GENERATION")
			var before: Dictionary = encounter.snapshot()
			await create_timer(0.03).timeout
			_check(callbacks.size() == 3 and callbacks[0].status == "REJECTED"
				and callbacks[1].status == "REJECTED" and callbacks[2].status == "REJECTED", "real stale callbacks rejected")
			_check(encounter.snapshot() == before and encounter.guidance_snapshot() == data, "old callbacks cannot touch restarted state")
			_check(encounter.submit_guidance(_request(encounter, "ATTACK")).status == "ACCEPTED", "fresh generation can submit")
			encounter.begin_round("DEFEND")
			var fresh: Dictionary = encounter.begin_next_action()
			before = encounter.snapshot()
			data = encounter.guidance_snapshot()
			_old_callback(encounter, token, request)
			_check(encounter.snapshot() == before and encounter.guidance_snapshot() == data, "old token inert against reused actionID1")
			encounter.resolve_action(fresh)
			encounter.complete_action(fresh)
			_drain(encounter)
			scenarios += 1
	_record("D22", "Restart before/after effect at all six actors rejects delayed old requests/tokens; fresh round works", {"scenarios": scenarios})
	var encounter = _new()
	_check(encounter.submit_guidance(_request(encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "scenario Guidance accepted")
	for stage in ["PENDING", "FROZEN", "RESOLVED"]:
		var token: Dictionary = {}
		if stage == "FROZEN":
			encounter.begin_round("DEFEND")
			token = encounter.begin_next_action()
		elif stage == "RESOLVED":
			encounter.resolve_action(encounter.snapshot().locked_action)
		var before: Dictionary = encounter.snapshot()
		var data: Dictionary = encounter.guidance_snapshot()
		for bad in [null, {}, {"extra": 1}]:
			_check(not encounter.restart(bad), "malformed Restart rejected")
		var invalid: Dictionary = _fixture()
		invalid.actors[-1].initial_hp = -1
		_check(not encounter.restart(invalid), "invalid actor Restart rejected")
		_check(encounter.snapshot() == before and encounter.guidance_snapshot() == data, "invalid Restart atomic at " + stage)
	_record("D23", "Failed Restart preserves pending/frozen Guidance, profiles, generation and all combat state")


func _normalized(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[key] = 0 if key == "encounter_id" else _normalized(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value:
			result.append(_normalized(entry))
		return result
	return value


func _equivalent_round(hp: Dictionary, kind: String, command: String, targets: Dictionary) -> void:
	var plain = _new(hp)
	var guided = _new(hp)
	var plain_view: Dictionary = _normalized(plain.snapshot())
	_check(guided.submit_guidance(_request(guided, kind, "enemy_b" if kind == "FOCUS_TARGET" else "")).status == "ACCEPTED", "matrix valid data accepted")
	_check(_normalized(guided.snapshot()) == plain_view and guided.decision_context() == plain.decision_context(), "submission leaves decision context and gameplay identical")
	plain.begin_round(command, "enemy_b" if command == "ATTACK" else "", targets)
	guided.begin_round(command, "enemy_b" if command == "ATTACK" else "", targets)
	for slot in range(8):
		if not plain.snapshot().round_running:
			break
		var a: Dictionary = plain.begin_next_action()
		var b: Dictionary = guided.begin_next_action()
		_check(a.has("decision") and b.has("decision"), "both queues lock a slot")
		if not a.has("decision") or not b.has("decision"):
			break
		_check(_normalized(a) == _normalized(b), "entire locked token/decision/reason equal")
		_check(plain.resolve_action(a) == guided.resolve_action(b), "effects identical")
		_check(_normalized(plain.snapshot()) == _normalized(guided.snapshot()), "HP/HELP/guard/queue/revisions/terminal equal at effect")
		_check(plain.complete_action(a) == guided.complete_action(b), "completions identical")
		_check(_normalized(plain.snapshot()) == _normalized(guided.snapshot()), "state identical after completion")
	_check(not plain.snapshot().round_running and not guided.snapshot().round_running, "both rounds terminate")


func _policy_equivalence() -> void:
	for hp in [{}, {"player": 6}, {"npc_01": 3}, {"npc_01": 0}, {"enemy_a": 0}]:
		_equivalent_round(hp, "NONE", "DEFEND", {"enemy_a": "npc_01"})
	var encounter = _new({"player": 12})
	_check(encounter.submit_guidance(_request(encounter, "HELP")).status == "ACCEPTED", "scenario Guidance accepted")
	encounter.begin_round("DEFEND")
	_step(encounter)
	var resolver = Resolver.new()
	var context: Dictionary = encounter.decision_context()
	var expected: Dictionary = resolver.decide_for_actor("npc_01", context)
	var locked: Dictionary = encounter.begin_next_action()
	_check(locked.decision == expected and expected.action == "ATTACK" and expected.reason_code == "ATTACK_AVAILABLE_ENEMY",
		"HELP at Player40% still ATTACK; HELP50% is not implemented")
	_check(not context.has("profiles") and context.size() == 7, "strict seven-field multi context unchanged")
	_record("D24", "NONE is identical across normal/HELP/self-defense/dead fixtures; Resolver schema and 30% threshold preserved")
	var matrix: int = 0
	for kind in Contract.TYPES:
		for player_hp in [1, 6, 9, 10, 12, 15, 16, 30]:
			for npc_hp in [0, 3, 4, 10]:
				for enemy_hp in [[15, 12], [5, 12], [15, 5], [0, 12], [15, 0]]:
					for command in ["ATTACK", "DEFEND"]:
						_equivalent_round({"player": player_hp, "npc_01": npc_hp,
							"enemy_a": enemy_hp[0], "enemy_b": enemy_hp[1]}, kind, command,
							{"enemy_a": "npc_01", "enemy_b": "player"})
						matrix += 1
	_record("D25", "Every Guidance type preserves complete decisions/effects/queue/terminal across the Cartesian fixture matrix",
		{"round_pairs": matrix, "guidance_types": Contract.TYPES, "player_hp": [1, 6, 9, 10, 12, 15, 16, 30],
		"npc_hp": [0, 3, 4, 10], "enemies": [[15, 12], [5, 12], [15, 5], [0, 12], [15, 0]], "commands": ["ATTACK", "DEFEND"]})
	encounter = _new({"enemy_b": 0})
	var before: Dictionary = encounter.snapshot()
	_check(encounter.submit_guidance(_request(encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "known HP0 preference accepted as data")
	_check(encounter.snapshot() == before, "known HP0 preference changes no effect/resource/target")
	encounter.begin_round("DEFEND")
	_step(encounter)
	locked = encounter.begin_next_action()
	_check(locked.decision.action == "ATTACK" and locked.decision.target_id == "enemy_a", "known dead preference does not influence NPC")
	var stable: Dictionary = encounter.snapshot()
	_reject(encounter, _request(encounter, "HELP"), "COMMAND_LOCKED")
	_check(encounter.snapshot() == stable, "locked token unmodified")
	encounter = _new()
	_check(encounter.submit_guidance(_request(encounter, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "scenario Guidance accepted")
	encounter.unregister_actor("enemy_b")
	_check(encounter.guidance_snapshot().pending.guidance_type == "NONE", "removing preferred enemy clears obsolete pending preference")
	_record("D26", "Data submission never changes HP/HELP/guards/queue/token; HP0 known target valid; removed target clears preference")


func _run() -> void:
	_initial_and_valid()
	_invalid_requests()
	_profiles_and_isolation()
	_lifecycle()
	await _restarts()
	_policy_equivalence()
	_check(cases.size() == 26, "D01-D26 focused coverage; D27/D28 supplied by full regression evidence")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases,
				"external_gates": {"D27": "gameplay / invalid-actions / presentation-proof",
					"D28": "all inherited proofs / main-cutover-proof / cutover-release-gates"}}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
