extends SceneTree

const Owner = preload("res://scripts/m4/playable_encounter.gd")
const Rules = preload("res://scripts/m4/playable_rules.gd")
const Contract = preload("res://scripts/m4/playable_contract.gd")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const Effects = preload("res://scripts/m4/playable_effect_rules.gd")
const MAIN = "m405-demo/main"
const PLAYER_LOW = "m405-demo/b2-player-low"
const NPC_GUARD_DOWN = "m405-demo/b2-npc-guard-down"
const V1_DIGEST = "09f773cd96f7bb61bfd42226f1324b863a3eec484a684b88e85709bf5afeb28c"
const LEGAL = "REAL LEGAL TRANSACTION"
const SCHEMA = "PURE SCHEMA / POLICY"
const REJECTION = "ADVERSARIAL REJECTION"
const DEFERRED = "DEFERRED DEPENDENCY"

# Alters only generated copies at the existing validation seam.
class FaultProbe:
	extends "res://scripts/m4/playable_encounter.gd"
	var fault: String = ""

	func _candidate_valid(request: Dictionary, result: Dictionary) -> bool:
		if fault.is_empty(): return super._candidate_valid(request, result)
		var bad: Dictionary = result.duplicate(true)
		match fault:
			"receipt": bad.response.receipt.authorization_id += "/forged"
			"resource": bad.root.party[1].help_uses = 1
			"guard":
				bad.response.effect.guards[0].after.grant_action_id += 1
				bad.root.actions.back().effect = bad.response.effect.duplicate(true)
				bad.root.party[0].guard.grant_action_id += 1
				bad.response.view.party[0].guard.grant_action_id += 1
		return super._candidate_valid(request, bad)

var factory := RefCounted.new()
var input_cap := RefCounted.new()
var driver := RefCounted.new()
var presenter := RefCounted.new()
var checks: Array = []
var history: Array = []
var deferred: Array = []
var final_roots: Dictionary = {}
var sequence: int = 0
var failures: int = 0
var scenario: String = ""

func _initialize() -> void:
	_catalog_proof()
	_player_round("help", "ATTACK", true)
	_player_round("player-guard-persists", "DEFEND", true)
	_player_round("player-guard-down", "DEFEND", false)
	_npc_round("npc-guard-consume", MAIN, 1)
	_npc_round("npc-guard-consume-down", NPC_GUARD_DOWN, 2)
	_record_deferred()
	var report: Dictionary = {
		"status": "PASS" if failures == 0 else "FAIL", "checks": checks, "failures": failures,
		"history": history, "deferred": deferred, "final_roots": final_roots,
		"v1_sha256": Catalog.canonical(Catalog.content(1)).sha256_text(),
		"v2_sha256": Catalog.canonical(Catalog.content(2)).sha256_text(),
	}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if file == null:
				print("FAIL: cannot write report")
				quit(1)
				return
			file.store_string(JSON.stringify(report, "\t"))
	print("B2 EFFECT PROOF: %s checks=%s failures=%s deferred=%s" % [report.status, checks.size(), failures, deferred.size()])
	quit(int(failures > 0))

func _check(ok: bool, label: String, classification: String = LEGAL) -> bool:
	checks.append({"scenario": scenario, "classification": classification, "label": label, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL: %s/%s" % [scenario, label])
	return ok

func _boot_payload(id: String, version: Variant) -> Dictionary:
	return {"domain": "M4_PLAYABLE", "version": 1, "fixture_id": id, "fixture_version": version}

func _catalog_proof() -> void:
	scenario = "catalog"
	var v1: Dictionary = Catalog.content()
	var v2: Dictionary = Catalog.content(2)
	_check(Catalog.canonical(v1).sha256_text() == V1_DIGEST and v1.contract_revision == 2, "exact V1 serialization and digest", SCHEMA)
	_check(v2.fixture_version == 2 and v2.contract_revision == 3 and v2.fixtures.size() == 2
		and Catalog.canonical(v2).sha256_text() != V1_DIGEST, "separate two-row V2 partition and digest", SCHEMA)
	var seeds: Dictionary = {
		MAIN: [30, 10, 7, 3, 15, 12], "m405-demo/player-down": [0, 10, 7, 3, 15, 12],
		"m405-demo/npc-down": [30, 0, 7, 3, 15, 12], "m405-demo/victory": [30, 10, 7, 3, 0, 0],
		"m405-demo/defeat": [0, 0, 0, 0, 15, 12], PLAYER_LOW: [2, 10, 7, 3, 15, 12],
		NPC_GUARD_DOWN: [30, 10, 7, 1, 15, 12],
	}
	var unknown: String = "m405-demo/unknown"
	for id in seeds.keys() + [unknown]:
		var version: int = 2 if id in [PLAYER_LOW, NPC_GUARD_DOWN] else 1
		for input_version in [1, 2, true, false, 1.0, 2.0, "1", "2", null, 0, -1, 3, 999]:
			var e := Owner.new(factory, input_cap, driver, presenter)
			var boot: Dictionary = _boot_payload(id, input_version)
			var valid_pair: bool = typeof(input_version) == TYPE_INT and input_version == version
			var label: String = "%s / %s [%s]" % [id, str(input_version), type_string(typeof(input_version))]
			var payload: Dictionary = {"fixture_id": id, "fixture_version": input_version}
			_check(Contract.valid("Bootstrap", boot) == valid_pair, "Bootstrap " + label, SCHEMA)
			_check(Contract.valid("RestartPayload", payload) == valid_pair, "RestartPayload " + label, SCHEMA)
			var seed: Dictionary = Catalog.seed_reference_snapshot(id, version)
			var wrong_seed: Dictionary = seed.duplicate(true)
			wrong_seed.fixture_version = input_version
			_check(Contract.valid("SeedReference", wrong_seed) == valid_pair, "SeedReference " + label, SCHEMA)
			var result: Dictionary = e.bootstrap(boot, factory)
			if not valid_pair or id == unknown:
				var reason: String = "M405_UNKNOWN_FIXTURE" if valid_pair else "M405_INVALID_SCHEMA"
				_check(result.reason == reason and e.snapshot().is_empty(), "factory rejection " + label, REJECTION)
				continue
			if not _check(result.status == "CREATED", "factory " + label): continue
			var root: Dictionary = e.snapshot()
			var hp: Array = []
			var max_hp: Array = []
			var ids: Array = []
			for row in root.party + root.enemies:
				hp.append(row.hp)
				max_hp.append(row.max_hp)
				ids.append(row.actor_id)
			_check(hp == seeds[id] and max_hp == [30, 10, 10, 10, 15, 12] and ids == Catalog.PARTY + Catalog.ENEMIES, "exact roster/HP " + id)
			_check(root.seed == seed and root.guidance.profiles == v1.profiles and root.journal.is_empty()
				and root.actions.is_empty() and root.receipts.is_empty() and root.queue == null, "exact initial provenance " + id)
			for party in root.party:
				_check(party.guard == null and party.rescue_uses == 1 and party.help_uses == (1 if party.role == "NPC" else null), "unspent initial ledgers " + party.actor_id)
				if version == 2:
					_check(party.life == "ALIVE" and party.participation == "PRESENT" and party.episode == null, "V2 begins ALIVE with no episode " + party.actor_id)
			_check(e.replay_matches() and Rules.replay(seed, root.session, root.generation, []) == root, "initial full-root replay " + id)
			var tampered: Dictionary = root.duplicate(true)
			tampered.seed.contract_revision = 2 if version == 2 else 3
			_check(not Contract.valid("Root", tampered) and not Rules.root_valid(tampered), "recursive partition revision rejection " + id, SCHEMA)
			tampered.seed = seed.duplicate(true)
			tampered.seed.catalog_sha256 = V1_DIGEST if version == 2 else Catalog.canonical(v2).sha256_text()
			_check(not Rules.root_valid(tampered) and Rules.replay(tampered.seed, root.session, root.generation, []).is_empty(), "wrong partition digest rejects replay " + id, REJECTION)
			var restarted: Dictionary = _transact(e, "RESTART", payload, "INPUT")
			_check(restarted.status == "APPLIED" and restarted.reason == "M405_RESTARTED"
				and restarted.effect == null and restarted.receipt == null and restarted.token == null,
				"Restart returns new View without combat Effect or Receipt")
			_check(e.snapshot() == Rules.initial(id, root.session, root.generation + 1, version),
				"Restart reconstructs exact selected catalog seed")
			var stale: Dictionary = _request(e, "RESTART", payload, "INPUT")
			stale.identity.generation = root.generation
			var fresh: Dictionary = e.snapshot()
			_check(e.transact(stale, input_cap).reason == "M405_STALE_GENERATION"
				and e.snapshot() == fresh, "old-generation Restart preserves complete new root", REJECTION)
			_reject(e, "RESTART", {"fixture_id": id, "fixture_version": 3 - version}, "M405_INVALID_SCHEMA", "INPUT")
	var detached: Dictionary = Catalog.content(2)
	detached.fixtures[0].hp[0] = 30
	_check(Catalog.content(2).fixtures[0].hp[0] == 2 and Catalog.content() == v1, "catalog snapshots isolated", SCHEMA)
	_check(Rules.replay(Catalog.seed_reference_snapshot(unknown), 1, 1, []).is_empty(), "unknown v1 seed cannot reconstruct", REJECTION)
	_check(Effects.help_gain(2, 30) == 4 and Effects.help_gain(28, 30) == 2 and Effects.help_gain(30, 30) == 0, "pure heal cap arithmetic", SCHEMA)

func _request(e: Owner, op: String, payload: Dictionary, issuer: String) -> Dictionary:
	sequence += 1
	var view: Dictionary = e.read_view()
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": view.identity, "queue_id": view.queue_id,
		"request_id": ("ui/" if issuer == "INPUT" else "driver/") + str(sequence),
		"issuer": issuer, "operation": op, "payload": payload}

func _transact(e: Owner, op: String, payload: Dictionary = {}, issuer: String = "DRIVER") -> Dictionary:
	var before: Dictionary = e.snapshot()
	var request: Dictionary = _request(e, op, payload, issuer)
	var cap: RefCounted = {"DRIVER": driver, "INPUT": input_cap, "PRESENTER": presenter}[issuer]
	var reply: Dictionary = e.transact(request, cap)
	var after: Dictionary = e.snapshot()
	var classification: String = REJECTION if reply.get("status") == "REJECTED" else LEGAL
	history.append({"scenario": scenario, "classification": classification, "request": request,
		"response": reply, "before": before, "after": after})
	_check(Contract.response_valid(op, reply), op + " exact response", classification)
	if classification == LEGAL and op == "RESTART":
		var audit: Dictionary = e.restart_audit().back()
		_check(after.session == before.session and after.generation == before.generation + 1
			and after.revision == 0 and after.journal.is_empty()
			and audit.root == before and audit.request == request and audit.identity == reply.identity,
			"RESTART authenticated generation publication")
	elif classification == LEGAL:
		_check(after.revision == before.revision + 1 and after.journal.size() == before.journal.size() + 1
			and after.journal.back().request == request
			and after.journal.back().result_digest == Catalog.canonical(reply).sha256_text(), op + " authenticated journal publication")
	return reply

func _reject(e: Owner, op: String, payload: Dictionary, reason: String, issuer: String = "DRIVER") -> void:
	var before: Dictionary = e.snapshot()
	var reply: Dictionary = _transact(e, op, payload, issuer)
	_check(reply.get("reason") == reason and reply.get("status") == "REJECTED"
		and reply.effect == null and reply.receipt == null and reply.token == null
		and e.snapshot() == before, op + " " + reason + " preserves full root", REJECTION)

func _begin(e: Owner, id: String, version: int, action: String, declared_target: String) -> bool:
	if not _check(e.bootstrap(_boot_payload(id, version), factory).status == "CREATED", "bootstrap " + id): return false
	var target: String = "player" if action == "DEFEND" else "enemy_a"
	if not _check(_transact(e, "COMMAND", {"actor_id": "player", "action": action, "target_id": target}, "INPUT").get("status") == "ACCEPTED", "accepted Player command"): return false
	if not _check(_transact(e, "ADMIT").get("status") == "APPLIED", "round admitted"): return false
	return _check(e.snapshot().declarations == [
		{"actor_id": "enemy_a", "target_id": declared_target, "damage": 3},
		{"actor_id": "enemy_b", "target_id": declared_target, "damage": 3},
	], "unchanged weakest-target admission")

func _lock(e: Owner, actor: String, kind: String, target: String) -> Dictionary:
	var slot: Dictionary = Rules.slot(e.snapshot())
	if not _check(slot.get("actor_id") == actor, "actual slot " + actor): return {}
	var op: String
	var payload: Dictionary
	if actor.begins_with("npc_"):
		op = "DECIDE_LOCK"
		payload = {"observation": e.read_observation()}
	else:
		op = "PLAYER_LOCK" if actor == "player" else "ENEMY_LOCK"
		payload = {"slot_id": slot.slot_id}
	var reply: Dictionary = _transact(e, op, payload)
	if not _check(reply.get("status") == "AUTHORIZED", "owner-issued lock " + actor): return {}
	var token: Dictionary = reply.token
	if not _check(token.actor_id == actor and token.kind == kind and token.target_id == target
		and token.slot_id == slot.slot_id and token.opportunity_id == slot.opportunity_id
		and token.identity == e.read_view().identity and token == e.snapshot().actions.back().token,
		"authorized %s %s to %s" % [actor, kind, target]): return {}
	return token

func _settle(e: FaultProbe, token: Dictionary, expected: Dictionary, adversarial: bool = false) -> bool:
	if token.is_empty(): return false
	var payload: Dictionary = {"token": token}
	var before: Dictionary = e.snapshot()
	if adversarial:
		var forged: Dictionary = token.duplicate(true)
		forged.authorization_id += "/forged"
		_reject(e, "IMPACT", {"token": forged}, "M405_INVALID_TOKEN", "PRESENTER")
		_reject(e, "COMPLETE", payload, "M405_INVALID_TOKEN_PHASE", "PRESENTER")
		if not _check(e.inject_failure_before_publication(driver), "arm publication fault", REJECTION): return false
		_reject(e, "IMPACT", payload, "M405_INVALID_CANDIDATE", "PRESENTER")
		if token.kind in ["HELP", "DEFEND"]:
			e.fault = "resource" if token.kind == "HELP" else "guard"
			_reject(e, "IMPACT", payload, "M405_INVALID_CANDIDATE", "PRESENTER")
			e.fault = ""
	var impact: Dictionary = _transact(e, "IMPACT", payload, "PRESENTER")
	var impacted: Dictionary = e.snapshot()
	if not _check(impact.get("effect") == expected and impact.get("status") == expected.status
		and impact.get("reason") == expected.reason and impact.receipt == null, token.actor_id + " exact IMPACT effect"): return false
	_check(impacted.receipts == before.receipts and impacted.actions.back().effect == expected,
		"IMPACT records effect with no receipt")
	if adversarial:
		_reject(e, "IMPACT", payload, "M405_INVALID_TOKEN_PHASE", "PRESENTER")
		_reject(e, "CANCEL", payload, "M405_INVALID_TOKEN_PHASE")
		e.fault = "receipt"
		_reject(e, "COMPLETE", payload, "M405_INVALID_CANDIDATE", "PRESENTER")
		e.fault = ""
	var complete: Dictionary = _transact(e, "COMPLETE", payload, "PRESENTER")
	var final: Dictionary = e.snapshot()
	if not _check(complete.get("status") == "COMPLETED" and complete.get("effect") == null, "genuine COMPLETE"): return false
	var receipt: Dictionary = complete.receipt
	_check(receipt.action_id == token.action_id and receipt.authorization_id == token.authorization_id
		and receipt.session == token.identity.session and receipt.generation == token.identity.generation
		and receipt.round_id == token.identity.round_id and receipt.slot_id == token.slot_id
		and receipt.queue_id == token.queue_id and receipt.impact_revision == impacted.revision
		and receipt.completion_revision == final.revision and receipt.effect_status == expected.status
		and final.receipts.size() == before.receipts.size() + 1 and final.receipts.back() == receipt
		and final.actions.back().effect == expected and final.party == impacted.party and final.enemies == impacted.enemies,
		"receipt bound to owner token, effect and revisions")
	if adversarial:
		_reject(e, "COMPLETE", payload, "M405_INVALID_TOKEN_PHASE", "PRESENTER")
		_invalid_effect_shapes(expected)
	return true

func _effect(target: String, hp_delta: int, resources: Array = [], guards: Array = [], lifecycle: Array = []) -> Dictionary:
	return {"status": "APPLIED", "reason": "M405_EFFECT_APPLIED", "target_id": target,
		"hp_delta": hp_delta, "resources": resources, "guards": guards, "lifecycle": lifecycle}

func _guard(token: Dictionary, mode: String) -> Dictionary:
	return {"actor_id": token.actor_id, "grant_action_id": token.action_id,
		"round_id": token.identity.round_id, "mode": mode}

func _guard_change(actor: String, before: Variant, after: Variant, cause: String) -> Dictionary:
	return {"actor_id": actor, "before": before, "after": after, "cause": cause}

func _life_change(actor: String) -> Dictionary:
	return {"actor_id": actor, "before_life": "ALIVE", "after_life": "DOWN",
		"before_participation": "PRESENT", "after_participation": "PRESENT"}

func _cancel(e: Owner, token: Dictionary) -> bool:
	if token.is_empty(): return false
	var before: Dictionary = e.snapshot()
	var reply: Dictionary = _transact(e, "CANCEL", {"token": token})
	var after: Dictionary = e.snapshot()
	return _check(reply.get("reason") == "M405_ACTION_CANCELLED" and reply.receipt == null and reply.effect == null
		and before.party == after.party and before.enemies == after.enemies and before.receipts == after.receipts
		and after.actions.back().phase == "CANCELLED" and after.actions.back().effect == null
		and after.queue.dispositions.back().kind == "CANCELLED", "legal pre-impact CANCEL without resource, effect or receipt")

func _player_round(label: String, command: String, help_applies: bool) -> void:
	scenario = label
	var e := FaultProbe.new(factory, input_cap, driver, presenter)
	if not _begin(e, PLAYER_LOW, 2, command, "player"): return
	var token: Dictionary = _lock(e, "player", command, "player" if command == "DEFEND" else "enemy_a")
	if token.is_empty(): return
	var guard: Variant = null
	if command == "DEFEND":
		guard = _guard(token, "ROUND")
		if not _settle(e, token, _effect("player", 0, [], [_guard_change("player", null, guard, "GRANT")]), help_applies): return
		_check(e.snapshot().party[0].guard == guard, "Player ROUND Guard owned after DEFEND")
	elif not _settle(e, token, _effect("enemy_a", -5)):
		return
	for index in range(1, 4):
		var npc: String = Catalog.PARTY[index]
		if help_applies and index == 3:
			if not _cancel(e, _lock(e, npc, "RETREAT", npc)): return
			continue
		var before: Dictionary = e.snapshot()
		token = _lock(e, npc, "HELP", "player")
		if not help_applies:
			if not _cancel(e, token): return
			continue
		_check(before.party[0].hp == 2 + (index - 1) * 4 and before.party[index].help_uses == 1, "HELP decision with living low Player and unspent helper " + npc)
		var spend: Dictionary = {"actor_id": npc, "resource": "HELP", "before": 1, "after": 0}
		if not _settle(e, token, _effect("player", 4, [spend]), label == "help" and index == 1): return
		var after: Dictionary = e.snapshot()
		_check(after.party[0].hp == 2 + index * 4 and after.party[0].episode == null
			and after.party[0].guard == guard and after.party[index].help_uses == 0
			and after.party[index].rescue_uses == 1, "HELP positive HP and only its own HELP ledger " + npc)
	for index in range(2):
		var enemy: String = Catalog.ENEMIES[index]
		token = _lock(e, enemy, "ATTACK", "player")
		var down: bool = not help_applies and index == 1
		var guard_changes: Array = [_guard_change("player", guard, null, "DOWN")] if down else []
		var lifecycle: Array = [_life_change("player")] if down else []
		var loss: int = 3 if command == "ATTACK" else 1
		if not _settle(e, token, _effect("player", -loss, [], guard_changes, lifecycle)): return
		var player: Dictionary = e.snapshot().party[0]
		_check(player.hp == (10 if help_applies else 2) - (index + 1) * loss
			and player.guard == (null if down else guard) and player.life == ("DOWN" if down else "ALIVE")
			and (player.episode != null) == down, "Player hit %s HP, lifecycle and Guard" % (index + 1))
	_finish(e)

func _npc_round(label: String, id: String, version: int) -> void:
	scenario = label
	var e := FaultProbe.new(factory, input_cap, driver, presenter)
	if not _begin(e, id, version, "ATTACK", "npc_03"): return
	for actor in ["player", "npc_01", "npc_02"]:
		if not _settle(e, _lock(e, actor, "ATTACK", "enemy_a"), _effect("enemy_a", -Rules.damage(actor))): return
	var token: Dictionary = _lock(e, "npc_03", "DEFEND", "npc_03")
	if token.is_empty(): return
	var guard: Dictionary = _guard(token, "NEXT_ENEMY_HIT")
	if not _settle(e, token, _effect("npc_03", 0, [], [_guard_change("npc_03", null, guard, "GRANT")])): return
	_check(e.snapshot().party[3].guard == guard, "independent NPC3 DEFEND grant")
	var same_hit_down: bool = version == 2
	var changes: Array = [_guard_change("npc_03", guard, null, "DOWN" if same_hit_down else "CONSUME")]
	var lifecycle: Array = [_life_change("npc_03")] if same_hit_down else []
	if not _settle(e, _lock(e, "enemy_a", "ATTACK", "npc_03"), _effect("npc_03", -1, [], changes, lifecycle)): return
	var npc: Dictionary = e.snapshot().party[3]
	_check(npc.guard == null and npc.hp == (0 if same_hit_down else 2)
		and npc.life == ("DOWN" if same_hit_down else "ALIVE"), "first Enemy hit reduces 3 to 1 and removes NPC Guard")
	var expected: Dictionary = _effect("npc_03", -2, [], [], [_life_change("npc_03")])
	if same_hit_down:
		expected = _effect("npc_03", 0)
		expected.status = "SKIPPED"
		expected.reason = "M405_TARGET_UNAVAILABLE"
	var previous: Dictionary = e.snapshot()
	if not _settle(e, _lock(e, "enemy_b", "ATTACK", "npc_03"), expected): return
	npc = e.snapshot().party[3]
	_check(npc.hp == 0 and npc.life == "DOWN" and npc.episode.active and npc.guard == null, "second Enemy retains target, no second Guard")
	if same_hit_down:
		_check(previous.party == e.snapshot().party and previous.enemies == e.snapshot().enemies, "genuine SKIPPED changes no actor rows")
	_finish(e)

func _invalid_effect_shapes(effect: Dictionary) -> void:
	var bad: Dictionary = effect.duplicate(true)
	bad.reason = "M405_TARGET_UNAVAILABLE"
	_check(not Contract.valid("Effect", bad), "wrong APPLIED reason rejects", SCHEMA)
	bad = effect.duplicate(true)
	bad.hp_delta = float(bad.hp_delta)
	_check(not Contract.valid("Effect", bad), "float delta rejects", SCHEMA)
	if not effect.resources.is_empty():
		bad = effect.duplicate(true)
		bad.resources[0].after = true
		_check(not Contract.valid("Effect", bad), "bool resource rejects recursively", SCHEMA)
		bad = effect.duplicate(true)
		bad.resources.append(bad.resources[0].duplicate(true))
		_check(not Contract.valid("Effect", bad), "duplicate resource actor rejects", SCHEMA)
	if not effect.guards.is_empty():
		bad = effect.duplicate(true)
		bad.guards[0].after.actor_id = "wrong_actor"
		_check(not Contract.valid("Effect", bad), "mismatched Guard actor rejects recursively", SCHEMA)
		bad = effect.duplicate(true)
		bad.guards.append(bad.guards[0].duplicate(true))
		_check(not Contract.valid("Effect", bad), "duplicate Guard actor rejects", SCHEMA)

func _finish(e: Owner) -> void:
	var root: Dictionary = e.snapshot()
	_check(root.phase == "OPEN" and root.queue.phase == "DRAINED" and root.outcome == null
		and root.round_history.is_empty(), "actual slot history drains without artificial boundary")
	_check(e.replay_matches() and Rules.replay(root.seed, root.session, root.generation, root.journal) == root,
		"full-root deterministic replay")
	var bad: Dictionary = e.snapshot()
	bad.party[0].hp = 30
	bad.party[1].help_uses = 0
	bad.receipts[0].authorization_id = "forged"
	bad.journal.back().result_digest = "forged"
	_check(e.snapshot() == root and not Rules.root_valid(bad), "detached actor/ledger/receipt/journal mutation isolated", REJECTION)
	_check(Rules.replay(root.seed, root.session, root.generation, bad.journal).is_empty(), "forged journal digest rejects reconstruction", REJECTION)
	final_roots[scenario] = root

func _record_deferred() -> void:
	for row in [
		["later-slot HELP exhaustion", "B3"], ["later-slot DEFEND replacement/nonstacking", "B3"],
		["post-lock external target change", "O7"], ["real capped HELP near MaxHP", "no legal B2 producer"],
		["DEAD/RETREATED and actual RESCUE", "later lifecycle gates"],
		["round-close Guard expiry", "B3"], ["terminal/Restart cleanup", "B4"],
	]:
		deferred.append({"classification": DEFERRED, "scenario": row[0], "dependency": row[1]})
