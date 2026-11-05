class_name M4IsolatedActorState
extends RefCounted

# Opt-in Party data only. Never passed to the production Resolver/Guidance APIs.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const FIXTURE_FIELDS: Array = ["current_hp", "life_state", "participation"]
const SNAPSHOT_FIELDS: Array = ["schema_version", "actor_id", "role", "max_hp",
	"current_hp", "life_state", "participation", "eligible"]
var _data: Dictionary = {}


static func exact_fields(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func create(definition: Variant, fixture: Variant) -> M4IsolatedActorState:
	if not definition is Definition or not exact_fields(fixture, FIXTURE_FIELDS):
		return null
	var baseline: Dictionary = definition.snapshot()
	if Definition.create(baseline) == null or baseline.role not in ["PLAYER", "NPC"]:
		return null
	if typeof(fixture.current_hp) != TYPE_INT \
		or fixture.current_hp < 0 or fixture.current_hp > baseline.base_max_hp:
		return null
	if typeof(fixture.life_state) != TYPE_STRING or typeof(fixture.participation) != TYPE_STRING:
		return null
	if fixture.life_state not in ["ALIVE", "DOWN", "DEAD"] \
		or fixture.participation not in ["PRESENT", "RETREATED"]:
		return null
	if fixture.participation == "RETREATED" and fixture.life_state != "ALIVE":
		return null
	if (fixture.life_state == "ALIVE") != (fixture.current_hp > 0):
		return null
	var state := M4IsolatedActorState.new()
	state._data = {"schema_version": 1, "actor_id": baseline.actor_id, "role": baseline.role,
		"max_hp": baseline.base_max_hp, "current_hp": fixture.current_hp,
		"life_state": fixture.life_state, "participation": fixture.participation,
		"eligible": fixture.life_state == "ALIVE" and fixture.participation == "PRESENT"}
	# All values are scalars. No public in-place HP/heal/life setters.
	state._data.make_read_only()
	return state


static func from_snapshot(definition: Variant, view: Variant) -> M4IsolatedActorState:
	if not exact_fields(view, SNAPSHOT_FIELDS):
		return null
	if typeof(view.schema_version) != TYPE_INT or view.schema_version != 1 \
		or typeof(view.actor_id) != TYPE_STRING or typeof(view.role) != TYPE_STRING \
		or typeof(view.max_hp) != TYPE_INT or typeof(view.eligible) != TYPE_BOOL:
		return null
	var state = create(definition, {"current_hp": view.current_hp,
		"life_state": view.life_state, "participation": view.participation})
	if state == null or state.snapshot() != view:
		return null
	return state


func snapshot() -> Dictionary:
	return _data.duplicate(true)
