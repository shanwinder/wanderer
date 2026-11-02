extends RefCounted

# M1.6A-01: เก็บแผน Action ของหนึ่งรอบโดยไม่ผูกกับ Scene, Tween หรือ Sprite
# ผู้ควบคุม Combat เป็นผู้เรียก take_next_action() หลัง Animation แต่ละตัวจบ
const ACTOR_PLAYER: String = "player"
const ACTOR_NPC: String = "npc"
const ACTOR_ENEMY: String = "enemy"
const INTENT_ATTACK: String = "ATK"
const INTENT_GUARD: String = "GUARD"

var _actions: Array[Dictionary] = []
var _next_index: int = 0


func reset() -> void:
	_actions.clear()
	_next_index = 0


func plan_round(player_defending: bool, npc_count: int, enemy_target_id: String) -> void:
	reset()

	var player_intent: String = INTENT_ATTACK
	var player_target_id: String = enemy_target_id
	if player_defending:
		player_intent = INTENT_GUARD
		player_target_id = "player"
	_actions.append({
		"actor": ACTOR_PLAYER,
		"actor_index": 0,
		"intent": player_intent,
		"target_id": player_target_id
	})

	# กฎ NPC2 แบบเดิม: Player โจมตี -> NPC2 Guard; Player ตั้งรับ -> NPC2 ATK
	for i in range(maxi(0, npc_count)):
		var npc_intent: String = INTENT_ATTACK
		if i == 1 and not player_defending:
			npc_intent = INTENT_GUARD
		var npc_target_id: String = enemy_target_id
		if npc_intent == INTENT_GUARD:
			npc_target_id = "player"
		_actions.append({
			"actor": ACTOR_NPC,
			"actor_index": i,
			"intent": npc_intent,
			"target_id": npc_target_id
		})

	_actions.append({
		"actor": ACTOR_ENEMY,
		"actor_index": 0,
		"intent": INTENT_ATTACK,
		"target_id": "player"
	})


func take_next_action() -> Dictionary:
	if _next_index >= _actions.size():
		return {}

	var action: Dictionary = _actions[_next_index]
	_next_index += 1
	return action.duplicate()


func npc_intent_at(npc_index: int) -> String:
	for action in _actions:
		if action["actor"] == ACTOR_NPC and int(action["actor_index"]) == npc_index:
			return String(action["intent"])
	return ""


func pending_count() -> int:
	return maxi(_actions.size() - _next_index, 0)
