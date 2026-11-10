extends RefCounted

# E1 v1. Rebuilt values/copies only: no mutable catalog backing store or seed import.
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const PARTY = ["player", "npc_01", "npc_02", "npc_03"]
const ENEMIES = ["enemy_a", "enemy_b"]
const MAX_HP = [30, 10, 10, 10, 15, 12]
const FIXTURES = ["main", "player-down", "npc-down", "victory", "defeat"]

static func canonical(value: Variant) -> String:
	# Versioned serialization: UTF-8, lexicographic object keys, stable arrays, ints.
	return JSON.stringify(value, "", true, true)

static func content() -> Dictionary:
	var fixtures: Array = []
	for name in FIXTURES:
		var hp: Array = [30, 10, 7, 3, 15, 12]
		if name == "player-down": hp[0] = 0
		if name == "npc-down": hp[1] = 0
		if name == "victory": hp[4] = 0; hp[5] = 0
		if name == "defeat": hp = [0, 0, 0, 0, 15, 12]
		fixtures.append({"fixture_id": "m405-demo/" + name, "fixture_version": 1, "hp": hp})
	var profiles: Array = []
	for id in PARTY.slice(1): profiles.append(Data.fixed_profile(id, "player"))
	return {"contract_revision": 2, "fixture_version": 1, "capacity": 6,
		"damage_policy": "MAIN_5_1_3", "enemy_policy": "WEAKEST_RATIO_HP_ORDER_V1",
		"party": PARTY.duplicate(), "enemies": ENEMIES.duplicate(), "max_hp": MAX_HP.duplicate(),
		"profiles": profiles, "fixtures": fixtures}

static func seed_reference_snapshot(id: String) -> Dictionary:
	return {"fixture_id": id, "fixture_version": 1, "contract_revision": 2,
		"catalog_sha256": canonical(content()).sha256_text(), "damage_policy": "MAIN_5_1_3",
		"enemy_policy": "WEAKEST_RATIO_HP_ORDER_V1", "capacity": 6}

static func fixture(id: String, version: int) -> Dictionary:
	if version != 1: return {}
	for row in content().fixtures:
		if row.fixture_id == id: return row.duplicate(true)
	return {}

static func initial_party(id: String, session: int, generation: int) -> Array:
	var row: Dictionary = fixture(id, 1)
	if row.is_empty(): return []
	var result: Array = []
	var ordinal: int = 0
	for i in range(4):
		var episode: Variant = null
		if row.hp[i] == 0:
			ordinal += 1
			episode = {"episode_id": "m405/%s/%s/episode/%s" % [session, generation, ordinal],
				"entry_round": 1, "budget": 2, "active": true, "entry_order": ordinal}
		result.append({"actor_id": PARTY[i], "role": "PLAYER" if i == 0 else "NPC", "hp": row.hp[i],
			"max_hp": MAX_HP[i], "life": "DOWN" if row.hp[i] == 0 else "ALIVE", "participation": "PRESENT",
			"eligible": row.hp[i] > 0, "episode": episode, "help_uses": null if i == 0 else 1,
			"rescue_uses": 1, "guard": null})
	return result

static func initial_enemies(id: String) -> Array:
	var row: Dictionary = fixture(id, 1)
	if row.is_empty(): return []
	var result: Array = []
	for i in range(2):
		result.append({"actor_id": ENEMIES[i], "hp": row.hp[i + 4], "max_hp": MAX_HP[i + 4],
			"available": row.hp[i + 4] > 0})
	return result
