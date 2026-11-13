extends RefCounted

const C = preload("res://scripts/m4/playable_contract.gd")

# Internal projection of a verified replay step or a committed Restart audit.
# This module has no owner capability and does not accept gameplay transactions.
static func project(operation: String, reply: Dictionary, request: Variant = null) -> Array:
	if reply.status == "REJECTED" or not C.response_valid(operation, reply):
		return []
	match operation:
		"PLAYER_LOCK", "ENEMY_LOCK", "DECIDE_LOCK":
			return [_event("INTENT", reply.view, reply.token)]
		"IMPACT":
			var events: Array = [_event("IMPACT", reply.view, request.payload.token, reply.effect)]
			if reply.view.outcome != null and reply.view.outcome.freeze_revision == reply.identity.state_revision:
				events.append(_event("TERMINAL", reply.view, request.payload.token))
			return events
		"COMPLETE":
			return [_event("COMPLETION", reply.view, request.payload.token, null, reply.receipt)]
		"ADMIT":
			if reply.reason == "M405_OUTCOME_FROZEN":
				return [_event("TERMINAL", reply.view)]
		"COMMIT_CLOSE":
			return [_event("ROUND_CLOSED", reply.view)]
		"RESTART":
			return [_event("RESET", reply.view)]
	return []

static func _event(kind: String, view: Dictionary, token: Variant = null,
		effect: Variant = null, receipt: Variant = null) -> Dictionary:
	var identity: Dictionary = view.identity
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": identity,
		"event_id": "m405/%d/%d/presentation/%d/%s" % [identity.session, identity.generation,
			identity.state_revision, kind], "kind": kind, "token": token, "effect": effect,
		"receipt": receipt, "view": view}.duplicate(true)

# Holds callback correlation only. Restart changes the owner generation;
# detaching or rebinding additionally revokes all callbacks for this consumer.
class Callbacks:
	extends RefCounted

	var _owner: RefCounted
	var _capability: RefCounted
	var _epoch: RefCounted = RefCounted.new()

	func attach(owner: RefCounted, capability: RefCounted) -> void:
		_epoch = RefCounted.new()
		_owner = owner
		_capability = capability

	func detach() -> void:
		attach(null, null)

	func bind(token: Dictionary, operation: String, request_id: String) -> Callable:
		if _owner == null or operation not in ["IMPACT", "COMPLETE"]:
			return Callable()
		var view: Dictionary = _owner.read_view()
		if view.get("active_token") != token:
			return Callable()
		return _forward.bind(_epoch, token.duplicate(true), operation, request_id)

	func _forward(epoch: RefCounted, token: Dictionary, operation: String, request_id: String) -> Dictionary:
		if epoch != _epoch or _owner == null:
			return {}
		var view: Dictionary = _owner.read_view()
		if view.is_empty() or view.identity.session != token.identity.session or view.identity.generation != token.identity.generation:
			return {}
		return _owner.transact({"domain": "M4_PLAYABLE", "version": 1,
			"identity": view.identity, "queue_id": view.queue_id, "issuer": "PRESENTER",
			"request_id": request_id, "operation": operation, "payload": {"token": token}}, _capability)
