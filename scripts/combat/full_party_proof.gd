extends Control

# Presentation owns nodes, motion and callback lifetime; Encounter owns all gameplay.
const Encounter = preload("res://scripts/combat/full_party_encounter.gd")
const COMBAT_SPEED_SCALE: float = 0.70
const SHORT_LUNGE_DISTANCE: float = 44.0
const HOMES: Dictionary = {
	"npc_01": Vector2(320, 480), "npc_02": Vector2(405, 435),
	"npc_03": Vector2(475, 509), "player": Vector2(570, 465),
	"enemy_a": Vector2(970, 506), "enemy_b": Vector2(1100, 424)
}
const NAMES: Dictionary = {"player": "Player", "npc_01": "NPC1", "npc_02": "NPC2",
	"npc_03": "NPC3", "enemy_a": "Enemy A", "enemy_b": "Enemy B"}
const PRESETS: Array[Dictionary] = [
	{"name": "S1 — Normal Full Party", "hp": {}, "targets": {}},
	{"name": "S2 — Player Needs HELP", "hp": {"player": 6}, "targets": {}},
	{"name": "S3 — NPC Self-DEFEND", "hp": {"npc_01": 3}, "targets": {"enemy_a": "npc_01"}},
	{"name": "S4 — Multiple HELP", "hp": {"player": 1}, "targets": {}},
	{"name": "S5 — A Falls / B Alive", "hp": {"enemy_a": 5}, "targets": {}},
	{"name": "S6a — Victory", "hp": {"enemy_a": 5, "enemy_b": 0}, "targets": {}},
	{"name": "S6b — Defeat", "hp": {"player": 1, "npc_01": 0, "npc_02": 0, "npc_03": 0}, "targets": {}},
	{"name": "S7 — Unavailable Slots / Restart", "hp": {"npc_01": 0, "enemy_a": 0}, "targets": {}}
]
const REASONS: Dictionary = {
	"PLAYER_COMMAND": "Player chose this action.",
	"ENEMY_DECLARED_TARGET": "Follow the target declared for this round.",
	"ATTACK_AVAILABLE_ENEMY": "An enemy is ready. I will attack.",
	"PLAYER_LOW_HP_HELP": "Player is badly hurt. I will use my HELP.",
	"SELF_LOW_HP_THREAT": "I am badly hurt and targeted. I will protect myself.",
	"SELF_LETHAL_THREAT": "The next declared hit could fell me. I will defend.",
	"HELP_UNAVAILABLE_ATTACK": "My HELP is spent. I will attack.",
	"ACTOR_UNAVAILABLE": "Unable to act; skip this slot.",
	"NO_LIVING_ENEMY": "No available enemy remains.",
	"PLAYER_DEFEATED": "Player is unavailable."
}
var encounter = Encounter.new()
var scenario_index: int = 0
var epoch: int = 0
var phase: String = "READY"
var busy: bool = false
var token: Dictionary = {}
var motion: Tween
var actors: Dictionary = {}
var hp_labels: Dictionary = {}
var intent_labels: Dictionary = {}
var popups: Dictionary = {}
var scenario_picker: OptionButton
var target_picker: OptionButton
var attack_button: Button
var defend_button: Button
var restart_button: Button
var decision_label: Label
var feedback: Label
var state_label: Label
var log_label: RichTextLabel


func _ready() -> void:
	_build_ui()
	restart_scenario()


func _label(at: Vector2, dimensions: Vector2, font_size: int = 18) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(caption: String, x: float, width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = Vector2(x, 62)
	button.size = Vector2(width, 38)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("202c30")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var ground := ColorRect.new()
	ground.position = Vector2(0, 350)
	ground.size = Vector2(1280, 202)
	ground.color = Color("403a30")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	_label(Vector2(24, 12), Vector2(1232, 36), 25).text = "WANDERER / FULL PARTY — Player chooses; companions decide at their slot"
	scenario_picker = OptionButton.new()
	scenario_picker.position = Vector2(24, 62)
	scenario_picker.size = Vector2(340, 38)
	for preset in PRESETS:
		scenario_picker.add_item(preset.name)
	scenario_picker.item_selected.connect(select_scenario)
	add_child(scenario_picker)
	attack_button = _button("ATTACK", 380, 120, player_command.bind("ATTACK"))
	defend_button = _button("DEFEND", 510, 120, player_command.bind("DEFEND"))
	target_picker = OptionButton.new()
	target_picker.position = Vector2(646, 62)
	target_picker.size = Vector2(200, 38)
	add_child(target_picker)
	restart_button = _button("Restart Scenario", 864, 190, restart_scenario)
	state_label = _label(Vector2(24, 108), Vector2(1232, 28), 18)
	decision_label = _label(Vector2(24, 140), Vector2(1232, 58), 18)
	var row: int = 0
	for id in ["npc_01", "npc_02", "npc_03"]:
		intent_labels[id] = _label(Vector2(24, 202 + row * 27), Vector2(1232, 27), 17)
		row += 1
	feedback = _label(Vector2(24, 286), Vector2(1232, 32), 21)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var textures: Dictionary = {
		"player": preload("res://assets/sprites/characters/player/battle/idle/player_idle_01.png"),
		"npc_01": preload("res://assets/sprites/characters/npc_01/battle/idle/npc_01_idle.png"),
		"npc_02": preload("res://assets/sprites/characters/npc_02/battle/idle/npc_02_idle.png"),
		"npc_03": preload("res://assets/sprites/characters/npc_03/battle/idle/npc_03_idle.png"),
		"enemy_a": preload("res://assets/sprites/enemies/enemy_01/battle/idle/enemy_01_idle.png"),
		"enemy_b": preload("res://assets/sprites/enemies/enemy_01/battle/idle/enemy_01_idle.png")
	}
	var field := Node2D.new()
	field.y_sort_enabled = true
	add_child(field)
	for id in HOMES:
		var actor := Sprite2D.new()
		actor.texture = textures[id]
		actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		actor.scale = Vector2(2.5, 2.5)
		actor.position = HOMES[id]
		actor.offset.y = -actor.texture.get_height() / 2.0
		field.add_child(actor)
		actors[id] = actor
		popups[id] = _label(HOMES[id] + Vector2(-80, 8), Vector2(160, 28), 22)
		popups[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Fixed HUD columns avoid overlapping HP text in the compact formation.
	var column: int = 0
	for id in ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"]:
		hp_labels[id] = _label(Vector2(24 + column * 207, 558), Vector2(202, 54), 15)
		column += 1
	log_label = RichTextLabel.new()
	log_label.position = Vector2(24, 622)
	log_label.size = Vector2(1232, 86)
	log_label.add_theme_font_size_override("normal_font_size", 16)
	log_label.scroll_following = true
	add_child(log_label)


func select_scenario(index: int) -> void:
	if busy or index < 0 or index >= PRESETS.size():
		return
	scenario_index = index
	scenario_picker.select(index)
	restart_scenario()


func restart_scenario() -> void:
	epoch += 1
	if motion != null:
		motion.kill()
	motion = null
	var fixture: Dictionary = Encounter.prototype_fixture()
	for entry in fixture.actors:
		var id: String = entry.definition.actor_id
		entry.definition.display_name = NAMES[id]
		entry.initial_hp = PRESETS[scenario_index].hp.get(id, entry.initial_hp)
	if not encounter.restart(fixture):
		push_error("Full party preset rejected")
		return
	token = {}
	busy = false
	phase = "READY" if encounter.snapshot().result.is_empty() else encounter.snapshot().result
	_reset_visuals()
	feedback.text = ""
	decision_label.text = "Choose Player ATTACK or DEFEND. Enemy targets: " + str(PRESETS[scenario_index].targets) + " (default: Player)"
	_waiting_intents()
	target_picker.clear()
	log_label.clear()
	_log(PRESETS[scenario_index].name + " / fresh encounter")
	_refresh()


func _reset_visuals() -> void:
	for id in actors:
		actors[id].position = HOMES[id]
		actors[id].modulate = Color.WHITE
		actors[id].rotation = 0.0
		popups[id].text = ""
		popups[id].position = HOMES[id] + Vector2(-80, 8)


func _waiting_intents() -> void:
	for id in intent_labels:
		intent_labels[id].text = NAMES[id] + " / Waiting to decide"


func _refresh() -> void:
	var view: Dictionary = encounter.snapshot()
	for id in hp_labels:
		var actor: Dictionary = view.actors[id]
		hp_labels[id].text = "%s [%s]\nHP %d/%d  %s%s" % [NAMES[id], id, actor.current_hp, actor.max_hp,
			"HELP %d  " % view.help_uses[id] if view.help_uses.has(id) else "",
			"GUARD" if view.guards.has(id) else ("Ready" if actor.can_act else "Unavailable")]
		actors[id].self_modulate = Color.WHITE if actor.can_act else Color("777777")
	var selected: String = ""
	if target_picker.selected >= 0:
		selected = str(target_picker.get_item_metadata(target_picker.selected))
	target_picker.clear()
	for id in view.available_enemy_ids:
		target_picker.add_item(NAMES[id])
		target_picker.set_item_metadata(target_picker.item_count - 1, id)
		if id == selected:
			target_picker.select(target_picker.item_count - 1)
	var ready: bool = not busy and phase == "READY" and view.command_ready and view.result.is_empty()
	attack_button.disabled = not ready or target_picker.item_count == 0
	defend_button.disabled = not ready
	target_picker.disabled = not ready
	scenario_picker.disabled = busy
	state_label.text = "Round %d / %s%s / Completed %d / Speed 0.70 / Lunge 44px" % [
		view.round_id, phase, " / " + view.result if not view.result.is_empty() else "", view.round_completions]


func _log(message: String) -> void:
	log_label.append_text(message + "\n")


func player_command(action: String) -> void:
	if busy or phase != "READY" or not encounter.snapshot().command_ready:
		return
	var target: String = ""
	if action == "ATTACK":
		if target_picker.selected < 0:
			return
		target = str(target_picker.get_item_metadata(target_picker.selected))
		if not encounter.available_enemy_ids().has(target):
			_refresh()
			return
	var reply: Dictionary = encounter.begin_round(action, target, PRESETS[scenario_index].targets)
	if reply.status != "STARTED":
		return
	busy = true
	phase = "HANDOFF"
	_waiting_intents()
	_log("Round %d / Player %s %s" % [encounter.snapshot().round_id, action, target])
	_advance()


func _advance() -> void:
	if not busy or phase != "HANDOFF" or not token.is_empty():
		return
	var view: Dictionary = encounter.snapshot()
	if not view.round_running:
		busy = false
		phase = "READY" if view.result.is_empty() else view.result
		_log("Round completion count %d / %s" % [view.round_completions, phase])
		_refresh()
		return
	token = encounter.begin_next_action()
	if not token.has("decision"):
		push_error("Encounter did not supply a presentation slot")
		return
	phase = "WINDUP"
	var locked: Dictionary = token.duplicate(true)
	var decision: Dictionary = locked.decision
	var description: String = "%s [%s] → %s → %s / %s\n%s" % [NAMES[locked.actor_id], locked.actor_id,
		decision.action, decision.target_id if not decision.target_id.is_empty() else "none", decision.reason_code, REASONS.get(decision.reason_code, decision.reason_code)]
	decision_label.text = description
	if intent_labels.has(locked.actor_id):
		intent_labels[locked.actor_id].text = "%s → %s → %s / %s — %s" % [NAMES[locked.actor_id], decision.action,
			decision.target_id, decision.reason_code, REASONS.get(decision.reason_code, decision.reason_code)]
	_log(description.replace("\n", " / "))
	_refresh()
	motion = create_tween().set_speed_scale(COMBAT_SPEED_SCALE)
	if decision.action == "ATTACK":
		var direction: float = 1.0 if HOMES[locked.actor_id].x < HOMES[decision.target_id].x else -1.0
		motion.tween_property(actors[locked.actor_id], "position:x", HOMES[locked.actor_id].x + direction * SHORT_LUNGE_DISTANCE, 0.24)
	else:
		motion.tween_interval(0.24)
	motion.tween_callback(_impact.bind(epoch, locked))
	motion.tween_interval(0.42)
	for id in popups:
		motion.parallel().tween_property(popups[id], "position:y", HOMES[id].y - 16, 0.40)
	motion.tween_callback(_settle.bind(epoch, locked))
	motion.tween_property(actors[locked.actor_id], "position", HOMES[locked.actor_id], 0.22)
	motion.tween_callback(_finish.bind(epoch, locked))


# Check both lifetimes, full token identity, locked decision and phase at every boundary.
func _current(callback_epoch: int, locked: Dictionary, expected_phase: String, states: Array) -> bool:
	if not busy or callback_epoch != epoch or phase != expected_phase or token != locked:
		return false
	var view: Dictionary = encounter.snapshot()
	if not view.active_action or locked.get("generation") != view.generation:
		return false
	for key in ["encounter_id", "generation", "round_id", "action_id", "actor_id", "decision"]:
		if not locked.has(key) or locked[key] != view.locked_action.get(key):
			return false
	return view.locked_action.get("state") in states


func _impact(callback_epoch: int, locked: Dictionary) -> void:
	if not _current(callback_epoch, locked, "WINDUP", ["LOCKED"]):
		return
	var before: Dictionary = encounter.snapshot()
	var effect: Dictionary = encounter.resolve_action(locked)
	phase = "IMPACT"
	var after: Dictionary = encounter.snapshot()
	var target: String = locked.decision.target_id
	var text: String = "%s %s → %s / %s / HP %+d" % [NAMES[locked.actor_id], locked.decision.action,
		target, effect.get("reason_code", effect.status), effect.hp_delta]
	if before.actors.has(target):
		text += " / %d → %d" % [before.actors[target].current_hp, after.actors[target].current_hp]
	feedback.text = text
	_log(text)
	if intent_labels.has(locked.actor_id):
		intent_labels[locked.actor_id].text += " / %s HP %+d" % [effect.status, effect.hp_delta]
	if effect.status == "APPLIED":
		if effect.hp_delta != 0:
			actors[target].modulate = Color("9bffb3") if effect.hp_delta > 0 else Color("ff9d89")
			popups[target].text = "HP %+d" % effect.hp_delta
		elif locked.decision.action == "DEFEND":
			actors[locked.actor_id].modulate = Color("84cfff")
			popups[locked.actor_id].text = "GUARD"
	_refresh()


func _settle(callback_epoch: int, locked: Dictionary) -> void:
	if not _current(callback_epoch, locked, "IMPACT", ["RESOLVED", "SKIPPED"]):
		return
	phase = "SETTLING"
	_refresh()


func _finish(callback_epoch: int, locked: Dictionary) -> void:
	if not _current(callback_epoch, locked, "SETTLING", ["RESOLVED", "SKIPPED"]):
		return
	var reply: Dictionary = encounter.complete_action(locked)
	if reply.status != "COMPLETED":
		return
	_reset_visuals()
	token = {}
	phase = "HANDOFF"
	_advance()


func _exit_tree() -> void:
	epoch += 1
	if motion != null:
		motion.kill()
