extends SceneTree

const Owner = preload("res://scripts/m4/playable_encounter.gd")
const Rules = preload("res://scripts/m4/playable_rules.gd")
const C = preload("res://scripts/m4/playable_contract.gd")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const InputAdapter = preload("res://scripts/m4/playable_input_adapter.gd")
const Guidance = preload("res://scripts/m4/playable_guidance_adapter.gd")
const MAIN = "m405-demo/main"
var factory := RefCounted.new()
var input_cap := RefCounted.new()
var driver := RefCounted.new()
var presenter := RefCounted.new()
var checks: Array = []
var traces: Array = []
var roots: Dictionary = {}
var failures: int = 0
var sequence: int = 0
var scenario: String = ""
var terminal_owners: Array[RefCounted] = []

func _initialize() -> void:
	var selected: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): selected = arg.substr(11)
	for test in ["victory", "guard_terminal", "six_closes", "last_party_down", "rescue_retreat", "guidance", "failed_close", "classifier"]:
		if not selected.is_empty() and selected != test: continue
		scenario = test
		print("B3 START ", test)
		check(call("_" + test) == true, "scenario reached its end")
		for terminal_owner in terminal_owners:
			verify_terminal_restart(terminal_owner)
		terminal_owners.clear()
	check(not checks.is_empty(), "at least one selected scenario ran", "HARNESS")
	var report: Dictionary = {"selected_scenario": selected, "status": "PASS" if failures == 0 else "FAIL", "failures": failures,
		"checks": checks, "traces": traces, "final_roots": roots,
		"coverage_limits": [
			{"case": "Positive Last-Party RETREAT through real transactions", "status": "DEFERRED — OWNER APPROVED", "authority": "30.7"},
			{"case": "Positive NO_PLAYER_COMMAND after rescue before Player slot", "status": "DEFERRED — OWNER APPROVED", "authority": "30.6; real UNAVAILABLE-before-RESCUE tested"},
			{"case": "GUI/keyboard/visual/performance", "status": "NOT RUN", "scope": "B4/B5 or separate acceptance"}]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if file == null: quit(1); return
			file.store_string(JSON.stringify(report, "\t"))
	print("B3 LIFECYCLE PROOF: %s checks=%s failures=%s transactions=%s" % [report.status, checks.size(), failures, traces.size()])
	quit(int(failures > 0))

func check(ok: bool, label: String, category: String = "REAL TRANSACTION") -> bool:
	checks.append({"scenario": scenario, "category": category, "label": label, "passed": ok})
	if not ok:
		failures += 1
		print("FAIL ", scenario, ": ", label)
	return ok

func boot(id: String = MAIN, version: int = 1) -> RefCounted:
	var owner := Owner.new(factory, input_cap, driver, presenter)
	check(owner.bootstrap({"domain": "M4_PLAYABLE", "version": 1, "fixture_id": id, "fixture_version": version}, factory).status == "CREATED", "bootstrap " + id)
	return owner

func request(owner: RefCounted, op: String, payload: Dictionary = {}) -> Dictionary:
	sequence += 1
	var v: Dictionary = owner.read_view()
	var ui: bool = op in ["COMMAND", "GUIDANCE"]
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": v.identity, "queue_id": v.queue_id,
		"request_id": ("ui/" if ui else "driver/") + str(sequence), "issuer": "INPUT" if ui else "DRIVER", "operation": op, "payload": payload}

func send(owner: RefCounted, req: Dictionary, expected: String, capability: Variant = null) -> Dictionary:
	var before: Dictionary = owner.snapshot()
	var cap: Variant = capability if capability != null else (input_cap if req.issuer == "INPUT" else driver)
	var reply: Dictionary = owner.transact(req, cap)
	var after: Dictionary = owner.snapshot()
	check(reply.status == expected, req.operation + " expected " + expected + " actual " + reply.status + "/" + reply.reason)
	check(C.response_valid(req.operation, reply), "exact Response " + req.operation)
	if reply.reason == "M405_CLOSE_FAILED" and after.phase == "SEALED":
		check(after.revision == before.revision + 1 and after.party == before.party and after.receipts == before.receipts, "E5 only genuine SEAL published before failed close", "FAILED COMPOUND CLOSE")
	elif reply.status in ["REJECTED", "READY"]: check(before == after, "whole-root equality " + req.operation, "REJECTION / READ")
	check(Rules.replay(after.seed, after.session, after.generation, after.journal) == after, "whole-root replay " + req.operation)
	traces.append({"scenario": scenario, "request": req.duplicate(true), "response": reply.duplicate(true),
		"pre_sha256": Catalog.canonical(before).sha256_text(), "post_sha256": Catalog.canonical(after).sha256_text(),
		"root_equal": before == after, "post_revision": after.revision})
	return reply

func tx(owner: RefCounted, op: String, payload: Dictionary = {}, expected: String = "APPLIED") -> Dictionary:
	return send(owner, request(owner, op, payload), expected)

func command(owner: RefCounted, action: String = "DEFEND", target: String = "player") -> void:
	tx(owner, "COMMAND", {"actor_id": "player", "action": action, "target_id": target}, "ACCEPTED")

func admit(owner: RefCounted) -> void:
	tx(owner, "ADMIT")
	var r: Dictionary = owner.snapshot()
	for hit in r.declarations: check(hit.target_id == Rules.weakest(r), "admission declaration actual weakest")

func lock(owner: RefCounted) -> Dictionary:
	var r: Dictionary = owner.snapshot()
	var s: Dictionary = Rules.slot(r)
	var actor: Dictionary = Rules.actor(r, s.actor_id)
	if not actor.get("eligible", actor.get("available", false)):
		tx(owner, "ADVANCE")
		return {}
	var op: String = "PLAYER_LOCK" if s.actor_id == "player" else "ENEMY_LOCK"
	var payload: Dictionary = {"slot_id": s.slot_id}
	if actor.get("role") == "NPC":
		op = "DECIDE_LOCK"; payload = {"observation": owner.read_observation()}
	var reply: Dictionary = tx(owner, op, payload, "AUTHORIZED")
	return {} if reply.token == null else reply.token

func finish(owner: RefCounted, token: Dictionary) -> void:
	var r: Dictionary = owner.snapshot()
	var target: Dictionary = Rules.actor(r, token.target_id)
	var skipped: bool = token.kind == "ATTACK" and not target.get("eligible", target.get("available", false))
	tx(owner, "IMPACT", {"token": token}, "SKIPPED" if skipped else "APPLIED")
	tx(owner, "COMPLETE", {"token": token}, "COMPLETED")

func drain(owner: RefCounted, effects: Array = []) -> void:
	for unused in range(6):
		var r: Dictionary = owner.snapshot()
		if r.phase == "TERMINAL" or r.queue.phase == "DRAINED": return
		var token: Dictionary = lock(owner)
		if token.is_empty(): continue
		if token.actor_id in effects: finish(owner, token)
		else: tx(owner, "CANCEL", {"token": token})

func close_round(owner: RefCounted, number: int) -> void:
	var before: Dictionary = owner.snapshot()
	var reply: Dictionary = tx(owner, "CLOSE_ROUND", {}, "STOPPED" if number == 6 else "APPLIED")
	var r: Dictionary = owner.snapshot()
	check(r.revision == before.revision + 2 and r.journal[-2].operation == "SEAL" and r.journal[-1].operation == "COMMIT_CLOSE", "exact two internal publications")
	check(r.closed_rounds == number and r.round_id == mini(6, number + 1), "one close / next prepared identity")
	check(r.guidance.guidance_revision == before.guidance.guidance_revision and r.guidance.active == null and r.command == null, "boundary clears command/Active without R1 increment")
	var h: Dictionary = r.round_history.back()
	check(h.close.consumed and h.close.witness.dispositions == before.queue.dispositions and h.close.witness.receipt_ids.size() > 0, "authentic consumed witness / progress")
	check(reply.view.boundary_changes == h.close.changes, "honest boundary changes")
	if number < 6: check(r.queue == null and r.guidance.pending == Guidance.record(r), "next-round NONE and absent queue")

func terminal_settle(owner: RefCounted, token: Dictionary, outcome: String) -> void:
	var before: Dictionary = owner.snapshot()
	check(owner.inject_failure_before_publication(driver), "arm terminal IMPACT fault")
	tx(owner, "IMPACT", {"token": token}, "REJECTED")
	check(owner.snapshot() == before, "terminal impact fault leaves original LOCKED grant")
	var impact: Dictionary = tx(owner, "IMPACT", {"token": token})
	var frozen: Dictionary = owner.snapshot()
	check(frozen.phase == "TERMINAL" and frozen.outcome.result == outcome and frozen.outcome.freeze_revision == frozen.revision, "IMPACT freezes expected outcome")
	check(impact.receipt == null and frozen.receipts == before.receipts and frozen.closed_rounds == 5, "no receipt/close at terminal impact")
	check(frozen.queue.phase == "WAIT_ACTION" and frozen.queue.cursor == before.queue.cursor and Rules.queue_relation_valid(frozen), "terminal WAIT_ACTION relational exception")
	check(frozen.guidance.active == null and frozen.guidance.pending == null and frozen.guidance.guidance_revision == before.guidance.guidance_revision, "atomic Guidance cleanup, no R1 increment")
	for p in frozen.party: check(p.guard == null, "terminal no Guard " + p.actor_id)
	for op in ["COMMAND", "GUIDANCE", "ADMIT", "ADVANCE", "PLAYER_LOCK", "ENEMY_LOCK", "DECIDE_LOCK", "CLOSE_ROUND"]:
		var payload: Dictionary = {}
		if op == "COMMAND": payload = {"actor_id": "player", "action": "DEFEND", "target_id": "player"}
		elif op == "GUIDANCE": payload = {"request": guidance_request(owner, "ATTACK")}
		elif op.ends_with("LOCK"):
			if op == "DECIDE_LOCK":
				for entry in before.journal:
					if entry.operation == "DECIDE_LOCK": payload = entry.request.payload
			else: payload = {"slot_id": token.slot_id}
		var rejected: Dictionary = tx(owner, op, payload, "REJECTED")
		check(rejected.reason == "M405_TERMINAL", "terminal stops " + op, "REJECTION")
	var forged: Dictionary = token.duplicate(true); forged.authorization_id += "/forged"
	check(tx(owner, "COMPLETE", {"token": forged}, "REJECTED").reason == "M405_INVALID_TOKEN", "forged causal completion rejects", "REJECTION")
	check(owner.inject_failure_before_publication(driver), "arm causal COMPLETE fault")
	tx(owner, "COMPLETE", {"token": token}, "REJECTED")
	check(owner.snapshot() == frozen, "causal COMPLETE fault entire frozen root unchanged")
	var complete: Dictionary = tx(owner, "COMPLETE", {"token": token}, "COMPLETED")
	var settled: Dictionary = owner.snapshot()
	check(complete.receipt.action_id == token.action_id and settled.receipts.size() == frozen.receipts.size() + 1 and settled.queue.phase == "STOPPED", "one causal receipt and STOPPED")
	for key in ["outcome", "party", "enemies", "closed_rounds", "round_id", "round_history", "guidance", "command"]:
		check(settled[key] == frozen[key], "COMPLETE preserves frozen " + key)
	check(tx(owner, "COMPLETE", {"token": token}, "REJECTED").reason == "M405_INVALID_TOKEN_PHASE", "duplicate COMPLETE phase precedence", "REJECTION")
	for key in ["missing-disposition", "duplicate-receipt", "outcome", "terminal-stop-revision", "queue-phase"]:
		var bad: Dictionary = settled.duplicate(true)
		match key:
			"missing-disposition": bad.queue.dispositions.pop_back()
			"duplicate-receipt": bad.receipts.append(bad.receipts.back().duplicate(true))
			"outcome": bad.outcome.freeze_revision += 1
			"terminal-stop-revision": bad.queue.dispositions.back().observed_revision += 1
			"queue-phase": bad.queue.phase = "READY"
		check(not Rules.root_valid(bad), "reject detached terminal root " + key, "NEGATIVE REPLAY")
	var bad_wait: Dictionary = frozen.duplicate(true)
	bad_wait.queue.dispositions.append(bad_wait.queue.dispositions[0].duplicate(true))
	check(not Rules.root_valid(bad_wait), "reject duplicate terminal WAIT_ACTION disposition", "NEGATIVE REPLAY")
	for field in frozen.outcome:
		var malformed: Dictionary = frozen.outcome.duplicate(true)
		malformed.erase(field)
		check(not C.valid("Outcome", malformed), "terminal schema missing " + field, "PURE SCHEMA")
	var wrong_reason: Dictionary = frozen.duplicate(true)
	wrong_reason.outcome.result = "PARTY_RETREAT"
	check(not Rules.root_valid(wrong_reason), "terminal result/roster mismatch rejected", "NEGATIVE REPLAY")
	var journal: Array = settled.journal.duplicate(true)
	journal.append(journal.back().duplicate(true))
	check(Rules.replay(settled.seed, settled.session, settled.generation, journal).is_empty(), "duplicate completion journal rejected", "NEGATIVE REPLAY")
	journal = settled.journal.duplicate(true)
	journal[-1].result_digest = "forged"
	check(Rules.replay(settled.seed, settled.session, settled.generation, journal).is_empty(), "tampered terminal result digest rejected", "NEGATIVE REPLAY")
	var stale_restart: Dictionary = request(owner, "RESTART", {"fixture_id": MAIN, "fixture_version": 1})
	stale_restart.identity.state_revision -= 1
	check(send(owner, stale_restart, "REJECTED").reason == "M405_STALE_REVISION",
		"stale terminal Restart preserves frozen root")
	terminal_owners.append(owner)
	tx(owner, "IMPACT", {"token": token}, "REJECTED")
	tx(owner, "CANCEL", {"token": token}, "REJECTED")
	roots[scenario + "-frozen"] = frozen
	roots[scenario] = settled

# Complete every terminal-specific scenario assertion before changing generation.
func verify_terminal_restart(owner: RefCounted) -> void:
	var before: Dictionary = owner.snapshot()
	var reply: Dictionary = tx(owner, "RESTART", {"fixture_id": MAIN, "fixture_version": 1})
	check(reply.reason == "M405_RESTARTED"
		and owner.snapshot() == Rules.initial(MAIN, before.session, before.generation + 1),
		"settled terminal Restart creates exact fresh generation")
	check(owner.restart_audit().back().root == before, "terminal history retained in audit")
	check(owner.read_presentation_events().size() == 1
		and owner.read_presentation_events()[0].kind == "RESET", "fresh generation projects RESET only")

func _victory() -> bool:
	var owner: RefCounted = boot()
	for round in range(1, 7):
		command(owner, "ATTACK", "enemy_a" if round <= 3 else "enemy_b")
		admit(owner)
		var token: Dictionary = lock(owner)
		if round == 6:
			check(owner.snapshot().enemies[1].hp == 2, "last Enemy starts HP2")
			terminal_settle(owner, token, "VICTORY")
		else:
			finish(owner, token)
			drain(owner)
			close_round(owner, round)
	return true

func _six_closes() -> bool:
	var owner: RefCounted = boot()
	for round in range(1, 7):
		command(owner)
		admit(owner)
		drain(owner, ["player", "enemy_a", "enemy_b"] if round == 1 else ["player"])
		close_round(owner, round)
		var r: Dictionary = owner.snapshot()
		if round < 3: check(r.party[3].episode.budget == (2 if round == 1 else 1), "DOWN grace then tick")
		else: check(r.party[3].life == "DEAD" and r.party[3].episode.budget == 0, "B0 DEAD retained")
		check(r.party[0].guard == null, "round Guard expires")
	var final: Dictionary = owner.snapshot()
	check(final.phase == "CLOSED" and final.outcome == null and final.diagnostic == "DEMO_LIMIT_REACHED", "six closes honest demo exhaustion")
	tx(owner, "ADMIT", {}, "REJECTED")
	tx(owner, "CLOSE_ROUND", {}, "REJECTED")
	roots[scenario] = final
	return true

func _last_party_down() -> bool:
	var owner: RefCounted = boot("m405-demo/b2-player-low", 2)
	var targets: Array = ["player", "npc_03", "npc_02", "npc_02", "npc_01", "npc_01"]
	var hit_hp: Array = [[0, 0], [0, 0], [4, 1], [0, 0], [7, 4], [1, 0]]
	var budgets: Array = [[2, -1, -1, -1], [1, -1, -1, 2], [0, -1, -1, 1], [0, -1, 2, 0], [0, -1, 1, 0]]
	var lives: Array = [["DOWN", "ALIVE", "ALIVE", "ALIVE"], ["DOWN", "ALIVE", "ALIVE", "DOWN"],
		["DEAD", "ALIVE", "ALIVE", "DOWN"], ["DEAD", "ALIVE", "DOWN", "DEAD"], ["DEAD", "ALIVE", "DOWN", "DEAD"]]
	for round in range(1, 7):
		if owner.read_view().command_ready: command(owner)
		admit(owner)
		check(owner.snapshot().declarations[0].target_id == targets[round - 1], "V2 exact declaration round " + str(round))
		for unused in range(6):
			var r: Dictionary = owner.snapshot()
			if r.queue.phase == "DRAINED": break
			var token: Dictionary = lock(owner)
			if token.is_empty(): continue
			if round == 6 and token.actor_id == "enemy_b":
				check(owner.snapshot().party[1].hp == 1 and owner.snapshot().party[2].episode.budget == 1, "last Party HP1, prior DOWN clock B1")
				terminal_settle(owner, token, "DEFEAT")
				break
			if token.actor_id in Catalog.ENEMIES:
				finish(owner, token)
				var target: Dictionary = Rules.actor(owner.snapshot(), targets[round - 1])
				check(target.hp == hit_hp[round - 1][0 if token.actor_id == "enemy_a" else 1], "independent expected HP after " + token.actor_id + " / round " + str(round))
				if target.hp == 0:
					check(target.life == "DOWN" and target.episode.active and target.episode.entry_round == round and target.episode.budget == 2, "actual DOWN episode and entry budget before close")
			else: tx(owner, "CANCEL", {"token": token})
		if round < 6:
			close_round(owner, round)
			var closed: Dictionary = owner.snapshot()
			for i in range(4):
				var p: Dictionary = closed.party[i]
				check(p.life == lives[round - 1][i], "independent life after close " + str(round) + "/" + p.actor_id)
				check((p.episode == null and budgets[round - 1][i] == -1) or (p.episode != null and p.episode.budget == budgets[round - 1][i]), "independent clock after close " + str(round) + "/" + p.actor_id)
	var final: Dictionary = owner.snapshot()
	check(final.party[1].hp == 0 and final.party[1].episode.entry_round == 6 and final.party[1].episode.budget == 2 and final.party[2].episode.budget == 1, "final DOWN episode never ticks terminal clocks")
	check(owner.snapshot().outcome.reason == "M403_NO_ACTIVE_PARTY", "last-Party DOWN reason")
	return true

func _rescue_retreat() -> bool:
	var owner: RefCounted = boot("m405-demo/player-down")
	admit(owner)
	check(lock(owner).is_empty(), "real unavailable Player disposition")
	var token: Dictionary = lock(owner)
	check(token.kind == "RESCUE" and token.target_id == "player", "independent NPC RESCUE")
	var episode: Dictionary = owner.snapshot().party[0].episode.duplicate(true)
	finish(owner, token)
	var r: Dictionary = owner.snapshot()
	check(r.party[0].hp == 1 and not r.party[0].episode.active and r.party[0].episode.episode_id == episode.episode_id and r.party[1].rescue_uses == 0 and r.party[1].help_uses == 1, "real HP1 / episode retirement / distinct resource")
	check(not owner.read_view().command_ready and r.queue.dispositions[0].kind == "UNAVAILABLE" and r.queue.dispositions[0].action_id == null, "rescue never restores consumed command slot")
	drain(owner)
	close_round(owner, 1)
	check(owner.read_view().command_ready, "selection resumes next prepared identity")
	tx(owner, "GUIDANCE", {"request": guidance_request(owner, "ATTACK")}, "ACCEPTED")
	command(owner); admit(owner)
	drain(owner, ["enemy_a", "enemy_b"])
	r = owner.snapshot()
	check(r.party[0].life == "DOWN" and r.party[0].episode.episode_id != episode.episode_id and r.party[0].episode.entry_order > episode.entry_order, "re-DOWN creates a new authentic ordered episode")
	check(r.guidance.active.guidance_type == "ATTACK" and r.guidance.guidance_revision == 1, "DOWN retains Frozen history without R1 increment")
	roots[scenario + "-rescue"] = r
	owner = boot("m405-demo/b2-player-low", 2)
	command(owner)
	admit(owner)
	finish(owner, lock(owner))
	finish(owner, lock(owner))
	finish(owner, lock(owner))
	token = lock(owner)
	check(token.kind == "RETREAT" and token.actor_id == "npc_03", "ordinary independent RETREAT")
	var forged: Dictionary = token.duplicate(true); forged.actor_id = "player"; forged.target_id = "player"
	tx(owner, "IMPACT", {"token": forged}, "REJECTED")
	finish(owner, token)
	r = owner.snapshot()
	check(r.party[3].participation == "RETREATED" and not r.party[3].eligible and r.party[3].hp == 3 and r.outcome == null, "actual nonterminal participation change, retained ID/HP")
	drain(owner, ["enemy_a", "enemy_b"])
	close_round(owner, 1)
	check(owner.snapshot().party[0].hp == 8, "actual guarded hits restore living HELP threshold")
	command(owner)
	admit(owner)
	finish(owner, lock(owner))
	token = lock(owner)
	check(token.kind != "HELP" and owner.snapshot().party[1].help_uses == 0, "later real NPC opportunity cannot repeat spent HELP")
	tx(owner, "CANCEL", {"token": token})
	drain(owner)
	roots[scenario + "-retreat"] = owner.snapshot()
	return true

func guidance_request(owner: RefCounted, kind: String, target: String = "") -> Dictionary:
	var v: Dictionary = owner.read_view()
	return {"schema_version": 1, "guidance_type": kind, "issuer_player_id": "player", "preferred_target_id": target,
		"encounter_id": v.identity.session, "generation": v.identity.generation, "round_id": v.identity.round_id,
		"expected_guidance_revision": v.guidance.guidance_revision}

func _guidance() -> bool:
	for kind in ["NONE", "ATTACK", "DEFEND", "HELP", "FOCUS_TARGET"]:
		var owner: RefCounted = boot()
		var inner: Dictionary = guidance_request(owner, kind, "enemy_b" if kind == "FOCUS_TARGET" else "")
		tx(owner, "GUIDANCE", {"request": inner}, "ACCEPTED")
		inner.expected_guidance_revision += 1
		tx(owner, "GUIDANCE", {"request": inner}, "ACCEPTED")
		check(owner.read_view().guidance.guidance_revision == 2, "identical content submit increments R1")
		var pending: Dictionary = owner.snapshot().guidance.pending.duplicate(true)
		tx(owner, "ADMIT", {}, "REJECTED")
		tx(owner, "COMMAND", {"actor_id": "npc_01", "action": "DEFEND", "target_id": "npc_01"}, "REJECTED")
		check(owner.snapshot().guidance.pending == pending, "failed admission/command preserve Pending")
		var stale: Dictionary = request(owner, "ADMIT")
		command(owner)
		check(not owner.read_view().command_ready and owner.read_view().has_accepted_fresh_command, "ready false, accepted fresh true")
		send(owner, stale, "REJECTED")
		check(owner.read_view().has_accepted_fresh_command, "rejected ADMIT preserves accepted command")
		admit(owner)
		check(owner.snapshot().guidance.active == pending and owner.snapshot().guidance.pending == null, "admission freezes exactly Pending")
		finish(owner, lock(owner))
		var token: Dictionary = lock(owner)
		var d: Dictionary = owner.read_view().decision
		if kind == "FOCUS_TARGET": check(d.guidance_relation.response == "FOLLOWED" and token.target_id == "enemy_b" and d.guidance_relation.behavior_changed, "causal FOLLOWED to B")
		if kind == "ATTACK": check(d.guidance_relation.response == "MATCHED_INDEPENDENTLY" and not d.guidance_relation.behavior_changed, "authentic independent ATTACK match")
		tx(owner, "CANCEL", {"token": token})
		token = lock(owner); tx(owner, "CANCEL", {"token": token})
		token = lock(owner)
		if kind == "ATTACK": check(owner.read_view().decision.guidance_relation.response == "REFUSED" and token.kind == "DEFEND", "safety refusal")
		tx(owner, "CANCEL", {"token": token})
		drain(owner)
		roots[scenario + "-" + kind] = owner.snapshot()
	var owner: RefCounted = boot("m405-demo/npc-down")
	tx(owner, "GUIDANCE", {"request": guidance_request(owner, "HELP")}, "ACCEPTED")
	command(owner); admit(owner)
	finish(owner, lock(owner)); lock(owner)
	var token: Dictionary = lock(owner)
	check(token.kind == "RESCUE" and owner.read_view().decision.guidance_relation.response == "NOT_APPLICABLE", "unsupported authentic DOWN: HELP is not RESCUE")
	tx(owner, "CANCEL", {"token": token})
	roots[scenario + "-unsupported"] = owner.snapshot()
	owner = boot()
	for field in ["encounter_id", "generation", "round_id", "issuer_player_id", "expected_guidance_revision", "preferred_target_id"]:
		var inner: Dictionary = guidance_request(owner, "FOCUS_TARGET", "enemy_a")
		if field in ["issuer_player_id", "preferred_target_id"]: inner[field] = "unknown_actor"
		else: inner[field] += 1
		check(tx(owner, "GUIDANCE", {"request": inner}, "REJECTED").reason == "M405_GUIDANCE_REJECTED", "inner v1 identity/member rejection " + field, "REJECTION")
	var adapter := InputAdapter.new(owner, input_cap)
	check(adapter.guidance("ui/adapter-guidance", guidance_request(owner, "NONE")).status == "ACCEPTED", "input adapter actual submit")
	check(adapter.command("ui/adapter-command", "DEFEND", "player").status == "ACCEPTED", "input adapter real Player command")
	var req: Dictionary = request(owner, "ADMIT")
	for field in ["queue", "revision", "session", "generation", "round", "capability"]:
		var bad: Dictionary = req.duplicate(true)
		match field:
			"queue": bad.queue_id = "foreign"
			"revision": bad.identity.state_revision -= 1
			"session": bad.identity.session += 1
			"generation": bad.identity.generation += 1
			"round": bad.identity.round_id += 1
		send(owner, bad, "REJECTED", RefCounted.new() if field == "capability" else driver)
	admit(owner)
	var saved: Dictionary = traces.back().request
	send(owner, saved, "REJECTED")
	var observation_owner: RefCounted = boot()
	command(observation_owner); admit(observation_owner); finish(observation_owner, lock(observation_owner))
	for field in ["resource", "profile", "frozen", "revision"]:
		var observation: Dictionary = observation_owner.read_observation()
		match field:
			"resource": observation.party[1].rescue_uses = 0
			"profile": observation.guidance.profiles[0].trust = "CAUTIOUS"
			"frozen": observation.guidance.active.guidance_type = "HELP"
			"revision": observation.source.owner_revision += 1
		check(tx(observation_owner, "DECIDE_LOCK", {"observation": observation}, "REJECTED").reason == "M405_INVALID_BINDING", "forged owned observation " + field, "REJECTION")
	return true

func _failed_close() -> bool:
	var owner: RefCounted = boot()
	command(owner); admit(owner); drain(owner)
	check(tx(owner, "CLOSE_ROUND", {}, "REJECTED").reason == "M405_NO_REAL_PROGRESS", "all-cancelled has no seal")
	owner = boot()
	command(owner); admit(owner); drain(owner, ["player"])
	var before: Dictionary = owner.snapshot()
	owner.inject_failure_before_close_commit(driver)
	check(tx(owner, "CLOSE_ROUND", {}, "REJECTED").reason == "M405_CLOSE_FAILED", "second publication failure")
	var held: Dictionary = owner.snapshot()
	check(held.phase == "SEALED" and held.revision == before.revision + 1 and held.closed_rounds == 0 and held.close.consumed == false, "E5 genuine SEALED retains reserved request, no tick")
	check(owner.close_failure_diagnostic().root == held, "read-only held diagnostics")
	check(tx(owner, "RESTART", {"fixture_id": MAIN, "fixture_version": 1}, "REJECTED").reason == "M405_SEALED_RESTART", "direct SEALED Restart blocked")
	tx(owner, "CLOSE_ROUND", {}, "REJECTED")
	var fresh: RefCounted = boot()
	check(fresh.snapshot().session != held.session and fresh.snapshot().revision == 0, "E5 separate fresh factory session")
	var old_token: Dictionary = held.actions[0].token
	tx(fresh, "COMPLETE", {"token": old_token}, "REJECTED")
	check(owner.snapshot() == held, "fresh construction never rewrites held owner")
	roots[scenario] = held
	return true

func _classifier() -> bool:
	var initial: Dictionary = Rules.initial(MAIN, 123)
	var cases: Array = [[1, 1, 0, "ACTIVE"], [1, 0, 0, "VICTORY"], [0, 1, 4, "PARTY_RETREAT"],
		[0, 0, 4, "PARTY_RETREAT"], [0, 1, 2, "MIXED_WITHDRAWAL"], [0, 0, 2, "MIXED_WITHDRAWAL"],
		[0, 0, 0, "DEFEAT"], [0, 1, 0, "DEFEAT"]]
	for row in cases:
		var data: Dictionary = initial.duplicate(true)
		for i in range(4):
			data.party[i].eligible = i < row[0]
			data.party[i].participation = "RETREATED" if i < row[2] else "PRESENT"
		for i in range(2): data.enemies[i].available = i < row[1]
		check(Rules.classify(data).result == row[3], "classifier precedence " + str(row), "PURE CLASSIFIER DATA ONLY")
	return true

func _guard_terminal() -> bool:
	var owner: RefCounted = boot()
	for round in range(1, 7):
		if round == 6:
			tx(owner, "GUIDANCE", {"request": guidance_request(owner, "ATTACK")}, "ACCEPTED")
			command(owner)
		else: command(owner, "ATTACK", "enemy_a" if round <= 3 else "enemy_b")
		admit(owner)
		finish(owner, lock(owner))
		if round == 5: finish(owner, lock(owner)) # B2 -> B1 through a real independent NPC hit.
		if round == 6:
			var token: Dictionary = lock(owner)
			check(owner.snapshot().party[0].guard != null and token.kind == "ATTACK", "terminal pre-root has actual Player Guard")
			terminal_settle(owner, token, "VICTORY")
			var effect: Dictionary = owner.snapshot().actions.back().effect
			check(effect.guards.size() == 1 and effect.guards[0].actor_id == "player" and effect.guards[0].cause == "TERMINAL", "terminal clears other actor Guard in causal effect")
			return true
		drain(owner)
		close_round(owner, round)
	return false
