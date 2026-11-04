extends Control

const CombatTurnFlow = preload("res://scripts/combat/combat_turn_flow.gd")
const CombatTargets = preload("res://scripts/combat/combat_targets.gd")
const FullPartyEncounter = preload("res://scripts/combat/full_party_encounter.gd")
const CombatPresentationAdapter = preload("res://scripts/combat/combat_presentation_adapter.gd")

# Chosen by the inherited entry BEFORE _ready; a live session cannot change authority.
enum SessionMode { LEGACY, AUTONOMOUS }
@export var session_mode: SessionMode = SessionMode.LEGACY:
	set(value):
		if not is_node_ready():
			session_mode = value

var encounter # Autonomous only. No Legacy queue/targets/HP are initialized in that mode.
var autonomous_token: Dictionary = {}
var autonomous_views: Dictionary = {}
var autonomous_hp_labels: Dictionary = {}
var autonomous_intents: Dictionary = {}
var autonomous_decision_label: Label
var autonomous_effect_label: Label
var autonomous_scenario_picker: OptionButton
var autonomous_scenario: int = 0
var autonomous_selected_target: String = ""

const AUTONOMOUS_NAMES: Dictionary = {"player": "Player", "npc_01": "NPC1", "npc_02": "NPC2",
	"npc_03": "NPC3", "enemy_a": "Enemy A", "enemy_b": "Enemy B"}
const AUTONOMOUS_REASONS: Dictionary = {
	"PLAYER_COMMAND": "Player chose this action.",
	"ENEMY_DECLARED_TARGET": "Following this round's declared target.",
	"ATTACK_AVAILABLE_ENEMY": "Attack the first available enemy.",
	"PLAYER_LOW_HP_HELP": "Player is badly hurt; use my HELP.",
	"SELF_LOW_HP_THREAT": "Low HP and targeted; protect myself.",
	"SELF_LETHAL_THREAT": "The declared hit could fell me; defend.",
	"HELP_UNAVAILABLE_ATTACK": "HELP unavailable; attack an enemy.",
	"ACTOR_UNAVAILABLE": "Unable to act; skip this slot.",
	"NO_LIVING_ENEMY": "No available enemy remains.",
	"PLAYER_DEFEATED": "Player is unavailable."
}
# Explicit opt-in test fixtures, never final Main Combat balance.
const AUTONOMOUS_SCENARIOS: Array[Dictionary] = [
	{"name": "Normal opt-in (NPC 10/10/10)", "hp": {}, "targets": {}},
	{"name": "Player needs HELP", "hp": {"player": 6}, "targets": {}},
	{"name": "NPC self-DEFEND", "hp": {"npc_01": 3}, "targets": {"enemy_a": "npc_01", "enemy_b": "npc_01"}},
	{"name": "Multiple HELP", "hp": {"player": 1}, "targets": {}},
	{"name": "A falls / B alive", "hp": {"enemy_a": 5}, "targets": {}},
	{"name": "Victory", "hp": {"enemy_a": 5, "enemy_b": 0}, "targets": {}},
	{"name": "Defeat", "hp": {"player": 1, "npc_01": 0, "npc_02": 0, "npc_03": 0}, "targets": {}},
	{"name": "Unavailable slots", "hp": {"npc_01": 0, "enemy_a": 0}, "targets": {}},
	{"name": "M2C HP fixture (10/7/3)", "hp": {"npc_02": 7, "npc_03": 3}, "targets": {}},
	{"name": "B falls / A alive", "hp": {"enemy_b": 5}, "targets": {}}
]

# 1.0 = จังหวะเดิม, 0.70 = Motion/Feedback ใช้เวลานานขึ้นประมาณ 43%
# ใช้ค่ากลางเดียวกันทุก Tween เพื่อปรับความเร็วในการทดลองได้จาก Inspector
@export_range(0.45, 1.0, 0.05) var combat_speed_scale: float = 0.70


# -----------------------------------------------------------------------------
# ค่าคงที่ของการต่อสู้
# -----------------------------------------------------------------------------
# ค่าคงที่ (const) คือค่าที่จะไม่เปลี่ยนระหว่างที่เกมกำลังทำงาน
# ในต้นแบบนี้เรากำหนดตัวเลขไว้ตรง ๆ ก่อน เพื่อให้เข้าใจระบบได้ง่าย
const PLAYER_MAX_HP: int = 30
const ENEMY_MAX_HP: int = 15
const ENEMY_B_MAX_HP: int = 12

const PLAYER_ATTACK_DAMAGE: int = 5
# M1.5D-03: NPC ทำ Damage ต่ำแบบกำหนดตายตัวก่อนมี AI/สกิลจริง
const NPC_ATTACK_DAMAGE: int = 1
const ENEMY_ATTACK_DAMAGE: int = 3
const DEFEND_REDUCTION: int = 2

# M1.5E-02: ขยับ Root ของผู้โจมตีสั้น ๆ จาก Formation แล้วออกท่าที่ตำแหน่งนั้น
# Player / NPC ไปทางขวา (+X), Enemy A ไปทางซ้าย (-X)
# ห้ามเป้าหมายเดินเข้ามารับ Action — มีเพียง Recoil สั้น ๆ ณ Formation
const SHORT_LUNGE_DISTANCE: float = 44.0
const SHORT_LUNGE_TIME: float = 0.18
const SHORT_LUNGE_RETURN_TIME: float = 0.22
# เว้นจังหวะเล็กน้อยหลังแต่ละ Action เพื่อให้ผู้เล่นอ่านลำดับเทิร์นทัน
const ACTION_HANDOFF_PAUSE: float = 0.16
const GUARD_POSE_RAISE_TIME: float = 0.12
const GUARD_POSE_RETURN_TIME: float = 0.18

# M1.5E-04: Player Defend ออกท่า Brace สั้น ๆ โดยไม่ย้าย Root
const PLAYER_DEFEND_BRACE_TIME: float = 0.12
const PLAYER_DEFEND_HOLD_TIME: float = 0.08
const PLAYER_DEFEND_RECOVER_TIME: float = 0.16
const PLAYER_DEFEND_BRACE_OFFSET: Vector2 = Vector2(-3.0, -2.0)
const PLAYER_DEFEND_BRACE_SCALE: Vector2 = Vector2(1.02, 0.99)
const PLAYER_DEFEND_BRACE_TINT: Color = Color(0.80, 0.92, 1.0, 1.0)
const ENEMY_RECOIL_DISTANCE: float = 18.0
const ENEMY_HIT_TIME: float = 0.14
const HIT_HOLD_TIME: float = 0.08
const PLAYER_HIT_RECOIL_DISTANCE: float = 14.0
# M1.5E-05: เมื่อ Player หรือ NPC2 ช่วย Guard ให้สะดุ้งน้อยกว่ารับ Hit ปกติ
const GUARDED_HIT_RECOIL_DISTANCE: float = 5.0
const GUARDED_HIT_SQUASH: Vector2 = Vector2(1.01, 0.99)
const PLAYER_HIT_TIME: float = 0.14
const ENEMY_COUNTER_HOLD_TIME: float = 0.08

# M1.5C-03: Floating Damage และการกระพริบค่า HP
const DAMAGE_FLOAT_TIME: float = 0.85
const DAMAGE_FLOAT_HEIGHT: float = 45.0
const HP_FLASH_TIME: float = 0.50
const ENEMY_DAMAGE_COLOR: Color = Color(1.0, 0.78, 0.42, 1.0)
const PLAYER_DAMAGE_COLOR: Color = Color(1.0, 0.48, 0.48, 1.0)
const DEFEND_DAMAGE_COLOR: Color = Color(0.53, 0.84, 1.0, 1.0)

# M1.5C-04: ขยายตัวผู้ลงมือเล็กน้อย และบีบ-ขยายเป้าหมายเมื่อถูกปะทะ
# ปรับขนาดที่ Sprite เท่านั้น ไม่เปลี่ยน Root, Contact Shadow หรือระยะพุ่ง
const ACTIVE_SPRITE_SCALE_FACTOR: float = 1.03
const IMPACT_SPRITE_SQUASH: Vector2 = Vector2(1.04, 0.96)

# M1.5E-01: ท่าโจมตีด้วย Sprite ทดแทน Attack Art จริงแบบเรียบง่าย
# ขยับเฉพาะตำแหน่ง Sprite ใน Root ไม่ย้ายเงาหรือสร้าง Projectile
const ATTACK_POSE_WINDUP_DISTANCE: float = 6.0
const ATTACK_POSE_STRIKE_DISTANCE: float = 14.0
const ATTACK_POSE_WINDUP_TIME: float = 0.10
const ATTACK_POSE_STRIKE_TIME: float = 0.10

# M1.5C-05: Pixel-style Hit Spark แบบ Polygon สั้น ๆ (ไม่ต้องมี Texture)
const HIT_SPARK_DURATION: float = 0.22
const HIT_SPARK_START_SCALE: float = 0.8
const HIT_SPARK_END_SCALE: float = 1.15
const HIT_SPARK_ENEMY_OFFSET: Vector2 = Vector2(-55, -70)
const HIT_SPARK_PLAYER_OFFSET: Vector2 = Vector2(45, -72)

# NPC รักษาจังหวะเตรียม Action ก่อน Hit; Guard ไม่ออกจาก Formation
const NPC_STAGE_HOLD_TIME: float = 0.10
const NPC_ATTACK_HIT_TIME: float = 0.14
const NPC_ACTIVE_TINT: Color = Color(1.12, 1.08, 1.02, 1.0)

# M1.6A: นิยาม ATK/GUARD และกฎเลือก Intent อยู่ใน CombatTurnFlow
# ที่นี่เก็บเฉพาะค่าเชิงการต่อสู้/การนำเสนอของ Guard
const NPC_GUARD_REDUCTION: int = 1
const NPC_GUARD_ACTIVE_TINT: Color = Color(0.76, 0.90, 1.0, 1.0)
const NPC_INTENT_QUEUED_COLOR: Color = Color(0.72, 0.82, 0.80, 0.95)
const NPC_INTENT_ACTIVE_COLOR: Color = Color(1.0, 0.85, 0.55, 1.0)


# -----------------------------------------------------------------------------
# ตัวแปรสถานะปัจจุบันของการต่อสู้
# -----------------------------------------------------------------------------
# ตัวแปรเหล่านี้จะเปลี่ยนไปตามการกดปุ่มของผู้เล่น
var player_hp: Variant
var enemy_hp: Variant
var enemy_b_hp: Variant

# ใช้ตรวจว่าผู้เล่นเลือกตั้งรับในรอบนี้หรือไม่
var player_is_defending: bool = false

# ผลการต่อสู้เก็บไว้จนกว่า Action สุดท้ายจะเล่นจบแล้วค่อยแสดงแผง
var battle_result_player_won: bool = false
var battle_result_tween: Tween

# ใช้ป้องกันไม่ให้กดโจมตีต่อ หลังจากการต่อสู้จบแล้ว
var battle_is_over: bool = false

# ใช้แสดงหมายเลขรอบใน Combat Log
var turn_number: int = 1

# แยกการวางแผนคิวเทิร์นออกจาก Animation และผลลัพธ์ของการโจมตี
var turn_flow

# คัดเป้าหมายฝ่ายศัตรูก่อนเริ่ม Action แล้วเก็บ ID ไปกับคิวเทิร์น
var target_registry
var active_action_target_id: String = ""

# ล็อกคำสั่งระหว่าง Motion ทั้งสองฝ่าย เพื่อไม่ให้ HP คลาดเคลื่อน
var action_in_progress: bool = false
var presentation_adapter = CombatPresentationAdapter.new()
var action_tween: Tween
var player_home: Vector2
var enemy_home: Vector2
var enemy_b_home: Vector2
var player_sprite_base_scale: Vector2
var enemy_sprite_base_scale: Vector2
var enemy_b_sprite_base_scale: Vector2
var player_sprite_base_position: Vector2
var enemy_sprite_base_position: Vector2
var enemy_b_sprite_base_position: Vector2
var enemy_b_base_tint: Color

# เป้าหมายภาพที่กำลังถูกโจมตี/ออก Action; set ก่อนสร้าง Tween ทุกครั้ง
var active_enemy_id: String = ""
var active_enemy_root: Node2D
var active_enemy_sprite: Sprite2D
var active_enemy_home: Vector2
var active_enemy_sprite_base_scale: Vector2
var active_enemy_sprite_base_position: Vector2
var active_enemy_base_tint: Color
var active_enemy_label: Label

# จัดกลุ่ม Root และ Sprite ของ NPC เพื่อสลับ Action ตามลำดับแน่นอน
var npc_roots: Array[Node2D] = []
var npc_sprites: Array[Sprite2D] = []
var npc_home_positions: Array[Vector2] = []
var npc_home_tints: Array[Color] = []
var npc_sprite_base_positions: Array[Vector2] = []
var npc_action_index: int = 0
var npc_guard_bonus: int = 0
var npc_intent_labels: Array[Label] = []

# เก็บ Feedback ที่ยังแสดงอยู่ เพื่อให้ Restart ล้างได้อย่างปลอดภัย
var damage_popups: Array[Label] = []
var hit_sparks: Array[Polygon2D] = []
var player_hp_flash_tween: Tween
var enemy_hp_flash_tween: Tween


# -----------------------------------------------------------------------------
# การอ้างอิง Node จากฉาก
# -----------------------------------------------------------------------------
# @onready หมายถึง ให้หา Node เหล่านี้หลังจาก Scene ถูกสร้างเสร็จแล้ว
# เส้นทางต้องตรงกับ Node Tree ใน combat_prototype.tscn
@onready var player_label: Label = (
	$MainMargin/MainVBox/BattleRow/AlliesPanel/PlayerLabel
)

@onready var enemy_a_label: Label = (
	$MainMargin/MainVBox/BattleRow/EnemiesPanel/EnemyALabel
)
@onready var enemy_b_label: Label = (
	$MainMargin/MainVBox/BattleRow/EnemiesPanel/EnemyBLabel
)

@onready var combat_log: RichTextLabel = (
	$MainMargin/MainVBox/CombatLog
)
@onready var action_status_label: Label = $ActionStatusLabel
@onready var battle_result_panel: PanelContainer = $BattleResultPanel
@onready var battle_result_title: Label = $BattleResultPanel/ResultMargin/ResultVBox/ResultTitle
@onready var battle_result_detail: Label = $BattleResultPanel/ResultMargin/ResultVBox/ResultDetail

@onready var attack_button: Button = (
	$MainMargin/MainVBox/ActionRow/AttackButton
)

@onready var defend_button: Button = (
	$MainMargin/MainVBox/ActionRow/DefendButton
)
@onready var target_picker: OptionButton = $MainMargin/MainVBox/ActionRow/TargetPicker

@onready var restart_button: Button = (
	$MainMargin/MainVBox/ActionRow/RestartButton
)

# ตัวละครที่ทำ Motion ถูกย้ายไว้ใน Root แล้วตั้งแต่ M1.5B
@onready var player_root: Node2D = $Battlefield/PlayerRoot
@onready var enemy_root: Node2D = $Battlefield/EnemyARoot
@onready var enemy_b_root: Node2D = $Battlefield/EnemyBRoot
@onready var player_sprite: AnimatedSprite2D = $Battlefield/PlayerRoot/Player
@onready var enemy_sprite: Sprite2D = $Battlefield/EnemyARoot/EnemyA
@onready var enemy_b_sprite: Sprite2D = $Battlefield/EnemyBRoot/EnemyB
@onready var battlefield: Node2D = $Battlefield
@onready var npc1_root: Node2D = $Battlefield/Npc1Root
@onready var npc2_root: Node2D = $Battlefield/Npc2Root
@onready var npc3_root: Node2D = $Battlefield/Npc3Root
@onready var npc1_sprite: Sprite2D = $Battlefield/Npc1Root/Npc1
@onready var npc2_sprite: Sprite2D = $Battlefield/Npc2Root/Npc2
@onready var npc3_sprite: Sprite2D = $Battlefield/Npc3Root/Npc3


# -----------------------------------------------------------------------------
# เริ่มต้น Scene
# -----------------------------------------------------------------------------
func _ready() -> void:
	# เชื่อมสัญญาณ pressed ของแต่ละปุ่มเข้ากับฟังก์ชันที่ต้องการ
	# เมื่อผู้เล่นกดปุ่ม ฟังก์ชันที่เชื่อมไว้จะถูกเรียกใช้งานทันที
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	target_picker.item_selected.connect(_on_target_picker_item_selected)

	# จดตำแหน่งที่จัดฉากไว้ เพื่อให้ทุก Action กลับเข้ากลุ่มเดิมได้
	player_home = player_root.position
	enemy_home = enemy_root.position
	enemy_b_home = enemy_b_root.position
	player_sprite_base_scale = player_sprite.scale
	enemy_sprite_base_scale = enemy_sprite.scale
	enemy_b_sprite_base_scale = enemy_b_sprite.scale
	player_sprite_base_position = player_sprite.position
	enemy_sprite_base_position = enemy_sprite.position
	enemy_b_sprite_base_position = enemy_b_sprite.position
	enemy_b_base_tint = enemy_b_sprite.modulate
	_activate_enemy(CombatTargets.ENEMY_A_ID)

	# บันทึก Formation และสีต้นฉบับของ NPC เพื่อใช้คืนค่าเมื่อ Restart
	npc_roots = [npc1_root, npc2_root, npc3_root]
	npc_sprites = [npc1_sprite, npc2_sprite, npc3_sprite]
	for i in range(npc_roots.size()):
		npc_home_positions.append(npc_roots[i].position)
		npc_home_tints.append(npc_sprites[i].modulate)
		npc_sprite_base_positions.append(npc_sprites[i].position)

	if session_mode == SessionMode.AUTONOMOUS:
		encounter = FullPartyEncounter.new()
		_build_autonomous_ui()
	else:
		turn_flow = CombatTurnFlow.new()
		target_registry = CombatTargets.new()
	# เริ่มการต่อสู้รอบแรก
	_start_new_battle()


# ตัวเลือกแสดงจาก Target Registry ไม่ฮาร์ดโค้ดรายชื่อศัตรูใน Scene
func _enemy_hp_for(enemy_id: String) -> int:
	if enemy_id == CombatTargets.ENEMY_A_ID:
		return enemy_hp
	if enemy_id == CombatTargets.ENEMY_B_ID:
		return enemy_b_hp
	return 0


func _activate_enemy(enemy_id: String) -> void:
	active_enemy_id = enemy_id
	if enemy_id == CombatTargets.ENEMY_B_ID:
		active_enemy_root = enemy_b_root
		active_enemy_sprite = enemy_b_sprite
		active_enemy_home = enemy_b_home
		active_enemy_sprite_base_scale = enemy_b_sprite_base_scale
		active_enemy_sprite_base_position = enemy_b_sprite_base_position
		active_enemy_base_tint = enemy_b_base_tint
		active_enemy_label = enemy_b_label
	else:
		active_enemy_id = CombatTargets.ENEMY_A_ID
		active_enemy_root = enemy_root
		active_enemy_sprite = enemy_sprite
		active_enemy_home = enemy_home
		active_enemy_sprite_base_scale = enemy_sprite_base_scale
		active_enemy_sprite_base_position = enemy_sprite_base_position
		active_enemy_base_tint = Color.WHITE
		active_enemy_label = enemy_a_label


func _enemy_display_name(enemy_id: String) -> String:
	return "Enemy B" if enemy_id == CombatTargets.ENEMY_B_ID else "Enemy A"


func _enemy_rest_tint(enemy_id: String) -> Color:
	if encounter != null:
		return (enemy_b_base_tint if enemy_id == "enemy_b" else Color.WHITE) \
			if encounter.actor_snapshot(enemy_id).can_act else Color(0.42, 0.42, 0.42, 1.0)
	if not target_registry.is_enemy_available(enemy_id):
		return Color(0.42, 0.42, 0.42, 1.0)
	return enemy_b_base_tint if enemy_id == CombatTargets.ENEMY_B_ID else Color.WHITE


func _restore_active_enemy() -> void:
	active_enemy_root.position = active_enemy_home
	active_enemy_sprite.position = active_enemy_sprite_base_position
	active_enemy_sprite.scale = active_enemy_sprite_base_scale
	active_enemy_sprite.modulate = _enemy_rest_tint(active_enemy_id)


func _resolve_live_attack_target(planned_id: String) -> String:
	if _is_enemy_target_valid(planned_id):
		return planned_id
	# Enemy เป้าหมายอาจถูก Player/NPC ก่อนหน้ากำจัดระหว่างรอบ
	return target_registry.first_available_enemy_id()


func _refresh_target_picker() -> void:
	if encounter != null:
		_refresh_autonomous_picker()
		return
	target_picker.clear()
	var selected_id: String = target_registry.selected_enemy_id()
	var selected_index: int = -1
	for enemy in target_registry.available_enemy_targets():
		target_picker.add_item(String(enemy["name"]))
		var index: int = target_picker.item_count - 1
		target_picker.set_item_metadata(index, String(enemy["id"]))
		if String(enemy["id"]) == selected_id:
			selected_index = index
	if selected_index >= 0:
		target_picker.select(selected_index)
	target_picker.disabled = selected_index < 0 or action_in_progress or battle_is_over


func _on_target_picker_item_selected(index: int) -> void:
	if encounter != null:
		if encounter.snapshot().command_ready and index >= 0 and index < target_picker.item_count:
			var id: String = str(target_picker.get_item_metadata(index))
			if encounter.available_enemy_ids().has(id):
				autonomous_selected_target = id
		_refresh_autonomous_picker()
		return
	# ระหว่าง Tween ไม่รับการเปลี่ยนเป้าหมาย: Action ที่เริ่มแล้วจะล็อก Target ID
	if battle_is_over or action_in_progress:
		return
	if not target_registry.select_enemy(String(target_picker.get_item_metadata(index))):
		_refresh_target_picker()


func _is_enemy_target_valid(target_id: String) -> bool:
	return target_registry.is_enemy_available(target_id) and _enemy_hp_for(target_id) > 0


# เรียกเมื่อ Root พุ่งจาก Formation สั้น ๆ แล้วคำนวณ Hit ตอน Sprite ออกท่า
# Player/NPC โจมตีไปทางขวา (+1), Enemy โจมตีไปทางซ้าย (-1)
# ปรับความเร็ว Tween ทั้ง Motion และ Feedback ให้สอดคล้องกัน
func _pace_tween(tween: Tween) -> Tween:
	tween.set_speed_scale(clampf(combat_speed_scale, 0.45, 1.0))
	return tween


func _queue_attack_pose(
	actor_sprite: Node2D, base_position: Vector2, facing_direction: float
) -> void:
	presentation_adapter.append_attack_pose(
		action_tween, actor_sprite, base_position, facing_direction, _presentation_settings())


# Presentation-only values from the accepted Main Combat baseline (not proof timing).
func _presentation_settings() -> Dictionary:
	return {
		"speed": combat_speed_scale,
		"SHORT_LUNGE_DISTANCE": SHORT_LUNGE_DISTANCE,
		"SHORT_LUNGE_TIME": SHORT_LUNGE_TIME,
		"SHORT_LUNGE_RETURN_TIME": SHORT_LUNGE_RETURN_TIME,
		"ACTIVE_SPRITE_SCALE_FACTOR": ACTIVE_SPRITE_SCALE_FACTOR,
		"ATTACK_POSE_WINDUP_DISTANCE": ATTACK_POSE_WINDUP_DISTANCE,
		"ATTACK_POSE_STRIKE_DISTANCE": ATTACK_POSE_STRIKE_DISTANCE,
		"ATTACK_POSE_WINDUP_TIME": ATTACK_POSE_WINDUP_TIME,
		"ATTACK_POSE_STRIKE_TIME": ATTACK_POSE_STRIKE_TIME,
		"ENEMY_RECOIL_DISTANCE": ENEMY_RECOIL_DISTANCE,
		"ENEMY_HIT_TIME": ENEMY_HIT_TIME,
		"IMPACT_SPRITE_SQUASH": IMPACT_SPRITE_SQUASH,
		"HIT_HOLD_TIME": HIT_HOLD_TIME,
		"ACTION_HANDOFF_PAUSE": ACTION_HANDOFF_PAUSE,
		"NPC_STAGE_HOLD_TIME": NPC_STAGE_HOLD_TIME,
		"NPC_ATTACK_HIT_TIME": NPC_ATTACK_HIT_TIME,
		"NPC_ACTIVE_TINT": NPC_ACTIVE_TINT,
		"PLAYER_HIT_RECOIL_DISTANCE": PLAYER_HIT_RECOIL_DISTANCE,
		"GUARDED_HIT_RECOIL_DISTANCE": GUARDED_HIT_RECOIL_DISTANCE,
		"GUARDED_HIT_SQUASH": GUARDED_HIT_SQUASH,
		"PLAYER_HIT_TIME": PLAYER_HIT_TIME,
		"ENEMY_COUNTER_HOLD_TIME": ENEMY_COUNTER_HOLD_TIME,
		"PLAYER_DEFEND_BRACE_TIME": PLAYER_DEFEND_BRACE_TIME,
		"PLAYER_DEFEND_HOLD_TIME": PLAYER_DEFEND_HOLD_TIME,
		"PLAYER_DEFEND_RECOVER_TIME": PLAYER_DEFEND_RECOVER_TIME,
		"PLAYER_DEFEND_BRACE_OFFSET": PLAYER_DEFEND_BRACE_OFFSET,
		"PLAYER_DEFEND_BRACE_SCALE": PLAYER_DEFEND_BRACE_SCALE,
		"PLAYER_DEFEND_BRACE_TINT": PLAYER_DEFEND_BRACE_TINT,
		"GUARD_POSE_RAISE_TIME": GUARD_POSE_RAISE_TIME,
		"GUARD_POSE_RETURN_TIME": GUARD_POSE_RETURN_TIME,
	}


# -----------------------------------------------------------------------------
# เริ่มการต่อสู้ใหม่
# -----------------------------------------------------------------------------
func _start_new_battle() -> void:
	presentation_adapter.cancel()
	# กด Restart ระหว่าง Motion ของฝ่ายใดก็ได้: ยกเลิก Tween และคืน Sprite
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	action_tween = null
	# กด Restart ระหว่างแผงผล Fade ก็ต้องหยุด Tween และซ่อนแผงทันที
	if battle_result_tween != null and battle_result_tween.is_valid():
		battle_result_tween.kill()
	battle_result_tween = null
	battle_result_panel.hide()
	battle_result_panel.modulate.a = 1.0

	# ยกเลิกคิวและ Target ID ที่ผูกกับ Action เก่าเมื่อ Restart
	if turn_flow != null:
		turn_flow.reset()
	active_action_target_id = ""
	# ล้าง Cue ที่เกาะกับ NPC เมื่อ Restart ระหว่างเดินทางหรือรับ Hit
	_clear_npc_intents()
	action_in_progress = false
	player_root.position = player_home
	enemy_root.position = enemy_home
	enemy_b_root.position = enemy_b_home
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	enemy_b_sprite.modulate = enemy_b_base_tint
	player_sprite.scale = player_sprite_base_scale
	enemy_sprite.scale = enemy_sprite_base_scale
	enemy_b_sprite.scale = enemy_b_sprite_base_scale
	player_sprite.position = player_sprite_base_position
	enemy_sprite.position = enemy_sprite_base_position
	enemy_b_sprite.position = enemy_b_sprite_base_position
	_activate_enemy(CombatTargets.ENEMY_A_ID)
	npc_action_index = 0
	for i in range(npc_roots.size()):
		npc_roots[i].position = npc_home_positions[i]
		npc_sprites[i].modulate = npc_home_tints[i]
		npc_sprites[i].position = npc_sprite_base_positions[i]

	# ล้างตัวเลข Damage และ HP Flash ที่อาจยังแสดงอยู่ตอน Restart
	for popup in damage_popups:
		if is_instance_valid(popup):
			popup.queue_free()
	damage_popups.clear()
	# Hit Spark ต้องหายไปทันทีเมื่อ Restart แม้กำลัง Fade อยู่
	for spark in hit_sparks:
		if is_instance_valid(spark):
			spark.queue_free()
	hit_sparks.clear()
	if player_hp_flash_tween != null and player_hp_flash_tween.is_valid():
		player_hp_flash_tween.kill()
	if enemy_hp_flash_tween != null and enemy_hp_flash_tween.is_valid():
		enemy_hp_flash_tween.kill()
	player_hp_flash_tween = null
	enemy_hp_flash_tween = null
	player_label.modulate = Color.WHITE
	enemy_a_label.modulate = Color.WHITE
	enemy_b_label.modulate = Color.WHITE

	if encounter != null:
		_restart_autonomous_session()
		return

	# คืนค่าทุกอย่างกลับเป็นค่าเริ่มต้น
	player_hp = PLAYER_MAX_HP
	enemy_hp = ENEMY_MAX_HP
	enemy_b_hp = ENEMY_B_MAX_HP
	player_is_defending = false
	npc_guard_bonus = 0
	battle_is_over = false
	battle_result_player_won = false
	turn_number = 1

	# เปิดปุ่มการกระทำอีกครั้ง
	attack_button.disabled = false
	defend_button.disabled = false
	target_registry.reset()
	target_registry.register_enemy(CombatTargets.ENEMY_A_ID, "Enemy A")
	target_registry.register_enemy(CombatTargets.ENEMY_B_ID, "Enemy B")
	_refresh_target_picker()

	# ล้างข้อความเก่า และเขียนข้อความเริ่มต้น
	combat_log.clear()
	_add_log("=== การต่อสู้เริ่มต้น ===")
	_add_log("กด 'โจมตี' เพื่อลด HP ของ Enemy A")
	_add_log("กด 'ตั้งรับ' เพื่อลดความเสียหายจากศัตรู")
	_add_log("")

	# แสดงสถานะพร้อมรับคำสั่งหลัง Reset โดยไม่เพิ่ม Animation หรือเวลารอ
	_set_action_status("รอบที่ %d · เลือกคำสั่ง" % turn_number)

	# อัปเดตตัวเลขบนหน้าจอ
	_update_ui()


# -----------------------------------------------------------------------------
# เมื่อผู้เล่นกดปุ่มโจมตี
# -----------------------------------------------------------------------------
func _on_attack_button_pressed() -> void:
	if encounter != null:
		_autonomous_command("ATTACK")
		return
	# ระหว่างแสดงท่าทางยังไม่อนุญาตให้กดคำสั่งซ้อนกัน
	if battle_is_over or action_in_progress:
		return

	var selected_enemy_id: String = target_registry.selected_enemy_id()
	if not _is_enemy_target_valid(selected_enemy_id):
		_refresh_target_picker()
		return

	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true
	target_picker.disabled = true
	player_is_defending = false
	# วางแผนทั้งรอบไว้ล่วงหน้า แล้วให้ Player ใช้ Action แรก
	turn_flow.plan_round(
		false, npc_roots.size(), selected_enemy_id,
		target_registry.available_enemy_ids()
	)
	var player_action: Dictionary = turn_flow.take_next_action()
	active_action_target_id = String(player_action["target_id"])
	_activate_enemy(active_action_target_id)
	_add_log("--- รอบที่ %d ---" % turn_number)
	_set_action_status("รอบที่ %d · Player: %s" % [
		turn_number, String(player_action["intent"])
	])

	# Adapter schedules visuals; the original controller callbacks still own gameplay.
	action_tween = presentation_adapter.play_player_attack(
		self, CombatTargets.PLAYER_ID, active_action_target_id,
		{"root": player_root, "sprite": player_sprite, "home": player_home,
			"sprite_home": player_sprite_base_position, "scale": player_sprite_base_scale},
		{"root": active_enemy_root, "sprite": active_enemy_sprite, "home": active_enemy_home,
			"sprite_home": active_enemy_sprite_base_position, "scale": active_enemy_sprite_base_scale,
			"tint": active_enemy_base_tint},
		_presentation_settings(), _apply_player_hit, _finish_player_attack)


func _apply_hit_to_active_enemy(damage: int, actor_name: String) -> void:
	if battle_is_over or not _is_enemy_target_valid(active_action_target_id):
		return

	var previous_hp: int = _enemy_hp_for(active_action_target_id)
	var new_hp: int = maxi(previous_hp - damage, 0)
	if active_action_target_id == CombatTargets.ENEMY_B_ID:
		enemy_b_hp = new_hp
	else:
		enemy_hp = new_hp

	var actual_damage: int = previous_hp - new_hp
	_add_log("%s โจมตี %s สร้างความเสียหาย %d หน่วย" % [
		actor_name, _enemy_display_name(active_action_target_id), actual_damage
	])
	_update_ui()
	_show_floating_damage(active_enemy_root.position, actual_damage, ENEMY_DAMAGE_COLOR)
	_show_hit_spark(
		active_enemy_root.position + HIT_SPARK_ENEMY_OFFSET, ENEMY_DAMAGE_COLOR
	)
	_flash_hp_label(active_enemy_label, ENEMY_DAMAGE_COLOR, false)

	if new_hp <= 0:
		var defeated_id: String = active_action_target_id
		target_registry.mark_enemy_defeated(defeated_id)
		_add_log("%s ถูกกำจัด" % _enemy_display_name(defeated_id))
		_refresh_target_picker()
		if target_registry.available_enemy_ids().is_empty():
			_end_battle(true)


func _apply_player_hit() -> void:
	_apply_hit_to_active_enemy(PLAYER_ATTACK_DAMAGE, "Player")



func _finish_player_attack() -> void:
	# คงตำแหน่งและขนาดเดิม แม้การโจมตีครั้งนี้กำจัดศัตรูได้
	player_root.position = player_home
	_restore_active_enemy()
	player_sprite.modulate = Color.WHITE
	player_sprite.scale = player_sprite_base_scale
	player_sprite.position = player_sprite_base_position
	action_tween = null

	if battle_is_over:
		_show_battle_result()
		action_in_progress = false
		return

	# ทดลองให้สมาชิก NPC แสดง Action ของตนก่อนศัตรูโต้กลับ
	_start_npc_turns()


# -----------------------------------------------------------------------------
# เมื่อผู้เล่นกดปุ่มตั้งรับ
# -----------------------------------------------------------------------------
func _on_defend_button_pressed() -> void:
	if encounter != null:
		_autonomous_command("DEFEND")
		return
	if battle_is_over or action_in_progress:
		return

	# ล็อกคำสั่งทันที ไม่ให้กด Attack/Defend ระหว่าง Player กำลัง Brace
	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true
	target_picker.disabled = true
	_add_log("--- รอบที่ %d ---" % turn_number)

	# ระบบ Defend และกฎตัดสินใจของ NPC2 ยังคงเหมือนเดิม
	player_is_defending = true
	turn_flow.plan_round(
		true, npc_roots.size(), target_registry.selected_enemy_id(),
		target_registry.available_enemy_ids()
	)
	var player_action: Dictionary = turn_flow.take_next_action()
	active_action_target_id = String(player_action["target_id"])
	_add_log("Player ตั้งรับ เตรียมลดความเสียหายจาก Enemy A")
	_set_action_status("รอบที่ %d · Player: %s" % [
		turn_number, String(player_action["intent"])
	])

	# ท่าตั้งรับไม่เคลื่อน Root หรือ Shadow และไม่สร้างเอฟเฟกต์ใหม่
	action_tween = _pace_tween(create_tween())
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.tween_property(
		player_sprite, "position",
		player_sprite_base_position + PLAYER_DEFEND_BRACE_OFFSET,
		PLAYER_DEFEND_BRACE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		player_sprite, "scale",
		player_sprite_base_scale * PLAYER_DEFEND_BRACE_SCALE,
		PLAYER_DEFEND_BRACE_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", PLAYER_DEFEND_BRACE_TINT,
		PLAYER_DEFEND_BRACE_TIME
	)

	action_tween.tween_interval(PLAYER_DEFEND_HOLD_TIME)
	action_tween.tween_property(
		player_sprite, "position", player_sprite_base_position,
		PLAYER_DEFEND_RECOVER_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "scale", player_sprite_base_scale,
		PLAYER_DEFEND_RECOVER_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color.WHITE,
		PLAYER_DEFEND_RECOVER_TIME
	)
	action_tween.tween_interval(ACTION_HANDOFF_PAUSE)
	action_tween.tween_callback(_finish_player_defend_pose)


func _finish_player_defend_pose() -> void:
	# คืน Sprite ให้ตรงตำแหน่งก่อนเข้าสู่ NPC phase แม้ถูก Restart ภายหลัง
	player_sprite.position = player_sprite_base_position
	player_sprite.scale = player_sprite_base_scale
	player_sprite.modulate = Color.WHITE
	action_tween = null
	if battle_is_over:
		action_in_progress = false
		return

	# แผน NPC ประเมิน player_is_defending หลังท่า Brace เสร็จ
	_start_npc_turns()


# -----------------------------------------------------------------------------
# NPC1 -> NPC2 -> NPC3 ออก Action ใกล้ Formation ของตนเอง
# -----------------------------------------------------------------------------
func _start_npc_turns() -> void:
	if battle_is_over:
		return

	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true
	target_picker.disabled = true
	npc_action_index = 0
	_prepare_npc_intents()
	_start_next_npc_action()


# เตรียม Intent ของทุก NPC ในรอบนี้ ก่อนให้ใครเริ่มเคลื่อนไหว
func _prepare_npc_intents() -> void:
	_clear_npc_intents()
	for i in range(npc_roots.size()):
		# Intent อ่านจาก Turn Flow ที่วางแผนไว้ตอน Player เลือกคำสั่ง
		# ไม่ให้ Animation ตัดสินใจ ATK/GUARD แยกซ้ำอีกที่หนึ่ง
		var intent: String = turn_flow.npc_intent_at(i)

		# Label เป็นลูกของ Root จึงเดินทางติดไปกับตัว NPC อัตโนมัติ
		var cue: Label = Label.new()
		cue.text = intent
		cue.size = Vector2(88, 25)
		cue.position = Vector2(-44, -121)
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cue.z_index = 12
		cue.add_theme_font_size_override("font_size", 15)
		cue.add_theme_color_override("font_color", NPC_INTENT_QUEUED_COLOR)
		cue.add_theme_color_override(
			"font_outline_color", Color(0.06, 0.07, 0.07, 0.95)
		)
		cue.add_theme_constant_override("outline_size", 4)
		npc_roots[i].add_child(cue)
		npc_intent_labels.append(cue)



func _clear_npc_intents() -> void:
	for cue in npc_intent_labels:
		if is_instance_valid(cue):
			cue.queue_free()
	npc_intent_labels.clear()


func _start_next_npc_action() -> void:
	if battle_is_over:
		return
	if not action_in_progress or action_tween != null:
		push_error("Combat Turn Flow: ยังไม่พร้อมเปลี่ยน Action")
		return

	# คิวอาจหมดหลังข้าม Enemy ที่ตายแล้ว แม้ไม่มี Counteraction ถัดไป
	# ตรวจจำนวนก่อนอ่าน เพื่อไม่ให้ Action ว่างที่ผิดรูปแบบกลายเป็นการจบรอบ
	if turn_flow.pending_count() == 0:
		_finish_round()
		return

	# Turn Flow เลือกว่าเป็น NPC คนถัดไปหรือ Enemy โดยไม่ขึ้นกับ Tween
	var next_action: Dictionary = turn_flow.take_next_action()
	if next_action.is_empty():
		push_error("Combat Turn Flow: ไม่มี Action ถัดไปหลัง NPC")
		return
	active_action_target_id = String(next_action["target_id"])
	if next_action["actor"] == CombatTurnFlow.ACTOR_ENEMY:
		var attacker_id: String = String(next_action["enemy_id"])
		if not target_registry.is_enemy_available(attacker_id):
			# ศัตรูที่ตายระหว่างรอบต้องข้ามคิวของตัวเอง
			_start_next_npc_action()
			return
		_activate_enemy(attacker_id)
		_clear_npc_intents()
		_start_enemy_counteraction()
		return
	if next_action["actor"] != CombatTurnFlow.ACTOR_NPC:
		push_error("Combat Turn Flow: ลำดับ Action ไม่ถูกต้อง")
		return

	npc_action_index = int(next_action["actor_index"])
	var intent: String = String(next_action["intent"])
	_set_action_status("รอบที่ %d · NPC%d: %s" % [
		turn_number, npc_action_index + 1, intent
	])
	var is_attack: bool = intent == CombatTurnFlow.INTENT_ATTACK
	if is_attack:
		active_action_target_id = _resolve_live_attack_target(active_action_target_id)
		if active_action_target_id.is_empty():
			_end_battle(true)
			return
		_activate_enemy(active_action_target_id)
	npc_intent_labels[npc_action_index].add_theme_color_override(
		"font_color", NPC_INTENT_ACTIVE_COLOR
	)

	var current_root: Node2D = npc_roots[npc_action_index]
	var current_sprite: Sprite2D = npc_sprites[npc_action_index]
	var home: Vector2 = npc_home_positions[npc_action_index]
	var original_tint: Color = npc_home_tints[npc_action_index]
	var sprite_home: Vector2 = npc_sprite_base_positions[npc_action_index]
	var lunge_position: Vector2 = home + Vector2(SHORT_LUNGE_DISTANCE, 0.0)
	var action_tint: Color = NPC_ACTIVE_TINT
	if not is_attack:
		action_tint = NPC_GUARD_ACTIVE_TINT
	if is_attack:
		_add_log("NPC%d ตั้งใจ %s: %s" % [
			npc_action_index + 1, intent, _enemy_display_name(active_action_target_id)
		])
	else:
		_add_log("NPC%d ตั้งใจ %s: ป้องกัน Player" % [npc_action_index + 1, intent])

	action_tween = _pace_tween(create_tween())
	action_tween.set_trans(Tween.TRANS_SINE)
	if is_attack:
		# โจมตี: ขยับจาก Formation เพียง 44px และยืนออกท่าที่จุดนั้น
		action_tween.tween_property(
			current_root, "position", lunge_position, SHORT_LUNGE_TIME
		).set_ease(Tween.EASE_OUT)
		action_tween.parallel().tween_property(
			current_sprite, "modulate", action_tint, SHORT_LUNGE_TIME
		)
	else:
		# GUARD: ยืนที่ Formation ไม่วิ่งไปไหน เน้นเพียงสีท่าป้องกัน
		action_tween.tween_property(
			current_sprite, "modulate", action_tint, GUARD_POSE_RAISE_TIME
		)
	action_tween.tween_interval(NPC_STAGE_HOLD_TIME)
	if is_attack:
		_queue_attack_pose(current_sprite, sprite_home, 1.0)
		action_tween.tween_callback(_apply_npc_hit)
		action_tween.tween_property(
			active_enemy_root, "position", active_enemy_home + Vector2(ENEMY_RECOIL_DISTANCE, 0),
			NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			current_sprite, "position", sprite_home, NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			active_enemy_sprite, "modulate", Color(1.0, 0.55, 0.55, 1.0),
			NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			active_enemy_sprite, "scale", active_enemy_sprite_base_scale * IMPACT_SPRITE_SQUASH,
			NPC_ATTACK_HIT_TIME
		)
	else:
		# GUARD ไม่มี Damage และไม่มี Hit Spark ให้ Enemy; แสดงสีป้องกันที่ Player
		action_tween.tween_callback(_apply_npc_guard)
		action_tween.tween_property(
			player_sprite, "modulate", DEFEND_DAMAGE_COLOR, NPC_ATTACK_HIT_TIME
		)

	# ผู้โจมตีถอยกลับ Formation; GUARD แค่คืนสี ไม่มีการย้าย Root
	if is_attack:
		action_tween.tween_property(
			current_root, "position", home, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			current_sprite, "modulate", original_tint, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			active_enemy_root, "position", active_enemy_home, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			active_enemy_sprite, "modulate", active_enemy_base_tint, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			active_enemy_sprite, "scale", active_enemy_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
		)
	else:
		action_tween.tween_property(
			current_sprite, "modulate", original_tint, GUARD_POSE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			player_sprite, "modulate", Color.WHITE, GUARD_POSE_RETURN_TIME
		)
	action_tween.tween_interval(ACTION_HANDOFF_PAUSE)
	action_tween.tween_callback(_finish_npc_action)



func _apply_npc_guard() -> void:
	if battle_is_over:
		return
	# Guard เก็บไว้ถึง Enemy counteraction รอบนี้เท่านั้น
	npc_guard_bonus = NPC_GUARD_REDUCTION
	_add_log("NPC%d ป้องกัน Player: ลดความเสียหายจาก Enemy รอบนี้ %d" % [
		npc_action_index + 1, npc_guard_bonus
	])
	_show_npc_guard_feedback()


func _show_npc_guard_feedback() -> void:
	# ใช้ระบบ popup เดิมเพื่อให้ Restart ลบ Cue ป้องกันได้พร้อม Damage
	var popup: Label = Label.new()
	popup.text = "SHIELD +%d" % npc_guard_bonus
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.size = Vector2(156, 32)
	popup.position = player_home + Vector2(-78, -155)
	popup.z_index = 10
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", DEFEND_DAMAGE_COLOR)
	popup.add_theme_color_override(
		"font_outline_color", Color(0.06, 0.06, 0.06, 0.95)
	)
	popup.add_theme_constant_override("outline_size", 5)
	battlefield.add_child(popup)
	damage_popups.append(popup)

	var float_tween: Tween = _pace_tween(create_tween().bind_node(popup))
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_OUT)
	float_tween.tween_property(
		popup, "position", popup.position + Vector2(0, -DAMAGE_FLOAT_HEIGHT),
		DAMAGE_FLOAT_TIME
	)
	float_tween.parallel().tween_property(
		popup, "modulate:a", 0.0, DAMAGE_FLOAT_TIME - 0.12
	).set_delay(0.12)
	float_tween.tween_callback(_finish_damage_popup.bind(popup))


func _apply_npc_hit() -> void:
	_apply_hit_to_active_enemy(NPC_ATTACK_DAMAGE, "NPC%d" % [
		npc_action_index + 1
	])



func _finish_npc_action() -> void:
	# คืนตำแหน่งและรูปทรงทุกฝ่ายก่อนข้ามไปคิวต่อไป
	npc_roots[npc_action_index].position = npc_home_positions[npc_action_index]
	npc_sprites[npc_action_index].modulate = npc_home_tints[npc_action_index]
	npc_sprites[npc_action_index].position = npc_sprite_base_positions[npc_action_index]
	player_sprite.modulate = Color.WHITE
	# ปิด Cue ของคนที่ออก Action เสร็จแล้ว (เหลือเฉพาะผู้รอคิว)
	npc_intent_labels[npc_action_index].hide()
	_restore_active_enemy()
	action_tween = null

	if battle_is_over:
		_clear_npc_intents()
		_show_battle_result()
		action_in_progress = false
		return

	_start_next_npc_action()


# -----------------------------------------------------------------------------
# เริ่ม Motion โต้กลับของศัตรู (ทั้งกรณีผู้เล่นโจมตีและตั้งรับ)
# -----------------------------------------------------------------------------
func _start_enemy_counteraction() -> void:
	if battle_is_over:
		return

	_set_action_status("รอบที่ %d · %s: ATK" % [
		turn_number, _enemy_display_name(active_enemy_id)
	])
	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true

	# แช่สถานะก่อน Enemy ตี: ทั้ง Player Defend และ NPC2 GUARD มีการรับ Hit แบบเบา
	# (_apply_enemy_hit จะใช้สถานะ Guard แล้วรีเซ็ต bonus เหล่านี้ตอนคำนวณ)
	var guarded_hit: bool = player_is_defending or npc_guard_bonus > 0
	var hit_color: Color = Color(1.0, 0.55, 0.55, 1.0)
	var recoil_distance: float = PLAYER_HIT_RECOIL_DISTANCE
	var hit_squash: Vector2 = IMPACT_SPRITE_SQUASH
	if guarded_hit:
		hit_color = DEFEND_DAMAGE_COLOR
		recoil_distance = GUARDED_HIT_RECOIL_DISTANCE
		hit_squash = GUARDED_HIT_SQUASH

	action_tween = _pace_tween(create_tween())
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.tween_property(
		active_enemy_root, "position", active_enemy_home + Vector2(-SHORT_LUNGE_DISTANCE, 0.0),
		SHORT_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		active_enemy_sprite, "modulate", Color(1.25, 0.95, 0.80, 1.0),
		SHORT_LUNGE_TIME
	)
	# Enemy เป็น Active Character ระหว่าง Counteraction
	action_tween.parallel().tween_property(
		active_enemy_sprite, "scale", active_enemy_sprite_base_scale * ACTIVE_SPRITE_SCALE_FACTOR,
		SHORT_LUNGE_TIME
	)

	# Player ยืนรับการโจมตีที่ Formation ไม่ถูกดึงเข้าหาผู้โจมตี
	# Enemy เตรียมและออกท่าไปทางซ้ายก่อนคำนวณ Damage
	_queue_attack_pose(active_enemy_sprite, active_enemy_sprite_base_position, -1.0)
	action_tween.tween_callback(_apply_enemy_hit)
	action_tween.tween_property(
		player_root, "position", player_home + Vector2(-recoil_distance, 0),
		PLAYER_HIT_TIME
	)
	action_tween.parallel().tween_property(
		active_enemy_sprite, "position", active_enemy_sprite_base_position, PLAYER_HIT_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", hit_color, PLAYER_HIT_TIME
	)
	# Guard รับแรงกระแทกน้อยกว่า Hit ปกติ โดยไม่ย้ายเป้าหมายเข้าหา Enemy
	action_tween.parallel().tween_property(
		player_sprite, "scale", player_sprite_base_scale * hit_squash,
		PLAYER_HIT_TIME
	)
	action_tween.tween_interval(ENEMY_COUNTER_HOLD_TIME)

	# Shadow ของทั้งสอง Actor จะกลับไปพร้อม Root ที่เป็น Parent
	action_tween.tween_property(
		active_enemy_root, "position", active_enemy_home, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		active_enemy_sprite, "modulate", active_enemy_base_tint, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_root, "position", player_home, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		active_enemy_sprite, "scale", active_enemy_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "scale", player_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.tween_interval(ACTION_HANDOFF_PAUSE)
	action_tween.tween_callback(_finish_enemy_counteraction)


# -----------------------------------------------------------------------------
# คำนวณผลโต้กลับของศัตรู ณ จังหวะปะทะ
# -----------------------------------------------------------------------------
func _apply_enemy_hit() -> void:
	# Enemy Action ก็กำหนดเป้าหมายชัดเจนใน Turn Flow
	if battle_is_over or active_action_target_id != CombatTargets.PLAYER_ID:
		return
	var was_defending: bool = player_is_defending
	# ใช้สถานะก่อนลด/รีเซ็ต Guard เพื่อให้ Popup และ Reaction สอดคล้องกัน
	var was_guarded: bool = was_defending or npc_guard_bonus > 0
	var previous_hp: int = player_hp
	# เริ่มจากความเสียหายปกติของศัตรู
	var damage: int = ENEMY_ATTACK_DAMAGE

	# ถ้าผู้เล่นตั้งรับ ให้หักความเสียหายลง
	if player_is_defending:
		damage -= DEFEND_REDUCTION

		# อย่างน้อยศัตรูควรสร้างความเสียหายได้ 1 หน่วย
		if damage < 1:
			damage = 1

	# NPC2 Guard ใช้ได้กับการโต้กลับครั้งเดียว และไม่ลดต่ำกว่า 1
	var guard_blocked: int = mini(npc_guard_bonus, maxi(damage - 1, 0))
	damage = maxi(1, damage - npc_guard_bonus)
	npc_guard_bonus = 0
	if guard_blocked > 0:
		_add_log("NPC2 ช่วยลดความเสียหายที่ Player ได้รับ %d หน่วย" % guard_blocked)

	# ลด HP ของผู้เล่น
	player_hp -= damage

	# ป้องกันไม่ให้ HP ติดลบ
	if player_hp < 0:
		player_hp = 0

	_add_log(
		"%s โจมตีกลับ สร้างความเสียหาย %d หน่วย"
		% [_enemy_display_name(active_enemy_id), damage]
	)

	# Player Defend มีผลกับการโต้กลับทุกครั้งในรอบนี้
	# NPC2 GUARD ถูกใช้ได้ครั้งเดียวและรีเซ็ตด้านบนแล้ว
	_update_ui()
	var actual_damage: int = previous_hp - player_hp
	var feedback_color: Color = PLAYER_DAMAGE_COLOR
	if was_guarded:
		feedback_color = DEFEND_DAMAGE_COLOR
	_show_floating_damage(
		player_root.position, actual_damage, feedback_color, was_guarded
	)
	# ตอน Guard ไม่มี Spark โจมตีซ้ำ; เล่าแรงปะทะผ่าน Recoil เบาและตัวเลขสีฟ้า
	if not was_guarded:
		_show_hit_spark(player_root.position + HIT_SPARK_PLAYER_OFFSET, feedback_color)
	_flash_hp_label(player_label, feedback_color, true)
	_add_log("")

	# หาก HP ผู้เล่นหมด ให้จบการต่อสู้
	if player_hp <= 0:
		_end_battle(false)


func _finish_enemy_counteraction() -> void:
	# คืนตำแหน่งและขนาดก่อนเปิดการเล่นรอบต่อไป หรือหลังแพ้
	_restore_active_enemy()
	player_root.position = player_home
	player_sprite.modulate = Color.WHITE
	player_sprite.scale = player_sprite_base_scale
	player_sprite.position = player_sprite_base_position
	action_tween = null

	if battle_is_over:
		# เมื่อแพ้ ใช้หมายเลขรอบที่ HP หมดจริง ไม่ใช่รอบถัดไป
		action_in_progress = false
		_show_battle_result()
		return

	_start_next_npc_action()


func _finish_round() -> void:
	# เรียกจาก Dispatcher หลัง Action จบและข้ามศัตรูที่ตายจนหมดคิวแล้วเท่านั้น
	turn_flow.reset()
	active_action_target_id = ""
	player_is_defending = false
	action_in_progress = false
	turn_number += 1
	_set_action_status("รอบที่ %d · เลือกคำสั่ง" % turn_number)
	attack_button.disabled = false
	defend_button.disabled = false
	_refresh_target_picker()


# -----------------------------------------------------------------------------
# ปุ่มเริ่มใหม่
# -----------------------------------------------------------------------------
func _on_restart_button_pressed() -> void:
	_start_new_battle()


# -----------------------------------------------------------------------------
# อัปเดตข้อความ HP บนหน้าจอ
# -----------------------------------------------------------------------------
func _update_ui() -> void:
	if encounter != null:
		_refresh_autonomous_ui()
		return
	player_label.text = "Player HP: %d / %d" % [
		player_hp,
		PLAYER_MAX_HP
	]

	enemy_a_label.text = "Enemy A HP: %d / %d" % [
		enemy_hp,
		ENEMY_MAX_HP
	]
	enemy_b_label.text = "Enemy B HP: %d / %d" % [
		enemy_b_hp,
		ENEMY_B_MAX_HP
	]


# -----------------------------------------------------------------------------
# Hit Spark: แสงปะทะทรงพิกเซลขนาดเล็ก ไม่เพิ่มการยืดตัวของ Sprite
# -----------------------------------------------------------------------------
func _show_hit_spark(hit_position: Vector2, spark_color: Color) -> void:
	var spark: Polygon2D = Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(-3, -17), Vector2(3, -17),
		Vector2(3, -4), Vector2(17, -4),
		Vector2(17, 4), Vector2(3, 4),
		Vector2(3, 17), Vector2(-3, 17),
		Vector2(-3, 4), Vector2(-17, 4),
		Vector2(-17, -4), Vector2(-3, -4)
	])
	spark.color = spark_color
	spark.position = hit_position
	spark.scale = Vector2.ONE * HIT_SPARK_START_SCALE
	spark.z_index = 9
	battlefield.add_child(spark)
	hit_sparks.append(spark)

	# Tween ผูกกับ Polygon: เมื่อ Restart ลบ Effect แล้ว Motion หยุดตาม
	var effect_tween: Tween = _pace_tween(create_tween().bind_node(spark))
	effect_tween.set_trans(Tween.TRANS_SINE)
	effect_tween.set_ease(Tween.EASE_OUT)
	effect_tween.tween_property(
		spark, "scale", Vector2.ONE * HIT_SPARK_END_SCALE, HIT_SPARK_DURATION
	)
	effect_tween.parallel().tween_property(
		spark, "modulate:a", 0.0, HIT_SPARK_DURATION
	)
	effect_tween.tween_callback(_finish_hit_spark.bind(spark))


func _finish_hit_spark(spark: Polygon2D) -> void:
	hit_sparks.erase(spark)
	if is_instance_valid(spark):
		spark.queue_free()


# -----------------------------------------------------------------------------
# Floating Damage: โชว์เฉพาะความเสียหายจริงเหนือผู้ถูกโจมตี
# -----------------------------------------------------------------------------
func _show_floating_damage(
	actor_home: Vector2,
	damage: int,
	damage_color: Color,
	is_defending: bool = false
) -> void:
	if damage <= 0:
		return

	var popup: Label = Label.new()
	popup.text = "-%d" % damage
	if is_defending:
		popup.text = "GUARD -%d" % damage
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", damage_color)
	popup.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.06, 0.95))
	popup.add_theme_constant_override("outline_size", 5)
	popup.z_index = 10
	battlefield.add_child(popup)

	# อยู่เหนือหัวของ Actor แม้ Actor จะเคลื่อนที่ไปกลาง Action Area
	popup.size = Vector2(128, 32)
	popup.position = actor_home + Vector2(-64, -155)
	damage_popups.append(popup)

	# Tween ผูกกับ Label: เมื่อ Restart ลบ Label แล้ว Tween หยุดตาม
	var float_tween: Tween = _pace_tween(create_tween().bind_node(popup))
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_OUT)
	float_tween.tween_property(
		popup, "position", popup.position + Vector2(0, -DAMAGE_FLOAT_HEIGHT),
		DAMAGE_FLOAT_TIME
	)
	float_tween.parallel().tween_property(
		popup, "modulate:a", 0.0, DAMAGE_FLOAT_TIME - 0.12
	).set_delay(0.12)
	float_tween.tween_callback(_finish_damage_popup.bind(popup))


func _finish_damage_popup(popup: Label) -> void:
	damage_popups.erase(popup)
	if is_instance_valid(popup):
		popup.queue_free()


# -----------------------------------------------------------------------------
# HP Feedback: เน้นข้อความ HP แล้วค่อย ๆ กลับเป็นปกติ
# -----------------------------------------------------------------------------
func _flash_hp_label(label: Label, color: Color, is_player: bool) -> void:
	var previous_tween: Tween = enemy_hp_flash_tween
	if is_player:
		previous_tween = player_hp_flash_tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()

	label.modulate = color
	var flash_tween: Tween = _pace_tween(create_tween())
	flash_tween.tween_property(label, "modulate", Color.WHITE, HP_FLASH_TIME)
	if is_player:
		player_hp_flash_tween = flash_tween
	else:
		enemy_hp_flash_tween = flash_tween


# -----------------------------------------------------------------------------
# เพิ่มข้อความลงใน Combat Log
# -----------------------------------------------------------------------------
func _set_action_status(message: String) -> void:
	action_status_label.text = message


func _add_log(message: String) -> void:
	combat_log.append_text(message + "\n")


# -----------------------------------------------------------------------------
# จบการต่อสู้
# -----------------------------------------------------------------------------
func _show_battle_result() -> void:
	# เรียกเฉพาะตอน Action สุดท้ายกลับ Formation แล้ว ไม่ทับช่วง Hit
	if not battle_is_over or battle_result_panel.visible:
		return

	_present_battle_result(battle_result_player_won,
		"รอบที่ %d · Player HP %d/%d\nEnemy A %d/%d · Enemy B %d/%d" % [
			turn_number, player_hp, PLAYER_MAX_HP,
			enemy_hp, ENEMY_MAX_HP, enemy_b_hp, ENEMY_B_MAX_HP])


# Presentation only; autonomous callers supply result/detail from an Encounter snapshot.
func _present_battle_result(player_won: bool, detail: String) -> void:
	battle_result_title.text = "ชัยชนะ" if player_won else "พ่ายแพ้"
	if player_won:
		battle_result_title.add_theme_color_override(
			"font_color", Color(0.96, 0.85, 0.55, 1.0)
		)
	else:
		battle_result_title.add_theme_color_override(
			"font_color", Color(1.0, 0.64, 0.60, 1.0)
		)
	battle_result_detail.text = detail
	battle_result_panel.modulate.a = 0.0
	battle_result_panel.show()
	battle_result_tween = _pace_tween(create_tween())
	battle_result_tween.tween_property(
		battle_result_panel, "modulate:a", 1.0, 0.22
	)


func _end_battle(player_won: bool) -> void:
	if battle_is_over:
		return
	battle_is_over = true
	battle_result_player_won = player_won
	# เป้าหมายที่ถูกกำจัดจะถูกทำเครื่องหมายตอน HP เป็นศูนย์
	target_picker.disabled = true
	# เมื่อใครสักคนแพ้ ห้าม Action ที่วางแผนไว้แล้วออกต่อ
	turn_flow.reset()
	npc_guard_bonus = 0

	# ปิดปุ่มโจมตีและตั้งรับ แต่ยังคงเปิดปุ่มเริ่มใหม่ไว้
	attack_button.disabled = true
	defend_button.disabled = true

	_add_log("")

	if player_won:
		_set_action_status("จบการต่อสู้ · ชนะ")
		_add_log("=== Enemy A ถูกกำจัด — คุณชนะ ===")
	else:
		_set_action_status("จบการต่อสู้ · แพ้")
		_add_log("=== Player พ่ายแพ้ — การต่อสู้สิ้นสุด ===")

	_add_log("กด 'เริ่มใหม่' เพื่อทดลองอีกครั้ง")


# M2D-03 wiring in the existing controller: Encounter is the sole gameplay authority.
func _build_autonomous_ui() -> void:
	var roots: Array = [player_root, npc1_root, npc2_root, npc3_root, enemy_root, enemy_b_root]
	var sprites: Array = [player_sprite, npc1_sprite, npc2_sprite, npc3_sprite, enemy_sprite, enemy_b_sprite]
	var ids: Array = ["player", "npc_01", "npc_02", "npc_03", "enemy_a", "enemy_b"]
	for i in range(ids.size()):
		autonomous_views[ids[i]] = {"root": roots[i], "sprite": sprites[i], "home": roots[i].position,
			"sprite_home": sprites[i].position, "scale": sprites[i].scale,
			"tint": sprites[i].modulate, "enemy": i >= 4}
	autonomous_hp_labels = {"player": player_label, "enemy_a": enemy_a_label, "enemy_b": enemy_b_label,
		"npc_01": $MainMargin/MainVBox/BattleRow/AlliesPanel/NpcALabel,
		"npc_02": $MainMargin/MainVBox/BattleRow/AlliesPanel/NpcBLabel,
		"npc_03": $MainMargin/MainVBox/BattleRow/AlliesPanel/NpcCLabel}
	$TitleLabel.text = "WANDERER — AUTONOMOUS OPT-IN"
	$TitleLabel.add_theme_font_size_override("font_size", 22)
	autonomous_scenario_picker = OptionButton.new()
	autonomous_scenario_picker.position = Vector2(900, 22)
	autonomous_scenario_picker.size = Vector2(348, 32)
	for preset in AUTONOMOUS_SCENARIOS:
		autonomous_scenario_picker.add_item(preset.name)
	autonomous_scenario_picker.item_selected.connect(_select_autonomous_scenario)
	add_child(autonomous_scenario_picker)
	autonomous_decision_label = _autonomous_label(90)
	autonomous_effect_label = _autonomous_label(116)
	for i in range(3):
		autonomous_intents["npc_%02d" % (i + 1)] = _autonomous_label(146 + i * 24)
	for label in autonomous_hp_labels.values():
		label.show()
		label.add_theme_font_size_override("font_size", 13)
	# Three real NPC HP/resource rows need more height than Legacy's hidden placeholders.
	$MainMargin.offset_top = 520
	$MainMargin.offset_bottom = 710
	$MainMargin/MainVBox.add_theme_constant_override("separation", 4)


func _autonomous_label(y: float) -> Label:
	var label := Label.new()
	label.position = Vector2(32, y)
	label.size = Vector2(1216, 24)
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _select_autonomous_scenario(index: int) -> void:
	if not encounter.snapshot().command_ready or index < 0 or index >= AUTONOMOUS_SCENARIOS.size():
		autonomous_scenario_picker.select(autonomous_scenario)
		return
	autonomous_scenario = index
	_start_new_battle()


func _restart_autonomous_session() -> void:
	autonomous_token.clear()
	var fixture: Dictionary = FullPartyEncounter.prototype_fixture()
	var overrides: Dictionary = AUTONOMOUS_SCENARIOS[autonomous_scenario].hp
	for entry in fixture.actors:
		var id: String = entry.definition.actor_id
		entry.definition.display_name = AUTONOMOUS_NAMES[id]
		# Normal opt-in starts ALL NPCs full; the isolated M2C fixture remains unchanged.
		entry.initial_hp = overrides.get(id, entry.definition.base_max_hp)
	encounter.restart(fixture)
	_restore_autonomous_views()
	for id in autonomous_intents:
		autonomous_intents[id].text = "%s [%s] · Waiting to decide" % [AUTONOMOUS_NAMES[id], id]
	autonomous_selected_target = ""
	autonomous_decision_label.text = "Player chooses ATTACK / DEFEND; each companion decides at its slot."
	autonomous_effect_label.text = ""
	combat_log.clear()
	_add_log("=== Autonomous opt-in · %s ===" % AUTONOMOUS_SCENARIOS[autonomous_scenario].name)
	_refresh_autonomous_ui()


func _restore_autonomous_views() -> void:
	var view: Dictionary = encounter.snapshot()
	for id in autonomous_views:
		var actor: Dictionary = autonomous_views[id]
		actor.root.position = actor.home
		actor.sprite.position = actor.sprite_home
		actor.sprite.scale = actor.scale
		actor.sprite.modulate = actor.tint if view.actors[id].can_act else Color(0.42, 0.42, 0.42)
	for label in autonomous_hp_labels.values():
		label.modulate = Color.WHITE


func _refresh_autonomous_picker() -> void:
	target_picker.clear()
	var available: Array = encounter.available_enemy_ids()
	if not available.has(autonomous_selected_target):
		autonomous_selected_target = "" if available.is_empty() else available[0]
	for id in available:
		target_picker.add_item(AUTONOMOUS_NAMES[id])
		var index: int = target_picker.item_count - 1
		target_picker.set_item_metadata(index, id)
		if id == autonomous_selected_target:
			target_picker.select(index)
	target_picker.disabled = not encounter.snapshot().command_ready or available.is_empty()


func _refresh_autonomous_ui() -> void:
	var view: Dictionary = encounter.snapshot()
	for id in autonomous_hp_labels:
		var actor: Dictionary = view.actors[id]
		var text: String = "%s [%s] HP: %d / %d" % [actor.display_name, id, actor.current_hp, actor.max_hp]
		if view.help_uses.has(id):
			text += " · HELP %d" % view.help_uses[id]
		if view.guards.has(id):
			text += " · GUARD"
		autonomous_hp_labels[id].text = text
	attack_button.disabled = not view.command_ready
	defend_button.disabled = not view.command_ready
	autonomous_scenario_picker.disabled = not view.command_ready
	_refresh_autonomous_picker()
	_set_action_status("Autonomous · Round %d · %s" % [view.round_id,
		view.result if not view.result.is_empty() else ("Choose command" if view.command_ready else presentation_adapter.phase)])


func _autonomous_command(action: String) -> void:
	if not encounter.snapshot().command_ready or action_in_progress:
		return
	var target: String = ""
	if action == "ATTACK":
		if target_picker.selected < 0:
			return
		target = str(target_picker.get_item_metadata(target_picker.selected))
		if not encounter.available_enemy_ids().has(target):
			_refresh_autonomous_picker()
			return
	var reply: Dictionary = encounter.begin_round(action, target, AUTONOMOUS_SCENARIOS[autonomous_scenario].targets)
	if reply.status != "STARTED":
		return
	action_in_progress = true # Presentation busy only, never a second queue.
	for id in autonomous_intents:
		autonomous_intents[id].text = "%s [%s] · Waiting to decide" % [AUTONOMOUS_NAMES[id], id]
	_autonomous_advance()


func _autonomous_advance() -> void:
	var view: Dictionary = encounter.snapshot()
	if not view.round_running:
		action_in_progress = false
		action_tween = null
		autonomous_token = {}
		_refresh_autonomous_ui()
		if not view.result.is_empty():
			_present_battle_result(view.result == "VICTORY",
				"Round %d · Player HP %d/%d\nEnemy A %d/%d · Enemy B %d/%d" % [view.round_id,
					view.actors.player.current_hp, view.actors.player.max_hp,
					view.actors.enemy_a.current_hp, view.actors.enemy_a.max_hp,
					view.actors.enemy_b.current_hp, view.actors.enemy_b.max_hp])
		return
	var locked: Dictionary = encounter.begin_next_action()
	if not locked.has("decision"):
		if locked.get("status") in ["COMPLETED", "TERMINAL"]:
			_autonomous_advance()
		else:
			push_error("Autonomous Main: unexpected action lifecycle reply " + str(locked))
		return
	autonomous_token = locked.duplicate(true)
	var decision: Dictionary = locked.decision
	var text: String = "%s [%s] · %s → %s · %s · %s" % [AUTONOMOUS_NAMES[locked.actor_id], locked.actor_id,
		decision.action, decision.target_id if not decision.target_id.is_empty() else "none",
		decision.reason_code, AUTONOMOUS_REASONS.get(decision.reason_code, decision.reason_code)]
	autonomous_decision_label.text = text
	if autonomous_intents.has(locked.actor_id):
		autonomous_intents[locked.actor_id].text = text
	_add_log(text)
	# A skipped slot has no target; its own view supplies node lifetime checks only.
	var visual_target: String = locked.actor_id if decision.target_id.is_empty() else decision.target_id
	action_tween = presentation_adapter.play_action(self, locked.actor_id, visual_target, decision.action,
		autonomous_views[locked.actor_id], autonomous_views[visual_target], _presentation_settings(),
		_autonomous_impact.bind(locked), _autonomous_complete.bind(locked))
	_refresh_autonomous_ui()


func _autonomous_current(locked: Dictionary, states: Array, visual_phase: String) -> bool:
	if encounter == null or not action_in_progress or locked != autonomous_token \
		or presentation_adapter.phase != visual_phase:
		return false
	var view: Dictionary = encounter.snapshot()
	if not view.active_action:
		return false
	for key in ["encounter_id", "generation", "round_id", "action_id", "actor_id", "decision"]:
		if not locked.has(key) or locked[key] != view.locked_action.get(key):
			return false
	return view.locked_action.state in states


func _autonomous_impact(locked: Dictionary) -> Dictionary:
	if not _autonomous_current(locked, ["LOCKED"], "IMPACT"):
		return {}
	var before: Dictionary = encounter.snapshot()
	var effect: Dictionary = encounter.resolve_action(locked)
	var target: String = locked.decision.target_id
	var guarded: bool = before.guards.has(target)
	var text: String = "%s · %s → %s · %s · HP %+d" % [AUTONOMOUS_NAMES[locked.actor_id],
		locked.decision.action, target, effect.get("reason_code", effect.status), effect.get("hp_delta", 0)]
	if before.actors.has(target):
		text += " (%d → %d)" % [before.actors[target].current_hp, encounter.actor_snapshot(target).current_hp]
	autonomous_effect_label.text = text
	if autonomous_intents.has(locked.actor_id):
		autonomous_intents[locked.actor_id].text += " · %s HP %+d" % [effect.status, effect.get("hp_delta", 0)]
	_add_log(text)
	if effect.status == "APPLIED" and effect.hp_delta != 0:
		var node: Node2D = autonomous_views[target].root
		var color: Color = Color("9bffb3") if effect.hp_delta > 0 else (DEFEND_DAMAGE_COLOR if guarded else ENEMY_DAMAGE_COLOR)
		if effect.hp_delta > 0:
			_show_floating_heal(node.position, effect.hp_delta, color)
		else:
			_show_floating_damage(node.position, -effect.hp_delta, color, guarded)
			if not guarded:
				_show_hit_spark(node.position + (HIT_SPARK_PLAYER_OFFSET if before.actors[target].role != "ENEMY" else HIT_SPARK_ENEMY_OFFSET), color)
		_flash_hp_label(autonomous_hp_labels[target], color, target == "player")
	elif effect.status == "APPLIED" and locked.decision.action == "DEFEND":
		autonomous_effect_label.text += " · GUARD"
	_refresh_autonomous_ui()
	return {"hit": effect.status == "APPLIED" and effect.get("hp_delta", 0) < 0, "guarded": guarded}


func _autonomous_complete(locked: Dictionary) -> void:
	if not _autonomous_current(locked, ["RESOLVED", "SKIPPED"], "COMPLETED"):
		return
	if encounter.complete_action(locked).status != "COMPLETED":
		return
	autonomous_token = {}
	action_tween = null
	_restore_autonomous_views()
	_autonomous_advance()


func _show_floating_heal(home: Vector2, amount: int, color: Color) -> void:
	# Reuse the existing popup lifetime/Restart cleanup; only the caption changes.
	_show_floating_damage(home, amount, color)
	if not damage_popups.is_empty():
		damage_popups.back().text = "+%d" % amount


func _exit_tree() -> void:
	presentation_adapter.cancel()
