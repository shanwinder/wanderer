extends SceneTree

const Scene = preload("res://scenes/combat/combat_m4_playable_optin.tscn")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const Contract = preload("res://scripts/m4/playable_contract.gd")
const MAIN := "m405-demo/main"
const HOMES := [Vector2(570, 465), Vector2(320, 480), Vector2(405, 435),
	Vector2(475, 509), Vector2(970, 506), Vector2(1100, 424)]

var battle: Control
var owner: RefCounted
var hud: Control
var checks: Array = []
var traces: Dictionary = {}
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_start()
	await process_frame
	await process_frame
	_input_and_round()
	_target_fallback()
	_restart_cases()
	_rescue_and_retreat()
	_victory("enemy_a", "enemy_b", false)
	_victory("enemy_b", "enemy_a", true)
	_defeat()
	_exhaustion()
	_failed_close()
	battle.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var report := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if _check(report != null, "write evidence"):
				report.store_string(JSON.stringify({"checks": checks, "failures": failures, "traces": traces}, "\t"))
	print("B5 SCENE PROOF: %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks.size(), failures])
	quit(int(failures != 0))


func _start(fixture: String = MAIN, version: int = 1) -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = Scene.instantiate()
	battle.fixture_id = fixture
	battle.fixture_version = version
	root.add_child(battle)
	battle.set_process(false)
	owner = battle._owner
	hud = battle.get_node("HUD")


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL: " + label)
	return ok


func _button(node_name: String) -> Button:
	return hud.find_child(node_name, true, false) as Button


func _step() -> void:
	# Use the scene's real frame driver and real Tween callbacks at deterministic checkpoints.
	battle._process(0.0)


func _command(target: String = "") -> void:
	if not _check(owner.read_view().command_ready, "owner permits Player input"):
		return
	if target.is_empty():
		_button("Defend").pressed.emit()
		return
	var picker: OptionButton = hud._target
	for i in picker.item_count:
		if picker.get_item_metadata(i) == target:
			picker.select(i)
			_button("Attack").pressed.emit()
			return
	_check(false, "live target selectable " + target)


func _play_action(cancel: bool = false) -> Dictionary:
	var view: Dictionary = owner.read_view()
	if view.active_token == null:
		return {}
	var token: Dictionary = view.active_token
	var before: Dictionary = owner.snapshot()
	var tween: Tween = hud._motion._motion
	if not _check(tween != null and tween.is_valid(), "authorized token starts a real Tween"):
		return {}
	if cancel:
		# Exercise the existing DRIVER cancellation lane for contract reachability.
		# The live UI never cancels a companion's authorized choice.
		var reply: Dictionary = battle._drive("CANCEL", {"token": token})
		hud._motion.cancel()
		battle._refresh()
		var after: Dictionary = owner.snapshot()
		_check(reply.status == "APPLIED" and after.party == before.party and after.enemies == before.enemies
			and after.receipts == before.receipts and after.queue.dispositions.back().kind == "CANCELLED",
			"pre-impact cancellation has no effect/receipt")
		return {}
	_reach_impact(tween)
	var impacted: Dictionary = owner.snapshot()
	if not _check(impacted.actions.back().phase in ["APPLIED", "SKIPPED"], "real IMPACT from Tween"):
		return {}
	var effect: Dictionary = impacted.actions.back().effect
	if token.kind == "ATTACK":
		var actor: Dictionary = hud._actors[token.actor_id]
		_check(is_equal_approx(absf(actor.root.position.x - actor.home.x), 44.0), "44px attack lunge at impact")
	if effect.status == "SKIPPED":
		_check(hud._log.text.contains("ข้ามผล"), "SKIPPED visibly distinguished from a hit")
		_check(impacted.party == before.party and impacted.enemies == before.enemies
			and not hud._motion._feedback.get("hit", false), "SKIPPED preserves HP and produces no hit reaction")
	_check(impacted.receipts == before.receipts, "impact alone cannot issue receipt")
	_finish_tween(tween)
	var settled: Dictionary = owner.snapshot()
	_check(settled.receipts.size() == before.receipts.size() + 1
		and settled.receipts.back().action_id == token.action_id
		and settled.actions.back().phase == "COMPLETED", "real COMPLETE adds exactly one receipt")
	_check(_at_homes(), "actor and target returned to saved homes before completion")
	return effect


func _reach_impact(tween: Tween) -> void:
	for _frame in range(120):
		if hud._motion.phase != "WINDUP" or not tween.is_valid():
			break
		tween.custom_step(1.0 / 60.0)


func _finish_tween(tween: Tween) -> void:
	for _frame in range(120):
		if not tween.is_valid():
			break
		tween.custom_step(1.0 / 60.0)


func _round(cancel_ids: Array = []) -> Array:
	var effects: Array = []
	for _tick in range(14):
		var view: Dictionary = owner.read_view()
		if view.phase in ["TERMINAL", "CLOSED", "SEALED"]:
			break
		_step()
		view = owner.read_view()
		if view.active_token != null:
			var effect := _play_action(view.active_token.actor_id in cancel_ids)
			if not effect.is_empty():
				effects.append(effect)
		elif view.phase != "OPEN":
			break
	return effects


func _at_homes() -> bool:
	var i := 0
	for actor in hud._actors.values():
		if actor.root.position != HOMES[i] or actor.sprite.position != actor.sprite_home:
			return false
		i += 1
	return true


func _trace(label: String) -> Array:
	var events: Array = owner.read_presentation_events()
	var timeline: Dictionary = {}
	_check(events.size() == battle._shown_events, label + " scene consumed committed event stream")
	for event in events:
		_check(Contract.valid("PresentationEvent", event), label + " exact event " + event.kind)
		if event.token == null:
			continue
		var action_id: int = event.token.action_id
		var previous: String = timeline.get(action_id, "")
		match event.kind:
			"INTENT": _check(previous.is_empty(), label + " first INTENT")
			"IMPACT": _check(previous == "INTENT", label + " IMPACT after INTENT")
			"TERMINAL": _check(previous == "IMPACT", label + " terminal-causing IMPACT first")
			"COMPLETION": _check(previous in ["IMPACT", "TERMINAL"]
				and event.receipt.action_id == action_id, label + " one causal COMPLETION")
		timeline[action_id] = event.kind
	traces[label] = {"events": events, "root": owner.snapshot(), "restart_audit": owner.restart_audit(),
		"log": hud._log.text}
	return events


func _input_and_round() -> void:
	var seed: Dictionary = owner.snapshot()
	_check(seed.seed == Catalog.seed_reference_snapshot(MAIN) and seed.party == Catalog.initial_party(MAIN, seed.session, 1)
		and seed.enemies == Catalog.initial_enemies(MAIN), "one scene owner starts with correct immutable seed")
	_check(battle._input_adapter._owner == owner and battle._callbacks._owner == owner
		and battle._callbacks._capability == battle._presenter, "driver/input/callbacks share one owner")
	_check(_at_homes() and hud._commands.visible and hud._status.text.contains("เลือกคำสั่ง")
		and hud._cards.player.state.text == "HP 30/30", "initial formation, Thai prompt and health")
	_check(root.gui_get_focus_owner() == hud._target, "keyboard focus starts at Player target")
	for id in ["Attack", "Defend", "Guidance", "PlayerTarget", "SendGuidance", "Restart", "BattleLog"]:
		var control: Control = hud.find_child(id, true, false)
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(control.get_global_rect()), "control fits 1280×720 " + id)

	for index in hud._guidance.item_count:
		hud._guidance.select(index)
		hud._guidance.item_selected.emit(index)
		hud._focus_target.select(1)
		_button("SendGuidance").pressed.emit()
		var pending: Dictionary = owner.read_view().guidance.pending
		_check(pending.guidance_type == hud._guidance.get_item_metadata(index), "real Guidance v1 selection " + str(index))
	var selected: Dictionary = owner.read_view()
	_check(selected.guidance.pending.preferred_target_id == "enemy_b" and selected.guidance.guidance_revision == 5,
		"Focus target and R1 revision preserved")
	_check(battle._command("ATTACK", "invalid", selected.identity).reason == "M405_INVALID_TARGET"
		and owner.read_view() == selected, "invalid target rejects without consuming Pending")
	_command("enemy_b")
	var accepted: Dictionary = owner.snapshot()
	_check(accepted.command.target_id == "enemy_b" and accepted.command.accepted_round == 1, "Player-selected target bound")
	_check(not hud._commands.visible and not hud._guidance_row.visible
		and battle._command("DEFEND", "player", selected.identity).is_empty()
		and battle._guidance("NONE", "", selected.identity).is_empty()
		and owner.snapshot() == accepted, "duplicate and stale input leave accepted root unchanged")
	_step()
	_check(owner.read_view().guidance.active == selected.guidance.pending, "admission freezes real Pending")
	_round()
	var closed: Dictionary = owner.snapshot()
	_check(closed.phase == "PREPARED" and closed.round_id == 2 and closed.round_history.size() == 1
		and hud._commands.visible, "one natural close, next Player input")
	if _check(closed.round_history.size() == 1, "round history present"):
		var queue: Dictionary = closed.round_history[0].queue
		var ids: Array = []
		for disposition in queue.dispositions:
			ids.append(disposition.actor_id)
			_check(disposition.kind == "COMPLETED", "owned disposition " + disposition.actor_id)
		_check(ids == Catalog.PARTY + Catalog.ENEMIES, "Player→NPCs→Enemies order")
	_check(closed.journal.filter(func(row: Dictionary) -> bool: return row.operation == "DECIDE_LOCK").size() == 3
		and closed.receipts.size() == 6, "three independent decisions and six receipts")
	var events := _trace("real-input-and-round")
	_check(events.back().kind == "ROUND_CLOSED", "close event published")


func _target_fallback() -> void:
	_start()
	for _i in range(3):
		_command("enemy_a")
		_round()
	var view: Dictionary = owner.read_view()
	_check(not view.enemies[0].available and view.enemies[1].available and hud._target.item_count == 1
		and hud._target.get_item_metadata(0) == "enemy_b", "unavailable target removed from picker")
	var reply: Dictionary = battle._command("ATTACK", "enemy_a", view.identity)
	_check(reply.get("status") == "ACCEPTED", "known but unavailable preference uses the owner fallback lane")
	_step()
	_step()
	var lock_view: Dictionary = owner.read_view()
	_check(lock_view.active_token != null and lock_view.active_token.target_id == "enemy_b",
		"real PLAYER_LOCK retargets to living Enemy B")
	_play_action()
	_trace("unavailable-target-and-owner-fallback")


func _restart_cases() -> void:
	_start()
	var stale_identity: Dictionary = owner.read_view().identity
	_restart("normal-prepared", false)
	_check(battle._command("DEFEND", "player", stale_identity).is_empty(), "old generation command rejected locally")
	_command()
	_restart("before-lock", false)
	_command()
	_step()
	_step()
	var token: Dictionary = owner.read_view().active_token
	var original_generation: int = owner.read_view().identity.generation
	var duplicate: Callable = battle._callbacks.bind(token, "COMPLETE", "driver/b5-duplicate")
	owner.inject_failure_before_publication(battle._driver)
	_check(battle._restart().reason == "M405_INVALID_CANDIDATE"
		and owner.read_view().identity.generation == original_generation
		and hud._motion.phase == "WINDUP", "rejected Restart preserves windup and epoch")
	_play_action()
	var settled: Dictionary = owner.snapshot()
	_check(settled.receipts.size() == 1, "pending real callback survives rejected Restart")
	_check(duplicate.call().reason == "M405_INVALID_TOKEN_PHASE" and owner.snapshot() == settled,
		"duplicate COMPLETE rejected without adding a receipt")
	_step()
	_restart("windup", true)
	_command()
	_step()
	_step()
	_reach_impact(hud._motion._motion)
	_check(owner.snapshot().actions.back().phase == "APPLIED", "impact committed before Restart")
	_restart("post-impact", true)
	_check(owner.restart_audit().back().root.actions.back().phase == "APPLIED"
		and owner.restart_audit().back().root.receipts.is_empty(), "audit retains old impact without invented receipt")
	_check(token.identity.generation < owner.read_view().identity.generation, "old token belongs to an earlier generation")


func _restart(label: String, active: bool) -> void:
	var before: Dictionary = owner.snapshot()
	var old_events: Array = owner.read_presentation_events()
	var callback: Callable
	var old_impact: Callable
	var old_motion: Tween
	var epoch: int = hud._motion.visual_epoch
	if active:
		callback = battle._callbacks.bind(before.actions.back().token, "COMPLETE", "driver/b5-late")
		old_motion = hud._motion._motion
		old_impact = battle._callbacks.bind(before.actions.back().token, "IMPACT", "driver/b5-late-impact")
	_check(not _button("Restart").disabled, label + " Restart reachable")
	_button("Restart").pressed.emit()
	var reset: Dictionary = owner.snapshot()
	_check(reset.session == before.session and reset.generation == before.generation + 1
		and reset.revision == 0 and reset.seed == before.seed and reset.journal.is_empty()
		and reset.receipts.is_empty() and _at_homes() and hud._motion.visual_epoch > epoch, label + " real reset and visual epoch")
	_check(reset.party == Catalog.initial_party(reset.seed.fixture_id, reset.session, reset.generation, reset.seed.fixture_version)
		and reset.enemies == Catalog.initial_enemies(reset.seed.fixture_id, reset.seed.fixture_version),
		label + " catalog actors restored")
	_check(owner.restart_audit().back().root == before, label + " authentic archived root")
	if active:
		_check(callback.is_valid() and callback.call().is_empty() and old_impact.call().is_empty() and owner.snapshot() == reset
			and not old_motion.is_valid(), label + " abandoned callback and Tween inert")
	var events := _trace(label)
	_check(events.size() == 1 and events[0].kind == "RESET", label + " only current RESET event")
	traces[label]["previous_events"] = old_events


func _rescue_and_retreat() -> void:
	_start("m405-demo/player-down")
	_round()
	var history: Dictionary = owner.snapshot().round_history[0]
	_check(history.queue.dispositions[0].kind == "UNAVAILABLE" and history.queue.dispositions[0].action_id == null,
		"DOWN Player's disposed slot has no proxy action")
	var events := _trace("rescue")
	var rescue := events.filter(func(e: Dictionary) -> bool: return e.kind == "IMPACT" and e.token.kind == "RESCUE")
	_check(rescue.size() == 1 and rescue[0].effect.hp_delta == 1
		and rescue[0].view.party[1].rescue_uses == 0 and not rescue[0].view.command_ready, "RESCUE spends its resource without reopening Player slot")
	_start(Catalog.PLAYER_LOW, 2)
	_command()
	_round()
	events = _trace("help-guard-retreat")
	var effects := events.filter(func(e: Dictionary) -> bool: return e.kind == "IMPACT")
	var helped := effects.any(func(e: Dictionary) -> bool:
		return e.token.kind == "HELP" and e.effect.hp_delta == 4 and e.effect.resources[0].resource == "HELP"
	)
	_check(helped, "authentic HELP +4 and resource debit")
	_check(owner.snapshot().party[3].participation == "RETREATED" and not hud._actors.npc_03.root.visible
		and owner.snapshot().outcome == null, "ordinary NPC RETREAT visibly removes participation")
	_check(hud._log.text.contains("การ์ดลดแรงโจมตี") and hud._log.text.contains("การ์ดหมดเมื่อปิดรอบ"),
		"actual Guard mitigation and expiration visible")


func _victory(first: String, last: String, interrupt: bool) -> void:
	_start()
	var kill_order: Array = []
	var frozen: Dictionary = {}
	for _round_id in range(1, 7):
		var enemies: Array = owner.read_view().enemies
		var target: String = first if enemies[0 if first == "enemy_a" else 1].available else last
		_command(target)
		for _tick in range(14):
			_step()
			var view: Dictionary = owner.read_view()
			if view.active_token == null:
				if view.phase != "OPEN":
					break
				continue
			var tween: Tween = hud._motion._motion
			_reach_impact(tween)
			var impact_view: Dictionary = owner.read_view()
			for enemy in impact_view.enemies:
				if not enemy.available and enemy.actor_id not in kill_order:
					kill_order.append(enemy.actor_id)
			if impact_view.outcome != null:
				frozen = impact_view.outcome
				var events := _trace("victory-impact-" + first)
				_check(events[-2].kind == "IMPACT" and events[-1].kind == "TERMINAL"
					and events[-1].identity == events[-2].identity and hud._status.text.contains("VICTORY"),
					"terminal impact and outcome published together")
				if interrupt:
					_check(kill_order == [first, last] and frozen.result == "VICTORY", "legal kill order " + first)
					_restart("terminal-causal-lane", true)
					return
			_finish_tween(tween)
			if not frozen.is_empty():
				break
		if not frozen.is_empty() or owner.read_view().phase == "CLOSED":
			break
	var final: Dictionary = owner.snapshot()
	var events := _trace("victory-settled-" + first)
	_check(kill_order == [first, last] and frozen.get("result") == "VICTORY", "legal kill order " + first)
	if _check(not frozen.is_empty(), "genuine terminal action available"):
		var late: Callable = battle._callbacks.bind(final.actions.back().token, "COMPLETE", "driver/b5-duplicate")
		_check(not late.is_valid() and final.outcome == frozen and events.back().kind == "COMPLETION"
			and final.queue.phase == "STOPPED", "terminal causal settlement stays frozen")
		_restart("terminal-settled", false)


func _defeat() -> void:
	_start(Catalog.PLAYER_LOW, 2)
	for _i in range(6):
		if owner.read_view().command_ready:
			_command()
		_round(Catalog.PARTY)
	var result: Dictionary = owner.snapshot()
	_check(result.outcome != null and result.outcome.result == "DEFEAT"
		and result.outcome.reason == "M403_NO_ACTIVE_PARTY" and result.party[1].life == "DOWN"
		and result.queue.phase == "STOPPED" and hud._status.text.contains("DEFEAT"), "Last-Party DOWN with causal completion")
	_trace("last-party-down-with-legal-driver-cancels")


func _exhaustion() -> void:
	_start()
	for i in range(6):
		_command()
		_round(["player", "enemy_a", "enemy_b"] if i == 0 else ["player"])
	var result: Dictionary = owner.snapshot()
	_check(result.phase == "CLOSED" and result.closed_rounds == 6 and result.outcome == null
		and hud._status.text.contains("ครบ 6 รอบ"), "six natural closes exhaust demo without frozen outcome")
	_check(hud._log.text.contains("เสียชีวิต") and hud._log.text.contains("เวลาช่วยให้ลุก"), "owned DEAD and clock events visible")
	_trace("six-close-with-legal-driver-cancels")
	_restart("post-exhaustion", false)


func _failed_close() -> void:
	_start()
	_command("enemy_a")
	_step()
	_step()
	var stale: Callable = battle._callbacks.bind(owner.read_view().active_token, "COMPLETE", "driver/b5-stale-held")
	_play_action()
	owner.inject_failure_before_close_commit(battle._driver)
	_round()
	var held: RefCounted = owner
	var diagnostic: Dictionary = held.close_failure_diagnostic()
	var old: Dictionary = held.snapshot()
	_check(old.phase == "SEALED" and diagnostic.reason == "M405_CLOSE_FAILED" and diagnostic.root == old
		and _button("Restart").disabled and _button("ExitHeldSession").visible
		and hud._status.text.contains(diagnostic.reason), "E5 genuine diagnostic and explicit exit")
	_check(battle._restart().reason == "M405_SEALED_RESTART" and held.snapshot() == old, "direct SEALED Restart rejected")
	_trace("e5-held")
	_button("ExitHeldSession").pressed.emit()
	owner = battle._owner
	var fresh: Dictionary = owner.snapshot()
	_check(fresh.session != old.session and fresh.generation == 1 and fresh.revision == 0
		and fresh.journal.is_empty() and fresh.receipts.is_empty() and owner.restart_audit().is_empty()
		and stale.call().is_empty() and held.snapshot() == old and _at_homes(), "E5 fresh factory session, detached callback, preserved held root")
	_trace("e5-fresh")
