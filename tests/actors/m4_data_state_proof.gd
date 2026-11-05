extends SceneTree

const Definition = preload("res://scripts/actors/actor_definition.gd")
const State = preload("res://scripts/m4/isolated_actor_state.gd")
const Registry = preload("res://scripts/m4/isolated_registry.gd")
const Encounter = preload("res://scripts/m4/isolated_encounter.gd")
const LegacyState = preload("res://scripts/actors/actor_runtime_state.gd")
const LegacyRegistry = preload("res://scripts/actors/actor_registry.gd")
const FullParty = preload("res://scripts/combat/full_party_encounter.gd")
const Guided = preload("res://scripts/combat/guided_encounter.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Guidance = preload("res://scripts/npc/guidance_data_contract.gd")
var checks: int = 0
var failures: int = 0
var cases: Array = []
var _start_checks: int = 0
var _start_failures: int = 0
var _current: Dictionary = {}
var example: Dictionary = {}


class ForgedParty:
	extends "res://scripts/m4/isolated_actor_state.gd"
	var forged: Dictionary = {}
	func snapshot() -> Dictionary:
		return forged.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + str(_current.get("id", "")) + " " + description)


func _begin(id: String, expected: String) -> void:
	_start_checks = checks
	_start_failures = failures
	_current = {"id": id, "expected": expected}


func _end() -> void:
	_current["actual"] = "PASS" if failures == _start_failures else "FAIL"
	_current["checks"] = checks - _start_checks
	cases.append(_current)
	print("CASE " + _current.id + ": " + _current.actual)


func _definition(id: String = "player", role: String = "PLAYER") -> ActorDefinition:
	return Definition.create({"actor_id": id, "display_name": id, "role": role, "base_max_hp": 10})


func _fixture_state(hp: Variant = 3, life: Variant = "ALIVE", participation: Variant = "PRESENT") -> Dictionary:
	return {"current_hp": hp, "life_state": life, "participation": participation}


func _fixture() -> Dictionary:
	return {"actors": [
		{"definition": _definition().snapshot(), "state": _fixture_state()},
		{"definition": _definition("npc_01", "NPC").snapshot(), "state": _fixture_state(10)},
		{"definition": _definition("enemy_a", "ENEMY").snapshot(), "state": {"current_hp": 0}}]}


func _encounter():
	var encounter = Encounter.new()
	_check(encounter.restart(_fixture()), "valid fixture creates encounter")
	return encounter


func _request(encounter, operation: String = "damage_one", actor: Variant = "player", amount: Variant = 3) -> Dictionary:
	var view: Dictionary = encounter.snapshot()
	return {"session_id": view.session_id, "generation": view.generation,
		"revision": view.revision, "operation_id": operation, "actor_id": actor, "amount": amount}


func _reject_unchanged(encounter, token: Variant, reason: String) -> void:
	var before: Dictionary = encounter.snapshot()
	var result: Dictionary = encounter.apply_fixture_damage(token)
	_check(result == {"status": "REJECTED", "reason_code": reason, "hp_delta": 0}, "exact rejection: " + reason)
	_check(encounter.snapshot() == before, "rejected operation has no HP/life/revision/roster delta")


func _states() -> void:
	for role in ["PLAYER", "NPC"]:
		for spec in [[10, "ALIVE", "PRESENT", true], [0, "DOWN", "PRESENT", false],
			[0, "DEAD", "PRESENT", false], [7, "ALIVE", "RETREATED", false]]:
			_begin("valid_" + role + "_" + spec[1] + "_" + spec[2], "valid pair round-trips with HP and derived eligibility preserved")
			var definition = _definition("party_actor", role)
			var fixture: Dictionary = _fixture_state(spec[0], spec[1], spec[2])
			var state = State.create(definition, fixture)
			_check(state != null, "factory returns validated complete state")
			var view: Dictionary = state.snapshot()
			_check(State.exact_fields(view, State.SNAPSHOT_FIELDS), "exact isolated snapshot fields")
			_check(view.schema_version == 1 and view.actor_id == "party_actor" and view.role == role, "identity preserved")
			_check(view.current_hp == spec[0] and view.max_hp == 10, "HP boundary/preservation")
			_check(view.life_state == spec[1] and view.participation == spec[2] and view.eligible == spec[3], "state and derived eligibility")
			_check(State.from_snapshot(definition, view).snapshot() == view, "copy reconstruction never resets life to ALIVE")
			var registry = Registry.new(RefCounted.new())
			_check(registry.register_actor(definition, state), "all valid pairs register")
			_check(registry.actor_snapshot("party_actor").state == view, "registration loses no lifecycle data")
			fixture.current_hp = 1
			view.life_state = "ALIVE"
			view.current_hp = 1
			_check(registry.actor_snapshot("party_actor").state == state.snapshot(), "copy-in and copy-out detached")
			_end()
	for spec in [[0, "DOWN", "RETREATED"], [0, "DEAD", "RETREATED"],
		[0, "ALIVE", "PRESENT"], [0, "ALIVE", "RETREATED"],
		[1, "DOWN", "PRESENT"], [1, "DEAD", "PRESENT"],
		[-1, "DOWN", "PRESENT"], [11, "ALIVE", "PRESENT"],
		[1, "UNAVAILABLE", "PRESENT"], [1, "ALIVE", "ABSENT"]]:
		_begin("invalid_pair_hp_%s_%s_%s" % spec, "invalid fixture returns null; no partial state")
		var input: Dictionary = _fixture_state(spec[0], spec[1], spec[2])
		var before: Dictionary = input.duplicate(true)
		_check(State.create(_definition(), input) == null, "reject invalid pair or HP invariant")
		_check(input == before, "invalid factory input untouched")
		_end()
	for field in State.FIXTURE_FIELDS:
		_begin("fixture_types_" + field, "missing/unknown/malformed scalar fields reject without coercion")
		for wrong in [null, true, 1.0, [], {}, "3"]:
			var input: Dictionary = _fixture_state()
			input[field] = wrong
			_check(State.create(_definition(), input) == null, "invalid type/value rejected")
		var missing: Dictionary = _fixture_state()
		missing.erase(field)
		_check(State.create(_definition(), missing) == null, "missing field rejected")
		_end()
	_begin("factory_boundaries", "bare definitions, enemy party lifecycle, non-dictionaries and extra fields reject")
	for wrong in [null, true, 1, [], "ALIVE"]:
		_check(State.create(_definition(), wrong) == null, "non-dictionary rejected")
	_check(State.create(Definition.new(), _fixture_state()) == null, "bare definition rejected")
	_check(State.create(_definition().snapshot(), _fixture_state()) == null, "raw definition rejected")
	_check(State.create(_definition("enemy_a", "ENEMY"), _fixture_state()) == null, "enemy not assigned party lifecycle")
	var extra: Dictionary = _fixture_state()
	extra["bleed_out"] = 2
	_check(State.create(_definition(), extra) == null, "unknown fixture field rejected")
	_end()


func _copies() -> void:
	var definition = _definition()
	var state = State.create(definition, _fixture_state(0, "DEAD"))
	for field in State.SNAPSHOT_FIELDS:
		_begin("snapshot_contract_" + field, "strict snapshot type/value and identity checks reject forged copies")
		var valid: Dictionary = state.snapshot()
		for wrong in [null, true, 1.0, [], {}, "wrong"]:
			var malformed: Dictionary = valid.duplicate(true)
			malformed[field] = wrong
			_check(State.from_snapshot(definition, malformed) == null, "malformed snapshot field rejected")
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		_check(State.from_snapshot(definition, missing) == null, "missing snapshot field rejected")
		_end()
	_begin("snapshot_unknown_and_identity", "unknown fields, version, derived eligibility and identity mismatches rejected on reconstruction and registration")
	for changes in [{"extra": 1}, {"schema_version": 2}, {"actor_id": "npc_01"}, {"role": "NPC"},
		{"max_hp": 9}, {"eligible": true}, {"life_state": "ALIVE"}, {"participation": "RETREATED"}]:
		var forged = ForgedParty.new()
		forged.forged = state.snapshot()
		forged.forged.merge(changes, true)
		var registry = Registry.new(RefCounted.new())
		_check(not registry.register_actor(definition, forged), "invalid registration rejects forged runtime")
		_check(registry.snapshot() == {}, "registry unchanged after invalid registration")
	_end()
	_begin("registry_ownership", "one owned state per ID; detached nested reads; invalid registration never replaces state")
	var capability := RefCounted.new()
	var registry = Registry.new(capability)
	_check(registry.register_actor(definition, state), "DEAD state registered")
	var before: Dictionary = registry.snapshot()
	_check(not registry.register_actor(definition, State.create(definition, _fixture_state())), "duplicate ID rejected, no accidental revival")
	_check(not registry.register_actor(definition, State.new()), "bare runtime rejected")
	_check(not registry.register_actor(Definition.new(), state), "bare definition rejected")
	_check(not registry.register_actor(null, state), "null definition rejected")
	_check(not registry.register_actor(_definition("npc_01", "NPC"), state), "foreign actor ID rejected")
	_check(not registry.register_actor(_definition("enemy_a", "ENEMY"), state), "role mismatch rejected")
	var changed_max: Dictionary = definition.snapshot()
	changed_max.base_max_hp = 20
	_check(not registry.register_actor(Definition.create(changed_max), state), "max HP mismatch rejected")
	_check(registry.snapshot() == before, "all invalid registrations atomic")
	var view: Dictionary = registry.snapshot()
	view.player.state.life_state = "ALIVE"
	view.player.state.current_hp = 10
	view.player.definition.role = "ENEMY"
	view.clear()
	_check(registry.snapshot() == before, "deep nested snapshot mutation cannot change owner")
	_check(registry.commit_fixture_damage("player", 1, RefCounted.new()).reason_code == "UNAUTHORIZED", "wrong registry capability rejected")
	_check(registry.commit_fixture_damage("player", 1, null).reason_code == "UNAUTHORIZED", "null capability rejected")
	_check(registry.snapshot() == before, "unauthorized registry operation has no delta")
	_check(registry.actor_snapshot(1) == {} and registry.actor_snapshot("missing") == {}, "invalid lookup safe")
	_check(not state.has_method("heal") and not state.has_method("take_damage"), "isolated model has no raw mutation bypass")
	_end()
	_begin("party_mutable_reference_copy_in", "registry reconstructs its own state even from a retained mutable snapshot provider")
	var supplied = ForgedParty.new()
	supplied.forged = State.create(definition, _fixture_state(0, "DOWN")).snapshot()
	var party_registry = Registry.new(capability)
	_check(party_registry.register_actor(definition, supplied), "validated supplied snapshot registers")
	var party_before: Dictionary = party_registry.snapshot()
	supplied.forged.life_state = "ALIVE"
	supplied.forged.current_hp = 10
	supplied.forged.eligible = true
	_check(party_registry.snapshot() == party_before, "retained party reference cannot revive owned DOWN state")
	_end()
	_begin("enemy_copy_in_out", "Enemy HP0 retains production availability only; mutable source runtime cannot mutate registry")
	var enemy_definition = _definition("enemy_a", "ENEMY")
	var enemy = LegacyState.create(enemy_definition, 0)
	var enemy_registry = Registry.new(capability)
	_check(enemy_registry.register_actor(enemy_definition, enemy), "enemy registers without party model")
	var enemy_before: Dictionary = enemy_registry.snapshot()
	enemy.heal(5)
	_check(enemy_registry.snapshot() == enemy_before, "mutable enemy caller reference detached at entry")
	var row: Dictionary = enemy_registry.actor_snapshot("enemy_a")
	_check(row.state == {"actor_id": "enemy_a", "current_hp": 0, "max_hp": 10, "can_act": false}, "exact original enemy snapshot; no DEAD mapping")
	row.state.current_hp = 9
	_check(enemy_registry.snapshot() == enemy_before, "enemy read detached")
	_check(enemy_registry.commit_fixture_damage("enemy_a", 1, capability).reason_code == "PARTY_ONLY", "no enemy transition adapter")
	_end()


func _transitions() -> void:
	for actor in ["player", "npc_01"]:
		_begin("authorized_down_" + actor, "authorized lethal damage commits HP0 and DOWN together once; never DEAD")
		var encounter = _encounter()
		var before: Dictionary = encounter.snapshot()
		var grant: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "lethal", actor, 10))
		_check(grant.status == "AUTHORIZED" and encounter.snapshot() == before, "authorization alone never mutates actor/revision")
		var result: Dictionary = encounter.apply_fixture_damage(grant.token)
		var after: Dictionary = encounter.snapshot()
		_check(result == {"status": "APPLIED", "reason_code": "HP_ZERO_DOWN", "hp_delta": -before.actors[actor].state.current_hp}, "clamped exact effect")
		_check(after.actors[actor].state.current_hp == 0 and after.actors[actor].state.life_state == "DOWN", "HP0 is DOWN, not DEAD")
		_check(after.actors[actor].state.participation == "PRESENT" and not after.actors[actor].state.eligible, "participation and eligibility")
		_check(after.actors[actor].definition == before.actors[actor].definition, "ActorDefinition unchanged by transition")
		_check(after.revision == before.revision + 1, "one atomic revision")
		_reject_unchanged(encounter, grant.token, "DUPLICATE_OPERATION")
		_check(encounter.authorize_fixture_damage(_request(encounter, "lethal", actor)).reason_code == "DUPLICATE_OPERATION", "duplicate issuance rejected")
		if actor == "player":
			example = {"before": before.actors.player.state, "after": after.actors.player.state, "result": result,
				"expected": "HP3 ALIVE/PRESENT -> damage10 clamped -3 -> HP0 DOWN/PRESENT", "actual": "PASS"}
		_end()
	for amount in [0, 1, 9223372036854775807]:
		_begin("damage_boundary_" + str(amount), "zero is one authorized no-op; partial damage stays ALIVE; INT64_MAX clamps safely")
		var encounter = _encounter()
		var grant: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "boundary", "player", amount))
		var result: Dictionary = encounter.apply_fixture_damage(grant.token)
		var expected_hp: int = 3 - mini(amount, 3)
		_check(result.status == "APPLIED" and result.hp_delta == -mini(amount, 3), "exact clamped delta")
		_check(encounter.actor_snapshot("player").state.current_hp == expected_hp, "expected HP")
		_check(encounter.actor_snapshot("player").state.life_state == ("DOWN" if expected_hp == 0 else "ALIVE"), "expected life")
		_reject_unchanged(encounter, grant.token, "DUPLICATE_OPERATION")
		_end()
	for wrong in [-1, null, true, 1.0, "3", [], {}]:
		_begin("invalid_amount_" + str(wrong), "invalid amount rejected before issuance and at application, with no mutation")
		var encounter = _encounter()
		var before: Dictionary = encounter.snapshot()
		var request: Dictionary = _request(encounter, "bad_amount", "player", wrong)
		_check(encounter.authorize_fixture_damage(request).reason_code == "INVALID_AMOUNT", "invalid authorization amount rejected")
		request["authorization_id"] = 1
		_reject_unchanged(encounter, request, "INVALID_AMOUNT")
		_check(encounter.snapshot() == before, "issuance rejection also unchanged")
		_end()
	for spec in [["actor_id", "missing", "UNKNOWN_ACTOR"], ["actor_id", "../player", "UNKNOWN_ACTOR"],
		["actor_id", 1, "UNKNOWN_ACTOR"], ["session_id", 0, "FOREIGN_SESSION"],
		["generation", 0, "STALE_GENERATION"], ["revision", -1, "STALE_REVISION"],
		["generation", 1.0, "INVALID_IDENTITY_TYPE"], ["session_id", true, "INVALID_IDENTITY_TYPE"],
		["revision", "0", "INVALID_IDENTITY_TYPE"], ["operation_id", "", "INVALID_OPERATION_ID"],
		["operation_id", 1, "INVALID_OPERATION_ID"], ["actor_id", "enemy_a", "PARTY_ONLY"]]:
		_begin("request_" + spec[0] + "_" + str(spec[1]), "identity/state/operation validation rejects: " + spec[2])
		var encounter = _encounter()
		var request: Dictionary = _request(encounter)
		request[spec[0]] = spec[1]
		var before: Dictionary = encounter.snapshot()
		_check(encounter.authorize_fixture_damage(request).reason_code == spec[2], "authorization exact reason")
		request["authorization_id"] = 1
		_reject_unchanged(encounter, request, spec[2])
		_check(encounter.snapshot() == before, "all rejection phases atomic")
		_end()
	_begin("authorization_tampering", "unissued, altered, foreign and malformed grants cannot mutate owned state; valid grant remains usable")
	var encounter = _encounter()
	var grant: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "signed", "player", 1))
	var fabricated: Dictionary = _request(encounter, "unissued")
	fabricated["authorization_id"] = 1
	_reject_unchanged(encounter, fabricated, "UNAUTHORIZED")
	for changes in [{"amount": 2}, {"actor_id": "npc_01"}, {"authorization_id": 999}, {"operation_id": "other"}]:
		var altered: Dictionary = grant.token.duplicate(true)
		altered.merge(changes, true)
		_reject_unchanged(encounter, altered, "UNAUTHORIZED")
	for wrong in [null, [], true, {}, {"extra": 1}]:
		_reject_unchanged(encounter, wrong, "INVALID_TOKEN_FIELDS")
	for field in Encounter.TOKEN_FIELDS:
		var missing: Dictionary = grant.token.duplicate(true)
		missing.erase(field)
		_reject_unchanged(encounter, missing, "INVALID_TOKEN_FIELDS")
	for wrong in [true, 1.0, 0, -1]:
		var altered: Dictionary = grant.token.duplicate(true)
		altered.authorization_id = wrong
		_reject_unchanged(encounter, altered, "INVALID_TOKEN_FIELDS")
	var extra_token: Dictionary = grant.token.duplicate(true)
	extra_token["rescue"] = true
	_reject_unchanged(encounter, extra_token, "INVALID_TOKEN_FIELDS")
	var other = _encounter()
	_reject_unchanged(other, grant.token, "FOREIGN_SESSION")
	_check(encounter.apply_fixture_damage(grant.token).hp_delta == -1, "rejections do not consume genuine authorization")
	_end()
	_begin("strict_authorization_request", "new proof request requires exact fields; unknown/missing fields rejected")
	encounter = _encounter()
	for field in Encounter.REQUEST_FIELDS:
		var missing: Dictionary = _request(encounter)
		missing.erase(field)
		_check(encounter.authorize_fixture_damage(missing).reason_code == "INVALID_REQUEST_FIELDS", "missing request field rejected")
	var extra: Dictionary = _request(encounter)
	extra["life_state"] = "DEAD"
	_check(encounter.authorize_fixture_damage(extra).reason_code == "INVALID_REQUEST_FIELDS", "no caller-controlled transition destination")
	_end()
	for spec in [[0, "DOWN", "PRESENT"], [0, "DEAD", "PRESENT"], [7, "ALIVE", "RETREATED"]]:
		_begin("ineligible_" + spec[1], "fixture states preserved; no damage/heal/rescue/retreat/death triggers exposed")
		encounter = Encounter.new()
		var fixture: Dictionary = _fixture()
		fixture.actors[0].state = _fixture_state(spec[0], spec[1], spec[2])
		_check(encounter.restart(fixture), "valid seeded fixture")
		var before: Dictionary = encounter.snapshot()
		_check(encounter.authorize_fixture_damage(_request(encounter)).reason_code == "INELIGIBLE_STATE", "no grant to ineligible pair")
		var token: Dictionary = _request(encounter)
		token["authorization_id"] = 1
		_reject_unchanged(encounter, token, "INELIGIBLE_STATE")
		_check(encounter.snapshot() == before, "no implicit recovery/death/retreat")
		for forbidden in ["heal", "rescue", "retreat", "revive", "tick_bleed_out", "unregister_actor", "begin_round"]:
			_check(not encounter.has_method(forbidden), "out-of-scope API absent: " + forbidden)
		_end()
	_begin("stale_revision", "a second grant from old revision is stale after a different operation commits")
	encounter = _encounter()
	var first: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "first", "player", 1)).token
	var second: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "second", "npc_01", 1)).token
	_check(encounter.apply_fixture_damage(first).hp_delta == -1, "first operation commits")
	_reject_unchanged(encounter, second, "STALE_REVISION")
	_end()


func _restart() -> void:
	_begin("restart_generation", "restart rebuilds fixtures, rejects old tokens despite reused actor/operation IDs, and isolates old views")
	var encounter = _encounter()
	var old_token: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "same_id")).token
	var before: Dictionary = encounter.snapshot()
	_check(encounter.apply_fixture_damage(old_token).reason_code == "HP_ZERO_DOWN", "old session became DOWN")
	var old_down: Dictionary = encounter.snapshot()
	var fixture: Dictionary = _fixture()
	_check(encounter.restart(fixture), "valid restart")
	var fresh: Dictionary = encounter.snapshot()
	_check(fresh.generation == before.generation + 1 and fresh.session_id == before.session_id and fresh.revision == 0, "new generation with stable session and reset revision")
	_check(fresh.actors == before.actors, "exact fixture restored, not copied from old DOWN state")
	_reject_unchanged(encounter, old_token, "STALE_GENERATION")
	old_down.actors.player.state.current_hp = 9
	old_down.actors.player.state.life_state = "ALIVE"
	fixture.actors[0].state.current_hp = 1
	_check(encounter.snapshot() == fresh, "old snapshots and retained restart fixture cannot mutate new generation")
	var new_token: Dictionary = encounter.authorize_fixture_damage(_request(encounter, "same_id")).token
	_check(new_token.authorization_id != old_token.authorization_id, "authorization serial never recycled")
	_check(encounter.apply_fixture_damage(new_token).hp_delta == -3, "same operation ID works only with fresh generation grant")
	_reject_unchanged(encounter, old_token, "STALE_GENERATION")
	_end()
	var malformed_fixtures: Array = [null, [], {}, {"actors": []}, {"actors": [], "extra": true}, {"actors": "wrong"}]
	var bad_pair: Dictionary = _fixture()
	bad_pair.actors[2] = {"definition": _definition("bad_npc", "NPC").snapshot(), "state": _fixture_state(0, "DOWN", "RETREATED")}
	malformed_fixtures.append(bad_pair)
	var duplicate: Dictionary = _fixture()
	duplicate.actors.append(duplicate.actors[0].duplicate(true))
	malformed_fixtures.append(duplicate)
	var bad_enemy: Dictionary = _fixture()
	bad_enemy.actors[2].state["life_state"] = "DEAD"
	malformed_fixtures.append(bad_enemy)
	var bad_entry: Dictionary = _fixture()
	bad_entry.actors[2].extra = true
	malformed_fixtures.append(bad_entry)
	var bad_definition: Dictionary = _fixture()
	bad_definition.actors[2].definition.base_max_hp = 0
	malformed_fixtures.append(bad_definition)
	var null_enemy: Dictionary = _fixture()
	null_enemy.actors[2].state.current_hp = null
	malformed_fixtures.append(null_enemy)
	for index in range(malformed_fixtures.size()):
		_begin("invalid_restart_" + str(index), "invalid whole-roster replacement leaves state/generation and previously issued grants usable")
		encounter = _encounter()
		var grant: Dictionary = encounter.authorize_fixture_damage(_request(encounter)).token
		var saved: Dictionary = encounter.snapshot()
		_check(not encounter.restart(malformed_fixtures[index]), "malformed restart rejected")
		_check(encounter.snapshot() == saved, "no partial roster, generation or HP mutation")
		_check(encounter.apply_fixture_damage(grant).hp_delta == -3, "failed restart did not lose pending authorization")
		_end()


func _compatibility() -> void:
	_begin("production_contract", "original runtime/registry/Resolver/Guidance schemas and Main HP0 defeat unchanged")
	var definition = _definition()
	var legacy = LegacyState.create(definition, 0)
	_check(legacy.snapshot() == {"actor_id": "player", "current_hp": 0, "max_hp": 10, "can_act": false}, "original exact 4-field runtime snapshot")
	_check(legacy.heal(4).hp_delta == 4 and legacy.can_act(), "original raw fixture heal from zero retained")
	var registry = LegacyRegistry.new()
	_check(registry.register_actor(definition, legacy, "PARTY"), "original registry accepts original state")
	_check(State.exact_fields(registry.actor_snapshot("player"), ["actor_id", "display_name", "role", "base_max_hp", "current_hp", "max_hp", "can_act", "membership"]), "production exact actor fields unchanged")
	var full = FullParty.new()
	var guided = Guided.new()
	var resolver = Resolver.new()
	# Production decision contexts require enemy declarations from an active round.
	# Inspect that real boundary; a pre-round context is intentionally incomplete.
	_check(full.begin_round("DEFEND").status == "STARTED", "base starts real decision round")
	_check(guided.begin_round("DEFEND").status == "STARTED", "production starts real decision round")
	_check(resolver._validate_context("npc_01", full.decision_context()) == "", "original full-party context still valid")
	_check(resolver._validate_context("npc_01", guided.decision_context()) == "", "production guided context still valid")
	var polluted: Dictionary = guided.decision_context()
	polluted.actors.player["life_state"] = "ALIVE"
	_check(not resolver._validate_context("npc_01", polluted).is_empty(), "strict resolver still rejects unknown life fields")
	var identity: Dictionary = guided.guidance_snapshot()
	var request: Dictionary = {"schema_version": 1, "guidance_type": "NONE", "issuer_player_id": "player",
		"preferred_target_id": "", "encounter_id": identity.encounter_id, "generation": identity.generation,
		"round_id": identity.round_id, "expected_guidance_revision": identity.guidance_revision}
	_check(request.size() == 8 and Guidance.validate_request(request) == "", "Guidance v1 eight fields unchanged")
	request["participation"] = "PRESENT"
	_check(not Guidance.validate_request(request).is_empty(), "Guidance still rejects lifecycle field")
	for encounter in [full, guided]:
		_check(encounter.restart(FullParty.prototype_fixture()), "reset production fixture after context inspection")
		var baseline: Dictionary = encounter.snapshot()
		_check(encounter.fixture_damage("player", 100, baseline.generation).hp_delta == -30, "production fixture damage retained")
		_check(encounter.begin_round("ATTACK", "enemy_a").reason_code == "DEFEAT", "Main/base Player HP0 still DEFEAT")
		_check(not encounter.actor_snapshot("player").has("life_state"), "no lifecycle leakage into production")
	_end()


func _run() -> void:
	_states()
	_copies()
	_transitions()
	_restart()
	_compatibility()
	var report: Dictionary = {"task": "M4-01 Isolated Data/State Proof Candidate", "cases": cases,
		"independent_cases": cases.size(), "checks": checks, "per_frame_checks": 0,
		"failures": failures, "example": example,
		"architecture_acceptance": {"A01": "DATA ONLY: HP0->DOWN; no B2/clock/terminal migration",
			"A19": "DATA ONLY: owned copies/no raw heal API; no RESCUE rule",
			"A21": "DATA ONLY: invalid pairs/reconstruction/requests; no gameplay transitions"}}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file = FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file == null:
				_check(false, "report file must be writable")
			else:
				file.store_string(JSON.stringify(report, "\t") + "\n")
	print("CASES: %d independent cases; 0 per-frame checks" % cases.size())
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
