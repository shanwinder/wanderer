extends Control

# Presentation adapter only: Encounter owns decisions, HP, costs and completion.
const Encounter = preload("res://scripts/npc/npc_proof_encounter.gd")
const COMBAT_SPEED_SCALE: float = 0.70
const SHORT_LUNGE_DISTANCE: float = 44.0
const PRESETS: Array[Dictionary] = [
	{"name": "S1 — Normal Combat", "state": {}},
	{"name": "S2 — Player Needs Help", "state": {"player_hp": 6}},
	{"name": "S3 — NPC Under Threat", "state": {"npc_hp": 3, "incoming_target_id": "npc"}},
	{"name": "S4 — HELP Unavailable", "state": {"player_hp": 6, "help_uses_remaining": 0}},
	{"name": "S6 — Guidance Conflict", "state": {"player_hp": 6, "guidance": "ATTACK"}},
	{"name": "S7 — Both at Risk", "state": {"player_hp": 6, "npc_hp": 3, "incoming_target_id": "npc"}}
]
const REASONS: Dictionary = {
	"ATTACK_AVAILABLE_ENEMY": "The enemy is still a threat. I will attack.",
	"SELF_LOW_HP_THREAT": "I am badly hurt and being targeted. I must protect myself first.",
	"SELF_LETHAL_THREAT": "That incoming hit could fell me. I must defend myself.",
	"PLAYER_LOW_HP_HELP": "You are badly hurt. I will help you first.",
	"HELP_UNAVAILABLE_ATTACK": "HELP is unavailable now, so I will attack instead.",
	"ACTOR_UNAVAILABLE": "I cannot act. Skip my slot.",
	"NO_LIVING_ENEMY": "There is no living enemy.",
	"PLAYER_DEFEATED": "The Player has fallen."
}
const HOMES: Dictionary = {"player": Vector2(330, 440), "npc": Vector2(540, 440), "enemy_a": Vector2(990, 440)}

var encounter = Encounter.new()
var scenario_index: int = 0
var busy: bool = false
var phase: String = "READY"
var epoch: int = 0
var motion: Tween
var token: Dictionary = {}
var actors: Dictionary = {}
var hp_labels: Dictionary = {}
var feedback: Label
var decision_label: Label
var state_label: Label
var intent_label: Label
var log_label: RichTextLabel
var scenario_picker: OptionButton
var run_button: Button


func _ready() -> void:
	_build_ui()
	restart_scenario()


func _label(at: Vector2, dimensions: Vector2, font_size: int = 20) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("202c30")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var ground := ColorRect.new()
	ground.position = Vector2(0, 420)
	ground.size = Vector2(1280, 92)
	ground.color = Color("403a30")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	_label(Vector2(28, 12), Vector2(1220, 36), 26).text = "WANDERER / NPC AUTONOMY — PLAYABLE PROOF"
	_label(Vector2(28, 52), Vector2(1220, 28), 16).text = "Post-Player snapshot · Presets change the situation; the NPC chooses its action · 0.70 speed / 44px lunge"
	scenario_picker = OptionButton.new()
	scenario_picker.position = Vector2(28, 94)
	scenario_picker.size = Vector2(380, 40)
	for preset in PRESETS:
		scenario_picker.add_item(preset.name)
	scenario_picker.item_selected.connect(select_scenario)
	add_child(scenario_picker)
	run_button = Button.new()
	run_button.text = "Run NPC Turn"
	run_button.position = Vector2(430, 94)
	run_button.size = Vector2(200, 40)
	run_button.pressed.connect(run_turn)
	add_child(run_button)
	var restart_button := Button.new()
	restart_button.text = "Restart Scenario"
	restart_button.position = Vector2(650, 94)
	restart_button.size = Vector2(200, 40)
	restart_button.pressed.connect(restart_scenario)
	add_child(restart_button)
	decision_label = _label(Vector2(28, 148), Vector2(1220, 88), 21)
	intent_label = _label(Vector2(28, 244), Vector2(1220, 34), 18)
	var textures: Dictionary = {
		"player": preload("res://assets/sprites/characters/player/battle/idle/player_idle_01.png"),
		"npc": preload("res://assets/sprites/characters/npc_01/battle/idle/npc_01_idle.png"),
		"enemy_a": preload("res://assets/sprites/enemies/enemy_01/battle/idle/enemy_01_idle.png")
	}
	for id in HOMES:
		var actor := Sprite2D.new()
		actor.texture = textures[id]
		actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		actor.scale = Vector2(2.5, 2.5)
		actor.position = HOMES[id]
		actor.offset.y = -actor.texture.get_height() / 2.0
		add_child(actor)
		actors[id] = actor
		hp_labels[id] = _label(HOMES[id] + Vector2(-100, 12), Vector2(210, 55), 19)
	feedback = _label(Vector2(28, 288), Vector2(1220, 42), 24)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label = _label(Vector2(28, 514), Vector2(1220, 32), 19)
	log_label = RichTextLabel.new()
	log_label.position = Vector2(28, 555)
	log_label.size = Vector2(1220, 147)
	log_label.add_theme_font_size_override("normal_font_size", 17)
	log_label.scroll_following = true
	add_child(log_label)


func select_scenario(index: int) -> void:
	if index < 0 or index >= PRESETS.size():
		return
	scenario_index = index
	scenario_picker.select(index)
	restart_scenario()


func restart_scenario() -> void:
	# Kill every scheduled visual/effect boundary before replacing the data generation.
	epoch += 1
	if motion != null:
		motion.kill()
	motion = null
	encounter.restart(PRESETS[scenario_index].state)
	token = {}
	busy = false
	phase = "READY"
	_reset_actors()
	feedback.text = ""
	decision_label.text = "NPC has not decided yet. Run the slot to observe its choice."
	log_label.clear()
	_log(PRESETS[scenario_index].name + " / fresh post-Player snapshot")
	_refresh()


func _reset_actors() -> void:
	for id in actors:
		actors[id].position = HOMES[id]
		actors[id].modulate = Color.WHITE
		actors[id].rotation = 0.0


func _refresh() -> void:
	var view: Dictionary = encounter.inspect()
	var state: Dictionary = view.state
	hp_labels.player.text = "Player\nHP %d/%d" % [state.player_hp, state.player_max_hp]
	hp_labels.npc.text = "NPC Companion\nHP %d/%d" % [state.npc_hp, state.npc_max_hp]
	hp_labels.enemy_a.text = "Enemy A\nHP %d/%d" % [state.enemy_hp, state.enemy_max_hp]
	intent_label.text = "Declared enemy response: %s / damage %d   |   Guidance: %s (suggestion only)" % [
		state.incoming_target_id if state.incoming_target_id != "" else "none", state.incoming_damage, state.guidance]
	state_label.text = "Round %d · HELP remaining %d · %s · Completed rounds %d%s" % [
		view.round, state.help_uses_remaining, phase, view.round_completions,
		" · " + view.result if not view.result.is_empty() else ""]
	run_button.disabled = busy or not view.result.is_empty()
	scenario_picker.disabled = busy


func _log(message: String) -> void:
	log_label.append_text(message + "\n")


func run_turn() -> void:
	if busy or not encounter.inspect().result.is_empty():
		return
	token = encounter.begin_npc_slot()
	if not token.has("decision"):
		_log("Slot: " + str(token))
		_refresh()
		return
	busy = true
	phase = "NPC_" + token.decision.action
	var decision: Dictionary = token.decision
	decision_label.text = "%s → %s\n%s" % [decision.action,
		decision.target_id if decision.target_id != "" else "none",
		REASONS.get(decision.reason_code, decision.reason_code)]
	_log("Decision %s → %s / %s / snapshot %s" % [decision.action, decision.target_id,
		decision.reason_code, str(decision.reason_details)])
	_refresh()
	var generation: int = epoch
	var locked: Dictionary = token.duplicate(true)
	motion = create_tween().set_speed_scale(COMBAT_SPEED_SCALE)
	match decision.action:
		"ATTACK":
			motion.tween_property(actors.npc, "position:x", HOMES.npc.x + SHORT_LUNGE_DISTANCE, 0.30)
		"DEFEND":
			motion.tween_property(actors.npc, "modulate", Color("84cfff"), 0.30)
		"HELP":
			motion.tween_property(actors.npc, "modulate", Color("9bffb3"), 0.30)
		_:
			motion.tween_interval(0.30)
	motion.tween_callback(_npc_impact.bind(generation, locked))
	motion.tween_interval(0.65)
	motion.tween_property(actors.npc, "position", HOMES.npc, 0.30)
	motion.tween_callback(_enemy_start.bind(generation, locked))


func _current(generation: int, locked: Dictionary) -> bool:
	var view: Dictionary = encounter.inspect()
	return busy and generation == epoch and locked.get("generation") == view.generation \
		and locked.get("action_id") == token.get("action_id")


func _npc_impact(generation: int, locked: Dictionary) -> void:
	if not _current(generation, locked) or phase != "NPC_" + locked.decision.action:
		return
	if encounter.inspect().active.resolved:
		return
	var effect: Dictionary = encounter.resolve_npc(locked)
	_log("NPC effect: " + str(effect))
	feedback.text = "%s → %s: %s / HP %+d / HELP uses %+d" % [locked.decision.action,
		locked.decision.target_id, effect.status, effect.get("hp_delta", 0), effect.get("help_use_delta", 0)]
	if effect.status == "APPLIED":
		if locked.decision.action == "ATTACK":
			actors.enemy_a.modulate = Color("ff9d89")
		elif locked.decision.action == "HELP":
			actors.player.modulate = Color("9bffb3")
	_refresh()


func _enemy_start(generation: int, locked: Dictionary) -> void:
	if not _current(generation, locked) or phase == "ENEMY_RESPONSE" or phase == "SETTLING":
		return
	var view: Dictionary = encounter.inspect()
	phase = "ENEMY_RESPONSE"
	_refresh()
	motion = create_tween().set_speed_scale(COMBAT_SPEED_SCALE)
	if view.result.is_empty() and view.state.incoming_target_id != "" \
		and view.state.incoming_damage > 0 and view.state[view.state.incoming_target_id + "_hp"] > 0:
		feedback.text = "Enemy A → " + view.state.incoming_target_id
		motion.tween_property(actors.enemy_a, "position:x", HOMES.enemy_a.x - SHORT_LUNGE_DISTANCE, 0.30)
	else:
		motion.tween_interval(0.10)
	motion.tween_callback(_enemy_impact.bind(generation, locked))
	motion.tween_interval(0.65)
	motion.tween_property(actors.enemy_a, "position", HOMES.enemy_a, 0.30)
	motion.tween_callback(_finish.bind(generation, locked))


func _enemy_impact(generation: int, locked: Dictionary) -> void:
	if not _current(generation, locked) or phase != "ENEMY_RESPONSE":
		return
	if encounter.inspect().active.completed:
		return
	var before: Dictionary = encounter.inspect()
	# Existing API atomically resolves enemy + round here, at the enemy impact.
	var completion: Dictionary = encounter.complete_npc(locked)
	var after: Dictionary = encounter.inspect()
	phase = "SETTLING"
	feedback.text = "Enemy response: Player HP %+d / NPC HP %+d" % [
		after.state.player_hp - before.state.player_hp, after.state.npc_hp - before.state.npc_hp]
	_log(feedback.text + " / " + completion.status + " / " + after.result)
	if after.state.player_hp < before.state.player_hp:
		actors.player.modulate = Color("ff9d89")
	if after.state.npc_hp < before.state.npc_hp:
		actors.npc.modulate = Color("84cfff") if before.self_defend else Color("ff9d89")
	_refresh()


func _finish(generation: int, locked: Dictionary) -> void:
	if not _current(generation, locked) or phase != "SETTLING":
		return
	busy = false
	phase = "ROUND_COMPLETE" if encounter.inspect().result.is_empty() else encounter.inspect().result
	_reset_actors()
	_refresh()
	_log("Presentation complete / " + state_label.text)


func _exit_tree() -> void:
	epoch += 1
	if motion != null:
		motion.kill()
