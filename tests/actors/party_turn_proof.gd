extends SceneTree

const Encounter = preload("res://scripts/combat/full_party_encounter.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const Legacy = preload("res://scripts/npc/npc_proof_encounter.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const Runtime = preload("res://scripts/actors/actor_runtime_state.gd")
var checks: int = 0
var failures: int = 0
var cases: Dictionary = {}
var trace: Array = []
var callback_results: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)


func _fixture(npcs: int = 3, enemies: int = 2, hp: Dictionary = {}) -> Dictionary:
	var fixture: Dictionary = Encounter.prototype_fixture(npcs, enemies)
	for entry in fixture.actors:
		if hp.has(entry.definition.actor_id):
			entry.initial_hp = hp[entry.definition.actor_id]
	return fixture


func _new(fixture: Dictionary):
	var encounter = Encounter.new()
	_check(encounter.restart(fixture), "valid scenario fixture")
	trace.clear()
	return encounter


func _step(encounter, actor: String, action: String, target: String, reason: String) -> Dictionary:
	var token: Dictionary = encounter.begin_next_action()
	_check(token.has("decision"), "slot locks one decision")
	if not token.has("decision"):
		return {}
	_check(token.actor_id == actor and token.decision.actor_id == actor, "stable actor identity")
	_check(token.decision.action == action, "%s expected %s actual %s" % [actor, action, token.decision.action])
	_check(token.decision.target_id == target, "target " + target)
	_check(token.decision.reason_code == reason, "reason " + reason)
	var effect: Dictionary = encounter.resolve_action(token)
	_check(effect.status in ["APPLIED", "SKIP"], "effect resolves")
	_check(encounter.complete_action(token).status == "COMPLETED", "completion accepted")
	trace.append({"decision": token.decision, "effect": effect, "after": encounter.snapshot()})
	return effect


func _drain(encounter) -> void:
	var slots: int = 0
	while encounter.snapshot().round_running and slots < 8:
		var token: Dictionary = encounter.begin_next_action()
		_check(token.has("decision"), "remaining slot available")
		if not token.has("decision"):
			break
		var effect: Dictionary = encounter.resolve_action(token)
		_check(effect.status in ["APPLIED", "SKIP"], "remaining effect")
		_check(encounter.complete_action(token).status == "COMPLETED", "remaining completion")
		trace.append({"decision": token.decision, "effect": effect, "after": encounter.snapshot()})
		slots += 1
	_check(not encounter.snapshot().round_running, "queue exhausts or terminal stops")


func _round_done(encounter, player_hp: int) -> void:
	var state: Dictionary = encounter.snapshot()
	_check(state.round_id == 2 and state.round_completions == 1, "exactly one round completion")
	_check(state.pending.is_empty() and not state.active_action and state.command_ready, "queue drained and command unlocked")
	_check(state.actors.player.current_hp == player_hp, "Player HP expected %d actual %d" % [player_hp, state.actors.player.current_hp])
	_check(state.guards.is_empty(), "all guards expire at round end")
	var before: Dictionary = encounter.snapshot()
	_check(encounter.begin_next_action().status == "REJECTED", "exhausted queue cannot dispatch")
	_check(encounter.snapshot() == before, "exhaustion cannot complete twice")


func _record(id: String, before: int, fixture: Dictionary, expected: String, encounter) -> void:
	cases[id] = {"status": "PASS" if failures == before else "FAIL", "input": fixture,
		"expected_decision_target_reason_effect_queue": expected, "actual": encounter.snapshot(),
		"actions": trace.duplicate(true)}
	print("CASE %s: %s" % [id, cases[id].status])


func _rosters() -> void:
	for spec in [["P1", 1, 1], ["P2", 3, 2], ["P3", 3, 1], ["P0", 0, 2]]:
		var before: int = failures
		var fixture: Dictionary = _fixture(spec[1], spec[2])
		var encounter = _new(fixture)
		_check(encounter.begin_round("ATTACK", "enemy_a").status == "STARTED", "start player attack")
		_step(encounter, "player", "ATTACK", "enemy_a", "PLAYER_COMMAND")
		for id in encounter.snapshot().party_order:
			_step(encounter, id, "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
		for id in encounter.snapshot().enemy_order:
			_step(encounter, id, "ATTACK", "player", "ENEMY_DECLARED_TARGET")
		_round_done(encounter, 30 - spec[2] * 3)
		_check(encounter.actor_snapshot("enemy_a").current_hp == 10 - spec[1], "Player 5 + NPC 1 each")
		_record(spec[0], before, fixture, "Player ATTACK A (-5), NPCs ATTACK A (-1 each), enemies ATTACK Player (-3 each), round 2 once", encounter)


func _help_and_reasons() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2, {"player": 6})
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "HELP", "player", "PLAYER_LOW_HP_HELP")
	_check(encounter.actor_snapshot("player").current_hp == 10, "P4 HELP uses fresh Player HP")
	for id in ["npc_02", "npc_03"]:
		_step(encounter, id, "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_check(encounter.snapshot().help_uses == {"npc_01": 0, "npc_02": 1, "npc_03": 1}, "P4 independent HELP ledger")
	_drain(encounter)
	_round_done(encounter, 8)
	_record("P4", before, fixture, "Player 6 DEFEND; NPC1 HELP 6→10; NPC2/3 ATTACK A fresh HP10; both hits -1; Player8, A13, round2", encounter)
	before = failures
	fixture = _fixture(3, 2, {"player": 6, "npc_01": 3})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01", "enemy_b": "player"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "DEFEND", "npc_01", "SELF_LOW_HP_THREAT")
	_step(encounter, "npc_02", "HELP", "player", "PLAYER_LOW_HP_HELP")
	_step(encounter, "npc_03", "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_drain(encounter)
	_check(encounter.actor_snapshot("npc_01").current_hp == 2, "P6 self-first guard")
	_round_done(encounter, 9)
	_record("P6", before, fixture, "A→NPC1 B→Player: NPC1 DEFEND self-low; NPC2 HELP; NPC3 ATTACK; NPC1 HP2, Player9, round2", encounter)


func _guards() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2, {"npc_01": 3})
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01", "enemy_b": "npc_01"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "DEFEND", "npc_01", "SELF_LOW_HP_THREAT")
	_step(encounter, "npc_02", "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_step(encounter, "npc_03", "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_check(_step(encounter, "enemy_a", "ATTACK", "npc_01", "ENEMY_DECLARED_TARGET").hp_delta == -1, "first hit reduced")
	_check(_step(encounter, "enemy_b", "ATTACK", "npc_01", "ENEMY_DECLARED_TARGET").hp_delta == -2, "second hit full damage clamped to remaining HP")
	_check(encounter.actor_snapshot("npc_01").current_hp == 0, "NPC death not Party defeat")
	_round_done(encounter, 30)
	_record("P5", before, fixture, "NPC1 DEFEND; NPC2/3 ATTACK; A hit1 then B hit3 clamp2 kills NPC1; no defeat, guard expires, round2", encounter)
	# D12 distinguishes NEXT hit from sum. First hit3 is nonlethal at HP4; sum6 would be lethal.
	before = failures
	fixture = _fixture(1, 2, {"npc_01": 4})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01", "enemy_b": "npc_01"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_drain(encounter)
	_round_done(encounter, 30)
	_record("E-next-hit", before, fixture, "Two declared hits3 at NPC HP4: ATTACK (next3 nonlethal; do not sum6); NPC0, round2", encounter)
	# Lethal at exactly HP3 above the 30% boundary with max HP5.
	fixture = _fixture(1, 1, {"npc_01": 3})
	fixture.actors[1].definition.base_max_hp = 5
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "DEFEND", "npc_01", "SELF_LETHAL_THREAT")
	_drain(encounter)
	_round_done(encounter, 30)
	_check(encounter.actor_snapshot("npc_01").current_hp == 2, "lethal-threat guard reduces3 to1")


func _dead_slots() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2, {"enemy_a": 5, "npc_02": 0})
	var encounter = _new(fixture)
	encounter.begin_round("ATTACK", "enemy_a")
	_step(encounter, "player", "ATTACK", "enemy_a", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY")
	_step(encounter, "npc_02", "SKIP", "", "ACTOR_UNAVAILABLE")
	_step(encounter, "npc_03", "ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY")
	_step(encounter, "enemy_a", "SKIP", "", "ACTOR_UNAVAILABLE")
	_step(encounter, "enemy_b", "ATTACK", "player", "ENEMY_DECLARED_TARGET")
	_round_done(encounter, 27)
	_check(encounter.actor_snapshot("enemy_b").current_hp == 10, "surviving B independent HP")
	_record("P7-P8", before, fixture, "Player kills A; NPC1/3 attack B; dead NPC2/A SKIP; B hits Player3; B10, Player27, round2", encounter)
	before = failures
	fixture = _fixture(1, 2, {"enemy_a": 0, "enemy_b": 0})
	encounter = _new(fixture)
	_check(encounter.snapshot().result == "VICTORY" and not encounter.snapshot().command_ready, "Restart immediately detects all enemies unavailable")
	_check(encounter.begin_round("ATTACK").status == "TERMINAL", "no available enemy")
	_check(encounter.snapshot().result == "VICTORY" and encounter.snapshot().round_completions == 0, "no phantom round")
	_record("E-no-enemy", before, fixture, "VICTORY before any action, no queue or round completion", encounter)
	# Known dead selected target falls back before Player lock; arbitrary unknown target is invalid.
	fixture = _fixture(0, 2, {"enemy_a": 0})
	encounter = _new(fixture)
	encounter.begin_round("ATTACK", "enemy_a")
	_step(encounter, "player", "ATTACK", "enemy_b", "PLAYER_COMMAND")
	_drain(encounter)
	_round_done(encounter, 27)


func _resources() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 1, {"player": 1})
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	for id in ["npc_01", "npc_02", "npc_03"]:
		_step(encounter, id, "HELP", "player", "PLAYER_LOW_HP_HELP")
	_check(encounter.actor_snapshot("player").current_hp == 13, "multiple HELP reads 1→5→9→13")
	_check(encounter.snapshot().help_uses == {"npc_01": 0, "npc_02": 0, "npc_03": 0}, "all three resources used independently")
	_drain(encounter)
	_round_done(encounter, 12)
	_check(encounter.reorder_party(["npc_03", "npc_01", "npc_02"]), "reorder ready")
	_check(encounter.snapshot().help_uses == {"npc_01": 0, "npc_02": 0, "npc_03": 0}, "reorder never resets resources")
	encounter.fixture_damage("player", 6, encounter.snapshot().generation)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	for id in ["npc_03", "npc_01", "npc_02"]:
		_step(encounter, id, "ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK")
	_drain(encounter)
	_check(encounter.snapshot().round_completions == 2, "second round works in new party order")
	_record("P9", before, fixture, "HELP1→5→9→13, ledger all0; reorder retains ledger; next round HP6 all ATTACK HELP_UNAVAILABLE; completions2", encounter)
	fixture = _fixture(1, 1, {"player": 1})
	fixture.actors[0].definition.base_max_hp = 4
	encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_check(_step(encounter, "npc_01", "HELP", "player", "PLAYER_LOW_HP_HELP").hp_delta == 3, "HELP clamps to Max HP4")
	_drain(encounter)
	_check(encounter.actor_snapshot("player").current_hp == 3, "clamp then defended hit")


func _lock_and_target() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(2, 2)
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	var token: Dictionary = encounter.begin_next_action()
	_check(token.decision.target_id == "enemy_a", "NPC1 locks A")
	# White-box fixture interruption: public fixture_damage stays blocked while busy.
	encounter._registry.fixture_damage("enemy_a", 999)
	_check(encounter.resolve_action(token).status == "SKIP", "locked dead target skips without retarget")
	_check(encounter.complete_action(token).status == "COMPLETED", "skipped slot completes")
	_check(encounter.actor_snapshot("enemy_b").current_hp == 12, "no mid-action retarget B")
	_step(encounter, "npc_02", "ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY")
	_drain(encounter)
	_round_done(encounter, 29)
	_record("P10", before, fixture, "NPC1 locks A then A becomes0: SKIP; NPC2 chooses fresh B (-1); A skips, B hits defended Player1; round2", encounter)
	before = failures
	fixture = _fixture(1, 2, {"player": 6})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	token = encounter.begin_next_action()
	_check(token.decision.action == "HELP", "locks HELP")
	token.decision.action = "ATTACK"
	token.decision.target_id = "enemy_b"
	token.decision.reason_code = "FORGED"
	token.state = "COMPLETED"
	_check(encounter.resolve_action(token).hp_delta == 4, "effect uses internal HELP not caller mutation")
	_check(encounter.actor_snapshot("enemy_b").current_hp == 12 and encounter.snapshot().help_uses.npc_01 == 0, "locked HELP owner")
	encounter.complete_action(token)
	_drain(encounter)
	_record("E-locked-record", before, fixture, "Caller changes action/target/reason/state but locked HELP still heals4 and consumes NPC1 only", encounter)
	# Enemy never retargets a declared unavailable target.
	fixture = _fixture(1, 2, {"npc_01": 0})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01", "enemy_b": "npc_01"})
	_drain(encounter)
	_round_done(encounter, 30)
	_check(trace[-1].effect.status == "SKIP" and trace[-2].effect.status == "SKIP", "both enemies skip unavailable target")


func _terminal() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2)
	var encounter = _new(fixture)
	for order in [["enemy_a", "enemy_b"], ["enemy_b", "enemy_a"]]:
		fixture = _fixture(3, 2, {order[0]: 5, order[1]: 6})
		encounter = _new(fixture)
		encounter.begin_round("ATTACK", order[0])
		_drain(encounter)
		_check(encounter.actor_snapshot(order[0]).current_hp == 0, "first kill order")
		_check(encounter.actor_snapshot(order[1]).current_hp == 3, "survivor gets NPC hits")
		encounter.begin_round("ATTACK", order[1])
		_step(encounter, "player", "ATTACK", order[1], "PLAYER_COMMAND")
		var stable: Dictionary = encounter.snapshot()
		_check(stable.result == "VICTORY" and stable.round_completions == 1 and stable.round_id == 2, "victory no extra round")
		_check(stable.pending.is_empty() and not stable.command_ready, "victory cancels counters")
		_check(encounter.begin_next_action().status == "REJECTED" and encounter.snapshot() == stable, "terminal no new actions")
	fixture = _fixture(0, 2, {"player": 3})
	encounter = _new(fixture)
	encounter.begin_round("ATTACK")
	_step(encounter, "player", "ATTACK", "enemy_a", "PLAYER_COMMAND")
	_step(encounter, "enemy_a", "ATTACK", "player", "ENEMY_DECLARED_TARGET")
	_check(encounter.snapshot().result == "DEFEAT" and encounter.snapshot().round_completions == 0, "defeat cancels enemy B without completion")
	_check(encounter.snapshot().pending.is_empty() and encounter.actor_snapshot("player").current_hp == 0, "defeat drained")
	_record("P14", before, fixture, "Both kill orders preserve survivor; final killing Player action cancels queue; enemy A lethal cancels B, no phantom completion", encounter)
	for change in ["defeated", "full", "actor_dead"]:
		fixture = _fixture(1, 1, {"player": 6})
		encounter = _new(fixture)
		encounter.begin_round("DEFEND")
		_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
		var token: Dictionary = encounter.begin_next_action()
		if change == "defeated":
			encounter._registry.fixture_damage("player", 999)
		elif change == "full":
			encounter._registry.fixture_heal("player", 999)
		else:
			encounter._registry.fixture_damage("npc_01", 999)
		var stable: Dictionary = encounter._registry.snapshot()
		_check(encounter.resolve_action(token).status == "SKIP", "invalidated HELP skips " + change)
		_check(encounter._registry.snapshot() == stable and encounter.snapshot().help_uses.npc_01 == 1, "invalidated HELP no resource/damage/revival")
		encounter.complete_action(token)
		if change == "defeated":
			_check(encounter.snapshot().result == "DEFEAT", "HELP never revives Player")
	fixture = _fixture(1, 1, {"player": 0})
	encounter = _new(fixture)
	_check(encounter.snapshot().result == "DEFEAT" and not encounter.snapshot().command_ready, "Restart immediately detects defeated Player")
	_check(encounter.begin_round("DEFEND").status == "TERMINAL", "already defeated Player cannot start HELP")


func _invalids() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture()
	var encounter = _new(fixture)
	for args in [["HELP", "", {}], [null, "", {}], [1, "", {}], ["ATTACK", "npc_01", {}],
		["ATTACK", "unknown", {}], ["DEFEND", "enemy_a", {}], ["ATTACK", null, {}],
		["ATTACK", "", {"unknown": "player"}], ["ATTACK", "", {"enemy_a": "enemy_b"}],
		["ATTACK", "", {"enemy_a": null}], ["ATTACK", "", []]]:
		var stable: Dictionary = encounter.snapshot()
		_check(encounter.begin_round(args[0], args[1], args[2]).status == "REJECTED", "invalid player action/target/declarations")
		_check(encounter.snapshot() == stable, "invalid command atomic")
	encounter.begin_round("ATTACK")
	var token: Dictionary = encounter.begin_next_action()
	var other = _new(fixture)
	other.begin_round("ATTACK")
	var foreign: Dictionary = other.begin_next_action()
	var stable: Dictionary = encounter.snapshot()
	_check(encounter.complete_action(token).status == "REJECTED", "completion before effect rejected")
	_check(not encounter.set_lifecycle(true, false), "legacy fixture guard cannot unlock live queue")
	_check(not encounter.unregister_actor("npc_01") and not encounter.reorder_party(["npc_03", "npc_02", "npc_01"]), "busy roster and order rejected")
	var definition = Definition.create({"actor_id": "extra", "display_name": "Extra", "role": "NPC", "base_max_hp": 10})
	_check(not encounter.register_actor(definition, Runtime.create(definition), "PARTY"), "busy registration rejected")
	_check(encounter.fixture_damage("enemy_a", 1, stable.generation).status == "REJECTED", "busy fixture damage blocked")
	_check(encounter.fixture_heal("player", 1, stable.generation).status == "REJECTED", "busy fixture heal blocked")
	_check(encounter.begin_round("DEFEND").status == "REJECTED" and encounter.begin_next_action().status == "REJECTED", "single active action")
	var invalid_tokens: Array = [null, {}, [], true, foreign]
	for key in ["actor_id", "action_id", "round_id", "generation", "encounter_id"]:
		for replacement in [null, true, -1, "unknown", 1.0, []]:
			var bad: Dictionary = token.duplicate(true)
			bad[key] = replacement
			invalid_tokens.append(bad)
		var missing: Dictionary = token.duplicate(true)
		missing.erase(key)
		invalid_tokens.append(missing)
	for bad in invalid_tokens:
		_check(encounter.resolve_action(bad).status == "REJECTED", "invalid token resolve rejected")
		_check(encounter.complete_action(bad).status == "REJECTED", "invalid token completion rejected")
		_check(encounter.snapshot() == stable, "invalid token no HP/resource/queue/revision change")
	_record("P15", before, fixture, "Invalid action/target/membership/types/token/foreign identity/busy mutations rejected atomically; early completion rejected", encounter)
	before = failures
	_check(encounter.resolve_action(token).hp_delta == -5, "valid effect after invalid attempts")
	stable = encounter.snapshot()
	_check(encounter.resolve_action(token).status == "REJECTED" and encounter.snapshot() == stable, "duplicate effect inert")
	_check(encounter.complete_action(token).status == "COMPLETED", "valid completion")
	stable = encounter.snapshot()
	_check(encounter.complete_action(token).status == "REJECTED" and encounter.snapshot() == stable, "duplicate completion inert")
	var next: Dictionary = encounter.begin_next_action()
	stable = encounter.snapshot()
	_check(encounter.resolve_action(token).status == "REJECTED" and encounter.complete_action(token).status == "REJECTED", "old action ID rejected during new slot")
	_check(encounter.snapshot() == stable, "old action cannot touch new slot")
	encounter.resolve_action(next)
	encounter.complete_action(next)
	_drain(encounter)
	_round_done(encounter, 24)
	_record("P13", before, fixture, "Duplicate resolve/completion and prior-slot tokens inert; valid queue still completes exactly once", encounter)


func _callback(encounter, token: Dictionary) -> void:
	callback_results.append(encounter.resolve_action(token))
	callback_results.append(encounter.complete_action(token))


func _restarts() -> void:
	for role in ["npc", "enemy"]:
		var before: int = failures
		var fixture: Dictionary = _fixture(1, 2, {"player": 6})
		var encounter
		for after_effect in [false, true]:
			encounter = _new(fixture)
			encounter.begin_round("DEFEND")
			_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
			if role == "enemy":
				_step(encounter, "npc_01", "HELP", "player", "PLAYER_LOW_HP_HELP")
			var old: Dictionary = encounter.begin_next_action()
			if after_effect:
				encounter.resolve_action(old)
			var stable: Dictionary = encounter.snapshot()
			var invalid: Dictionary = fixture.duplicate(true)
			invalid.actors[-1].initial_hp = -1
			_check(not encounter.restart(invalid) and encounter.snapshot() == stable, "invalid Restart atomic while busy")
			var old_registry = encounter._registry
			callback_results.clear()
			create_timer(0.01).timeout.connect(_callback.bind(encounter, old))
			_check(encounter.restart(fixture), "valid Restart while active")
			_check(encounter.snapshot().generation == old.generation + 1, "Restart increments generation")
			_check(encounter.snapshot().help_uses.npc_01 == 1 and encounter.snapshot().guards.is_empty(), "Restart resources/guards reset")
			encounter.begin_round("DEFEND")
			var fresh: Dictionary = encounter.begin_next_action()
			stable = encounter.snapshot()
			old_registry.fixture_damage("player", 999)
			await create_timer(0.03).timeout
			_check(callback_results.size() == 2, "real delayed callbacks fired")
			_check(callback_results[0].status == "REJECTED" and callback_results[1].status == "REJECTED", "stale callbacks rejected")
			_check(encounter.snapshot() == stable, "old runtime/callback cannot change new session")
			encounter.resolve_action(fresh)
			encounter.complete_action(fresh)
			_drain(encounter)
			_round_done(encounter, 8)
		_record("P11" if role == "npc" else "P12", before, fixture,
			"Restart before/after effect at " + role + ": old timer callbacks reject; new HP/resources/guards/token/queue intact; fresh round works", encounter)


func _resolver_validation() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2)
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	var resolver = Resolver.new()
	var context: Dictionary = encounter.decision_context()
	var stable: Dictionary = context.duplicate(true)
	var decision: Dictionary = resolver.decide_for_actor("npc_01", context)
	for i in range(20):
		_check(resolver.decide_for_actor("npc_01", context) == decision, "pure deterministic multi-actor policy")
	_check(context == stable, "resolver does not mutate context")
	decision.reason_details.declared_hits.clear()
	_check(context == stable, "reason details detached")
	for key in context:
		var missing: Dictionary = context.duplicate(true)
		missing.erase(key)
		_check(resolver.decide_for_actor("npc_01", missing).status == "INVALID_INPUT", "missing context field " + key)
		for value in [null, true, "invalid", 1.0, []]:
			var bad: Dictionary = context.duplicate(true)
			bad[key] = value
			_check(resolver.decide_for_actor("npc_01", bad).status == "INVALID_INPUT", "wrong context type/value " + key)
	for id in [null, 1, true, [], {}, "unknown", "player", "enemy_a"]:
		_check(resolver.decide_for_actor(id, context).status == "INVALID_INPUT", "NPC membership required")
	for kind in range(14):
		var bad: Dictionary = context.duplicate(true)
		match kind:
			0: bad.actors.npc_01.current_hp = -1
			1: bad.actors.npc_01.current_hp = 99
			2: bad.actors.npc_01.can_act = false
			3: bad.actors.npc_01.role = "ENEMY"
			4: bad.actors.npc_01.membership = "ENEMY"
			5: bad.party_order = ["npc_01", "npc_01"]
			6: bad.help_uses.npc_01 = 2
			7: bad.declared_hits[0].actor_id = "npc_01"
			8: bad.declared_hits[0].target_id = "enemy_a"
			9: bad.declared_hits[0].damage = 6
			10: bad.snapshot_revision = -1
			11: bad.extra = 1
			12: bad.actors.npc_01 = []
			13: bad.declared_hits[0] = null
		_check(resolver.decide_for_actor("npc_01", bad).status == "INVALID_INPUT", "malformed multi context rejected")
	# Legacy API remains strict and returns identical equivalent reasons/targets.
	var legacy: Dictionary = Legacy.new().situation_snapshot()
	_check(resolver.validate_snapshot(legacy) == "", "legacy schema still accepted")
	_check(resolver.decide(legacy).reason_code == "ATTACK_AVAILABLE_ENEMY", "legacy policy reason preserved")
	legacy.living_enemy_ids = ["enemy_a", "enemy_b"]
	_check(resolver.decide(legacy).status == "INVALID_INPUT", "legacy multi enemy input still rejected")
	_record("P16-policy", before, fixture, "Shared policy deterministic/pure, strict legacy schema unchanged; full regression checked separately by verify.py", encounter)


func _extra_lifecycle() -> void:
	var before: int = failures
	var fixture: Dictionary = _fixture(3, 2, {"player": 6, "npc_02": 3})
	var encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_02", "enemy_b": "npc_02"})
	# Exercise duplicates for Player DEFEND, NPC HELP, NPC DEFEND, NPC ATTACK and enemies.
	for id in ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"]:
		var token: Dictionary = encounter.begin_next_action()
		_check(token.actor_id == id, "all action kinds in declared order")
		var pristine: Dictionary = encounter.snapshot()
		var view: Dictionary = encounter.snapshot()
		view.pending.clear()
		view.help_uses.clear()
		view.declared_hits.clear()
		view.locked_action.decision.action = "FORGED"
		_check(encounter.snapshot() == pristine, "nested public snapshots detached while locked")
		_check(encounter.complete_action(token).status == "REJECTED", "all kinds reject early completion")
		encounter.resolve_action(token)
		var stable: Dictionary = encounter.snapshot()
		_check(encounter.resolve_action(token).status == "REJECTED", "all kinds reject duplicate effect")
		_check(encounter.snapshot() == stable, "duplicate cannot heal/spend/guard/hit twice")
		encounter.complete_action(token)
		stable = encounter.snapshot()
		_check(encounter.complete_action(token).status == "REJECTED" and encounter.snapshot() == stable, "all kinds reject duplicate completion")
		trace.append({"decision": token.decision, "after": stable})
	_round_done(encounter, 10)
	_check(encounter.snapshot().help_uses.npc_01 == 0 and encounter.snapshot().help_uses.npc_02 == 1, "HELP and guard retain independent ownership")
	_record("E-exactly-once-all-actions", before, fixture, "Every action type rejects early/duplicate callbacks; HELP heals4 once; NPC2 guard only first hit; round2 once", encounter)
	before = failures
	fixture = _fixture(2, 2, {"npc_02": 3})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_02", "enemy_b": "player"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	# Kill A and NPC1 just before NPC1 slot: actor remains in Registry, no stale decision.
	encounter._registry.fixture_damage("enemy_a", 999)
	encounter._registry.fixture_damage("npc_01", 999)
	_step(encounter, "npc_01", "SKIP", "", "ACTOR_UNAVAILABLE")
	_step(encounter, "npc_02", "ATTACK", "enemy_b", "ATTACK_AVAILABLE_ENEMY")
	_drain(encounter)
	_round_done(encounter, 29)
	_record("E-dead-threat-and-midround-NPC", before, fixture, "A killed before NPC slot: its declared threat ignored; NPC1 becomes0 and skips; low NPC2 ATTACK B since B targets Player", encounter)
	before = failures
	fixture = _fixture(2, 2, {"npc_01": 3, "enemy_a": 1})
	encounter = _new(fixture)
	encounter.begin_round("DEFEND", "", {"enemy_a": "npc_01", "enemy_b": "player"})
	_step(encounter, "player", "DEFEND", "player", "PLAYER_COMMAND")
	_step(encounter, "npc_01", "DEFEND", "npc_01", "SELF_LOW_HP_THREAT")
	_step(encounter, "npc_02", "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY")
	_check(encounter.snapshot().guards.has("npc_01"), "unused NPC guard still present before round end")
	_drain(encounter)
	_round_done(encounter, 29)
	_check(encounter.actor_snapshot("npc_01").current_hp == 3, "unused guard never protects someone else")
	_record("E-unused-guard-expiry", before, fixture, "NPC1 DEFEND; NPC2 kills A before hit, B hits Player1; unused NPC1 guard expires end-round", encounter)
	# IDs are identities, never numeric positions or hardcoded names in the resolver.
	before = failures
	fixture = _fixture(1, 1, {"player": 6})
	var names: Dictionary = {"player": "adventurer", "npc_01": "companion_z", "enemy_a": "foe_z"}
	for actor in fixture.actors:
		actor.definition.actor_id = names[actor.definition.actor_id]
	fixture.player_id = "adventurer"
	fixture.party_order = ["companion_z"]
	fixture.enemy_order = ["foe_z"]
	encounter = _new(fixture)
	encounter.begin_round("DEFEND")
	_step(encounter, "adventurer", "DEFEND", "adventurer", "PLAYER_COMMAND")
	_step(encounter, "companion_z", "HELP", "adventurer", "PLAYER_LOW_HP_HELP")
	_step(encounter, "foe_z", "ATTACK", "adventurer", "ENEMY_DECLARED_TARGET")
	_check(encounter.actor_snapshot("adventurer").current_hp == 9, "custom stable IDs work")
	_record("E-custom-ids", before, fixture, "Custom stable IDs: companion HELP adventurer4, foe hits defended adventurer1; HP9, round2", encounter)


func _run() -> void:
	_rosters()
	_help_and_reasons()
	_guards()
	_dead_slots()
	_resources()
	_lock_and_target()
	_terminal()
	_invalids()
	await _restarts()
	_resolver_validation()
	_extra_lifecycle()
	print("SCENARIOS_JSON: " + JSON.stringify(cases))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
