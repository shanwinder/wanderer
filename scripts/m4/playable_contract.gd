extends RefCounted

# Corrected §§19/25/27/28. Value validation never confers capability/provenance.
const Data = preload("res://scripts/npc/guidance_data_contract.gd")
const Catalog = preload("res://scripts/m4/playable_fixture_catalog.gd")
const OPS = ["COMMAND", "GUIDANCE", "ADMIT", "ADVANCE", "DECIDE_LOCK", "PLAYER_LOCK", "ENEMY_LOCK", "IMPACT", "COMPLETE", "CANCEL", "CLOSE_ROUND", "RESTART"]
const KINDS = ["ATTACK", "HELP", "DEFEND", "RESCUE", "RETREAT"]
const LIFE = ["ALIVE", "DOWN", "DEAD"]
const PARTICIPATION = ["PRESENT", "RETREATED"]
const PHASES = ["PREPARED", "OPEN", "SEALED", "CLOSED", "TERMINAL"]
const QPHASES = ["READY", "WAIT_ACTION", "DRAINED", "STOPPED"]
const REJECTIONS = ["INVALID_SCHEMA", "WRONG_DOMAIN", "WRONG_VERSION", "FOREIGN_SESSION", "STALE_GENERATION", "UNAUTHORIZED", "INVALID_TOKEN", "DUPLICATE_REQUEST", "INVALID_TOKEN_PHASE", "WRONG_ROUND", "WRONG_QUEUE", "WRONG_SLOT", "INVALID_PHASE", "TERMINAL", "COMMAND_LOCKED", "COMMAND_REQUIRED", "SEALED_RESTART", "STALE_REVISION", "ACTOR_UNAVAILABLE", "INVALID_TARGET", "EPISODE_CHANGED", "RESOURCE_UNAVAILABLE", "INVALID_BINDING", "UNKNOWN_FIXTURE", "NO_REAL_PROGRESS", "CLOSE_FAILED", "COUNTER_OVERFLOW", "INVALID_CANDIDATE", "GUIDANCE_REJECTED"]
const SUCCESS = {"COMMAND": {"ACCEPTED": ["COMMAND_ACCEPTED"]}, "GUIDANCE": {"ACCEPTED": ["GUIDANCE_ACCEPTED"]},
	"ADMIT": {"APPLIED": ["ROUND_ADMITTED"], "STOPPED": ["OUTCOME_FROZEN"]},
	"ADVANCE": {"READY": ["SLOT_READY"], "APPLIED": ["SLOT_DISPOSED"]},
	"DECIDE_LOCK": {"AUTHORIZED": ["ACTION_LOCKED"]}, "PLAYER_LOCK": {"AUTHORIZED": ["ACTION_LOCKED"]}, "ENEMY_LOCK": {"AUTHORIZED": ["ACTION_LOCKED"]},
	"IMPACT": {"APPLIED": ["EFFECT_APPLIED"], "SKIPPED": ["ACTOR_UNAVAILABLE", "TARGET_UNAVAILABLE", "EPISODE_CHANGED", "RESOURCE_UNAVAILABLE", "HELP_NO_HEAL"]},
	"COMPLETE": {"COMPLETED": ["ACTION_COMPLETED"]}, "CANCEL": {"APPLIED": ["ACTION_CANCELLED"]},
	"CLOSE_ROUND": {"APPLIED": ["ROUND_CLOSED"], "STOPPED": ["DEMO_LIMIT_REACHED"]}, "RESTART": {"APPLIED": ["RESTARTED"]},
	"SEAL": {"AUTHORIZED": ["ROUND_SEALED"]}, "COMMIT_CLOSE": {"APPLIED": ["ROUND_CLOSED"], "STOPPED": ["DEMO_LIMIT_REACHED"]}}
const DECISION_CODES = ["SELF_LOW_HP_THREAT", "SELF_LETHAL_THREAT", "PLAYER_LOW_HP_HELP", "HELP_UNAVAILABLE_ATTACK", "ATTACK_AVAILABLE_ENEMY", "GUIDANCE_DISCRETIONARY_DEFEND", "GUIDANCE_FOCUS_TARGET", "M404_URGENT_RESCUE", "M404_NONURGENT_RESCUE", "M404_SELF_PRESERVATION_RETREAT", "M404_RETREAT_DEPENDENCY", "M404_INVALID_CONTEXT", "M404_NO_ELIGIBLE_SLOT", "M404_EXCEPTION_BOUNDARY"]
const RELATION_REASONS = ["NO_GUIDANCE", "M404_SITUATION_PRIORITY", "M404_GUIDANCE_NOT_APPLICABLE", "SELF_PRESERVATION_PRIORITY", "URGENT_HELP_PRIORITY", "RESOURCE_UNAVAILABLE", "HELP_UNAVAILABLE_BASELINE_PRIORITY", "BASELINE_ATTACK", "PLAYER_ABOVE_HELP_THRESHOLD", "NO_VALID_THREAT", "PROFILE_PREFERS_BASELINE", "TARGET_UNAVAILABLE", "BASELINE_TARGET", "PROFILE_PERMITTED_COOPERATION"]

static func schemas() -> Dictionary:
	return {
	"Bootstrap": {"domain": ["M4_PLAYABLE"], "version": [1], "fixture_id": "S", "fixture_version": [1, 2]},
	"BootstrapReply": {"status": ["CREATED", "REJECTED"], "reason": "S", "view": "?View"},
	"Identity": {"session": "session", "generation": "positive", "round_id": "positive", "state_revision": "nonneg"},
	"DecisionIdentity": {"session": "session", "generation": "positive", "round_id": "positive", "snapshot_revision": "nonneg"},
	"Request": {"domain": ["M4_PLAYABLE"], "version": [1], "identity": "Identity", "request_id": "S", "issuer": ["INPUT", "DRIVER", "PRESENTER"], "operation": OPS, "payload": "Payload", "queue_id": "?S"},
	"CommandPayload": {"actor_id": "S", "action": ["ATTACK", "DEFEND"], "target_id": "S"},
	"GuidancePayload": {"request": "GuidanceRequest"}, "DecisionPayload": {"observation": "Observation"},
	"SlotPayload": {"slot_id": "S"}, "TokenPayload": {"token": "Token"},
	"RestartPayload": {"fixture_id": "S", "fixture_version": [1, 2]}, "Empty": {},
	"Observation": {"domain": ["M4_PLAYABLE"], "version": [1], "identity": "Identity", "source": "Source", "slot": "Slot", "party": "[]Party", "enemies": "[]Enemy", "hits": "[]Hit", "guidance": "GuidanceView"},
	"Source": {"owner_id": "S", "owner_revision": "nonneg", "observation_id": "S"},
	"Slot": {"queue_id": "S", "slot_id": "S", "opportunity_id": "S", "actor_id": "S", "cursor": "nonneg", "phase": ["READY"]},
	"Party": {"actor_id": "S", "role": ["PLAYER", "NPC"], "hp": "nonneg", "max_hp": "positive", "life": LIFE, "participation": PARTICIPATION, "eligible": "bool", "episode": "?Episode", "help_uses": "?bit", "rescue_uses": "bit", "guard": "?Guard"},
	"Episode": {"episode_id": "S", "entry_round": "positive", "budget": [0, 1, 2], "active": "bool", "entry_order": "positive"},
	"Guard": {"actor_id": "S", "grant_action_id": "positive", "round_id": "positive", "mode": ["ROUND", "NEXT_ENEMY_HIT"]},
	"Enemy": {"actor_id": "S", "hp": "nonneg", "max_hp": "positive", "available": "bool"},
	"Hit": {"actor_id": "S", "target_id": "S", "damage": [3]},
	"GuidanceView": {"encounter_id": "session", "generation": "positive", "round_id": "positive", "guidance_revision": "nonneg", "pending": "?FrozenRecord", "active": "?FrozenRecord", "profiles": "[]Profile"},
	"Token": {"domain": ["M4_PLAYABLE"], "version": [1], "identity": "Identity", "queue_id": "S", "slot_id": "S", "opportunity_id": "S", "action_id": "positive", "authorization_id": "S", "actor_id": "S", "target_id": "S", "kind": KINDS, "episode_id": "?S", "amount": "nonneg", "request_id": "S"},
	"ResourceChange": {"actor_id": "S", "resource": ["HELP", "RESCUE"], "before": "bit", "after": "bit"},
	"GuardChange": {"actor_id": "S", "before": "?Guard", "after": "?Guard", "cause": ["GRANT", "CONSUME", "DOWN", "DEAD", "RETREATED", "ROUND_CLOSE", "TERMINAL", "RESTART"]},
	"LifeChange": {"actor_id": "S", "before_life": LIFE, "after_life": LIFE, "before_participation": PARTICIPATION, "after_participation": PARTICIPATION},
	"Effect": {"status": ["APPLIED", "SKIPPED"], "reason": "S", "hp_delta": "int", "target_id": "S", "resources": "[]ResourceChange", "guards": "[]GuardChange", "lifecycle": "[]LifeChange"},
	"Receipt": {"receipt_id": "S", "action_id": "positive", "session": "session", "authorization_id": "S", "generation": "positive", "round_id": "positive", "queue_id": "S", "slot_id": "S", "impact_revision": "positive", "completion_revision": "positive", "effect_status": ["APPLIED", "SKIPPED"]},
	"Response": {"domain": ["M4_PLAYABLE"], "version": [1], "status": ["ACCEPTED", "REJECTED", "AUTHORIZED", "APPLIED", "SKIPPED", "COMPLETED", "READY", "STOPPED"], "reason": "S", "identity": "Identity", "token": "?Token", "effect": "?Effect", "receipt": "?Receipt", "view": "?View", "guidance_reason": "Z"},
	"View": {"identity": "Identity", "phase": PHASES, "queue_phase": ["ABSENT", "READY", "WAIT_ACTION", "DRAINED", "STOPPED"], "command_ready": "bool", "has_accepted_fresh_command": "bool", "queue_id": "?S", "guidance": "GuidanceView", "party": "[]Party", "enemies": "[]Enemy", "decision": "?Decision", "outcome": "?Outcome", "diagnostic": "?S", "active_token": "?Token", "boundary_changes": "?BoundaryChanges"},
	"Choice": {"action": KINDS, "target_id": "S", "episode_id": "?S"},
	"Decision": {"schema_version": [1], "identity": "?DecisionIdentity", "baseline": "?Choice", "selected": "?Choice", "decision_reason": "DecisionReason", "guidance_relation": "Relation", "legal_effect": "LegalEffect", "refusal_type": ["NONE", "HELPER_PRIORITY"]},
	"DecisionReason": {"code": DECISION_CODES, "excluded": "[]Exclusion"},
	"Exclusion": {"action": KINDS, "target_id": "?S", "code": ["NO_RESCUE_USE", "TARGET_NOT_DOWN", "TARGET_NOT_PRESENT", "EPISODE_INVALID", "HELP_UNAVAILABLE", "HIGHER_PRIORITY", "RETREAT_PREDICATE_UNAPPROVED"]},
	"Relation": {"response": ["NONE", "FOLLOWED", "MATCHED_INDEPENDENTLY", "REFUSED", "NOT_APPLICABLE"], "reason": RELATION_REASONS, "behavior_changed": "bool"},
	"LegalEffect": {"status": ["CANDIDATE_ONLY", "NO_ACTION", "INVALID_INPUT", "DESIGN_BLOCKED"], "required_transaction": "?Kind"},
	"Outcome": {"outcome_id": "S", "freeze_revision": "nonneg", "result": ["VICTORY", "DEFEAT", "PARTY_RETREAT", "MIXED_WITHDRAWAL", "ABORTED"], "reason": ["M403_ENEMIES_UNAVAILABLE", "M403_ALL_PARTY_RETREATED", "M403_ESCAPED_WITH_LEFT_BEHIND", "M403_MUTUAL_INCAPACITATION", "M403_NO_ACTIVE_PARTY", "M403_ABORTED"], "party": "[]PartySummary", "enemies": "[]EnemySummary"},
	"PartySummary": {"actor_id": "S", "life": LIFE, "participation": PARTICIPATION, "hp": "nonneg", "final_episode": "?Episode"},
	"EnemySummary": {"actor_id": "S", "hp": "nonneg", "available": "bool"},
	"JournalEntry": {"sequence": "positive", "operation": OPS + ["SEAL", "COMMIT_CLOSE"], "request": "?Request", "internal": "?InternalClose", "pre_revision": "nonneg", "post_revision": "positive", "result_digest": "S"},
	"ClockChange": {"actor_id": "S", "episode_id": "S", "before_budget": [1, 2], "after_budget": [0, 1, 2], "reason": ["GRACE", "TICK", "BLED_OUT"]},
	"BoundaryChanges": {"guards": "[]GuardChange", "lifecycle": "[]LifeChange", "clocks": "[]ClockChange"},
	"PresentationEvent": {"domain": ["M4_PLAYABLE"], "version": [1], "identity": "Identity", "event_id": "S", "kind": ["INTENT", "IMPACT", "COMPLETION", "ROUND_CLOSED", "TERMINAL", "RESET"], "token": "?Token", "effect": "?Effect", "receipt": "?Receipt", "view": "View"},
	"InternalClose": {"kind": ["SEAL", "COMMIT_CLOSE"], "witness": "Witness", "event": "CloseEvent", "origin": "Request"},
	"Witness": {"session": "session", "generation": "positive", "round_id": "positive", "queue_id": "S", "witness_id": "S", "expected_opportunities": "[]S", "receipt_ids": "[]S", "dispositions": "[]Disposition", "outstanding": [0], "sealed_revision": "positive"},
	"Disposition": {"opportunity_id": "S", "slot_id": "S", "actor_id": "S", "kind": ["COMPLETED", "CANCELLED", "UNAVAILABLE", "NO_PLAYER_COMMAND", "TERMINAL_STOP"], "action_id": "?positive", "observed_revision": "nonneg"},
	"CloseEvent": {"domain": ["M4_PLAYABLE"], "version": [1], "session": "session", "generation": "positive", "round_id": "positive", "queue_id": "S", "event_id": "S", "witness_id": "S", "sealed_revision": "positive", "authorization_id": "S"},
	"SeedReference": {"fixture_id": "S", "fixture_version": [1, 2], "contract_revision": [2, 3], "catalog_sha256": "S", "damage_policy": ["MAIN_5_1_3"], "enemy_policy": ["WEAKEST_RATIO_HP_ORDER_V1"], "capacity": [6]},
	"CommandState": {"request_id": "S", "actor_id": "S", "action": ["ATTACK", "DEFEND"], "target_id": "S", "accepted_round": "positive", "accepted_revision": "positive"},
	"QueueState": {"queue_id": "S", "phase": QPHASES, "cursor": "nonneg", "opportunities": "[]Opportunity", "dispositions": "[]Disposition"},
	"Opportunity": {"opportunity_id": "S", "slot_id": "S", "actor_id": "S"},
	"ActionGrant": {"token": "Token", "phase": ["LOCKED", "APPLIED", "SKIPPED", "COMPLETED", "CANCELLED"], "effect": "?Effect", "impact_revision": "?positive", "disposed_revision": "?positive"},
	"RequestRecord": {"request_id": "S", "operation": OPS, "accepted_revision": "positive", "result_status": ["ACCEPTED", "AUTHORIZED", "APPLIED", "SKIPPED", "COMPLETED", "STOPPED"]},
	"CloseHistory": {"witness": "Witness", "event": "CloseEvent", "consumed": "bool", "close_revision": "?positive", "changes": "?BoundaryChanges"},
	"RoundHistory": {"round_id": "positive", "queue": "QueueState", "declarations": "[]Hit", "close": "?CloseHistory"},
	"Root": {"domain": ["M4_PLAYABLE"], "version": [1], "session": "session", "generation": "positive", "revision": "nonneg", "seed": "SeedReference", "phase": PHASES, "round_id": "positive", "closed_rounds": "nonneg", "party": "[]Party", "enemies": "[]Enemy", "guidance": "GuidanceView", "command": "?CommandState", "queue": "?QueueState", "declarations": "[]Hit", "actions": "[]ActionGrant", "receipts": "[]Receipt", "requests": "[]RequestRecord", "close": "?CloseHistory", "round_history": "[]RoundHistory", "outcome": "?Outcome", "diagnostic": "?S", "journal": "[]JournalEntry"}
	}

static func exact(value: Variant, fields: Array) -> bool:
	return Data._fields(value, fields)

static func valid(spec: Variant, value: Variant) -> bool:
	if typeof(spec) == TYPE_ARRAY:
		for item in spec:
			if typeof(item) == typeof(value) and item == value: return true
		return false
	if typeof(spec) == TYPE_DICTIONARY:
		if not exact(value, spec.keys()): return false
		for key in spec:
			if key == "payload" and value.has("operation"):
				if not valid(payload_type(value.operation), value[key]): return false
			elif not valid(spec[key], value[key]): return false
		return true
	if spec.begins_with("?"): return value == null or valid(spec.substr(1), value)
	if spec.begins_with("[]"):
		if typeof(value) != TYPE_ARRAY: return false
		for item in value:
			if not valid(spec.substr(2), item): return false
		return true
	match spec:
		"int": return typeof(value) == TYPE_INT
		"nonneg": return typeof(value) == TYPE_INT and value >= 0
		"positive": return typeof(value) == TYPE_INT and value > 0
		"session": return typeof(value) == TYPE_INT and value != 0
		"bit": return typeof(value) == TYPE_INT and value in [0, 1]
		"bool": return typeof(value) == TYPE_BOOL
		"S": return typeof(value) == TYPE_STRING and not value.is_empty()
		"Z": return typeof(value) == TYPE_STRING
		"Kind": return valid(KINDS, value)
		"GuidanceRequest": return Data.validate_request(value).is_empty()
		"Profile": return Data.validate_profile(value).is_empty()
		"FrozenRecord":
			if not exact(value, ["guidance_type", "issuer_player_id", "preferred_target_id", "encounter_id", "generation", "round_id", "guidance_revision"]): return false
			var request: Dictionary = value.duplicate(true)
			request.schema_version = 1
			request.expected_guidance_revision = request.guidance_revision
			request.erase("guidance_revision")
			return Data.validate_request(request).is_empty()
	var all: Dictionary = schemas()
	if not all.has(spec) or not valid(all[spec], value): return false
	# Named recursive records share these invariants at every nesting depth.
	if spec in ["Bootstrap", "RestartPayload", "SeedReference"]:
		if not Catalog.fixture_pair_valid(value.fixture_id, value.fixture_version): return false
		return spec != "SeedReference" or value.contract_revision == Catalog.contract_revision(value.fixture_version)
	if spec == "BootstrapReply":
		if value.status == "CREATED": return value.reason == "M405_CREATED" and value.view != null
		return value.view == null and value.reason in ["M405_INVALID_SCHEMA", "M405_UNAUTHORIZED", "M405_UNKNOWN_FIXTURE", "M405_INVALID_SEED", "M405_INVALID_CANDIDATE"]
	if spec == "Token":
		return (value.amount > 0 if value.kind == "ATTACK" else value.amount == 0) and ((value.episode_id != null) == (value.kind == "RESCUE"))
	if spec == "Receipt": return value.completion_revision > value.impact_revision
	if spec == "PresentationEvent":
		return value.identity == value.view.identity and ((value.effect != null) == (value.kind == "IMPACT")) and ((value.receipt != null) == (value.kind == "COMPLETION"))
	if spec == "JournalEntry":
		if value.post_revision != value.pre_revision + 1: return false
		if value.operation in ["SEAL", "COMMIT_CLOSE"]:
			return value.request == null and value.internal != null and value.internal.kind == value.operation
		return value.internal == null and value.request != null and value.request.operation == value.operation
	if spec == "InternalClose": return value.origin.operation == "CLOSE_ROUND"
	if spec == "Effect":
		if not SUCCESS.IMPACT[value.status].has(value.reason.trim_prefix("M405_")) or not value.reason.begins_with("M405_"): return false
		for rows in [value.resources, value.guards, value.lifecycle]:
			var actors: Array = []
			for row in rows:
				if row.actor_id in actors: return false
				actors.append(row.actor_id)
		if value.status == "SKIPPED":
			return value.hp_delta == 0 and value.resources.is_empty() and value.guards.is_empty() and value.lifecycle.is_empty()
		return value.hp_delta != 0 or not value.resources.is_empty() or not value.guards.is_empty() or not value.lifecycle.is_empty()
	if spec == "ResourceChange": return value.before == 1 and value.after == 0
	if spec == "GuardChange":
		if value.before == value.after: return false
		for guard in [value.before, value.after]:
			if guard != null and guard.actor_id != value.actor_id: return false
		return value.after != null if value.cause == "GRANT" else value.before != null and value.after == null
	if spec == "LifeChange":
		if value.before_participation != "PRESENT": return false
		if value.after_participation == "RETREATED": return value.before_life == "ALIVE" and value.after_life == "ALIVE"
		return (value.before_life == "ALIVE" and value.after_life == "DOWN") or (value.before_life == "DOWN" and value.after_life in ["ALIVE", "DEAD"])
	if spec == "ActionGrant":
		var lock_revision: int = value.token.identity.state_revision
		if value.phase == "LOCKED": return value.effect == null and value.impact_revision == null and value.disposed_revision == null
		if value.phase == "CANCELLED": return value.effect == null and value.impact_revision == null and value.disposed_revision != null and value.disposed_revision > lock_revision
		if value.effect == null or value.impact_revision == null or value.effect.target_id != value.token.target_id: return false
		if value.impact_revision <= lock_revision: return false
		if value.phase == "COMPLETED": return value.disposed_revision != null and value.disposed_revision > value.impact_revision
		return value.phase == value.effect.status and value.disposed_revision == null
	return true

static func payload_type(operation: Variant) -> String:
	match operation:
		"COMMAND": return "CommandPayload"
		"GUIDANCE": return "GuidancePayload"
		"DECIDE_LOCK": return "DecisionPayload"
		"PLAYER_LOCK", "ENEMY_LOCK": return "SlotPayload"
		"IMPACT", "COMPLETE", "CANCEL": return "TokenPayload"
		"RESTART": return "RestartPayload"
	return "Empty"

static func request_error(r: Variant) -> String:
	if not exact(r, schemas().Request.keys()): return "INVALID_SCHEMA"
	if typeof(r.domain) != TYPE_STRING or typeof(r.version) != TYPE_INT: return "INVALID_SCHEMA"
	if r.domain != "M4_PLAYABLE": return "WRONG_DOMAIN"
	if r.version != 1: return "WRONG_VERSION"
	if not valid("Request", r): return "INVALID_SCHEMA"
	if not r.request_id.begins_with("ui/") and not r.request_id.begins_with("driver/"): return "INVALID_SCHEMA"
	if r.issuer == "INPUT" and not r.request_id.begins_with("ui/"): return "INVALID_SCHEMA"
	if r.issuer != "INPUT" and not r.request_id.begins_with("driver/"): return "INVALID_SCHEMA"
	return ""

static func party_valid(p: Dictionary, round_id: int) -> bool:
	if not valid("Party", p) or p.hp > p.max_hp or p.max_hp > 30: return false
	if (p.hp > 0) != (p.life == "ALIVE") or (p.participation == "RETREATED" and p.life != "ALIVE"): return false
	if p.eligible != (p.life == "ALIVE" and p.participation == "PRESENT"): return false
	if p.role == "PLAYER" and p.help_uses != null: return false
	if p.role == "NPC" and p.help_uses == null: return false
	if p.guard != null:
		if not p.eligible or p.guard.actor_id != p.actor_id or p.guard.round_id != round_id: return false
		if p.guard.mode != ("ROUND" if p.role == "PLAYER" else "NEXT_ENEMY_HIT"): return false
	if p.episode == null: return p.life == "ALIVE"
	var e: Dictionary = p.episode
	if e.entry_round > round_id: return false
	if p.life == "DOWN": return e.active and e.budget > 0 and (e.entry_round != round_id or e.budget == 2)
	return not e.active and (e.budget == 0 if p.life == "DEAD" else e.budget > 0)

static func response_valid(operation: String, response: Variant) -> bool:
	if not valid("Response", response): return false
	if not response.reason.begins_with("M405_"): return false
	var reason: String = response.reason.substr(5)
	if response.status == "REJECTED":
		return reason in REJECTIONS and response.token == null and response.effect == null and response.receipt == null and response.view == null and (reason == "GUIDANCE_REJECTED" or response.guidance_reason == "")
	if response.guidance_reason != "" or not SUCCESS.get(operation, {}).get(response.status, []).has(reason): return false
	if response.view == null: return false
	if (response.token != null) != (response.status == "AUTHORIZED" and operation.ends_with("LOCK")): return false
	if (response.effect != null) != (operation == "IMPACT"): return false
	if (response.receipt != null) != (operation == "COMPLETE"): return false
	if operation == "IMPACT" and (response.status != response.effect.status or response.reason != response.effect.reason): return false
	return response.identity == response.view.identity
