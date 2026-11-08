extends RefCounted

# Detached replay projection. No Registry, live state or ID decoding.
const Rules = preload("res://scripts/m4/m403_terminal_rules.gd")

static func project(view: Variant) -> Dictionary:
	if not Rules.valid(view): return {}
	var replay: Dictionary = Rules.prepare(view.session, view.generation, view.seed)
	var orders: Dictionary = {}
	var ordinal: int = 0
	for id in replay.initial_party:
		if replay.clocks.has(id):
			ordinal += 1
			orders[replay.clocks[id].episode_id] = ordinal
	if ordinal != replay.episode_serial: return {}
	for event in view.journal:
		var next: Dictionary = Rules.apply(replay, event.operation, event.payload).get("candidate", {})
		if next.is_empty(): return {}
		for id in next.initial_party:
			if next.clocks.has(id) and (not replay.clocks.has(id) or next.clocks[id].episode_id != replay.clocks[id].episode_id):
				var episode: String = next.clocks[id].episode_id
				if orders.has(episode): return {}
				ordinal += 1
				orders[episode] = ordinal
		if ordinal != next.episode_serial: return {}
		replay = next
	if replay != view: return {}
	var result: Dictionary = {}
	for id in replay.clocks:
		var episode: String = replay.clocks[id].episode_id
		if not orders.has(episode): return {}
		result[id] = {"episode_id": episode, "entry_order": orders[episode]}
	return {"session": view.session, "generation": view.generation, "revision": view.revision, "episodes": result}
