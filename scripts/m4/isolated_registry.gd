extends RefCounted

# Single owned runtime per ID. This registry is not the production ActorRegistry.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")
var _actors: Dictionary = {}
var _definitions: Dictionary = {}
var _authority: RefCounted


func _init(authority: RefCounted) -> void:
	_authority = authority


func register_actor(definition: Variant, runtime: Variant) -> bool:
	if not definition is Definition:
		return false
	var baseline: Dictionary = definition.snapshot()
	var validated = Definition.create(baseline)
	if validated == null or _actors.has(baseline.actor_id):
		return false
	var owned: RefCounted
	if baseline.role == "ENEMY":
		if not runtime is EnemyState:
			return false
		var view: Dictionary = runtime.snapshot()
		if not PartyState.exact_fields(view, ["actor_id", "current_hp", "max_hp", "can_act"]) \
			or typeof(view.actor_id) != TYPE_STRING or view.actor_id != baseline.actor_id \
			or typeof(view.max_hp) != TYPE_INT or view.max_hp != baseline.base_max_hp \
			or typeof(view.current_hp) != TYPE_INT or typeof(view.can_act) != TYPE_BOOL:
			return false
		owned = EnemyState.create(validated, view.current_hp)
		if owned == null or owned.snapshot() != view:
			return false
	else:
		if not runtime is PartyState:
			return false
		owned = PartyState.from_snapshot(validated, runtime.snapshot())
		if owned == null:
			return false
	# Nothing is published until every check succeeds; supplied objects are not kept.
	_actors[baseline.actor_id] = owned
	_definitions[baseline.actor_id] = validated
	return true


func actor_snapshot(id: Variant) -> Dictionary:
	if typeof(id) != TYPE_STRING or not _actors.has(id):
		return {}
	var baseline: Dictionary = _definitions[id].snapshot()
	return {"definition": baseline, "state": _actors[id].snapshot(),
		"membership": "ENEMY" if baseline.role == "ENEMY" else "PARTY"}


func snapshot() -> Dictionary:
	var view: Dictionary = {}
	for id in _actors:
		view[id] = actor_snapshot(id)
	return view


func commit_fixture_damage(id: Variant, amount: Variant, authority: Variant) -> Dictionary:
	if authority == null or authority != _authority:
		return _reply("REJECTED", "UNAUTHORIZED")
	var row: Dictionary = actor_snapshot(id)
	if row.is_empty():
		return _reply("REJECTED", "UNKNOWN_ACTOR")
	if row.membership != "PARTY":
		return _reply("REJECTED", "PARTY_ONLY")
	if not row.state.eligible:
		return _reply("REJECTED", "INELIGIBLE_STATE")
	if typeof(amount) != TYPE_INT or amount < 0:
		return _reply("REJECTED", "INVALID_AMOUNT")
	# Clamp BEFORE subtraction (also safe for INT64_MAX).
	var applied: int = mini(amount, row.state.current_hp)
	var hp: int = row.state.current_hp - applied
	var candidate = PartyState.create(_definitions[id], {"current_hp": hp,
		"life_state": "DOWN" if hp == 0 else "ALIVE", "participation": "PRESENT"})
	if candidate == null:
		return _reply("REJECTED", "INVALID_CANDIDATE")
	# Replace one validated object: HP and LifeState become visible together.
	_actors[id] = candidate
	return {"status": "APPLIED", "reason_code": "HP_ZERO_DOWN" if hp == 0 else "FIXTURE_DAMAGE",
		"hp_delta": -applied}


func _reply(status: String, reason: String) -> Dictionary:
	return {"status": status, "reason_code": reason, "hp_delta": 0}
