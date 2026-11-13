extends Control

signal command_pressed(action: String, target: String, identity: Dictionary)
signal guidance_pressed(kind: String, target: String, identity: Dictionary)
signal restart_pressed
signal exit_pressed

const Motion = preload("res://scripts/combat/combat_presentation_adapter.gd")
const Messages = preload("res://scripts/combat/guidance_messages.gd")
const Guidance = preload("res://scripts/npc/guidance_data_contract.gd")

const combat_speed_scale: float = 0.70
const SHORT_LUNGE_DISTANCE: float = 44.0
# Motion settings copied from the accepted Main choreography for the shared visual adapter.
const MOTION_SETTINGS := {
	"speed": combat_speed_scale,
	"SHORT_LUNGE_DISTANCE": SHORT_LUNGE_DISTANCE,
	"SHORT_LUNGE_TIME": 0.18,
	"SHORT_LUNGE_RETURN_TIME": 0.22,
	"ACTIVE_SPRITE_SCALE_FACTOR": 1.03,
	"ATTACK_POSE_WINDUP_DISTANCE": 6.0,
	"ATTACK_POSE_STRIKE_DISTANCE": 14.0,
	"ATTACK_POSE_WINDUP_TIME": 0.10,
	"ATTACK_POSE_STRIKE_TIME": 0.10,
	"ENEMY_RECOIL_DISTANCE": 18.0,
	"ENEMY_HIT_TIME": 0.14,
	"IMPACT_SPRITE_SQUASH": Vector2(1.04, 0.96),
	"HIT_HOLD_TIME": 0.08,
	"ACTION_HANDOFF_PAUSE": 0.16,
	"NPC_STAGE_HOLD_TIME": 0.10,
	"NPC_ATTACK_HIT_TIME": 0.14,
	"NPC_ACTIVE_TINT": Color(1.12, 1.08, 1.02, 1.0),
	"PLAYER_HIT_RECOIL_DISTANCE": 14.0,
	"GUARDED_HIT_RECOIL_DISTANCE": 5.0,
	"GUARDED_HIT_SQUASH": Vector2(1.01, 0.99),
	"PLAYER_HIT_TIME": 0.14,
	"ENEMY_COUNTER_HOLD_TIME": 0.08,
	"PLAYER_DEFEND_BRACE_TIME": 0.12,
	"PLAYER_DEFEND_HOLD_TIME": 0.08,
	"PLAYER_DEFEND_RECOVER_TIME": 0.16,
	"PLAYER_DEFEND_BRACE_OFFSET": Vector2(-3.0, -2.0),
	"PLAYER_DEFEND_BRACE_SCALE": Vector2(1.02, 0.99),
	"PLAYER_DEFEND_BRACE_TINT": Color(0.80, 0.92, 1.0, 1.0),
	"GUARD_POSE_RAISE_TIME": 0.12,
	"GUARD_POSE_RETURN_TIME": 0.18,
}

const NAMES := {"player": "Player", "npc_01": "NPC 1", "npc_02": "NPC 2",
	"npc_03": "NPC 3", "enemy_a": "ศัตรู A", "enemy_b": "ศัตรู B"}
const ACTIONS := {"ATTACK": "โจมตี", "DEFEND": "ตั้งรับ", "HELP": "ช่วย Player",
	"RESCUE": "ช่วยให้ลุก", "RETREAT": "ถอนตัว"}
const OUTCOMES := {"VICTORY": "ชัยชนะ", "DEFEAT": "พ่ายแพ้", "PARTY_RETREAT": "ทีมถอนตัว",
	"MIXED_WITHDRAWAL": "ถอนตัวโดยมีผู้ถูกทิ้งไว้"}
const DECISIONS := {"M404_URGENT_RESCUE": "ช่วยก่อนหมดเวลา",
	"M404_NONURGENT_RESCUE": "ช่วยเพื่อนที่ล้ม", "M404_SELF_PRESERVATION_RETREAT": "ถอนตัวเพื่อเอาตัวรอด"}
const GUARD_CAUSES := {"GRANT": "ได้รับการ์ด", "CONSUME": "ใช้การ์ดแล้ว", "DOWN": "เสียการ์ดเมื่อล้ม",
	"RETREATED": "เสียการ์ดเมื่อถอนตัว", "TERMINAL": "การ์ดสิ้นสุดเมื่อจบการต่อสู้", "ROUND_CLOSE": "การ์ดหมดเมื่อปิดรอบ"}
const GOLD := Color("#f2d98f")
const MINT := Color("#a7d3cb")
const MUTED := Color("#afbfbb")

var _motion := Motion.new()
var _actors: Dictionary = {}
var _cards: Dictionary = {}
var _input_identity: Dictionary = {}
var _status: Label
var _intent: Label
var _feedback: Label
var _log: Label
var _log_panel: Control
var _log_scroll: ScrollContainer
var _log_toggle: Button
var _log_return_focus: Control
var _follow_log: bool = true
var _shown_diagnostic: String = ""
var _commands: HBoxContainer
var _guidance_row: HBoxContainer
var _attack: Button
var _defend: Button
var _restart: Button
var _exit: Button
var _target: OptionButton
var _guidance: OptionButton
var _focus_target: OptionButton
var _send_guidance: Button
var _guidance_status: Label


func setup(nodes: Dictionary) -> void:
	for id in nodes:
		var actor_root: Node2D = nodes[id][0]
		var sprite: Node2D = nodes[id][1]
		_actors[id] = {"root": actor_root, "sprite": sprite, "home": actor_root.position,
			"sprite_home": sprite.position, "scale": sprite.scale, "tint": sprite.modulate,
			"enemy": id.begins_with("enemy")}
	_build_hud()


func _build_hud() -> void:
	var header := _panel(Rect2(26, 18, 1228, 124))
	header.add_theme_constant_override("separation", 3)
	var title_row := HBoxContainer.new()
	header.add_child(title_row)
	var title := _label(title_row, "WANDERER  /  M4 PLAYABLE", 20, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_toggle = _button(title_row, "BattleLogToggle", "บันทึกการต่อสู้ [L]", _toggle_log)
	_status = _label(header, "", 17, MINT)
	_status.name = "BattleStatus"
	_status.focus_mode = Control.FOCUS_ALL
	_status.focus_entered.connect(_status.queue_redraw)
	_status.focus_exited.connect(_status.queue_redraw)
	_status.draw.connect(_draw_status_focus)
	_intent = _label(header, "", 16, GOLD)
	_feedback = _label(header, "", 16, Color.WHITE)

	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	_place(roster, Rect2(26, 152, 1228, 84))
	for id in _actors:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel_style())
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster.add_child(card)
		var body := VBoxContainer.new()
		card.add_child(body)
		_label(body, NAMES[id], 16, MINT if _actors[id].enemy else GOLD)
		var health := ProgressBar.new()
		health.custom_minimum_size.y = 6
		health.show_percentage = false
		body.add_child(health)
		_cards[id] = {"health": health, "state": _label(body, "", 14, Color.WHITE),
			"resources": _label(body, "", 13, MUTED)}

	var footer := _panel(Rect2(26, 554, 1228, 148))
	var navigation := HBoxContainer.new()
	footer.add_child(navigation)
	_guidance_status = _label(navigation, "", 17, MINT)
	_guidance_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart = _button(navigation, "Restart", "เริ่มใหม่", func() -> void: restart_pressed.emit())
	_exit = _button(navigation, "ExitHeldSession", "ออกและเปิดเซสชันใหม่", func() -> void: exit_pressed.emit())

	_guidance_row = HBoxContainer.new()
	footer.add_child(_guidance_row)
	_label(_guidance_row, "คำชี้นำ NPC", 16, GOLD)
	_guidance = OptionButton.new()
	_guidance.name = "Guidance"
	_guidance_row.add_child(_guidance)
	for kind in Guidance.TYPES:
		_guidance.add_item(Messages.message(kind))
		_guidance.set_item_metadata(_guidance.item_count - 1, kind)
	_guidance.item_selected.connect(func(_index: int) -> void:
		_update_focus_target()
		_update_tab_order())
	_focus_target = OptionButton.new()
	_focus_target.name = "GuidanceTarget"
	_guidance_row.add_child(_focus_target)
	_send_guidance = _button(_guidance_row, "SendGuidance", "ส่งคำชี้นำ", _emit_guidance)

	_commands = HBoxContainer.new()
	footer.add_child(_commands)
	_label(_commands, "คำสั่ง Player", 16, GOLD)
	_target = OptionButton.new()
	_target.name = "PlayerTarget"
	_commands.add_child(_target)
	_attack = _button(_commands, "Attack", "โจมตี", func() -> void: _emit_command("ATTACK", _selected(_target)))
	_defend = _button(_commands, "Defend", "ตั้งรับ", func() -> void: _emit_command("DEFEND", "player"))
	_label(_commands, "Tab เลือกปุ่ม · Enter/Space ยืนยัน", 14, MUTED)

	_build_log()


func _build_log() -> void:
	var body := _panel(Rect2(26, 246, 1228, 232))
	_log_panel = body.get_parent() as Control
	_log_panel.name = "BattleLogPanel"
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(body, "บันทึกการต่อสู้  ·  Page Up/Down เลื่อน  ·  Tab ออกจากบันทึก  ·  L / Esc ปิด", 16, GOLD)

	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "BattleLogReader"
	_log_scroll.accessibility_name = "ประวัติการต่อสู้"
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.focus_mode = Control.FOCUS_ALL
	_log_scroll.draw_focus_border = true
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = GOLD
	focus_style.set_border_width_all(1)
	_log_scroll.add_theme_stylebox_override("focus", focus_style)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_log_scroll.gui_input.connect(_read_log_key)
	body.add_child(_log_scroll)
	_log = _label(_log_scroll, "", 16, Color("#d5dfd9"))
	_log.name = "BattleLog"
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := _log_scroll.get_v_scroll_bar()
	bar.focus_mode = Control.FOCUS_NONE
	bar.changed.connect(_scroll_to_latest)
	bar.value_changed.connect(func(value: float) -> void:
		_follow_log = value >= bar.max_value - bar.page - 1.0)
	_log_panel.hide()


func _draw_status_focus() -> void:
	if _status.has_focus():
		_status.draw_rect(Rect2(Vector2(-4, 0), _status.size + Vector2(8, 0)), GOLD, false, 1.0)


func _read_log_key(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed:
		return
	if event.keycode not in [KEY_PAGEUP, KEY_PAGEDOWN]:
		return
	var page := int(_log_scroll.get_v_scroll_bar().page)
	_log_scroll.scroll_vertical += -page if event.keycode == KEY_PAGEUP else page
	_log_scroll.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	# The OptionButton popup owns its input while open, including Escape.
	for picker in [_target, _guidance, _focus_target]:
		if picker.get_popup().visible:
			return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and (not is_ancestor_of(focus) or focus is LineEdit or focus is TextEdit):
		return
	if event.keycode == KEY_L or (event.keycode == KEY_ESCAPE and _log_panel.visible):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_toggle_log()


func _toggle_log() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if _log_panel.visible:
		_log_panel.hide()
		_log_toggle.text = "บันทึกการต่อสู้ [L]"
		_update_tab_order()
		# Keep focus outside the reader and never hand activation to Restart or Exit.
		var restore := focus if focus != null and not _log_panel.is_ancestor_of(focus) and focus != _log_toggle else _log_return_focus
		if not _is_tab_stop(restore) or restore in [_restart, _exit]:
			restore = _status
		restore.grab_focus()
		_log_return_focus = null
	else:
		_log_return_focus = focus
		_log_panel.show()
		_log_toggle.text = "ปิดบันทึก [L / Esc]"
		_update_tab_order()
		_follow_log = true
		_scroll_to_latest()
		_log_scroll.grab_focus()


func _scroll_to_latest() -> void:
	if _follow_log and _log_panel.visible:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _is_tab_stop(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and not (control is BaseButton and control.disabled)


func _update_tab_order() -> void:
	var stops: Array[Control] = []
	for control in [_status, _log_toggle, _log_scroll, _guidance, _focus_target, _send_guidance,
			_target, _attack, _defend, _restart, _exit]:
		if _is_tab_stop(control):
			stops.append(control)
	for i in stops.size():
		stops[i].focus_next = stops[i].get_path_to(stops[(i + 1) % stops.size()])
		stops[i].focus_previous = stops[i].get_path_to(stops[posmod(i - 1, stops.size())])


func render(view: Dictionary, driver_error: String, diagnostic: Dictionary) -> void:
	var ready: bool = view.command_ready and driver_error.is_empty()
	var became_ready: bool = ready and (_input_identity.is_empty()
		or view.identity.generation != _input_identity.generation or view.identity.round_id != _input_identity.round_id)
	_input_identity = view.identity.duplicate() if ready else {}
	_commands.visible = ready
	_guidance_row.visible = ready
	_restart.disabled = view.phase == "SEALED"
	_exit.visible = not diagnostic.is_empty()
	for row in view.party + view.enemies:
		_render_actor(row)
	if ready:
		_update_targets(_target, view.enemies)
		_update_targets(_focus_target, view.enemies)
		if became_ready:
			_guidance.select(0)
		_attack.disabled = _target.selected == -1
		_update_focus_target()
	_update_tab_order()
	var focus := get_viewport().gui_get_focus_owner()
	if became_ready and not _log_panel.visible:
		_target.grab_focus()
	elif not _is_tab_stop(focus):
		# A hidden command row or disabled Restart must leave a safe focus anchor.
		_status.grab_focus()

	var advice: Variant = view.guidance.pending if view.phase == "PREPARED" else view.guidance.active
	var advice_text: String = Messages.message(advice.guidance_type) if advice != null else Messages.message("NONE")
	if advice != null and advice.guidance_type == "FOCUS_TARGET":
		advice_text += " → " + NAMES[advice.preferred_target_id]
	_guidance_status.text = ("คำชี้นำรอบนี้  ·  " if view.phase == "OPEN" else "คำชี้นำที่ส่งไว้  ·  ") + advice_text
	var status: String = "กำลังดำเนินการตามคิว"
	if not diagnostic.is_empty():
		status = "ปิดรอบไม่สำเร็จ — พักเซสชันนี้ · ออกแล้วเริ่มเซสชันใหม่ได้ [%s · %s]" % [diagnostic.stage, diagnostic.reason]
	elif not driver_error.is_empty():
		status = "หยุดดำเนินการ [%s]" % driver_error
	elif view.outcome != null:
		status = OUTCOMES.get(view.outcome.result, view.outcome.result) + "  /  " + view.outcome.result
	elif view.diagnostic == "DEMO_LIMIT_REACHED":
		status = "ครบ 6 รอบของฉากทดลอง"
	elif ready:
		status = "เลือกคำสั่ง Player"
	elif view.phase == "PREPARED" and not view.has_accepted_fresh_command:
		status = "Player ไม่พร้อม · เพื่อนร่วมทีมดำเนินการตามคิว"
	_status.text = "รอบ %d / 6  ·  %s" % [view.identity.round_id, status]
	if not diagnostic.is_empty() and _shown_diagnostic != status:
		_shown_diagnostic = status
		_append(status)


func _render_actor(row: Dictionary) -> void:
	var card: Dictionary = _cards[row.actor_id]
	var actor: Dictionary = _actors[row.actor_id]
	var life: String = row.get("life", "ALIVE" if row.get("available", true) else "UNAVAILABLE")
	var retreated: bool = row.get("participation") == "RETREATED"
	var state: String = ""
	if retreated:
		state = " · ถอนตัว"
	elif life == "DOWN":
		state = " · ล้ม (%d)" % row.episode.budget
	elif life == "DEAD":
		state = " · เสียชีวิต"
	elif life == "UNAVAILABLE":
		state = " · ไม่พร้อม"
	elif row.get("guard") != null:
		state = " · การ์ด"
	card.health.max_value = row.max_hp
	card.health.value = row.hp
	card.state.text = "HP %d/%d%s" % [row.hp, row.max_hp, state]
	card.resources.text = ""
	if row.has("role"):
		card.resources.text = "ช่วยให้ลุก %d" % row.rescue_uses
		if row.help_uses != null:
			card.resources.text = "HELP %d  ·  %s" % [row.help_uses, card.resources.text]
	actor.root.visible = not retreated and life != "UNAVAILABLE"
	actor.root.modulate = Color.WHITE
	actor.sprite.rotation = 0.0
	if life == "DOWN" or life == "DEAD":
		actor.root.modulate = Color("#a3a6b5") if life == "DOWN" else Color("#606167")
		actor.sprite.rotation = -0.32 if life == "DOWN" else -1.10


func present(events: Array) -> Dictionary:
	var reaction: Dictionary = {}
	for event in events:
		match event.kind:
			"INTENT":
				var token: Dictionary = event.token
				_intent.text = "%s  ·  %s → %s" % [NAMES[token.actor_id], ACTIONS[token.kind], NAMES[token.target_id]]
				_append(_intent.text)
				if event.view.decision != null:
					_report_decision(event.view.decision)
			"IMPACT":
				reaction = _report_effect(event)
			"TERMINAL":
				_append("%s [%s]" % [OUTCOMES.get(event.view.outcome.result, event.view.outcome.result), event.view.outcome.reason])
			"COMPLETION":
				_append("%s · จบการกระทำ #%d" % [NAMES[event.token.actor_id], event.receipt.action_id])
			"ROUND_CLOSED":
				var exhausted: bool = event.view.diagnostic == "DEMO_LIMIT_REACHED"
				var closed := "ปิดรอบ %d%s" % [event.identity.round_id - int(not exhausted),
					" · ครบ 6 รอบ" if exhausted else ""]
				_append(closed)
				var changes: Dictionary = event.view.boundary_changes
				var results := _report_changes(changes)
				if not results.is_empty():
					_show_feedback("  |  ".join(results))
				_intent.text = closed
				for clock in changes.clocks:
					_append("%s · เวลาช่วยให้ลุก %d → %d" % [NAMES[clock.actor_id], clock.before_budget, clock.after_budget])
			"RESET":
				_record_feedback("เริ่มใหม่ · รุ่นที่ %d" % event.identity.generation)
	return reaction


func _report_decision(decision: Dictionary) -> void:
	var code: String = decision.decision_reason.code
	var reason: String = DECISIONS.get(code, Messages.message(code))
	var baseline: Dictionary = decision.baseline
	var relation: String = Messages.message(decision.guidance_relation.response)
	if decision.guidance_relation.response == "NONE":
		relation = "ไม่มีคำชี้นำ"
	var detail: String = " · " + Messages.message(decision.guidance_relation.reason)
	if decision.guidance_relation.reason == "M404_SITUATION_PRIORITY":
		detail = " · ให้ความสำคัญกับสถานการณ์ตรงหน้า"
	elif decision.guidance_relation.reason in ["M404_GUIDANCE_NOT_APPLICABLE", "NONE", "NO_GUIDANCE"]:
		detail = ""
	_append("  %s · เดิม %s → %s · %s%s" % [reason, ACTIONS[baseline.action], NAMES[baseline.target_id], relation, detail])


func _report_effect(event: Dictionary) -> Dictionary:
	var effect: Dictionary = event.effect
	if effect.status == "SKIPPED":
		var code: String = effect.reason.trim_prefix("M405_")
		var reason: String = Messages.message(code)
		if code == "HELP_NO_HEAL":
			reason = "HP เต็มแล้ว"
		_record_feedback("ข้ามผล · %s [%s]" % [reason, code])
		return {}
	var guarded: bool = false
	if effect.hp_delta < 0:
		for row in event.view.party:
			if row.actor_id == effect.target_id and row.guard != null:
				guarded = true
		for change in effect.guards:
			if change.actor_id == effect.target_id and change.before != null:
				guarded = true
	var results: Array[String] = []
	if effect.hp_delta != 0:
		var hp := "%s · HP %+d%s" % [NAMES[effect.target_id], effect.hp_delta, " · การ์ดลดแรงโจมตี" if guarded else ""]
		_append(hp)
		results.append(hp)
	for resource in effect.resources:
		_append("%s · ใช้ %s (%d → %d)" % [NAMES[resource.actor_id], resource.resource, resource.before, resource.after])
	results.append_array(_report_changes(effect))
	if not results.is_empty():
		_show_feedback("  |  ".join(results))
	return {"hit": effect.hp_delta < 0, "guarded": guarded}


func _report_changes(changes: Dictionary) -> Array[String]:
	var results: Array[String] = []
	for guard in changes.guards:
		results.append("%s · %s" % [NAMES[guard.actor_id], GUARD_CAUSES[guard.cause]])
	for change in changes.lifecycle:
		var state: String
		match change.after_life:
			"DOWN": state = "ล้ม"
			"DEAD": state = "เสียชีวิต"
			_: state = "ถอนตัว" if change.after_participation == "RETREATED" else "ลุกขึ้นแล้ว"
		results.append("%s · %s" % [NAMES[change.actor_id], state])
	for message in results:
		_append(message)
	return results


func play(token: Dictionary, impact: Callable, complete: Callable) -> void:
	# RESCUE and RETREAT use a short stationary intent pose. Their result and the
	# target's visual state are applied only by present()/render() after IMPACT.
	_motion.play_action(self, token.actor_id, token.target_id, token.kind,
		_actors[token.actor_id], _actors[token.target_id], MOTION_SETTINGS, impact, complete)


func reset() -> void:
	_motion.cancel()
	_input_identity = {}
	_log.text = ""
	_log_panel.hide()
	_log_toggle.text = "บันทึกการต่อสู้ [L]"
	_log_return_focus = null
	_follow_log = true
	_shown_diagnostic = ""
	_status.text = ""
	_intent.text = "พร้อมเริ่มการต่อสู้"
	_feedback.text = ""
	_commands.hide()
	_guidance_row.hide()
	_exit.hide()
	_restart.disabled = true
	_target.select(-1)
	_focus_target.select(-1)
	for actor in _actors.values():
		actor.root.position = actor.home
		actor.sprite.position = actor.sprite_home
		actor.sprite.scale = actor.scale
		actor.sprite.modulate = actor.tint


func report_command(action: String, target: String) -> void:
	_intent.text = "Player เลือก %s → %s" % [ACTIONS[action], NAMES[target]]
	_append(_intent.text)


func report_unavailable(actor_id: String) -> void:
	_record_feedback("%s · ข้ามคิว ผู้กระทำไม่พร้อม" % NAMES[actor_id])


func report_error(reason: String) -> void:
	_record_feedback("คำขอถูกปฏิเสธ [%s]" % reason)


func _record_feedback(message: String) -> void:
	_append(message)
	_show_feedback(message)


func _show_feedback(message: String) -> void:
	_feedback.text = "ล่าสุด  ·  " + message


func _append(message: String) -> void:
	_log.text += ("\n" if not _log.text.is_empty() else "") + message


func _emit_command(action: String, target: String) -> void:
	if _commands.visible:
		command_pressed.emit(action, target, _input_identity.duplicate())


func _emit_guidance() -> void:
	if _guidance_row.visible:
		var kind := _selected(_guidance)
		guidance_pressed.emit(kind, _selected(_focus_target) if kind == "FOCUS_TARGET" else "", _input_identity.duplicate())


func _update_focus_target() -> void:
	_focus_target.visible = _selected(_guidance) == "FOCUS_TARGET"
	_send_guidance.disabled = _focus_target.visible and _focus_target.selected == -1


func _update_targets(picker: OptionButton, enemies: Array) -> void:
	var previous := _selected(picker)
	var ids: Array = []
	for row in enemies:
		if row.available:
			ids.append(row.actor_id)
	var existing: Array = []
	for i in picker.item_count:
		existing.append(picker.get_item_metadata(i))
	if ids == existing and (ids.is_empty() or picker.selected != -1):
		return
	picker.clear()
	for id in ids:
		picker.add_item(NAMES[id])
		picker.set_item_metadata(picker.item_count - 1, id)
	if not ids.is_empty():
		picker.select(maxi(0, ids.find(previous)))


func _selected(picker: OptionButton) -> String:
	return "" if picker.selected == -1 else picker.get_item_metadata(picker.selected)


func _panel(bounds: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	_place(panel, bounds)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#192626")
	style.border_color = Color("#45615b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _place(control: Control, bounds: Rect2) -> void:
	add_child(control)
	control.position = bounds.position
	control.size = bounds.size


func _label(parent: Control, caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, node_name: String, caption: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = Vector2(100, 32)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button
