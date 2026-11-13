extends "res://tests/actors/m4_05_playable_lifecycle_proof.gd"

const Presentation = preload("res://scripts/m4/playable_presentation_projection.gd")
const RESET_PAYLOAD = {"fixture_id": "m405-demo/b2-player-low", "fixture_version": 2}
var owners: Array[RefCounted] = []
var event_traces: Array = []
var terminal_mid: bool = false
var feedback: Dictionary = {}

func _initialize() -> void:
	for test in ["restart_phases", "six_closes", "victory", "last_party_down", "rescue_retreat", "e5_exit"]:
		scenario = test
		print("B4 START ", test)
		check(call("_" + test) == true, "scenario reached its end")
		for owner in owners:
			verify_stream(owner)
		owners.clear()
	for kind in ["SKIPPED", "DOWN", "DEAD", "RESCUE", "RETREAT", "Guard", "GRACE", "TICK", "BLED_OUT"]:
		check(feedback.has(kind), "observed real projected feedback " + kind)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var output := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if output == null:
				quit(1)
				return
			# Write canonical audit JSON with full integer precision.
			output.store_string(Catalog.canonical({"checks": checks, "traces": traces, "events": event_traces}))
	print("B4 EVENT PROOF: checks=%d failures=%d transactions=%d streams=%d" % [
		checks.size(), failures, traces.size(), event_traces.size()])
	quit(int(failures > 0))

func boot(id: String = MAIN, version: int = 1) -> RefCounted:
	var owner: RefCounted = super.boot(id, version)
	owners.append(owner)
	return owner

func verify_stream(owner: RefCounted) -> void:
	var root: Dictionary = owner.snapshot()
	var events: Array = owner.read_presentation_events()
	var expected: Array = []
	var audit: Array = owner.restart_audit()
	if not audit.is_empty():
		expected.append("RESET")
	var terminal_count: int = 0
	for row in root.journal:
		match row.operation:
			"PLAYER_LOCK", "ENEMY_LOCK", "DECIDE_LOCK": expected.append("INTENT")
			"IMPACT": expected.append("IMPACT")
			"COMPLETE": expected.append("COMPLETION")
			"COMMIT_CLOSE": expected.append("ROUND_CLOSED")
		if root.outcome != null and root.outcome.freeze_revision == row.post_revision:
			expected.append("TERMINAL")
			terminal_count += 1
	var kinds: Array = []
	var ids: Dictionary = {}
	for event in events:
		var kind: String = event.kind
		var revision: int = event.identity.state_revision
		kinds.append(kind)
		check(C.valid("PresentationEvent", event), "exact schema " + kind)
		check(not ids.has(event.event_id), "unique deterministic event ID " + kind)
		ids[event.event_id] = true
		check(event.event_id == "m405/%d/%d/presentation/%d/%s" % [
			root.session, root.generation, revision, kind], "identity and event ID " + kind)
		if kind == "RESET":
			check(revision == 0 and event.token == null and event.view.boundary_changes == null, "fresh RESET payload")
			continue
		var entry: Dictionary = root.journal[revision - 1]
		check(entry.post_revision == revision, "committed event revision")
		if kind in ["INTENT", "IMPACT", "COMPLETION"]:
			var grant: Dictionary = root.actions[event.token.action_id - 1]
			check(event.token == grant.token, "authentic action token")
			if kind == "IMPACT":
				check(event.effect == grant.effect and event.receipt == null, "exact stored APPLIED or SKIPPED effect")
				if event.effect.status == "SKIPPED":
					feedback["SKIPPED"] = true
					check(event.effect.hp_delta == 0 and event.effect.resources.is_empty(), "skip carries no successful hit or heal")
				for change in event.effect.lifecycle:
					feedback[change.after_life] = true
					if change.after_participation == "RETREATED":
						feedback["RETREAT"] = true
				for change in event.effect.resources:
					feedback[change.resource] = true
				if not event.effect.guards.is_empty():
					feedback["Guard"] = true
			elif kind == "COMPLETION":
				check(event.receipt in root.receipts and event.receipt.completion_revision == revision, "actual causal receipt")
		elif kind == "ROUND_CLOSED":
			var close: Dictionary = root.round_history[entry.internal.event.round_id - 1].close
			check(event.view.boundary_changes == close.changes and event.token == null, "committed clock, Guard and lifecycle payload")
			check(event.identity.round_id == mini(6, entry.internal.event.round_id + 1), "post-close identity")
			for change in event.view.boundary_changes.lifecycle:
				feedback[change.after_life] = true
			for change in event.view.boundary_changes.clocks:
				feedback[change.reason] = true
		elif kind == "TERMINAL":
			var token: Variant = entry.request.payload.token if entry.operation == "IMPACT" else null
			check(event.view.outcome == root.outcome and event.token == token, "frozen Outcome and actual causal token")
	check(kinds == expected and terminal_count <= 1, "exact event sequence")
	check(owner.snapshot() == root and owner.read_presentation_events() == events, "deterministic read-only replay")
	event_traces.append({"scenario": scenario, "events": events, "restart_audit": audit})
	if not events.is_empty():
		events[0].view.party[0].hp = -1
		check(owner.read_presentation_events()[0].view.party[0].hp >= 0, "nested event is detached")

func restart(owner: RefCounted) -> void:
	var before: Dictionary = owner.snapshot()
	var req: Dictionary = request(owner, "RESTART", RESET_PAYLOAD)
	var incorrect: Dictionary = req.duplicate(true)
	incorrect.queue_id = null if req.queue_id != null else "wrong"
	check(send(owner, incorrect, "REJECTED").reason == "M405_WRONG_QUEUE", "reject wrong nullable queue")
	var reply: Dictionary = send(owner, req, "APPLIED")
	var after: Dictionary = owner.snapshot()
	check(reply.reason == "M405_RESTARTED" and reply.view == owner.read_view(), "actual Restart View")
	check(after == Rules.initial(RESET_PAYLOAD.fixture_id, before.session, before.generation + 1, 2), "whole new generation equals catalog initial")
	var audit: Array = owner.restart_audit()
	check(audit.back().root == before and audit.back().request == req, "old generation detached audit")
	audit.back().root.party[0].hp = -1
	check(owner.restart_audit().back().root == before, "audit mutation does not reach owner")
	check(send(owner, req, "REJECTED").reason == "M405_STALE_GENERATION", "old Restart request rejected")
	verify_stream(owner)

func _restart_phases() -> bool:
	var owner: RefCounted = boot()
	var req: Dictionary = request(owner, "RESTART", RESET_PAYLOAD)
	var rejections := {"session": "FOREIGN_SESSION", "generation": "STALE_GENERATION",
		"round_id": "WRONG_ROUND", "state_revision": "STALE_REVISION"}
	for field in rejections:
		var bad: Dictionary = req.duplicate(true)
		bad.identity[field] += 1
		check(send(owner, bad, "REJECTED").reason == "M405_" + rejections[field], "Restart rejects wrong " + field)
	check(send(owner, req, "REJECTED", RefCounted.new()).reason == "M405_UNAUTHORIZED", "foreign capability")
	check(tx(owner, "RESTART", {"fixture_id": "missing", "fixture_version": 1}, "REJECTED").reason == "M405_UNKNOWN_FIXTURE", "unknown fixture")
	restart(owner)
	var initial: Dictionary = owner.snapshot()
	var adapter := InputAdapter.new(owner, input_cap)
	check(adapter.restart("ui/b4-input-restart", MAIN, 1).reason == "M405_RESTARTED", "real INPUT capability restarts")
	check(owner.snapshot() == Rules.initial(MAIN, initial.session, initial.generation + 1), "second Restart resets from V1 seed")
	check(owner.restart_audit().size() == 2, "both previous generations retained only in audit")
	var seeded: RefCounted = boot("m405-demo/victory")
	tx(seeded, "ADMIT", {}, "STOPPED")
	verify_stream(seeded)
	restart(seeded)
	for impact_first in [false, true]:
		owner = boot()
		command(owner); admit(owner)
		var token: Dictionary = lock(owner)
		var callbacks := Presentation.Callbacks.new()
		callbacks.attach(owner, presenter)
		var hit: Callable = callbacks.bind(token, "IMPACT", "driver/b4-hit")
		var completion: Callable = callbacks.bind(token, "COMPLETE", "driver/b4-complete")
		owner.inject_failure_before_publication(driver)
		check(tx(owner, "RESTART", RESET_PAYLOAD, "REJECTED").reason == "M405_INVALID_CANDIDATE", "Restart fault leaves pending action")
		if impact_first:
			check(hit.call().status == "APPLIED", "pending callback survives failed Restart")
			var applied: Dictionary = owner.snapshot()
			check(hit.call().status == "REJECTED" and owner.snapshot() == applied, "duplicate hit leaves effect committed")
		verify_stream(owner)
		restart(owner)
		command(owner); admit(owner); lock(owner)
		var new_root: Dictionary = owner.snapshot()
		check(hit.call().is_empty() and completion.call().is_empty() and owner.snapshot() == new_root, "old callbacks cannot mutate new queue")
		check(tx(owner, "COMPLETE", {"token": token}, "REJECTED").reason == "M405_INVALID_TOKEN", "old token with current request rejected")
	return true

func close_round(owner: RefCounted, number: int) -> void:
	super.close_round(owner, number)
	if number == 6:
		verify_stream(owner)

func terminal_settle(owner: RefCounted, token: Dictionary, outcome: String) -> void:
	var before: Dictionary = owner.snapshot()
	owner.inject_failure_before_publication(driver)
	tx(owner, "IMPACT", {"token": token}, "REJECTED")
	check(owner.snapshot() == before, "terminal IMPACT failure leaves lock")
	tx(owner, "IMPACT", {"token": token})
	var frozen: Dictionary = owner.snapshot()
	var events: Array = owner.read_presentation_events()
	check(frozen.outcome.result == outcome and events[-2].kind == "IMPACT" and events[-1].kind == "TERMINAL"
		and events[-2].identity == events[-1].identity, "terminal emitted at impact before completion")
	verify_stream(owner)
	if terminal_mid:
		restart(owner)
		return
	var callbacks := Presentation.Callbacks.new()
	callbacks.attach(owner, presenter)
	var done: Callable = callbacks.bind(token, "COMPLETE", "driver/b4-causal-complete")
	check(done.call().status == "COMPLETED", "causal callback succeeds")
	var settled: Dictionary = owner.snapshot()
	check(done.call().status == "REJECTED" and owner.snapshot() == settled, "duplicate completion cannot issue second receipt")
	check(settled.outcome == frozen.outcome and settled.receipts.size() == frozen.receipts.size() + 1, "frozen outcome and one receipt")
	verify_stream(owner)

func _victory() -> bool:
	for interrupt in [false, true]:
		terminal_mid = interrupt
		super._victory()
		if not interrupt:
			restart(owners.back())
	terminal_mid = false
	return true

func _six_closes() -> bool:
	var result: bool = super._six_closes()
	restart(owners.back())
	return result

func _e5_exit() -> bool:
	var held: RefCounted = boot()
	command(held); admit(held)
	var token: Dictionary = lock(held)
	var callbacks := Presentation.Callbacks.new()
	callbacks.attach(held, presenter)
	var late: Callable = callbacks.bind(token, "COMPLETE", "driver/late-e5")
	finish(held, token); drain(held)
	held.inject_failure_before_close_commit(driver)
	check(tx(held, "CLOSE_ROUND", {}, "REJECTED").reason == "M405_CLOSE_FAILED", "genuine failed COMMIT_CLOSE")
	var root: Dictionary = held.snapshot()
	var diagnostic: Dictionary = held.close_failure_diagnostic()
	check(root.phase == "SEALED" and diagnostic.root == root, "SEALED witness and diagnostic retained")
	check(tx(held, "RESTART", RESET_PAYLOAD, "REJECTED").reason == "M405_SEALED_RESTART", "SEALED Restart rejected")
	callbacks.detach()
	var rejected := Owner.new(factory, input_cap, driver, presenter)
	var boot_request: Dictionary = {"domain": "M4_PLAYABLE", "version": 1, "fixture_id": MAIN, "fixture_version": 1}
	check(rejected.bootstrap(boot_request, RefCounted.new()).status == "REJECTED"
		and rejected.snapshot().is_empty() and late.call().is_empty(), "failed fresh construction leaves exit in effect")
	var fresh: RefCounted = boot()
	callbacks.attach(fresh, presenter)
	check(fresh.snapshot().session != root.session and fresh.snapshot().generation == 1
		and late.call().is_empty(), "fresh owner with distinct session and stale callback")
	var old: Dictionary = request(held, "RESTART", RESET_PAYLOAD)
	check(send(fresh, old, "REJECTED").reason == "M405_FOREIGN_SESSION", "old request rejected across session")
	check(tx(fresh, "COMPLETE", {"token": token}, "REJECTED").reason == "M405_INVALID_TOKEN", "old token cannot settle in fresh owner")
	check(held.snapshot() == root and held.close_failure_diagnostic() == diagnostic, "fresh exit preserves held root and diagnostics")
	return true
