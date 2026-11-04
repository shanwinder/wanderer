extends SceneTree

const OptIn = preload("res://scenes/combat/combat_autonomous_optin.tscn")
const Legacy = preload("res://scenes/combat/combat_prototype.tscn")
var scene
var checks: int = 0
var failures: int = 0
var events: Array = []
var seen: Dictionary = {}
var cases: Array = []
var case_start: int = 0
var legacy_differential: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _record(name: String, expected: String) -> void:
	cases.append({"scenario": name, "expected": expected,
		"actual": "PASS" if failures == case_start else "FAIL", "failures": failures - case_start,
		"final_snapshot": scene.encounter.snapshot(), "action_trace": events.duplicate(true)})
	print("CASE: %s / %s" % [name, cases.back().actual])
	case_start = failures


func _choose(index: int = 0, target: String = "enemy_a") -> void:
	scene.autonomous_scenario = index # Test fixture selection, followed by a NEW battle.
	scene.restart_button.pressed.emit()
	events.clear()
	seen.clear()
	for i in range(scene.target_picker.item_count):
		if scene.target_picker.get_item_metadata(i) == target:
			scene.target_picker.select(i)
			scene.target_picker.item_selected.emit(i)


func _observe() -> void:
	var view: Dictionary = scene.encounter.snapshot()
	_check(scene.turn_flow == null and scene.target_registry == null, "no Legacy queue or target registry")
	_check(scene.player_hp == null and scene.enemy_hp == null and scene.enemy_b_hp == null, "no Legacy HP mirror")
	for id in scene.autonomous_hp_labels:
		var label: Label = scene.autonomous_hp_labels[id]
		_check(label.is_visible_in_tree(), "HUD visible " + id)
		_check(label.get_global_rect().end.y <= 720, "HUD inside viewport " + id)
		_check(label.text.contains("HP: %d / %d" % [view.actors[id].current_hp, view.actors[id].max_hp]), "snapshot HUD " + id)
		_check(label.text.contains("GUARD") == view.guards.has(id), "snapshot guard " + id)
		if view.help_uses.has(id):
			_check(label.text.contains("HELP %d" % view.help_uses[id]), "snapshot HELP " + id)
	if scene.action_in_progress:
		_check(scene.attack_button.disabled and scene.defend_button.disabled and scene.target_picker.disabled
			and scene.autonomous_scenario_picker.disabled and not scene.restart_button.disabled, "controls locked / Restart available")
	if scene.autonomous_token.is_empty():
		return
	var locked: Dictionary = scene.autonomous_token
	var d: Dictionary = locked.decision
	var key: String = "%d/%d" % [locked.generation, locked.action_id]
	if not seen.has(key):
		seen[key] = events.size()
		events.append({"token": locked.duplicate(true), "at_lock": view.duplicate(true)})
	var event: Dictionary = events[seen[key]]
	_check(scene.autonomous_decision_label.text.contains(d.actor_id)
		and scene.autonomous_decision_label.text.contains(d.action)
		and scene.autonomous_decision_label.text.contains(d.target_id if not d.target_id.is_empty() else "none")
		and scene.autonomous_decision_label.text.contains(d.reason_code)
		and scene.autonomous_decision_label.text.contains(scene.AUTONOMOUS_REASONS[d.reason_code]), "visible locked reason")
	if view.locked_action.has("effect") and not event.has("effect"):
		event["effect"] = view.locked_action.effect.duplicate(true)
		event["after_effect"] = view.duplicate(true)
		_check(scene.autonomous_effect_label.text.contains("HP %+d" % event.effect.hp_delta), "actual effect caption")
		if d.action == "ATTACK":
			_check(is_equal_approx(absf(scene.autonomous_views[d.actor_id].root.position.x
				- scene.autonomous_views[d.actor_id].home.x), 44), "44px impact lunge " + d.actor_id)
		if event.effect.status == "SKIP":
			_check(event.effect.hp_delta == 0, "SKIP zero delta")


func _wait(actor: String, phase: String) -> bool:
	for frame in range(1100):
		_observe()
		if scene.autonomous_token.get("actor_id", "") == actor and scene.presentation_adapter.phase == phase:
			return true
		if not scene.action_in_progress:
			break
		await process_frame
	_check(false, "timeout " + actor + " / " + phase + " actual " + scene.presentation_adapter.phase)
	return false


func _idle() -> void:
	for frame in range(1200):
		_observe()
		if not scene.action_in_progress:
			return
		await process_frame
	_check(false, "round completion timeout")


func _home() -> void:
	for id in scene.autonomous_views:
		var actor: Dictionary = scene.autonomous_views[id]
		_check(actor.root.position == actor.home and actor.sprite.position == actor.sprite_home
			and actor.sprite.scale == actor.scale, "saved home/pose/scale " + id)
		_check(actor.sprite.modulate == (actor.tint if scene.encounter.actor_snapshot(id).can_act else Color(0.42, 0.42, 0.42)), "rest tint " + id)


func _ids() -> Array:
	var ids: Array = []
	for event in events:
		ids.append(event.token.actor_id)
	return ids


func _startup_and_differential() -> void:
	_check(scene.session_mode == scene.SessionMode.AUTONOMOUS and scene.encounter != null, "inherited mode before initialization")
	for id in ["npc_01", "npc_02", "npc_03"]:
		_check(scene.encounter.actor_snapshot(id).current_hp == 10 and scene.encounter.actor_snapshot(id).max_hp == 10, "approved NPC full HP")
		_check(scene.autonomous_intents[id].text.contains("Waiting to decide"), "waiting before slot " + id)
	_check(scene.combat_speed_scale == 0.70 and scene.SHORT_LUNGE_DISTANCE == 44.0, "Main motion settings")
	_check(scene.player_sprite.is_playing() and scene.player_sprite.animation == "idle", "Main Player idle")
	_check(scene.battlefield.y_sort_enabled, "Main depth")
	for id in scene.autonomous_views:
		_check(scene.autonomous_views[id].root.get_child(0) is Polygon2D, "Main contact shadow " + id)
	_check(scene.enemy_b_sprite.scale == Vector2(2.1, 2.1) and scene.enemy_b_sprite.modulate == scene.enemy_b_base_tint, "Enemy B identity")
	_check(root.content_scale_size == Vector2i(1280, 720), "1280x720")
	_check(scene.restart_button.get_global_rect().end.y <= 720, "commands inside viewport")
	_check(scene.battle_result_panel.z_index > scene.autonomous_intents.npc_03.z_index, "terminal panel above reason rows")
	_home()
	_observe()
	_record("S01 opt-in startup / S22 Main presentation structure", "Inherited Main scene; six original actors/idle/shadows/depth/B; full NPC HP; visual quality needs owner F6")
	var legacy = Legacy.instantiate()
	root.add_child(legacy)
	await process_frame
	_check(legacy.session_mode == legacy.SessionMode.LEGACY and legacy.encounter == null
		and legacy.turn_flow != null and legacy.target_registry != null, "default isolated Legacy authority")
	_check(load(ProjectSettings.get_setting("application/run/main_scene")) == Legacy, "project default remains Legacy")
	# Session mode cannot be toggled in a running battle.
	scene.session_mode = scene.SessionMode.LEGACY
	legacy.session_mode = legacy.SessionMode.AUTONOMOUS
	_check(scene.session_mode == scene.SessionMode.AUTONOMOUS and legacy.session_mode == legacy.SessionMode.LEGACY, "mode immutable during session")
	_record("S02 default Main scene / S20 isolation", "Legacy initializes only Legacy; opt-in initializes only Encounter; live switching ignored")
	for row in [["ATTACK", "enemy_a", [25, 8, 12], [24, 7, 12]],
		["ATTACK", "enemy_b", [25, 15, 5], [24, 12, 7]], ["DEFEND", "enemy_a", [28, 12, 12], [28, 12, 12]]]:
		_choose(0, row[1])
		legacy.restart_button.pressed.emit()
		legacy.target_picker.select(1 if row[1] == "enemy_b" else 0)
		legacy.target_picker.item_selected.emit(legacy.target_picker.selected)
		(legacy.attack_button if row[0] == "ATTACK" else legacy.defend_button).pressed.emit()
		(scene.attack_button if row[0] == "ATTACK" else scene.defend_button).pressed.emit()
		var locked: Dictionary = scene.autonomous_token.duplicate(true)
		scene.attack_button.pressed.emit()
		scene.defend_button.pressed.emit()
		scene.target_picker.item_selected.emit(1)
		scene.autonomous_scenario_picker.item_selected.emit(2)
		_check(scene.autonomous_token == locked and scene.autonomous_scenario == 0, "duplicate commands/picker/scenario cannot replace locked decision")
		await _idle()
		for frame in range(900):
			if not legacy.action_in_progress:
				break
			await process_frame
		_check(not legacy.action_in_progress, "Legacy bounded completion")
		var view: Dictionary = scene.encounter.snapshot()
		var actual: Array = [view.actors.player.current_hp, view.actors.enemy_a.current_hp, view.actors.enemy_b.current_hp]
		var old: Array = [legacy.player_hp, legacy.enemy_hp, legacy.enemy_b_hp]
		_check(old == row[2] and actual == row[3], "intentional differential " + row[0] + row[1])
		legacy_differential.append({"action": row[0], "target": row[1], "legacy_expected": row[2], "legacy_actual": old,
			"autonomous_expected": row[3], "autonomous_actual": actual})
		_check(_ids() == ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"], "six separate slots")
		_check(view.round_completions == 1 and view.round_id == 2 and view.pending.is_empty(), "exactly one round completion")
		for event in events.slice(1, 4):
			_check(event.token.decision.action == "ATTACK" and event.token.decision.target_id == "enemy_a", "NPC independently targets first living enemy")
		_home()
		_record("S03/S04/S05/S21 differential " + row[0] + " " + row[1], "Legacy %s; autonomous %s; six slots, commands locked, one completion" % [str(row[2]), str(row[3])])
	legacy.queue_free()
	await process_frame


func _decisions() -> void:
	for preset in [1, 2, 3]:
		_choose(preset)
		scene.defend_button.pressed.emit()
		if await _wait("npc_01", "WINDUP"):
			_check(scene.autonomous_intents.npc_02.text.contains("Waiting to decide")
				and scene.autonomous_intents.npc_03.text.contains("Waiting to decide"), "no early NPC2/3 decisions")
		await _idle()
		var v: Dictionary = scene.encounter.snapshot()
		if preset == 1:
			_check(events[1].token.decision.action == "HELP" and events[1].effect.hp_delta == 4, "HELP4")
			_check(events[2].at_lock.actors.player.current_hp == 10 and events[2].token.decision.action == "ATTACK"
				and events[3].token.decision.action == "ATTACK", "fresh slot decision after HELP")
			_check(v.actors.player.current_hp == 8 and v.help_uses == {"npc_01": 0, "npc_02": 1, "npc_03": 1}, "independent resource / Player round guard")
		elif preset == 2:
			_check(events[1].token.decision.action == "DEFEND" and events[1].after_effect.guards.has("npc_01"), "NPC self guard")
			_check(events[4].effect.hp_delta == -1 and events[5].effect.hp_delta == -2 and v.actors.npc_01.current_hp == 0,
				"NPC guard next hit only / clamp second hit to remaining HP")
			_check(v.actors.player.current_hp == 30 and v.guards.is_empty(), "explicit enemy targets; guards expire")
		else:
			for i in [1, 2, 3]:
				_check(events[i].token.decision.action == "HELP" and events[i].effect.hp_delta == 4, "three independent HELP")
			_check(v.actors.player.current_hp == 11 and v.help_uses == {"npc_01": 0, "npc_02": 0, "npc_03": 0}, "HELP resources once each")
		_home()
		_record("S06/S07/S08/S09 decision fixture %d" % preset, "Per-slot snapshots, HELP4/resource independence, Player each-hit guard, NPC next-hit self guard")


func _skips_and_terminal() -> void:
	for preset in [4, 9, 7, 5, 6]:
		_choose(preset, "enemy_b" if preset == 9 else "enemy_a")
		scene.attack_button.pressed.emit()
		await _idle()
		var v: Dictionary = scene.encounter.snapshot()
		if preset == 4:
			_check(events[1].token.decision.target_id == "enemy_b" and events[4].effect.status == "SKIP"
				and events[5].effect.hp_delta == -3 and v.actors.player.current_hp == 27, "dead A skip, B counter")
		elif preset == 9:
			_check(events[5].effect.status == "SKIP" and events[4].effect.hp_delta == -3
				and v.actors.player.current_hp == 27, "dead B skip, A counter")
		elif preset == 7:
			_check(events[1].effect.status == "SKIP" and events[4].effect.status == "SKIP", "HP0 actor skip")
		else:
			_check(v.result == ("VICTORY" if preset == 5 else "DEFEAT") and scene.battle_result_panel.visible, "terminal panel after return")
			_check(not v.round_running and not v.active_action and v.pending.is_empty() and scene.attack_button.disabled, "terminal drains queue and locks commands")
			scene.attack_button.pressed.emit()
			scene.defend_button.pressed.emit()
			_check(scene.encounter.snapshot() == v, "no command after terminal")
		_home()
		_record("S10/S11/S12/S14/S15 fixture %d" % preset, "Dead slots SKIP; living enemy counters separately; terminal after return, no stuck queue")
		if preset in [5, 6]:
			scene.restart_button.pressed.emit()
			var fresh: Dictionary = scene.encounter.snapshot()
			await create_timer(1.0).timeout
			_check(not scene.battle_result_panel.visible and scene.encounter.snapshot() == fresh
				and not scene.attack_button.disabled, "Restart kills result fade")
	# Both full kill orders must remain playable through repeated real animations.
	for target in ["enemy_a", "enemy_b"]:
		_choose(0, target)
		for round_index in range(8):
			if not scene.encounter.snapshot().result.is_empty():
				break
			scene.attack_button.pressed.emit()
			await _idle()
		_check(scene.encounter.snapshot().result == "VICTORY", "complete kill order " + target)
		_record("S14 full kill order " + target, "Victory, all actors home, queue stopped, result shown")


func _races() -> void:
	# TEST ONLY white-box interruptions. Controller never mutates Registry directly.
	for race in ["target_dead", "actor_dead", "enemy_dead", "enemy_target_dead", "help_threshold", "help_full", "help_clamp", "help_player_dead"]:
		_choose(1 if race.begins_with("help") else 0)
		scene.defend_button.pressed.emit()
		var actor: String = "enemy_a" if race.begins_with("enemy") else "npc_01"
		if not await _wait(actor, "WINDUP"):
			continue
		var target: String = scene.autonomous_token.decision.target_id
		if race == "help_threshold":
			scene.encounter._registry.fixture_heal("player", 5)
		elif race == "help_full" or race == "help_clamp":
			scene.encounter._registry.fixture_heal("player", 24 if race == "help_full" else 23)
		elif race == "actor_dead" or race == "enemy_dead":
			scene.encounter._registry.fixture_damage(actor, 100)
		else:
			scene.encounter._registry.fixture_damage(target, 100)
		scene._refresh_autonomous_ui()
		var spark_count: int = scene.hit_sparks.size()
		var popup_count: int = scene.damage_popups.size()
		if await _wait(actor, "IMPACT"):
			var v: Dictionary = scene.encounter.snapshot()
			var effect: Dictionary = v.locked_action.effect
			if race == "help_threshold":
				_check(v.actors.player.current_hp == 15 and effect.hp_delta == 4, "HELP threshold tested only at decision")
			elif race == "help_clamp":
				_check(v.actors.player.current_hp == 30 and effect.hp_delta == 1 and v.help_uses.npc_01 == 0, "HELP clamps actual delta and spends once")
			else:
				_check(effect.status == "SKIP" and effect.hp_delta == 0, "invalidated locked action SKIP")
				_check(scene.hit_sparks.size() <= spark_count and scene.damage_popups.size() <= popup_count, "SKIP no hit/popups")
				var view: Dictionary = scene.autonomous_views[target]
				var pos: Vector2 = view.root.position
				await process_frame
				_check(view.root.position == pos, "SKIP no target recoil")
				if race == "help_full" or race == "help_player_dead":
					_check(v.help_uses.npc_01 == 1, "unavailable HELP resource preserved")
		await _idle()
		_record("S13 effect-boundary race " + race, "Locked target never moves; invalid actor/target SKIP without hit; HELP threshold only at decision, max clamp, no revival")


func _callback_safety() -> void:
	_choose(1)
	scene.defend_button.pressed.emit()
	if not await _wait("npc_01", "WINDUP"):
		return
	var adapter = scene.presentation_adapter
	var locked: Dictionary = scene.autonomous_token.duplicate(true)
	var epoch: int = adapter.visual_epoch
	var before: Dictionary = scene.encounter.snapshot()
	adapter._action_impact(epoch, "npc_01", "player") # Correct IDs, too early.
	adapter._action_complete(epoch, "npc_01", "player")
	scene._autonomous_impact(locked)
	scene._autonomous_complete(locked)
	for key in ["encounter_id", "generation", "round_id", "action_id", "actor_id", "decision"]:
		var forged: Dictionary = locked.duplicate(true)
		if key == "decision":
			forged.decision.action = "ATTACK"
		elif key == "actor_id":
			forged[key] = "npc_02"
		else:
			forged[key] += 1
		scene._autonomous_impact(forged)
		scene._autonomous_complete(forged)
	adapter._action_impact(epoch - 1, "npc_01", "player")
	adapter._action_impact(epoch, "npc_02", "player")
	adapter._action_impact(epoch, "npc_01", "enemy_b")
	_check(scene.encounter.snapshot() == before, "early/wrong/forged callbacks inert")
	# Probe forged tokens in the valid visual phase immediately before the real effect.
	var impact: Callable = adapter._on_impact
	adapter._on_impact = func():
		var pending: Dictionary = scene.encounter.snapshot()
		for key in ["encounter_id", "generation", "round_id", "action_id", "actor_id", "decision"]:
			var forged: Dictionary = locked.duplicate(true)
			if key == "decision":
				forged.decision.target_id = "enemy_b"
			elif key == "actor_id":
				forged[key] = "npc_02"
			else:
				forged[key] += 1
			scene._autonomous_impact(forged)
		_check(scene.encounter.snapshot() == pending, "forged token rejected at valid impact phase")
		return impact.call()
	if await _wait("npc_01", "IMPACT"):
		var after: Dictionary = scene.encounter.snapshot()
		adapter._action_impact(epoch, "npc_01", "player")
		scene._autonomous_impact(locked)
		_check(scene.encounter.snapshot() == after and after.help_uses.npc_01 == 0, "duplicate impact inert")
	if await _wait("npc_02", "WINDUP"):
		var next: Dictionary = scene.encounter.snapshot()
		adapter._action_complete(epoch, "npc_01", "player")
		scene._autonomous_complete(locked)
		_check(scene.encounter.snapshot() == next, "duplicate completion cannot advance next action")
	await _idle()
	_record("S18 stale/forged/early/duplicate callbacks", "Token/decision/phase/visual epoch and boundaries reject replay; effect/completion once")


func _restart_matrix() -> void:
	for actor in ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"]:
		for phase in ["WINDUP", "IMPACT", "RETURN"]:
			_choose()
			scene.attack_button.pressed.emit()
			if not await _wait(actor, phase):
				continue
			var locked: Dictionary = scene.autonomous_token.duplicate(true)
			var adapter = scene.presentation_adapter
			var epoch: int = adapter.visual_epoch
			var old_motion: Tween = scene.action_tween
			var target: String = locked.decision.target_id
			scene.restart_button.pressed.emit()
			var reset: Dictionary = scene.encounter.snapshot()
			_check(adapter.visual_epoch == epoch + 1 and not old_motion.is_valid() and scene.action_tween == null, "Restart invalidates visual lifetime")
			for e in [epoch, adapter.visual_epoch]:
				adapter._action_impact(e, actor, target)
				adapter._action_return(e, actor, target)
				adapter._action_complete(e, actor, target)
				scene._autonomous_impact(locked)
				scene._autonomous_complete(locked)
			await create_timer(2.0).timeout
			_check(scene.encounter.snapshot() == reset and scene.autonomous_token.is_empty()
				and not scene.action_in_progress and scene.damage_popups.is_empty() and scene.hit_sparks.is_empty(), "no stale gameplay or feedback")
			_home()
			scene.attack_button.pressed.emit()
			var fresh: Dictionary = scene.encounter.snapshot()
			_check(fresh.locked_action.action_id == 1 and fresh.generation != locked.generation, "reused action ID has new generation")
			adapter._action_impact(epoch, actor, target)
			scene._autonomous_impact(locked)
			scene._autonomous_complete(locked)
			_check(scene.encounter.snapshot() == fresh, "old callback cannot affect fresh action")
			await _idle()
			_check(scene.encounter.snapshot().round_completions == 1, "fresh queue completes once")
			_record("S16/S17 Restart " + actor + " / " + phase, "Kill owning Tween, invalidate generation/epoch, clear feedback/pose, fresh queue completes once")
	# Reentrant Restart within effect notification and before terminal completion.
	for preset in [0, 5, 6]:
		_choose(preset)
		scene.attack_button.pressed.emit()
		if preset == 0:
			var impact: Callable = scene.presentation_adapter._on_impact
			scene.presentation_adapter._on_impact = func():
				var visual: Dictionary = impact.call()
				scene.restart_button.pressed.emit()
				return visual
			await create_timer(2.0).timeout
		else:
			if await _wait("player" if preset == 5 else "enemy_a", "IMPACT"):
				_check(not scene.encounter.snapshot().result.is_empty() and not scene.battle_result_panel.visible, "terminal waits for return")
				scene.restart_button.pressed.emit()
			await create_timer(2.0).timeout
		_check(scene.encounter.snapshot().command_ready and not scene.action_in_progress
			and not scene.battle_result_panel.visible, "Restart cancels reentrant/terminal callbacks")
		_home()
		_record("S16/S17 reentrant/terminal Restart %d" % preset, "No post-Restart effects, motion or result fade")


func _run() -> void:
	scene = OptIn.instantiate()
	root.add_child(scene)
	await process_frame
	await _startup_and_differential()
	await _decisions()
	await _skips_and_terminal()
	await _races()
	await _callback_safety()
	await _restart_matrix()
	_choose()
	var detached: Dictionary = scene.encounter.snapshot()
	detached.actors.player.current_hp = 1
	detached.help_uses.npc_01 = 0
	_check(scene.encounter.actor_snapshot("player").current_hp == 30 and scene.encounter.snapshot().help_uses.npc_01 == 1, "snapshot is detached")
	_observe()
	_record("S19 HUD / S20 HP ownership", "Snapshot reads match HUD/HELP/guard; detached mutations cannot affect authority; no Legacy HP/queue")
	scene.queue_free()
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "differential": legacy_differential}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
