extends SceneTree

const Scene = preload("res://scenes/npc/npc_autonomy_proof.tscn")
var checks: int = 0
var failures: int = 0
var scene


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _until_phase(expected: String) -> void:
	for frame in range(600):
		if scene.phase == expected:
			return
		await process_frame
	_check(false, "timeout awaiting " + expected + " actual " + scene.phase)


func _idle() -> void:
	for frame in range(600):
		if not scene.busy:
			return
		_check(scene.run_button.disabled and scene.scenario_picker.disabled, "commands locked during Tween")
		await process_frame
	_check(false, "turn finishes without hanging")


func _choose(index: int) -> void:
	scene.scenario_picker.item_selected.emit(index)
	_check(scene.scenario_index == index and not scene.busy, "scenario selected")


func _run() -> void:
	scene = Scene.instantiate()
	root.add_child(scene)
	await process_frame
	var cases: Array[Array] = [
		[0, "ATTACK", "enemy_a", "ATTACK_AVAILABLE_ENEMY", 17, 10, 9, 1],
		[1, "HELP", "player", "PLAYER_LOW_HP_HELP", 7, 10, 10, 0],
		[2, "DEFEND", "npc", "SELF_LOW_HP_THREAT", 20, 2, 10, 1],
		[3, "ATTACK", "enemy_a", "HELP_UNAVAILABLE_ATTACK", 3, 10, 9, 0],
		[4, "HELP", "player", "PLAYER_LOW_HP_HELP", 7, 10, 10, 0],
		[5, "DEFEND", "npc", "SELF_LOW_HP_THREAT", 6, 2, 10, 1]
	]
	for case in cases:
		var before_failures: int = failures
		_choose(case[0])
		scene.run_button.pressed.emit()
		var locked: Dictionary = scene.token.duplicate(true)
		var generation: int = scene.epoch
		_check(locked.decision.action == case[1] and locked.decision.target_id == case[2]
			and locked.decision.reason_code == case[3], "scenario decision/target/reason")
		_check(scene.decision_label.text.contains(case[1]) and scene.decision_label.text.contains(case[2])
			and scene.decision_label.text.contains(scene.REASONS[case[3]]), "visible action/target/reason bound")
		_check(scene.log_label.get_parsed_text().contains(case[3]), "reason_code logged")
		scene.run_button.pressed.emit()
		_check(scene.token == locked, "duplicate input keeps locked decision")
		# At the real impact boundary, assert intermediate HELP HP and distinct feedback.
		for frame in range(200):
			if scene.encounter.inspect().active.resolved:
				break
			await process_frame
		var impact: Dictionary = scene.encounter.inspect()
		_check(impact.active.resolved and not impact.active.completed, "real Tween effect before completion")
		_check(scene.feedback.text.contains(case[1]), "action feedback visible")
		if case[1] == "HELP":
			_check(impact.state.player_hp == 10 and impact.state.help_uses_remaining == 0,
				"HELP 6 to 10 before enemy response")
			_check(scene.actors.player.modulate != Color.WHITE, "HELP visual")
		if case[1] == "ATTACK":
			_check(is_equal_approx(scene.actors.npc.position.x, scene.HOMES.npc.x + 44.0), "44px lunge")
		if case[1] == "DEFEND":
			_check(impact.self_defend and scene.actors.npc.modulate != Color.WHITE, "DEFEND visual and state")
		scene._npc_impact(generation, locked)
		_check(scene.encounter.inspect() == impact, "duplicate impact is inert")
		await _idle()
		var actual: Dictionary = scene.encounter.inspect()
		_check([actual.state.player_hp, actual.state.npc_hp, actual.state.enemy_hp,
			actual.state.help_uses_remaining] == [case[4], case[5], case[6], case[7]], "exact HP/resource outcomes")
		_check(actual.round == 2 and actual.round_completions == 1 and actual.pending.is_empty(), "one round, drained queue")
		_check(scene.hp_labels.player.text.contains("HP %d/30" % case[4])
			and scene.state_label.text.contains("HELP remaining %d" % case[7]), "UI reflects encounter")
		for id in scene.HOMES:
			_check(scene.actors[id].position == scene.HOMES[id], "return home " + id)
		scene._enemy_impact(generation, locked)
		scene._finish(generation, locked)
		_check(scene.encounter.inspect() == actual, "duplicate completion/counter inert")
		print("CASE " + scene.PRESETS[case[0]].name + ": " + ("PASS" if failures == before_failures else "FAIL"))

	# Restart every action before effect, after effect, enemy windup and enemy settling.
	for index in [0, 1, 2]:
		for boundary in ["windup", "effect", "enemy", "settling"]:
			_choose(index)
			scene.run_turn()
			var old: Dictionary = scene.token.duplicate(true)
			var old_epoch: int = scene.epoch
			if boundary == "effect":
				while not scene.encounter.inspect().active.resolved:
					await process_frame
			elif boundary == "enemy":
				await _until_phase("ENEMY_RESPONSE")
			elif boundary == "settling":
				await _until_phase("SETTLING")
			scene.restart_scenario()
			var reset: Dictionary = scene.encounter.inspect()
			var ui: Array = [scene.feedback.text, scene.decision_label.text, scene.log_label.get_parsed_text(), scene.state_label.text]
			# Explicit stale callbacks and enough engine time for any abandoned Tween.
			scene._npc_impact(old_epoch, old)
			scene._enemy_start(old_epoch, old)
			scene._enemy_impact(old_epoch, old)
			scene._finish(old_epoch, old)
			await create_timer(5.0).timeout
			_check(scene.encounter.inspect() == reset, "restart stable " + boundary)
			_check([scene.feedback.text, scene.decision_label.text, scene.log_label.get_parsed_text(), scene.state_label.text] == ui,
				"stale callbacks cannot mutate UI " + boundary)
			_check(not scene.busy and not scene.run_button.disabled, "restart unlocks")
			scene.run_turn()
			await _idle()
			_check(scene.encounter.inspect().round_completions == 1, "fresh turn after restart")
	print("CASE restart all actions / enemy response: complete")

	# Inject races through the existing fixture seam, never through presentation HP math.
	_choose(0)
	scene.run_turn()
	scene.encounter.apply_fixture_change({"enemy_hp": 0})
	await _idle()
	_check(scene.encounter.inspect().result == "VICTORY" and scene.encounter.inspect().state.player_hp == 20,
		"invalidated attack target skips safely without enemy damage")
	_check(scene.encounter.inspect().pending.is_empty() and scene.encounter.inspect().round_completions == 0,
		"terminal skip drains queue without another round")
	_check(scene.log_label.get_parsed_text().contains("TARGET_DEAD_BEFORE_RESOLVE"), "skip reason logged")
	_choose(0)
	scene.encounter.apply_fixture_change({"enemy_hp": 1})
	scene.run_turn()
	await _idle()
	_check(scene.phase == "VICTORY" and scene.run_button.disabled, "killing blow locks terminal scene")
	_choose(3)
	scene.encounter.apply_fixture_change({"player_hp": 2})
	scene.run_turn()
	await _idle()
	_check(scene.phase == "DEFEAT" and scene.encounter.inspect().state.player_hp == 0, "enemy causes defeat")
	var terminal: Dictionary = scene.encounter.inspect()
	scene.run_turn()
	_check(scene.encounter.inspect() == terminal and scene.run_button.disabled, "no new turn after defeat")
	_choose(0)
	scene.encounter.apply_fixture_change({"npc_hp": 0})
	scene.run_turn()
	await _idle()
	_check(scene.encounter.inspect().round_completions == 1, "unavailable actor SKIP finishes")
	# Actual second turn must not reuse HELP.
	_choose(1)
	scene.run_turn()
	await _idle()
	scene.run_turn()
	_check(scene.token.decision.reason_code == "HELP_UNAVAILABLE_ATTACK", "second turn no HELP reuse")
	await _idle()
	_check(scene.encounter.inspect().state.help_uses_remaining == 0, "resource never negative")
	scene.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
