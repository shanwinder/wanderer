extends Control

const Owner = preload("res://scripts/m4/playable_encounter.gd")
const Rules = preload("res://scripts/m4/playable_rules.gd")
const InputAdapter = preload("res://scripts/m4/playable_input_adapter.gd")
const Presentation = preload("res://scripts/m4/playable_presentation_projection.gd")
const Guidance = preload("res://scripts/npc/guidance_data_contract.gd")

@export var fixture_id: String = "m405-demo/main"
@export var fixture_version: int = 1

@onready var _hud: Control = $HUD

var _owner: RefCounted
var _input_adapter: RefCounted
var _driver: RefCounted
var _presenter: RefCounted
var _callbacks := Presentation.Callbacks.new()
var _request_number: int = 0
var _shown_events: int = 0
var _driver_error: String = ""


func _ready() -> void:
	_hud.setup({
		"player": [$Battlefield/PlayerRoot, $Battlefield/PlayerRoot/Player],
		"npc_01": [$Battlefield/Npc1Root, $Battlefield/Npc1Root/Npc1],
		"npc_02": [$Battlefield/Npc2Root, $Battlefield/Npc2Root/Npc2],
		"npc_03": [$Battlefield/Npc3Root, $Battlefield/Npc3Root/Npc3],
		"enemy_a": [$Battlefield/EnemyARoot, $Battlefield/EnemyARoot/EnemyA],
		"enemy_b": [$Battlefield/EnemyBRoot, $Battlefield/EnemyBRoot/EnemyB],
	})
	_hud.command_pressed.connect(_command)
	_hud.guidance_pressed.connect(_guidance)
	_hud.restart_pressed.connect(_restart)
	_hud.exit_pressed.connect(_exit_held_session)
	_create_session()


func _create_session() -> void:
	var factory := RefCounted.new()
	var input := RefCounted.new()
	var driver := RefCounted.new()
	var presenter := RefCounted.new()
	var candidate := Owner.new(factory, input, driver, presenter)
	var reply: Dictionary = candidate.bootstrap({
		"domain": "M4_PLAYABLE", "version": 1, "fixture_id": fixture_id,
		"fixture_version": fixture_version,
	}, factory)
	if reply.status != "CREATED":
		_hud.report_error(reply.reason)
		return
	_owner = candidate
	_input_adapter = InputAdapter.new(_owner, input)
	_driver = driver
	_presenter = presenter
	_callbacks.attach(_owner, _presenter)
	_shown_events = 0
	_driver_error = ""
	_hud.reset()
	_refresh()


func _process(_delta: float) -> void:
	if _owner == null or not _driver_error.is_empty():
		return
	var view: Dictionary = _owner.read_view()
	if view.phase == "PREPARED" and not view.command_ready:
		# ADMIT itself validates a fresh command, unavailable Player or terminal seed.
		var reply := _drive("ADMIT")
		_after_driver(reply, reply.status == "STOPPED")
	elif view.phase == "OPEN" and view.queue_phase == "DRAINED":
		var reply := _drive("CLOSE_ROUND")
		_after_driver(reply, reply.status != "REJECTED")
	elif view.phase == "OPEN" and view.queue_phase == "READY":
		_advance_slot()


func _advance_slot() -> void:
	# View has no current-slot field. The driver reads the detached owned Queue via
	# the existing slot accessor. It never keeps a cursor or sends a calculated move.
	var slot: Dictionary = Rules.slot(_owner.snapshot())
	var advance := _drive("ADVANCE")
	if advance.status == "APPLIED":
		_hud.report_unavailable(slot.actor_id)
		_refresh()
		return
	if advance.status != "READY":
		_after_driver(advance)
		return

	var locked: Dictionary
	match slot.actor_id:
		"player":
			locked = _drive("PLAYER_LOCK", {"slot_id": slot.slot_id})
		"enemy_a", "enemy_b":
			locked = _drive("ENEMY_LOCK", {"slot_id": slot.slot_id})
		_:
			locked = _drive("DECIDE_LOCK", {"observation": _owner.read_observation()})
	if locked.status != "AUTHORIZED":
		_after_driver(locked)
		return
	_present_events()
	if not _driver_error.is_empty():
		return
	var hit := _callbacks.bind(locked.token, "IMPACT", _request_id("driver"))
	var done := _callbacks.bind(locked.token, "COMPLETE", _request_id("driver"))
	_hud.play(locked.token, _impact.bind(hit), _complete.bind(done))


func _impact(callback: Callable) -> Dictionary:
	var reply: Dictionary = callback.call()
	if reply.is_empty():
		return {}
	if reply.status == "REJECTED":
		_after_driver(reply)
		return {}
	return _present_events()


func _complete(callback: Callable) -> void:
	if not _driver_error.is_empty():
		return
	var reply: Dictionary = callback.call()
	if not reply.is_empty():
		_after_driver(reply, reply.status == "COMPLETED")


func _drive(operation: String, payload: Dictionary = {}) -> Dictionary:
	var view: Dictionary = _owner.read_view()
	return _owner.transact({
		"domain": "M4_PLAYABLE", "version": 1, "identity": view.identity,
		"queue_id": view.queue_id, "issuer": "DRIVER", "operation": operation,
		"request_id": _request_id("driver"), "payload": payload,
	}, _driver)


func _after_driver(reply: Dictionary, has_events: bool = false) -> void:
	if reply.status == "REJECTED":
		_driver_error = reply.reason
	if has_events:
		_present_events()
	else:
		_refresh()


func _present_events() -> Dictionary:
	var events: Array = _owner.read_presentation_events()
	if events.size() <= _shown_events:
		_driver_error = "ไม่พบเหตุการณ์จากการบันทึกผลการต่อสู้"
		_refresh()
		return {}
	var feedback: Dictionary = _hud.present(events.slice(_shown_events))
	_shown_events = events.size()
	_refresh()
	return feedback


func _command(action: String, target: String, identity: Dictionary) -> Dictionary:
	if not _accepts_input(identity):
		return {}
	var reply: Dictionary = _input_adapter.command(_request_id("ui"), action, target)
	if reply.status == "ACCEPTED":
		_hud.report_command(action, target)
	else:
		_hud.report_error(reply.reason)
	_refresh()
	return reply


func _guidance(kind: String, target: String, identity: Dictionary) -> Dictionary:
	if not _accepts_input(identity):
		return {}
	var view: Dictionary = _owner.read_view()
	var reply: Dictionary = _input_adapter.guidance(_request_id("ui"), {
		"schema_version": Guidance.SCHEMA_VERSION, "guidance_type": kind,
		"issuer_player_id": "player", "preferred_target_id": target,
		"encounter_id": identity.session, "generation": identity.generation,
		"round_id": identity.round_id, "expected_guidance_revision": view.guidance.guidance_revision,
	})
	if reply.status == "REJECTED":
		_hud.report_error(reply.guidance_reason if not reply.guidance_reason.is_empty() else reply.reason)
	_refresh()
	return reply


func _accepts_input(identity: Dictionary) -> bool:
	if _owner == null or not _driver_error.is_empty():
		return false
	var view: Dictionary = _owner.read_view()
	return view.command_ready and view.identity == identity


func _restart() -> Dictionary:
	if _owner == null:
		return {}
	var reply: Dictionary = _input_adapter.restart(_request_id("ui"), fixture_id, fixture_version)
	if reply.status == "APPLIED":
		_callbacks.attach(_owner, _presenter)
		_hud.reset()
		_shown_events = 0
		_driver_error = ""
		_present_events()
	else:
		_hud.report_error(reply.reason)
	return reply


func _exit_held_session() -> void:
	if _owner == null or _owner.close_failure_diagnostic().is_empty() or _owner.read_view().phase != "SEALED":
		return
	_detach()
	_create_session()


func _detach() -> void:
	_callbacks.detach()
	_hud.reset()
	_owner = null
	_input_adapter = null
	_driver = null
	_presenter = null


func _refresh() -> void:
	var view: Dictionary = _owner.read_view()
	var diagnostic: Dictionary = _owner.close_failure_diagnostic() if view.phase == "SEALED" else {}
	_hud.render(view, _driver_error, diagnostic)


func _request_id(issuer: String) -> String:
	_request_number += 1
	return "%s/b5/%d" % [issuer, _request_number]


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_detach()
