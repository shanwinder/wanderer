extends SceneTree

# Run the real combat scene and its Tweens; no mocks, timing or balance overrides.
const COMBAT_SCENE = preload("res://scenes/combat/combat_prototype.tscn")
var combat
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _new_battle(target: String = "enemy_a") -> void:
	combat.restart_button.pressed.emit()
	for i in range(combat.target_picker.item_count):
		if combat.target_picker.get_item_metadata(i) == target:
			combat.target_picker.select(i)
			combat.target_picker.item_selected.emit(i)
			return
	_check(false, "target exists: " + target)


func _wait_until_idle() -> bool:
	var elapsed: float = 0.0
	while elapsed < 12.0:
		await process_frame
		elapsed += combat.get_process_delta_time()
		if combat.action_tween != null:
			_check(combat.action_in_progress, "busy throughout action Tween")
			_check(combat.attack_button.disabled and combat.defend_button.disabled
				and combat.target_picker.disabled, "commands locked until action finishes")
		if not combat.action_in_progress and combat.action_tween == null:
			if combat.battle_is_over or not combat.attack_button.disabled:
				return true
	_check(false, "round reaches idle/result within 12 simulated seconds")
	return false


func _round(defending: bool = false) -> bool:
	var before: int = combat.turn_number
	var button: Button = combat.defend_button if defending else combat.attack_button
	_check(not button.disabled, "command available before round")
	button.pressed.emit()
	_check(combat.action_in_progress, "command locks immediately")
	var pending: int = combat.turn_flow.pending_count()
	# Even direct duplicate signals must not replace the action already running.
	combat.attack_button.pressed.emit()
	combat.defend_button.pressed.emit()
	_check(combat.turn_flow.pending_count() == pending, "duplicate commands ignored")
	if not await _wait_until_idle():
		return false
	var expected_turn: int = before if combat.battle_is_over else before + 1
	_check(combat.turn_number == expected_turn, "exactly one round increment, none on result")
	_check(combat.turn_flow.pending_count() == 0, "queue drained/reset")
	await create_timer(2.0).timeout
	_check(combat.turn_number == expected_turn, "no delayed duplicate round completion")
	if combat.battle_is_over:
		_check(combat.attack_button.disabled and combat.defend_button.disabled
			and combat.target_picker.disabled, "commands stay locked after battle")
		_check(combat.battle_result_panel.visible, "result appears after final action")
	else:
		_check(not combat.attack_button.disabled and not combat.defend_button.disabled
			and not combat.target_picker.disabled, "commands unlocked after round")
		_check(combat.active_action_target_id == "" and not combat.player_is_defending,
			"round state cleared")
	return true


func _log_count(fragment: String) -> int:
	return combat.combat_log.get_parsed_text().count(fragment)


func _test_b_first() -> void:
	var before: int = failures
	_new_battle("enemy_b")
	if not await _round():
		return
	_check(combat.enemy_hp == 15 and combat.enemy_b_hp == 5 and combat.player_hp == 25,
		"attack B: player 5 + NPC1/3 1 each; guard blocks one hit by 1")
	if not await _round():
		return
	_check(combat.enemy_b_hp == 0 and combat.enemy_hp == 13 and combat.player_hp == 23,
		"B dies first; NPCs retarget A; only living A counters")
	_check(_log_count("Enemy A โจมตีกลับ") == 2 and _log_count("Enemy B โจมตีกลับ") == 1,
		"dead trailing B never counterattacks")
	_check(combat.target_picker.item_count == 1
		and combat.target_registry.selected_enemy_id() == "enemy_a", "picker selects survivor A")
	if not await _round():
		return
	_check(combat.enemy_hp == 6 and combat.player_hp == 21, "can play another round after B dies")
	if not await _round():
		return
	_check(combat.battle_is_over and combat.battle_result_player_won
		and combat.enemy_hp == 0 and combat.enemy_b_hp == 0, "B-first battle ends in victory")
	_check(combat.turn_number == 4 and combat.player_hp == 21, "victory adds no round/counterattack")
	print("%s: B-first progression, dead-tail skip, retarget, victory" % _result(before))


func _test_a_first() -> void:
	var before: int = failures
	_new_battle()
	for i in range(3):
		if not await _round():
			return
	_check(combat.enemy_hp == 0 and combat.enemy_b_hp == 10 and combat.player_hp == 18,
		"A dies first; living B still counters after skipped A")
	_check(_log_count("Enemy A โจมตีกลับ") == 2 and _log_count("Enemy B โจมตีกลับ") == 3,
		"dead A skipped without skipping live B")
	for i in range(2):
		if not await _round():
			return
	_check(combat.battle_is_over and combat.battle_result_player_won
		and combat.turn_number == 5 and combat.player_hp == 16, "A-first continuation and victory")
	print("%s: A-first progression, live B counter, victory" % _result(before))


func _test_rules() -> void:
	var before: int = failures
	_new_battle()
	if not await _round():
		return
	_check(combat.enemy_hp == 8 and combat.enemy_b_hp == 12 and combat.player_hp == 25,
		"Attack damage and single-use NPC2 guard unchanged")
	var log_text: String = combat.combat_log.get_parsed_text()
	var previous: int = -1
	for fragment in ["Player โจมตี", "NPC1 โจมตี", "NPC2 ป้องกัน", "NPC3 โจมตี",
		"Enemy A โจมตีกลับ", "Enemy B โจมตีกลับ"]:
		var index: int = log_text.find(fragment)
		_check(index > previous, "ordered action: " + fragment)
		previous = index
	_check(_log_count("NPC2 ช่วยลดความเสียหาย") == 1, "NPC2 guard consumed once")
	_new_battle()
	if not await _round(true):
		return
	_check(combat.enemy_hp == 12 and combat.enemy_b_hp == 12 and combat.player_hp == 28,
		"Defend: all three NPCs attack; each enemy deals 1")
	_check(_log_count("NPC2 โจมตี") == 1 and _log_count("NPC2 ป้องกัน") == 0,
		"NPC2 attacks on Defend")
	# A fixture exercises the existing minimum damage and defeat path.
	_new_battle()
	combat.player_hp = 1
	if not await _round(true):
		return
	_check(combat.battle_is_over and not combat.battle_result_player_won
		and combat.turn_number == 1 and combat.player_hp == 0, "defeat does not start another round")
	_check(_log_count("Enemy B โจมตีกลับ") == 0, "defeat cancels remaining counter")
	print("%s: Attack, Defend, NPC2 guard, damage, order, defeat" % _result(before))


func _test_restart() -> void:
	var before: int = failures
	for phase in ["Player: ATK", "NPC1: ATK", "NPC2: GUARD", "Enemy A: ATK", "Enemy B: ATK"]:
		_new_battle("enemy_b")
		combat.attack_button.pressed.emit()
		var elapsed: float = 0.0
		while not combat.action_status_label.text.contains(phase) and elapsed < 12.0:
			await process_frame
			elapsed += combat.get_process_delta_time()
		_check(combat.action_status_label.text.contains(phase), "reached restart phase " + phase)
		await create_timer(0.1).timeout
		_check(combat.action_tween != null, "restart during an active Tween: " + phase)
		_new_battle()
		await create_timer(12.0).timeout
		_check(combat.player_hp == 30 and combat.enemy_hp == 15 and combat.enemy_b_hp == 12
			and combat.turn_number == 1 and combat.turn_flow.pending_count() == 0
			and not combat.action_in_progress and combat.action_tween == null,
			"old queue stays cancelled after restart: " + phase)
		_check(not combat.attack_button.disabled and not combat.defend_button.disabled
			and not combat.target_picker.disabled and not combat.battle_result_panel.visible,
			"restart returns to command state: " + phase)
		if not await _round():
			return
		_check(combat.player_hp == 25 and combat.enemy_hp == 8 and combat.enemy_b_hp == 12,
			"fresh round unaffected by old callbacks: " + phase)
	print("%s: Restart during player/NPC attack/NPC guard/both enemy actions" % _result(before))


func _test_invalid_actions() -> void:
	var before: int = failures
	# Expected push_error messages are verified separately by the Python runner.
	for malformed in [{}, {"actor": "player", "target_id": "enemy_a"}]:
		_new_battle()
		combat.action_in_progress = true
		combat.attack_button.disabled = true
		combat.defend_button.disabled = true
		combat.target_picker.disabled = true
		combat.turn_flow._actions.append(malformed)
		combat._start_next_npc_action()
		_check(combat.turn_number == 1 and combat.attack_button.disabled,
			"malformed queued action is not normal exhaustion")
	_new_battle()
	combat._start_next_npc_action()
	_check(combat.turn_number == 1, "idle dispatch cannot add a round")
	combat.attack_button.pressed.emit()
	var pending: int = combat.turn_flow.pending_count()
	combat._start_next_npc_action()
	_check(combat.turn_flow.pending_count() == pending and combat.attack_button.disabled,
		"dispatch during animation cannot consume queue/unlock")
	await _wait_until_idle()
	combat._start_next_npc_action()
	_check(combat.turn_number == 2, "duplicate completion cannot add a second round")
	print("%s: malformed actions and invalid dispatch remain errors" % _result(before))


func _result(before: int) -> String:
	return "PASS" if failures == before else "FAIL"


func _run() -> void:
	combat = COMBAT_SCENE.instantiate()
	root.add_child(combat)
	_check(is_equal_approx(combat.combat_speed_scale, 0.70), "original combat speed")
	_check(is_equal_approx(combat.SHORT_LUNGE_DISTANCE, 44.0), "original lunge distance")
	if OS.get_cmdline_user_args().has("--invalid-actions"):
		await _test_invalid_actions()
	else:
		await _test_b_first()
		await _test_a_first()
		await _test_rules()
		await _test_restart()
	combat.restart_button.pressed.emit()
	combat.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
