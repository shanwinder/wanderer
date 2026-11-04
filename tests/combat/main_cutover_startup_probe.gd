extends Node

# Snapshot-only autoload observer: the engine still starts the configured main scene
# without --script or an explicit scene argument. Never installed in production.
func _ready() -> void:
	call_deferred("_probe")


func _probe() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene = get_tree().current_scene
	var legacy: bool = "--expect-legacy" in OS.get_cmdline_user_args()
	var expected: String = "res://scenes/combat/combat_prototype.tscn" if legacy else "res://scenes/combat/combat_autonomous_optin.tscn"
	var checks: Array = []
	checks.append(scene != null and scene.scene_file_path == expected)
	if scene != null:
		checks.append(scene.session_mode == (0 if legacy else 1))
		checks.append((scene.encounter == null) == legacy)
		checks.append((scene.turn_flow != null and scene.target_registry != null) == legacy)
		if legacy:
			checks.append([scene.player_hp, scene.enemy_hp, scene.enemy_b_hp] == [30, 15, 12])
		else:
			checks.append(scene.player_hp == null and scene.enemy_hp == null and scene.enemy_b_hp == null)
			checks.append(scene.autonomous_scenario == 0 and scene.encounter.snapshot().command_ready)
			for id in ["npc_01", "npc_02", "npc_03"]:
				checks.append(scene.encounter.actor_snapshot(id).current_hp == 10 and scene.encounter.actor_snapshot(id).max_hp == 10)
	var failures: int = checks.count(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"expected_entry": expected, "actual_entry": scene.scene_file_path if scene != null else "none",
				"session_mode": scene.session_mode if scene != null else -1, "checks": checks.size(), "failures": failures,
				"actual": "PASS" if failures == 0 else "FAIL", "manual_owner_acceptance": "PENDING"}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)
