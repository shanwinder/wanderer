extends "res://tests/combat/autonomous_main_integration.gd"

const Base = preload("res://scripts/combat/full_party_encounter.gd")
const GuidedMain = preload("res://scripts/combat/guided_encounter.gd")
const ProofOnly = preload("res://scripts/npc/guided_decision_proof_encounter.gd")
const Messages = preload("res://scripts/combat/guidance_messages.gd")
var coverage: Array = []

# Test only: force the documented partial-failure path after ACCEPTED submission.
class RejectingRound extends GuidedMain:
	func begin_round(_action: Variant, _target: Variant = "", _hits: Variant = {}) -> Dictionary:
		return {"status": "REJECTED", "reason_code": "INVALID_ENEMY_TARGET"}



func _case(id: String, expected: String) -> void:
	_record(id, expected)
	coverage.append({"id": id, "expected": expected, "actual": cases.back().actual})


func _draft(kind: String, target: String = "") -> void:
	var index: int = scene.GUIDANCE_TYPES.find(kind)
	scene.guidance_picker.select(index)
	scene.guidance_picker.item_selected.emit(index)
	if kind == "FOCUS_TARGET":
		for i in range(scene.guidance_focus_picker.item_count):
			if scene.guidance_focus_picker.get_item_metadata(i) == target:
				scene.guidance_focus_picker.select(i)
				scene.guidance_focus_picker.item_selected.emit(i)


func _response(id: String) -> Dictionary:
	for event in events:
		if event.token.actor_id == id:
			return event.token.get("guidance_decision", {}).get("guidance_response", {})
	return {}


func _req(e, kind: String = "NONE", target: String = "") -> Dictionary:
	var v: Dictionary = e.guidance_snapshot()
	return {"schema_version": 1, "guidance_type": kind, "preferred_target_id": target,
		"issuer_player_id": e.snapshot().player_id, "encounter_id": v.encounter_id,
		"generation": v.generation, "round_id": v.round_id, "expected_guidance_revision": v.guidance_revision}


func _revision_contract() -> void:
	var e = GuidedMain.new()
	var v: Dictionary = e.guidance_snapshot()
	_check(e.submit_guidance(_req(e, "FOCUS_TARGET", "enemy_b")).status == "ACCEPTED", "R1 accepted submit")
	_check(e.guidance_snapshot().guidance_revision == v.guidance_revision + 1, "R1 submit +1")
	var stale: Dictionary = _req(e, "ATTACK")
	var before: Dictionary = e.snapshot()
	_check(e.unregister_actor("enemy_b"), "remove preferred Enemy")
	v = e.guidance_snapshot()
	_check(v.guidance_revision == stale.expected_guidance_revision + 1
		and v.pending.guidance_revision == v.guidance_revision and v.pending.guidance_type == "NONE"
		and v.pending.preferred_target_id == "", "R1 invalidate +1 and coherent NONE record")
	_check(e.snapshot().actors.player == before.actors.player and e.snapshot().help_uses == before.help_uses
		and e.snapshot().pending == before.pending and e.snapshot().guards == before.guards,
		"invalidation affects no HP/resources/queue/Guard")
	var stable: Dictionary = e.guidance_snapshot()
	_check(e.submit_guidance(stale).reason_code == "STALE_GUIDANCE_REVISION", "old snapshot cannot overwrite system clear")
	_check(e.guidance_snapshot() == stable, "reject atomic")
	_check(e.guidance_snapshot() == stable and e.guidance_snapshot() == stable, "reads do not increment")
	_check(not e.unregister_actor("enemy_b") and not e.unregister_actor("missing"), "duplicate/unknown removals fail")
	_check(e.guidance_snapshot() == stable, "failed removal no increment")
	_check(e.submit_guidance(_req(e, "FOCUS_TARGET", "enemy_b")).reason_code == "UNKNOWN_GUIDANCE_TARGET", "fresh revision cannot restore removed Enemy")
	_check(e.guidance_snapshot() == stable, "unknown focus reject no increment")
	_check(e.submit_guidance(_req(e, "ATTACK")).status == "ACCEPTED", "fresh client accepted")
	var revision: int = e.guidance_snapshot().guidance_revision
	_check(e.unregister_actor("npc_02") and e.guidance_snapshot().guidance_revision == revision, "non-preferred roster removal no Guidance increment")
	_check(e.begin_round("DEFEND").status == "STARTED", "freeze succeeds")
	var frozen: Dictionary = e.guidance_snapshot()
	_check(not e.unregister_actor("enemy_a") and e.submit_guidance(_req(e)).reason_code == "COMMAND_LOCKED", "running queue cannot mutate roster/Guidance")
	_check(e.guidance_snapshot() == frozen, "frozen content/revision unchanged")
	var old: Dictionary = _req(e)
	_check(e.restart(Base.prototype_fixture()), "restart")
	_check(e.guidance_snapshot().guidance_revision == 0 and e.guidance_snapshot().generation == old.generation + 1, "Restart resets revision changes generation")
	_check(e.submit_guidance(old).reason_code == "STALE_GENERATION", "old request rejected after Restart")
	for preferred in ["enemy_a", "enemy_b"]:
		e.restart(Base.prototype_fixture())
		e.submit_guidance(_req(e, "FOCUS_TARGET", preferred))
		revision = e.guidance_snapshot().guidance_revision
		_check(e.fixture_damage(preferred, 99, e.snapshot().generation).status == "APPLIED"
			and e.guidance_snapshot().guidance_revision == revision
			and e.guidance_snapshot().pending.preferred_target_id == preferred, "HP0 retains registered preference/revision " + preferred)
		_check(e.unregister_actor(preferred) and e.guidance_snapshot().guidance_revision == revision + 1, "both enemy IDs invalidate exactly once " + preferred)
	e.restart(Base.prototype_fixture())
	e.submit_guidance(_req(e, "FOCUS_TARGET", "enemy_a"))
	revision = e.guidance_snapshot().guidance_revision
	_check(e.unregister_actor("enemy_b") and e.guidance_snapshot().guidance_revision == revision, "unrelated enemy removal retains focus/revision")
	_case("I21", "R1 Option A: accepted submit/system preference clear +1; reads/rejects/HP0/unrelated roster changes unchanged; stale clients rejected; Frozen immutable; Restart new generation/rev0")


func _ui_contract() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/combat/combat_autonomous_optin.tscn", "configured F5")
	_case("I01", "F5 remains Autonomous")
	_check(scene.encounter is GuidedMain and not scene.encounter is ProofOnly, "production Guided type")
	_case("I02", "Main uses production guided policy, no proof-class dependency")
	_observe()
	_case("I03", "single Encounter authority; Legacy mirrors/queue/targets null")
	_check(scene.encounter.guidance_snapshot().pending.guidance_type == "NONE" and scene.guidance_draft_type == "NONE", "initial NONE")
	_case("I04", "initial Guidance NONE")
	var data: Dictionary = scene.encounter.guidance_snapshot()
	_draft("FOCUS_TARGET", "enemy_b")
	_check(scene.autonomous_selected_target == "enemy_a" and scene.guidance_draft_target == "enemy_b", "Player A / Focus B independent")
	_check(scene.encounter.guidance_snapshot() == data and scene.guidance_state_label.text.contains("Draft"), "selection is unsubmitted Draft")
	_case("I05", "Player target independent; UI Draft changes no authority")
	scene.attack_button.pressed.emit()
	_check(scene.encounter.guidance_snapshot().active.guidance_type == "FOCUS_TARGET"
		and scene.encounter.guidance_snapshot().active.preferred_target_id == "enemy_b"
		and scene.guidance_state_label.text.contains("Frozen"), "submit accepted then frozen")
	_check(scene.guidance_picker.disabled and scene.guidance_focus_picker.disabled, "busy selector locks")
	var token: Dictionary = scene.autonomous_token.duplicate(true)
	scene.guidance_picker.item_selected.emit(2)
	_check(scene.autonomous_token == token and scene.guidance_draft_type == "FOCUS_TARGET", "busy edit ignored")
	await _idle()
	_check(scene.guidance_draft_type == "NONE" and scene.encounter.guidance_snapshot().pending.guidance_type == "NONE"
		and scene.guidance_state_label.text.contains("Pending"), "round scoped NONE")
	_case("I06", "accepted submit freezes for one round; busy edits inert; completion resets NONE")
	_choose()
	_draft("FOCUS_TARGET")
	scene.attack_button.pressed.emit()
	_check(not scene.action_in_progress and scene.encounter.snapshot().command_ready
		and scene.encounter.guidance_snapshot().guidance_revision == 0
		and scene.guidance_error_label.text.contains("INVALID_GUIDANCE_TARGET"), "invalid draft blocks round")
	for bad in [null, {}, {"schema_version": 1}, _req(scene.encounter)]:
		if typeof(bad) == TYPE_DICTIONARY and bad.size() == 8:
			bad.extra = 1
		var before: Dictionary = scene.encounter.guidance_snapshot()
		_check(scene.encounter.submit_guidance(bad).status == "REJECTED" and scene.encounter.guidance_snapshot() == before, "malformed request atomic")
	# Accepted Guidance followed by rejected Player target must stay Pending.
	var live_encounter = scene.encounter
	scene.encounter = RejectingRound.new()
	scene._start_new_battle()
	_draft("ATTACK")
	scene.defend_button.pressed.emit()
	_check(not scene.action_in_progress and scene.encounter.guidance_snapshot().pending.guidance_type == "ATTACK"
		and scene.encounter.guidance_snapshot().active.is_empty() and scene.guidance_state_label.text.contains("Pending")
		and scene.guidance_error_label.text.contains("INVALID_ENEMY_TARGET"), "rejected round keeps accepted Pending")
	_case("I07", "invalid/malformed Guidance never starts round; accepted Guidance with rejected Player input remains Pending (test-only rejecting Encounter)")
	scene.encounter = live_encounter
	scene._start_new_battle()


func _policies() -> void:
	for row in [
		["I08", 0, "ATTACK", "", "npc_01", "MATCHED_INDEPENDENTLY", "BASELINE_ATTACK"],
		["I09", 0, "FOCUS_TARGET", "enemy_b", "npc_01", "FOLLOWED", "PROFILE_PERMITTED_COOPERATION"],
		["I10", 0, "FOCUS_TARGET", "enemy_a", "npc_01", "MATCHED_INDEPENDENTLY", "BASELINE_TARGET"],
		["I11", 11, "DEFEND", "", "npc_02", "FOLLOWED", "PROFILE_PERMITTED_COOPERATION"],
		["I12", 2, "ATTACK", "", "npc_01", "REFUSED", "SELF_PRESERVATION_PRIORITY"],
		["I13", 1, "FOCUS_TARGET", "enemy_b", "npc_01", "REFUSED", "URGENT_HELP_PRIORITY"],
		["I14", 0, "HELP", "", "npc_01", "NOT_APPLICABLE", "PLAYER_ABOVE_HELP_THRESHOLD"],
		["I15", 1, "HELP", "", "npc_01", "MATCHED_INDEPENDENTLY", "URGENT_HELP_PRIORITY"],
		["I16", 0, "FOCUS_TARGET", "enemy_b", "npc_03", "REFUSED", "PROFILE_PREFERS_BASELINE"]]:
		_choose(row[1])
		if row[0] == "I14":
			scene.encounter.fixture_damage("player", 18, scene.encounter.snapshot().generation)
		_draft(row[2], row[3])
		scene.defend_button.pressed.emit()
		await _idle()
		var response: Dictionary = _response(row[4])
		_check(response.get("response") == row[5] and response.get("reason_code") == row[6], "main policy " + row[0] + str(response))
		_check(scene.autonomous_intents[row[4]].text.contains(Messages.message(row[5])), "Thai response visible " + row[0])
		_case(row[0], "Main per-slot policy: " + row[5] + " / " + row[6])
	_choose(10)
	_draft("FOCUS_TARGET", "enemy_b")
	scene.defend_button.pressed.emit()
	await _idle()
	_check(_response("npc_01").response == "FOLLOWED" and _response("npc_02").response == "REFUSED"
		and _response("npc_02").reason_code == "SELF_PRESERVATION_PRIORITY"
		and _response("npc_03").reason_code == "PROFILE_PREFERS_BASELINE", "same team Guidance three responses")
	_case("I17", "NPC1 follows; NPC2 safety refusal; NPC3 profile refusal from same Guidance")
	_choose(9, "enemy_b")
	_draft("FOCUS_TARGET", "enemy_b")
	scene.attack_button.pressed.emit()
	await _idle()
	_check(_response("npc_01").response == "NOT_APPLICABLE" and _response("npc_01").reason_code == "TARGET_UNAVAILABLE", "focus dead before slot reevaluated")
	_case("I18", "Player kills focused B before NPC slot; NPC chooses living A")
	_choose()
	_draft("FOCUS_TARGET", "enemy_b")
	scene.defend_button.pressed.emit()
	await _wait("npc_01", "WINDUP")
	var locked: Dictionary = scene.autonomous_token.duplicate(true)
	# Existing race-test technique, no production mid-action HP API.
	scene.encounter._registry.fixture_damage("enemy_b", 99)
	scene._refresh_autonomous_ui()
	await _wait("npc_01", "IMPACT")
	_check(scene.encounter.snapshot().locked_action.effect.status == "SKIP"
		and scene.encounter.snapshot().locked_action.guidance_decision == locked.guidance_decision
		and scene.autonomous_intents.npc_01.text.contains("SKIP HP +0")
		and scene.autonomous_intents.npc_01.text.contains(Messages.message("FOLLOWED")), "lock followed + actual SKIP separately visible")
	await _idle()
	_case("I19", "Focus dies after lock; no retarget/damage; FOLLOWED retained and actual SKIP HP0")
	_choose()
	_draft("FOCUS_TARGET", "enemy_b")
	_check(scene.encounter.submit_guidance(scene._guidance_request()).status == "ACCEPTED", "pending focus")
	await process_frame
	var old: Dictionary = scene._guidance_request()
	_check(scene.encounter.unregister_actor("enemy_b"), "command-ready remove")
	await process_frame
	_check(scene.guidance_draft_type == "NONE" and scene.guidance_state_label.text.contains("rev 2")
		and scene.encounter.submit_guidance(old).reason_code == "STALE_GUIDANCE_REVISION", "UI detects system clear revision")
	_check(scene.guidance_focus_picker.item_count == 2 and scene.target_picker.item_count == 1, "both pickers reflect roster without alias")
	_case("I20", "system invalidation refreshes UI NONE/revision and removes enemy; stale request rejected")
	_choose()
	var snapshot: Dictionary = scene.encounter.guidance_snapshot()
	snapshot.pending.guidance_type = "HELP"
	snapshot.profiles.npc_01.trust = "CAUTIOUS"
	_check(scene.encounter.guidance_snapshot().pending.guidance_type == "NONE"
		and scene.encounter.guidance_snapshot().profiles.npc_01.trust == "ESTABLISHED", "nested detached snapshots")
	_draft("FOCUS_TARGET", "enemy_b")
	scene.defend_button.pressed.emit()
	await _wait("npc_01", "WINDUP")
	var detached: Dictionary = scene.encounter.snapshot()
	detached.locked_action.guidance_decision.guidance_response.details.actor_profile.trust = "CAUTIOUS"
	_check(scene.encounter.snapshot().locked_action == scene.autonomous_token, "UI snapshot cannot mutate token")
	await _idle()
	_choose(7)
	_draft("ATTACK")
	scene.defend_button.pressed.emit()
	await _idle()
	_check(_response("npc_01").get("response") == "NOT_APPLICABLE"
		and _response("npc_01").get("reason_code") == "ACTOR_UNAVAILABLE", "unavailable NPC explains skipped slot without changing base decision")
	_case("I22", "nested Guidance/UI/token data detached; unavailable NPC metadata explains actual base SKIP")


func _restart_and_effects() -> void:
	for phase in ["WINDUP", "IMPACT", "RETURN"]:
		_choose()
		_draft("FOCUS_TARGET", "enemy_b")
		scene.defend_button.pressed.emit()
		await _wait("npc_01", phase)
		var old: Dictionary = scene.autonomous_token.duplicate(true)
		var epoch: int = scene.presentation_adapter.visual_epoch
		scene.restart_button.pressed.emit()
		var before: Dictionary = scene.encounter.snapshot()
		scene._autonomous_impact(old)
		scene._autonomous_complete(old)
		_check(scene.encounter.resolve_action(old).status == "REJECTED" and scene.encounter.complete_action(old).status == "REJECTED", "old token rejected")
		for frame in range(100):
			await process_frame
		_check(scene.encounter.snapshot() == before and scene.presentation_adapter.visual_epoch > epoch
			and scene.guidance_draft_type == "NONE" and scene.encounter.guidance_snapshot().guidance_revision == 0
			and scene.damage_popups.is_empty() and scene.hit_sparks.is_empty(), "restart cancels delayed callbacks/feedback " + phase)
		_case({"WINDUP": "I23", "IMPACT": "I24", "RETURN": "I25"}[phase], "Guided Restart " + phase + ": fresh generation/NONE/rev0; delayed old callbacks inert")
	_choose()
	_draft("FOCUS_TARGET", "enemy_b")
	scene.defend_button.pressed.emit()
	await _wait("npc_01", "WINDUP")
	var forged: Dictionary = scene.autonomous_token.duplicate(true)
	forged.guidance_decision.guidance_response.response = "REFUSED"
	scene.autonomous_token = forged.duplicate(true) # Even a forged matching UI cache cannot bypass authority comparison.
	scene.presentation_adapter.phase = "IMPACT"
	var before: Dictionary = scene.encounter.snapshot()
	_check(scene._autonomous_impact(forged).is_empty() and scene.encounter.snapshot() == before, "controller compares guidance metadata against Encounter")
	scene.restart_button.pressed.emit()
	_case("I26", "forged Guided metadata rejected even when controller cache matches; old generation/token callbacks covered I23-25")
	for index in [5, 6]:
		_choose(index)
		_draft("ATTACK")
		scene.attack_button.pressed.emit()
		await _idle()
		_check(scene.encounter.snapshot().result == ("VICTORY" if index == 5 else "DEFEAT")
			and scene.guidance_picker.disabled and scene.encounter.guidance_snapshot().active.is_empty()
			and scene.encounter.guidance_snapshot().pending.is_empty() and scene.battle_result_panel.visible, "guided terminal cleanup")
		before = scene.encounter.snapshot()
		scene.guidance_picker.item_selected.emit(3)
		scene.attack_button.pressed.emit()
		_check(scene.encounter.snapshot() == before, "terminal inputs inert")
	_case("I27", "Guided victory/defeat clear Guidance, lock inputs and present result")
	for row in [[1, "HELP", "npc_01", "HELP"], [11, "DEFEND", "npc_02", "DEFEND"]]:
		_choose(row[0])
		_draft(row[1])
		scene.defend_button.pressed.emit()
		await _wait(row[2], "IMPACT")
		var token: Dictionary = scene.autonomous_token.duplicate(true)
		before = scene.encounter.snapshot()
		_check(token.decision.action == row[3] and before.locked_action.effect.status == "APPLIED", "guided effect applied")
		_check(scene.encounter.resolve_action(token).status == "REJECTED" and scene._autonomous_impact(token).is_empty()
			and scene.encounter.snapshot() == before, "duplicate impact no HP/HELP/Guard mutation")
		if row[1] == "HELP":
			_check(before.help_uses.npc_01 == 0 and before.actors.player.current_hp == 10
				and scene.autonomous_effect_label.text.contains("HELP use 1 → 0"), "HELP +4 once with actual consumption")
		else:
			_check(before.guards.has("npc_02") and scene.autonomous_intents.npc_02.text.contains("GUARD"), "actual guard visible")
		await _idle()
		if row[1] == "DEFEND":
			_check(scene.encounter.actor_snapshot("npc_02").current_hp == 9, "next valid self hit reduced 3 to1")
	_case("I28", "HELP +4/use once and self Guard next-hit semantics; duplicate impacts inert")


func _layout_and_equivalence() -> void:
	_choose()
	await process_frame
	var controls: Array = [scene.guidance_picker, scene.guidance_focus_picker, scene.target_picker,
		scene.attack_button, scene.defend_button, scene.restart_button, scene.autonomous_scenario_picker]
	for i in range(controls.size()):
		var rect: Rect2 = controls[i].get_global_rect()
		_check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 1280 and rect.end.y <= 720, "control within viewport")
		_check(controls[i].focus_mode == Control.FOCUS_ALL and not controls[i].focus_next.is_empty(), "keyboard focus cycle")
		for j in range(i + 1, controls.size()):
			_check(not rect.intersects(controls[j].get_global_rect()), "distinct control hitboxes")
		_check(not rect.intersects(scene.combat_log.get_global_rect()), "log clear of control")
	_case("I29", "1280x720 independent controls/hitboxes; explicit keyboard focus cycle; scrollable log clear of commands (visual acceptance separate)")
	var required: Array = ["NONE", "FOLLOWED", "MATCHED_INDEPENDENTLY", "REFUSED", "NOT_APPLICABLE", "NO_GUIDANCE",
		"SELF_PRESERVATION_PRIORITY", "URGENT_HELP_PRIORITY", "RESOURCE_UNAVAILABLE", "HELP_UNAVAILABLE_BASELINE_PRIORITY",
		"BASELINE_ATTACK", "PLAYER_ABOVE_HELP_THRESHOLD", "NO_VALID_THREAT", "PROFILE_PREFERS_BASELINE",
		"TARGET_UNAVAILABLE", "BASELINE_TARGET", "PROFILE_PERMITTED_COOPERATION", "ACTOR_UNAVAILABLE",
		"NO_LIVING_ENEMY", "PLAYER_DEFEATED"]
	for key in required:
		_check(Messages.MESSAGES.has(key) and Messages.message(key) != key and Messages.message(key, "en") != key,
			"Thai/English message for every actual response reason " + key)
	_case("I30", "all response/reason codes from Layer mapped to Thai/English outside policy")
	_draft("FOCUS_TARGET", "enemy_b")
	scene.defend_button.pressed.emit()
	await _wait("npc_02", "WINDUP")
	var first: String = scene.autonomous_intents.npc_01.text
	_check(scene.autonomous_intents.npc_02.text.begins_with("NPC2") and first.begins_with("NPC1"), "per ID reasons")
	await _idle()
	_check(scene.autonomous_intents.npc_01.text == first and scene.autonomous_intents.npc_03.text.contains(Messages.message("REFUSED")), "later NPC rows do not overwrite earlier ones")
	_case("I31", "independent response rows survive later slots/effects")
	var legacy = Legacy.instantiate()
	root.add_child(legacy)
	await process_frame
	_check(legacy.encounter == null and legacy.guidance_picker == null and legacy.guidance_focus_picker == null
		and legacy.session_mode == 0 and legacy.turn_flow != null, "Legacy no Guided policy/UI")
	legacy.queue_free()
	_case("I32", "direct Legacy F6 has only Legacy authority and no Guidance controls")
	for command in ["ATTACK", "DEFEND"]:
		for index in [0, 1, 2, 3, 4, 5, 6, 7, 9]:
			_choose(index)
			var base = Base.new()
			var fixture: Dictionary = Base.prototype_fixture()
			for entry in fixture.actors:
				entry.initial_hp = scene.encounter.actor_snapshot(entry.definition.actor_id).current_hp
				entry.definition.display_name = scene.AUTONOMOUS_NAMES[entry.definition.actor_id]
			base.restart(fixture)
			_check(base.begin_round(command, "enemy_a" if command == "ATTACK" else "", scene.AUTONOMOUS_SCENARIOS[index].targets).status == "STARTED", "base round")
			(scene.attack_button if command == "ATTACK" else scene.defend_button).pressed.emit()
			await _idle()
			for event in events:
				var token: Dictionary = base.begin_next_action()
				_check(token.decision == event.token.decision, "NONE exact locked decision/reason/target")
				_check(base.resolve_action(token) == event.effect, "NONE actual effect exact")
				base.complete_action(token)
			var actual: Dictionary = scene.encounter.snapshot()
			var expected: Dictionary = base.snapshot()
			for view in [actual, expected]:
				view.erase("encounter_id")
				view.erase("generation") # Independent restart counts differ.
				view.locked_action.erase("encounter_id")
				view.locked_action.erase("generation")
				view.locked_action.erase("guidance_decision") # New metadata only, compared separately.
			_check(actual == expected, "NONE complete combat state equality")
	_case("I33", "18 paired real-Main NONE rounds vs unchanged unguided base: decisions/effects/HP/HELP/Guard/queue/revision/terminal equal; normalize independent identities and extension metadata only")
	_choose()
	_home()
	_check(scene.combat_speed_scale == 0.70 and scene.SHORT_LUNGE_DISTANCE == 44.0
		and scene.player_home == Vector2(570, 465) and scene.npc_home_positions == [Vector2(320, 480), Vector2(405, 435), Vector2(475, 509)]
		and scene.enemy_home == Vector2(970, 506) and scene.enemy_b_home == Vector2(1100, 424), "presentation baseline")
	_case("I34", "0.70 speed/44px lunge/Compact Formation/saved homes unchanged; real-Tween inherited matrix also runs")


func _run() -> void:
	scene = OptIn.instantiate()
	root.add_child(scene)
	await process_frame
	await _ui_contract()
	_revision_contract()
	await _policies()
	await _restart_and_effects()
	await _layout_and_equivalence()
	_check(coverage.size() == 34, "I01-I34 independent focused cases; I35/36 external regression gates")
	scene.queue_free()
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "focused_cases": coverage.size(),
				"coverage": coverage, "cases": cases,
				"external_gates": {"I35": "all inherited suites/counts + exact Legacy differential", "I36": "results.json unexpected errors/timeouts"}}, "\t"))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
