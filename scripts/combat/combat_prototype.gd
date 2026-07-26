extends Control


const PLAYER_MAX_HP: int = 30
const ENEMY_MAX_HP: int = 15

const PLAYER_ATTACK_DAMAGE: int = 5
const ENEMY_ATTACK_DAMAGE: int = 3
const DEFEND_REDUCTION: int = 2


var player_hp: int = PLAYER_MAX_HP
var enemy_hp: int = ENEMY_MAX_HP

var player_is_defending: bool = false
var battle_is_over: bool = false


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


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)

	combat_log.clear()
	_add_log("การต่อสู้เริ่มต้น")

	_update_ui()


func _on_attack_button_pressed() -> void:
	if battle_is_over:
		return

	player_is_defending = false

	enemy_hp = max(
		enemy_hp - PLAYER_ATTACK_DAMAGE,
		0
	)

	_add_log(
		"Player โจมตี Enemy A สร้างความเสียหาย %d"
		% PLAYER_ATTACK_DAMAGE
	)

	_update_ui()

	if enemy_hp <= 0:
		_end_battle(true)
		return

	_enemy_turn()


func _on_defend_button_pressed() -> void:
	if battle_is_over:
		return

	player_is_defending = true
	_add_log("Player ตั้งรับ")

	_enemy_turn()


func _enemy_turn() -> void:
	var damage: int = ENEMY_ATTACK_DAMAGE

	if player_is_defending:
		damage = max(
			ENEMY_ATTACK_DAMAGE - DEFEND_REDUCTION,
			1
		)

	player_hp = max(
		player_hp - damage,
		0
	)

	_add_log(
		"Enemy A โจมตีกลับ สร้างความเสียหาย %d"
		% damage
	)

	player_is_defending = false

	_update_ui()

	if player_hp <= 0:
		_end_battle(false)


func _update_ui() -> void:
	player_label.text = "Player HP: %d / %d" % [
		player_hp,
		PLAYER_MAX_HP
	]

	enemy_a_label.text = "Enemy A HP: %d / %d" % [
		enemy_hp,
		ENEMY_MAX_HP
	]


func _add_log(message: String) -> void:
	combat_log.append_text(message + "\n")


func _end_battle(player_won: bool) -> void:
	battle_is_over = true

	attack_button.disabled = true
	defend_button.disabled = true

	if player_won:
		_add_log("Enemy A ถูกกำจัด — คุณชนะ")
	else:
		_add_log("Player พ่ายแพ้ — การต่อสู้สิ้นสุด")
