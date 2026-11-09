extends RefCounted

# Pure new-domain adapter; no old owner_kind, live Encounter, or writable state.
# O1/O2/O3 independent policy is retained; v1 delegation uses only true supported data.
const Contract = preload("res://scripts/m4/playable_contract.gd")
const Policy = preload("res://scripts/m4/m404_autonomous_decision_policy.gd")
const Layer = preload("res://scripts/npc/guidance_decision_layer.gd")

static func decision_identity(c: Dictionary) -> Dictionary:
	return {"session": c.identity.session, "generation": c.identity.generation,
		"round_id": c.identity.round_id, "snapshot_revision": c.identity.state_revision}

static func output(identity: Variant = null, code: String = "M404_INVALID_CONTEXT", status: String = "INVALID_INPUT") -> Dictionary:
	return Policy.output(identity, code, status)

static func choice(action: String, target: String, episode: Variant = null) -> Dictionary:
	return Policy.choice(action, target, episode)

static func less(a: Dictionary, b: Dictionary) -> bool:
	return Policy.less(a, b)

static func decide(c: Variant) -> Dictionary:
	if not Contract.valid("Observation", c): return output()
	var frozen: Variant = null
	var profile: Variant = null
	if c.guidance.active != null:
		frozen = {"record": c.guidance.active.duplicate(true), "identity": {
			"encounter_id": c.guidance.encounter_id, "generation": c.identity.generation,
			"round_id": c.identity.round_id, "guidance_revision": c.guidance.guidance_revision,
			"snapshot_revision": c.identity.state_revision}}
		for row in c.guidance.profiles:
			if row.actor_id == c.slot.actor_id: profile = row
	var actor_exists: bool = false
	for p in c.party:
		if not Contract.party_valid(p, c.identity.round_id): return output()
		if p.actor_id == c.slot.actor_id: actor_exists = p.role == "NPC" and p.eligible
	if not actor_exists: return output(null, "M404_NO_ELIGIBLE_SLOT", "NO_ACTION")
	var rows: Dictionary = {}
	var actor: Dictionary = {}
	var player: Dictionary = {}
	var enemy: String = ""
	for p in c.party:
		rows[p.actor_id] = p
		if p.actor_id == c.slot.actor_id: actor = p
		if p.actor_id == "player": player = p
	for e in c.enemies:
		rows[e.actor_id] = e
		if enemy.is_empty() and e.available: enemy = e.actor_id
	if enemy.is_empty(): return output(decision_identity(c), "M404_NO_ELIGIBLE_SLOT", "NO_ACTION")
	var incoming: int = 0
	for h in c.hits:
		if h.target_id == c.slot.actor_id and rows[h.actor_id].available:
			incoming = h.damage
			break
	var candidates: Array = []
	var exclusions: Array = []
	for index in range(c.party.size()):
		var p: Dictionary = c.party[index]
		if p.actor_id == c.slot.actor_id: continue
		if p.life != "DOWN" or p.participation != "PRESENT": continue
		if actor.rescue_uses == 0:
			exclusions.append({"action": "RESCUE", "target_id": p.actor_id, "code": "NO_RESCUE_USE"})
			continue
		candidates.append({"target_id": p.actor_id, "episode_id": p.episode.episode_id,
			"budget": p.episode.budget, "entry_order": p.episode.entry_order, "stable_party_index": index,
			"urgent": p.episode.budget == 1 and p.episode.entry_round < c.identity.round_id})
	candidates.sort_custom(less)
	var selected: Dictionary
	var code: String
	var refusal: String = "NONE"
	if incoming > 0 and (actor.hp * 100 <= actor.max_hp * 30 or incoming >= actor.hp):
		selected = choice("DEFEND", c.slot.actor_id)
		code = "SELF_LOW_HP_THREAT" if actor.hp * 100 <= actor.max_hp * 30 else "SELF_LETHAL_THREAT"
		if not candidates.is_empty() or (player.eligible and player.hp * 100 <= player.max_hp * 30 and actor.help_uses == 1):
			refusal = "HELPER_PRIORITY"
			if player.eligible and player.hp * 100 <= player.max_hp * 30 and actor.help_uses == 1:
				exclusions.append({"action": "HELP", "target_id": "player", "code": "HIGHER_PRIORITY"})
			for p in candidates: exclusions.append({"action": "RESCUE", "target_id": p.target_id, "code": "HIGHER_PRIORITY"})
	elif not candidates.is_empty() and candidates[0].urgent:
		selected = choice("RESCUE", candidates[0].target_id, candidates[0].episode_id)
		code = "M404_URGENT_RESCUE"
	elif player.eligible and player.hp * 100 <= player.max_hp * 30 and actor.help_uses == null:
		# No authoritative HELP ledger in C: unknown is never silently zero.
		var blocked: Dictionary = output(decision_identity(c), "M404_INVALID_CONTEXT", "DESIGN_BLOCKED")
		blocked.decision_reason.excluded = [{"action": "HELP", "target_id": "player", "code": "HELP_UNAVAILABLE"}]
		return blocked
	elif player.eligible and player.hp * 100 <= player.max_hp * 30 and actor.help_uses == 1:
		selected = choice("HELP", "player")
		code = "PLAYER_LOW_HP_HELP"
		if not candidates.is_empty():
			refusal = "HELPER_PRIORITY"
			for p in candidates: exclusions.append({"action": "RESCUE", "target_id": p.target_id, "code": "HIGHER_PRIORITY"})
	elif not candidates.is_empty():
		selected = choice("RESCUE", candidates[0].target_id, candidates[0].episode_id)
		code = "M404_NONURGENT_RESCUE"
	elif actor.hp * 100 <= actor.max_hp * 30:
		selected = choice("RETREAT", c.slot.actor_id)
		code = "M404_SELF_PRESERVATION_RETREAT"
	else:
		selected = choice("ATTACK", enemy)
		code = "HELP_UNAVAILABLE_ATTACK" if player.eligible and player.hp * 100 <= player.max_hp * 30 else "ATTACK_AVAILABLE_ENEMY"
	var result: Dictionary = output(decision_identity(c), code, "CANDIDATE_ONLY")
	result.baseline = selected.duplicate(true)
	result.selected = selected.duplicate(true)
	result.decision_reason.excluded = exclusions
	result.refusal_type = refusal
	result.legal_effect.required_transaction = selected.action
	if frozen == null: return result
	var kind: String = frozen.record.guidance_type
	if kind == "NONE": return result
	# Only build existing strict schemas on a truly supported v1 state.
	var supported: bool = c.party.size() <= 4 and c.enemies.size() <= 2 and c.hits.size() == c.enemies.size()
	for p in c.party:
		supported = supported and p.eligible and (p.role == "PLAYER" or p.help_uses != null)
	if selected.action == "ATTACK" and supported:
		var actors: Dictionary = {}
		var party_order: Array = []
		var enemy_order: Array = []
		var uses: Dictionary = {}
		for p in c.party:
			actors[p.actor_id] = {"actor_id": p.actor_id, "display_name": p.actor_id, "role": p.role,
				"base_max_hp": p.max_hp, "hp": p.hp, "max_hp": p.max_hp, "can_act": p.eligible, "membership": "PARTY"}
			if p.role == "NPC":
				party_order.append(p.actor_id)
				uses[p.actor_id] = p.help_uses
		for e in c.enemies:
			enemy_order.append(e.actor_id)
			actors[e.actor_id] = {"actor_id": e.actor_id, "display_name": e.actor_id, "role": "ENEMY",
				"base_max_hp": e.max_hp, "hp": e.hp, "max_hp": e.max_hp, "can_act": e.available, "membership": "ENEMY"}
		var reply: Dictionary = Layer.new().decide_with_guidance(c.slot.actor_id, {"schema_version": 1,
			"base_context": {"actors": actors, "player_id": "player", "party_order": party_order, "enemy_order": enemy_order,
				"help_uses": uses, "declared_hits": c.hits.duplicate(true), "snapshot_revision": c.identity.state_revision},
			"identity": frozen.identity.duplicate(true), "frozen_guidance": frozen.record.duplicate(true),
			"actor_profile": profile.duplicate(true), "capabilities": Layer.CAPABILITIES.duplicate()})
		if reply.status != "OK": return output(null)
		result.selected = choice(reply.decision.action, reply.decision.target_id)
		result.decision_reason.code = reply.decision.reason_code
		result.guidance_relation = {"response": reply.guidance_response.response, "reason": reply.guidance_response.reason_code,
			"behavior_changed": reply.guidance_response.details.behavior_changed}
		result.legal_effect.required_transaction = result.selected.action
	elif not supported:
		result.guidance_relation = {"response": "NOT_APPLICABLE", "reason": "M404_GUIDANCE_NOT_APPLICABLE", "behavior_changed": false}
	else:
		result.guidance_relation = {"response": "MATCHED_INDEPENDENTLY" if kind == selected.action else "REFUSED",
			"reason": "M404_SITUATION_PRIORITY", "behavior_changed": false}
	return result
