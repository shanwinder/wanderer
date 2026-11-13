extends SceneTree

const Battle := preload("res://scenes/combat/combat_m4_playable_optin.tscn")

var battle: Control
var hud: Control
var owner: RefCounted
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_start()
	await process_frame
	await process_frame
	_check(not hud._log_panel.visible and _focused("PlayerTarget"), "PREPARED: reader hidden; target focused")
	var baseline: Dictionary = owner.snapshot()
	_key(KEY_L)
	_check(hud._log_panel.visible and _focused("BattleLogReader"), "L opens history and focuses its reader")
	_send_key(KEY_L, true, false, true)
	_check(hud._log_panel.visible, "held L does not toggle a second time")
	_key(KEY_TAB)
	_check(_focused("Guidance"), "Tab leaves reader for Guidance")
	_key(KEY_TAB, true)
	_key(KEY_TAB, true)
	_check(_focused("BattleLogToggle"), "Shift+Tab leaves reader for log toggle")
	_key(KEY_ESCAPE)
	_check(not hud._log_panel.visible and _focused("PlayerTarget") and owner.snapshot() == baseline,
		"Escape restores target and full owner snapshot is unchanged")
	_key(KEY_L)
	_key(KEY_L)
	_check(not hud._log_panel.visible and _focused("PlayerTarget"), "L closes and restores focus")

	_key(KEY_ENTER)
	await process_frame
	_check(hud._target.get_popup().visible, "keyboard opens the real target popup")
	_key(KEY_L)
	_check(not hud._log_panel.visible and hud._target.get_popup().visible, "target popup owns its keys")
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	await process_frame
	_check(hud._target.get_selected_metadata() == "enemy_b" and _focused("PlayerTarget"), "select target B by keyboard")
	_key(KEY_L)
	_key(KEY_TAB)
	_key(KEY_ENTER)
	await process_frame
	_check(hud._guidance.get_popup().visible, "guidance popup opens while history remains open")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not hud._guidance.get_popup().visible and hud._log_panel.visible, "popup Escape does not close history")
	_key(KEY_ENTER)
	await process_frame
	for i in 4:
		_key(KEY_DOWN)
	_key(KEY_ENTER)
	await process_frame
	_key(KEY_TAB)
	_check(_focused("GuidanceTarget"), "Focus Target advice inserts its own keyboard target")
	_key(KEY_TAB)
	_check(_focused("SendGuidance"), "Tab reaches send advice")
	_key(KEY_SPACE)
	_check(owner.read_view().guidance.pending != null and owner.read_view().guidance.pending.guidance_type == "FOCUS_TARGET",
		"keyboard submits genuine pending guidance")
	_key(KEY_L)
	_check(_focused("SendGuidance") and not hud._log_panel.visible, "closing from a legal control keeps context")

	for pair in [[KEY_ENTER, KEY_ENTER], [KEY_SPACE, KEY_SPACE], [KEY_ENTER, KEY_SPACE], [KEY_SPACE, KEY_ENTER]]:
		_start()
		_repeat_attack(pair[0], pair[1])
		await process_frame

	_start()
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_step()
	_step()
	var token: Dictionary = owner.read_view().active_token
	var old_callback: Callable = battle._callbacks.bind(token, "IMPACT", "driver/hud-stale-after-restart")
	var old: Dictionary = owner.snapshot()
	_key(KEY_TAB, true)
	_check(_focused("Restart"), "deliberate Shift+Tab reaches Restart from active status")
	_key(KEY_ENTER)
	_check_restart(old, "active Restart")
	var fresh: Dictionary = owner.snapshot()
	_check(old_callback.call().is_empty() and owner.snapshot() == fresh and hud._log.text.contains("รุ่นที่ 2"),
		"stale impact changes neither new-generation root nor log")
	_check(not hud._log.text.contains("Player เลือก"), "accepted Restart clears old visible history")

	_start()
	_attack_round()
	_check(hud._feedback.text.contains("ล้ม") and not hud._log_panel.visible and _focused("PlayerTarget"),
		"real round 1 close: DOWN feedback visible and target focus restored")
	var history: String = hud._log.text
	var history_root: Dictionary = owner.snapshot()
	_key(KEY_L)
	await process_frame
	await process_frame
	var bottom: int = hud._log_scroll.scroll_vertical
	_key(KEY_PAGEUP)
	var older: int = hud._log_scroll.scroll_vertical
	_check(bottom > 0 and older < bottom, "Page Up scrolls authentic history back")
	_key(KEY_PAGEDOWN)
	_check(hud._log_scroll.scroll_vertical == bottom, "Page Down returns to the bottom")
	_key(KEY_ESCAPE)
	_key(KEY_L)
	_check(hud._log.text == history and owner.snapshot() == history_root, "open, scroll and close preserve full history and owner state")
	_key(KEY_ESCAPE)

	_key(KEY_TAB)
	_key(KEY_TAB)
	_key(KEY_SPACE)
	_check(hud._intent.text.contains("ตั้งรับ"), "real Defend visibly accepted")
	_step()
	var saw_rescue := false
	var saw_guard := false
	for i in 20:
		var active: Variant = owner.read_view().active_token
		if active != null:
			_impact()
			if active.kind == "RESCUE":
				saw_rescue = hud._feedback.text.contains("ลุกขึ้นแล้ว")
			if active.kind == "DEFEND":
				saw_guard = saw_guard or hud._feedback.text.contains("ได้รับการ์ด")
			_finish_motion()
		if owner.read_view().phase != "OPEN":
			break
		_step()
	_check(saw_guard and saw_rescue, "committed Guard and NPC RESCUE shown while history hidden")
	_check(_focused("PlayerTarget"), "round close restores target with history hidden")

	# A reader left open during a round must keep its focus when commands return.
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_key(KEY_L)
	_round()
	_check(owner.read_view().command_ready and _focused("BattleLogReader"), "next round does not steal active reading focus")
	_key(KEY_ESCAPE)
	_check(_focused("BattleStatus"), "hidden old command context falls back to status")

	# Genuine normal-play VICTORY plus a separate immutable defeat fixture.
	_start()

	for i in 6:
		if not owner.read_view().command_ready:
			break
		_attack_round()
	_check(owner.read_view().outcome != null and owner.read_view().outcome.result == "VICTORY", "normal commands reach VICTORY")
	_terminal_navigation("VICTORY")
	_start("m405-demo/defeat")
	_step()
	_terminal_navigation("DEFEAT")

	_start()
	for i in 6:
		_key(KEY_TAB)
		_key(KEY_TAB)
		_key(KEY_SPACE)
		_round()
	_check(owner.snapshot().closed_rounds == 6 and owner.read_view().outcome == null, "six real Defend rounds reach exhaustion")
	_terminal_navigation("ครบ 6 รอบ")

	_start()
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_step()
	_step()
	var held_callback: Callable = battle._callbacks.bind(owner.read_view().active_token, "COMPLETE", "driver/hud-stale-held")
	owner.inject_failure_before_close_commit(battle._driver)
	_round()
	var held := owner
	old = held.snapshot()
	var diagnostic: Dictionary = held.close_failure_diagnostic()
	_check(old.phase == "SEALED" and diagnostic.reason == "M405_CLOSE_FAILED"
		and hud._status.text.contains(diagnostic.reason) and hud._log.text.contains(diagnostic.reason),
		"genuine E5 SEALED HOLD shows diagnostics in status and history")
	# Bypass the disabled button only to probe the real rejected owner request.
	_check(battle._restart().reason == "M405_SEALED_RESTART" and held.snapshot() == old
		and hud._feedback.text.contains("M405_SEALED_RESTART"), "rejected Restart retains held root and reports failure")
	_key(KEY_L)
	_key(KEY_TAB)
	_check(_focused("ExitHeldSession") and hud._restart.disabled, "E5 reader Tab skips disabled Restart and reaches Exit")
	_key(KEY_TAB, true)
	_key(KEY_ESCAPE)
	_check(_focused("BattleStatus") and held.snapshot() == old, "E5 Escape restores safe focus without mutating held session")
	_key(KEY_TAB, true)
	_check(_focused("ExitHeldSession"), "E5 explicit reverse navigation focuses Exit")
	_key(KEY_SPACE)
	owner = battle._owner
	fresh = owner.snapshot()
	_check(fresh.session != old.session and fresh.generation == 1 and fresh.revision == 0
		and fresh.journal.is_empty() and fresh.receipts.is_empty() and held.snapshot() == old
		and held_callback.call().is_empty() and _focused("PlayerTarget"), "keyboard Exit creates a fresh factory session and detaches stale callback")

	battle.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var report := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if _check(report != null, "write proof report"):
				report.store_string(JSON.stringify({"checks": checks, "failures": failures, "observations": observations}, "\t"))
	print("B5 KEYBOARD PROOF: %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks.size(), failures])
	quit(int(failures != 0))


func _start(fixture: String = "m405-demo/main") -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = Battle.instantiate()
	battle.fixture_id = fixture
	root.add_child(battle)
	battle.set_process(false)
	owner = battle._owner
	hud = battle.get_node("HUD")


func _repeat_attack(first: Key, second: Key) -> void:
	var label := "%s/%s" % [OS.get_keycode_string(first), OS.get_keycode_string(second)]
	var before: Dictionary = owner.snapshot()
	_key(KEY_TAB)
	_check(_focused("Attack"), label + " starts with deliberate Attack focus")
	_key(first)
	var accepted: Dictionary = owner.snapshot()
	_check(accepted.generation == before.generation and accepted.revision == before.revision + 1
		and accepted.journal.size() == before.journal.size() + 1 and accepted.journal.back().operation == "COMMAND"
		and accepted.receipts == before.receipts and accepted.command.action == "ATTACK"
		and _focused("BattleStatus"), label + " one real command, status focus, no new receipt")
	_key(second)
	_send_key(second, true, false, true)
	_send_key(second, false)
	_check(owner.snapshot() == accepted and owner.restart_audit().is_empty() and _focused("BattleStatus"),
		label + " rapid press and echo leave generation, revision, journal and receipts unchanged")
	_step()
	_step()
	_finish_motion()
	var settled: Dictionary = owner.snapshot()
	_check(settled.generation == accepted.generation and settled.receipts.size() == accepted.receipts.size() + 1
		and settled.enemies[0].hp == before.enemies[0].hp - 5, label + " accepted attack completes once with real damage")


func _terminal_navigation(label: String) -> void:
	var before: Dictionary = owner.snapshot()
	_check(hud._status.text.contains(label) and not hud._log_panel.visible, label + " visible without reader")
	_key(KEY_L)
	_check(_focused("BattleLogReader") and hud._log_panel.visible, label + " keyboard opens full history")
	_key(KEY_TAB)
	_check(_focused("Restart") and owner.snapshot() == before, label + " reader exits to legal Restart")
	_key(KEY_TAB, true)
	_key(KEY_ESCAPE)
	_check(_focused("BattleStatus") and not hud._log_panel.visible, label + " Escape returns to status")
	_key(KEY_TAB, true)
	_check(_focused("Restart"), label + " deliberate navigation focuses Restart")
	_key(KEY_SPACE)
	_check_restart(before, label)


func _check_restart(before: Dictionary, label: String) -> void:
	var after: Dictionary = owner.snapshot()
	var audit: Array = owner.restart_audit()
	_check(after.session == before.session and after.generation == before.generation + 1
		and after.revision == 0 and after.journal.is_empty() and after.receipts.is_empty()
		and audit.size() == 1 and not hud._log_panel.visible, label + " genuine same-session Restart")
	if owner.read_view().command_ready:
		_check(_focused("PlayerTarget"), label + " restores Player target")


func _attack_round() -> void:
	_check(_focused("PlayerTarget"), "prepared attack starts at target")
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_round()


func _round() -> void:
	for i in 20:
		_finish_motion()
		var view: Dictionary = owner.read_view()
		if view.phase in ["TERMINAL", "CLOSED", "SEALED"] or view.command_ready:
			break
		_step()


func _step() -> void:
	battle._process(0.0)


func _impact() -> void:
	var tween: Tween = hud._motion._motion
	for i in 120:
		if tween == null or not tween.is_valid() or hud._motion.phase != "WINDUP":
			break
		tween.custom_step(1.0 / 60.0)


func _finish_motion() -> void:
	var tween: Tween = hud._motion._motion
	for i in 120:
		if tween == null or not tween.is_valid():
			break
		tween.custom_step(1.0 / 60.0)


func _key(code: Key, shift: bool = false) -> void:
	_send_key(code, true, shift)
	_send_key(code, false, shift)
	var view: Dictionary = owner.snapshot()
	var focus := root.gui_get_focus_owner()
	observations.append({"key": OS.get_keycode_string(code), "shift": shift,
		"focus": str(focus.name) if focus != null else "",
		"session": view.session, "generation": view.generation, "revision": view.revision,
		"journal": view.journal.size(), "receipts": view.receipts.size(),
		"log_open": hud._log_panel.visible, "scroll": hud._log_scroll.scroll_vertical})


func _send_key(code: Key, pressed: bool, shift: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	root.push_input(event)


func _focused(node_name: String) -> bool:
	var focus := root.gui_get_focus_owner()
	return focus != null and focus.name == node_name and focus.is_visible_in_tree()


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL: " + label)
	return ok
