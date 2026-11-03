extends RefCounted

# Isolated data-only encounter; not connected to the main combat controller.
# Tests supply the post-Player state, then run one NPC slot and one enemy slot.
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const ATTACK_DAMAGE: int = 1
const HELP_AMOUNT: int = 4
const DEFEND_REDUCTION: int = 2

var _resolver = Resolver.new()
var _state: Dictionary = {}
var _generation: int = 0
var _next_action_id: int = 0
var _active: Dictionary = {}
var _pending: Array[String] = []
var _round: int = 1
var _round_completions: int = 0
var _result: String = ""
var _self_defend: bool = false


func _init() -> void:
	restart()


func restart(overrides: Dictionary = {}) -> Dictionary:
	var initial: Dictionary = {
		"player_hp": 20, "player_max_hp": 30, "npc_hp": 10, "npc_max_hp": 10,
		"enemy_hp": 10, "enemy_max_hp": 15, "incoming_target_id": "player",
		"incoming_damage": 3, "help_enabled": true, "help_uses_remaining": 1, "guidance": "NONE"
	}
	for key in overrides:
		if not initial.has(key):
			return _response("INVALID_INPUT", "UNKNOWN_FIELD")
	initial.merge(overrides, true)
	for key in ["enemy_hp", "enemy_max_hp"]:
		if typeof(initial[key]) != TYPE_INT:
			return _response("INVALID_INPUT", "INVALID_ENEMY_HP")
	if initial.enemy_max_hp <= 0 or initial.enemy_hp < 0 or initial.enemy_hp > initial.enemy_max_hp:
		return _response("INVALID_INPUT", "INVALID_ENEMY_HP")
	var invalid: String = _resolver.validate_snapshot(_snapshot_from(initial))
	if not invalid.is_empty():
		return _response("INVALID_INPUT", invalid)
	# Invalidate old effect AND completion callbacks before replacing state.
	_generation += 1
	_state = initial.duplicate(true)
	_active.clear()
	_pending.clear()
	_round = 1
	_round_completions = 0
	_self_defend = false
	_result = ""
	_update_terminal()
	return _response("RESTARTED")


func situation_snapshot() -> Dictionary:
	return _snapshot_from(_state)


func _snapshot_from(state: Dictionary) -> Dictionary:
	var snapshot: Dictionary = state.duplicate(true)
	snapshot.erase("enemy_hp")
	snapshot.erase("enemy_max_hp")
	snapshot["living_enemy_ids"] = ["enemy_a"] if state.enemy_hp > 0 else []
	return snapshot


func inspect() -> Dictionary:
	return {"state": _state.duplicate(true), "generation": _generation, "round": _round,
		"round_completions": _round_completions, "result": _result,
		"self_defend": _self_defend, "pending": _pending.duplicate(),
		"active": _active.duplicate(true)}


func begin_npc_slot() -> Dictionary:
	if not _active.is_empty() and not _active.completed:
		return _response("REJECTED", "SLOT_IN_PROGRESS")
	_update_terminal()
	if not _result.is_empty():
		return _response("SKIP", "BATTLE_OVER")
	var decision: Dictionary = _resolver.decide(situation_snapshot())
	if decision.status == "INVALID_INPUT":
		return decision
	_next_action_id += 1
	_active = {"generation": _generation, "action_id": _next_action_id,
		"round": _round, "decision": decision.duplicate(true), "resolved": false,
		"completed": false, "effect_result": {}}
	_pending.assign(["npc", "enemy"])
	return _active.duplicate(true)


func resolve_npc(token: Dictionary) -> Dictionary:
	var rejection: String = _check_token(token)
	if not rejection.is_empty():
		return _response("REJECTED", rejection)
	if _active.resolved:
		return _response("REJECTED", "ACTION_ALREADY_RESOLVED")
	# Every attempt consumes the effect boundary, including invalidated targets.
	_active.resolved = true
	var decision: Dictionary = _active.decision
	var effect: Dictionary = _response("APPLIED")
	effect["hp_delta"] = 0
	effect["help_use_delta"] = 0
	_update_terminal()
	if _state.enemy_hp == 0 and decision.action == "ATTACK":
		effect = _response("SKIP", "TARGET_DEAD_BEFORE_RESOLVE")
	elif not _result.is_empty():
		effect = _response("SKIP", "BATTLE_OVER")
	elif _state.npc_hp == 0:
		effect = _response("SKIP", "ACTOR_UNAVAILABLE")
	elif decision.action == "ATTACK":
		if decision.target_id != "enemy_a":
			effect = _response("SKIP", "INVALID_TARGET")
		else:
			var damage: int = mini(ATTACK_DAMAGE, _state.enemy_hp)
			_state.enemy_hp -= damage
			effect.hp_delta = -damage
	elif decision.action == "DEFEND":
		if decision.target_id != "npc":
			effect = _response("SKIP", "INVALID_TARGET")
		else:
			_self_defend = true
	elif decision.action == "HELP":
		if decision.target_id != "player" or not _state.help_enabled \
			or _state.help_uses_remaining == 0 \
			or _state.player_hp * 100 > _state.player_max_hp * 30:
			effect = _response("SKIP", "HELP_UNAVAILABLE_AT_RESOLVE")
		else:
			var healed: int = mini(HELP_AMOUNT, _state.player_max_hp - _state.player_hp)
			_state.player_hp += healed
			_state.help_uses_remaining -= 1
			effect.hp_delta = healed
			effect.help_use_delta = -1
	elif decision.action == "SKIP":
		effect = _response("SKIP", decision.reason_code)
	else:
		effect = _response("INVALID_INPUT", "UNKNOWN_ACTION")
	_update_terminal()
	_active.effect_result = effect.duplicate(true)
	return effect


func complete_npc(token: Dictionary) -> Dictionary:
	var rejection: String = _check_token(token)
	if not rejection.is_empty():
		return _response("REJECTED", rejection)
	if _active.completed:
		return _response("REJECTED", "ACTION_ALREADY_COMPLETED")
	if not _active.resolved:
		return _response("REJECTED", "EFFECT_NOT_RESOLVED")
	_active.completed = true
	_pending.pop_front()
	_update_terminal()
	if _result.is_empty():
		_resolve_enemy()
	_pending.clear()
	_self_defend = false
	if _result.is_empty():
		_round += 1
		_round_completions += 1
	return _response("COMPLETED")


func _resolve_enemy() -> void:
	# Enemy target/damage were declared before the NPC slot and remain locked.
	var target: String = _state.incoming_target_id
	if _state.enemy_hp <= 0 or _state.incoming_damage == 0 or target == "":
		return
	var hp_key: String = target + "_hp"
	if _state[hp_key] <= 0:
		return
	var damage: int = _state.incoming_damage
	if target == "npc" and _self_defend:
		damage = maxi(1, damage - DEFEND_REDUCTION)
		_self_defend = false
	_state[hp_key] = maxi(0, _state[hp_key] - damage)
	_update_terminal()


# Race injection for the isolated fixture (e.g. enemy defeated before callback).
# Changes combat values only; never re-evaluates the locked decision.
func apply_fixture_change(changes: Dictionary) -> Dictionary:
	for key in changes:
		if key not in ["enemy_hp", "player_hp", "npc_hp", "help_enabled", "help_uses_remaining"]:
			return _response("INVALID_INPUT", "UNSUPPORTED_FIXTURE_CHANGE")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.merge(changes, true)
	if typeof(candidate.enemy_hp) != TYPE_INT or candidate.enemy_hp < 0 \
		or candidate.enemy_hp > candidate.enemy_max_hp:
		return _response("INVALID_INPUT", "INVALID_ENEMY_HP")
	var invalid: String = _resolver.validate_snapshot(_snapshot_from(candidate))
	if not invalid.is_empty():
		return _response("INVALID_INPUT", invalid)
	_state = candidate
	_update_terminal()
	return _response("CHANGED")


func _check_token(token: Dictionary) -> String:
	if typeof(token.get("generation")) != TYPE_INT or typeof(token.get("action_id")) != TYPE_INT:
		return "INVALID_TOKEN"
	if token.generation != _generation:
		return "STALE_BATTLE_GENERATION"
	if _active.is_empty() or token.action_id != _active.action_id:
		return "INVALID_ACTION_ID"
	return ""


func _update_terminal() -> void:
	if not _result.is_empty():
		return
	if _state.player_hp == 0:
		_result = "DEFEAT"
	elif _state.enemy_hp == 0:
		_result = "VICTORY"


func _response(status: String, reason: String = "") -> Dictionary:
	return {"status": status, "reason_code": reason}
