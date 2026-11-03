extends SceneTree

const Scene = preload("res://scenes/combat/full_party_proof.tscn")
var scene
var checks: int = 0
var failures: int = 0
var events: Array = []
var seen: Dictionary = {}
var cases: Array = []
var case_start: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _observe() -> void:
	var view: Dictionary = scene.encounter.snapshot()
	for id in scene.HOMES:
		_check(scene.hp_labels[id].text.contains("HP %d/%d" % [view.actors[id].current_hp, view.actors[id].max_hp]), "HUD HP " + id)
		if view.help_uses.has(id):
			_check(scene.hp_labels[id].text.contains("HELP %d" % view.help_uses[id]), "HUD HELP " + id)
		_check(scene.hp_labels[id].text.contains("GUARD") == view.guards.has(id), "HUD Guard " + id)
	if scene.busy:
		_check(scene.attack_button.disabled and scene.defend_button.disabled and scene.target_picker.disabled
			and scene.scenario_picker.disabled and not scene.restart_button.disabled, "all commands locked, Restart available")
	if not scene.token.is_empty():
		var d: Dictionary = scene.token.decision
		_check(scene.decision_label.text.contains(d.actor_id) and scene.decision_label.text.contains(d.action)
			and scene.decision_label.text.contains(d.target_id if not d.target_id.is_empty() else "none") and scene.decision_label.text.contains(d.reason_code)
			and scene.decision_label.text.contains(scene.REASONS[d.reason_code]), "visible locked decision identity/action/target/reason")
		var key: String = "%d/%d" % [scene.epoch, scene.token.action_id]
		if not seen.has(key):
			seen[key] = true
			events.append({"token": scene.token.duplicate(true), "at_lock": view.duplicate(true)})
		if scene.phase == "IMPACT" and not events[-1].has("effect"):
			events[-1]["effect"] = view.locked_action.effect.duplicate(true)
			events[-1]["after_effect"] = view.duplicate(true)
			var effect: Dictionary = view.locked_action.effect
			_check(scene.feedback.text.contains("HP %+d" % effect.hp_delta), "feedback actual delta")
			if d.action == "ATTACK":
				_check(is_equal_approx(absf(scene.actors[d.actor_id].position.x - scene.HOMES[d.actor_id].x), 44.0), "44px each attacking actor")
			if effect.hp_delta != 0:
				_check(scene.popups[d.target_id].position.y >= 318, "popup separated from reason/feedback rows")


func _wait(actor: String, expected_phase: String) -> bool:
	for frame in range(1400):
		_observe()
		if scene.token.get("actor_id", "") == actor and scene.phase == expected_phase:
			return true
		if not scene.busy:
			break
		await process_frame
	_check(false, "timeout waiting " + actor + " / " + expected_phase + " actual " + scene.phase)
	return false


func _idle() -> void:
	for frame in range(1600):
		_observe()
		if not scene.busy:
			return
		await process_frame
	_check(false, "timeout draining actual scene Tweens")


func _choose(index: int) -> void:
	scene.scenario_picker.item_selected.emit(index)
	_check(scene.scenario_index == index and not scene.busy, "choose preset")
	events.clear()
	seen.clear()
	case_start = failures


func _record(name: String, expected: String) -> void:
	var record: Dictionary = {"name": name, "status": "PASS" if failures == case_start else "FAIL",
		"expected": expected, "actual": scene.encounter.snapshot(), "actions": events.duplicate(true)}
	cases.append(record)
	print("CASE %s: %s" % [name, record.status])


func _home() -> void:
	for id in scene.HOMES:
		_check(scene.actors[id].position == scene.HOMES[id], "saved home " + id)
		_check(scene.actors[id].modulate == Color.WHITE and scene.actors[id].rotation == 0, "no stale flash/rotation " + id)
		_check(scene.popups[id].text.is_empty() and scene.popups[id].position == scene.HOMES[id] + Vector2(-80, 8), "no stale popup " + id)
		_check(scene.actors[id].self_modulate == (Color.WHITE if scene.encounter.actor_snapshot(id).can_act else Color("777777")), "availability tint from fresh snapshot")


func _action_ids() -> Array:
	var ids: Array = []
	for event in events:
		ids.append(event.token.actor_id)
	return ids


func _normal_and_controls() -> void:
	_choose(0)
	_check(scene.actors.size() == 6 and scene.hp_labels.size() == 6 and scene.intent_labels.size() == 3, "complete roster UI")
	_check(root.content_scale_size == Vector2i(1280, 720), "project 1280x720")
	for id in scene.intent_labels:
		_check(scene.intent_labels[id].text.contains("Waiting to decide"), "no early intent")
	# Tampered picker metadata is rejected without invoking a combat round.
	var before: Dictionary = scene.encounter.snapshot()
	scene.target_picker.set_item_metadata(0, "npc_01")
	scene.attack_button.pressed.emit()
	_check(scene.encounter.snapshot() == before and not scene.busy, "picker rejects invalid membership")
	scene.target_picker.select(1)
	scene.attack_button.pressed.emit()
	_check(scene.token.decision.target_id == "enemy_b", "Player target picker B")
	var locked: Dictionary = scene.token.duplicate(true)
	scene.attack_button.pressed.emit()
	scene.defend_button.pressed.emit()
	scene.scenario_picker.item_selected.emit(2)
	_check(scene.token == locked and scene.scenario_index == 0, "reentrant commands and scenario ignored")
	if await _wait("player", "IMPACT"):
		_check(is_equal_approx(scene.actors.player.position.x, scene.HOMES.player.x + 44), "44px player lunge")
		_check(scene.encounter.actor_snapshot("enemy_b").current_hp == 7, "damage exactly at impact")
	await _idle()
	_check(_action_ids() == ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"], "one full six actor queue")
	var after: Dictionary = scene.encounter.snapshot()
	_check(after.actors.player.current_hp == 24 and after.actors.enemy_a.current_hp == 12
		and after.actors.enemy_b.current_hp == 7, "normal exact HP")
	_check(after.round_completions == 1 and after.round_id == 2 and after.pending.is_empty(), "one round completion")
	_check(not scene.attack_button.disabled and scene.phase == "READY", "ready only after return")
	_home()
	await create_timer(2.0).timeout
	_check(scene.encounter.snapshot() == after, "idle cannot complete round twice")
	_record("I1 full party ATTACK / target UI / locks / homes", "Player attacks B -5; NPCs attack A -3; A/B each hit Player -3; round2 once")


func _help_and_guard() -> void:
	for preset in [1, 2, 3]:
		_choose(preset)
		scene.defend_button.pressed.emit()
		if await _wait("npc_01", "WINDUP"):
			_check(scene.intent_labels.npc_02.text.contains("Waiting to decide")
				and scene.intent_labels.npc_03.text.contains("Waiting to decide"), "NPC2/3 have no final intent before slot")
		await _idle()
		_check(_action_ids().size() == 6, "six separate slots")
		var view: Dictionary = scene.encounter.snapshot()
		if preset == 1:
			_check(events[1].token.decision.action == "HELP" and events[1].effect.hp_delta == 4, "NPC1 HELP")
			_check(events[2].at_lock.actors.player.current_hp == 10 and events[2].token.decision.action == "ATTACK"
				and events[3].token.decision.action == "ATTACK", "NPC2/3 read fresh HP10")
			_check(view.actors.player.current_hp == 8 and view.help_uses == {"npc_01": 0, "npc_02": 1, "npc_03": 1}, "HELP once / player guard each hit")
		elif preset == 2:
			_check(events[1].token.decision.action == "DEFEND" and events[1].after_effect.guards.has("npc_01"), "self guard at impact")
			_check(events[4].effect.hp_delta == -1 and view.actors.npc_01.current_hp == 2, "NPC guard reduces hit3 to1")
			_check(view.actors.player.current_hp == 29 and view.guards.is_empty(), "Player guard hit / end round expiration")
		else:
			for i in [1, 2, 3]:
				_check(events[i].token.decision.action == "HELP" and events[i].effect.hp_delta == 4, "three independent HELP")
			_check(view.actors.player.current_hp == 11 and view.help_uses == {"npc_01": 0, "npc_02": 0, "npc_03": 0}, "three HELP resources spent once")
		_home()
		_record("I2 preset %d HELP/DEFEND" % preset, "NPC decisions use fresh HP; HELP4 once/NPC; guard reduces3 to1")


func _skips_and_terminal() -> void:
	_choose(4)
	scene.attack_button.pressed.emit()
	await _idle()
	_check(events[1].token.decision.target_id == "enemy_b", "NPC chooses surviving B before lock")
	_check(events[4].token.decision.action == "SKIP" and events[4].effect.hp_delta == 0, "dead A no effect")
	_check(events[5].token.actor_id == "enemy_b" and events[5].effect.hp_delta == -3, "B independent live slot")
	_check(scene.encounter.actor_snapshot("player").current_hp == 27, "only B counters")
	_record("I3 A defeated B alive", "NPCs target B; A SKIP; B still attacks; Player27")
	_choose(7)
	_check(scene.target_picker.item_count == 1 and scene.target_picker.get_item_metadata(0) == "enemy_b", "dead target excluded")
	scene.attack_button.pressed.emit()
	await _idle()
	_check(events[1].token.decision.action == "SKIP" and events[1].effect.hp_delta == 0, "dead NPC no effect")
	_record("I4 unavailable NPC/enemy slots", "NPC1 and A SKIP; target picker only B")
	for preset in [5, 6]:
		_choose(preset)
		scene.attack_button.pressed.emit()
		await _idle()
		var view: Dictionary = scene.encounter.snapshot()
		_check(scene.phase == ("VICTORY" if preset == 5 else "DEFEAT"), "terminal result presented")
		_check(not view.round_running and view.pending.is_empty() and not view.active_action
			and scene.attack_button.disabled and scene.defend_button.disabled, "terminal queue stopped / commands locked")
		scene.player_command("ATTACK")
		_check(scene.encounter.snapshot() == view, "no round after terminal")
		_home()
		scene.restart_button.pressed.emit()
		_check(scene.phase == "READY" and not scene.busy and not scene.attack_button.disabled, "restart terminal unlocks")
		_record("I5 terminal restart %d" % preset, "terminal stops; Restart restores ready")

	for preset in [5, 6]:
		for boundary in ["IMPACT", "SETTLING"]:
			_choose(preset)
			scene.attack_button.pressed.emit()
			if await _wait("player" if preset == 5 else "enemy_a", boundary):
				_check(not scene.encounter.snapshot().result.is_empty(), "terminal exists before presentation completion")
				scene.restart_button.pressed.emit()
				var reset: Dictionary = scene.encounter.snapshot()
				await create_timer(2.0).timeout
				_check(scene.encounter.snapshot() == reset and not scene.busy and scene.phase == "READY", "Restart during terminal presentation")
				_home()
			_record("I5 terminal boundary %d / %s" % [preset, boundary], "Restart before terminal completion cancels old effect/queue/visuals")


func _duplicate_and_forged_callbacks() -> void:
	_choose(1)
	scene.defend_button.pressed.emit()
	if not await _wait("npc_01", "WINDUP"):
		return
	var locked: Dictionary = scene.token.duplicate(true)
	var before: Dictionary = scene.encounter.snapshot()
	scene._finish(scene.epoch, locked)
	scene._settle(scene.epoch, locked)
	for key in ["actor_id", "generation", "action_id", "encounter_id", "round_id", "decision"]:
		var forged: Dictionary = locked.duplicate(true)
		if key == "decision":
			forged.decision.action = "ATTACK"
		elif key == "actor_id":
			forged[key] = "npc_02"
		else:
			forged[key] += 1
		scene._impact(scene.epoch, forged)
	scene._impact(scene.epoch - 1, locked)
	_check(scene.encounter.snapshot() == before, "wrong identity/epoch/phase callbacks inert")
	if await _wait("npc_01", "IMPACT"):
		var after: Dictionary = scene.encounter.snapshot()
		scene._impact(scene.epoch, locked)
		_check(scene.encounter.snapshot() == after and after.actors.player.current_hp == 10
			and after.help_uses.npc_01 == 0, "duplicate impact no HP/resource reuse")
	if await _wait("npc_01", "SETTLING"):
		# Let real Tween complete, then replay its completion against the next actor.
		var old_epoch: int = scene.epoch
		await _wait("npc_02", "WINDUP")
		var next: Dictionary = scene.encounter.snapshot()
		scene._finish(old_epoch, locked)
		_check(scene.encounter.snapshot() == next, "duplicate completion cannot advance next slot")
	await _idle()
	_record("I6 duplicate / forged callbacks", "wrong phase/identity/epoch rejected; effect and completion once")


func _restart_boundaries() -> void:
	for actor in ["player", "npc_01", "enemy_a", "enemy_b"]:
		for boundary in ["WINDUP", "IMPACT", "SETTLING"]:
			_choose(1)
			scene.defend_button.pressed.emit()
			if not await _wait(actor, boundary):
				continue
			var locked: Dictionary = scene.token.duplicate(true)
			var old_epoch: int = scene.epoch
			var old_motion: Tween = scene.motion
			scene.restart_button.pressed.emit()
			_check(scene.epoch == old_epoch + 1 and not old_motion.is_valid() and scene.motion == null, "epoch increments / Tween killed")
			var reset: Dictionary = scene.encounter.snapshot()
			var ui: Array = [scene.feedback.text, scene.decision_label.text, scene.log_label.text, scene.state_label.text]
			for replay_epoch in [old_epoch, scene.epoch]:
				scene._impact(replay_epoch, locked)
				scene._settle(replay_epoch, locked)
				scene._finish(replay_epoch, locked)
			await create_timer(2.0).timeout
			_check(scene.encounter.snapshot() == reset and scene.token.is_empty() and not scene.busy, "stale data callbacks after restart " + actor + boundary)
			_check([scene.feedback.text, scene.decision_label.text, scene.log_label.text, scene.state_label.text] == ui, "stale UI callbacks after restart")
			_home()
			# Replay old callbacks during a new active slot too (action IDs repeat).
			scene.defend_button.pressed.emit()
			var fresh: Dictionary = scene.encounter.snapshot()
			scene._impact(scene.epoch, locked)
			scene._settle(old_epoch, locked)
			scene._finish(old_epoch, locked)
			_check(scene.encounter.snapshot() == fresh, "old generation cannot affect fresh action")
			await _idle()
			_check(scene.encounter.snapshot().round_completions == 1, "fresh round after restart once")
			_record("I7 restart " + actor + " / " + boundary, "kill Tween; no old HP/HELP/queue/UI; fresh six-slot round completes once")


func _effect_races_and_threshold() -> void:
	# TEST ONLY white-box interruptions model concurrent changes absent from playable controls.
	# Production controller never touches Registry or mutates gameplay during a slot.
	for race in ["target_dead", "actor_dead", "enemy_dead", "enemy_target_dead", "help_threshold", "help_full"]:
		_choose(2 if race == "enemy_target_dead" else (1 if race.begins_with("help") else 0))
		scene.defend_button.pressed.emit()
		var actor: String = "enemy_a" if race.begins_with("enemy") else "npc_01"
		if not await _wait(actor, "WINDUP"):
			continue
		var target: String = scene.token.decision.target_id
		if race == "help_threshold":
			scene.encounter._registry.fixture_heal("player", 5)
		elif race == "help_full":
			scene.encounter._registry.fixture_heal("player", 30)
		elif race == "actor_dead" or race == "enemy_dead":
			scene.encounter._registry.fixture_damage(actor, 100)
		elif race == "enemy_target_dead":
			# S3 declares NPC1 before begin_round; invalidate only after lock.
			target = "npc_01"
			scene.encounter._registry.fixture_damage(target, 100)
		else:
			scene.encounter._registry.fixture_damage(target, 100)
		scene._refresh()
		var other_hp: int = scene.encounter.actor_snapshot("enemy_b").current_hp
		if await _wait(actor, "IMPACT"):
			var view: Dictionary = scene.encounter.snapshot()
			var effect: Dictionary = view.locked_action.effect
			if race == "help_threshold":
				_check(view.actors.player.current_hp == 15 and effect.hp_delta == 4 and view.help_uses.npc_01 == 0,
					"HELP threshold decision-time only: lock6 / before11 / after15")
			elif race == "help_full":
				_check(effect.status == "SKIP" and effect.reason_code == "HELP_UNAVAILABLE" and view.help_uses.npc_01 == 1, "full HP HELP skips without consuming")
			else:
				_check(effect.status == "SKIP" and effect.hp_delta == 0, "unavailable actor/target no effect")
				_check(scene.encounter.actor_snapshot("enemy_b").current_hp == other_hp, "no retarget after lock")
				_check(scene.feedback.text.contains("HP +0"), "SKIP has no fabricated hit")
		await _idle()
		_record("I8 impact race / " + race, "after-lock invalidation SKIP without retarget; HELP threshold decision-time, full HP skips")


func _run() -> void:
	scene = Scene.instantiate()
	root.add_child(scene)
	await process_frame
	await _normal_and_controls()
	await _help_and_guard()
	await _skips_and_terminal()
	await _duplicate_and_forged_callbacks()
	await _restart_boundaries()
	await _effect_races_and_threshold()
	scene.queue_free()
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
