extends RefCounted

# M4Playable v1's sole live publication authority. Capabilities are object identity,
# never strings in a Request. The trusted composition root retains these handles.
const C = preload("res://scripts/m4/playable_contract.gd")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const Rules = preload("res://scripts/m4/playable_rules.gd")
var _root: Dictionary = {}
var _factory_capability: RefCounted
var _input_capability: RefCounted
var _driver_capability: RefCounted
var _presenter_capability: RefCounted
var _fail_close_commit: bool = false
var _close_failure: Dictionary = {} # E5 host diagnostic, never combat state.
var _fail_before_publish: bool = false # Host fault probe; never combat state/import.

func _init(factory: RefCounted, input: RefCounted, driver: RefCounted, presenter: RefCounted) -> void:
	_factory_capability = factory
	_input_capability = input
	_driver_capability = driver
	_presenter_capability = presenter

func bootstrap(request: Variant, capability: Variant) -> Dictionary:
	var reason: String = ""
	if not C.valid("Bootstrap", request): reason = "INVALID_SCHEMA"
	elif capability == null or capability != _factory_capability or not _root.is_empty(): reason = "UNAUTHORIZED"
	elif Catalog.fixture(request.fixture_id, request.fixture_version).is_empty(): reason = "UNKNOWN_FIXTURE"
	if not reason.is_empty(): return {"status": "REJECTED", "reason": "M405_" + reason, "view": null}
	var candidate: Dictionary = Rules.initial(request.fixture_id, get_instance_id(), 1, request.fixture_version)
	if not Rules.root_valid(candidate): return {"status": "REJECTED", "reason": "M405_INVALID_SEED", "view": null}
	if _fail_before_publish:
		_fail_before_publish = false
		return {"status": "REJECTED", "reason": "M405_INVALID_CANDIDATE", "view": null}
	_root = candidate # Atomic bootstrap publication; no partially live Session.
	return {"status": "CREATED", "reason": "M405_CREATED", "view": Rules.view(_root)}

func snapshot() -> Dictionary:
	return _root.duplicate(true)

func read_view() -> Dictionary:
	return {} if _root.is_empty() else Rules.view(_root)

func read_observation() -> Dictionary:
	return {} if _root.is_empty() else Rules.observation(_root)

func replay_matches() -> bool:
	return not _root.is_empty() and Rules.root_valid(_root)

func inject_failure_before_publication(capability: Variant) -> bool:
	if capability == null or capability != _driver_capability: return false
	_fail_before_publish = true
	return true

func transact(request: Variant, capability: Variant) -> Dictionary:
	# No identity-bearing transaction exists before a successful factory bootstrap.
	if _root.is_empty(): return {}
	var invalid: String = C.request_error(request)
	if not invalid.is_empty(): return Rules.response(_root, "REJECTED", invalid)
	if request.identity.session != _root.session: return Rules.response(_root, "REJECTED", "FOREIGN_SESSION")
	if request.identity.generation != _root.generation: return Rules.response(_root, "REJECTED", "STALE_GENERATION")
	var expected: Variant = {"INPUT": _input_capability, "DRIVER": _driver_capability, "PRESENTER": _presenter_capability}[request.issuer]
	if capability == null or capability != expected: return Rules.response(_root, "REJECTED", "UNAUTHORIZED")
	if request.operation == "CLOSE_ROUND": return _close_round(request)
	var prior_revision: int = _root.revision
	var result: Dictionary = Rules.step(_root, request)
	if result.root.is_empty(): return result.response.duplicate(true)
	var candidate: Dictionary = result.root
	if not _candidate_valid(request, result):
		return Rules.response(_root, "REJECTED", "INVALID_CANDIDATE")
	# Full reconstruction includes actual issued tokens/receipts, not caller results.
	if _root.revision != prior_revision: return Rules.response(_root, "REJECTED", "STALE_REVISION")
	if _fail_before_publish:
		_fail_before_publish = false
		return Rules.response(_root, "REJECTED", "INVALID_CANDIDATE")
	_root = candidate # The only successful transaction publication seam. No await.
	return result.response.duplicate(true)

func _candidate_valid(request: Dictionary, result: Dictionary) -> bool:
	return Rules.candidate_valid(_root, request, result) and Rules.root_valid(result.root)

func inject_failure_before_close_commit(capability: Variant) -> bool:
	if capability == null or capability != _driver_capability: return false
	_fail_close_commit = true
	return true

func close_failure_diagnostic() -> Dictionary:
	return _close_failure.duplicate(true)

func _close_round(request: Dictionary) -> Dictionary:
	for kind in ["SEAL", "COMMIT_CLOSE"]:
		var prior_revision: int = _root.revision
		var result: Dictionary = Rules.close_step(_root, request, kind)
		if result.root.is_empty():
			if kind == "COMMIT_CLOSE":
				_close_failure = {"stage": kind, "reason": result.response.reason, "root": snapshot()}
			return result.response.duplicate(true)
		var valid: bool = (C.response_valid(kind, result.response) and result == Rules.close_step(_root, request, kind)
			and Rules.root_valid(result.root) and _root.revision == prior_revision)
		var fault: bool = _fail_before_publish or (kind == "COMMIT_CLOSE" and _fail_close_commit)
		if fault:
			_fail_before_publish = false
			if kind == "COMMIT_CLOSE": _fail_close_commit = false
		if not valid or fault:
			if kind == "COMMIT_CLOSE":
				_close_failure = {"stage": kind, "reason": "M405_CLOSE_FAILED", "root": snapshot()}
			return Rules.response(_root, "REJECTED", "CLOSE_FAILED" if kind == "COMMIT_CLOSE" else "INVALID_CANDIDATE")
		_root = result.root # Same single authority; each genuine internal revision publishes once.
		if kind == "COMMIT_CLOSE": return result.response.duplicate(true)
	return Rules.response(_root, "REJECTED", "CLOSE_FAILED")
