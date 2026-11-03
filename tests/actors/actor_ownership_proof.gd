extends SceneTree

const Encounter = preload("res://scripts/npc/npc_proof_encounter.gd")
const Definition = preload("res://scripts/actors/actor_definition.gd")
const RuntimeState = preload("res://scripts/actors/actor_runtime_state.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _case(id: String, before: int) -> void:
	print("CASE %s: %s" % [id, "PASS" if before == failures else "FAIL"])


func _bounds(encounter) -> void:
	var view: Dictionary = encounter.inspect().state
	for spec in Encounter.ACTORS:
		var actor: Dictionary = encounter._actors[spec[1]].snapshot()
		_check(actor.current_hp >= 0 and actor.current_hp <= actor.max_hp, "runtime HP in bounds")
		_check(view[spec[0] + "_hp"] == actor.current_hp
			and view[spec[0] + "_max_hp"] == actor.max_hp, "compatibility reads runtime")
		_check(not encounter._state.has(spec[0] + "_hp")
			and not encounter._state.has(spec[0] + "_max_hp"), "metadata contains no duplicate HP")


func _registry_and_snapshots() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	_check(encounter._actors.size() == 3, "exactly three runtime actors")
	for spec in Encounter.ACTORS:
		var actor = encounter._actors[spec[1]]
		_check(actor is RuntimeState and actor.snapshot().actor_id == spec[1], "correct runtime type/ID")
		var definition = Definition.create({"actor_id": spec[1], "display_name": spec[1],
			"role": spec[2], "base_max_hp": actor.snapshot().max_hp})
		_check(definition.snapshot().role == spec[2], "correct definition role")
		var registry: Dictionary = {}
		_check(encounter._register_actor(registry, definition, 1), "register valid actor")
		var first = registry[spec[1]]
		_check(not encounter._register_actor(registry, definition, 0), "duplicate ID rejected")
		_check(registry.size() == 1 and registry[spec[1]] == first
			and first.snapshot().current_hp == 1, "duplicate never overwrites existing actor")
		_check(not encounter._register_actor(registry, Definition.new(), 1), "invalid definition rejected")
		_check(not encounter._register_actor(registry, definition, -1), "invalid state rejected")
	var original: Dictionary = encounter.inspect()
	var view: Dictionary = encounter.inspect()
	view.state.player_hp = 0
	view.state.npc_max_hp = 999
	view.state.enemy_hp = 0
	view.pending.append("intruder")
	var situation: Dictionary = encounter.situation_snapshot()
	situation.player_hp = 0
	situation.npc_hp = 0
	situation.living_enemy_ids.clear()
	_check(encounter.inspect() == original, "inspect and situation are detached")
	# White-box probe proves that adapters read the actual object, not a cached HP copy.
	encounter._actors.player.take_damage(2)
	_check(encounter.inspect().state.player_hp == 18
		and encounter.situation_snapshot().player_hp == 18, "both adapters read authoritative HP")
	_check(encounter.inspect().state.npc_hp == 10 and encounter.inspect().state.enemy_hp == 10,
		"player mutation independent of NPC/enemy")
	encounter._actors.enemy_a.take_damage(100)
	_check(encounter.situation_snapshot().living_enemy_ids.is_empty(), "living IDs derived from runtime")
	_bounds(encounter)
	_case("registry-snapshot-ownership", before)


func _effects_and_duplicates() -> void:
	var before: int = failures
	for settings in [{}, {"player_hp": 6}, {"npc_hp": 3, "incoming_target_id": "npc"}]:
		var encounter = Encounter.new()
		encounter.restart(settings)
		var token: Dictionary = encounter.begin_npc_slot()
		var action: String = token.decision.action
		var effect: Dictionary = encounter.resolve_npc(token)
		var impact: Dictionary = encounter.inspect()
		_check(effect.status == "APPLIED", "effect applied")
		if action == "ATTACK":
			_check(effect.hp_delta == -1 and impact.state.enemy_hp == 9
				and impact.state.player_hp == 20 and impact.state.npc_hp == 10, "ATTACK only enemy")
		elif action == "HELP":
			_check(effect.hp_delta == 4 and effect.help_use_delta == -1
				and impact.state.player_hp == 10 and impact.state.help_uses_remaining == 0
				and impact.state.npc_hp == 10 and impact.state.enemy_hp == 10, "HELP only Player and resource")
		else:
			_check(impact.self_defend and impact.state.npc_hp == 3, "DEFEND records guard before response")
		_check(encounter.resolve_npc(token).reason_code == "ACTION_ALREADY_RESOLVED", "duplicate effect rejected")
		_check(encounter.inspect() == impact, "duplicate effect changes nothing")
		_bounds(encounter)
		encounter.complete_npc(token)
		var complete: Dictionary = encounter.inspect()
		_check(complete.state.player_hp == (7 if action == "HELP" else 20 if action == "DEFEND" else 17),
			"enemy damages declared Player only")
		_check(complete.state.npc_hp == (2 if action == "DEFEND" else 10), "guarded NPC takes minimum one")
		_check(not complete.self_defend and complete.pending.is_empty()
			and complete.round_completions == 1, "guard expires and round finishes once")
		_check(encounter.complete_npc(token).reason_code == "ACTION_ALREADY_COMPLETED", "duplicate completion rejected")
		_check(encounter.inspect() == complete, "duplicate completion changes nothing")
		_bounds(encounter)
	var encounter = Encounter.new()
	encounter.restart({"incoming_target_id": "npc"})
	var token: Dictionary = encounter.begin_npc_slot()
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().state.npc_hp == 7 and encounter.inspect().state.player_hp == 20,
		"unguarded NPC enemy response")
	encounter.restart({"player_hp": 1, "player_max_hp": 4, "incoming_damage": 0})
	token = encounter.begin_npc_slot()
	_check(encounter.resolve_npc(token).hp_delta == 3, "HELP caps at runtime max")
	_bounds(encounter)
	encounter.restart({"player_hp": 2, "help_enabled": false, "incoming_damage": 1000})
	token = encounter.begin_npc_slot()
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().result == "DEFEAT", "lethal enemy response defeat")
	_bounds(encounter)
	_case("effects-duplicates-bounds", before)


func _atomic_mutation_and_restart() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	encounter.restart({"player_hp": 6})
	var token: Dictionary = encounter.begin_npc_slot()
	var initial: Dictionary = encounter.inspect()
	var actors: Dictionary = encounter._actors.duplicate()
	for invalid in [{"player_hp": 7, "enemy_hp": -1}, {"player_hp": 7, "npc_hp": 11},
		{"npc_hp": 2, "help_enabled": 1}, {"enemy_hp": 2, "help_uses_remaining": 2},
		{"player_hp": 1.0}, {"npc_hp": true}, {"enemy_hp": "1"}, {"player_hp": null},
		{"enemy_max_hp": 99}, {"unknown": 1}]:
		_check(encounter.apply_fixture_change(invalid).status == "INVALID_INPUT", "invalid fixture rejected")
		_check(encounter.inspect() == initial and encounter._actors == actors, "fixture rejection atomic including objects")
	for invalid in [{"player_hp": 7, "enemy_hp": -1}, {"npc_hp": 3, "npc_max_hp": 0},
		{"player_hp": 31}, {"player_max_hp": false}, {"enemy_max_hp": 0},
		{"incoming_target_id": "unknown"}, {"guidance": "HELP"}, {"extra": 1}]:
		_check(encounter.restart(invalid).status == "INVALID_INPUT", "invalid restart rejected")
		_check(encounter.inspect() == initial and encounter._actors == actors, "restart rejection atomic including generation/queue")
	_check(encounter.apply_fixture_change({"player_hp": 1, "npc_hp": 2, "enemy_hp": 3}).status == "CHANGED",
		"valid multi-HP fixture accepted")
	_check(encounter.inspect().generation == initial.generation and encounter.inspect().active == initial.active,
		"fixture preserves generation and locked action")
	_check(encounter.inspect().state.player_hp == 1 and encounter.inspect().state.npc_hp == 2
		and encounter.inspect().state.enemy_hp == 3, "fixture commits all runtime values")
	_bounds(encounter)
	encounter.resolve_npc(token)
	_check(encounter.inspect().state.player_hp == 5, "locked HELP uses replacement runtime")
	var old_actors: Dictionary = encounter._actors.duplicate()
	_check(encounter.restart().status == "RESTARTED", "restart accepted")
	var fresh: Dictionary = encounter.inspect()
	_check(fresh.generation == initial.generation + 1 and fresh.round == 1
		and fresh.round_completions == 0 and fresh.pending.is_empty() and fresh.active.is_empty()
		and not fresh.self_defend and fresh.result == "", "restart clears lifecycle atomically")
	_check(fresh.state.player_hp == 20 and fresh.state.npc_hp == 10
		and fresh.state.enemy_hp == 10 and fresh.state.help_uses_remaining == 1, "restart restores defaults")
	for id in old_actors:
		_check(encounter._actors[id] != old_actors[id], "restart creates fresh object " + id)
		old_actors[id].take_damage(999)
	_check(encounter.inspect() == fresh, "old objects cannot leak HP into restarted encounter")
	var current: Dictionary = encounter.begin_npc_slot()
	fresh = encounter.inspect()
	_check(encounter.resolve_npc(token).reason_code == "STALE_BATTLE_GENERATION", "old effect rejected")
	_check(encounter.complete_npc(token).reason_code == "STALE_BATTLE_GENERATION", "old completion rejected")
	_check(encounter.inspect() == fresh, "stale callbacks preserve new HP/resource/queue")
	encounter.resolve_npc(current)
	encounter.complete_npc(current)
	_bounds(encounter)
	_case("atomic-fixture-restart-stale", before)


func _terminal_races() -> void:
	var before: int = failures
	var encounter = Encounter.new()
	var token: Dictionary = encounter.begin_npc_slot()
	encounter.apply_fixture_change({"enemy_hp": 0})
	_check(encounter.resolve_npc(token).reason_code == "TARGET_DEAD_BEFORE_RESOLVE", "dead target skips")
	encounter.complete_npc(token)
	_check(encounter.inspect().result == "VICTORY" and encounter.inspect().state.player_hp == 20
		and encounter.inspect().pending.is_empty(), "dead enemy cannot counter; queue drains")
	encounter.restart({"enemy_hp": 1})
	token = encounter.begin_npc_slot()
	encounter.resolve_npc(token)
	encounter.complete_npc(token)
	_check(encounter.inspect().result == "VICTORY" and encounter.inspect().state.player_hp == 20, "killing blow victory")
	encounter.restart({"player_hp": 6})
	token = encounter.begin_npc_slot()
	encounter.apply_fixture_change({"player_hp": 0})
	_check(encounter.resolve_npc(token).status == "SKIP", "HELP cannot revive defeated Player")
	encounter.complete_npc(token)
	_check(encounter.inspect().result == "DEFEAT" and encounter.inspect().state.player_hp == 0
		and encounter.inspect().state.help_uses_remaining == 1, "failed HELP consumes no resource")
	_bounds(encounter)
	_case("terminal-races-no-revival", before)


func _run() -> void:
	_registry_and_snapshots()
	_effects_and_duplicates()
	_atomic_mutation_and_restart()
	_terminal_races()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
