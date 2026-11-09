extends "res://scripts/m4/m403_terminal_encounter.gd"

# Opt-in extension of the same C owner, not a wrapper or second Encounter.
const OrderProjection = preload("res://scripts/m4/m404_episode_order_projection.gd")
const Context = preload("res://scripts/m4/m404_decision_context.gd")
const Policy = preload("res://scripts/m4/m404_autonomous_decision_policy.gd")

func decision_context() -> Dictionary:
	var v: Dictionary = snapshot()
	if v.generation < 1 or not v.get("admitted", false) or v.phase != "OPEN" or not v.outcome.is_empty() \
		or v.queue.phase != "READY" or v.active_operation != null: return {}
	var slot: Dictionary = Rules.opportunity(v)
	if slot.is_empty() or slot.actor_id not in v.initial_party or v.actors[slot.actor_id].definition.role != "NPC" \
		or not v.actors[slot.actor_id].state.eligible: return {}
	var projection: Dictionary = OrderProjection.project(v)
	if projection.is_empty(): return {}
	var party: Array = []
	var enemies: Array = []
	var hits: Array = []
	var player_id: String = ""
	for id in v.initial_party:
		var p: Dictionary = v.actors[id].state
		var episode: Variant = null
		if v.clocks.has(id):
			episode = v.clocks[id].duplicate(true)
			episode.entry_order = projection.episodes[id].entry_order
		party.append({"actor_id": id, "role": p.role, "current_hp": p.current_hp, "max_hp": p.max_hp,
			"life_state": p.life_state, "participation": p.participation, "eligible": p.eligible,
			"help_uses": null, "rescue_uses": v.rescue_uses[id], "episode": episode})
		if p.role == "PLAYER": player_id = id
	for id in v.initial_enemies:
		var p: Dictionary = v.actors[id].state
		enemies.append({"actor_id": id, "current_hp": p.current_hp, "max_hp": p.max_hp, "available": p.can_act})
		if v.declarations.has(id): hits.append({"actor_id": id, "target_id": v.declarations[id], "damage": 3})
	var c: Dictionary = {"schema_version": 1,
		"identity": {"session": v.session, "generation": v.generation, "round_id": v.round_id, "snapshot_revision": v.revision},
		"source": {"adapter_version": 1, "owner_kind": "M403_ISOLATED", "owner_revision": v.revision,
			"observation_id": "m404/%s/%s/%s" % [v.session, v.generation, v.revision]},
		"actor_id": slot.actor_id, "player_id": player_id, "party": party, "enemies": enemies,
		"queue": {"queue_id": v.queue.queue_id, "slot_id": slot.slot_id, "opportunity_id": slot.opportunity_id,
			"slot_actor_id": slot.actor_id, "cursor": v.queue.cursor, "round_phase": v.phase, "queue_phase": v.queue.phase},
		"declared_hits": hits, "frozen_guidance": null, "profile": null, "boundary": "RUNNING_SLOT"}
	return c if Context.validate(c).is_empty() else {}

func decide_current(input: Variant) -> Dictionary:
	if not Context.validate(input).is_empty(): return Policy.output()
	var owned: Dictionary = decision_context()
	if owned.is_empty() or input != owned: return Policy.output()
	return Policy.decide(owned)

func lock_decision(input: Variant, request_id: Variant, capability: Variant) -> Dictionary:
	if typeof(request_id) != TYPE_STRING or request_id.is_empty(): return _reply("M404_INVALID_CONTEXT")
	var decision: Dictionary = decide_current(input)
	if decision.legal_effect.status != "CANDIDATE_ONLY": return _reply(decision.decision_reason.code)
	var action: String = decision.selected.action
	if action not in ["ATTACK", "RESCUE", "RETREAT"]: return _reply("M404_EFFECT_BRIDGE_BLOCKED")
	var c: Dictionary = input
	var request: Dictionary = {"version": 1, "session": c.identity.session, "generation": c.identity.generation,
		"expected_revision": c.identity.snapshot_revision, "queue_id": c.queue.queue_id, "slot_id": c.queue.slot_id,
		"request_id": request_id, "actor_id": c.actor_id, "kind": action}
	if action == "RETREAT": return lock_self_retreat(request, capability)
	request.target_id = decision.selected.target_id
	if action == "RESCUE": return lock_fixture_rescue(request, capability)
	# Existing NPC damage5; supported fixtures must accept this exact amount.
	# Do not invent an amount for a fixture unable to support the accepted damage.
	var target: Dictionary = actor_snapshot(request.target_id)
	if target.state.max_hp < 5: return _reply("M404_EFFECT_BRIDGE_BLOCKED")
	request.amount = 5
	return lock_fixture_attack(request, capability)
