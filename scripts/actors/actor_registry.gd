extends RefCounted

# Encounter-local ownership. Public reads return detached value snapshots only.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const RuntimeState = preload("res://scripts/actors/actor_runtime_state.gd")
var _actors: Dictionary = {}
var _definitions: Dictionary = {}
var _memberships: Dictionary = {}
var _retired: Dictionary = {}


func register_actor(definition: Variant, runtime: Variant, membership: Variant) -> bool:
	if not definition is Definition or not runtime is RuntimeState:
		return false
	var baseline: Dictionary = definition.snapshot()
	var validated = Definition.create(baseline)
	if validated == null or typeof(membership) != TYPE_STRING:
		return false
	if membership not in ["PARTY", "ENEMY"] \
		or (baseline.role == "ENEMY") != (membership == "ENEMY"):
		return false
	var id: String = baseline.actor_id
	if _actors.has(id) or _retired.has(id):
		return false
	var state: Dictionary = runtime.snapshot()
	if state.actor_id != id or state.max_hp != baseline.base_max_hp:
		return false
	var owned = RuntimeState.create(validated, state.current_hp)
	if owned == null or owned.snapshot() != state:
		return false
	# Copy at entry too: a caller retaining the supplied runtime cannot mutate us.
	_actors[id] = owned
	_definitions[id] = validated
	_memberships[id] = membership
	return true


func unregister_actor(id: Variant) -> bool:
	if typeof(id) != TYPE_STRING or not _actors.has(id):
		return false
	_actors.erase(id)
	_definitions.erase(id)
	_memberships.erase(id)
	_retired[id] = true
	return true


func actor_snapshot(id: Variant) -> Dictionary:
	if typeof(id) != TYPE_STRING or not _actors.has(id):
		return {}
	var view: Dictionary = _definitions[id].snapshot()
	view.merge(_actors[id].snapshot(), true)
	view["membership"] = _memberships[id]
	return view


func snapshot() -> Dictionary:
	var view: Dictionary = {}
	for id in _actors:
		view[id] = actor_snapshot(id)
	return view


# Narrow data-proof mutation boundary; no combat actions/effects framework.
func fixture_damage(id: Variant, amount: Variant) -> Dictionary:
	if typeof(id) != TYPE_STRING or not _actors.has(id):
		return {"status": "INVALID_INPUT", "hp_delta": 0}
	return _actors[id].take_damage(amount)


func fixture_heal(id: Variant, amount: Variant) -> Dictionary:
	if typeof(id) != TYPE_STRING or not _actors.has(id):
		return {"status": "INVALID_INPUT", "hp_delta": 0}
	return _actors[id].heal(amount)
