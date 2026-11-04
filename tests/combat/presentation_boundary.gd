extends SceneTree

# Real legacy scene, identical trace observer on the merged base and extracted code.
const Scene = preload("res://scenes/combat/combat_prototype.tscn")
var combat
var checks: int = 0
var failures: int = 0
var traces: Array = []
var safety: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _reset(target: String = "enemy_a") -> void:
	combat.restart_button.pressed.emit()
	for i in range(combat.target_picker.item_count):
		if combat.target_picker.get_item_metadata(i) == target:
			combat.target_picker.select(i)
			combat.target_picker.item_selected.emit(i)


func _state() -> Array:
	var state: Array = [combat.player_hp, combat.enemy_hp, combat.enemy_b_hp,
		combat.player_is_defending, combat.npc_guard_bonus, combat.turn_number,
		combat.turn_flow.pending_count(), combat.active_action_target_id,
		combat.active_enemy_id, combat.action_in_progress, combat.battle_is_over,
		combat.battle_result_player_won, combat.attack_button.disabled,
		combat.defend_button.disabled, combat.target_picker.disabled,
		combat.battle_result_panel.visible, combat.action_status_label.text,
		combat.combat_log.get_parsed_text(), combat.damage_popups.size(), combat.hit_sparks.size()]
	for node in [combat.player_root, combat.npc1_root, combat.npc2_root, combat.npc3_root,
		combat.enemy_root, combat.enemy_b_root, combat.player_sprite, combat.npc1_sprite,
		combat.npc2_sprite, combat.npc3_sprite, combat.enemy_sprite, combat.enemy_b_sprite,
		combat.player_label, combat.enemy_a_label, combat.enemy_b_label]:
		state.append([var_to_str(node.position), var_to_str(node.scale), var_to_str(node.modulate)])
	return state


func _homes() -> void:
	for pair in [[combat.player_root, Vector2(570, 465)], [combat.npc1_root, Vector2(320, 480)],
		[combat.npc2_root, Vector2(405, 435)], [combat.npc3_root, Vector2(475, 509)],
		[combat.enemy_root, Vector2(970, 506)], [combat.enemy_b_root, Vector2(1100, 424)]]:
		_check(pair[0].position == pair[1], "compact saved home")
	_check(combat.player_sprite.position == combat.player_sprite_base_position
		and combat.player_sprite.scale == combat.player_sprite_base_scale, "Player pose restored")
	_check(combat.enemy_b_sprite.scale == combat.enemy_b_sprite_base_scale, "B scale restored")


func _drain(frames: Array) -> void:
	for frame in range(900):
		frames.append(_state())
		if not combat.action_in_progress:
			_homes()
			return
		_check(combat.attack_button.disabled and combat.defend_button.disabled
			and combat.target_picker.disabled, "commands locked through return")
		await process_frame
	_check(false, "bounded real Tween completion")


func _trace_case(name: String, target: String, rounds: int, defend: bool = false,
	low_hp: bool = false, restart_at: String = "") -> void:
	_reset(target)
	if low_hp:
		combat.player_hp = 1 # Defeat fixture only; production balance is unchanged.
		combat._update_ui()
	var frames: Array = [_state()]
	for round_index in range(rounds):
		var button: Button = combat.defend_button if defend else combat.attack_button
		button.pressed.emit()
		if not restart_at.is_empty():
			for frame in range(120):
				frames.append(_state())
				if (restart_at == "windup" and frame == 5) or (restart_at == "impact" and combat.enemy_hp < 15):
					combat.restart_button.pressed.emit()
					break
				await process_frame
		await _drain(frames)
		# Let bound popup/result/HP-flash Tweens settle, observe all frames.
		for frame in range(125):
			frames.append(_state())
			await process_frame
	traces.append({"case": name, "frames": frames})
	print("TRACE: %s / %d frames" % [name, frames.size()])


func _wait_phase(phase: String) -> bool:
	for frame in range(120):
		if combat.presentation_adapter.phase == phase:
			return true
		await process_frame
	_check(false, "bounded Player boundary " + phase)
	return false


func _boundary_tests() -> void:
	var adapter = combat.presentation_adapter
	_check(combat.combat_speed_scale == 0.70 and combat.SHORT_LUNGE_DISTANCE == 44.0,
		"accepted speed/lunge")
	_check(combat.player_sprite.is_playing() and combat.player_sprite.animation == "idle", "Player idle still plays")
	for target in ["enemy_a", "enemy_b"]:
		_reset(target)
		combat.attack_button.pressed.emit()
		var epoch: int = adapter.visual_epoch
		var before: Array = _state()
		# Correct identity still cannot trigger damage/completion before the visual boundary.
		adapter._impact(epoch, "player", target)
		adapter._complete(epoch, "player", target)
		_check(_state() == before, "no early impact/completion")
		combat.target_picker.item_selected.emit(1 if target == "enemy_a" else 0)
		_check(combat.active_action_target_id == target and adapter.target_id == target, "locked target")
		# Observe at the callback itself: a frame observer may already see recoil advancing.
		var impact_capture: Array = []
		var legacy_hit: Callable = adapter._on_impact
		adapter._on_impact = func():
			impact_capture.append(combat.player_sprite.position)
			impact_capture.append(combat._enemy_hp_for(target))
			legacy_hit.call()
			impact_capture.append(combat._enemy_hp_for(target))
		if not await _wait_phase("IMPACT"):
			continue
		_check(combat._enemy_hp_for(target) == (10 if target == "enemy_a" else 7), "exact Player damage at impact")
		_check(combat.player_root.position == combat.player_home + Vector2(44, 0), "44px at strike")
		_check(impact_capture.size() == 3 and impact_capture[0] == combat.player_sprite_base_position + Vector2(14, 0)
			and impact_capture[1] == (15 if target == "enemy_a" else 12)
			and impact_capture[2] == (10 if target == "enemy_a" else 7), "strike pose and HP boundary inside callback")
		_check(combat.damage_popups.size() == 1 and combat.hit_sparks.size() == 1, "impact feedback once")
		_check(combat.active_enemy_label.modulate != Color.WHITE, "HP flash at impact")
		var after: Array = _state()
		for args in [[epoch, "player", target], [epoch - 1, "player", target],
			[epoch, "npc_01", target], [epoch, "player", "wrong_target"]]:
			adapter._impact(args[0], args[1], args[2])
			adapter._complete(args[0], args[1], args[2])
		_check(_state() == after, "duplicate/wrong/stale boundary cannot change HP/queue")
		await process_frame
		_check(combat.active_enemy_root.position.x > combat.active_enemy_home.x
			and combat.active_enemy_sprite.scale != combat.active_enemy_sprite_base_scale, "recoil/squash still runs")
		var frames: Array = []
		await _drain(frames)
		_check(combat._enemy_hp_for(target) == (8 if target == "enemy_a" else 5)
			and combat.player_hp == 25 and combat.turn_number == 2, "Legacy full round unchanged")
		var completed: Array = _state()
		adapter._impact(epoch, "player", target)
		adapter._complete(epoch, "player", target)
		_check(_state() == completed, "completion replay does not damage/advance")
		safety.append("impact/complete/identity/pose/recoil/feedback " + target)
	# Restart while all three portions of Player motion are active, for both identities.
	for target in ["enemy_a", "enemy_b"]:
		for boundary in ["windup", "impact", "return"]:
			_reset(target)
			combat.attack_button.pressed.emit()
			var epoch: int = adapter.visual_epoch
			var motion: Tween = combat.action_tween
			if boundary != "windup":
				await _wait_phase("IMPACT")
			if boundary == "return":
				for frame in range(18):
					await process_frame
			combat.restart_button.pressed.emit()
			_check(not motion.is_valid() and combat.action_tween == null, "Restart kills old Tween")
			var reset: Array = _state()
			adapter._impact(epoch, "player", target)
			adapter._complete(epoch, "player", target)
			for frame in range(150):
				await process_frame
			_check(_state() == reset and combat.damage_popups.is_empty() and combat.hit_sparks.is_empty(),
				"Restart leaves no stale HP/queue/motion/popup/flash")
			_homes()
			combat.attack_button.pressed.emit()
			var fresh: Array = _state()
			adapter._impact(epoch, "player", target)
			adapter._complete(epoch, "player", target)
			_check(_state() == fresh, "old epoch cannot affect fresh Player attack")
			var frames: Array = []
			await _drain(frames)
			_check(combat.turn_number == 2 and combat.player_hp == 25, "fresh queue completes once")
			safety.append("Restart " + target + " / " + boundary)

	# Restart inside the impact notification itself must also cancel later visual steps.
	_reset()
	combat.attack_button.pressed.emit()
	var legacy_hit: Callable = adapter._on_impact
	adapter._on_impact = func():
		legacy_hit.call()
		combat.restart_button.pressed.emit()
	for frame in range(180):
		await process_frame
	_check(combat.player_hp == 30 and combat.enemy_hp == 15 and combat.enemy_b_hp == 12
		and combat.turn_number == 1 and not combat.action_in_progress, "reentrant impact Restart")
	_homes()
	safety.append("Restart inside impact callback")
	# Lethal Player impact: result waits for return; Restart cancels the pending result.
	_reset()
	combat.enemy_hp = 5
	combat.enemy_b_hp = 0
	combat.target_registry.mark_enemy_defeated("enemy_b")
	combat._refresh_target_picker()
	combat._update_ui()
	combat.attack_button.pressed.emit()
	await _wait_phase("IMPACT")
	_check(combat.battle_is_over and not combat.battle_result_panel.visible
		and combat.action_in_progress, "lethal impact waits for return before result")
	combat.restart_button.pressed.emit()
	var reset: Array = _state()
	for frame in range(180):
		await process_frame
	_check(_state() == reset and not combat.battle_result_panel.visible, "Restart cancels lethal completion")
	safety.append("Restart after lethal impact")


func _run() -> void:
	combat = Scene.instantiate()
	root.add_child(combat)
	await process_frame
	await _trace_case("A-first victory", "enemy_a", 5)
	await _trace_case("B-first victory", "enemy_b", 4)
	await _trace_case("DEFEND", "enemy_a", 1, true)
	await _trace_case("defeat", "enemy_a", 1, false, true)
	await _trace_case("Restart windup", "enemy_a", 1, false, false, "windup")
	await _trace_case("Restart after impact", "enemy_a", 1, false, false, "impact")
	if not "--legacy-trace-only" in OS.get_cmdline_user_args():
		await _boundary_tests()
	combat.queue_free()
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "traces": traces, "safety": safety}))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
