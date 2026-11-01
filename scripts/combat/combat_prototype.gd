extends Control


# -----------------------------------------------------------------------------
# ค่าคงที่ของการต่อสู้
# -----------------------------------------------------------------------------
# ค่าคงที่ (const) คือค่าที่จะไม่เปลี่ยนระหว่างที่เกมกำลังทำงาน
# ในต้นแบบนี้เรากำหนดตัวเลขไว้ตรง ๆ ก่อน เพื่อให้เข้าใจระบบได้ง่าย
const PLAYER_MAX_HP: int = 30
const ENEMY_MAX_HP: int = 15

const PLAYER_ATTACK_DAMAGE: int = 5
const ENEMY_ATTACK_DAMAGE: int = 3
const DEFEND_REDUCTION: int = 2

# M1.5C: ระยะเคลื่อนที่ใช้หน่วยเป็นพิกเซล ส่วนเวลาของ Tween ใช้หน่วยเป็นวินาที
# Player พุ่งไปครึ่งหนึ่งของระยะ X ระหว่างจุดยืน Player กับ Enemy
const ATTACK_APPROACH_RATIO: float = 0.5
const ENEMY_RECOIL_DISTANCE: float = 18.0

# แยกเวลาของแต่ละจังหวะไว้ให้ปรับความเร็วได้โดยไม่แตะระบบ HP
const ATTACK_LUNGE_TIME: float = 0.42
const ENEMY_HIT_TIME: float = 0.14
const HIT_HOLD_TIME: float = 0.08
const ATTACK_RETURN_TIME: float = 0.34

# M1.5C-02: จังหวะโต้กลับของ Enemy A
const ENEMY_COUNTER_STEP_DISTANCE: float = 96.0
const ENEMY_COUNTER_LUNGE_TIME: float = 0.26
const PLAYER_HIT_RECOIL_DISTANCE: float = 14.0
const PLAYER_HIT_TIME: float = 0.14
const ENEMY_COUNTER_HOLD_TIME: float = 0.08
const ENEMY_COUNTER_RETURN_TIME: float = 0.30


# -----------------------------------------------------------------------------
# ตัวแปรสถานะปัจจุบันของการต่อสู้
# -----------------------------------------------------------------------------
# ตัวแปรเหล่านี้จะเปลี่ยนไปตามการกดปุ่มของผู้เล่น
var player_hp: int = PLAYER_MAX_HP
var enemy_hp: int = ENEMY_MAX_HP

# ใช้ตรวจว่าผู้เล่นเลือกตั้งรับในรอบนี้หรือไม่
var player_is_defending: bool = false

# ใช้ป้องกันไม่ให้กดโจมตีต่อ หลังจากการต่อสู้จบแล้ว
var battle_is_over: bool = false

# ใช้แสดงหมายเลขรอบใน Combat Log
var turn_number: int = 1

# ล็อกคำสั่งระหว่าง Motion ทั้งสองฝ่าย เพื่อไม่ให้ HP คลาดเคลื่อน
var action_in_progress: bool = false
var action_tween: Tween
var player_home: Vector2
var enemy_home: Vector2


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

@onready var attack_button: Button = (
	$MainMargin/MainVBox/ActionRow/AttackButton
)

@onready var defend_button: Button = (
	$MainMargin/MainVBox/ActionRow/DefendButton
)

@onready var restart_button: Button = (
	$MainMargin/MainVBox/ActionRow/RestartButton
)

# ตัวละครที่ทำ Motion ถูกย้ายไว้ใน Root แล้วตั้งแต่ M1.5B
@onready var player_root: Node2D = $Battlefield/PlayerRoot
@onready var enemy_root: Node2D = $Battlefield/EnemyARoot
@onready var player_sprite: AnimatedSprite2D = $Battlefield/PlayerRoot/Player
@onready var enemy_sprite: Sprite2D = $Battlefield/EnemyARoot/EnemyA


# -----------------------------------------------------------------------------
# เริ่มต้น Scene
# -----------------------------------------------------------------------------
func _ready() -> void:
	# เชื่อมสัญญาณ pressed ของแต่ละปุ่มเข้ากับฟังก์ชันที่ต้องการ
	# เมื่อผู้เล่นกดปุ่ม ฟังก์ชันที่เชื่อมไว้จะถูกเรียกใช้งานทันที
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

	# จดตำแหน่งที่จัดฉากไว้ เพื่อให้ทุก Action กลับเข้ากลุ่มเดิมได้
	player_home = player_root.position
	enemy_home = enemy_root.position

	# เริ่มการต่อสู้รอบแรก
	_start_new_battle()


# -----------------------------------------------------------------------------
# เริ่มการต่อสู้ใหม่
# -----------------------------------------------------------------------------
func _start_new_battle() -> void:
	# กด Restart ระหว่าง Motion ของฝ่ายใดก็ได้: ยกเลิก Tween และคืน Sprite
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	action_tween = null
	action_in_progress = false
	player_root.position = player_home
	enemy_root.position = enemy_home
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE

	# คืนค่าทุกอย่างกลับเป็นค่าเริ่มต้น
	player_hp = PLAYER_MAX_HP
	enemy_hp = ENEMY_MAX_HP
	player_is_defending = false
	battle_is_over = false
	turn_number = 1

	# เปิดปุ่มการกระทำอีกครั้ง
	attack_button.disabled = false
	defend_button.disabled = false

	# ล้างข้อความเก่า และเขียนข้อความเริ่มต้น
	combat_log.clear()
	_add_log("=== การต่อสู้เริ่มต้น ===")
	_add_log("กด 'โจมตี' เพื่อลด HP ของ Enemy A")
	_add_log("กด 'ตั้งรับ' เพื่อลดความเสียหายจากศัตรู")
	_add_log("")

	# อัปเดตตัวเลขบนหน้าจอ
	_update_ui()


# -----------------------------------------------------------------------------
# เมื่อผู้เล่นกดปุ่มโจมตี
# -----------------------------------------------------------------------------
func _on_attack_button_pressed() -> void:
	# ระหว่างแสดงท่าทางยังไม่อนุญาตให้กดคำสั่งซ้อนกัน
	if battle_is_over or action_in_progress:
		return

	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true
	player_is_defending = false
	_add_log("--- รอบที่ %d ---" % turn_number)

	# Tween เป็นเพียง Presentation; ความเสียหายยังใช้ค่าเดิม
	action_tween = create_tween()
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.tween_property(
		player_root, "position", Vector2(
			player_home.x + (enemy_home.x - player_home.x) * ATTACK_APPROACH_RATIO,
			player_home.y
		), ATTACK_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color(1.25, 1.15, 1.05, 1.0), ATTACK_LUNGE_TIME
	)

	# เมื่อ Player ก้าวถึงจุดโจมตี จึงหัก HP และแสดง Hit Feedback
	action_tween.tween_callback(_apply_player_hit)
	action_tween.tween_property(
		enemy_root, "position", enemy_home + Vector2(ENEMY_RECOIL_DISTANCE, 0), ENEMY_HIT_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color(1.0, 0.55, 0.55, 1.0), ENEMY_HIT_TIME
	)

	# ค้าง Hit Pose สั้น ๆ ให้ตาเห็นการปะทะ ก่อนถอยกลับเข้าที่
	action_tween.tween_interval(HIT_HOLD_TIME)

	# คืน Actor ไปตำแหน่งเดิมก่อนอนุญาตให้เล่นเทิร์นถัดไป
	action_tween.tween_property(enemy_root, "position", enemy_home, ATTACK_RETURN_TIME)
	action_tween.parallel().tween_property(enemy_sprite, "modulate", Color.WHITE, ATTACK_RETURN_TIME)
	action_tween.parallel().tween_property(player_root, "position", player_home, ATTACK_RETURN_TIME)
	action_tween.parallel().tween_property(player_sprite, "modulate", Color.WHITE, ATTACK_RETURN_TIME)
	action_tween.tween_callback(_finish_player_attack)


func _apply_player_hit() -> void:
	enemy_hp = maxi(enemy_hp - PLAYER_ATTACK_DAMAGE, 0)
	_add_log(
		"Player โจมตี Enemy A สร้างความเสียหาย %d หน่วย"
		% PLAYER_ATTACK_DAMAGE
	)
	_update_ui()

	# ศัตรูที่ HP หมดยังรับ Hit Feedback ก่อน Motion จบ แต่ไม่สวนกลับ
	if enemy_hp <= 0:
		_end_battle(true)


func _finish_player_attack() -> void:
	# คงตำแหน่งเดิม แม้การโจมตีครั้งนี้กำจัดศัตรูได้
	player_root.position = player_home
	enemy_root.position = enemy_home
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	action_tween = null

	if battle_is_over:
		action_in_progress = false
		return

	# รอให้ศัตรูแสดงการโต้กลับและหัก HP ก่อนเปิดคำสั่งรอบถัดไป
	_start_enemy_counteraction()


# -----------------------------------------------------------------------------
# เมื่อผู้เล่นกดปุ่มตั้งรับ
# -----------------------------------------------------------------------------
func _on_defend_button_pressed() -> void:
	if battle_is_over or action_in_progress:
		return

	_add_log("--- รอบที่ %d ---" % turn_number)

	# ตั้งสถานะว่าผู้เล่นกำลังป้องกันในรอบนี้
	player_is_defending = true
	_add_log("Player ตั้งรับ เตรียมลดความเสียหายจาก Enemy A")

	# การตั้งรับข้ามการโจมตีของ Player และเข้าสู่ Motion ของศัตรู
	_start_enemy_counteraction()


# -----------------------------------------------------------------------------
# เริ่ม Motion โต้กลับของศัตรู (ทั้งกรณีผู้เล่นโจมตีและตั้งรับ)
# -----------------------------------------------------------------------------
func _start_enemy_counteraction() -> void:
	if battle_is_over:
		return

	action_in_progress = true
	attack_button.disabled = true
	defend_button.disabled = true

	# เลือกสี Hit Feedback ก่อนคำนวณ Damage เพราะสถานะ Defend จะถูกรีเซ็ต
	var hit_color: Color = (
		Color(0.75, 0.88, 1.0, 1.0) if player_is_defending
		else Color(1.0, 0.55, 0.55, 1.0)
	)

	action_tween = create_tween()
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.tween_property(
		enemy_root, "position", enemy_home + Vector2(-ENEMY_COUNTER_STEP_DISTANCE, 0),
		ENEMY_COUNTER_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color(1.25, 0.95, 0.80, 1.0),
		ENEMY_COUNTER_LUNGE_TIME
	)

	# ลด HP หลังศัตรูพุ่งถึงจุดโต้กลับ ไม่หัก HP ทันทีตอนเริ่มเทิร์น
	action_tween.tween_callback(_apply_enemy_hit)
	action_tween.tween_property(
		player_root, "position", player_home + Vector2(-PLAYER_HIT_RECOIL_DISTANCE, 0),
		PLAYER_HIT_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", hit_color, PLAYER_HIT_TIME
	)
	action_tween.tween_interval(ENEMY_COUNTER_HOLD_TIME)

	# Shadow ของทั้งสอง Actor จะกลับไปพร้อม Root ที่เป็น Parent
	action_tween.tween_property(
		enemy_root, "position", enemy_home, ENEMY_COUNTER_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		enemy_sprite, "modulate", Color.WHITE, ENEMY_COUNTER_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_root, "position", player_home, ENEMY_COUNTER_RETURN_TIME
	)
	action_tween.parallel().tween_property(
		player_sprite, "modulate", Color.WHITE, ENEMY_COUNTER_RETURN_TIME
	)
	action_tween.tween_callback(_finish_enemy_counteraction)


# -----------------------------------------------------------------------------
# คำนวณผลโต้กลับของศัตรู ณ จังหวะปะทะ
# -----------------------------------------------------------------------------
func _apply_enemy_hit() -> void:
	# เริ่มจากความเสียหายปกติของศัตรู
	var damage: int = ENEMY_ATTACK_DAMAGE

	# ถ้าผู้เล่นตั้งรับ ให้หักความเสียหายลง
	if player_is_defending:
		damage -= DEFEND_REDUCTION

		# อย่างน้อยศัตรูควรสร้างความเสียหายได้ 1 หน่วย
		if damage < 1:
			damage = 1

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
	_add_log("")

	# หาก HP ผู้เล่นหมด ให้จบการต่อสู้
	if player_hp <= 0:
		_end_battle(false)


func _finish_enemy_counteraction() -> void:
	# คืนตำแหน่งก่อนเปิดการเล่นรอบต่อไป หรือหลังแพ้
	enemy_root.position = enemy_home
	player_root.position = player_home
	enemy_sprite.modulate = Color.WHITE
	player_sprite.modulate = Color.WHITE
	action_tween = null
	action_in_progress = false
	turn_number += 1

	if not battle_is_over:
		attack_button.disabled = false
		defend_button.disabled = false


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
# เพิ่มข้อความลงใน Combat Log
# -----------------------------------------------------------------------------
func _add_log(message: String) -> void:
	combat_log.append_text(message + "\n")


# -----------------------------------------------------------------------------
# จบการต่อสู้
# -----------------------------------------------------------------------------
func _end_battle(player_won: bool) -> void:
	battle_is_over = true

	# ปิดปุ่มโจมตีและตั้งรับ แต่ยังคงเปิดปุ่มเริ่มใหม่ไว้
	attack_button.disabled = true
	defend_button.disabled = true

	_add_log("")

	if player_won:
		_add_log("=== Enemy A ถูกกำจัด — คุณชนะ ===")
	else:
		_add_log("=== Player พ่ายแพ้ — การต่อสู้สิ้นสุด ===")

	_add_log("กด 'เริ่มใหม่' เพื่อทดลองอีกครั้ง")
