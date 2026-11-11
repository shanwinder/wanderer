extends RefCounted

# Computes only detached actor rows and the corresponding effect.
static func project(root: Dictionary, token: Dictionary) -> Dictionary:
	var party: Array = root.party.duplicate(true)
	var enemies: Array = root.enemies.duplicate(true)
	var rows: Dictionary = {}
	for row in party + enemies:
		rows[row.actor_id] = row
	var actor: Dictionary = rows.get(token.actor_id, {})
	var target: Dictionary = rows.get(token.target_id, {})
	if actor.is_empty() or target.is_empty(): return {}

	var actor_is_party: bool = actor.has("role")
	var target_is_party: bool = target.has("role")
	match token.kind:
		"ATTACK":
			if actor_is_party == target_is_party: return {}
		"HELP":
			if actor.get("role") != "NPC" or target.get("role") != "PLAYER": return {}
		"DEFEND":
			if not actor_is_party or token.actor_id != token.target_id: return {}
		_: return {}

	var effect: Dictionary = {"status": "APPLIED", "reason": "M405_EFFECT_APPLIED",
		"hp_delta": 0, "target_id": token.target_id, "resources": [], "guards": [], "lifecycle": []}
	if not actor.get("eligible", actor.get("available", false)):
		_skip(effect, "M405_ACTOR_UNAVAILABLE")
	elif not target.get("eligible", target.get("available", false)):
		_skip(effect, "M405_TARGET_UNAVAILABLE")
	else:
		match token.kind:
			"ATTACK": _attack(root, target, token.amount, effect)
			"HELP": _help(actor, target, effect)
			"DEFEND": _defend(root.round_id, token, target, effect)
	return {"party": party, "enemies": enemies, "effect": effect}

static func _skip(effect: Dictionary, reason: String) -> void:
	effect.status = "SKIPPED"
	effect.reason = reason

static func help_gain(hp: int, max_hp: int) -> int:
	return mini(4, max_hp - hp)

static func _help(actor: Dictionary, target: Dictionary, effect: Dictionary) -> void:
	if actor.help_uses != 1:
		_skip(effect, "M405_RESOURCE_UNAVAILABLE")
		return
	# The <=30% threshold selected HELP at lock. Here the target must still benefit.
	var gain: int = help_gain(target.hp, target.max_hp)
	if gain <= 0:
		_skip(effect, "M405_HELP_NO_HEAL")
		return
	target.hp += gain
	effect.hp_delta = gain
	effect.resources.append({"actor_id": actor.actor_id, "resource": "HELP", "before": actor.help_uses, "after": 0})
	actor.help_uses = 0

static func _defend(round_id: int, token: Dictionary, target: Dictionary, effect: Dictionary) -> void:
	var guard: Dictionary = {"actor_id": target.actor_id, "grant_action_id": token.action_id,
		"round_id": round_id, "mode": "ROUND" if target.role == "PLAYER" else "NEXT_ENEMY_HIT"}
	_set_guard(target, guard, "GRANT", effect)

static func _set_guard(target: Dictionary, after: Variant, cause: String, effect: Dictionary) -> void:
	if target.guard == after: return
	effect.guards.append({"actor_id": target.actor_id, "before": target.guard, "after": after, "cause": cause})
	target.guard = after

static func _attack(root: Dictionary, target: Dictionary, amount: int, effect: Dictionary) -> void:
	# ATTACK crosses teams. Only a hit on Party can encounter a Guard.
	var guard: Variant = target.get("guard")
	var guarded: bool = guard != null and guard.round_id == root.round_id
	var hit_damage: int = maxi(1, amount - 2) if guarded else amount
	var hp_before: int = target.hp
	target.hp = maxi(0, hp_before - hit_damage)
	effect.hp_delta = target.hp - hp_before
	if not target.has("life"):
		target.available = target.hp > 0
		return
	if target.hp == 0:
		_down(root, target, effect)
		# DOWN supersedes consumption. Publish one change from the original grant.
		_set_guard(target, null, "DOWN", effect)
	elif guarded and guard.mode == "NEXT_ENEMY_HIT":
		_set_guard(target, null, "CONSUME", effect)

static func _down(root: Dictionary, target: Dictionary, effect: Dictionary) -> void:
	var ordinal: int = 1
	for member in root.party:
		if member.episode != null:
			ordinal = maxi(ordinal, member.episode.entry_order + 1)
	target.life = "DOWN"
	target.eligible = false
	target.episode = {"episode_id": "m405/%s/%s/episode/%s" % [root.session, root.generation, ordinal],
		"entry_round": root.round_id, "budget": 2, "active": true, "entry_order": ordinal}
	effect.lifecycle.append({"actor_id": target.actor_id, "before_life": "ALIVE", "after_life": "DOWN",
		"before_participation": "PRESENT", "after_participation": "PRESENT"})
