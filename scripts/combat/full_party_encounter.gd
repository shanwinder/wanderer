extends RefCounted

# M2C-02 data foundation only: no turn order, decisions or action execution.
const Registry = preload("res://scripts/actors/actor_registry.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const RuntimeState = preload("res://scripts/actors/actor_runtime_state.gd")
var _registry = Registry.new()
var _player_id: String = ""
var _party_order: Array = [] # NPC companions only; Player has its own identity.
var _enemy_order: Array = []
var _generation: int = 0
var _command_ready: bool = true
var _active_action: bool = false


static func prototype_fixture(npc_count: int = 3, enemy_count: int = 2) -> Dictionary:
	if npc_count < 0 or npc_count > 3 or enemy_count < 1 or enemy_count > 2:
		return {}
	var specs: Array = [["player", "PLAYER", 30, 30]]
	var party: Array = []
	var enemies: Array = []
	for i in range(npc_count):
		var id: String = "npc_%02d" % (i + 1)
		party.append(id)
		specs.append([id, "NPC", 10, [10, 7, 3][i]])
	for i in range(enemy_count):
		var id: String = ["enemy_a", "enemy_b"][i]
		enemies.append(id)
		var hp: int = [15, 12][i]
		specs.append([id, "ENEMY", hp, hp])
	var actors: Array = []
	for spec in specs:
		actors.append({"definition": {"actor_id": spec[0], "display_name": spec[0],
			"role": spec[1], "base_max_hp": spec[2]}, "initial_hp": spec[3]})
	return {"actors": actors, "player_id": "player", "party_order": party, "enemy_order": enemies}


func _init() -> void:
	restart(prototype_fixture())


func _schema(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _valid_roster(registry, player: Variant, party: Variant, enemies: Variant) -> bool:
	if typeof(player) != TYPE_STRING or typeof(party) != TYPE_ARRAY or typeof(enemies) != TYPE_ARRAY:
		return false
	if party.size() > 3 or enemies.size() < 1 or enemies.size() > 2:
		return false
	var seen: Dictionary = {}
	for group in [[ [player], "PLAYER", "PARTY" ], [party, "NPC", "PARTY"], [enemies, "ENEMY", "ENEMY"]]:
		for id in group[0]:
			if typeof(id) != TYPE_STRING or seen.has(id):
				return false
			var actor: Dictionary = registry.actor_snapshot(id)
			if actor.is_empty() or actor.role != group[1] or actor.membership != group[2]:
				return false
			seen[id] = true
	return seen.size() == registry.snapshot().size()


func restart(fixture: Variant) -> bool:
	if not _schema(fixture, ["actors", "player_id", "party_order", "enemy_order"]) \
		or typeof(fixture.actors) != TYPE_ARRAY:
		return false
	var candidate = Registry.new()
	for entry in fixture.actors:
		if not _schema(entry, ["definition", "initial_hp"]):
			return false
		var definition = Definition.create(entry.definition)
		# Explicit initial HP is mandatory in this fixture schema (null is not a default).
		if definition == null or typeof(entry.initial_hp) != TYPE_INT:
			return false
		var runtime = RuntimeState.create(definition, entry.initial_hp)
		var membership: String = "ENEMY" if definition.snapshot().role == "ENEMY" else "PARTY"
		if not candidate.register_actor(definition, runtime, membership):
			return false
	if not _valid_roster(candidate, fixture.player_id, fixture.party_order, fixture.enemy_order):
		return false
	_registry = candidate
	_player_id = fixture.player_id
	_party_order = fixture.party_order.duplicate()
	_enemy_order = fixture.enemy_order.duplicate()
	_generation += 1
	_command_ready = true
	_active_action = false
	return true


func _can_mutate() -> bool:
	return _command_ready and not _active_action


# Minimal proof guard; these booleans do not schedule or execute an action.
func set_lifecycle(command_ready: Variant, active_action: Variant) -> bool:
	if typeof(command_ready) != TYPE_BOOL or typeof(active_action) != TYPE_BOOL:
		return false
	_command_ready = command_ready
	_active_action = active_action
	return true


func register_actor(definition: Variant, runtime: Variant, membership: Variant) -> bool:
	if not _can_mutate() or not definition is Definition:
		return false
	var baseline: Dictionary = definition.snapshot()
	if Definition.create(baseline) == null:
		return false
	# No second Player; capacity checks precede registry mutation.
	if baseline.role == "PLAYER" or (baseline.role == "NPC" and _party_order.size() >= 3) \
		or (baseline.role == "ENEMY" and _enemy_order.size() >= 2):
		return false
	if not _registry.register_actor(definition, runtime, membership):
		return false
	if baseline.role == "NPC":
		_party_order.append(baseline.actor_id)
	else:
		_enemy_order.append(baseline.actor_id)
	return true


func unregister_actor(id: Variant) -> bool:
	if not _can_mutate() or typeof(id) != TYPE_STRING or id == _player_id:
		return false
	if not _party_order.has(id) and (not _enemy_order.has(id) or _enemy_order.size() == 1):
		return false
	if not _registry.unregister_actor(id):
		return false
	_party_order.erase(id)
	_enemy_order.erase(id)
	return true


func reorder_party(order: Variant) -> bool:
	if not _can_mutate() or typeof(order) != TYPE_ARRAY or order.size() != _party_order.size():
		return false
	if not _valid_roster(_registry, _player_id, order, _enemy_order):
		return false
	_party_order = order.duplicate()
	return true


func actor_snapshot(id: Variant) -> Dictionary:
	return _registry.actor_snapshot(id)


func available_enemy_ids() -> Array:
	var ids: Array = []
	for id in _enemy_order:
		if _registry.actor_snapshot(id).can_act:
			ids.append(id)
	return ids


func snapshot() -> Dictionary:
	return {"actors": _registry.snapshot(), "player_id": _player_id,
		"party_order": _party_order.duplicate(), "enemy_order": _enemy_order.duplicate(),
		"generation": _generation, "command_ready": _command_ready, "active_action": _active_action,
		"available_enemy_ids": available_enemy_ids()}


# Generation is required so an old proof callback cannot mutate a new session.
func fixture_damage(id: Variant, amount: Variant, generation: Variant) -> Dictionary:
	if not _can_mutate() or typeof(generation) != TYPE_INT or generation != _generation:
		return {"status": "REJECTED", "hp_delta": 0}
	return _registry.fixture_damage(id, amount)


func fixture_heal(id: Variant, amount: Variant, generation: Variant) -> Dictionary:
	if not _can_mutate() or typeof(generation) != TYPE_INT or generation != _generation:
		return {"status": "REJECTED", "hp_delta": 0}
	return _registry.fixture_heal(id, amount)
