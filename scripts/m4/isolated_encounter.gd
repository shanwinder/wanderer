extends RefCounted

# Fixture authorization only. No scene, queue, terminal policy, heal or NPC policy.
const Definition = preload("res://scripts/actors/actor_definition.gd")
const PartyState = preload("res://scripts/m4/isolated_actor_state.gd")
const EnemyState = preload("res://scripts/actors/actor_runtime_state.gd")
const Registry = preload("res://scripts/m4/isolated_registry.gd")
const REQUEST_FIELDS: Array = ["session_id", "generation", "revision", "operation_id", "actor_id", "amount"]
const TOKEN_FIELDS: Array = ["session_id", "generation", "revision", "operation_id", "actor_id", "amount", "authorization_id"]
var _authority := RefCounted.new()
var _registry = Registry.new(_authority)
var _session_id: int = get_instance_id()
var _generation: int = 0
var _revision: int = 0
var _next_authorization: int = 0
var _grants: Dictionary = {}
var _used: Dictionary = {}


func restart(fixture: Variant) -> bool:
	if not PartyState.exact_fields(fixture, ["actors"]) \
		or typeof(fixture.actors) != TYPE_ARRAY or fixture.actors.is_empty():
		return false
	var candidate = Registry.new(_authority)
	for entry in fixture.actors:
		if not PartyState.exact_fields(entry, ["definition", "state"]):
			return false
		var definition = Definition.create(entry.definition)
		if definition == null:
			return false
		var state: RefCounted
		if entry.definition.role == "ENEMY":
			if not PartyState.exact_fields(entry.state, ["current_hp"]) \
				or typeof(entry.state.current_hp) != TYPE_INT:
				return false
			state = EnemyState.create(definition, entry.state.current_hp)
		else:
			state = PartyState.create(definition, entry.state)
		if not candidate.register_actor(definition, state):
			return false
	# Publish only the completely validated roster. Failed restart preserves grants too.
	_registry = candidate
	_generation += 1
	_revision = 0
	_grants = {}
	_used = {}
	return true


func snapshot() -> Dictionary:
	return {"schema_version": 1, "session_id": _session_id, "generation": _generation,
		"revision": _revision, "actors": _registry.snapshot()}


func actor_snapshot(id: Variant) -> Dictionary:
	return _registry.actor_snapshot(id)


func authorize_fixture_damage(request: Variant) -> Dictionary:
	if not PartyState.exact_fields(request, REQUEST_FIELDS):
		return _reject("INVALID_REQUEST_FIELDS")
	var invalid: String = _validate_request(request)
	if not invalid.is_empty():
		return _reject(invalid)
	if _grants.has(request.operation_id):
		return _reject("DUPLICATE_OPERATION")
	_next_authorization += 1
	var token: Dictionary = request.duplicate(true)
	token["authorization_id"] = _next_authorization
	_grants[request.operation_id] = token.duplicate(true)
	return {"status": "AUTHORIZED", "reason_code": "FIXTURE_ONLY", "hp_delta": 0,
		"token": token}


func apply_fixture_damage(token: Variant) -> Dictionary:
	if not PartyState.exact_fields(token, TOKEN_FIELDS) \
		or typeof(token.authorization_id) != TYPE_INT or token.authorization_id <= 0:
		return _reject("INVALID_TOKEN_FIELDS")
	var invalid: String = _validate_request(token)
	if not invalid.is_empty():
		return _reject(invalid)
	if not _grants.has(token.operation_id) or _grants[token.operation_id] != token:
		return _reject("UNAUTHORIZED")
	var effect: Dictionary = _registry.commit_fixture_damage(token.actor_id, token.amount, _authority)
	if effect.status == "APPLIED":
		_used[token.operation_id] = true
		_revision += 1
	return effect


func _validate_request(request: Dictionary) -> String:
	if typeof(request.actor_id) != TYPE_STRING or not Definition.valid_actor_id(request.actor_id) \
		or actor_snapshot(request.actor_id).is_empty():
		return "UNKNOWN_ACTOR"
	for field in ["session_id", "generation", "revision"]:
		if typeof(request[field]) != TYPE_INT:
			return "INVALID_IDENTITY_TYPE"
	if _generation == 0 or request.session_id != _session_id:
		return "FOREIGN_SESSION"
	if request.generation != _generation:
		return "STALE_GENERATION"
	if typeof(request.operation_id) != TYPE_STRING or not Definition.valid_actor_id(request.operation_id):
		return "INVALID_OPERATION_ID"
	if _used.has(request.operation_id):
		return "DUPLICATE_OPERATION"
	if request.revision != _revision:
		return "STALE_REVISION"
	var row: Dictionary = actor_snapshot(request.actor_id)
	if row.membership != "PARTY":
		return "PARTY_ONLY"
	if not row.state.eligible:
		return "INELIGIBLE_STATE"
	if typeof(request.amount) != TYPE_INT or request.amount < 0:
		return "INVALID_AMOUNT"
	return ""


func _reject(reason: String) -> Dictionary:
	return {"status": "REJECTED", "reason_code": reason, "hp_delta": 0}
