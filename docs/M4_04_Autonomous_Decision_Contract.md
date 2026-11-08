# M4-04 — Autonomous Decision Contract & Owner Approval Gate

**O1-A/O2-A/O3-A/O5-A: OWNER APPROVED for isolated implementation. M4-04 isolated implementation: IMPLEMENTED CANDIDATE. PR #55: DRAFT / Awaiting Independent Follow-up Review.** Canonical `6cd7b842c07e308203f61bbaaff6339233567c68` includes [PR #54](https://github.com/shanwinder/wanderer/pull/54)'s approved Decision Register. Existing branch `codex/m4-04-isolated-autonomous-decision-proof` is rebased onto that canonical for G55-DOC-01; §2.1 remains the approved design authority. [Prior independent review](https://github.com/shanwinder/wanderer/pull/55#pullrequestreview-5818357540) inspected old delivery `af3c4161a0d5e72bafec46ae07561be5ec1fdc7c` and requested this reconciliation.

**Recorded focused proof: 128 cases / 458 assertions**, originally executed on `6187a4ff6dea0a5a983c21171e92db53eff6cd63`; original [run record](../tests/actors/evidence/m4-04/run-record.json) remains unchanged. Separate [post-rebase source, commands, regression and audit record](../tests/actors/evidence/m4-04/post-r54-rebase.json) attributes the new runs to their actual source. Pure candidates and real C-owned ATTACK/RESCUE/RETREAT transactions remain distinct. **No full Production Integration. No Manual GUI/Visual Acceptance** (GUI/F5/F6/keyboard/visual NOT RUN). HELP/DEFEND real effect bridge is **BLOCKED DEPENDENCY / PURE POLICY ONLY**; O4 consent deferred and O7 interleaving producers diagnostic/deferred. No M4-05 authorization. [API and coverage limits](../tests/actors/README.md#m4-04--isolated-autonomous-decision-proof).

## 1. Baseline and authority

**Historical PR #53 design baseline:** verified local HEAD, fetched canonical, live remote and feature merge-base: `5b870953cc88773ecbfb005cf274c2e40f3f719d`, branch `visual-combat-test-1`. [PR #52](https://github.com/shanwinder/wanderer/pull/52) merged on 8 November 2026 at 13:08:52 Asia/Bangkok. [Independent follow-up review 5816854644](https://github.com/shanwinder/wanderer/pull/52#pullrequestreview-5816854644) reviewed delivery `e81aabd8cc55fe7a5e3d92607c4d45d91e51d332`: R52-01 resolved, isolated source/evidence review PASS; reviewer did not rerun Godot or exhaustively verify archives. This does not verify M4-04.

Initial working tree clean; open PR search found only #2/#17, no duplicate M4-04 PR; live M4-04 branch search empty. Task branch: `codex/m4-04-autonomous-decision-design-gate`. No merge/cherry-pick of unrelated proposals.

**Historical PR #54 approval-record baseline:** local/fetched/live canonical and feature merge-base `0c5eef193da6265d1e7f502123711ba4753625ce`; [PR #53](https://github.com/shanwinder/wanderer/pull/53) merged at this SHA. [Independent design review 5816930180](https://github.com/shanwinder/wanderer/pull/53#pullrequestreview-5816930180) reviewed `e4bf563d179c005b395c2ed64767d8438f7d2aa6` and recorded DESIGN-ONLY REVIEW PASS; O1/O2/O3/O5 were still pending at that historical review. The subsequent explicit owner approval in §2.1 closes those design subdecisions within isolated scope, not runtime verification. Initial tree clean; no duplicate open M4-04 PR/remote branch; #2/#17 remain unrelated. Approval-record branch: `codex/m4-04-owner-subdecision-approval`.

**Inherited C evidence only:** Godot `4.7.2.stable.official.ed1daf0bf`, executable `/Applications/Godot.app/Contents/MacOS/Godot`, tested source `d583b4b6fdd3226178e4f5b4e916c874a82d83c4`; recorded 115 cases/6,054 assertions, canonical 82/candidate 88 stages PASS, Legacy 6 cases/5,892 frames identical. Expected/actual, full commands, exits, failed attempts and source attribution remain in [run record](../tests/actors/evidence/m4-03c/run-record.json) and [R52 record](../tests/actors/evidence/m4-03c/r52-01.json). This paragraph describes inherited C evidence only; current M4-04 runs are recorded separately above. M403-10/14/15 DIAGNOSTIC-ONLY; M403-13/42 PARTIAL; M402-06 BLOCKED end-to-end/M402-24 PARTIAL remain so. No playable/visual acceptance claim.

## 2. Owner decision register

**Owner Approval Source:** attached task titled “WANDERER — M4-04 Owner-Approved Design Contract & Decision Register Update”, supplied in this chat, dated **8 พฤศจิกายน 2569 / 8 November 2026 (Asia/Bangkok)**. The source authorizes four documentation files and a Draft PR, not implementation. The following quotations preserve its operative wording; technical details were proposals at that checkpoint. Subsequent approval in §2.1 governs O1/O2/O3/O5 now.

| ID | Actual approved direction / scope | Remaining open subdecisions |
|---|---|---|
| D08 | **APPROVED DESIGN:** “Safety → Urgent RESCUE → Existing HELP → Nonurgent RESCUE → RETREAT / Existing Action”. Preserve existing first-valid-hit Safety; RESCUE uses real DOWN episode/resource; HELP remains for living Player; latest state at each NPC slot; unavailable RESCUE explains cause and uses legal fallback | O1-A/O2-A/O3-A approved in §2.1, including the new isolated RETREAT rule HP≤30%; no new trait weighting or Compassion effect |
| D16 | **APPROVED DESIGN DIRECTION:** distinguish helper choosing another priority, recipient refusing aid, protocol/identity/resource request rejection, and post-lock effect SKIPPED. For unconscious DOWN: “ไม่มี Active Consent หรือ Active Refusal จากผู้รับ” | Conscious-DOWN model, consent UI and recipient-refusal gameplay require separate contract/approval; no such gameplay added here |
| D09 | **APPROVED DESIGN DIRECTION: Isolated Strict Boundary Option A.** Preserve exact8 v1, types, R1, Pending/Frozen, generation/round and HELP/FOCUS. Design isolated versioned M4 adapter; no unknown fields into v1. “ไม่อนุญาตให้ HP0→RESCUE→HP-positive ใน Identity เดิม เปิด Accepted Pending หรือ Player Command เก่ากลับมาโดยอัตโนมัติ” | O5-A exact isolated schema/provenance approved in §2.1; future production adapter remains outside scope. No revision bump merely for DOWN/RETREAT/RESCUE; no full production D09 integration |

Earlier D03B/D04B/D05A/D06A/D09A/D13A/D17A approvals remain isolated; [M4-02 §10](M4_02_Rescue_Clock_Death_Contract.md#10-owner-decision-register-and-exact-approval-wording). D07A/D10A/D11A/D14A/D15A remain isolated M4-03 scope; [M4-03 §12](M4_03_Queue_Retreat_Outcome_Contract.md#12-owner-approval-gate-and-learning-notes). This document does not approve full-game mechanics by combining those scopes.

### 2.1 Owner subdecision approval — current authority

**Source:** owner message in this chat, “อนุมัติ O1-A, O2-A, O3-A และ O5-A สำหรับ M4-04 Isolated Implementation”, with attached **“WANDERER — M4-04 Owner Subdecision Package”**, dated 8 November 2026 (Asia/Bangkok). Package canonical is `0c5eef193da6265d1e7f502123711ba4753625ce`. Its PROPOSED/AWAITING labels describe the package before this explicit approval; rejected alternatives are not approved by it.

| Subdecision | Approved Option A / isolated implementation scope |
|---|---|
| O1-A | `urgent = valid_rescue_candidate AND budget == 1 AND entry_round < current_round`. Safety remains first. B1 previous entry = urgent; B2 previous = nonurgent; B2 current = nonurgent/grace; B1 current = invalid; B0/DEAD not rescuable; no use = ineligible. No forecast, real-time or future-hit speculation |
| O2-A | Rank `(budget ASC, entry_order ASC, stable_party_index ASC)`, no Player preference. Derive global generation-scoped ordinal from owner-validated initial fixture replay and authenticated operation journal at real episode creation. Match current episode/root, re-DOWN gets new ordinal, Restart resets generation scope. Never parse opaque episode ID or trust caller/detached order; missing provenance = INVALID_INPUT / NO ACTION / NO MUTATION. Equal ordinal is comparator-only; duplicate live ordinals reject |
| O3-A | Current legal NPC slot, ALIVE/PRESENT, nonterminal, at least one active Enemy, no Safety/urgent RESCUE/existing HELP/nonurgent RESCUE, and `current_hp * 100 <= max_hp * 30` → RETREAT/self, reason `M404_SELF_PRESERVATION_RETREAT`. This is a **new approved gameplay rule for isolated implementation**, despite reusing the existing low-HP number. No traits, random success/failure, new cost/cooldown/resource. Execution uses M4-03C owned transaction and approved terminal rules |
| O5-A | Approves §§3–4 exact12 input/exact8 output and nested schemas, strict types/identity/provenance and relation/refusal semantics **for isolated proof only**. Same-revision owner observation, reject forged/stale/mixed views; pure read-only candidate grants no token/receipt/opportunity. Actual Lock/Impact/Complete use M4-03C authority. No Pending import, fake Player HP or v1 schema/type/R1 change |

O5-A retains the HELP/Guard boundary: `help_uses` needs owner-valid provenance before executable effect. Labelled pure fixtures may study HELP; real HELP integration is **BLOCKED DEPENDENCY** until O6 separately authorized. No HELP receipt or resource reduction in an unowned dictionary. Pure refusal_type emits only NONE/HELPER_PRIORITY; RECIPIENT_REFUSAL remains reserved, REQUEST_REJECTION belongs to actual request result, EFFECT_SKIPPED to actual post-lock result. Existing Guidance causality remains required.

## 3. Code-backed boundaries and approved isolated adapter

Inspected on the verified base; **inspection is not runtime verification**:

| Source | Implemented fact | M4-04 gap / proposal |
|---|---|---|
| [Resolver](../scripts/npc/npc_decision_resolver.gd) | Exact7 multi-actor context; first still-valid declared hit aimed at this NPC, not sum; safety low HP≤30% or lethal hit; HELP≤30%, available use; first available Enemy | `_policy` returns PLAYER_DEFEATED when Player HP0. Cannot reuse that output as a valid M4 continuation decision or forge positive Player HP |
| [Guidance Layer](../scripts/npc/guidance_decision_layer.gd), [GuidedEncounter](../scripts/combat/guided_encounter.gd) | Exact6 envelope, exact5 identity, exact7 frozen record; independent baseline/selected decision and guidance relation; decisions locked per slot | M4 policy must be separate; only a genuinely v1-compatible snapshot can call unchanged v1. No catch-all forwarding of M4 dictionaries |
| [Isolated actor state](../scripts/m4/isolated_actor_state.gd), [rescue/clock owner](../scripts/m4/isolated_rescue_clock_encounter.gd) | Party lifecycle/eligibility, active episode, entry round/budget, helper rescue ledger; one owned publication | Copies are observations, not authority. Current episode stores opaque ID, entry_round, budget, active; no explicit per-episode order field |
| [Queue adapter](../scripts/m4/m403_queue_adapter.gd), [terminal owner](../scripts/m4/m403_terminal_encounter.gd) | Prepared opportunity identity differs from actionable current slot; disposed slots never reinsert; terminal/close/continuation owned separately | Policy output cannot issue opportunity, seal witness, action token or receipt. C has no production Player Command/Guidance bridge |

O5-A approved pure adapter observes one coherent owner snapshot at current slot start, derives eligibility and candidate explanations, then returns data only. No mutation, callbacks, random choice, wall-clock urgency or persistent personality. The isolated candidate facade independently authenticates/revalidates and delegates supported actions to existing C-owned transaction gates; HELP/DEFEND effect execution remains blocked.

### 3.1 Exact input schema — O5-A approved, isolated only

Wire name `M4DecisionContext`, `schema_version=1` is an independent namespace, not Guidance v1. All dictionary keys below are **required and exact** recursively; extra/missing keys reject. `int` means strict integer (no float/bool coercion); IDs are nonempty strings unless explicitly nullable. Arrays are ordered, unique by ID. `null` is explicit, never omitted. No free-form authority flags.

| Exact record | Fields and types |
|---|---|
| Context (12) | `schema_version:int=1`, `identity:Identity`, `source:Source`, `actor_id:string`, `player_id:string`, `party:Party[]`, `enemies:Enemy[]`, `queue:Queue`, `declared_hits:Hit[]`, `frozen_guidance:FrozenBinding or null`, `profile:Profile or null`, `boundary:string` |
| Identity (4) | `session:int!=0`, `generation:int>=1`, `round_id:int>=1`, `snapshot_revision:int>=0` |
| Source (4) | `adapter_version:int=1`, `owner_kind:string="M403_ISOLATED"`, `owner_revision:int>=0`, `observation_id:string` |
| Party (10) | `actor_id:string`, `role:string in {PLAYER,NPC}`, `current_hp:int>=0`, `max_hp:int>0`, `life_state:string in {ALIVE,DOWN,DEAD}`, `participation:string in {PRESENT,RETREATED}`, `eligible:bool`, `help_uses:int in {0,1} or null`, `rescue_uses:int in {0,1}`, `episode:Episode or null` |
| Episode (5) | `episode_id:string`, `entry_round:int>=1`, `budget:int in {0,1,2}`, `active:bool`, `entry_order:int>=1` |
| Enemy (4) | `actor_id:string`, `current_hp:int>=0`, `max_hp:int>0`, `available:bool` |
| Queue (7) | `queue_id:string`, `slot_id:string`, `opportunity_id:string`, `slot_actor_id:string`, `cursor:int>=0`, `round_phase:string`, `queue_phase:string` |
| Hit (3) | `actor_id:string` (Enemy), `target_id:string` (Party), `damage:int=3` |
| FrozenBinding (2) | `identity:GuidanceIdentity`, `record:FrozenRecord` |
| GuidanceIdentity (5, existing Layer shape) | `encounter_id:int!=0`, `generation:int>=1`, `round_id:int>=1`, `guidance_revision:int>=0`, `snapshot_revision:int>=0` |
| FrozenRecord (7, existing shape) | `guidance_type:string`, `issuer_player_id:string`, `preferred_target_id:string` (empty except FOCUS_TARGET), `encounter_id:int!=0`, `generation:int>=1`, `round_id:int>=1`, `guidance_revision:int>=0` |
| Profile (7, existing shape) | `schema_version:int=1`, `actor_id:string`, `player_id:string`, `discipline:string`, `trust:string`, `compassion:string`, `courage:string` |

Profile is the existing exact7 [Data contract](../scripts/npc/guidance_data_contract.gd) profile, with discipline FLEXIBLE/PLAN_ORIENTED, trust CAUTIOUS/ESTABLISHED, compassion ORDINARY/HIGH, courage CAUTIOUS/BOLD and its existing validation; no M4 trait thresholds. Guidance types remain NONE/ATTACK/DEFEND/HELP/FOCUS_TARGET. `boundary` is exactly `RUNNING_SLOT` or `ISOLATED_EXCEPTION`; latter is diagnostic-only and cannot dispatch. `round_phase` uses existing UNINITIALIZED/OPEN/SEALED/CLOSED/ABORTED; `queue_phase` READY/WAIT_ACTION/DRAINED. A decision candidate requires OPEN/READY and a real current undisposed NPC slot. No queue yet or exhausted cursor yields no context/action, not fabricated IDs.

**Source authority and consistency — O2-A/O5-A approved:**

- Owner supplies session/generation/round/revision and retained roster arrays in initial stable order; exactly one Player, actor_id is an NPC, all IDs unique across Party/Enemy. HP≤max; valid pairs only ALIVE/PRESENT, DOWN/PRESENT, DEAD/PRESENT, ALIVE/RETREATED. ALIVE iff HP>0; eligible iff ALIVE/PRESENT; Enemy available iff HP>0. Party array order defines stable party rank, never alphabetical order or a Player preference.
- Queue IDs/cursor/slot owner must equal the authenticated owner queue at that revision. Source.owner_revision equals identity.snapshot_revision. An observation_id is only a correlation label: possession of this string or of a copied snapshot grants no rights. Future adapter must prove acquisition from one owned revision and reject mixed/forged snapshots; pure tests may use explicitly labelled fixtures only.
- Episode membership/ID/active/budget must match the owned ledger. DOWN has active budget1/2, entry_round≤current round; entry-round grace requires B2. DEAD can retain inactive B0; rescued ALIVE may retain an inactive episode, never reuse it as a target. `entry_order` is an owner-derived **generation-wide monotonic episode creation ordinal**, not per-actor count, lexical episode ID or caller priority. Current code's global episode_serial suggests provenance, but no direct field is published per episode: O2-A requires derivation by owner-domain replay of the initial fixture and authenticated operation journal, recording actual episode creation order and validating it against the current root. This is approved but not implemented here. Do not parse opaque IDs as a new public contract. Missing trustworthy order blocks ranking/context; stable order cannot hide missing provenance.
- HELP use is null for Player (no fabricated NPC HELP entitlement) and comes from the authoritative NPC HELP ledger for each NPC; isolated `help_reference` alone does not prove a runnable HELP/Guard integration. RESCUE uses come from the owned rescue ledger. Reads/decisions consume nothing.
- Hits retain current declared Enemy order and exact existing hit values; unavailable attackers are ignored. The first valid hit aimed at this NPC wins even if later damage would be larger. Eligibility uses current state at this slot, not a round-start cached decision.
- FrozenBinding/profile are both null when no authenticated isolated Guidance fixture binding exists. Otherwise identity fields agree with the frozen record; session-to-encounter mapping, Player issuer, round/generation/revision and profile must be owner-bound. Never assume unrelated instance IDs equal. snapshot_revision denotes the current slot observation, not the historical freeze revision; guidance_revision denotes the frozen Guidance identity. A null binding means no Guidance, not permission to import Pending. Profile actor/player IDs must match this context; frozen issuer is the retained Player even if now DOWN. Existing v1 delegation is limited to its exact supported roster (one Player, up to three NPCs, one or two Enemies), valid living-Player state and current eligibility; otherwise the separate M4 policy applies.

**Validation order (O5-A isolated adapter only):** exact schema/types/version → owner/provenance/session → generation → round → snapshot/queue identity → roster/episode/resource consistency → boundary/phase/current actor eligibility → priority selection. Invalid input returns no selected action and no writes. This does not reorder existing Guidance request validation or assign its error codes to M4.

## 4. Exact decision output — O5-A approved, not an action receipt

Exact8 fields: `schema_version:int=1`, `identity:Identity or null` (same validated observation; null only when input identity cannot be validated), `baseline:Choice or null`, `selected:Choice or null`, `decision_reason:Reason`, `guidance_relation:Relation`, `legal_effect:Effect`, `refusal_type:string`.

| Record | Exact fields / values |
|---|---|
| Choice (3) | `action:string in {ATTACK,DEFEND,HELP,RESCUE,RETREAT}`, `target_id:string`, `episode_id:string or null` (required only nonnull for RESCUE) |
| Reason (2) | `code:string` from the codes below, `excluded:Exclusion[]` ordered by priority then target rank |
| Exclusion (3) | `action:string` from Choice enum, `target_id:string or null`, `code:string in {NO_RESCUE_USE,TARGET_NOT_DOWN,TARGET_NOT_PRESENT,EPISODE_INVALID,HELP_UNAVAILABLE,HIGHER_PRIORITY,RETREAT_PREDICATE_UNAPPROVED}` |
| Relation (3) | `response:string in {NONE,FOLLOWED,MATCHED_INDEPENDENTLY,REFUSED,NOT_APPLICABLE}`, `reason:string`, `behavior_changed:bool` |
| Effect (2) | `status:string in {CANDIDATE_ONLY,NO_ACTION,INVALID_INPUT,DESIGN_BLOCKED}`, `required_transaction:string or null` from {ATTACK,DEFEND,HELP,RESCUE,RETREAT} |

`baseline` is the independent **M4 situation policy choice without Guidance**, not necessarily a successful call to old v1; `selected` is the result after compatible existing Guidance evaluation. Target is self for DEFEND/RETREAT, living Player for HELP, ranked DOWN Party for RESCUE, available Enemy for ATTACK. Null choice is not a fake SKIP action, token or completion. Invalid context: both null, INVALID_INPUT, transaction null, no gameplay refusal. Unavailable slot: both null/NO_ACTION, and only the queue owner may record its actual unavailable disposition. Unresolved decision dependency: null/DESIGN_BLOCKED; do not invent RETREAT or a silent approved default.

Decision codes: existing safety `SELF_LOW_HP_THREAT` then `SELF_LETHAL_THREAT`, `PLAYER_LOW_HP_HELP`, `HELP_UNAVAILABLE_ATTACK`, `ATTACK_AVAILABLE_ENEMY`, `GUIDANCE_DISCRETIONARY_DEFEND`, `GUIDANCE_FOCUS_TARGET`; isolated `M404_URGENT_RESCUE`, `M404_NONURGENT_RESCUE`, `M404_SELF_PRESERVATION_RETREAT`, `M404_RETREAT_DEPENDENCY`, `M404_INVALID_CONTEXT`, `M404_NO_ELIGIBLE_SLOT`, `M404_EXCEPTION_BOUNDARY`. O3-A supplies the RETREAT reason and cases below; historical M404_RETREAT_DEPENDENCY/RETREAT_PREDICATE_UNAPPROVED are retained vocabulary and are not reached merely because O3 was formerly open. Relation.reason reuses existing Layer reason on valid v1 delegation; O5-A M4 relation reasons are `NO_GUIDANCE`, `M404_SITUATION_PRIORITY`, `M404_GUIDANCE_NOT_APPLICABLE`. No arbitrary reason string at the policy boundary.

RESCUE/RETREAT have no v1 guidance type: with active applicable Guidance displaced by RESCUE, response is REFUSED/M404_SITUATION_PRIORITY, behavior_changed=false because baseline=selected; it is not FOLLOWED HELP. NONE stays NONE; inapplicable Guidance is NOT_APPLICABLE. Existing v1-only behavior uses existing causality, including MATCHED_INDEPENDENTLY and genuine FOLLOWED only when Guidance changes action/target. Any unsupported v1 state must use separately reviewed M4 policy rather than synthetic HP/context. This includes Player DOWN and retained Party lifecycle unavailable to old v1.

**No impact authorization:** CANDIDATE_ONLY describes a legal candidate at observation time. Owner must still validate current slot/revision, lock real token, revalidate actor/target/episode/resources at impact, atomically apply and issue a receipt on real completion. A stale candidate must be rejected/recomputed before lock, not treated as already executed. No retarget after lock, no resource reservation from output, no effect/receipt/opportunity on reads, rejection or design blockage.

### 4.1 Refusal semantics

`refusal_type` is one of `NONE`, `HELPER_PRIORITY`, `RECIPIENT_REFUSAL`, `REQUEST_REJECTION`, `EFFECT_SKIPPED`. These are separate outcome categories, not synonyms. This pure decision output emits only NONE or HELPER_PRIORITY; INVALID_INPUT is a validation result, not a recipient decision. REQUEST_REJECTION belongs to a separate request result; EFFECT_SKIPPED belongs to an actual owned post-lock effect report and must never overwrite locked decision metadata. RECIPIENT_REFUSAL is reserved, **not producible in this scope**.

HELPER_PRIORITY requires a legal aid candidate displaced by a higher priority (e.g. Safety), not merely no resource. No rescue use is inability with NO_RESCUE_USE/NONE; it is not unwillingness. A malformed/foreign/resource-invalid request is rejected without action/consumption. A once-valid locked RESCUE whose episode/state changes is SKIPPED with actual transaction reason, no rescue delta/use consumption; completion remains owned. Unconscious DOWN has neither active consent nor active refusal; no consent boolean or default “accepted” fiction is added. Existing living-Player HELP remains unchanged without recipient-refusal gameplay.

## 5. Deterministic priority matrix

**Approved order:** Safety → Urgent RESCUE → Existing HELP → Nonurgent RESCUE → RETREAT / Existing Action. The old architecture §9's preemptive conditional RETREAT row is historical proposal, **not current priority authority**. No RETREAT can jump legal urgent/nonurgent RESCUE under this approved order.

**O1-A approved detailed predicates:** legal rescue set R contains other Party DOWN/PRESENT with active matching episode, helper ALIVE/PRESENT and rescue use>0, actual eligible slot and nonterminal owned boundary. Urgent subset U: `entry_round < current_round AND budget == 1`; grace (`entry_round == current_round`) is not urgent. This means “would expire at the next eligible natural close”, not predicted death during a pending action; strict seal still forbids close with outstanding work. B2/no grace and B2/grace are nonurgent. O1-A approves this urgency formula; B1 with entry-round grace is invalid, not a special urgency tie.

| Priority / authority | Preconditions | Result / reason | Fallback / tie-break |
|---|---|---|---|
| Gate — existing lifecycle direction, O5-A adapter details | Valid observation, eligible current NPC opportunity, nonterminal OPEN/READY | Continue; otherwise null/NO_ACTION or INVALID_INPUT | Never invent Player command or opportunity; latest state each slot |
| 1 Safety — **approved existing predicate** | First still-valid hit aimed at self has damage>0; HP≤30% OR damage≥HP | DEFEND self; SELF_LOW_HP_THREAT takes precedence if both, else SELF_LETHAL_THREAT | False →2. No summed hits, Courage or new threshold; existing Guard behavior |
| 2 Urgent RESCUE — **O1-A/O2-A approved** | U nonempty | RESCUE ranked U; M404_URGENT_RESCUE | Empty/unavailable →3; annotate excluded candidates, no fake RESCUE |
| 3 Existing HELP — **preserved rule** | Living PRESENT Player HP≤30%, NPC HELP use available; Safety/U absent | HELP Player; PLAYER_LOW_HP_HELP | Unavailable →4 with HELP_UNAVAILABLE; HELP never rescues DOWN |
| 4 Nonurgent RESCUE — **O1-A/O2-A approved** | R nonempty; higher priorities absent | RESCUE ranked R; M404_NONURGENT_RESCUE | Empty →5; no ATTACK while legal rescue exists at this tier |
| 5 RETREAT / Existing Action — **O3-A approved** | Current legal NPC ALIVE/PRESENT slot, nonterminal, active Enemy≥1, no priority1–4, HP×100≤maxHP×30 | RETREAT self; M404_SELF_PRESERVATION_RETREAT | HP>30% → existing-action branch. Unavailable/terminal/no Enemy → owner boundary/no action. No trait weighting, random roll, new cost/cooldown/resource |
| Existing-action branch — **existing rules only, effect bridge subject to O6** | Higher priorities and O3-A RETREAT false, at least one available Enemy | First available Enemy ATTACK; preserve existing HELP_UNAVAILABLE_ATTACK when relevant, else ATTACK_AVAILABLE_ENEMY; existing Guidance may produce FOCUS/discretionary DEFEND | Stable Enemy order; exact existing approved profile predicates only; no available Enemy → owner terminal boundary, no fake attack |

**O2-A approved exact target ranking:** within chosen rescue tier, sort ascending `(budget, entry_order, stable_party_index)`. Oldest active episode wins equal budgets; Player gets no extra weight. `entry_order` is global, so valid distinct episodes normally cannot tie in its ordinal. Stable index is an explicit total-order fallback: equal-ordinal fixtures are comparator-only adversarial diagnostics, rejected by provenance validation as live contexts. Do not claim such a live tie was exercised. Same actor re-DOWN uses a new episode/order; retired episode cannot win. Each next NPC reranks from new state after real preceding effects; no precomputed whole-round plan.

## 6. Guidance and lifecycle compatibility — A33–A39

Existing request remains exact8: `schema_version, guidance_type, issuer_player_id, preferred_target_id, encounter_id, generation, round_id, expected_guidance_revision`. Existing types NONE/ATTACK/DEFEND/HELP/FOCUS_TARGET; preferred Enemy is never reinterpreted as a RESCUE target. Adapter records above never enter v1 requests/Resolver/Layer; only explicitly constructed existing schemas may be passed on a supported state. No new schema fields, counters, R1 rules or production API in this task.

[R1 Option A](../tests/npc/README.md#r1-option-a--current-m3a-04-contract): accepted submission including unchanged content +1; successful command-ready unregister of the preferred Enemy clearing Pending FOCUS +1 before NONE. Reads/rejects/HP0/unrelated removal/freeze/completion/terminal do not increment; Restart new generation/rev0. Life state change is not unregister. Retained HP0 Enemy can remain known preference data but cannot be an effect target.

| Architecture row | Required compatibility / boundary (design, not execution evidence) |
|---|---|
| A33 | Accepted Pending freezes only on successful Begin. Player DOWN during running nonterminal round leaves Frozen/locked reports unchanged; no new submission/revision bump; NPC still chooses from latest state |
| A34 | Natural close/next valid round produces Pending NONE with new round identity; still-DOWN Player cannot submit. Autonomous continuation needs real eligible NPC opportunities, no fake Player DEFEND/command. No Pending/Frozen carried across rounds |
| A35 | RESCUE does not unlock input mid-round or reinsert a disposed Player slot. At next valid ALIVE/PRESENT command-ready boundary read fresh identity; old round rejects when identity validation reached; fresh v1 submit +1 |
| A36 | Strict Option A rejects exceptional command-ready Player eligibility transition before HP/life/Pending/revision/queue mutation. Deliberately forced fixture is isolated from production submit/Begin |
| A37 | Forced pre-round DOWN→RESCUE→HP-positive in same identity cannot re-arm accepted Pending or old Player Command. Recovery only through valid reset boundary with Pending NONE; initial isolated exceptional path uses valid Restart/new generation, not fabricated round advance |
| A38 | Valid Restart clears old identities/active/frozen references and resets Guidance rev0; old request rejects STALE_GENERATION when that check is reached; invalid Restart no partial writes. Preserve C's SEALED Abort→Restart requirement |
| A39 | Preferred Enemy unregister follows exact R1 +1; stale revision request rejects; fresh FOCUS on removed ID rejects unknown target. HP0/unrelated/failed removal/reads do not increment. Frozen unavailable target at slot is NOT_APPLICABLE; post-lock invalid target produces actual SKIP, no retroactive decision rewrite |

Existing validation precedence is retained: running request may receive COMMAND_LOCKED before identity checks; WRONG_ROUND/STALE_GENERATION are asserted only at eligible command-ready checks. Exceptional M4 rejection names remain proposed, not new production codes. Full production D09 and runnable combined HELP/Guard/Guidance with M403 remain dependencies, not claims that C already supports them.

## 7. Paired and adversarial acceptance design

**Historical PR #54 design matrix: PROPOSED / NOT RUN at that checkpoint.** Expected behavior uses the approved O1-A/O2-A/O3-A/O5-A rules. These design rows are preserved, not globally relabelled PASS; the implementation mapping below identifies executed slices and remaining gaps. Pure comparator/fixture diagnostics are labelled; no historical C evidence makes any M404 row PASS. [Original A01–A39](M4_Down_Help_Death_Retreat_Architecture.md#13-acceptance-matrix--future-scenarios-not-run) retain their historical text and status. A references map only the stated slice, not whole-row completion.

| ID / pair | Controlled input / adversarial variant | Expected decision and actual-effect boundary | Mapping |
|---|---|---|---|
| M404-01 Safety vs urgent rescue | Self3/10, first valid self hit3, other DOWN B1/no grace/use1; pair self10/10 | DEFEND self / RESCUE. First has HELPER_PRIORITY, no rescue consumption; second candidate requires real transaction | A06,A07 |
| M404-02 First-hit fidelity | Self5/10, two valid self hits3+3; pair first attacker unavailable; pair self3/10 first valid hit3 | No aggregate-lethal Safety in first two; last Safety. A zero/absent valid threat never triggers low-HP Safety alone | A07 |
| M404-03 Urgent vs HELP | Living Player3/10, other DOWN B1 earlier round, healthy helper/use1 for both; pair B2 | RESCUE vs HELP. HELP remains +4/once/living Player; no shared resource charge | A06,A09 |
| M404-04 Grace and nonurgent vs ATTACK | Player healthy, other DOWN B2 current entry vs B2 previous entry, helper safe | Both nonurgent RESCUE over ATTACK; B1 previous entry urgent; B1 current entry invalid, not coerced | A06,A09 |
| M404-05 Budget ranking | X B1 older-round, Y B2; swap budgets while valid | Choose lower budget in urgent tier; no Player preference; immutable target/episode once later locked | A09 |
| M404-06 Episode ranking | X/Y B1, orders7/8; swap valid provenance order | Choose older episode. Pure comparator-only equal orders chooses lower stable index; live duplicate ordinal rejects, not a passing integration case | A09 |
| M404-07 Sequential freshness | NPC1 rescues X; then NPC2 slot with X alive/Y down; pair X re-DOWN new episode | NPC2 selects from current eligible episodes/resources, not cached X decision; old episode rejects at effect. No extra slot | A09 |
| M404-08 No rescue resource | Same DOWN candidate/use1 vs use0, Safety absent, living low Player HELP available | RESCUE if urgent/use1; HELP/use0 with NO_RESCUE_USE/NONE. If HELP also unavailable and no other rescue, HP≤30% with O3-A gates → RETREAT; HP>30% → existing ATTACK branch. No-use remains inability, not refusal | A06,A07 |
| M404-09 DOWN recipient consent | DOWN unconscious, no consent data; pair supplies consent/refusal key | Legal rescue candidate without active consent/refusal; unknown field rejects. No recipient-refusal gameplay or fabricated acceptance | A27 |
| M404-10 Helper vs recipient refusal | Legal urgent aid displaced by Safety vs hypothetical conscious refusal | First HELPER_PRIORITY; second deferred/unsupported, never emitted as if implemented. No-use variant is inability, not refusal | A07,A27 |
| M404-11 Reject vs SKIP | Invalid protocol/foreign identity/no-use request before lock vs valid owned lock then changed target episode | First actual request rejection/no action; second actual effect SKIPPED/no HP or resource delta, original decision immutable. If no legal interleaving producer, diagnostic-only, not fabricated integration PASS | A27,A24 |
| M404-12 RETREAT vs higher priorities | Self3/10 in legal nonterminal slot with active Enemy; vary first valid self hit, urgent rescue, living-Player HELP, nonurgent rescue, then none | Respectively DEFEND / urgent RESCUE / HELP / nonurgent RESCUE / RETREAT self. RETREAT reason M404_SELF_PRESERVATION_RETREAT; execution still needs owned transaction | A06,A07 |
| M404-13 Player DOWN continuation | Player DOWN, NPC eligible real slot; pair NPC also unavailable or all enemies unavailable | M4 decision may rescue despite old v1 PLAYER_DEFEATED. Unavailable/terminal boundary produces no action; no forged positive HP, command, receipt or opportunity | A06,A33,A34 |
| M404-14 Frozen and autonomy | Frozen ATTACK vs HELP while urgent rescue exists; pair NONE | Rescue independently both; REFUSED/situation reason vs NONE, unchanged baseline/selected and Frozen. HELP guidance never means RESCUE | A06,A24,A33 |
| M404-15 Old Pending after rescue | Accepted Pending pre-round, external DOWN attempt vs forced isolated DOWN→RESCUE | Rejected event leaves all state unchanged; forced fixture cannot submit/Begin/re-arm same identity even with HP positive. Only valid reset exits isolation | A36,A37 |
| M404-16 Wrong round / generation | Running round old request vs command-ready old-round request; repeat after Restart with same numeric revision | COMMAND_LOCKED when prior gate; otherwise WRONG_ROUND / STALE_GENERATION as applicable. No mutations/revision increment on reject | A34,A35,A38 |
| M404-17 Preferred Enemy R1 | Pending FOCUS then unregister preferred vs HP0/unrelated/failed removal/read | +1 and NONE only in first; stale client rejects; fresh removed target unknown; no lifecycle-triggered revision | A24,A39 |
| M404-18 Rescued Player input | Rescue before vs after Player disposed slot; attempt input during running then next valid boundary | No extra/reinserted slot or mid-round command. New valid command only at boundary; no synthetic completion | A35,A37 |
| M404-19 Context integrity | Extra field/type coercion/mixed owner revision/wrong queue/foreign episode/noncurrent slot vs coherent observation | INVALID_INPUT/no action/no writes vs candidate; old frozen identity and caller-made provenance cannot authorize effect | A09,A24,A38 |
| M404-20 v1 isolation | Exact existing request vs added lifecycle/RESCUE field; valid v1 living-state comparison vs Player DOWN | Existing schema acceptance/rejection unchanged; supported state preserves v1 reasons; unsupported state never forwarded or patched with fake HP | A24,A33–A39 |
| M404-21 O3-A threshold boundary | No higher priority, legal slot/nonterminal/active Enemy; HP30/100 vs31/100 | RETREAT self / existing action; no new Courage/Trust/Compassion effect | A07 |
| M404-22 O3-A action eligibility | HP0/DOWN, DEAD, ALIVE/RETREATED, disposed/noncurrent slot, terminal or no active Enemy vs eligible low-HP NPC | No selectable action in invalid/unavailable boundary; no fake RETREAT/receipt/opportunity; valid case candidate only | A07,A24 |
| M404-23 O2-A replay provenance | Seed then real journal creates episodes, re-DOWN, Restart; pair forged/detached/missing/mixed-revision creation order | Ordinals match owner creation replay, new episode new ordinal and generation reset; invalid provenance yields INVALID_INPUT/no action/no mutation | A09,A38 |

### 7.1 Implemented candidate coverage mapping

[Executed cases and assertions](../tests/actors/evidence/m4-04/m4-04-scenarios.json) and [M404-01–20 mapping](../tests/actors/evidence/m4-04/coverage.json) record 121 pure cases, five owned-transaction cases, one diagnostic-only case and one blocked-dependency case. M404-08/10/11/16/18/20 remain PARTIAL; M404-15 is DIAGNOSTIC-ONLY and M404-17 BLOCKED DEPENDENCY. No design row is wholly passed by a pure fixture or inherited C evidence.

| Additional approved design group | Executed proof slices (M404 case IDs) | Remaining boundary |
|---|---|---|
| M404-21 O3 threshold | 011/012/013 (exact30%,31%, higher priority), 126 (owned RETREAT) | No production RETREAT integration or visual acceptance |
| M404-22 O3 eligibility | 057–067 (nested Party schema), 049–056 (nested queue schema), 115/124/126/128 (owner binding, stale context and transaction lifecycle) | PARTIAL: schema rejection and owned boundary slices only; the complete unavailable/lifecycle/terminal/no-Enemy matrix is not independently enumerated by M404 |
| M404-23 O2 replay provenance | 009 (ranking and comparator-only tie), 084–089 (episode schema including ordinal), 115/124 (current owner binding), 128 (real later DOWN/re-DOWN/Restart) | Comparator tie is pure-only; duplicate live ordinals reject; no production performance claim |

Pure decision success cannot prove transaction completion or visual quality. Source, commands, exact case mapping and fresh results are audited in the separate post-rebase record.

## 8. Risks, remaining owner subdecisions and stop

| ID | Open dependency / risk | Candidate evidence / remaining review |
|---|---|---|
| O1 D08 urgency | **APPROVED O1-A**, §2.1 | Implemented candidate; executed urgency/grace pairs in focused proof |
| O2 D08 ranking | **APPROVED O2-A**, §2.1; order projected by isolated candidate | Candidate validates seed/journal replay against current root; no opaque-ID decoding or provenance fallback |
| O3 D08 RETREAT | **APPROVED O3-A**, §2.1; new isolated HP≤30% gameplay rule | Candidate requires higher priorities false and legal slot/nonterminal/Enemy gates; no trait behavior |
| O4 D16 consent | Conscious-DOWN and recipient refusal not modeled | Separate contract/approval; keep no active consent/refusal for unconscious DOWN |
| O5 D09 adapter | **APPROVED O5-A**, §§2.1/3–4, isolated only | Candidate exact schemas/current-root binding covered; full production D09 outside approval |
| O6 Effect bridge | C has no HELP/Guard/production Guidance integration; output does not authorize execution | Separate reviewed owner/executor seam, current slot/episode revalidation, real receipts and retained no-progress limitations |
| O7 Evidence | Proposed cases may lack legal effect producers; historical C diagnostic/partial rows remain | Label pure/diagnostic/blocked accurately; never create fake actions, receipts or opportunities to close a test |

Learning check: explain why “decided RESCUE” does not mean “rescued”, why no-use is not recipient refusal, why HP-positive recovery cannot re-arm old Pending, and why global episode age differs from per-actor episode count. Compare the paired pure cases with the supported owned-transaction cases.

Current reconciliation retains the approved §2.1 and architecture register byte-for-byte. Documentation links, anchors, source hashes and fresh Godot results are recorded in [post-rebase evidence](../tests/actors/evidence/m4-04/post-r54-rebase.json); original run records remain attributed to their original source. Manual GUI/F5/F6/keyboard/visual acceptance NOT RUN.

**Delivery stop:** existing Draft PR #55 / Awaiting Independent Follow-up Code & Evidence Review. Do not merge, enable auto-merge, delete the branch, create a replacement PR, start M4-05 or integrate Production/Main/Legacy/Guidance. O4/O6/O7 remain deferred/blocked as described above.
