extends RefCounted

# Encounter owns actor state, M2C-03 turns and M3A-02 data-only Guidance.
const Registry = preload("res://scripts/actors/actor_registry.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const RuntimeState = preload("res://scripts/actors/actor_runtime_state.gd")
const Resolver = preload("res://scripts/npc/npc_decision_resolver.gd")
const GuidanceData = preload("res://scripts/npc/guidance_data_contract.gd")
# Owner-approved M2C-03 PROTOTYPE values, not final gameplay balance.
const PLAYER_DAMAGE: int = 5
const NPC_DAMAGE: int = 1
const ENEMY_DAMAGE: int = 3
const HELP_AMOUNT: int = 4
const DEFEND_REDUCTION: int = 2
var _registry = Registry.new()
var _resolver = Resolver.new()
var _encounter_id: int = get_instance_id()
var _round: int = 1
var _round_completions: int = 0
var _round_running: bool = false
var _revision: int = 0
var _next_action_id: int = 0
var _pending: Array = [] # Stable IDs, no HP or precomputed NPC decisions.
var _locked: Dictionary = {}
var _help_uses: Dictionary = {}
var _guards: Dictionary = {}
var _declared_hits: Array = []
var _player_command: Dictionary = {}
var _result: String = ""
var _player_id: String = ""
var _party_order: Array = [] # NPC companions only; Player has its own identity.
var _enemy_order: Array = []
var _generation: int = 0
var _command_ready: bool = true
var _active_action: bool = false
var _guidance_pending: Dictionary = {}
var _guidance_active: Dictionary = {}
var _guidance_revision: int = 0
var _guidance_profiles: Dictionary = {}


static func prototype_fixture(npc_count: int = 3, enemy_count: int = 2) -> Dictionary:
	if npc_count < 0 or npc_count > 3 or enemy_count < 1 or enemy_count > 2:
		return {}
	var specs: Array = [["player", "PLAYER", 30, 30]]
	var party: Array = []
	var enemies: Array = []
	for i in range(npc_count):
		var id: String = "npc_%02d" % (i + 1)
		party.append(id)
		specs.append([id, "NPC", 10, [10, 7, 3][i]])
	for i in range(enemy_count):
		var id: String = ["enemy_a", "enemy_b"][i]
		enemies.append(id)
		var hp: int = [15, 12][i]
		specs.append([id, "ENEMY", hp, hp])
	var actors: Array = []
	for spec in specs:
		actors.append({"definition": {"actor_id": spec[0], "display_name": spec[0],
			"role": spec[1], "base_max_hp": spec[2]}, "initial_hp": spec[3]})
	return {"actors": actors, "player_id": "player", "party_order": party, "enemy_order": enemies}


func _init() -> void:
	restart(prototype_fixture())


func _schema(value: Variant, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _valid_roster(registry, player: Variant, party: Variant, enemies: Variant) -> bool:
	if typeof(player) != TYPE_STRING or typeof(party) != TYPE_ARRAY or typeof(enemies) != TYPE_ARRAY:
		return false
	if party.size() > 3 or enemies.size() < 1 or enemies.size() > 2:
		return false
	var seen: Dictionary = {}
	for group in [[ [player], "PLAYER", "PARTY" ], [party, "NPC", "PARTY"], [enemies, "ENEMY", "ENEMY"]]:
		for id in group[0]:
			if typeof(id) != TYPE_STRING or seen.has(id):
				return false
			var actor: Dictionary = registry.actor_snapshot(id)
			if actor.is_empty() or actor.role != group[1] or actor.membership != group[2]:
				return false
			seen[id] = true
	return seen.size() == registry.snapshot().size()


func restart(fixture: Variant) -> bool:
	if not _schema(fixture, ["actors", "player_id", "party_order", "enemy_order"]) \
		or typeof(fixture.actors) != TYPE_ARRAY:
		return false
	var candidate = Registry.new()
	for entry in fixture.actors:
		if not _schema(entry, ["definition", "initial_hp"]):
			return false
		var definition = Definition.create(entry.definition)
		# Explicit initial HP is mandatory in this fixture schema (null is not a default).
		if definition == null or typeof(entry.initial_hp) != TYPE_INT:
			return false
		var runtime = RuntimeState.create(definition, entry.initial_hp)
		var membership: String = "ENEMY" if definition.snapshot().role == "ENEMY" else "PARTY"
		if not candidate.register_actor(definition, runtime, membership):
			return false
	if not _valid_roster(candidate, fixture.player_id, fixture.party_order, fixture.enemy_order):
		return false
	var profiles: Dictionary = {}
	for id in fixture.party_order:
		var profile: Dictionary = GuidanceData.fixed_profile(id, fixture.player_id)
		if profile.is_empty():
			return false
		profiles[id] = profile
	_registry = candidate
	_player_id = fixture.player_id
	_party_order = fixture.party_order.duplicate()
	_enemy_order = fixture.enemy_order.duplicate()
	_generation += 1
	_command_ready = true
	_active_action = false
	_round = 1
	_round_completions = 0
	_round_running = false
	_revision = 0
	_next_action_id = 0
	_pending.clear()
	_locked.clear()
	_guards.clear()
	_declared_hits.clear()
	_player_command.clear()
	_result = ""
	_help_uses.clear()
	for id in _party_order:
		_help_uses[id] = 1
	_guidance_profiles = profiles.duplicate(true)
	_guidance_revision = 0
	_guidance_pending = _guidance_record("NONE", "")
	_guidance_active.clear()
	_update_terminal()
	return true


func _can_mutate() -> bool:
	return _command_ready and not _active_action and not _round_running and _result.is_empty()


# M2C-02 fixture guard only; cannot override a real M2C-03 round or terminal lock.
func set_lifecycle(command_ready: Variant, active_action: Variant) -> bool:
	if _round_running or not _result.is_empty() or typeof(command_ready) != TYPE_BOOL or typeof(active_action) != TYPE_BOOL:
		return false
	_command_ready = command_ready
	_active_action = active_action
	return true


func register_actor(definition: Variant, runtime: Variant, membership: Variant) -> bool:
	if not _can_mutate() or not definition is Definition:
		return false
	var baseline: Dictionary = definition.snapshot()
	if Definition.create(baseline) == null:
		return false
	# No second Player; capacity checks precede registry mutation.
	if baseline.role == "PLAYER" or (baseline.role == "NPC" and _party_order.size() >= 3) \
		or (baseline.role == "ENEMY" and _enemy_order.size() >= 2):
		return false
	if not _registry.register_actor(definition, runtime, membership):
		return false
	if baseline.role == "NPC":
		_party_order.append(baseline.actor_id)
		_help_uses[baseline.actor_id] = 1
		_guidance_profiles[baseline.actor_id] = GuidanceData.fixed_profile(baseline.actor_id, _player_id)
	else:
		_enemy_order.append(baseline.actor_id)
	_revision += 1
	return true


func unregister_actor(id: Variant) -> bool:
	if not _can_mutate() or typeof(id) != TYPE_STRING or id == _player_id:
		return false
	if not _party_order.has(id) and (not _enemy_order.has(id) or _enemy_order.size() == 1):
		return false
	if not _registry.unregister_actor(id):
		return false
	_party_order.erase(id)
	_enemy_order.erase(id)
	_help_uses.erase(id)
	_guidance_profiles.erase(id)
	if _guidance_pending.get("preferred_target_id", "") == id:
		_guidance_pending = _guidance_record("NONE", "")
	_revision += 1
	return true


func reorder_party(order: Variant) -> bool:
	if not _can_mutate() or typeof(order) != TYPE_ARRAY or order.size() != _party_order.size():
		return false
	if not _valid_roster(_registry, _player_id, order, _enemy_order):
		return false
	_party_order = order.duplicate()
	_revision += 1
	return true


func actor_snapshot(id: Variant) -> Dictionary:
	return _registry.actor_snapshot(id)


func available_enemy_ids() -> Array:
	var ids: Array = []
	for id in _enemy_order:
		if _registry.actor_snapshot(id).can_act:
			ids.append(id)
	return ids


func snapshot() -> Dictionary:
	return {"actors": _registry.snapshot(), "player_id": _player_id,
		"party_order": _party_order.duplicate(), "enemy_order": _enemy_order.duplicate(),
		"generation": _generation, "command_ready": _command_ready, "active_action": _active_action,
		"available_enemy_ids": available_enemy_ids(), "encounter_id": _encounter_id,
		"round_id": _round, "round_completions": _round_completions, "round_running": _round_running,
		"snapshot_revision": _revision, "pending": _pending.duplicate(),
		"locked_action": _locked.duplicate(true), "help_uses": _help_uses.duplicate(),
		"guards": _guards.duplicate(), "result": _result, "declared_hits": _declared_hits.duplicate(true)}


# Separate accessor preserves every existing combat/Resolver snapshot field.
func guidance_snapshot() -> Dictionary:
	return {"schema_version": GuidanceData.SCHEMA_VERSION, "encounter_id": _encounter_id,
		"generation": _generation, "round_id": _round, "guidance_revision": _guidance_revision,
		"pending": _guidance_pending.duplicate(true), "active": _guidance_active.duplicate(true),
		"profiles": _guidance_profiles.duplicate(true)}


func _guidance_record(kind: String, preferred_target: String) -> Dictionary:
	return {"guidance_type": kind, "issuer_player_id": _player_id,
		"preferred_target_id": preferred_target, "encounter_id": _encounter_id,
		"generation": _generation, "round_id": _round, "guidance_revision": _guidance_revision}


func submit_guidance(request: Variant) -> Dictionary:
	if not _result.is_empty():
		return _reply("TERMINAL", _result)
	if not _can_mutate():
		return _reply("REJECTED", "COMMAND_LOCKED")
	var invalid: String = GuidanceData.validate_request(request)
	if not invalid.is_empty():
		return _reply("REJECTED", invalid)
	for spec in [["encounter_id", _encounter_id, "FOREIGN_ENCOUNTER"],
		["generation", _generation, "STALE_GENERATION"], ["round_id", _round, "WRONG_ROUND"],
		["issuer_player_id", _player_id, "INVALID_ISSUER"],
		["expected_guidance_revision", _guidance_revision, "STALE_GUIDANCE_REVISION"]]:
		if request[spec[0]] != spec[1]:
			return _reply("REJECTED", spec[2])
	# Membership only: a known HP0 enemy remains a valid preference, not an effect.
	if request.guidance_type == "FOCUS_TARGET" and not _enemy_order.has(request.preferred_target_id):
		return _reply("REJECTED", "UNKNOWN_GUIDANCE_TARGET")
	# No combat revision/HP/queue/token/resource changes. All validation precedes writes.
	_guidance_revision += 1
	_guidance_pending = _guidance_record(request.guidance_type, request.preferred_target_id)
	return _reply("ACCEPTED")


# Generation is required so an old proof callback cannot mutate a new session.
func fixture_damage(id: Variant, amount: Variant, generation: Variant) -> Dictionary:
	if not _can_mutate() or typeof(generation) != TYPE_INT or generation != _generation:
		return {"status": "REJECTED", "hp_delta": 0}
	var effect: Dictionary = _registry.fixture_damage(id, amount)
	if effect.status == "APPLIED":
		_revision += 1
	return effect


func fixture_heal(id: Variant, amount: Variant, generation: Variant) -> Dictionary:
	if not _can_mutate() or typeof(generation) != TYPE_INT or generation != _generation:
		return {"status": "REJECTED", "hp_delta": 0}
	var effect: Dictionary = _registry.fixture_heal(id, amount)
	if effect.status == "APPLIED":
		_revision += 1
	return effect


# Enemy declarations are locked for the whole round; {} defaults each hit to Player.
# Player attack accepts a known enemy even if unavailable: fallback happens before lock.
func begin_round(action: Variant, target_id: Variant = "", enemy_targets: Variant = {}) -> Dictionary:
	if not _result.is_empty():
		return _reply("TERMINAL", _result)
	if not _can_mutate():
		return _reply("REJECTED", "COMMAND_LOCKED")
	if typeof(action) != TYPE_STRING or action not in ["ATTACK", "DEFEND"] \
		or typeof(target_id) != TYPE_STRING or typeof(enemy_targets) != TYPE_DICTIONARY:
		return _reply("REJECTED", "INVALID_PLAYER_ACTION")
	if (action == "ATTACK" and target_id != "" and not _enemy_order.has(target_id)) \
		or (action == "DEFEND" and target_id not in ["", _player_id]):
		return _reply("REJECTED", "INVALID_PLAYER_TARGET")
	for id in enemy_targets:
		if typeof(id) != TYPE_STRING or not _enemy_order.has(id) \
			or typeof(enemy_targets[id]) != TYPE_STRING \
			or not ([_player_id] + _party_order).has(enemy_targets[id]):
			return _reply("REJECTED", "INVALID_ENEMY_TARGET")
	_update_terminal()
	if not _result.is_empty():
		return _reply("TERMINAL", _result)
	_declared_hits.clear()
	for id in _enemy_order:
		_declared_hits.append({"actor_id": id, "target_id": enemy_targets.get(id, _player_id),
			"damage": ENEMY_DAMAGE})
	_player_command = {"action": action, "target_id": target_id}
	_pending = [_player_id] + _party_order + _enemy_order
	_locked.clear()
	_round_running = true
	_command_ready = false
	_guidance_active = _guidance_pending.duplicate(true)
	_guidance_pending.clear()
	_revision += 1
	return _reply("STARTED")


func decision_context() -> Dictionary:
	return {"actors": _registry.snapshot(), "player_id": _player_id,
		"party_order": _party_order.duplicate(), "enemy_order": _enemy_order.duplicate(),
		"help_uses": _help_uses.duplicate(), "declared_hits": _declared_hits.duplicate(true),
		"snapshot_revision": _revision}


func begin_next_action() -> Dictionary:
	if not _round_running or _active_action:
		return _reply("REJECTED", "NO_PENDING_SLOT" if not _round_running else "ACTION_IN_PROGRESS")
	_update_terminal()
	if not _result.is_empty():
		_stop_round()
		return _reply("TERMINAL", _result)
	if _pending.is_empty():
		_finish_round()
		return _reply("COMPLETED", "ROUND_COMPLETE")
	var id: String = _pending.pop_front()
	var actor: Dictionary = actor_snapshot(id)
	var decision: Dictionary
	if not actor.can_act:
		decision = _make_decision(id, "SKIP", "", "ACTOR_UNAVAILABLE")
	elif id == _player_id:
		var target: String = _player_id
		if _player_command.action == "ATTACK":
			target = _player_command.target_id
			if not available_enemy_ids().has(target):
				target = available_enemy_ids()[0]
		decision = _make_decision(id, _player_command.action, target, "PLAYER_COMMAND")
	elif _party_order.has(id):
		decision = _resolver.decide_for_actor(id, decision_context())
	else:
		var target: String = ""
		for hit in _declared_hits:
			if hit.actor_id == id:
				target = hit.target_id
		decision = _make_decision(id, "ATTACK", target, "ENEMY_DECLARED_TARGET")
	_next_action_id += 1
	_locked = {"encounter_id": _encounter_id, "generation": _generation, "round_id": _round,
		"action_id": _next_action_id, "actor_id": id, "state": "LOCKED",
		"decision": decision.duplicate(true)}
	_active_action = true
	return _locked.duplicate(true)


func _make_decision(id: String, action: String, target: String, reason: String) -> Dictionary:
	return {"actor_id": id, "status": "SKIP" if action == "SKIP" else "DECIDED",
		"action": action, "target_id": target, "reason_code": reason,
		"reason_details": {}, "snapshot_revision": _revision}


func _valid_token(token: Variant) -> bool:
	if typeof(token) != TYPE_DICTIONARY or not _active_action or _locked.is_empty():
		return false
	for key in ["encounter_id", "generation", "round_id", "action_id", "actor_id"]:
		if not token.has(key) or typeof(token[key]) != typeof(_locked[key]) or token[key] != _locked[key]:
			return false
	return true


func resolve_action(token: Variant) -> Dictionary:
	if not _valid_token(token) or _locked.state != "LOCKED":
		return _reply("REJECTED", "INVALID_TOKEN_OR_STATE")
	var decision: Dictionary = _locked.decision
	var id: String = _locked.actor_id
	var target: Dictionary = actor_snapshot(decision.target_id)
	_update_terminal()
	var skipped: String = ""
	if not _result.is_empty():
		skipped = _result
	elif not actor_snapshot(id).can_act:
		skipped = "ACTOR_UNAVAILABLE"
	elif decision.action == "SKIP":
		skipped = decision.reason_code
	elif target.is_empty() or not target.can_act:
		skipped = "TARGET_DEAD_BEFORE_RESOLVE"
	elif decision.action == "HELP" and (_help_uses.get(id, 0) == 0 or target.current_hp == target.max_hp):
		skipped = "HELP_UNAVAILABLE"
	var effect: Dictionary = {"status": "SKIP", "reason_code": skipped, "hp_delta": 0}
	if skipped.is_empty():
		match decision.action:
			"ATTACK":
				var damage: int = PLAYER_DAMAGE if id == _player_id else NPC_DAMAGE
				if _enemy_order.has(id):
					damage = ENEMY_DAMAGE
					if _guards.has(decision.target_id):
						damage = maxi(1, damage - DEFEND_REDUCTION)
						# Player DEFEND covers every enemy hit this round; NPC covers next hit only.
						if decision.target_id != _player_id:
							_guards.erase(decision.target_id)
				effect = _registry.fixture_damage(decision.target_id, damage)
			"HELP":
				effect = _registry.fixture_heal(decision.target_id, HELP_AMOUNT)
				if effect.hp_delta > 0:
					_help_uses[id] -= 1
			"DEFEND":
				_guards[id] = true
				effect = {"status": "APPLIED", "hp_delta": 0}
	_locked.state = "SKIPPED" if effect.status == "SKIP" else "RESOLVED"
	_locked["effect"] = effect.duplicate(true)
	_revision += 1
	_update_terminal()
	return effect.duplicate(true)


func complete_action(token: Variant) -> Dictionary:
	if not _valid_token(token) or _locked.state not in ["RESOLVED", "SKIPPED"]:
		return _reply("REJECTED", "INVALID_TOKEN_OR_STATE")
	_locked.state = "COMPLETED"
	_active_action = false
	_update_terminal()
	if not _result.is_empty():
		_stop_round()
	elif _pending.is_empty():
		_finish_round()
	return _reply("COMPLETED")


func _update_terminal() -> void:
	if not actor_snapshot(_player_id).can_act:
		_result = "DEFEAT"
	elif available_enemy_ids().is_empty():
		_result = "VICTORY"
	if not _result.is_empty():
		_pending.clear()
		_command_ready = false
		_guidance_pending.clear()
		_guidance_active.clear()


func _stop_round() -> void:
	_pending.clear()
	_guards.clear()
	_round_running = false
	_command_ready = false


func _finish_round() -> void:
	if not _round_running:
		return
	_round_completions += 1
	_round += 1
	_guards.clear()
	_round_running = false
	_command_ready = true
	_guidance_active.clear()
	_guidance_pending = _guidance_record("NONE", "")


func _reply(status: String, reason: String = "") -> Dictionary:
	return {"status": status, "reason_code": reason}
