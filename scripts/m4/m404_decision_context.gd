extends RefCounted

const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const TOP = ["schema_version", "identity", "source", "actor_id", "player_id", "party", "enemies", "queue", "declared_hits", "frozen_guidance", "profile", "boundary"]
const IDENTITY = ["session", "generation", "round_id", "snapshot_revision"]
const SOURCE = ["adapter_version", "owner_kind", "owner_revision", "observation_id"]
const PARTY = ["actor_id", "role", "current_hp", "max_hp", "life_state", "participation", "eligible", "help_uses", "rescue_uses", "episode"]
const EPISODE = ["episode_id", "entry_round", "budget", "active", "entry_order"]
const ENEMY = ["actor_id", "current_hp", "max_hp", "available"]
const QUEUE = ["queue_id", "slot_id", "opportunity_id", "slot_actor_id", "cursor", "round_phase", "queue_phase"]
const GI = ["encounter_id", "generation", "round_id", "guidance_revision", "snapshot_revision"]
const FROZEN = ["guidance_type", "issuer_player_id", "preferred_target_id", "encounter_id", "generation", "round_id", "guidance_revision"]

static func exact(value: Variant, fields: Array) -> bool:
	return Data._fields(value, fields)

static func integers(v: Dictionary, fields: Array) -> bool:
	for f in fields:
		if typeof(v[f]) != TYPE_INT: return false
	return true

static func strings(v: Dictionary, fields: Array) -> bool:
	for f in fields:
		if typeof(v[f]) != TYPE_STRING or v[f].is_empty(): return false
	return true

static func validate(c: Variant) -> String:
	if not exact(c, TOP): return "M404_INVALID_CONTEXT"
	if typeof(c.schema_version) != TYPE_INT or c.schema_version != 1: return "M404_INVALID_CONTEXT"
	if not exact(c.identity, IDENTITY) or not integers(c.identity, IDENTITY): return "M404_INVALID_CONTEXT"
	var i: Dictionary = c.identity
	if i.session == 0 or i.generation < 1 or i.round_id < 1 or i.snapshot_revision < 0: return "M404_INVALID_CONTEXT"
	if not exact(c.source, SOURCE) or not integers(c.source, ["adapter_version", "owner_revision"]) \
		or not strings(c.source, ["owner_kind", "observation_id"]): return "M404_INVALID_CONTEXT"
	if c.source.adapter_version != 1 or c.source.owner_kind != "M403_ISOLATED" or c.source.owner_revision != i.snapshot_revision: return "M404_INVALID_CONTEXT"
	if not strings(c, ["actor_id", "player_id", "boundary"]) or c.boundary not in ["RUNNING_SLOT", "ISOLATED_EXCEPTION"]: return "M404_INVALID_CONTEXT"
	for f in ["party", "enemies", "declared_hits"]:
		if typeof(c[f]) != TYPE_ARRAY: return "M404_INVALID_CONTEXT"
	if c.party.is_empty() or c.enemies.is_empty(): return "M404_INVALID_CONTEXT"
	var seen: Dictionary = {}
	var orders: Dictionary = {}
	var episodes: Dictionary = {}
	var player_count: int = 0
	var actor_ok: bool = false
	for p in c.party:
		if not exact(p, PARTY) or not strings(p, ["actor_id", "role", "life_state", "participation"]) \
			or not integers(p, ["current_hp", "max_hp", "rescue_uses"]): return "M404_INVALID_CONTEXT"
		if seen.has(p.actor_id) or p.role not in ["PLAYER", "NPC"] or p.life_state not in ["ALIVE", "DOWN", "DEAD"] \
			or p.participation not in ["PRESENT", "RETREATED"] or typeof(p.eligible) != TYPE_BOOL: return "M404_INVALID_CONTEXT"
		if p.max_hp < 1 or p.current_hp < 0 or p.current_hp > p.max_hp or (p.current_hp > 0) != (p.life_state == "ALIVE") \
			or (p.participation == "RETREATED" and p.life_state != "ALIVE") \
			or p.eligible != (p.life_state == "ALIVE" and p.participation == "PRESENT") or p.rescue_uses not in [0, 1]: return "M404_INVALID_CONTEXT"
		if p.help_uses != null and (typeof(p.help_uses) != TYPE_INT or p.help_uses not in [0, 1]): return "M404_INVALID_CONTEXT"
		if p.role == "PLAYER":
			player_count += 1
			if p.actor_id != c.player_id or p.help_uses != null: return "M404_INVALID_CONTEXT"
		if p.actor_id == c.actor_id: actor_ok = p.role == "NPC" and p.eligible
		seen[p.actor_id] = "PARTY"
		if p.episode == null:
			if p.life_state != "ALIVE": return "M404_INVALID_CONTEXT"
		else:
			var e: Variant = p.episode
			if not exact(e, EPISODE) or not strings(e, ["episode_id"]) or not integers(e, ["entry_round", "budget", "entry_order"]) \
				or typeof(e.active) != TYPE_BOOL: return "M404_INVALID_CONTEXT"
			if e.entry_round < 1 or e.entry_round > i.round_id or e.budget not in [0, 1, 2] or e.entry_order < 1 \
				or orders.has(e.entry_order) or episodes.has(e.episode_id): return "M404_INVALID_CONTEXT"
			if p.life_state == "DOWN":
				if not e.active or e.budget == 0 or (e.entry_round == i.round_id and e.budget != 2): return "M404_INVALID_CONTEXT"
			elif e.active or (p.life_state == "DEAD" and e.budget != 0) or (p.life_state == "ALIVE" and e.budget == 0): return "M404_INVALID_CONTEXT"
			orders[e.entry_order] = true
			episodes[e.episode_id] = true
	if player_count != 1 or not actor_ok: return "M404_NO_ELIGIBLE_SLOT"
	var enemy_ids: Array = []
	for e in c.enemies:
		if not exact(e, ENEMY) or not strings(e, ["actor_id"]) or not integers(e, ["current_hp", "max_hp"]) \
			or typeof(e.available) != TYPE_BOOL: return "M404_INVALID_CONTEXT"
		if seen.has(e.actor_id) or e.max_hp < 1 or e.current_hp < 0 or e.current_hp > e.max_hp or e.available != (e.current_hp > 0): return "M404_INVALID_CONTEXT"
		seen[e.actor_id] = "ENEMY"
		enemy_ids.append(e.actor_id)
	if not exact(c.queue, QUEUE) or not strings(c.queue, ["queue_id", "slot_id", "opportunity_id", "slot_actor_id", "round_phase", "queue_phase"]) \
		or not integers(c.queue, ["cursor"]) or c.queue.cursor < 0 or c.queue.cursor >= c.party.size() \
		or c.queue.slot_actor_id != c.actor_id or c.party[c.queue.cursor].actor_id != c.actor_id \
		or c.queue.round_phase not in ["UNINITIALIZED", "OPEN", "SEALED", "CLOSED", "ABORTED"] \
		or c.queue.queue_phase not in ["READY", "WAIT_ACTION", "DRAINED"]: return "M404_INVALID_CONTEXT"
	var hit_ids: Array = []
	for h in c.declared_hits:
		if not exact(h, ["actor_id", "target_id", "damage"]) or not strings(h, ["actor_id", "target_id"]) \
			or not integers(h, ["damage"]) or h.damage != 3: return "M404_INVALID_CONTEXT"
		if seen.get(h.actor_id) != "ENEMY" or seen.get(h.target_id) != "PARTY" or hit_ids.has(h.actor_id): return "M404_INVALID_CONTEXT"
		hit_ids.append(h.actor_id)
	var ordered: Array = []
	for id in enemy_ids:
		if hit_ids.has(id): ordered.append(id)
	if ordered != hit_ids: return "M404_INVALID_CONTEXT"
	if (c.frozen_guidance == null) != (c.profile == null): return "M404_INVALID_CONTEXT"
	if c.frozen_guidance != null:
		var b: Variant = c.frozen_guidance
		if not exact(b, ["identity", "record"]) or not exact(b.identity, GI) or not integers(b.identity, GI) \
			or not exact(b.record, FROZEN): return "M404_INVALID_CONTEXT"
		if b.identity.encounter_id == 0 or b.identity.generation != i.generation or b.identity.round_id != i.round_id \
			or b.identity.snapshot_revision != i.snapshot_revision or b.identity.guidance_revision < 0: return "M404_INVALID_CONTEXT"
		var r: Dictionary = b.record.duplicate(true)
		r.schema_version = 1
		r.expected_guidance_revision = r.guidance_revision
		r.erase("guidance_revision")
		if not Data.validate_request(r).is_empty() or not Data.validate_profile(c.profile).is_empty(): return "M404_INVALID_CONTEXT"
		for f in ["encounter_id", "generation", "round_id", "guidance_revision"]:
			if b.record[f] != b.identity[f]: return "M404_INVALID_CONTEXT"
		if b.record.issuer_player_id != c.player_id or c.profile.actor_id != c.actor_id or c.profile.player_id != c.player_id: return "M404_INVALID_CONTEXT"
		if b.record.guidance_type == "FOCUS_TARGET" and b.record.preferred_target_id not in enemy_ids: return "M404_INVALID_CONTEXT"
	return ""
