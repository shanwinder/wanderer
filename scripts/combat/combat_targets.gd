extends RefCounted

# M1.6B-01: รายชื่อเป้าหมายฝ่ายศัตรู แยกจาก UI และ Animation
# ลงทะเบียนศัตรู 2 ตัวที่มี ID ต่างกัน
const ENEMY_A_ID: String = "enemy_a"
const ENEMY_B_ID: String = "enemy_b"
const PLAYER_ID: String = "player"

var _enemies: Array[Dictionary] = []
var _selected_enemy_id: String = ""


func reset() -> void:
	_enemies.clear()
	_selected_enemy_id = ""


func register_enemy(enemy_id: String, display_name: String) -> void:
	if enemy_id.is_empty():
		return
	for enemy in _enemies:
		if String(enemy["id"]) == enemy_id:
			return
	_enemies.append({"id": enemy_id, "name": display_name, "alive": true})
	if _selected_enemy_id.is_empty():
		_selected_enemy_id = enemy_id


func available_enemy_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for enemy in _enemies:
		if bool(enemy["alive"]):
			targets.append(enemy.duplicate())
	return targets


func available_enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	for enemy in _enemies:
		if bool(enemy["alive"]):
			ids.append(String(enemy["id"]))
	return ids


func first_available_enemy_id() -> String:
	var ids: Array[String] = available_enemy_ids()
	if ids.is_empty():
		return ""
	return ids[0]


func is_enemy_available(enemy_id: String) -> bool:
	for enemy in _enemies:
		if String(enemy["id"]) == enemy_id:
			return bool(enemy["alive"])
	return false


func select_enemy(enemy_id: String) -> bool:
	if not is_enemy_available(enemy_id):
		return false
	_selected_enemy_id = enemy_id
	return true


func selected_enemy_id() -> String:
	if is_enemy_available(_selected_enemy_id):
		return _selected_enemy_id
	return ""


func mark_enemy_defeated(enemy_id: String) -> void:
	for enemy in _enemies:
		if String(enemy["id"]) == enemy_id:
			enemy["alive"] = false
			if _selected_enemy_id == enemy_id:
				_selected_enemy_id = first_available_enemy_id()
			return
