extends RefCounted

# Each version rebuilds its immutable partition. No mutable catalog or seed import.
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const PARTY = ["player", "npc_01", "npc_02", "npc_03"]
const ENEMIES = ["enemy_a", "enemy_b"]
const MAX_HP = [30, 10, 10, 10, 15, 12]
const FIXTURES = ["main", "player-down", "npc-down", "victory", "defeat"]
const PLAYER_LOW = "m405-demo/b2-player-low"
const NPC_GUARD_DOWN = "m405-demo/b2-npc-guard-down"

static func fixture_pair_valid(id: String, version: int) -> bool:
	# An unknown v1 ID still reaches the factory's historical UNKNOWN_FIXTURE path.
	var is_v2: bool = id in [PLAYER_LOW, NPC_GUARD_DOWN]
	return version == (2 if is_v2 else 1)

static func contract_revision(version: int) -> int:
	return 3 if version == 2 else 2

static func canonical(value: Variant) -> String:
	# Versioned serialization: UTF-8, lexicographic object keys, stable arrays, ints.
	return JSON.stringify(value, "", true, true)

static func content(version: int = 1) -> Dictionary:
	var fixtures: Array = []
	match version:
		1:
			for name in FIXTURES:
				var hp: Array = [30, 10, 7, 3, 15, 12]
				if name == "player-down": hp[0] = 0
				if name == "npc-down": hp[1] = 0
				if name == "victory": hp[4] = 0; hp[5] = 0
				if name == "defeat": hp = [0, 0, 0, 0, 15, 12]
				fixtures.append({"fixture_id": "m405-demo/" + name, "fixture_version": 1, "hp": hp})
		2:
			fixtures = [
				{"fixture_id": PLAYER_LOW, "fixture_version": 2, "hp": [2, 10, 7, 3, 15, 12]},
				{"fixture_id": NPC_GUARD_DOWN, "fixture_version": 2, "hp": [30, 10, 7, 1, 15, 12]},
			]
		_: return {}
	var profiles: Array = []
	for id in PARTY.slice(1): profiles.append(Data.fixed_profile(id, "player"))
	return {"contract_revision": contract_revision(version), "fixture_version": version, "capacity": 6,
		"damage_policy": "MAIN_5_1_3", "enemy_policy": "WEAKEST_RATIO_HP_ORDER_V1",
		"party": PARTY.duplicate(), "enemies": ENEMIES.duplicate(), "max_hp": MAX_HP.duplicate(),
		"profiles": profiles, "fixtures": fixtures}

static func seed_reference_snapshot(id: String, version: int = 1) -> Dictionary:
	if not fixture_pair_valid(id, version): return {}
	var partition: Dictionary = content(version)
	return {"fixture_id": id, "fixture_version": version, "contract_revision": partition.contract_revision,
		"catalog_sha256": canonical(partition).sha256_text(), "damage_policy": partition.damage_policy,
		"enemy_policy": partition.enemy_policy, "capacity": partition.capacity}

static func fixture(id: String, version: int) -> Dictionary:
	if not fixture_pair_valid(id, version): return {}
	for row in content(version).fixtures:
		if row.fixture_id == id: return row
	return {}

static func initial_party(id: String, session: int, generation: int, version: int = 1) -> Array:
	var row: Dictionary = fixture(id, version)
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

static func initial_enemies(id: String, version: int = 1) -> Array:
	var row: Dictionary = fixture(id, version)
	if row.is_empty(): return []
	var result: Array = []
	for i in range(2):
		result.append({"actor_id": ENEMIES[i], "hp": row.hp[i + 4], "max_hp": MAX_HP[i + 4],
			"available": row.hp[i + 4] > 0})
	return result
