extends SceneTree
const Owner = preload("res://scripts/m4/playable_encounter.gd")
const Rules = preload("res://scripts/m4/playable_rules.gd")
const C = preload("res://scripts/m4/playable_contract.gd")
# Diagnostic subclass corrupts only detached generated candidates before validation.
class PoisonOwner:
	extends "res://scripts/m4/playable_encounter.gd"
	var fault: String = ""

	func _candidate_valid(req: Dictionary, result: Dictionary) -> bool:
		if fault.is_empty(): return super._candidate_valid(req, result)
		var bad: Dictionary = result.duplicate(true)
		match fault:
			"outer_reason": bad.response.reason = "M405_TARGET_UNAVAILABLE"
			"nested_reason": bad.response.effect.reason = "M405_UNKNOWN"
			"stored_reason": bad.root.actions.back().effect.reason = "M405_UNKNOWN"
			"delta": bad.response.effect.hp_delta -= 1; bad.root.actions.back().effect.hp_delta -= 1
			"hp": bad.root.enemies[0].hp -= 1
			"resource": bad.root.party[1].help_uses = 0
			"receipt": bad.root.receipts.append({})
			"journal": bad.root.journal.back().result_digest = "forged"
			"revision": bad.root.revision += 1
			"outbound_token": bad.response.token.authorization_id = "forged/authorization"
			"outbound_receipt": bad.response.receipt.authorization_id = "forged/authorization"
		return super._candidate_valid(req, bad)

var factory = RefCounted.new()
var input_cap = RefCounted.new()
var driver = RefCounted.new()
var presenter = RefCounted.new()
var checks: Array = []
var history: Array = []
var sequence: int = 0
var failed: bool = false

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok:
		failed = true
		print("FAIL: " + label)

func request(e, operation: String, payload: Dictionary = {}, issuer: String = "DRIVER") -> Dictionary:
	sequence += 1
	var v: Dictionary = e.read_view()
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": v.identity, "queue_id": v.queue_id,
		"request_id": ("ui/" if issuer == "INPUT" else "driver/") + str(sequence), "issuer": issuer, "operation": operation, "payload": payload}

func call_tx(e, operation: String, payload: Dictionary = {}, issuer: String = "DRIVER") -> Dictionary:
	var before: Dictionary = e.snapshot()
	var req: Dictionary = request(e, operation, payload, issuer)
	var result: Dictionary = e.transact(req, input_cap if issuer == "INPUT" else driver)
	check(C.response_valid(operation, result), operation + " exact response")
	check(e.replay_matches(), operation + " replay equality")
	history.append({"request": req, "response": result, "before": before, "after": e.snapshot()})
	return result

func _initialize() -> void:
	var e = Owner.new(factory, input_cap, driver, presenter)
	var boot: Dictionary = e.bootstrap({"domain": "M4_PLAYABLE", "version": 1, "fixture_id": "m405-demo/main", "fixture_version": 1}, factory)
	check(boot.status == "CREATED", "catalog bootstrap")
	check(e.replay_matches(), "bootstrap replay")
	var root_before: Dictionary = e.snapshot()
	var reject: Dictionary = call_tx(e, "ADMIT")
	check(reject.reason == "M405_COMMAND_REQUIRED" and e.snapshot() == root_before, "eligible Player requires command with full-root equality")
	var command: Dictionary = call_tx(e, "COMMAND", {"actor_id": "player", "action": "ATTACK", "target_id": "enemy_a"}, "INPUT")
	check(command.status == "ACCEPTED" and command.view.has_accepted_fresh_command and not command.view.command_ready, "real accepted command freshness")
	var admitted: Dictionary = call_tx(e, "ADMIT")
	check(admitted.status == "APPLIED", "admission")
	if admitted.status == "APPLIED":
		for index in range(6):
			var s: Dictionary = Rules.slot(e.snapshot())
			var op: String = "PLAYER_LOCK" if index == 0 else ("DECIDE_LOCK" if index < 4 else "ENEMY_LOCK")
			var payload: Dictionary = {"observation": e.read_observation()} if op == "DECIDE_LOCK" else {"slot_id": s.slot_id}
			var locked: Dictionary = call_tx(e, op, payload)
			check(locked.status == "AUTHORIZED", "real slot lock " + str(index))
			if locked.status != "AUTHORIZED": break
			var token: Dictionary = locked.token
			if token.kind != "ATTACK":
				var cancelled: Dictionary = call_tx(e, "CANCEL", {"token": token})
				check(cancelled.status == "APPLIED" and cancelled.receipt == null, "cancel policy-selected non-Attack without fake receipt")
				continue
			var pre: Dictionary = e.snapshot()
			var impact: Dictionary = call_tx(e, "IMPACT", {"token": token})
			check(impact.status in ["APPLIED", "SKIPPED"], "real impact")
			if impact.status == "APPLIED": check(impact.effect.hp_delta == -Rules.damage(token.actor_id), "actual damage " + token.actor_id)
			var after: Dictionary = e.snapshot()
			var duplicate: Dictionary = call_tx(e, "IMPACT", {"token": token})
			check(duplicate.status == "REJECTED" and e.snapshot() == after, "duplicate impact full-root equality")
			var complete: Dictionary = call_tx(e, "COMPLETE", {"token": token})
			check(complete.status == "COMPLETED" and complete.receipt != null, "genuine completion receipt")
			check(pre.receipts.size() + 1 == e.snapshot().receipts.size(), "exactly one receipt")
	adversarial(e)
	if "--gate=DIAG" in OS.get_cmdline_user_args(): recovery05_diagnostics()
	if "--gate=D" in OS.get_cmdline_user_args():
		schema_recovery()
		recovery05_schema()
	if "--gate=E" in OS.get_cmdline_user_args():
		real_recovery()
		recovery05_runtime()
	var report: Dictionary = {"checks": checks, "history": history, "final_root": e.snapshot(), "status": "FAIL" if failed else "PASS", "coverage": "Recovery-05 " + str(OS.get_cmdline_user_args()) + "; schema fixtures and actual transactions separately labelled; B2-B5 NOT IMPLEMENTED"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f = FileAccess.open(arg.substr(9), FileAccess.WRITE)
			f.store_string(JSON.stringify(report, "\t"))
	print("B1 INITIAL PROOF: " + report.status + " checks=" + str(checks.size()))
	quit(1 if failed else 0)

func adversarial(e) -> void:
	var before: Dictionary = e.snapshot()
	var copied: Dictionary = e.snapshot()
	copied.party[0].hp = 1
	copied.guidance.profiles[0].trust = "CAUTIOUS"
	copied.receipts.clear()
	check(e.snapshot() == before, "nested detached snapshot has no ownership")
	var req: Dictionary = request(e, "ADVANCE")
	for field in ["session", "generation", "round_id", "state_revision"]:
		var mutated: Dictionary = req.duplicate(true)
		mutated.identity[field] += 1
		var response: Dictionary = e.transact(mutated, driver)
		check(response.status == "REJECTED" and e.snapshot() == before, "identity mismatch no mutation: " + field)
	for bad in [null, "", "wrong-queue"]:
		var mutated: Dictionary = req.duplicate(true)
		mutated.queue_id = bad
		var response: Dictionary = e.transact(mutated, driver)
		check(response.status == "REJECTED" and e.snapshot() == before, "queue mismatch no mutation: " + str(bad))
	var unauthorized: Dictionary = e.transact(req, RefCounted.new())
	check(unauthorized.reason == "M405_UNAUTHORIZED" and e.snapshot() == before, "serialized issuer does not grant capability")
	# Generated responses must obey the closed nested reason catalog (SC09).
	# Mutations are detached validation inputs, never imported into live authority.
	for item in history:
		if item.request.operation == "IMPACT" and item.response.status == "APPLIED":
			var response: Dictionary = item.response.duplicate(true)
			check(C.response_valid("IMPACT", response), "positive genuine IMPACT response validates")
			response.effect.reason = "M405_FORGED_UNKNOWN_REASON"
			var accepted: bool = C.response_valid("IMPACT", response)
			check(not accepted, "SC09 unknown nested Effect.reason must reject; actual accepted=" + str(accepted))
			history.append({"classification": "DETACHED SCHEMA ADVERSARIAL", "expected_valid": false, "actual_valid": accepted, "mutated_response": response})
			break

# Recovery-04: pure schema fixtures are never submitted as gameplay effects.
var schema_records: Dictionary = {}

func event_for(reply: Dictionary) -> Dictionary:
	return {"domain": "M4_PLAYABLE", "version": 1, "identity": reply.identity.duplicate(true),
		"event_id": "pure-schema/impact", "kind": "IMPACT", "token": null,
		"effect": reply.effect.duplicate(true), "receipt": null, "view": reply.view.duplicate(true)}

func nested_effect_checks(effect: Dictionary, original: Dictionary, expected: bool, label: String) -> void:
	check(C.valid("Effect", effect) == expected, "D pure Effect " + label)
	var reply: Dictionary = original.duplicate(true)
	reply.status = effect.status; reply.reason = effect.reason; reply.effect = effect.duplicate(true)
	check(C.response_valid("IMPACT", reply) == expected, "D pure IMPACT Response " + label)
	var event: Dictionary = event_for(reply)
	check(C.valid("PresentationEvent", event) == expected, "D pure PresentationEvent " + label)
	var grant: Dictionary = {"token": original.view.active_token.duplicate(true), "phase": effect.status,
		"effect": effect.duplicate(true), "impact_revision": original.identity.state_revision, "disposed_revision": null}
	check(C.valid("ActionGrant", grant) == expected, "D pure ActionGrant " + label)

func collect_records(spec: Variant, value: Variant) -> void:
	if typeof(spec) != TYPE_STRING: return
	if spec.begins_with("?"):
		if value != null: collect_records(spec.substr(1), value)
		return
	if spec.begins_with("[]"):
		for item in value: collect_records(spec.substr(2), item)
		return
	var schemas: Dictionary = C.schemas()
	if not schemas.has(spec): return
	if not schema_records.has(spec): schema_records[spec] = value.duplicate(true)
	for key in schemas[spec]:
		collect_records(C.payload_type(value.operation) if key == "payload" and value.has("operation") else schemas[spec][key], value[key])

func schema_recovery() -> void:
	var genuine: Dictionary = {}
	for item in history:
		if item.has("request") and item.request.operation == "IMPACT" and item.response.status == "APPLIED":
			genuine = item.duplicate(true)
			break
	check(not genuine.is_empty(), "D genuine APPLIED fixture exists")
	if genuine.is_empty(): return
	var original: Dictionary = genuine.response
	for status in ["APPLIED", "SKIPPED"]:
		for reason in C.SUCCESS.IMPACT[status]:
			var effect: Dictionary = original.effect.duplicate(true)
			effect.status = status; effect.reason = "M405_" + reason
			if status == "SKIPPED": effect.hp_delta = 0; effect.resources = []; effect.guards = []; effect.lifecycle = []
			nested_effect_checks(effect, original, true, status + "/" + reason)
			var wrong_pair: Dictionary = effect.duplicate(true)
			wrong_pair.status = "SKIPPED" if status == "APPLIED" else "APPLIED"
			nested_effect_checks(wrong_pair, original, false, "wrong status/" + reason)
	for reason in ["M405_ARBITRARY", "", null, 1, true, 1.0, [], {}, "M404_URGENT_RESCUE", "M403_CONTINUE", "ATTACK_AVAILABLE_ENEMY", "RESOURCE_UNAVAILABLE", "M405_ACTION_COMPLETED"]:
		var bad: Dictionary = original.effect.duplicate(true)
		bad.reason = reason
		nested_effect_checks(bad, original, false, "invalid reason=" + str(reason))
	for field in ["hp_delta", "resources", "guards", "lifecycle"]:
		var bad: Dictionary = original.effect.duplicate(true)
		bad.status = "SKIPPED"; bad.reason = "M405_TARGET_UNAVAILABLE"; bad.hp_delta = 0
		if field == "hp_delta": bad.hp_delta = -1
		elif field == "resources": bad.resources = [{"actor_id": "npc_01", "resource": "HELP", "before": 1, "after": 0}]
		elif field == "guards": bad.guards = [{"actor_id": "npc_01", "before": null, "after": {"actor_id": "npc_01", "grant_action_id": 1, "round_id": 1, "mode": "NEXT_ENEMY_HIT"}, "cause": "GRANT"}]
		else: bad.lifecycle = [{"actor_id": "npc_01", "before_life": "ALIVE", "after_life": "DOWN", "before_participation": "PRESENT", "after_participation": "PRESENT"}]
		nested_effect_checks(bad, original, false, "SKIPPED mutation/" + field)
	var mismatch: Dictionary = original.duplicate(true)
	mismatch.status = "SKIPPED"; mismatch.reason = "M405_TARGET_UNAVAILABLE"
	check(not C.response_valid("IMPACT", mismatch), "D outer/inner status mismatch")
	mismatch.effect.status = "SKIPPED"; mismatch.effect.reason = "M405_ACTOR_UNAVAILABLE"; mismatch.effect.hp_delta = 0
	check(not C.response_valid("IMPACT", mismatch), "D individually valid SKIPPED reasons must agree")
	for field in ["hp_delta", "target_id", "resources", "guards", "lifecycle"]:
		var result: Dictionary = {"root": genuine.after.duplicate(true), "response": original.duplicate(true)}
		if field == "hp_delta": result.response.effect.hp_delta -= 1
		elif field == "target_id": result.response.effect.target_id = "enemy_b"
		elif field == "resources": result.response.effect.resources = [{"actor_id": "npc_01", "resource": "HELP", "before": 1, "after": 0}]
		elif field == "guards": result.response.effect.guards = [{"actor_id": "npc_01", "before": null, "after": {"actor_id": "npc_01", "grant_action_id": 1, "round_id": 1, "mode": "NEXT_ENEMY_HIT"}, "cause": "GRANT"}]
		else: result.response.effect.lifecycle = [{"actor_id": "npc_01", "before_life": "ALIVE", "after_life": "DOWN", "before_participation": "PRESENT", "after_participation": "PRESENT"}]
		result.root.actions[0].effect = result.response.effect.duplicate(true)
		check(not Rules.candidate_valid(genuine.before, genuine.request, result), "D valid reason cannot authorize forged projection/" + field)
		check(not Rules.root_valid(result.root), "D full root replay rejects forged stored Effect/" + field)
	var all_replies: Array = history.duplicate(true)
	for item in all_replies:
		if not item.has("request"): continue
		collect_records("Request", item.request); collect_records("Response", item.response)
		collect_records("Root", item.before); collect_records("Root", item.after)
	collect_records("PresentationEvent", event_for(original))
	collect_records("ResourceChange", {"actor_id": "npc_01", "resource": "HELP", "before": 1, "after": 0})
	collect_records("GuardChange", {"actor_id": "npc_01", "before": null, "after": {"actor_id": "npc_01", "grant_action_id": 1, "round_id": 1, "mode": "NEXT_ENEMY_HIT"}, "cause": "GRANT"})
	for name in schema_records:
		var sample: Dictionary = schema_records[name]
		check(C.valid(name, sample), "D positive exact record/" + name)
		var extra: Dictionary = sample.duplicate(true); extra.unapproved = true
		check(not C.valid(name, extra), "D extra field/" + name)
		for field in sample:
			var missing: Dictionary = sample.duplicate(true); missing.erase(field)
			check(not C.valid(name, missing), "D missing/" + name + "/" + field)
			var malformed: Dictionary = sample.duplicate(true)
			malformed[field] = 0.5 if typeof(sample[field]) == TYPE_INT else (123 if typeof(sample[field]) == TYPE_ARRAY else [])
			check(not C.valid(name, malformed), "D wrong type/" + name + "/" + field)
			if typeof(sample[field]) == TYPE_INT:
				malformed[field] = true
				check(not C.valid(name, malformed), "D bool-as-int/" + name + "/" + field)
	history.append({"classification": "PURE SCHEMA ONLY", "records_exercised": schema_records.keys(), "six_pairs": "schema membership only; no B2-B5 effect producer claimed", "presentation": "detached fixture only; B4 emitter not implemented"})

func real_recovery() -> void:
	var applied: int = 0
	var skipped: int = 0
	var complete: int = 0
	for item in history.duplicate(true):
		if not item.has("request"): continue
		check(Rules.root_valid(item.before) and Rules.root_valid(item.after), "E every actual transaction full-root replay")
		if item.response.status == "REJECTED":
			check(item.before == item.after and item.response.effect == null and item.response.receipt == null, "E rejected full root/journal unchanged")
		if item.request.operation == "IMPACT" and item.response.status != "REJECTED":
			check(Rules.impact_projection_valid(item.before, item.after, item.request, item.response), "E authorized IMPACT actual projection")
			check(item.before.receipts == item.after.receipts and item.response.receipt == null, "E no receipt at IMPACT")
			applied += int(item.response.status == "APPLIED"); skipped += int(item.response.status == "SKIPPED")
		if item.request.operation == "COMPLETE":
			complete += 1
			check(item.response.reason == "M405_ACTION_COMPLETED" and item.response.effect == null, "E COMPLETE keeps its own reason")
			check(item.before.actions[item.request.payload.token.action_id - 1].effect == item.after.actions[item.request.payload.token.action_id - 1].effect, "E COMPLETE preserves exact stored effect")
			check(item.response.receipt.effect_status == item.before.actions[item.request.payload.token.action_id - 1].effect.status, "E receipt binds actual impact status")
	check(applied > 0 and skipped > 0 and complete == applied + skipped, "E real APPLIED and target-unavailable SKIPPED each completed once")
	var e = PoisonOwner.new(factory, input_cap, driver, presenter)
	var boot_req: Dictionary = {"domain": "M4_PLAYABLE", "version": 1, "fixture_id": "m405-demo/main", "fixture_version": 1}
	for bad in [null, {}, {"domain": "M4_PLAYABLE", "version": true, "fixture_id": "m405-demo/main", "fixture_version": 1}]:
		var result: Dictionary = e.bootstrap(bad, factory)
		check(result.status == "REJECTED" and e.snapshot().is_empty(), "E invalid bootstrap no publication")
	check(e.bootstrap(boot_req, RefCounted.new()).status == "REJECTED" and e.snapshot().is_empty(), "E factory capability required")
	check(e.bootstrap(boot_req, factory).status == "CREATED", "E real factory bootstrap")
	var initial_root: Dictionary = e.snapshot()
	check(e.bootstrap(boot_req, factory).status == "REJECTED" and e.snapshot() == initial_root, "E duplicate bootstrap rejects")
	call_tx(e, "COMMAND", {"actor_id": "player", "action": "ATTACK", "target_id": "enemy_a"}, "INPUT")
	var accepted: Dictionary = history.back().request.duplicate(true)
	var after_command: Dictionary = e.snapshot()
	check(e.transact(accepted, input_cap).reason == "M405_DUPLICATE_REQUEST" and e.snapshot() == after_command, "E actual duplicate request full-root equality")
	call_tx(e, "ADMIT")
	var lock: Dictionary = call_tx(e, "PLAYER_LOCK", {"slot_id": Rules.slot(e.snapshot()).slot_id})
	var token: Dictionary = lock.token
	var before: Dictionary = e.snapshot()
	for key in token:
		var forged: Dictionary = token.duplicate(true)
		if typeof(token[key]) == TYPE_INT: forged[key] += 1
		elif typeof(token[key]) == TYPE_STRING: forged[key] += "/forged"
		elif key == "identity": forged.identity.generation += 1
		else: forged[key] = "forged"
		var result: Dictionary = e.transact(request(e, "IMPACT", {"token": forged}), presenter)
		# A PRESENTER envelope is used below; this DRIVER mismatch also proves capabilities.
		check(result.status == "REJECTED" and e.snapshot() == before, "E mismatched capability no mutation/" + key)
		result = e.transact(request(e, "IMPACT", {"token": forged}), driver)
		check(result.status == "REJECTED" and e.snapshot() == before, "E forged token full equality/" + key)
	for fault_name in ["outer_reason", "nested_reason", "stored_reason", "delta", "hp", "resource", "receipt", "journal", "revision"]:
		e.fault = fault_name
		var result: Dictionary = call_tx(e, "IMPACT", {"token": token})
		check(result.reason == "M405_INVALID_CANDIDATE" and e.snapshot() == before, "E diagnostic candidate poison atomically rejected/" + fault_name)
		e.fault = ""
	check(e.inject_failure_before_publication(driver), "E arm authorized publication fault")
	var failed_publish: Dictionary = call_tx(e, "IMPACT", {"token": token})
	check(failed_publish.reason == "M405_INVALID_CANDIDATE" and e.snapshot() == before, "E final seam fault preserves full root")
	var req: Dictionary = request(e, "IMPACT", {"token": token}, "PRESENTER")
	var impact: Dictionary = e.transact(req, presenter)
	check(impact.status == "APPLIED" and e.replay_matches(), "E genuine presenter token executes once after faults")
	history.append({"classification": "ACTUAL AUTHORIZED OPERATION", "request": req, "response": impact, "before": before, "after": e.snapshot()})
	call_tx(e, "COMPLETE", {"token": token})
	var completed: Dictionary = e.snapshot()
	var duplicate: Dictionary = call_tx(e, "COMPLETE", {"token": token})
	check(duplicate.status == "REJECTED" and e.snapshot() == completed, "E duplicate COMPLETE no second receipt")
	for field in completed:
		var bad_root: Dictionary = completed.duplicate(true)
		if typeof(bad_root[field]) == TYPE_ARRAY: bad_root[field].append({"forged": true})
		elif typeof(bad_root[field]) == TYPE_DICTIONARY: bad_root[field].forged = true
		elif typeof(bad_root[field]) == TYPE_INT: bad_root[field] += 1
		else: bad_root[field] = "forged"
		check(not Rules.root_valid(bad_root) and e.snapshot() == completed, "E detached root mutation rejects/" + field)
	for index in range(completed.journal.size()):
		var bad_journal: Array = completed.journal.duplicate(true)
		bad_journal[index].result_digest = "forged"
		check(Rules.replay(completed.seed, completed.session, completed.generation, bad_journal).is_empty(), "E authenticated replay digest mutation/" + str(index))
	var foreign = Owner.new(factory, input_cap, driver, presenter)
	check(foreign.bootstrap(boot_req, factory).status == "CREATED", "E distinct real session")
	var foreign_before: Dictionary = foreign.snapshot()
	check(foreign.transact(request(e, "IMPACT", {"token": token}), driver).reason == "M405_FOREIGN_SESSION" and foreign.snapshot() == foreign_before, "E foreign-session callback rejected")
	history.append({"classification": "B1 LIMITATIONS", "not_implemented": ["B2 HELP/Guard effects", "B3 rounds/Guidance integration", "B4 Restart/terminal/presentation", "B5 playable scene"], "skipped_runtime": "TARGET_UNAVAILABLE only; other four pairs schema-only", "faults": "detached generated candidates only; no live root mutation or O7 producer"})


func recovery05_diagnostics() -> void:
	for value in [2, 999]:
		check(not C.valid("Bootstrap", {"domain": "M4_PLAYABLE", "version": 1, "fixture_id": "m405-demo/main", "fixture_version": value}), "R05 Bootstrap unsupported fixture version rejects/" + str(value))
		check(not C.valid("RestartPayload", {"fixture_id": "m405-demo/main", "fixture_version": value}), "R05 RestartPayload unsupported fixture version rejects/" + str(value))
	for item in history:
		if not item.has("request") or item.request.operation != "COMPLETE": continue
		var result: Dictionary = {"root": item.after.duplicate(true), "response": item.response.duplicate(true)}
		result.response.receipt.authorization_id = "forged/authorization"
		check(not Rules.candidate_valid(item.before, item.request, result), "R05 forged outbound COMPLETE receipt rejects before publication")
		break

# Recovery-05 coverage closure. Generated records prove schema shape only;
# actual authority, legality and provenance are separately exercised by the owner.
func schema_sample(spec: Variant) -> Variant:
	if typeof(spec) == TYPE_ARRAY: return spec[0]
	if typeof(spec) == TYPE_DICTIONARY:
		var record: Dictionary = {}
		for key in spec:
			record[key] = schema_sample(C.payload_type(record.operation)) if key == "payload" else schema_sample(spec[key])
		return record
	if spec.begins_with("?"): return null
	if spec.begins_with("[]"): return []
	if schema_records.has(spec): return schema_records[spec].duplicate(true)
	match spec:
		"S", "Z": return "schema/value"
		"positive", "session": return 1
		"int", "nonneg", "bit": return 0
		"bool": return false
		"Kind": return "ATTACK"
		"GuidanceRequest": return {"schema_version": 1, "guidance_type": "NONE", "issuer_player_id": "player", "preferred_target_id": "", "encounter_id": 1, "generation": 1, "round_id": 1, "expected_guidance_revision": 0}
		"Profile": return Rules.Catalog.content().profiles[0].duplicate(true)
		"FrozenRecord": return {"guidance_type": "NONE", "issuer_player_id": "player", "preferred_target_id": "", "encounter_id": 1, "generation": 1, "round_id": 1, "guidance_revision": 0}
	var result: Dictionary = schema_sample(C.schemas()[spec])
	match spec:
		"Bootstrap": result.fixture_id = "m405-demo/main"
		"BootstrapReply": result.reason = "M405_CREATED"; result.view = schema_sample("View")
		"RestartPayload": result.fixture_id = "m405-demo/main"
		"Receipt": result.completion_revision = result.impact_revision + 1
		"InternalClose":
			result.origin.operation = "CLOSE_ROUND"; result.origin.payload = {}
	return result

func recovery05_schema() -> void:
	recovery05_diagnostics()
	for item in history:
		if item.has("request") and item.request.operation == "DECIDE_LOCK":
			collect_records("Decision", Rules.Adapter.decide(item.request.payload.observation))
			break
	for name in C.schemas():
		if not schema_records.has(name): collect_records(name, schema_sample(name))
	for name in ["GuidanceRequest", "FrozenRecord", "Profile"]: schema_records[name] = schema_sample(name)
	for name in schema_records:
		var value: Dictionary = schema_records[name]
		check(C.valid(name, value), "R05 schema closure positive/" + name)
		var extra: Dictionary = value.duplicate(true); extra.forged_extra = 1
		check(not C.valid(name, extra), "R05 schema closure extra/" + name)
		for field in value:
			var missing: Dictionary = value.duplicate(true); missing.erase(field)
			check(not C.valid(name, missing), "R05 schema closure missing/" + name + "/" + field)
			var bad: Dictionary = value.duplicate(true)
			bad[field] = 0.5 if typeof(value[field]) == TYPE_INT else (123 if typeof(value[field]) == TYPE_ARRAY else [])
			check(not C.valid(name, bad), "R05 schema closure wrong type/" + name + "/" + field)
			if typeof(value[field]) == TYPE_INT:
				bad[field] = true
				check(not C.valid(name, bad), "R05 schema closure bool/int/" + name + "/" + field)
			var spec: Variant = C.schemas().get(name, {}).get(field)
			if typeof(spec) == TYPE_ARRAY:
				bad[field] = "UNKNOWN_ENUM" if typeof(value[field]) == TYPE_STRING else 999
				check(not C.valid(name, bad), "R05 closed enum/" + name + "/" + field)
	for version in [0, -1, 2, 999, true, 1.0, "1", null]:
		for name in ["Bootstrap", "RestartPayload", "SeedReference"]:
			var bad: Dictionary = schema_records[name].duplicate(true); bad.fixture_version = version
			check(not C.valid(name, bad), "R05 fixture version exact1/" + name + "/" + str(version))
	for item in history:
		if not item.has("request") or item.request.operation not in ["PLAYER_LOCK", "IMPACT", "COMPLETE"] or item.response.status == "REJECTED": continue
		for field in item.response:
			var result: Dictionary = {"root": item.after.duplicate(true), "response": item.response.duplicate(true)}
			if typeof(result.response[field]) == TYPE_DICTIONARY: result.response[field].forged = true
			elif typeof(result.response[field]) == TYPE_INT: result.response[field] += 1
			else: result.response[field] = "forged"
			check(not Rules.candidate_valid(item.before, item.request, result), "R05 outbound reply fully bound/" + item.request.operation + "/" + field)
	var complete_records: Array = C.schemas().keys()
	complete_records.append_array(["GuidanceRequest", "FrozenRecord", "Profile"])
	history.append({"classification": "PURE SCHEMA CLOSURE", "record_names": complete_records, "record_count": complete_records.size(), "every_required_key": "positive/missing/extra/wrong-type; bool-as-int and closed enum where applicable", "deferred_runtime": "B2-B5 records are typed fixtures only, never live operations/imports"})

func recovery05_runtime() -> void:
	var boot: Dictionary = {"domain": "M4_PLAYABLE", "version": 1, "fixture_id": "m405-demo/main", "fixture_version": 1}
	for version in [0, -1, 2, 999, true, 1.0, "1", null]:
		var e = Owner.new(factory, input_cap, driver, presenter)
		var bad: Dictionary = boot.duplicate(true); bad.fixture_version = version
		var result: Dictionary = e.bootstrap(bad, factory)
		check(result.reason == "M405_INVALID_SCHEMA" and C.valid("BootstrapReply", result) and e.snapshot().is_empty(), "R05 invalid bootstrap version no publication/" + str(version))
	var e = PoisonOwner.new(factory, input_cap, driver, presenter)
	check(e.bootstrap(boot, factory).status == "CREATED", "R05 diagnostic owner bootstrap")
	var before: Dictionary = e.snapshot()
	var ready_command: Dictionary = request(e, "COMMAND", {"actor_id": "player", "action": "ATTACK", "target_id": "enemy_a"}, "INPUT")
	for field in ready_command:
		var bad: Dictionary = ready_command.duplicate(true); bad.erase(field)
		var result: Dictionary = e.transact(bad, input_cap)
		check(result.reason == "M405_INVALID_SCHEMA" and e.snapshot() == before, "R05 malformed transaction envelope no publication/" + field)
	for version in [2, true, 1.0, null]:
		var result: Dictionary = call_tx(e, "RESTART", {"fixture_id": "m405-demo/main", "fixture_version": version}, "INPUT")
		check(result.reason == "M405_INVALID_SCHEMA" and e.snapshot() == before, "R05 invalid nested restart version rejects before deferred lifecycle")
	call_tx(e, "COMMAND", ready_command.payload, "INPUT")
	call_tx(e, "ADMIT")
	var ready_before: Dictionary = e.snapshot()
	check(call_tx(e, "ADVANCE").status == "READY" and e.snapshot() == ready_before, "R05 READY is read only; no journal reservation")
	e.fault = "outbound_token"
	var rejected: Dictionary = call_tx(e, "PLAYER_LOCK", {"slot_id": Rules.slot(e.snapshot()).slot_id})
	check(rejected.reason == "M405_INVALID_CANDIDATE" and e.snapshot() == ready_before, "R05 generated fake token rejected atomically")
	e.fault = ""
	var lock: Dictionary = call_tx(e, "PLAYER_LOCK", {"slot_id": Rules.slot(e.snapshot()).slot_id})
	var token: Dictionary = lock.token
	before = e.snapshot()
	check(call_tx(e, "COMPLETE", {"token": token}).status == "REJECTED" and e.snapshot() == before, "R05 no COMPLETE receipt before IMPACT")
	call_tx(e, "IMPACT", {"token": token})
	before = e.snapshot()
	e.fault = "outbound_receipt"
	rejected = call_tx(e, "COMPLETE", {"token": token})
	check(rejected.reason == "M405_INVALID_CANDIDATE" and e.snapshot() == before, "R05 generated fake receipt rejected atomically")
	e.fault = ""
	check(call_tx(e, "COMPLETE", {"token": token}).status == "COMPLETED", "R05 retry after rejected fake receipt issues genuine receipt once")
	var observation: Dictionary = e.read_observation()
	before = e.snapshot()
	for mode in ["profile", "hp", "help", "source", "revision", "slot", "extra"]:
		var forged: Dictionary = observation.duplicate(true)
		match mode:
			"profile": forged.guidance.profiles[0].trust = "CAUTIOUS"
			"hp": forged.party[0].hp -= 1
			"help": forged.party[1].help_uses = 0
			"source": forged.source.owner_id = "forged-owner"
			"revision": forged.identity.state_revision += 1
			"slot": forged.slot.actor_id = "npc_02"
			"extra": forged.source.extra = true
		var result: Dictionary = call_tx(e, "DECIDE_LOCK", {"observation": forged})
		check(result.status == "REJECTED" and e.snapshot() == before, "R05 forged/mixed observation cannot select NPC action/" + mode)
	check(call_tx(e, "DECIDE_LOCK", {"observation": observation}).status == "AUTHORIZED", "R05 exact owner observation independently locks NPC decision")
	for fixture in Rules.Catalog.FIXTURES:
		var fresh_owner = Owner.new(factory, input_cap, driver, presenter)
		var bootstrap: Dictionary = boot.duplicate(true); bootstrap.fixture_id = "m405-demo/" + fixture
		var result: Dictionary = fresh_owner.bootstrap(bootstrap, factory)
		check(result.status == "CREATED" and C.valid("BootstrapReply", result) and fresh_owner.replay_matches(), "R05 genuine immutable fixture/" + fixture)
		check(fresh_owner.snapshot().receipts.is_empty(), "R05 bootstrap never invents receipts/" + fixture)
		if fixture in ["victory", "defeat"]:
			var admitted: Dictionary = call_tx(fresh_owner, "ADMIT")
			check(admitted.status == "STOPPED" and fresh_owner.snapshot().receipts.is_empty() and fresh_owner.snapshot().queue == null, "R05 seeded terminal admission only, no fake action receipt/" + fixture)
