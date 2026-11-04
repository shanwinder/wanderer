extends RefCounted

# M2D-02: visual lifetime only. No HP, damage, Guard, target selection or queue.
# RefCounted needs no scene node: the supplied owner binds the real Tween to its tree.
var visual_epoch: int = 0
var actor_id: String = ""
var target_id: String = ""
var phase: String = "IDLE"
var _motion: Tween
var _actor: Dictionary = {}
var _target: Dictionary = {}
var _settings: Dictionary = {}
var _on_impact: Callable
var _on_complete: Callable
var _action: String = ""
var _facing: float = 1.0
var _impact_at: float = 0.0
var _complete_at: float = 0.0
var _return_at: float = 0.0
var _feedback: Dictionary = {}


func cancel() -> void:
	visual_epoch += 1
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	phase = "IDLE"
	actor_id = ""
	target_id = ""
	_actor.clear()
	_target.clear()
	_settings.clear()
	_on_impact = Callable()
	_on_complete = Callable()
	_action = ""
	_feedback.clear()


# Append the identical two pose steps to Player, NPC or Enemy's existing Tween.
func append_attack_pose(tween: Tween, sprite: Node2D, home: Vector2,
	facing: float, settings: Dictionary) -> void:
	tween.tween_property(sprite, "position",
		home + Vector2(-facing * settings.ATTACK_POSE_WINDUP_DISTANCE, 0.0),
		settings.ATTACK_POSE_WINDUP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position",
		home + Vector2(facing * settings.ATTACK_POSE_STRIKE_DISTANCE, 0.0),
		settings.ATTACK_POSE_STRIKE_TIME).set_ease(Tween.EASE_OUT)


# Views contain nodes and saved transforms only. IDs are locked identity, not selection.
func play_player_attack(owner: Node, locked_actor_id: String, locked_target_id: String,
	actor_view: Dictionary, target_view: Dictionary, configuration: Dictionary,
	impact: Callable, completed: Callable) -> Tween:
	cancel()
	actor_id = locked_actor_id
	target_id = locked_target_id
	_actor = actor_view.duplicate()
	_target = target_view.duplicate()
	_settings = configuration.duplicate()
	_on_impact = impact
	_on_complete = completed
	phase = "WINDUP"
	var actor: Dictionary = _actor
	var target: Dictionary = _target
	var settings: Dictionary = _settings
	# Tween เป็นเพียง Presentation; ความเสียหายยังใช้ค่าเดิม
	_motion = owner.create_tween().set_speed_scale(clampf(settings.speed, 0.45, 1.0))
	_motion.set_trans(Tween.TRANS_SINE)
	_motion.tween_property(
		actor.root, "position", actor.home + Vector2(settings.SHORT_LUNGE_DISTANCE, 0.0),
		settings.SHORT_LUNGE_TIME
	).set_ease(Tween.EASE_OUT)
	_motion.parallel().tween_property(
		actor.sprite, "modulate", Color(1.25, 1.15, 1.05, 1.0), settings.SHORT_LUNGE_TIME
	)
	# Player ชัดขึ้นในฐานะ Active Character ขณะพุ่งโจมตี
	_motion.parallel().tween_property(
		actor.sprite, "scale", actor.scale * settings.ACTIVE_SPRITE_SCALE_FACTOR,
		settings.SHORT_LUNGE_TIME
	)

	# Enemy A ยังอยู่ Formation; Player เตรียมและออกท่าที่จุดพุ่งสั้น ๆ
	append_attack_pose(_motion, actor.sprite, actor.sprite_home, 1.0, settings)
	# หัก HP ที่ปลาย Strike ไม่ใช่ทันทีที่ Root เข้ากลางสนาม
	_motion.tween_callback(_impact.bind(visual_epoch, actor_id, target_id))
	_motion.tween_property(
		target.root, "position", target.home + Vector2(settings.ENEMY_RECOIL_DISTANCE, 0),
		settings.ENEMY_HIT_TIME
	)
	# กลับ Sprite ของผู้โจมตีหลัง Hit ขณะเป้าหมายสะดุ้ง
	_motion.parallel().tween_property(
		actor.sprite, "position", actor.sprite_home, settings.ENEMY_HIT_TIME
	)
	_motion.parallel().tween_property(
		target.sprite, "modulate", Color(1.0, 0.55, 0.55, 1.0), settings.ENEMY_HIT_TIME
	)
	# Impact Punch ของเป้าหมายใช้ทิศทางกว้าง-เตี้ย แทนการย้าย Root เพิ่ม
	_motion.parallel().tween_property(
		target.sprite, "scale", target.scale * settings.IMPACT_SPRITE_SQUASH,
		settings.ENEMY_HIT_TIME
	)

	# ค้าง Hit Pose สั้น ๆ ให้ตาเห็นการปะทะ ก่อนถอยกลับเข้าที่
	_motion.tween_interval(settings.HIT_HOLD_TIME)

	# คืน Actor ไปตำแหน่งเดิมก่อนอนุญาตให้เล่นเทิร์นถัดไป
	_motion.tween_property(target.root, "position", target.home, settings.SHORT_LUNGE_RETURN_TIME)
	_motion.parallel().tween_property(target.sprite, "modulate", target.tint, settings.SHORT_LUNGE_RETURN_TIME)
	_motion.parallel().tween_property(actor.root, "position", actor.home, settings.SHORT_LUNGE_RETURN_TIME)
	_motion.parallel().tween_property(actor.sprite, "modulate", Color.WHITE, settings.SHORT_LUNGE_RETURN_TIME)
	_motion.parallel().tween_property(
		actor.sprite, "scale", actor.scale, settings.SHORT_LUNGE_RETURN_TIME
	)
	_motion.parallel().tween_property(
		target.sprite, "scale", target.scale, settings.SHORT_LUNGE_RETURN_TIME
	)
	_motion.tween_interval(settings.ACTION_HANDOFF_PAUSE)
	_motion.tween_callback(_complete.bind(visual_epoch, actor_id, target_id))

	return _motion


func _current(epoch: int, actor: String, target: String, expected_phase: String) -> bool:
	return epoch == visual_epoch and actor == actor_id and target == target_id \
		and phase == expected_phase and _motion != null and _motion.is_valid() \
		and is_instance_valid(_actor.get("root")) and is_instance_valid(_actor.get("sprite")) \
		and is_instance_valid(_target.get("root")) and is_instance_valid(_target.get("sprite"))


func _impact(epoch: int, actor: String, target: String) -> void:
	if not _current(epoch, actor, target, "WINDUP"):
		return
	# Reject an early replay even with the current identity: the strike must arrive first.
	if _actor.root.position != _actor.home + Vector2(_settings.SHORT_LUNGE_DISTANCE, 0.0) \
		or _actor.sprite.position != _actor.sprite_home + Vector2(_settings.ATTACK_POSE_STRIKE_DISTANCE, 0.0):
		return
	phase = "IMPACT" # Set before calling out; reentrant/duplicate impacts are inert.
	var callback: Callable = _on_impact
	_on_impact = Callable()
	callback.call() # Legacy controller alone applies gameplay and its existing feedback.


func _complete(epoch: int, actor: String, target: String) -> void:
	if not _current(epoch, actor, target, "IMPACT"):
		return
	# Completion cannot hand off the Legacy queue until both roots have returned.
	if _actor.root.position != _actor.home or _target.root.position != _target.home:
		return
	phase = "COMPLETED"
	_motion = null
	var callback: Callable = _on_complete
	_on_complete = Callable()
	_on_impact = Callable()
	_actor.clear()
	_target.clear()
	_settings.clear()
	callback.call()


# M2D-03: same Main presentation values, generalized views and actual-effect feedback.
# No Encounter/HP/decision policy lives here. Impact returns only visual facts.
func play_action(owner: Node, actor: String, target: String, action: String,
	actor_view: Dictionary, target_view: Dictionary, configuration: Dictionary,
	impact: Callable, completed: Callable) -> Tween:
	cancel()
	actor_id = actor
	target_id = target
	_action = action
	_actor = actor_view.duplicate()
	_target = target_view.duplicate()
	_settings = configuration.duplicate()
	_on_impact = impact
	_on_complete = completed
	_facing = -1.0 if actor_view.enemy else 1.0
	phase = "WINDUP"
	_motion = owner.create_tween().set_speed_scale(clampf(_settings.speed, 0.45, 1.0))
	_motion.set_trans(Tween.TRANS_SINE)
	if action == "ATTACK":
		_motion.tween_property(_actor.root, "position",
			_actor.home + Vector2(_facing * _settings.SHORT_LUNGE_DISTANCE, 0), _settings.SHORT_LUNGE_TIME).set_ease(Tween.EASE_OUT)
		_motion.parallel().tween_property(_actor.sprite, "modulate",
			Color(1.25, 0.95, 0.80) if actor_view.enemy else
			(Color(1.25, 1.15, 1.05) if actor == "player" else _settings.NPC_ACTIVE_TINT), _settings.SHORT_LUNGE_TIME)
		_motion.parallel().tween_property(_actor.sprite, "scale",
			_actor.scale * _settings.ACTIVE_SPRITE_SCALE_FACTOR, _settings.SHORT_LUNGE_TIME)
		_impact_at = _settings.SHORT_LUNGE_TIME
		if actor != "player" and not actor_view.enemy:
			_motion.tween_interval(_settings.NPC_STAGE_HOLD_TIME)
			_impact_at += _settings.NPC_STAGE_HOLD_TIME
		append_attack_pose(_motion, _actor.sprite, _actor.sprite_home, _facing, _settings)
		_impact_at += _settings.ATTACK_POSE_WINDUP_TIME + _settings.ATTACK_POSE_STRIKE_TIME
	elif action == "DEFEND":
		_motion.tween_property(_actor.sprite, "position",
			_actor.sprite_home + _settings.PLAYER_DEFEND_BRACE_OFFSET, _settings.PLAYER_DEFEND_BRACE_TIME)
		_motion.parallel().tween_property(_actor.sprite, "scale",
			_actor.scale * _settings.PLAYER_DEFEND_BRACE_SCALE, _settings.PLAYER_DEFEND_BRACE_TIME)
		_motion.parallel().tween_property(_actor.sprite, "modulate",
			_settings.PLAYER_DEFEND_BRACE_TINT, _settings.PLAYER_DEFEND_BRACE_TIME)
		_impact_at = _settings.PLAYER_DEFEND_BRACE_TIME
	else:
		# HELP stays home; SKIP waits without a strike or fabricated hit.
		_motion.tween_property(_actor.sprite, "modulate",
			Color("9bffb3") if action == "HELP" else _actor.tint, _settings.GUARD_POSE_RAISE_TIME)
		_impact_at = _settings.GUARD_POSE_RAISE_TIME
	_motion.tween_callback(_action_impact.bind(visual_epoch, actor_id, target_id))
	_append_action_recovery(visual_epoch, actor_id, target_id)
	return _motion


func _action_impact(epoch: int, actor: String, target: String) -> void:
	if not _current(epoch, actor, target, "WINDUP") or _motion.get_total_elapsed_time() < _impact_at:
		return
	phase = "IMPACT"
	var callback: Callable = _on_impact
	_on_impact = Callable()
	var feedback: Dictionary = callback.call()
	if _current(epoch, actor, target, "IMPACT"):
		_feedback = feedback.duplicate()


# Build the whole Tween before it starts. The reaction method reads visual feedback
# AFTER impact, so an invalidated locked target receives no fake hit or recoil.
func _append_action_recovery(epoch: int, actor: String, target: String) -> void:
	var reaction_time: float
	if _action == "ATTACK":
		reaction_time = _settings.PLAYER_HIT_TIME if _actor.enemy else \
			(_settings.ENEMY_HIT_TIME if actor == "player" else _settings.NPC_ATTACK_HIT_TIME)
		_motion.tween_method(_action_reaction.bind(epoch, actor, target), 0.0, 1.0, reaction_time)
		_motion.parallel().tween_property(_actor.sprite, "position", _actor.sprite_home, reaction_time)
		var hold: float = _settings.ENEMY_COUNTER_HOLD_TIME if _actor.enemy else \
			(_settings.HIT_HOLD_TIME if actor == "player" else 0.0)
		if hold > 0:
			_motion.tween_interval(hold)
		reaction_time += hold
	else:
		reaction_time = _settings.PLAYER_DEFEND_HOLD_TIME if _action == "DEFEND" else _settings.NPC_STAGE_HOLD_TIME
		_motion.tween_interval(reaction_time)
	_return_at = _impact_at + reaction_time
	_motion.tween_callback(_action_return.bind(epoch, actor, target))
	var return_time: float = _settings.SHORT_LUNGE_RETURN_TIME
	if _action == "DEFEND":
		return_time = _settings.PLAYER_DEFEND_RECOVER_TIME
	elif _action != "ATTACK":
		return_time = _settings.GUARD_POSE_RETURN_TIME
	_motion.tween_property(_actor.root, "position", _actor.home, return_time)
	_motion.parallel().tween_property(_actor.sprite, "position", _actor.sprite_home, return_time)
	_motion.parallel().tween_property(_actor.sprite, "scale", _actor.scale, return_time)
	_motion.parallel().tween_property(_actor.sprite, "modulate", _actor.tint, return_time)
	if _target.root != _actor.root:
		_motion.parallel().tween_property(_target.root, "position", _target.home, return_time)
		_motion.parallel().tween_property(_target.sprite, "scale", _target.scale, return_time)
		_motion.parallel().tween_property(_target.sprite, "modulate", _target.tint, return_time)
	_motion.tween_interval(_settings.ACTION_HANDOFF_PAUSE)
	_complete_at = _return_at + return_time + _settings.ACTION_HANDOFF_PAUSE
	_motion.tween_callback(_action_complete.bind(epoch, actor, target))


func _action_reaction(weight: float, epoch: int, actor: String, target: String) -> void:
	if not _current(epoch, actor, target, "IMPACT") or not _feedback.get("hit", false):
		return
	var guarded: bool = _feedback.get("guarded", false)
	var recoil: float = _settings.ENEMY_RECOIL_DISTANCE
	if _actor.enemy:
		recoil = _settings.GUARDED_HIT_RECOIL_DISTANCE if guarded else _settings.PLAYER_HIT_RECOIL_DISTANCE
	_target.root.position = _target.home.lerp(_target.home + Vector2(_facing * recoil, 0), weight)
	_target.sprite.modulate = _target.tint.lerp(_settings.PLAYER_DEFEND_BRACE_TINT if guarded else Color(1, 0.55, 0.55), weight)
	_target.sprite.scale = _target.scale.lerp(_target.scale * (_settings.GUARDED_HIT_SQUASH if guarded else _settings.IMPACT_SPRITE_SQUASH), weight)


func _action_return(epoch: int, actor: String, target: String) -> void:
	if _current(epoch, actor, target, "IMPACT") and _motion.get_total_elapsed_time() >= _return_at:
		phase = "RETURN"


func _action_complete(epoch: int, actor: String, target: String) -> void:
	if not _current(epoch, actor, target, "RETURN") or _motion.get_total_elapsed_time() < _complete_at:
		return
	if _actor.root.position != _actor.home or _target.root.position != _target.home \
		or _actor.sprite.position != _actor.sprite_home:
		return
	phase = "COMPLETED"
	_motion = null
	var callback: Callable = _on_complete
	_on_complete = Callable()
	callback.call()
