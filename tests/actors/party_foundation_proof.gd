extends SceneTree

const Encounter = preload("res://scripts/combat/full_party_encounter.gd")
const Registry = preload("res://scripts/actors/actor_registry.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const RuntimeState = preload("res://scripts/actors/actor_runtime_state.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)


func _case(id: String, before: int) -> void:
	print("CASE %s: %s" % [id, "PASS" if failures == before else "FAIL"])


func _definition(id: String = "npc_02", role: String = "NPC"):
	return Definition.create({"actor_id": id, "display_name": id, "role": role, "base_max_hp": 10})


func _values_only(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if not _values_only(key) or not _values_only(value[key]):
				return false
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			if not _values_only(entry):
				return false
	elif typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL]:
		return false
	return true


func _fixtures() -> void:
	var before: int = failures
	for count in range(4):
		for enemies in [1, 2]:
			var encounter = Encounter.new()
			_check(encounter.restart(Encounter.prototype_fixture(count, enemies)), "fixture accepted")
			var view: Dictionary = encounter.snapshot()
			_check(view.player_id == "player" and view.actors.player.role == "PLAYER", "F01 one Player")
			_check(view.party_order.size() == count and view.enemy_order.size() == enemies, "F02/F03 capacities")
			_check(view.actors.size() == 1 + count + enemies, "F04 unique IDs")
			_check(_values_only(view), "F13 no objects in snapshot")
			for id in view.actors:
				var actor: Dictionary = view.actors[id]
				_check(actor.actor_id == id and actor.membership == ("ENEMY" if actor.role == "ENEMY" else "PARTY"), "F05 membership")
				_check(actor.current_hp <= actor.max_hp and actor.current_hp >= 0, "HP bounds")
	_check(Encounter.prototype_fixture(-1, 1).is_empty(), "invalid fixture count")
	_check(Encounter.prototype_fixture(4, 1).is_empty(), "too many NPCs")
	_check(Encounter.prototype_fixture(0, 0).is_empty(), "zero enemies")
	_check(Encounter.prototype_fixture(0, 3).is_empty(), "too many enemies")
	_case("F01-F05-fixtures", before)


func _registry_validation() -> void:
	var before: int = failures
	var registry = Registry.new()
	var definition = _definition()
	var supplied = RuntimeState.create(definition, 7)
	_check(registry.register_actor(definition, supplied, "PARTY"), "register actor")
	var first = registry._actors.npc_02 # White-box probes only; public API never returns this.
	var original: Dictionary = registry.snapshot()
	_check(not registry.register_actor(definition, RuntimeState.create(definition), "PARTY"), "F07 duplicate definition ID")
	_check(registry._actors.npc_02 == first and registry.snapshot() == original, "no overwrite")
	supplied.take_damage(7)
	_check(registry.snapshot() == original, "input runtime alias detached")
	for role in ["PLAYER", "NPC", "ENEMY"]:
		var other = _definition("other", role)
		var state = RuntimeState.create(other)
		var wrong: String = "PARTY" if role == "ENEMY" else "ENEMY"
		_check(not registry.register_actor(other, state, wrong), "F06 role/membership mismatch")
	for bad in [null, {}, 1, "npc", Definition.new(), RuntimeState.new()]:
		_check(not registry.register_actor(bad, supplied, "PARTY"), "F08 invalid definition type/factory")
		_check(not registry.register_actor(_definition("other"), bad, "PARTY"), "F08 invalid runtime")
	for membership in [null, "NPC", "", 1, [], {}]:
		_check(not registry.register_actor(_definition("other"), supplied, membership), "invalid membership")
	_check(not registry.register_actor(_definition("other"), RuntimeState.create(definition), "PARTY"), "ID mismatch")
	var corrupt = RuntimeState.create(_definition("other"))
	for values in [[-1, 10], [11, 10], [1, 9], [0, 0]]:
		corrupt._current_hp = values[0]
		corrupt._max_hp = values[1]
		_check(not registry.register_actor(_definition("other"), corrupt, "PARTY"), "reject corrupted runtime bounds/max")
	_check(registry.snapshot() == original and registry._actors.npc_02 == first, "all invalid operations atomic")
	for id in [null, [], 1, "", "unknown"]:
		_check(registry.actor_snapshot(id).is_empty(), "invalid/unknown snapshot ID")
		_check(not registry.unregister_actor(id), "invalid/unknown removal")
		_check(registry.fixture_damage(id, 1).status == "INVALID_INPUT", "unknown damage ID")
	_check(registry.unregister_actor("npc_02"), "unregister")
	_check(not registry.register_actor(definition, RuntimeState.create(definition), "PARTY"), "F17 tombstone")
	_case("F06-F08-registry-validation", before)


func _hp_and_reorder() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	var original: Dictionary = encounter.snapshot()
	var generation: int = original.generation
	var objects: Dictionary = encounter._registry._actors.duplicate()
	_check(encounter.fixture_damage("npc_02", 3, generation).hp_delta == -3, "F09 NPC2 7 to 4")
	for id in original.actors:
		_check(encounter.actor_snapshot(id).current_hp == (4 if id == "npc_02" else original.actors[id].current_hp), "F09 HP independence " + id)
	var actors_before_reorder: Dictionary = encounter.snapshot().actors
	var new_order: Array = ["npc_03", "npc_01", "npc_02"]
	_check(encounter.reorder_party(new_order), "F14 reorder accepted")
	_check(encounter._registry._actors == objects and encounter.actor_snapshot("npc_02").current_hp == 4, "F14 same objects and HP")
	new_order.clear()
	_check(encounter.snapshot().actors == actors_before_reorder, "F14 all actor values preserved")
	_check(encounter.snapshot().party_order == ["npc_03", "npc_01", "npc_02"], "reorder input detached")
	var view: Dictionary = encounter.snapshot()
	view.actors.npc_02.current_hp = 999
	view.actors.player.role = "ENEMY"
	view.party_order.clear()
	view.enemy_order.append("npc_02")
	view.available_enemy_ids.clear()
	var actor_view: Dictionary = encounter.actor_snapshot("npc_02")
	actor_view.max_hp = 99
	_check(encounter.actor_snapshot("npc_02").current_hp == 4 and encounter.snapshot().party_order.size() == 3, "F13 detached nested snapshots")
	for id in objects:
		_check(objects[id] is RuntimeState, "F10 actual runtime owner")
		objects[id].take_damage(1)
		_check(encounter.actor_snapshot(id).current_hp == objects[id].snapshot().current_hp, "F10 reads live runtime")
	for id in original.actors:
		_check(encounter.fixture_damage(id, 9223372036854775807, generation).status == "APPLIED", "F11 clamp damage")
		_check(encounter.actor_snapshot(id).current_hp == 0 and not encounter.actor_snapshot(id).can_act, "F12 zero unavailable")
		_check(encounter.snapshot().actors.has(id), "F12 retained in roster")
	_check(encounter.available_enemy_ids().is_empty(), "F21 enemy availability from runtime")
	for id in original.actors:
		_check(encounter.fixture_heal(id, 9223372036854775807, generation).status == "APPLIED", "heal boundary")
		_check(encounter.actor_snapshot(id).current_hp == original.actors[id].max_hp, "F11 heal cap")
	_check(encounter.available_enemy_ids() == ["enemy_a", "enemy_b"], "F21 no alive cache")
	var stable: Dictionary = encounter.snapshot()
	for amount in [-1, null, "3", 3.0, true, [], {}]:
		_check(encounter.fixture_damage("npc_02", amount, generation).status == "INVALID_INPUT", "invalid damage")
		_check(encounter.fixture_heal("npc_02", amount, generation).status == "INVALID_INPUT", "invalid heal")
		_check(encounter.snapshot() == stable, "invalid HP mutation atomic")
	_case("F09-F14-F21-HP-snapshots-reorder", before)


func _roster_and_locks() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	for order in [null, {}, "npc_01", [], ["npc_01", "npc_01", "npc_03"], ["npc_01", "npc_02", "unknown"], ["player", "npc_02", "npc_03"], ["enemy_a", "npc_02", "npc_03"], [1, 2, 3]]:
		var original: Dictionary = encounter.snapshot()
		_check(not encounter.reorder_party(order) and encounter.snapshot() == original, "F15 invalid reorder atomic")
	encounter.restart(Encounter.prototype_fixture(1, 1))
	var definition = _definition()
	var runtime = RuntimeState.create(definition, 7)
	for lock in [[false, false], [true, true], [false, true]]:
		encounter.set_lifecycle(lock[0], lock[1])
		var original: Dictionary = encounter.snapshot()
		_check(not encounter.register_actor(definition, runtime, "PARTY"), "F16 locked register")
		_check(not encounter.unregister_actor("npc_01"), "F16 locked unregister")
		_check(not encounter.reorder_party(["npc_01"]), "locked reorder")
		_check(encounter.fixture_damage("npc_01", 1, original.generation).status == "REJECTED", "locked fixture")
		_check(encounter.snapshot() == original, "locked operations inert")
	encounter.set_lifecycle(true, false)
	_check(not encounter.set_lifecycle(1, false), "invalid lifecycle types")
	var ready: Dictionary = encounter.snapshot()
	for bad in [null, {}, 1, Definition.new()]:
		_check(not encounter.register_actor(bad, runtime, "PARTY"), "encounter invalid definition")
	for membership in ["ENEMY", "NPC", null, 1, []]:
		_check(not encounter.register_actor(definition, runtime, membership), "encounter invalid membership")
	_check(not encounter.register_actor(definition, RuntimeState.create(_definition("other")), "PARTY"), "encounter mismatched runtime")
	_check(not encounter.register_actor(definition, RuntimeState.new(), "PARTY"), "encounter bare runtime")
	_check(encounter.snapshot() == ready, "invalid registration preserves roster and registry")
	_check(encounter.register_actor(definition, runtime, "PARTY"), "register NPC ready")
	_check(encounter.actor_snapshot("npc_02").current_hp == 7, "new actor HP")
	ready = encounter.snapshot()
	_check(not encounter.register_actor(definition, RuntimeState.create(definition), "PARTY"), "duplicate register before capacity")
	_check(encounter.snapshot() == ready, "duplicate cannot overwrite HP or membership")
	_check(encounter.unregister_actor("npc_02"), "remove NPC ready")
	var original: Dictionary = encounter.snapshot()
	_check(not encounter.register_actor(definition, RuntimeState.create(definition), "PARTY"), "F17 remove/re-add rejected")
	_check(encounter.snapshot() == original, "tombstone rejection atomic")
	_check(not encounter.unregister_actor("player") and not encounter.unregister_actor("enemy_a"), "preserve one player and enemy")
	for id in [null, {}, 1, "unknown"]:
		_check(not encounter.unregister_actor(id), "invalid removal")
	_check(not encounter.register_actor(_definition("another_player", "PLAYER"), RuntimeState.create(_definition("another_player", "PLAYER")), "PARTY"), "second Player rejected")
	var enemy = _definition("enemy_b", "ENEMY")
	_check(encounter.register_actor(enemy, RuntimeState.create(enemy), "ENEMY"), "register second enemy")
	_check(encounter.unregister_actor("enemy_b"), "remove second enemy")
	_check(encounter.restart(Encounter.prototype_fixture(1, 1)), "new session")
	_check(encounter.register_actor(definition, RuntimeState.create(definition), "PARTY"), "tombstones cleared only by restart")
	encounter.restart(Encounter.prototype_fixture())
	for spec in [["npc_04", "NPC", "PARTY"], ["enemy_c", "ENEMY", "ENEMY"]]:
		var extra = _definition(spec[0], spec[1])
		_check(not encounter.register_actor(extra, RuntimeState.create(extra), spec[2]), "capacity rejection")
	_case("F15-F17-roster-and-locks", before)


func _atomic_restart() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	encounter.fixture_damage("npc_02", 3, encounter.snapshot().generation)
	encounter.unregister_actor("npc_03")
	encounter.set_lifecycle(false, true)
	var original: Dictionary = encounter.snapshot()
	var old_registry = encounter._registry
	var objects: Dictionary = old_registry._actors.duplicate()
	var invalids: Array = [null, [], {}, 1, "fixture"]
	for key in ["actors", "player_id", "party_order", "enemy_order"]:
		for bad in [null, 1, {}, "", []]:
			var fixture: Dictionary = Encounter.prototype_fixture()
			fixture[key] = bad
			invalids.append(fixture)
	for kind in range(15):
		var fixture: Dictionary = Encounter.prototype_fixture()
		match kind:
			0: fixture.actors.append(fixture.actors[0].duplicate(true))
			1: fixture.party_order = ["npc_01", "npc_01", "npc_03"]
			2: fixture.enemy_order = ["enemy_a", "enemy_a"]
			3: fixture.enemy_order = ["npc_01"]
			4: fixture.player_id = "npc_01"
			5: fixture.actors[-1].initial_hp = -1 # Fail after earlier candidates built.
			6: fixture.actors[-1].initial_hp = 99
			7: fixture.actors[-1].initial_hp = null
			8: fixture.actors[-1].definition.role = "PLAYER"
			9: fixture.actors[-1].definition.actor_id = "BAD ID"
			10: fixture.actors[-1].extra = true
			11: fixture.actors.append(null)
			12: fixture.extra = true
			13: fixture.actors[-1].definition.base_max_hp = 1.0
			14: fixture.enemy_order = ["unknown"]
		invalids.append(fixture)
	for fixture in invalids:
		_check(not encounter.restart(fixture), "F19 invalid restart rejected")
		_check(encounter.snapshot() == original and encounter._registry == old_registry \
			and encounter._registry._actors == objects, "F19 preserves HP/roster/generation/locks/objects")
	_check(old_registry._retired.has("npc_03"), "invalid restart preserves tombstones")
	var fresh_fixture: Dictionary = Encounter.prototype_fixture(2, 1)
	_check(encounter.restart(fresh_fixture), "F18 valid restart while locked")
	var fresh: Dictionary = encounter.snapshot()
	_check(fresh.generation == original.generation + 1 and fresh.command_ready and not fresh.active_action, "F18 generation and lifecycle reset")
	_check(fresh.party_order == ["npc_01", "npc_02"] and fresh.enemy_order == ["enemy_a"] \
		and fresh.actors.npc_02.current_hp == 7, "F18 new roster and initial HP")
	fresh_fixture.party_order.clear()
	fresh_fixture.actors[0].initial_hp = 0
	_check(encounter.snapshot() == fresh, "restart input detached")
	for id in objects:
		objects[id].take_damage(999)
		if fresh.actors.has(id):
			_check(encounter._registry._actors[id] != objects[id], "F20 fresh object identity")
	old_registry.fixture_heal("npc_02", 999)
	_check(encounter.snapshot() == fresh, "F20 old runtime/registry cannot mutate new encounter")
	_check(encounter.fixture_damage("npc_02", 1, original.generation).status == "REJECTED", "stale generation rejected")
	_check(encounter.fixture_heal("npc_02", 1, true).status == "REJECTED", "wrong generation type")
	_check(encounter.snapshot() == fresh, "stale mutation inert")
	_case("F18-F20-atomic-restart", before)


func _run() -> void:
	_fixtures()
	_registry_validation()
	_hp_and_reorder()
	_roster_and_locks()
	_atomic_restart()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
