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
