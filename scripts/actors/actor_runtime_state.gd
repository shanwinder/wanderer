class_name ActorRuntimeState
extends RefCounted

const Definition = preload("res://scripts/actors/actor_definition.gd")
var _actor_id: String = ""
var _current_hp: int = 0
var _max_hp: int = 0


static func create(definition: Variant, initial_hp: Variant = null) -> ActorRuntimeState:
	if not definition is Definition:
		return null
	var baseline: Dictionary = definition.snapshot()
	# Also rejects a bare Definition.new() that bypassed the validated factory.
	if Definition.create(baseline) == null:
		return null
	var hp: Variant = baseline.base_max_hp if initial_hp == null else initial_hp
	if typeof(hp) != TYPE_INT or hp < 0 or hp > baseline.base_max_hp:
		return null
	var state := ActorRuntimeState.new()
	state._actor_id = baseline.actor_id
	state._max_hp = baseline.base_max_hp
	state._current_hp = hp
	return state


func take_damage(amount: Variant) -> Dictionary:
	if _actor_id.is_empty() or typeof(amount) != TYPE_INT or amount < 0:
		return {"status": "INVALID_INPUT", "hp_delta": 0}
	var applied: int = mini(amount, _current_hp)
	_current_hp -= applied
	return {"status": "APPLIED", "hp_delta": -applied}


func heal(amount: Variant) -> Dictionary:
	if _actor_id.is_empty() or typeof(amount) != TYPE_INT or amount < 0:
		return {"status": "INVALID_INPUT", "hp_delta": 0}
	# Clamp before addition, including very large integer inputs.
	var applied: int = mini(amount, _max_hp - _current_hp)
	_current_hp += applied
	return {"status": "APPLIED", "hp_delta": applied}


func can_act() -> bool:
	# Fixture availability only; no Down/Death/permadeath semantics.
	return not _actor_id.is_empty() and _current_hp > 0


func snapshot() -> Dictionary:
	return {"actor_id": _actor_id, "current_hp": _current_hp,
		"max_hp": _max_hp, "can_act": can_act()}
