extends RefCounted

# Trusted composition supplies the real INPUT capability. No mirrored combat state.
var _owner: RefCounted
var _capability: RefCounted

func _init(owner: RefCounted, capability: RefCounted) -> void:
	_owner = owner
	_capability = capability

func command(request_id: String, action: String, target_id: String) -> Dictionary:
	return _submit(request_id, "COMMAND", {"actor_id": "player", "action": action, "target_id": target_id})

func guidance(request_id: String, request: Dictionary) -> Dictionary:
	return _submit(request_id, "GUIDANCE", {"request": request.duplicate(true)})

func restart(request_id: String, fixture_id: String, fixture_version: int) -> Dictionary:
	return _submit(request_id, "RESTART", {"fixture_id": fixture_id, "fixture_version": fixture_version})

func _submit(request_id: String, operation: String, payload: Dictionary) -> Dictionary:
	var current: Dictionary = _owner.read_view()
	if current.is_empty(): return {}
	return _owner.transact({"domain": "M4_PLAYABLE", "version": 1,
		"identity": current.identity, "queue_id": current.queue_id, "request_id": request_id,
		"issuer": "INPUT", "operation": operation, "payload": payload}, _capability)
