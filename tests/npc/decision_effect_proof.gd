extends SceneTree

const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Encounter = preload("res://scripts/npc/npc_proof_encounter.gd")
var checks: int = 0
var failures: int = 0
var cases: Dictionary = {}
var callback_results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _decision(token: Dictionary, action: String, target: String, reason: String) -> void:
	_check(token.has("decision"), "slot returns a decision")
	if not token.has("decision"):
		return
	_check(token.decision.action == action, "action: " + action)
	_check(token.decision.target_id == target, "target: " + target)
	_check(token.decision.reason_code == reason, "reason: " + reason)


func _case_done(id: String, before: int) -> void:
	cases[id] = "PASS" if failures == before else "FAIL"
	print("CASE " + id + ": " + cases[id])


func _play(settings: Dictionary, action: String, target: String, reason: String,
	expected: Dictionary) -> void:
	var encounter = Encounter.new()
	_check(encounter.restart(settings).status == "RESTARTED", "valid fixture")
	var token: Dictionary = encounter.begin_npc_slot()
	_decision(token, action, target, reason)
	_check(encounter.resolve_npc(token).status == "APPLIED", "effect applied")
	_check(encounter.complete_npc(token).status == "COMPLETED", "slot completes")
	var actual: Dictionary = encounter.inspect()
	for key in expected:
		_check(actual.state[key] == expected[key], "%s expected %s actual %s" % [
			key, expected[key], actual.state[key]])
	_check(actual.pending.is_empty(), "queue drained")
	_check(actual.round == 2 and actual.round_completions == 1, "round completes once")
	_check(not actual.self_defend, "self-defend expires")


func _basic_scenarios() -> void:
	var before: int = failures
	_play({}, "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY",
		{"enemy_hp": 9, "player_hp": 17, "npc_hp": 10})
	_case_done("S1", before)
	before = failures
	_play({"player_hp": 6}, "HELP", "player", "PLAYER_LOW_HP_HELP",
		{"enemy_hp": 10, "player_hp": 7, "help_uses_remaining": 0})
	_case_done("S2", before)
	before = failures
	_play({"npc_hp": 3, "incoming_target_id": "npc"}, "DEFEND", "npc", "SELF_LOW_HP_THREAT",
		{"npc_hp": 2, "player_hp": 20, "enemy_hp": 10})
	var unguarded = Encounter.new()
	unguarded.restart({"incoming_target_id": "npc"})
	var attack_token: Dictionary = unguarded.begin_npc_slot()
	unguarded.apply_fixture_change({"npc_hp": 3})
	unguarded.resolve_npc(attack_token)
	unguarded.complete_npc(attack_token)
	_check(unguarded.inspect().state.npc_hp == 0, "same hit exhausts unguarded NPC HP")
	_case_done("S3", before)
	before = failures
	_play({"player_hp": 6, "help_uses_remaining": 0}, "ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK",
		{"enemy_hp": 9, "player_hp": 3, "help_uses_remaining": 0})
	var unavailable = Encounter.new()
	unavailable.restart({"player_hp": 6, "help_enabled": false})
	_check(unavailable.begin_npc_slot().decision.reason_details.help_unavailable_reason == "HELP_DISABLED",
		"disabled ability explained")
	unavailable.restart({"player_hp": 6, "help_uses_remaining": 0})
	_check(unavailable.begin_npc_slot().decision.reason_details.help_unavailable_reason == "NO_HELP_USES",
		"exhausted HELP explained")
	_case_done("S4", before)
	before = failures
	_play({"player_hp": 6, "guidance": "ATTACK"}, "HELP", "player", "PLAYER_LOW_HP_HELP",
		{"player_hp": 7, "enemy_hp": 10, "help_uses_remaining": 0})
	_case_done("S6", before)
	before = failures
	_play({"player_hp": 6, "npc_hp": 3, "incoming_target_id": "npc"},
		"DEFEND", "npc", "SELF_LOW_HP_THREAT",
		{"player_hp": 6, "npc_hp": 2, "help_uses_remaining": 1})
	_case_done("S7", before)


func _dead_targets() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	var token: Dictionary = encounter.begin_npc_slot()
	encounter.apply_fixture_change({"enemy_hp": 0})
	var result: Dictionary = encounter.resolve_npc(token)
	_check(result.status == "SKIP" and result.reason_code == "TARGET_DEAD_BEFORE_RESOLVE",
		"enemy dies between decision and impact")
	encounter.complete_npc(token)
	var actual: Dictionary = encounter.inspect()
	_check(actual.state.enemy_hp == 0 and actual.state.player_hp == 20, "no damage or dead counter")
	_check(actual.result == "VICTORY" and actual.round == 1, "victory adds no round")
	_check(actual.pending.is_empty(), "terminal skip drains queue")
	_check(encounter.complete_npc(token).status == "REJECTED", "no second terminal completion")
	_case_done("S5", before)
	before = failures
	encounter.restart({"enemy_hp": 0})
	_check(encounter.begin_npc_slot().status == "SKIP", "dead before slot never starts action")
	_check(encounter.inspect().pending.is_empty(), "no pending work after terminal state")
	var resolver = Resolver.new()
	var decision: Dictionary = resolver.decide(encounter.situation_snapshot())
	_check(decision.action == "SKIP" and decision.reason_code == "NO_LIVING_ENEMY",
		"explicit SKIP, not empty dictionary")
	_case_done("S9", before)


func _boundaries_and_determinism() -> void:
	var before: int = failures
	var resolver = Resolver.new()
	var encounter = Encounter.new()
	for hp in [8, 9, 10]:
		encounter.restart({"player_hp": hp})
		var snapshot: Dictionary = encounter.situation_snapshot()
		var original: Dictionary = snapshot.duplicate(true)
		var decision: Dictionary = resolver.decide(snapshot)
		_check(decision.action == ("HELP" if hp <= 9 else "ATTACK"), "Player 30% inclusive boundary")
		for repetition in range(50):
			_check(resolver.decide(snapshot) == decision, "determinism")
		_check(snapshot == original, "resolver leaves input unchanged")
		decision.reason_details.player_hp = 0
		_check(snapshot == original, "reason does not alias snapshot")
	for hp in [2, 3, 4]:
		encounter.restart({"npc_hp": hp, "incoming_target_id": "npc", "incoming_damage": 1})
		var snapshot: Dictionary = encounter.situation_snapshot()
		var decision: Dictionary = resolver.decide(snapshot)
		_check(decision.action == ("DEFEND" if hp <= 3 else "ATTACK"),
			"NPC 30% inclusive boundary")
		for repetition in range(10):
			_check(resolver.decide(snapshot) == decision, "DEFEND determinism")
	encounter.restart({"npc_hp": 4, "incoming_target_id": "npc", "incoming_damage": 4})
	_check(resolver.decide(encounter.situation_snapshot()).reason_code == "SELF_LETHAL_THREAT",
		"lethal threat above threshold")
	encounter.restart({"npc_hp": 1, "incoming_target_id": "player"})
	_check(resolver.decide(encounter.situation_snapshot()).action == "ATTACK", "low HP alone is not threat")
	_case_done("S8", before)


func _limits_and_invalid_input() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	encounter.restart({"player_hp": 1, "incoming_damage": 0})
	var token: Dictionary = encounter.begin_npc_slot()
	_check(encounter.resolve_npc(token).hp_delta == 4, "HELP capped at four")
	encounter.complete_npc(token)
	_check(encounter.begin_npc_slot().decision.action == "ATTACK", "HELP unavailable on second round")
	encounter.restart({"player_hp": 1, "player_max_hp": 4, "incoming_damage": 0})
	token = encounter.begin_npc_slot()
	_check(encounter.resolve_npc(token).hp_delta == 3, "HELP clamped to max HP")
	_check(encounter.inspect().state.player_hp == 4, "no overheal")
	for damage in [1, 2, 3, 5]:
		encounter.restart({"npc_hp": 3, "incoming_target_id": "npc", "incoming_damage": damage})
		token = encounter.begin_npc_slot()
		encounter.resolve_npc(token)
		encounter.complete_npc(token)
		_check(encounter.inspect().state.npc_hp == maxi(0, 3 - maxi(1, damage - 2)),
			"DEFEND reduction and minimum one damage")
	encounter.restart({"npc_hp": 0, "incoming_target_id": "npc"})
	token = encounter.begin_npc_slot()
	_check(token.decision.reason_code == "ACTOR_UNAVAILABLE", "dead NPC explicitly skips")
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().state.npc_hp == 0, "enemy cannot hit dead NPC")
	encounter.restart({"player_hp": 0})
	_check(encounter.inspect().result == "DEFEAT", "Player zero is defeat, no revival")
	_check(encounter.begin_npc_slot().status == "SKIP", "no HELP after defeat")
	encounter.restart({"npc_hp": 3, "incoming_target_id": "npc", "incoming_damage": 0})
	_check(encounter.begin_npc_slot().decision.action == "ATTACK", "zero incoming damage is no threat")
	# A declared lethal hit can still kill: DEFEND never grants invulnerability.
	encounter.restart({"npc_hp": 1, "incoming_target_id": "npc", "incoming_damage": 3})
	token = encounter.begin_npc_slot()
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().state.npc_hp == 0, "minimum damage can exhaust NPC HP")
	encounter.restart({"enemy_hp": 1})
	token = encounter.begin_npc_slot()
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().result == "VICTORY" and encounter.inspect().state.player_hp == 20,
		"NPC killing blow suppresses enemy counter")
	var resolver = Resolver.new()
	var valid: Dictionary = Encounter.new().situation_snapshot()
	for key in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		_check(resolver.decide(missing).status == "INVALID_INPUT", "missing field: " + key)
		var wrong_type: Dictionary = valid.duplicate(true)
		wrong_type[key] = Node2D.new()
		_check(resolver.decide(wrong_type).status == "INVALID_INPUT", "Node rejected: " + key)
		wrong_type[key].free()
	for changes in [{"player_hp": -1}, {"npc_max_hp": 0}, {"player_hp": 31},
		{"help_uses_remaining": 2}, {"help_uses_remaining": -1},
		{"incoming_target_id": "unknown"}, {"living_enemy_ids": ["unknown"]},
		{"incoming_target_id": "", "incoming_damage": 3}, {"incoming_damage": -1},
		{"guidance": "COMMAND_HELP"}, {"extra": 1}]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.merge(changes, true)
		var original: Dictionary = invalid.duplicate(true)
		_check(resolver.decide(invalid).status == "INVALID_INPUT", "malformed snapshot rejected")
		_check(invalid == original, "invalid input not mutated")
	var original_state: Dictionary = encounter.inspect()
	_check(encounter.restart({"enemy_hp": -1}).status == "INVALID_INPUT", "bad restart rejected")
	_check(encounter.inspect() == original_state, "bad restart atomic")
	_case_done("limits-invalid-input", before)


func _locking_and_invalidated_help() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	var token: Dictionary = encounter.begin_npc_slot()
	_check(encounter.begin_npc_slot().reason_code == "SLOT_IN_PROGRESS", "no duplicate slot")
	_check(encounter.complete_npc(token).reason_code == "EFFECT_NOT_RESOLVED", "no early handoff")
	encounter.apply_fixture_change({"player_hp": 6})
	# Neither live state changes nor caller mutations may replace the locked action.
	token.decision.action = "HELP"
	token.decision.target_id = "player"
	encounter.resolve_npc(token)
	_check(encounter.inspect().state.enemy_hp == 9, "decision locked at slot start")
	_check(encounter.inspect().state.player_hp == 6, "not re-evaluated after locking")
	encounter.complete_npc(token)
	for change in [{"player_hp": 30}, {"help_enabled": false}, {"help_uses_remaining": 0},
		{"npc_hp": 0}, {"player_hp": 0}]:
		encounter.restart({"player_hp": 6})
		token = encounter.begin_npc_slot()
		encounter.apply_fixture_change(change)
		var state_before: Dictionary = encounter.inspect().state
		_check(encounter.resolve_npc(token).status == "SKIP", "validate HELP/actor before effect")
		_check(encounter.inspect().state == state_before, "failed HELP costs nothing, no fallback attack")
		encounter.complete_npc(token)
		_check(encounter.inspect().pending.is_empty(), "invalid HELP cannot stall queue")
	_case_done("locking-invalid-target", before)


func _delayed_callback(encounter, token: Dictionary) -> void:
	callback_results.append(encounter.resolve_npc(token))
	callback_results.append(encounter.complete_npc(token))


func _restart_and_duplicates() -> void:
	var before: int = failures
	for settings in [{}, {"player_hp": 6}, {"npc_hp": 3, "incoming_target_id": "npc"}]:
		for after_effect in [false, true]:
			var encounter = Encounter.new()
			encounter.restart(settings)
			var old: Dictionary = encounter.begin_npc_slot()
			if after_effect:
				encounter.resolve_npc(old)
			callback_results.clear()
			create_timer(0.01).timeout.connect(_delayed_callback.bind(encounter, old))
			encounter.restart()
			var current: Dictionary = encounter.begin_npc_slot()
			var fresh: Dictionary = encounter.inspect()
			await create_timer(0.03).timeout
			_check(callback_results.size() == 2, "real delayed callbacks fired")
			for result in callback_results:
				_check(result.reason_code == "STALE_BATTLE_GENERATION", "old callback rejected")
			_check(encounter.inspect() == fresh, "old callbacks cannot affect new queue or state")
			encounter.resolve_npc(current)
			encounter.complete_npc(current)
			_check(encounter.inspect().round == 2, "new encounter still works")
	_case_done("S10", before)
	before = failures
	for settings in [{}, {"player_hp": 6}, {"npc_hp": 3, "incoming_target_id": "npc"}]:
		var encounter = Encounter.new()
		encounter.restart(settings)
		var token: Dictionary = encounter.begin_npc_slot()
		encounter.resolve_npc(token)
		var once: Dictionary = encounter.inspect()
		_check(encounter.resolve_npc(token).reason_code == "ACTION_ALREADY_RESOLVED", "effect once")
		_check(encounter.inspect() == once, "no duplicate HP/HELP/defend changes")
		encounter.complete_npc(token)
		once = encounter.inspect()
		_check(encounter.complete_npc(token).reason_code == "ACTION_ALREADY_COMPLETED", "completion once")
		_check(encounter.inspect() == once, "no duplicate counter or round increment")
		var next: Dictionary = encounter.begin_npc_slot()
		var next_before: Dictionary = encounter.inspect()
		_check(encounter.resolve_npc(token).reason_code == "INVALID_ACTION_ID", "prior round token rejected")
		_check(encounter.resolve_npc({}).reason_code == "INVALID_TOKEN", "malformed token rejected")
		_check(encounter.inspect() == next_before, "invalid tokens cannot consume slot")
		encounter.resolve_npc(next)
		encounter.complete_npc(next)
	_case_done("S11", before)


func _run() -> void:
	_basic_scenarios()
	_dead_targets()
	_boundaries_and_determinism()
	_limits_and_invalid_input()
	_locking_and_invalidated_help()
	await _restart_and_duplicates()
	print("SCENARIOS_JSON: " + JSON.stringify(cases))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
