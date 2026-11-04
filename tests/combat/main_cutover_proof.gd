extends "res://tests/combat/autonomous_main_integration.gd"

# Reuse the full real-Tween matrix against the CONFIGURED project entry. Keeping
# the inherited harness avoids a second set of gameplay expectations for cutover.
var coverage: Array = []


func _coverage(id: String, expected: String, markers: Array) -> void:
	var matched: Array = []
	for entry in cases:
		for marker in markers:
			if entry.scenario.contains(marker):
				matched.append(entry)
				break
	var ok: bool = not matched.is_empty()
	for entry in matched:
		ok = ok and entry.failures == 0
	_check(ok, id + " evidence exists and passes")
	coverage.append({"id": id, "expected": expected, "actual": "PASS" if ok else "FAIL",
		"evidence_cases": matched.map(func(entry): return entry.scenario), "mode": "HEADLESS",
		"manual_gui": "PENDING owner F5/F6"})


func _run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(path == "res://scenes/combat/combat_autonomous_optin.tscn", "C01 candidate configured entry")
	var packed = load(path)
	_check(packed is PackedScene, "C01 clean-import resource resolves")
	if not packed is PackedScene:
		print("RESULT: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	scene = packed.instantiate()
	_check(scene.session_mode == scene.SessionMode.AUTONOMOUS and scene.encounter == null, "mode set before ready; no premature authority")
	root.add_child(scene)
	await process_frame
	if scene.encounter == null:
		_check(false, "C02 configured entry creates Encounter")
		print("RESULT: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	_observe()
	_record("C01-C04 configured Main entry", "Configured inherited scene resolves; mode before ready; sole Encounter; Normal NPC10/10/10 checked next")
	await _startup_and_differential()
	await _decisions()
	await _skips_and_terminal()
	await _races()
	await _callback_safety()
	await _restart_matrix()
	# Explicit pre-command picker fallback after an unavailable selected target.
	_choose(7)
	scene.autonomous_selected_target = "enemy_a"
	scene._refresh_autonomous_ui()
	_check(scene.autonomous_selected_target == "enemy_b" and scene.target_picker.item_count == 1
		and scene.target_picker.get_item_metadata(0) == "enemy_b", "dead target picker falls back to B")
	scene.attack_button.pressed.emit()
	_check(scene.autonomous_token.decision.target_id == "enemy_b", "Player command uses live fallback")
	await _idle()
	_record("C11 picker fallback", "Unavailable A omitted; B selected before lock; Player attacks B")
	_choose()
	var detached: Dictionary = scene.encounter.snapshot()
	detached.actors.player.current_hp = 1
	detached.help_uses.npc_01 = 0
	_check(scene.encounter.actor_snapshot("player").current_hp == 30 and scene.encounter.snapshot().help_uses.npc_01 == 1, "detached HP/resource ownership")
	_observe()
	_record("C04/C08 detached ownership", "UI snapshot mutation cannot change HP/HELP; Legacy HP/queue/targets null")
	for row in [
		["C01", "Project Main resolves Autonomous", ["C01-C04"]],
		["C02", "Configured entry creates only FullPartyEncounter; native F5 probe separately required", ["C01-C04", "S02"]],
		["C03", "Normal NPC current/max HP10 each", ["S01"]],
		["C04", "No Legacy HP/queue/targets, detached snapshots", ["C04/C08", "S02"]],
		["C05", "ATTACK A24/7/12; ATTACK B24/12/7", ["differential ATTACK"]],
		["C06", "DEFEND28/12/12; reduction2 per valid enemy hit", ["differential DEFEND"]],
		["C07", "Three separate decisions at slot time; HELP changes later decisions", ["decision fixture 1", "differential ATTACK"]],
		["C08", "HELP4/clamp/once per NPC, no revival, RuntimeState ownership", ["decision fixture 3", "effect-boundary race help", "C04/C08"]],
		["C09", "Self-DEFEND next valid self hit only", ["decision fixture 2"]],
		["C10", "Enemy A/B separate actions; living enemy still responds", ["fixture 4", "fixture 9", "differential"]],
		["C11", "Fallback before lock; dead actors SKIP; invalidated locked target not retargeted", ["C11 picker", "effect-boundary race", "fixture 7"]],
		["C12", "Victory/Defeat after return; terminal commands inert", ["fixture 5", "fixture 6", "full kill order"]],
		["C13", "Restart WINDUP all six actors", ["/ WINDUP"]],
		["C14", "Restart after IMPACT all six actors", ["/ IMPACT"]],
		["C15", "Restart RETURN all six actors", ["/ RETURN"]],
		["C16", "Stale/forged/duplicate callbacks inert including new actionID1", ["Restart", "S18"]],
		["C17", "Direct Legacy scene starts Legacy with no Encounter; GUI F6 pending", ["S02"]],
		["C18", "Legacy HP/Guard/queue unchanged; full regression/trace gate separately required", ["differential"]],
		["C19", "Main speed0.70/44px/formation/home/idle/shadows/depth/B/result structure; visual gate pending", ["S01"]]
	]:
		_coverage(row[0], row[1], row[2])
	scene.queue_free()
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "configured_entry": path,
				"coverage": coverage, "cases": cases, "differential": legacy_differential}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
