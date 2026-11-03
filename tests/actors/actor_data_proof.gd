extends SceneTree

const Definition = preload("res://scripts/actors/actor_definition.gd")
const State = preload("res://scripts/actors/actor_runtime_state.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _definition(id: String, role: String, maximum: int) -> ActorDefinition:
	return Definition.create({"actor_id": id, "display_name": id,
		"role": role, "base_max_hp": maximum})


func _ownership_and_hp() -> void:
	var definitions: Array = [_definition("player", "PLAYER", 30),
		_definition("npc", "NPC", 10), _definition("enemy_a", "ENEMY", 15)]
	var ids: Array[String] = []
	for definition in definitions:
		var state = State.create(definition)
		_check(state != null, "Player/NPC/Enemy can be created")
		var view: Dictionary = state.snapshot()
		_check(view.actor_id not in ids, "fixture has distinct actor IDs")
		ids.append(view.actor_id)
		_check(view.current_hp == view.max_hp and state.can_act(), "initial full HP and availability")
	var player = State.create(definitions[0])
	var npc = State.create(definitions[1])
	var twin = State.create(definitions[1])
	var baseline: Dictionary = definitions[1].snapshot()
	_check(npc.take_damage(3) == {"status": "APPLIED", "hp_delta": -3}, "damage returns actual delta")
	_check(npc.snapshot().current_hp == 7, "10 minus 3 is 7")
	_check(player.snapshot().current_hp == 30, "NPC damage leaves Player HP unchanged")
	_check(twin.snapshot().current_hp == 10, "two states sharing one definition have independent HP")
	_check(npc.heal(2).hp_delta == 2 and npc.snapshot().current_hp == 9, "healing increases HP")
	_check(npc.heal(100).hp_delta == 1 and npc.snapshot().current_hp == 10, "healing capped at max")
	_check(npc.take_damage(100).hp_delta == -10 and npc.snapshot().current_hp == 0, "damage capped at zero")
	_check(not npc.can_act() and not npc.snapshot().can_act, "zero HP cannot act in fixture")
	_check(npc.take_damage(1).hp_delta == 0, "damage at zero is safe")
	_check(definitions[1].snapshot() == baseline, "runtime HP never changes definition")
	_check(not baseline.has("current_hp"), "definition contains no current HP")
	var view: Dictionary = player.snapshot()
	view.current_hp = 0
	view.max_hp = 1
	view.actor_id = "intruder"
	view.can_act = false
	_check(player.snapshot() == {"actor_id": "player", "current_hp": 30,
		"max_hp": 30, "can_act": true}, "returned snapshot cannot mutate runtime")
	var input: Dictionary = baseline.duplicate(true)
	var copied = Definition.create(input)
	input.base_max_hp = 999
	var definition_view: Dictionary = copied.snapshot()
	definition_view.base_max_hp = 1
	_check(copied.snapshot() == baseline, "definition copies input and output")
	var restarted = State.create(definitions[1])
	_check(restarted.snapshot().current_hp == 10, "fresh state resets to full HP")
	_check(npc.snapshot().current_hp == 0 and twin.snapshot().current_hp == 10,
		"reset is replacement; other state references are unaffected")
	var preset = State.create(definitions[0], 6)
	preset.take_damage(5)
	_check(State.create(definitions[0], 6).snapshot().current_hp == 6, "fresh preset restores explicit initial HP")
	_check(npc.heal(9223372036854775807).hp_delta == 10, "large healing input does not overflow")
	_check(npc.take_damage(9223372036854775807).hp_delta == -10, "large damage input clamps safely")
	_check(player.take_damage(0).hp_delta == 0 and player.heal(0).hp_delta == 0, "zero amounts are no-ops")
	print("CASE ownership-hp-recreation: complete")


func _invalid_inputs() -> void:
	var valid: Dictionary = _definition("player", "PLAYER", 30).snapshot()
	for field in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		_check(Definition.create(missing) == null, "missing definition field rejected: " + field)
		for value in [null, true, [], {}, 1.5]:
			var malformed: Dictionary = valid.duplicate(true)
			malformed[field] = value
			_check(Definition.create(malformed) == null, "wrong definition type rejected: " + field)
	for changes in [{"actor_id": ""}, {"actor_id": "bad id"}, {"actor_id": "../player"},
		{"actor_id": "1player"}, {"actor_id": "Player"}, {"display_name": " \n"},
		{"role": "UNKNOWN"}, {"base_max_hp": 0}, {"base_max_hp": -1},
		{"current_hp": 10}]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.merge(changes, true)
		var before: Dictionary = malformed.duplicate(true)
		_check(Definition.create(malformed) == null, "malformed/extra definition data rejected")
		_check(malformed == before, "invalid creation leaves input unchanged")
	for value in [null, true, 1, "player", []]:
		_check(Definition.create(value) == null, "non-dictionary definition rejected")
		_check(State.create(value) == null, "non-definition runtime input rejected")
	_check(State.create(valid) == null, "raw dictionary is not validated definition")
	_check(State.create(Definition.new()) == null, "uninitialized definition rejected")
	var definition = Definition.create(valid)
	for hp in [-1, 31, 1.5, true, "6", [], {}]:
		_check(State.create(definition, hp) == null, "invalid initial HP rejected")
	_check(State.create(definition, 0) != null, "zero initial HP is valid unavailable state")
	var state = State.create(definition, 6)
	for amount in [-1, 1.5, true, "3", null, [], {}]:
		var before: Dictionary = state.snapshot()
		_check(state.take_damage(amount).status == "INVALID_INPUT", "invalid damage rejected")
		_check(state.heal(amount).status == "INVALID_INPUT", "invalid healing rejected")
		_check(state.snapshot() == before, "invalid operations are atomic")
	var bare = State.new()
	_check(not bare.can_act(), "bare state is unavailable")
	_check(bare.take_damage(1).status == "INVALID_INPUT" and bare.heal(1).status == "INVALID_INPUT",
		"bare state cannot process effects")
	print("CASE invalid-input: complete")


func _resolver_bridge() -> void:
	var player = State.create(_definition("player", "PLAYER", 30), 6)
	var npc = State.create(_definition("npc", "NPC", 10))
	var enemy = State.create(_definition("enemy_a", "ENEMY", 15), 10)
	var player_view: Dictionary = player.snapshot()
	var npc_view: Dictionary = npc.snapshot()
	var enemy_view: Dictionary = enemy.snapshot()
	# Only this fixture translates the schema. No changes to M2A contracts.
	var situation: Dictionary = {
		"player_hp": player_view.current_hp, "player_max_hp": player_view.max_hp,
		"npc_hp": npc_view.current_hp, "npc_max_hp": npc_view.max_hp,
		"living_enemy_ids": [enemy_view.actor_id] if enemy_view.can_act else [],
		"incoming_target_id": player_view.actor_id, "incoming_damage": 3,
		"help_enabled": true, "help_uses_remaining": 1, "guidance": "ATTACK"
	}
	var resolver = Resolver.new()
	_check(resolver.validate_snapshot(situation).is_empty(), "runtime-derived M2A snapshot valid")
	var before: Dictionary = situation.duplicate(true)
	var decision: Dictionary = resolver.decide(situation)
	_check(decision.status == "DECIDED" and decision.action == "HELP"
		and decision.target_id == "player" and decision.reason_code == "PLAYER_LOW_HP_HELP",
		"6/30 Player + 10/10 NPC yields HELP/player/PLAYER_LOW_HP_HELP")
	_check(situation == before, "resolver does not mutate situation")
	situation.player_hp = 0
	decision.reason_details.npc_hp = 0
	_check(player.snapshot().current_hp == 6 and npc.snapshot().current_hp == 10,
		"situation/reason edits cannot reach runtime HP")
	_check(player.heal(4).hp_delta == 4 and player.snapshot().current_hp == 10,
		"fixture can apply existing HELP amount through state API")
	_check(player.take_damage(3).hp_delta == -3 and player.snapshot().current_hp == 7,
		"fixture enemy hit gives same 6→10→7 result")
	_check(npc.snapshot().current_hp == 10 and enemy.snapshot().current_hp == 10,
		"bridge effects leave other actors unchanged")
	print("CASE M2A-bridge: HELP/player/PLAYER_LOW_HP_HELP; Player 6→10→7")


func _run() -> void:
	_ownership_and_hp()
	_invalid_inputs()
	_resolver_bridge()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
