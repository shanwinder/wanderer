extends Control

const CombatTurnFlow = preload("res://scripts/combat/combat_turn_flow.gd")
const CombatTargets = preload("res://scripts/combat/combat_targets.gd")

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
var player_hp: int = PLAYER_MAX_HP
var enemy_hp: int = ENEMY_MAX_HP

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
var turn_flow = CombatTurnFlow.new()

# คัดเป้าหมายฝ่ายศัตรูก่อนเริ่ม Action แล้วเก็บ ID ไปกับคิวเทิร์น
var target_registry = CombatTargets.new()
var active_action_target_id: String = ""

# ล็อกคำสั่งระหว่าง Motion ทั้งสองฝ่าย เพื่อไม่ให้ HP คลาดเคลื่อน
var action_in_progress: bool = false
var action_tween: Tween
var player_home: Vector2
var enemy_home: Vector2
var player_sprite_base_scale: Vector2
var enemy_sprite_base_scale: Vector2
var player_sprite_base_position: Vector2
var enemy_sprite_base_position: Vector2

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
@onready var player_sprite: AnimatedSprite2D = $Battlefield/PlayerRoot/Player
@onready var enemy_sprite: Sprite2D = $Battlefield/EnemyARoot/EnemyA
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
	player_sprite_base_scale = player_sprite.scale
	enemy_sprite_base_scale = enemy_sprite.scale
	player_sprite_base_position = player_sprite.position
	enemy_sprite_base_position = enemy_sprite.position

	# บันทึก Formation และสีต้นฉบับของ NPC เพื่อใช้คืนค่าเมื่อ Restart
	npc_roots = [npc1_root, npc2_root, npc3_root]
	npc_sprites = [npc1_sprite, npc2_sprite, npc3_sprite]
	for i in range(npc_roots.size()):
		npc_home_positions.append(npc_roots[i].position)
		npc_home_tints.append(npc_sprites[i].modulate)
		npc_sprite_base_positions.append(npc_sprites[i].position)

	# เริ่มการต่อสู้รอบแรก
	_start_new_battle()


# ตัวเลือกแสดงจาก Target Registry ไม่ฮาร์ดโค้ดรายชื่อศัตรูใน Scene
func _refresh_target_picker() -> void:
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
	# ระหว่าง Tween ไม่รับการเปลี่ยนเป้าหมาย: Action ที่เริ่มแล้วจะล็อก Target ID
	if battle_is_over or action_in_progress:
		return
	if not target_registry.select_enemy(String(target_picker.get_item_metadata(index))):
		_refresh_target_picker()


func _is_enemy_target_valid(target_id: String) -> bool:
	# ปัจจุบันมี Enemy A ตัวเดียว; จุดนี้จะขยาย Damage Routing ในขั้นถัดไป
	return target_id == CombatTargets.ENEMY_A_ID and enemy_hp > 0 and (
		target_registry.is_enemy_available(target_id)
	)


# เรียกเมื่อ Root พุ่งจาก Formation สั้น ๆ แล้วคำนวณ Hit ตอน Sprite ออกท่า
# Player/NPC โจมตีไปทางขวา (+1), Enemy โจมตีไปทางซ้าย (-1)
# ปรับความเร็ว Tween ทั้ง Motion และ Feedback ให้สอดคล้องกัน
func _pace_tween(tween: Tween) -> Tween:
	tween.set_speed_scale(clampf(combat_speed_scale, 0.45, 1.0))
	return tween


func _queue_attack_pose(
	actor_sprite: Node2D, base_position: Vector2, facing_direction: float
) -> void:
	action_tween.tween_property(
		actor_sprite, "position",
		base_position + Vector2(-facing_direction * ATTACK_POSE_WINDUP_DISTANCE, 0.0),
		ATTACK_POSE_WINDUP_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.tween_property(
		actor_sprite, "position",
		base_position + Vector2(facing_direction * ATTACK_POSE_STRIKE_DISTANCE, 0.0),
		ATTACK_POSE_STRIKE_TIME
	).set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# เริ่มการต่อสู้ใหม่
# -----------------------------------------------------------------------------
func _start_new_battle() -> void:
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
	turn_flow.reset()
	active_action_target_id = ""
	# ล้าง Cue ที่เกาะกับ NPC เมื่อ Restart ระหว่างเดินทางหรือรับ Hit
	_clear_npc_intents()
	action_in_progress = false
	player_root.position = player_home
	enemy_root.position = enemy_home
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	player_sprite.scale = player_sprite_base_scale
	enemy_sprite.scale = enemy_sprite_base_scale
	player_sprite.position = player_sprite_base_position
	enemy_sprite.position = enemy_sprite_base_position
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

	# คืนค่าทุกอย่างกลับเป็นค่าเริ่มต้น
	player_hp = PLAYER_MAX_HP
	enemy_hp = ENEMY_MAX_HP
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
	turn_flow.plan_round(false, npc_roots.size(), selected_enemy_id)
	var player_action: Dictionary = turn_flow.take_next_action()
	active_action_target_id = String(player_action["target_id"])
	_add_log("--- รอบที่ %d ---" % turn_number)
	_set_action_status("รอบที่ %d · Player: %s" % [
		turn_number, String(player_action["intent"])
	])

	# Tween เป็นเพียง Presentation; ความเสียหายยังใช้ค่าเดิม
	action_tween = _pace_tween(create_tween())
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.tween_property(
		player_root, "position", player_home + Vector2(SHORT_LUNGE_DISTANCE, 0.0),
		SHORT_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color(1.25, 1.15, 1.05, 1.0), SHORT_LUNGE_TIME
	)
	# Player ชัดขึ้นในฐานะ Active Character ขณะพุ่งโจมตี
	action_tween.parallel().tween_property(
		player_sprite, "scale", player_sprite_base_scale * ACTIVE_SPRITE_SCALE_FACTOR,
		SHORT_LUNGE_TIME
	)

	# Enemy A ยังอยู่ Formation; Player เตรียมและออกท่าที่จุดพุ่งสั้น ๆ
	_queue_attack_pose(player_sprite, player_sprite_base_position, 1.0)
	# หัก HP ที่ปลาย Strike ไม่ใช่ทันทีที่ Root เข้ากลางสนาม
	action_tween.tween_callback(_apply_player_hit)
	action_tween.tween_property(
		enemy_root, "position", enemy_home + Vector2(ENEMY_RECOIL_DISTANCE, 0),
		ENEMY_HIT_TIME
	)
	# กลับ Sprite ของผู้โจมตีหลัง Hit ขณะเป้าหมายสะดุ้ง
	action_tween.parallel().tween_property(
		player_sprite, "position", player_sprite_base_position, ENEMY_HIT_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color(1.0, 0.55, 0.55, 1.0), ENEMY_HIT_TIME
	)
	# Impact Punch ของเป้าหมายใช้ทิศทางกว้าง-เตี้ย แทนการย้าย Root เพิ่ม
	action_tween.parallel().tween_property(
		enemy_sprite, "scale", enemy_sprite_base_scale * IMPACT_SPRITE_SQUASH,
		ENEMY_HIT_TIME
	)

	# ค้าง Hit Pose สั้น ๆ ให้ตาเห็นการปะทะ ก่อนถอยกลับเข้าที่
	action_tween.tween_interval(HIT_HOLD_TIME)

	# คืน Actor ไปตำแหน่งเดิมก่อนอนุญาตให้เล่นเทิร์นถัดไป
	action_tween.tween_property(enemy_root, "position", enemy_home, SHORT_LUNGE_RETURN_TIME)
	action_tween.parallel().tween_property(enemy_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME)
	action_tween.parallel().tween_property(player_root, "position", player_home, SHORT_LUNGE_RETURN_TIME)
	action_tween.parallel().tween_property(player_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME)
	action_tween.parallel().tween_property(
		player_sprite, "scale", player_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "scale", enemy_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.tween_interval(ACTION_HANDOFF_PAUSE)
	action_tween.tween_callback(_finish_player_attack)


func _apply_player_hit() -> void:
	if battle_is_over or not _is_enemy_target_valid(active_action_target_id):
		return
	var previous_hp: int = enemy_hp
	enemy_hp = maxi(enemy_hp - PLAYER_ATTACK_DAMAGE, 0)
	var actual_damage: int = previous_hp - enemy_hp
	_add_log(
		"Player โจมตี Enemy A สร้างความเสียหาย %d หน่วย"
		% PLAYER_ATTACK_DAMAGE
	)
	_update_ui()
	_show_floating_damage(enemy_root.position, actual_damage, ENEMY_DAMAGE_COLOR)
	_show_hit_spark(enemy_root.position + HIT_SPARK_ENEMY_OFFSET, ENEMY_DAMAGE_COLOR)
	_flash_hp_label(enemy_a_label, ENEMY_DAMAGE_COLOR, false)

	# ศัตรูที่ HP หมดยังรับ Hit Feedback ก่อน Motion จบ แต่ไม่สวนกลับ
	if enemy_hp <= 0:
		_end_battle(true)


func _finish_player_attack() -> void:
	# คงตำแหน่งและขนาดเดิม แม้การโจมตีครั้งนี้กำจัดศัตรูได้
	player_root.position = player_home
	enemy_root.position = enemy_home
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	player_sprite.scale = player_sprite_base_scale
	enemy_sprite.scale = enemy_sprite_base_scale
	player_sprite.position = player_sprite_base_position
	enemy_sprite.position = enemy_sprite_base_position
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
	turn_flow.plan_round(true, npc_roots.size(), target_registry.selected_enemy_id())
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

	# Turn Flow เลือกว่าเป็น NPC คนถัดไปหรือ Enemy โดยไม่ขึ้นกับ Tween
	var next_action: Dictionary = turn_flow.take_next_action()
	if next_action.is_empty():
		push_error("Combat Turn Flow: ไม่มี Action ถัดไปหลัง NPC")
		return
	active_action_target_id = String(next_action["target_id"])
	if next_action["actor"] == CombatTurnFlow.ACTOR_ENEMY:
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
		_add_log("NPC%d ตั้งใจ %s: Enemy A" % [npc_action_index + 1, intent])
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
			enemy_root, "position", enemy_home + Vector2(ENEMY_RECOIL_DISTANCE, 0),
			NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			current_sprite, "position", sprite_home, NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			enemy_sprite, "modulate", Color(1.0, 0.55, 0.55, 1.0),
			NPC_ATTACK_HIT_TIME
		)
		action_tween.parallel().tween_property(
			enemy_sprite, "scale", enemy_sprite_base_scale * IMPACT_SPRITE_SQUASH,
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
			enemy_root, "position", enemy_home, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			enemy_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME
		)
		action_tween.parallel().tween_property(
			enemy_sprite, "scale", enemy_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
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
	# NPC ใช้ Target ID ที่ได้จากคิว (ยังมี Enemy A ตัวเดียว)
	if battle_is_over or not _is_enemy_target_valid(active_action_target_id):
		return

	var previous_hp: int = enemy_hp
	enemy_hp = maxi(enemy_hp - NPC_ATTACK_DAMAGE, 0)
	var actual_damage: int = previous_hp - enemy_hp
	_add_log("NPC%d โจมตี Enemy A สร้างความเสียหาย %d หน่วย" % [
		npc_action_index + 1, actual_damage
	])
	_update_ui()
	_show_floating_damage(enemy_root.position, actual_damage, ENEMY_DAMAGE_COLOR)
	_show_hit_spark(enemy_root.position + HIT_SPARK_ENEMY_OFFSET, ENEMY_DAMAGE_COLOR)
	_flash_hp_label(enemy_a_label, ENEMY_DAMAGE_COLOR, false)

	# ถ้าการโจมตีของ NPC ปิดฉาก ให้ Finish Motion ได้ แต่ห้าม NPC ถัดไป
	# และห้าม Enemy ออก Action อีก
	if enemy_hp <= 0:
		_end_battle(true)


func _finish_npc_action() -> void:
	# คืนตำแหน่งและรูปทรงทุกฝ่ายก่อนข้ามไปคิวต่อไป
	npc_roots[npc_action_index].position = npc_home_positions[npc_action_index]
	npc_sprites[npc_action_index].modulate = npc_home_tints[npc_action_index]
	npc_sprites[npc_action_index].position = npc_sprite_base_positions[npc_action_index]
	player_sprite.modulate = Color.WHITE
	# ปิด Cue ของคนที่ออก Action เสร็จแล้ว (เหลือเฉพาะผู้รอคิว)
	npc_intent_labels[npc_action_index].hide()
	enemy_root.position = enemy_home
	enemy_sprite.modulate = Color.WHITE
	enemy_sprite.scale = enemy_sprite_base_scale
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

	_set_action_status("รอบที่ %d · Enemy A: ATK" % turn_number)
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
		enemy_root, "position", enemy_home + Vector2(-SHORT_LUNGE_DISTANCE, 0.0),
		SHORT_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color(1.25, 0.95, 0.80, 1.0),
		SHORT_LUNGE_TIME
	)
	# Enemy เป็น Active Character ระหว่าง Counteraction
	action_tween.parallel().tween_property(
		enemy_sprite, "scale", enemy_sprite_base_scale * ACTIVE_SPRITE_SCALE_FACTOR,
		SHORT_LUNGE_TIME
	)

	# Player ยืนรับการโจมตีที่ Formation ไม่ถูกดึงเข้าหาผู้โจมตี
	# Enemy เตรียมและออกท่าไปทางซ้ายก่อนคำนวณ Damage
	_queue_attack_pose(enemy_sprite, enemy_sprite_base_position, -1.0)
	action_tween.tween_callback(_apply_enemy_hit)
	action_tween.tween_property(
		player_root, "position", player_home + Vector2(-recoil_distance, 0),
		PLAYER_HIT_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "position", enemy_sprite_base_position, PLAYER_HIT_TIME
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
		enemy_root, "position", enemy_home, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_root, "position", player_home, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color.WHITE, SHORT_LUNGE_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "scale", enemy_sprite_base_scale, SHORT_LUNGE_RETURN_TIME
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
		"Enemy A โจมตีกลับ สร้างความเสียหาย %d หน่วย"
		% damage
	)

	# สถานะตั้งรับมีผลเพียงรอบเดียว
	player_is_defending = false

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
	enemy_root.position = enemy_home
	player_root.position = player_home
	enemy_sprite.modulate = Color.WHITE
	player_sprite.modulate = Color.WHITE
	enemy_sprite.scale = enemy_sprite_base_scale
	player_sprite.scale = player_sprite_base_scale
	enemy_sprite.position = enemy_sprite_base_position
	player_sprite.position = player_sprite_base_position
	action_tween = null
	action_in_progress = false

	if battle_is_over:
		# เมื่อแพ้ ใช้หมายเลขรอบที่ HP หมดจริง ไม่ใช่รอบถัดไป
		_show_battle_result()
		return

	turn_flow.reset()
	active_action_target_id = ""
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
	player_label.text = "Player HP: %d / %d" % [
		player_hp,
		PLAYER_MAX_HP
	]

	enemy_a_label.text = "Enemy A HP: %d / %d" % [
		enemy_hp,
		ENEMY_MAX_HP
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

	battle_result_title.text = "ชัยชนะ" if battle_result_player_won else "พ่ายแพ้"
	if battle_result_player_won:
		battle_result_title.add_theme_color_override(
			"font_color", Color(0.96, 0.85, 0.55, 1.0)
		)
	else:
		battle_result_title.add_theme_color_override(
			"font_color", Color(1.0, 0.64, 0.60, 1.0)
		)
	battle_result_detail.text = "รอบที่ %d · Player HP %d/%d · Enemy HP %d/%d" % [
		turn_number, player_hp, PLAYER_MAX_HP, enemy_hp, ENEMY_MAX_HP
	]
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
	# เป้าหมายที่ถูกกำจัดจะเลือกซ้ำไม่ได้
	if player_won:
		target_registry.mark_enemy_defeated(CombatTargets.ENEMY_A_ID)
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
