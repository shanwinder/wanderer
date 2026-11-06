# M4-03 — Queue / Retreat / Outcome Contract & Owner Decision Gate

**Current design approval — 7 November 2026 (Asia/Bangkok): D07/D10/D11/D14/D15 = APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only.** Owner source and exact selections are recorded in §12. **M4-03 Design Decisions Approved / Awaiting Implementation Task Authorization.** PR #49 remains Design-Only / Draft / unmerged; implementation is NOT authorized. Original proposal/conditional wording records design intent and alternatives, not runtime or verification. Current scoped approval supersedes historical pending wording only for these five isolated decisions; full production extensions remain Pending.

[Documentation index](README.md#current-status-and-next-roadmap) is the sole Milestone Authority. This specification extends the [M4 Architecture](M4_Down_Help_Death_Retreat_Architecture.md) and [M4-02 contract](M4_02_Rescue_Clock_Death_Contract.md); it does not replace their historical decision/evidence records. A01–A39, M401, M402 and M3 assertions are unchanged. No M4-04/M4-05 work is authorized.

## 1. Objective and baseline

ออกแบบ isolated proof ที่ตอบได้ว่าใครมีสิทธิ์ใช้ slot, Player DOWN แล้วใครเดินคิวต่อ, RETREAT เป็น action ของใคร และเมื่อใด encounter จบพร้อม summary ที่ไม่ทำข้อมูลคนหาย. ต้องป้องกัน deadlock, duplicate slot/outcome, stale callback และ fake round close โดยรักษา Strict Seal, B2/grace, action impact/completion และ Restart identity. การพิสูจน์ scheduler ไม่เท่ากับการพิสูจน์ NPC เลือกช่วย/หนีเอง.

### Repository preflight recorded in this design task

| Check | Actual observation |
|---|---|
| Repository / requested canonical | `shanwinder/wanderer` / `visual-combat-test-1` |
| Initial working tree / branch | Clean / `visual-combat-test-1` |
| Local, fetched origin, live remote, merge-base | All `383598f946bbe0f9747e3b81b82b07dfb5c6b8bf`; no newer canonical at preflight |
| PR #46 | Merged `e6c3cab7291a3cd45dcacdf48406cf48f0d67118`; isolated Data/State proof |
| PR #47 | Merged `4969f32d5de1d1795968bdab5c3a85bbfe00c460`; scoped design decisions / Strict Seal |
| PR #48 | GitHub merged=true; merge `383598f946bbe0f9747e3b81b82b07dfb5c6b8bf`, 6 Nov 2026 13:02:25 Asia/Bangkok. Single parent `4969f32`; squash of PR head `4765b0c0ec555728ab5eb834bfc81faf9a1124cc` |
| Old feature / duplicate work | Local/remote branch inventories have no PR #48 feature branch; no M4-03 branch or design PR. Open PR search returned #2/#17 only; all-state M4-03 search found historical references, no dedicated M4-03 PR. Nothing to clean up |
| PR #2 / #17 | Open/Draft/unmerged; their heads `fac99aa` / `c162d63` are not ancestors of this base. No merge/cherry-pick; `docs/GAME.md`/`WORLD.md`/`WORKFLOW.md` proposal does not become canonical |
| This task branch | `codex/m4-03-queue-retreat-outcome-design-gate`, created from verified canonical |
| Source of authority | Owner's attached M4-03 Planning & Owner Decision Gate task dated6Nov2026; permits this document/Draft, not runtime/tests or selecting pending options |

Read AGENTS/root/index, architecture, M4-02, actor/combat test guides, v0.1 and v0.4 plus relevant source below. Git fetch/live remote was checked with network access; branch creation required ordinary sandbox escalation for `.git`, not a new gameplay authorization.

### Implemented / verified / proposed are different claims

| Layer | Scope and evidence |
|---|---|
| **Implemented fact — merged source** | M4-01 isolated Party model has four valid pairs and atomic fixture HP0→DOWN. M4-02 separate aggregate has owned RESCUE, episodes/uses, finite completed witness, Strict Seal, ROUND_CLOSED batch clock/death and generation-safe Restart. Production remains HP-only / Player HP0→DEFEAT |
| **Verified fact — Recorded Evidence from PR #48** | Godot `4.7.2.stable.official.ed1daf0bf`, executable `/Applications/Godot.app/Contents/MacOS/Godot`, tested fix `a8dda626aa268bc243dfaac827b70a5465eaa7e9`; delivery `4765b0c…` added documentation/evidence only. **55 focused cases / 1,188 assertions / 0 failures; 73 stages PASS**. M4-01 **78 cases / 525 checks**; fresh canonical of that task (`4969f32`) **69 stages PASS**; Legacy **6 cases / 5,892 frames identical** |
| **Independent review — recorded, not rerun here** | [R48-01 review](https://github.com/shanwinder/wanderer/pull/48#pullrequestreview-5795418762) found reserved-ID collision; [follow-up](https://github.com/shanwinder/wanderer/pull/48#pullrequestreview-5795655645) on `4765b0c…` recorded R48-01 RESOLVED / Code & Evidence Review PASS. Reviewer did not independently execute Godot or unpack/revalidate raw ZIPs |
| **Proposed behavior — this document** | M403 queue eligibility, self-retreat, Player-unavailable scheduling, outcome and summary. No executable M403 proof exists; all matrix rows **PROPOSED / NOT RUN** |

PR #48 expected all executable suites PASS, no unexpected errors/timeouts and equal Legacy traces; recorded actual agrees within that scope: all final exits0, five expected negative errors accounted separately, 19 inherited suite counts equal, 111 tested hashes match and89 protected files unchanged. Exact commands/engine/commits/expected-actual: [run-record](../tests/actors/evidence/m4-02/run-record.json); [73-stage results](../tests/actors/evidence/m4-02/final-results.json), [canonical69](../tests/actors/evidence/m4-02/canonical-results.json), [focused scenarios](../tests/actors/evidence/m4-02/m4-02-scenarios.json), [coverage](../tests/actors/evidence/m4-02/coverage.json), [logs](../tests/actors/evidence/m4-02/logs.zip), [Legacy differential](../tests/actors/evidence/m4-02/trace-comparison.json). None is a new run on `383598f` or this design HEAD.

**Coverage retained:** M402-06 BLOCKED end-to-end (pending rescue prevents natural close/death); M402-24 PARTIAL (authenticated unused wrong-round event has no legal issuer path); M402-D01/D02/D04 BLOCKED, D03/D05 DEFERRED. D10/D15 isolated design is now approved; production extensions remain Pending. Historical M402 blocked/partial coverage is unchanged. Manual GUI/Keyboard/Visual Acceptance NOT RUN. M4-02 is not Production Gameplay Integration. Candidate/pending statements in prior test guides/contracts remain historical checkpoints, superseded only by the index's current milestone status.

## 2. Source architecture and design alternatives

The following are **implemented facts from inspection**, not new runtime verification.

| Source / relevant methods | Actual responsibility and gap |
|---|---|
| [M4 Party state](../scripts/m4/isolated_actor_state.gd) `create/from_snapshot` | Exact8 snapshot fields; ALIVE/PRESENT, DOWN/PRESENT, DEAD/PRESENT, ALIVE/RETREATED. ALIVE iff HP>0; eligibility = ALIVE and PRESENT. RETREATED is Participation, **not a fourth LifeState**. Snapshot detached; no public lifecycle setter |
| [M4 Registry](../scripts/m4/isolated_registry.gd) | Copies/validates one runtime per stable ID; Party model versus original Enemy HP/can_act. Capability-gated fixture damage. No death-as-unregister or shared mutable snapshot |
| [M4-01 Encounter](../scripts/m4/isolated_encounter.gd) | Exact6 damage request/7 token, current revision, consumed operation, validated Restart generation+1/revision0. No rescue/clock/queue/terminal APIs; preserve absent-API assertions |
| [M4-02 aggregate](../scripts/m4/isolated_rescue_clock_encounter.gd) `_publish/_valid_candidate` | Reconstruct candidate Registry plus ledgers; one synchronous root publication. Registry owns HP/life/participation; episode/resource ledgers do not mirror HP. Atomicity is bounded single-threaded correctness, not hostile-code security |
| M4-02 `lock_rescue/impact/complete/cancel` | request8/action13/event10 unchanged. Exact owned token; lock_revision is audit, not blindly compared with every newer live revision. Revalidate helper/target/episode/use at impact; success HP1/ALIVE, retire clock/use−1 together. Complete does no second effect; cancel only LOCKED |
| M4-02 `lock_fixture_slot/seal/_boundary` | Issuer reserves **all `slot_` prefix**, including future rounds (R48-01). Real fixture damage/completion produces receipts. Seal requires nonempty expected slots, all receipts, no outstanding work and eligible Player/Party/Enemy. Fixture slots are Party damage operations, not a production NPC/Enemy queue |
| M4-02 `apply_round_closed/next_round/abort_round/restart` | OPEN→SEALED→CLOSED or OPEN/SEALED→ABORTED; close batch B2/grace/B1/DEAD and semantic dedupe. Explicit finite next round; no automatic scheduler. SEALED accepts only owned close/pre-issued Abort; valid Restart requires Abort first. Abort adds accounting only, no close/tick/death |
| [FullPartyEncounter](../scripts/combat/full_party_encounter.gd) | `begin_round` accepts Player ATTACK/DEFEND; stable Player→NPC→Enemy queue; declared Enemy targets (default Player). `begin_next_action` decides per slot; unavailable actor currently gets a SKIP token. Player fallback occurs before lock; impact revalidates and does not retarget after lock |
| FullPartyEncounter `resolve_action/complete_action/_update_terminal/_finish_round` | One effect and completion per owned token. Player unavailable→DEFEAT checked before Enemy exhaustion→VICTORY; terminal clears pending/input/Guidance. `_finish_round` increments once and creates next Pending NONE; it is **not** a witnessed M4 ROUND_CLOSED API |
| [GuidedEncounter](../scripts/combat/guided_encounter.gd) / [Decision Layer](../scripts/npc/guidance_decision_layer.gd) / [Resolver](../scripts/npc/npc_decision_resolver.gd) | Per-slot independent approved policy and frozen response metadata. Resolver returns `PLAYER_DEFEATED` at Player HP0; strict context requires HP-based can_act. Layer capabilities ATTACK/DEFEND/HELP/FOCUS_TARGET only. Cannot obtain NPC continuation by merely ignoring production defeat or supplying fake Player HP |
| [Guidance contract](../scripts/npc/guidance_data_contract.gd) / [controller](../scripts/combat/combat_prototype.gd) | `_autonomous_command` submits eight-field Guidance then begins round; unsuccessful command can leave accepted Pending. Frozen/round/generation identities, R1 Option A, UI drafts and callback token/phase guards already exist. Result UI treats VICTORY as bool; cannot display proposed withdrawal outcomes without later integration |
| [Legacy flow](../scripts/combat/combat_turn_flow.gd) / [targets](../scripts/combat/combat_targets.gd) / controller | Scripted ATK/GUARD; NPC2 Guard after Player Attack, all attack after Defend; original target fallback, living-enemy counters, round completion, Restart/Tween cancellation. Not NPC autonomy evidence |
| [Existing runner](../tests/combat/verify.py) / [combat guide](../tests/combat/README.md) | Fresh snapshot/import/parse/main startup/gameplay/negative tests, optional M4 data and atomic-clock flags. Unexpected errors fail even exit0; negative exactly5 separate; source manifests and Legacy trace/count checks. No M403 flag exists |

### Architecture comparison — recommendation remains proposed

| Approach | Benefit | Cost / decision |
|---|---|---|
| Extend production FullParty/GuidedEncounter now | Reuses real command/UI flow | Touches terminal, strict policy/schema, Legacy-shared controller and visual lifecycle at once; outside authorization. Reject for this bounded proof |
| Wrap the live M4-02 fixture with a queue | Reuses tested fixture API | `_boundary` blocks Player DOWN/Enemy0; expected damage slots cannot be replaced with skip receipts; sequential queue/root writes break atomicity. Do **not** weaken seal, forge receipts or teach its fixture issuer to be production scheduler |
| **New isolated M403 aggregate + queue adapter, existing M4 factories preserved** | Explicit eligibility, identity and terminal owner; can compare old M4 proofs unchanged | New reviewed witness schema and effect orchestration; duplicated semantic contracts require parity tests. Recommended after decisions/task authorization, with one published root, not two live aggregates writing sequentially |

M403 may reuse validated state/Registry factories and the **semantics** of M4-02 rescue/clock via a separately reviewed candidate calculation seam in new files. It must not call existing M4-02 public mutation methods then try to roll them back after queue/outcome failure. No extraction/change to M4-02 is pre-authorized. If sharing requires edits there, return a concrete file-level proposal for review. Original M4-02 remains its own conservative issuer; M403 Player-independent admission is a **new D15-approved contract**, not evidence that M4-02 already permits it.

**Intent gap:** v0.1 expects NPC continuation after Player death and eventual carry/permadeath consequences; current Main terminates at Player HP0. M403 can bound the scheduling question but does not silently fulfill the full vision, final Turn System, Speed Order or post-combat fate.

## 3. Owner decision package

Owner selected **Option A for all five decisions — APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only** on 7 November 2026; exact source/scope is in §12. Alternatives, suggested approval wording and “if not approved” consequences below preserve the reviewed decision package. They do not override this approval record. Only the scoped five decisions and reviewed isolated §4–§9 contract are approved; no implementation or production extension is authorized.

| Decision | Option A | Option B | Recommendation / scenario impact | Status |
|---|---|---|---|---|
| D07 Retreat success | Deterministic valid self-retreat at owned impact | Threat/escape contest, rule/resource inputs still to design | A: healthy Player's valid slot exits only Player; B could consume a real slot but leave them PRESENT after failure | APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only |
| D10 Terminal outcome | Party/enemy active-state classifier, withdrawal distinctions, frozen result | Preserve immediate Player-unavailable DEFEAT | A: Player DOWN + live NPC continues; B ends before NPC can rescue in that encounter | APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only |
| D11 Summary | Separate Party Lifecycle / Enemy Combat rows | Unified lifecycle rows; requires approved Enemy mapping | A: DOWN ally stays DOWN and Enemy HP0 says unavailable; B cannot assign Enemy DEAD without D14 expansion | APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only |
| D14 Enemy scope | Existing HP/availability only, no lifecycle migration | Design Enemy DOWN/DEAD/RETREAT in later scope | A keeps proof small; B changes target/outcome/clock domains and needs a new reviewed package | APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only |
| D15 Player unavailable | Deterministic eligible NPC/Enemy slot continuation, no Player command | Suspend at Player-unavailable boundary | A enables scheduler-only continuation; B freezes clock/progress pending explicit recovery decision, never auto-kills | APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only |

### D07 — self-retreat

- **Existing/problem:** only ALIVE/RETREATED seeds exist; no runtime RETREAT action. Exiting by removing ID would lose summary identity; direct participation writes would bypass lock/impact/completion.
- **A:** eligible Party actor owns one self-target RETREAT in its existing slot. Valid impact deterministically succeeds; before-impact unavailability produces a one-shot SKIP. No resource/item/escape roll; cost is the one scheduled action opportunity. Exact contract in §5.
- **B:** a declared threat/escape contest may fail with PRESENT retained and actual slot spent. Threat snapshot, success predicate, resource payment and reason precedence need another design; no threshold/chance invented here.
- **Recommendation/benefit/trade-off:** A isolates transaction/queue correctness and is easy to predict in the v0.4 learning loop; not final difficulty/balance. It permits cost-free escape beyond spending the action opportunity, so later challenge design remains open.
- **Risk:** Medium for isolated transaction, High at last-active departure/outcome. **Dependencies:** D02, D10/D15 for terminal/continuation; D08/D16 for autonomous choice/consent outside proof.
- **Exact boundary:** validated self-retreat for Party in an isolated owned slot; nonterminal fixture first, last-active case only after D10/D15. **Excluded:** team command, evacuation/carry, Enemy retreat, UI, inventory, randomness, resurrection, unregister.
- **Suggested approval:** “อนุมัติ D07 Option A เฉพาะ isolated M403: ALIVE/PRESENT self-retreat ใน slot เดิม, deterministic success ที่ impact, no resource/contest/carry/extra slot; completion และ retained ID ตาม §5; ยังไม่อนุญาต implementation.”
- **Acceptance:** M403-01–10, 22, 43. **If not approved:** no RETREAT transaction/terminal withdrawal implementation; passive seeded-state eligibility can be separately scoped. B requires revised matrix before coding.

### D10 — outcome classification

- **Existing/problem:** `_update_terminal` prioritizes Player unavailable over Enemy exhaustion. This is implemented production behavior; it prevents Player rescue windows irrespective of live companions.
- **A:** classify the complete post-effect/post-tick snapshot using §7's explicit precedence. Player DOWN alone is nonterminal while active Party and Enemy remain. No active Party yields defeat/withdrawal categories without changing life states.
- **B:** retain Player immediate DEFEAT. Simpler migration and current UI fit, but active NPC cannot save the Player after defeat; does not meet continuation intent. Selecting B overrides neither v0.1 intent nor other pending decisions silently; record the deliberate bounded experiment gap.
- **Recommendation/benefit/trade-off:** A aligns lifecycle and agency while preserving DOWN in summary. More outcome states, simultaneous candidates and terminal/close ordering require explicit owner selection; DEFEAT is loss of encounter agency, not “all dead”.
- **Risk:** High. **Dependencies: BLOCKED DEPENDENCY — D15**, D07 for withdrawals, D11/D14 for frozen results; **full D09 queue/target/Guidance integration remains unapproved**. Isolated no-Guidance proof can be scoped separately; production classifier cannot bypass these dependencies.
- **Exact boundary:** pure classification and one atomic isolated freeze; authorized effects only, no result-screen integration. **Excluded:** aftercare, revival, death from terminal, persistence, player replacement/save deletion, full NPC policy.
- **Suggested approval:** “อนุมัติ D10 Option A เฉพาะ M403 isolated classifier รวม precedence/abort/Strict Seal ใน §7; freeze DOWN ตามจริง, no aftercare. D15 ต้องเลือกแยก และไม่อนุมัติ full D09/production integration หรือ implementation.”
- **Acceptance:** M403-21–30, 33, 41–42. **If not approved:** A/B transactions stop at boundary dependency; no invented victory/defeat/withdrawal, no fake rounds to exhaust clocks. B requires explicit scope/matrix reconciliation with D15.

### D11 — summary domains

- **Existing/problem:** Main result UI reports Player/Enemy HP, not lifecycle roster/archive. Filtering only active actors omits DOWN/DEAD/RETREATED members.
- **A:** separate versioned Party lifecycle rows and Enemy combat rows, exact initial roster ID coverage, frozen with outcome (§8).
- **B:** unified lifecycle rows for every actor, as the existing architecture alternative states. Requires D14 Enemy mapping and separate reviewed schema; not implemented by inventing HP0=DEAD. A generic tagged envelope could host A's two domains, but is not an excuse to call B approved.
- **Recommendation/benefit/trade-off:** A keeps different meanings visible and avoids false Enemy death claims; requires two row validators and consumers. Example: victory with one DOWN NPC must still show that NPC DOWN and both enemies HP0/unavailable.
- **Risk:** Medium, High if ID retention/archive is omitted. **Dependencies:** D02/D10/D14, generation/retained roster; D15 affects freeze boundary.
- **Exact boundary:** in-memory detached snapshot of a validated finite initial roster; no dynamic unregister. **Excluded:** production UI, persistence/permadeath, aftercare edits, resurrection, archival deletion.
- **Suggested approval:** “อนุมัติ D11 Option A เฉพาะ isolated summary v1 ใน §8: Party/Enemy แยก domain, initial IDs ครบครั้งเดียว, freeze พร้อม outcome, detached copies; ไม่อนุมัติ production result screen/persistence หรือ implementation.”
- **Acceptance:** M403-31–36, 41, 45. **If not approved:** inspection snapshots stay diagnostic, not a survivor-summary deliverable; C's summary proof blocks. B first needs D14/schema decisions.

### D14 — Enemy lifecycle scope

- **Existing/problem:** Enemy runtime is HP/can_act only; Party lifecycle cannot be copied onto it without new death/rescue/exit semantics.
- **A:** Enemy HP>0 available, HP0 unavailable; retain IDs and separate combat result. Availability is data, not permission to act after terminal.
- **B:** explicitly design Enemy lifecycle/retreat and mapping in later task. This expands effects, clocks, targeting, terminal categories and tests; not silently part of M403.
- **Recommendation/benefit/trade-off:** A bounds the proof and respects actual data. Asymmetric Party/Enemy semantics are deliberate; Enemy HP0 does not establish lore death. Example: living Enemy remains HP5/available in Party withdrawal summary, yet terminal prohibits its next action.
- **Risk:** Low within A, High for B. **Dependencies:** D10/D11; B needs new lifecycle/target/rescue decisions beyond this package.
- **Exact boundary:** no Enemy LifeState/Participation fields, no Enemy DOWN clock/RESCUE/RETREAT. **Excluded:** Enemy AI extension, corpse/escape consequences and mapping to Party partitions.
- **Suggested approval:** “อนุมัติ D14 Option A เฉพาะ M403: Enemy คง HP/availability และ Enemy Combat Summary, HP0 ไม่ใช่ DEAD; Enemy lifecycle/retreat ยังไม่อนุมัติ; ไม่มี implementation authorization.”
- **Acceptance:** M403-23, 30–32, 46. **If not approved:** keep existing Enemy runtime untouched; cross-domain classifier/summary C blocks until scope chosen. B is a separate design, not a code toggle.

### D15 — Player-unavailable continuation

- **Existing/problem:** Player input begins every production round; HP0 causes DEFEAT; Resolver itself returns PLAYER_DEFEATED. Merely opening the next round cannot prove independent NPC action selection.
- **A:** isolated queue advances eligible actor opportunities deterministically, independent of Player input. No Player command/Guidance while unavailable; no reinserted Player slot after rescue. Real NPC policy for this new lifecycle is **not** included: test harness supplies explicit slot effects with actor-bound fixture authority, labelled scheduler proof, not autonomy.
- **B:** suspend when Player becomes unavailable after settling the active action; retain state/clock. Needs a later explicitly authorized recovery/abort path. Do not generate DEFEND, fake rescue or empty rounds to escape suspension.
- **Recommendation/benefit/trade-off:** A exposes scheduler deadlocks early and supports autonomy intent later; needs clear slot/round/target boundaries and cannot reuse Resolver v1 in DOWN contexts. B is simpler but progress may remain intentionally suspended and bleed budget is not guaranteed time to rescue.
- **Risk:** High. **Dependencies: BLOCKED DEPENDENCY — D10** for no-active/terminal precedence and **full D09** for eventual production command/target/Guidance integration; D08/D16 for actual NPC rescue/retreat behavior. A and D10-A must be approved as a coherent isolated pair; D10-B defeats Player and preempts A continuation.
- **Exact boundary:** serial, finite isolated plans, owned adapter witnesses, live eligibility; fixture action choice contains no personality/consent rules. No unattended endless round generator; plan exhaustion rejects admission with N-all; any SUSPENDED indication is a derived read-only diagnostic (§4), without a clock event. **Excluded:** production scheduler, player puppet control, NPC policy, new Guidance type, fake HP or permissive v1 schema.
- **Suggested approval:** “อนุมัติ D15 Option A เฉพาะ finite isolated scheduler ตาม §4/§6 พร้อม D10 ที่เลือก: eligible slots ต่อได้เมื่อ Player unavailable, ไม่มี fake command/slot/close หรือ reinsert; fixture effects ไม่ใช่ NPC policy proof; D08/D16/full D09 ยัง Pending และยังไม่อนุญาต implementation.”
- **Acceptance:** M403-11–22, 28–30, 37–40, 44, 47–48. **If not approved:** passive eligibility foundation only; Player-unavailable continuation/close stays blocked, not converted to PASS. B requires explicit suspend/resume boundary review.

## 4. Proposed isolated ownership, identity and API

Everything in §§4–9 is a proposal conditional on decisions. The five decisions do not implicitly approve exact file/API implementation. Names prefixed `M403_` below are **new proposed reasons**, never changes to production/M401/M402 reason strings.

### One publication owner

New `M403IsolatedEncounter` would own a single published root: validated Registry, immutable initial roster orders, generation/revision, queue/witness/action ledgers, round phase, episode/rescue/guard data, terminal and frozen summary. Queue adapter is an **internal candidate builder**; classifier and summary builder are pure. None owns a second live HP, round or result. Candidate validation must include every domain before one root swap; no await/signal/UI/virtual writer during commit. Read snapshots are detached copies. No external callback sets “all done”.

Proposed identity families:

| Object | Identity / authority |
|---|---|
| Actor | Stable validated ID + initial domain/role; initial Party and Enemy sets disjoint, retained until Restart |
| Queue / round | `(session, generation, round_id, queue_id)`; one queue per round. Immutable roster opportunity order Player→NPC order→Enemy order; cursor never rewinds |
| Slot opportunity | `(queue identity, slot_id, actor_id)` assigned once by adapter from initial roster order. A skipped unavailable opportunity is a disposition, **not an action token, empty action or fake completion** |
| Owned action | Adapter-assigned `action_id`/`authorization_id`, current slot, actor, kind, self/target ID, lock revision and window; serial not reused. Caller cannot name issuer keys; typed/domain-separated action/slot/event maps preserve R48-01 protection |
| Close witness | `issuer_id=M403_ISOLATED_QUEUE`, current queue/round, expected opportunity IDs, actual completion receipts, unavailable dispositions with observed revision, outstanding set, sealed revision; all assembled internally |
| Event | Separate event primary key `(session,generation,issuer,event_id)` plus semantic `(session,generation,round_id)`; exact owned event, no caller counters/booleans |
| Outcome / summary | One `(session,generation,outcome_id)` with freeze revision/round and cause; immutable freeze, no new outcome ID on duplicate observation |

**Proposed methods (documentation notation, not executable additions):**

| API | Input / proposed result / authority |
|---|---|
| `restart(fixture, capability)` | Validate complete roster, finite plan, clocks/resources and policy selection before reset; generation+1/revision0, first plan identity OPEN/READY but not admitted, summary ABSENT. No effects/actions issued. SEALED requires explicit pre-issued Abort first |
| `open_round(request, capability)` | Exact version/session/generation/expected_revision/round_id/queue_id. Admit initial READY identity once, or create/admit next finite identity only after CLOSED. Classify first: terminal seed freezes without any action. Nonterminal Player-ready boundary may admit a Player fixture command; unavailable Player uses D15-A, never fake DEFEND |
| `advance(request, capability)` | Exact version/session/generation/expected_revision/queue_id; visit next opportunity once. Record unavailable disposition internally; return next eligible slot or boundary dependency. No action minted for skipped opportunities |
| `lock_self_retreat(request, capability)` | Exact9: `version,session,generation,expected_revision,queue_id,slot_id,request_id,actor_id,kind=RETREAT`; no target argument. Self target derived. Return owned token |
| `impact(token)` / `complete(token)` / `cancel(token)` | Exact token returned by lock; authenticate full owned equality/identity. Effects only at impact. Cancellation only pre-impact; one opportunity spent, no completion receipt fabricated |
| `seal(request, capability)` / `close(event)` | Internal witness plus strict availability/terminal gates; grant owned close, then pre-tick batch candidate. No M402 token/event accepted in this namespace |
| `authorize_abort(request, capability)` / `abort(token)` | Grant only OPEN, apply OPEN/SEALED. Cancel authority from round creation may be pre-issued for terminal-freeze path; do not issue grants in SEALED |
| `classify(snapshot)` / `summary_snapshot(identity)` | Pure classifier cannot publish. Public summary read is absent until freeze, then detached frozen result for matching generation/outcome ID |

Token proposed exact15 fields: `version:int=1, session:int, generation:int, round_id:int, queue_id:String, slot_id:String, action_id:int, actor_id:String, kind:String, target_id:String, lock_revision:int, authorization_id:int, window_id:String, request_id:String, episode_id:String`. RETREAT target=self, episode empty. Other effect kinds require their own exact reviewed validation, not free-form fields. RESCUE would bind current episode with original semantics. No additions to M4-01 snapshot8, M4-02 request8/action13/event10 or Guidance request8.

**Cursor rule:** cursor identifies the first undisposed opportunity. `advance` may atomically record successive unavailable dispositions and stop at the first eligible slot; it never consumes an eligible slot by merely returning it. Returning an already-current eligible slot is a read-only `M403_SLOT_READY`; active token means `M403_ACTION_IN_PROGRESS`. Lock leaves cursor on that actor. Only its first valid completion or pre-impact cancellation disposes that opportunity and increments cursor once; unavailable disposition increments once without an action token. Completion never calls impact. Every advance is bounded by the remaining finite opportunity count; no recursive auto-round loop. Terminal cancellation of remainder is explicitly terminal accounting, not completion receipts.

Request optimistic revision must equal current before grant publication; token `lock_revision` is immutable audit while current state is revalidated at impact. Transactions validate expected live revision again before publication. These two revision purposes must not be conflated. Reused request IDs reject before allocation; no caller can reserve any `slot_` key or internal action/event ID. All integers typed, no coercion; session may be a signed nonzero instance identity, not assumed positive.

**Reason precedence:** exact shape/version/types → session/generation → owned capability/token equality → authenticated duplicate action/event → phase/window/queue/current-slot → request/live publication revision → actor/target/episode/resource → candidate validation. Cancellation replay has `M403_DUPLICATE_OPERATION`; applying a previously cancelled token has `M403_ACTION_CANCELLED`. Malformed/foreign/unissued calls cannot probe domain state by skipping authentication. Domain-specific reasons only expected when earlier gates pass.

**Proposed target boundary (isolated only, dependent on D15 and review of D09 scope):** declare each eligible Enemy's target at round opening as the first ALIVE/PRESENT Party ID in stable Player→NPC order, as the architecture's existing proposed direction states. No such target means classify at an authorized boundary or reject admission N-all while dependencies remain pending; do not target DOWN/DEAD/RETREATED or invent an action. No Enemy retarget after lock; if a declared target becomes unavailable, the real locked action settles SKIP with `M403_TARGET_UNAVAILABLE`, then completes. Fixture ATTACK uses an explicit available opposing target; fixture RESCUE binds a distinct DOWN Party/episode and never falls back. These are bounded fixture declarations, not new NPC policy or changes to production target/fallback. Owner D15 wording includes this declaration rule; full production D09 still requires separate review/approval.

**Additional proposed exact schemas:** close event = M402's ten field names/types with `issuer_id=M403_ISOLATED_QUEUE`, plus `queue_id:String` (eleven fields, separately versioned M403 authority). Witness exact12 fields: `session:int, generation:int, round_id:int, queue_id:String, witness_id:String, expected_opportunities:Array, action_receipts:Dictionary, dispositions:Dictionary, outstanding:Dictionary, aborted:bool, phase:String, revision:int`. All IDs/receipts derive from owned queue/actions; caller supplies neither dictionary. Abort request uses exact `version,session,generation,expected_revision,queue_id,request_id`; its issued token adds owned `round_id,authorization_id,kind=ABORT`. Seal request exact `version,session,generation,expected_revision,queue_id`. All request integer fields are strict ints, version1; all other request fields strings. Event/Abort authorization lives in separate maps from actions. No M402 grant is accepted by M403, even if field shapes overlap.

**No-delta vocabulary:** `N-all` = entire published root including generation/revision, counters/grants, cursor/dispositions/receipts, action/event consumption, actors/episodes/uses/guards/outcome/summary unchanged. `N-effect` = actors/HP/life/participation/clocks/uses/guards/roster unchanged; only the explicitly listed lifecycle accounting may change. Successful mutation protects every unrelated domain. Candidate-validation failure always N-all, including calculated but unpublished summary/death/retreat.

### Strict Seal compatibility and new admission boundary

The M402 issuer cannot be called with different witness fields; no override/patch of `_boundary`. M403 proposes its own exact witness schema and authority, after D10/D15 approval:

1. Finite nonempty owned round plan; no inserted/duplicated actor opportunity, monotonic cursor; each opportunity either has one real action completion receipt or a verified unavailable/cancel disposition. Dispositions are not action receipts.
2. At least one **actual completed action** in the round, not just unavailable/cancel dispositions; no outstanding impact/completion. After the existing protocol gates, `seal()` with no actual completed action returns **REJECTED / `M403_NO_REAL_PROGRESS` / N-all**. It never emits ROUND_CLOSED, changes stored queue phase or allocates a grant. Actual zero-damage legitimate action is not invented to satisfy this gate.
3. Active Party and Enemy remain and classifier is nonterminal. Player availability is **not required only in the new D15-A isolated adapter**. Missing decisions return `M403_BOUNDARY_DEPENDENCY`. A/B stages cannot weaken M402 to reach this state.
4. OPEN→SEALED publishes frozen witness/close grant/post-seal revision. SEALED→CLOSED consumes one semantic close and batch ticks B2/grace/death; only pre-issued Abort is the other mutation. No action/cancel/outcome-only write in SEALED; no unseal/reseal/reopen. Close candidate can include classifier/summary after its tick, in the same single publication.
5. `open_round()` beyond the finite round plan, after the existing protocol gates, returns **REJECTED / `M403_PLAN_EXHAUSTED` / N-all**. Empty/invalid plans remain rejected by existing validation; no-progress/exhausted plans never auto-loop or count clock time. Neither boundary rejection changes the published root, revision, stored queue phase, cursor, dispositions/receipts, round phase/identity, grants/counters, clock, outcome or summary. Explicit next-round identity only after CLOSED; ABORTED needs Restart. This proves finite scheduling safety, not indefinite autonomous gameplay.

**R49-01 — Strict Rejection / derived diagnostic:** `SUSPENDED` is not a published queue state or an accepted suspension transaction. A pure projection of a detached snapshot may return diagnostic `progress_status=SUSPENDED` and `suspension_reason=M403_NO_REAL_PROGRESS` when the OPEN nonterminal queue is fully disposed/drained, no work is outstanding and no actual action completed; or `suspension_reason=M403_PLAN_EXHAUSTED` when the last finite round is CLOSED/nonterminal and no next plan entry exists. These diagnostic fields are separate from `queue.phase`, are not stored/cached in the authoritative root, and create no revision, grant, receipt or side effect. A rejected call does not set the diagnostic: the same snapshot yields the same view before and after it. In particular, no completed action yet while legitimate work remains pending does not itself mean SUSPENDED. Other pending decisions/D15 Option B do not authorize a stored suspension API through this correction.

**Retry / duplicate / stale revision:** for either boundary, an identical well-formed request against the unchanged root/current expected revision returns the same REJECTED reason and N-all on every retry. Rejected `seal/open_round` requests issue/consume nothing and enter no duplicate-request ledger; their schemas have no request ID, so repeating these denials does not become `M403_DUPLICATE_OPERATION`. Read-only diagnostic reads are also repeatable and N-all. No automatic retry loop, cursor advance, plan extension, fabricated action or reset is implied. After any separately authorized publication, validate against the new snapshot: if identity/phase gates still pass but expected_revision is old, return REJECTED / `M403_STALE_REVISION` before the no-progress/plan-exhaustion check, N-all relative to the current root. If an earlier identity/phase gate fails, retain its existing reason and N-all. A refreshed valid request is evaluated afresh and succeeds only if all existing admission/witness gates genuinely pass; previous rejection reserves no identity or right to progress. Existing duplicate owned-action/event rules, Strict Seal, Abort and Restart are unchanged.

Unavailable skipped opportunities are retained for audit, not removed from the immutable plan or manufactured as DEFEND/SKIP actions. This deliberately differs from production's current SKIP-token implementation and remains isolated. Full queue/target/Guidance migration requires a separate D09 gate.

## 5. Proposed RETREAT transaction

| Stage | Preconditions / owner | Mutation / reason / safety |
|---|---|---|
| Admission / lock | Encounter capability; current eligible Party actor ALIVE/PRESENT HP>0, current slot, OPEN/nonterminal, no active action, exact request/current revision | Store owned self-target token and consume no HP/resource; revision+1, `M403_RETREAT_LOCKED`. DOWN/DEAD/RETREATED→`M403_ACTOR_UNAVAILABLE`, Enemy→`M403_PARTY_ONLY`, wrong slot→`M403_WRONG_SLOT`, invalid fields/authority/revision→protocol reason; all rejections N-all |
| Impact success | Exact unused owned LOCKED token, same generation/round/window; actor still ALIVE/PRESENT | Candidate ALIVE/RETREATED, same HP, eligibility false, own guard cleared, retained Registry ID. Record impact result/consumption/revision+1 atomically, `M403_RETREATED`; evaluate terminal on candidate if C approved. No uses charged, no slot appended |
| Impact becomes unavailable | Legal owned LOCKED token but actor is now DOWN/DEAD/RETREATED in a reviewed revalidation fixture | One-shot SKIPPED / `M403_ACTOR_UNAVAILABLE`; N-effect (only result/consumption/phase/revision); complete still permitted. This fixture interleaving is not a production concurrent-action claim |
| Completion | Owned APPLIED/SKIPPED token; current generation; actor eligibility **not required** | COMPLETED receipt once, clear active action, advance only afterward; `M403_ACTION_COMPLETED`. HP/participation/clock/use do not change. If impact froze terminal, terminal settlement lane accepts this one receipt without natural close or new effects |
| Cancel before impact | Owned LOCKED token, OPEN, authority; not already consumed | CANCELLED/disposition once, release outstanding, spend original opportunity; `M403_ACTION_CANCELLED`. N-effect; no refund/extra slot. Old impact denied, no rescue/retreat applied |
| Abort / Restart | Explicit authorized abort, or fully validated reset; SEALED abort first | Abort produces no effect/clock; valid Restart new generation invalidates every old token/callback before reused IDs. Invalid reset N-all. No in-encounter re-entry or resurrection |

Reject before lock leaves the eligible slot available for a corrected request; do not spin automatically. After lock, applied/skipped/cancelled action consumes only that opportunity. RETREATED actor cannot attack/HELP/RESCUE/retreat again or be a new combat target; old unrelated attack tokens fail ownership/phase/generation, never “follow the actor out”. No DOWN/RETREATED or DEAD/RETREATED pair, carry, evacuation, inventory/MP, escape contest, whole-team retreat or unregister. Last active Party retreat is blocked until D10/D15 selection; nonterminal proof must not pretend it classified an outcome.

## 6. Proposed queue continuation cases and six state machines

Common identity rule for the ten cases: `G` and `R/Q` unchanged during a round; only an authorized new round allocates `R+1/Qnew`, and only valid Restart allocates `G+1/revision0`. No callback may infer current identity from a reused actor ID. Eligible NPC means “may receive its own opportunity”; **choice of rescue/retreat still D08/D16/M4-04**, not a Player instruction. In scheduler tests explicit fixture effects are not independent-policy evidence.

| Case | Current slot / remaining slots | Round / generation | Player input / NPC eligibility | Completion / authorized ROUND_CLOSED | Terminal dependency / expected continuation |
|---|---|---|---|---|---|
| 1 Player DOWN before round | No active token; Player opportunity unavailable, eligible NPC/Enemy retained in stable order | Explicit new R/Q in G only via D15-A; otherwise no publication | Input off; ALIVE/PRESENT NPC eligible | Only real completed work can satisfy new adapter witness; M402 issuer rejects | D10/D15/full D09 production BLOCKED; isolated finite continuation proposed, no fake Player command |
| 2 DOWN during own action | Before impact: owned action settles SKIP; after impact: retain applied effect and complete once; later IDs unchanged | Same R/Q/G | Input off; NPC checked live at slot | Cannot seal with pending impact/completion; after settlement apply actual dispositions | D10 decides nonterminal if active NPC; no undo/double impact. External mid-windup damage only explicit fixture revalidation, not new production event |
| 3 DOWN during NPC action | NPC action remains owned; revalidate effect targets normally; remaining slots unchanged | Same R/Q/G | Input off; current/next NPC independent eligibility | Pending NPC action blocks seal; current slot cannot be dropped just because Player unavailable | D10/D15-A continue if active Party/Enemy; no fallback rescue inserted |
| 4 DOWN with ALIVE NPC | Resolve/complete current token; unavailable Player opportunity skipped if not yet visited; no reordering | Same R/Q/G then explicit next R if valid | No input; eligible NPC opportunities proceed | Full real witness may close in M403 only; close does not guarantee rescue | D10/D15-A nonterminal; existing Resolver cannot supply new policy |
| 5 DOWN and no actionable NPC | Settle current effect; freeze/cancel remainder under D10-A; missing decision rejects admission N-all | Same R/Q/G; no next round | Input off; no eligible Party helper | No natural close to run out DOWN clocks; no fake DEFEND | D10-A DEFEAT if no retreat, possibly mixed withdrawal if others retreated; B suspension policy still requires separate review; pending gate means no classifier or stored suspension published |
| 6 Player rescued to ALIVE | Current helper completes; visited/skipped Player slot never reinserted; later IDs unchanged | Same R/Q/G; input may return only next eligible command boundary Rnew | No mid-round input; NPC eligibility unchanged | Real rescue completion counts once; retired episode not ticked | D10/D15-A continue. If Player was unavailable at opening, opportunity already disposed before later NPC rescue; no same-round late command |
| 7 Player RETREATED | Own retreat token completes despite eligibility false; other slots remain | Same R/Q/G | Input off permanently in G; NPC ALIVE/PRESENT eligible | May close only nonterminal full witness; no Player-required M402 close | D07/D10/D15; no whole-party departure, no Guidance from exited Player |
| 8 Last active Party retreats | Impact freezes terminal candidate/outcome in C; one current completion allowed; remainder cancelled terminally | Same R/Q/G, round ABORTED, no next round | Input off; no actionable Party | No natural close, no tick; terminal completion lane cannot claim round completion | D07/D10/D11/D14/D15; PARTY_RETREAT or MIXED_WITHDRAWAL per §7 |
| 9 No actionable Enemy | No new attack locks; if final hit just applied, allow its completion only | Same R/Q/G; ABORTED if outcome reached before close | Input off after freeze; no more NPC choices | Terminal before seal wins; no synthetic remaining receipts/close | D10/D14: victory only with active Party; mutual-unavailable precedence per §7 |
| 10 Restart with callback pending | Validate reset before replacing queue/action ledgers; old slot no longer current | G+1, revision0, new initial R/Q; SEALED needs explicit Abort first | New fixture decides input/eligibility, never old callback | Old impact/complete/close/abort reject stale generation; invalid reset retains legitimate pending work | Restart is reset, not outcome/aftercare; frozen old summary never restored |

### State vocabulary and transition contract

| Domain | Proposed states / meaning |
|---|---|
| Actor | M4-01 four valid pairs; actionable derived from ALIVE/PRESENT (Enemy HP>0) **and** encounter/slot authority. No new LifeState |
| Action | NONE→LOCKED→APPLIED or SKIPPED→COMPLETED; LOCKED→CANCELLED; no completion→impact |
| Queue | Published `queue.phase`: READY / RUNNING / WAIT_ACTION / DRAINED / TERMINAL_SETTLING / STOPPED; cursor monotonic, at most one active token. SUSPENDED is only a derived read-only diagnostic (§4), never a stored phase |
| Round | OPEN / SEALED / CLOSED / ABORTED; no reopen. Valid reset reserves first OPEN identity in READY/unadmitted state; only admission can start action opportunities |
| Encounter terminal | ACTIVE / FROZEN; classification candidate is scratch only, never a public mutable result; explicit Abort may freeze administrative ABORTED |
| Summary | ABSENT / FROZEN; diagnostic live view is not a partial frozen summary; Restart begins ABSENT in new generation |

Rows below describe logical transitions, not separate commits when they share a trigger: effect + terminal + summary is one candidate/publication/revision increment. All successful publications below use current generation with revision+1 unless Reset says otherwise. All rejected transitions use N-all; reasons list the relevant gate after authentication (§4). No transition permits completion to apply damage/retreat/RESCUE again.

| Trigger / transition | Authorization owner / preconditions | Atomic mutation / identity | Expected reason; rejection |
|---|---|---|---|
| Initial/new round → RUNNING or FROZEN | Encounter; validated finite plan, chosen decisions, ACTIVE; previous round CLOSED or first READY admission | Initial R/Q retained, or new R/Q/OPEN witness after CLOSED; classifier may freeze terminal seed before actions, otherwise ordered opportunities admitted; G stable | `M403_ROUND_OPENED`; invalid identity/decision→`M403_INVALID_ROUND`/`M403_BOUNDARY_DEPENDENCY` |
| Actor receives real damage → DOWN | Isolated effect owner, Party ALIVE/PRESENT, valid owned action | HP0/DOWN, new episode/B2/entryR with result; queue remains WAIT_ACTION; classify candidate before publish | `M403_DOWN_ENTERED`; invalid actor/token→protocol/unavailable |
| DOWN → ALIVE by RESCUE | Effect owner, helper eligible, target distinct DOWN/current episode/use1, owned action | HP1, retire clock/use0/result together; no slot insertion | `M403_RESCUED`; changed eligibility/episode/use→one-shot SKIP, N-effect |
| Eligible actor → LOCKED / WAIT_ACTION | Adapter grants only current slot/actor; OPEN/ACTIVE, no token | Grant/serial/lock, no actor delta; immutable decision/target | `M403_ACTION_LOCKED` (RETREAT specific lock reason in §5); wrong slot/phase→reject |
| Ineligible opportunity → unavailable disposition | Adapter, OPEN/ACTIVE, no active action, current observed state unavailable | Advance cursor/disposition only; no token/impact/completion receipt | `M403_SLOT_UNAVAILABLE`; wrong current identity/revision→reject |
| RETREAT LOCKED → APPLIED | Encounter effect owner; §5 | ALIVE/RETREATED/guard removal/result together; no extra slot | `M403_RETREATED`; actor changed→SKIP/N-effect |
| LOCKED → SKIPPED at impact | Encounter; owned grant but live domain precondition fails | Consumption/result/phase only; WAIT_ACTION retained until completion | `M403_ACTOR_UNAVAILABLE` or target/episode reason; N-effect |
| APPLIED/SKIPPED → COMPLETED | Encounter, exact token/generation; OPEN or terminal settlement lane | One actual receipt, clear outstanding/active; queue RUNNING/DRAINED or STOPPED; actor effect immutable | `M403_ACTION_COMPLETED`; repeat→`M403_DUPLICATE_OPERATION`, LOCKED→`M403_INVALID_PHASE` |
| LOCKED → CANCELLED | Encounter/capability, OPEN, pre-impact only | Cancel accounting/disposition/cursor; no completion receipt/no actor effect | `M403_ACTION_CANCELLED`; APPLIED/SEALED→`M403_INVALID_PHASE` |
| DRAINED → SEALED | Adapter authority, §4 witness, no pending/terminal, real progress, active sides | Freeze witness, owned event/pre-issued Abort remains; sealed_revision = new revision | `M403_ROUND_SEALED`; incomplete→`M403_ROUND_NOT_CLOSABLE`; no progress→REJECTED / `M403_NO_REAL_PROGRESS`, N-all; no stored SUSPENDED |
| SEALED → CLOSED; DOWN may → DEAD | Encounter authenticates owned event + semantic dedupe + sealed revision | Pre-tick batch grace/B−1/death0, close consumed once, classifier and any summary in same candidate | `M403_ROUND_CLOSED`, per episode `M403_BLEED_GRACE/TICK/BLED_OUT`; duplicate→`M403_DUPLICATE_ROUND_CLOSED` |
| ACTIVE → FROZEN; summary ABSENT → FROZEN | Encounter only, D10-approved post-effect/close classification nonempty | Effect + classification + exact summary + input/queue freeze together; OPEN round→ABORTED, CLOSED stays CLOSED; retain only settling token | outcome reason in §7; incomplete summary→`M403_INVALID_CANDIDATE` rejects whole candidate |
| OPEN/SEALED → ABORTED | Explicit owned Abort, issued in OPEN; no frozen outcome yet | Abort accounting + administrative outcome/summary in C; queue STOPPED (no fake completion), clocks/effects unchanged | `M403_ABORTED`; forged/duplicate/phase→protocol reject; Abort itself N-effect |
| Boundary rejection → no published transition | Adapter validates capability/identity/phase/expected revision; missing decision, no actual completion for seal, or next round beyond finite plan | No publication, revision increment or stored queue-phase/cursor change; whole root N-all. Read-only diagnostic may independently report SUSPENDED; no new round/tick | REJECTED / `M403_BOUNDARY_DEPENDENCY`, `M403_NO_REAL_PROGRESS` or `M403_PLAN_EXHAUSTED`; stale revision at its earlier gate → `M403_STALE_REVISION`, N-all; no automatic recovery action |
| Any allowed reset boundary → new generation | Encounter capability; validate entire fixture first; SEALED must Abort before reset | G+1/revision0, fresh identities/ledgers/ABSENT summary; old detached snapshots remain historical | `M403_RESTARTED`; malformed→`M403_INVALID_RESTART` N-all; valid SEALED reset→`M403_INVALID_PHASE` N-all |

Terminal settlement lane is **proposed only in M403**, not a change to M402 `complete()` (which requires OPEN). It accepts only the already APPLIED/SKIPPED token that caused the freeze, changes completion accounting once, and cannot mutate frozen outcome/summary/effects or create ROUND_CLOSED. Explicit Abort with a LOCKED action invalidates it; it does not fabricate a completion. Restart clears the lane. This distinction is required to avoid a deadlock when the last actor retreats at impact.

## 7. Proposed terminal contract and precedence — D10-A

Authoritative decision owner = isolated Encounter; pure classifier returns a candidate from the complete validated state, not UI, animation callback, last damage event or Player HP alone. Let `P` be count of ALIVE/PRESENT Party, `E` Enemy HP>0, `R` ALIVE/RETREATED Party. Initial Party roster nonempty with exactly one Player; Enemy initial roster nonempty. Reject malformed/empty fixtures; do not call an empty roster a victory.

Evaluate the following mutually exclusive order **only if owner selects A**:

| Priority / condition | Proposed outcome / reason | Example / unchanged state |
|---|---|---|
| 1 P>0 and E>0 | ACTIVE / `M403_CONTINUE` | Player DOWN/DEAD/RETREATED but NPC ALIVE/PRESENT continues; Player unavailability is not terminal |
| 2 P>0 and E=0 | VICTORY / `M403_ENEMIES_UNAVAILABLE` | Last Enemy HP0; DOWN ally stays DOWN, no free rescue or clock tick |
| 3 P=0 and every Party member ALIVE/RETREATED | PARTY_RETREAT / `M403_ALL_PARTY_RETREATED` | All Party escaped; Enemy availability still reported, including E=0 fixture |
| 4 P=0 and R>0 with DOWN/DEAD Party | MIXED_WITHDRAWAL / `M403_ESCAPED_WITH_LEFT_BEHIND` | Retreated Player + DOWN/DEAD companions; no auto death/evacuation; applies even E=0 |
| 5 P=0, R=0, E=0 | DEFEAT / `M403_MUTUAL_INCAPACITATION` | Both sides unavailable; specific reason takes precedence over generic no-active-Party |
| 6 P=0, R=0, E>0 | DEFEAT / `M403_NO_ACTIVE_PARTY` | All DOWN, all DEAD or mixed DOWN/DEAD. DEFEAT never rewrites DOWN→DEAD |
| Administrative explicit Abort while ACTIVE | ABORTED / `M403_ABORTED` | No gameplay winner; retain actual actors/clock. Does not override an already frozen result |

This makes explicit the architecture §8 proposal's specific mutual reason and withdrawal precedence, without changing its historical rows. Alternative ordering (draw, victory with no active Party, post-combat rescue window) is **not approved**; owner can choose a revised rule before implementation. A synchronous isolated batch classifier test may inspect simultaneous candidates; current production has no simultaneous damage mechanism.

### Evaluation boundary and event ordering

1. Validate/authenticate input and build complete effect candidate. Classify **after** effect, before publishing or allowing another effect. If terminal, atomically freeze outcome + summary + stop new input/slots/clock in that same publication. An OPEN round becomes ABORTED by owned terminal authority prepared at round admission; never label this natural completion. Keep only the already impacted action's completion lane.
2. If nonterminal, complete the action once. Only drained real witness can seal; only sealed owned close can tick. Close calculates all episode deltas from one pre-tick root and classifies that candidate; if terminal, publish CLOSED + frozen outcome/summary together. No second publication window with incomplete summary.
3. Last Enemy defeated **before ROUND_CLOSED** therefore yields victory (when P>0), aborts remaining round work and leaves DOWN budgets unchanged. Even the last planned action killing the last Enemy does not earn a natural-close tick. This precedence is part of D10-A proposal, not a settled production rule.
4. Pending rescue blocks natural close. In the serial one-action M403 path, an outstanding rescue and a different last-Enemy attack cannot coexist: reject the second lock `M403_ACTION_IN_PROGRESS`. Thus “last Enemy defeat with pending rescue” is a **boundary rejection test**, not proof of a two-action race. Detached classifier input can show Enemy0/DOWN, but cannot claim the unreachable ordering passed. A multi-action terminal cancellation policy would require another design; do not waive M402-06.
5. SEALED permits only close or pre-issued Abort. No new action, fixture damage, outcome-only classify-and-publish, completion or reseal. If close and Abort are delivered sequentially, the first valid publication decides: close may finish nonterminal or terminal; subsequent Abort then fails phase/frozen gate. If Abort wins, close fails phase. No concurrency winner or signal timing claim.
6. Frozen outcome has exactly one ID, cause, reason, freeze revision and summary. Repeated matching read/evaluation returns identical data with no revision/counter delta (`M403_OUTCOME_FROZEN`); mutation requests reject. Old-generation callbacks reject identity first. Completion accounting may advance live revision but never changes `freeze_revision` or rows.
7. Valid Restart is reset, not ABORT/DEFEAT/resurrection/aftercare. Invalid Restart retains both pending/frozen state and valid grants. Abort/terminal cannot auto-heal, kill DOWN, give rescue uses, unregister or write a save.

**Reachability limit:** with active Party required at seal and ticks affecting only already-DOWN actors, a natural close in this bounded model cannot by itself remove the last active Party or Enemy. Post-close classification is a consistency guard; simultaneous/no-active candidates are detached or seeded tests, not evidence of a natural clock-caused terminal path. Do not inject an extra lethal effect into SEALED to make that path reachable.

**Dependency boundary:** pure A classification can be reviewed now, but end-to-end Player-unavailable queue/clock needs D15-A and a reviewed adapter; production additionally needs full D09 integration. Missing approval is `BLOCKED DEPENDENCY`, not evidence that immediate defeat or continuation is selected. D08/D16 remain needed for later independent NPC choice, not for an explicitly labelled fixture scheduler experiment.

## 8. Proposed isolated summary v1 — D11-A / D14-A

Freeze summary in the same candidate as terminal. Every field below is proposed; no production result screen or original actor snapshot is edited.

| Schema object | Exact proposed fields / types |
|---|---|
| Envelope | `schema_version:int=1, domain:String=M403_ISOLATED_SUMMARY, session:int, generation:int, round_id:int, outcome_id:String, freeze_revision:int, encounter_outcome:String, reason_code:String, party_lifecycle_rows:Array, enemy_combat_rows:Array` |
| Party row | `actor_id:String, role:String(PLAYER/NPC), current_hp:int, life_state:String, participation:String, final_down:Dictionary, outcome_relation:String` |
| final_down | Empty if no episode; otherwise exact `episode_id:String, entry_round:int, budget:int, active:bool`; retain last episode even after RESCUE/DEAD, with current active flag; not a new clock authority |
| Enemy row | `actor_id:String, current_hp:int, availability:String(AVAILABLE/UNAVAILABLE), combat_result:String(ACTIVE_AT_END/UNAVAILABLE_AT_END)`; no LifeState or Participation |

`outcome_relation` is deterministic presentation metadata from Party pair: ALIVE/PRESENT→`PRESENT_ALIVE_AT_END`, DOWN/PRESENT→`DOWN_AT_END`, DEAD/PRESENT→`DEAD_AT_END`, ALIVE/RETREATED→`SELF_RETREATED`. It does not claim a DOWN actor safely survived or an Enemy died. Envelope carries encounter outcome; no duplicate row-owned winner rule. Abort uses same exact rows with outcome ABORTED; diagnostics before any freeze return `ABSENT`, never a partially filled summary.

Proposed invariants:

- Party row IDs exactly equal initial Party IDs (Player included), ordered Player→initial NPC order; Enemy row IDs exactly initial Enemy order. Unique within/across domains; union equals initial roster. No filtered-out DOWN/DEAD/RETREATED/Enemy0, no dynamic roster removal/archive path.
- Each Party state matches M4-01 valid pair/HP rules. Final episode corresponds to that actor in current generation; DOWN active B1/B2, DEAD inactive B0, rescued ALIVE may retain retired B1/B2, never active bleed while ALIVE/RETREATED. Enemy HP0 says unavailable only.
- Private frozen value never mutates. Public reads are deep detached snapshots; caller edits nested rows/episode cannot change future reads. “Immutable” describes owned record, not an unsupported promise about recursively read-only caller dictionaries.
- Summary state/clock is the same committed root that produced outcome; no aftercare mutation between classification and copying. Candidate invalid last row/duplicate ID/missing actor rejects **entire** effect/clock/outcome/summary commit, N-all.
- Matching duplicate outcome read returns same identity/order/values, not new rows or freeze revision. Restart resets current summary to ABSENT/new generation only after whole fixture validation. Historical detached copies remain historical, cannot authorize new effects or reattach to new encounter.
- No persistence, save archive, permanent death or result-screen acceptance claim. Empty/partial data is invalid; no “best effort” omission. Counts, if later added, must be derived per domain (Party living includes ALIVE+DOWN; Enemy availability separate), not new authorities.

## 9. Proposed M403 acceptance matrix

**Every row: PROPOSED / NOT RUN.** `B` in Feasibility means **BLOCKED UNTIL OWNER APPROVAL** of D10/D15 (plus listed choices). `F` means a bounded fixture is technically feasible after its listed design approvals **and separate implementation authorization**; no F row is authorized now. `D` means detached data/diagnostic test only; it cannot stand in for an end-to-end effect ordering. `R` means future unchanged regression/evidence gate. Counts here are design rows, not runtime cases/assertions.

Exact-input notation, all proposed: `SID` is the owned session identity. Base fixture `F` has Party `p:ALIVE/PRESENT HP10`, `n:ALIVE/PRESENT HP10`, `t:DOWN/PRESENT HP0 B2/entry3`, Enemy `a:HP5`, initial orders `[p,n,t]` / `[a]`, G1/R3/Q3, OPEN/ACTIVE, separate rescue use1 each, guard empty. Each test begins from a fresh valid setup unless stated. `F[x=…]` replaces only named seed facts via validated setup, never writes live state directly. A listed current slot is reached through prior owned real actions/completions, not fake receipts. Snapshots before test input exclude setup effects.

`L(x)` = `lock_self_retreat({version:1,session:SID,generation:1,expected_revision:liveRev,queue_id:Q3,slot_id:ownedSlot(x),request_id:caseID,actor_id:x,kind:RETREAT},cap)`; `I(k)/C(k)/X(k)` = impact/complete/cancel exact returned token; `A` = advance exact §4 request with fresh live revision/capability; `O4` = open exact next R4/Q4 request; `Z` = seal with owned witness, `E` = close exact returned event; `AB` = owned pre-issued Abort. `hit(actor,target,amount)` / `rescue(h,t)` designate explicit **owned fixture** action lock→impact→complete for that actor/target/amount/episode, not NPC policy; actual legal setup and one-active-action constraints still apply. `class(V)` is pure classifier, `S` detached summary read. Variant inputs explicitly listed override the exact request/token fields; unknown fields reject. `same` refers to the just-before-input snapshot. `Ø` = no frozen outcome/summary; `frozen` means §7/§8 exact result. `N-unrelated` protects everything outside explicitly expected mutations. All unspecified reason names carry the `M403_` prefix.

### RETREAT and identity

| ID | Preconditions | Exact proposed input | Expected result | Expected reason | Expected Actor State | Expected Queue State | Expected Round State | Expected Outcome | No-delta assertions | Decision dependency | Test feasibility | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M403-01 | F, current p, n active | L(p); I(k); C(k) | Own retreat applies/completes once | RETREATED; ACTION_COMPLETED | p ALIVE/RETREATED HP10 retained | Next n; no added slot | OPEN R3/G1 | Ø | HP/uses/clock/other actors same; N-unrelated | D07; D10 nonterminal gate | B | PROPOSED / NOT RUN |
| M403-02 | F, current p | L(p) with actor_id=unknown | Reject before grant | WRONG_SLOT | same | same | OPEN | Ø | N-all incl serial | D07 | F | PROPOSED / NOT RUN |
| M403-03 | F[p=DOWN0/B2], admission not attempted | L(p) at retained p opportunity | Reject unavailable; no token | ACTOR_UNAVAILABLE | p DOWN/PRESENT0 | same | OPEN | Ø | N-all; no evacuation | D07/D15 | B | PROPOSED / NOT RUN |
| M403-04 | F[p=DEAD0/B0] or p=ALIVE/RETREATED10 | L(p), each fresh fixture | Reject both variants | ACTOR_UNAVAILABLE | seeded pair retained | same | OPEN | Ø | N-all; no resurrection/reentry | D07/D15 | B | PROPOSED / NOT RUN |
| M403-05 | L(p) succeeded | Replay identical request_id at fresh revision | Reject duplicate request | DUPLICATE_OPERATION | same | One LOCKED token only | OPEN | Ø | N-all/counter unchanged | D07 | F | PROPOSED / NOT RUN |
| M403-06 | I(k) retreat applied | I(k) again; C(k); C(k) again | Reject duplicate impact/completion; first complete only | DUPLICATE_OPERATION / ACTION_COMPLETED | p RETREATED same HP | One receipt/no extra advance | OPEN | Ø | Replays N-all; completion N-effect | D07/D10 | B | PROPOSED / NOT RUN |
| M403-07 | Old k in G1; valid Restart G2 | I(k); C(k); X(k) | All reject before reused IDs | STALE_GENERATION | G2 seed same | G2 queue same | G2 initial | Ø | N-all | D07 | F | PROPOSED / NOT RUN |
| M403-08 | Valid SEALED fixture; no active token | L(p); Z again | Reject wrong phase | INVALID_PHASE | same | DRAINED same | SEALED same | Ø | N-all incl grants | D07/D15 | B | PROPOSED / NOT RUN |
| M403-09 | k LOCKED OPEN | X(k); I(k) | Cancel; late impact rejected | ACTION_CANCELLED | p PRESENT HP10 | Cancel disposition, no receipt; opportunity spent | OPEN | Ø | Cancel N-effect; late I N-all | D07 | F | PROPOSED / NOT RUN |
| M403-10 | k LOCKED; authorized diagnostic actor-unavailable snapshot | I(k); C(k) | SKIP then complete | ACTOR_UNAVAILABLE; ACTION_COMPLETED | observed DOWN unchanged | One receipt, no reinsertion | OPEN | Ø | N-effect | D07/D10/D15 | D+B; not natural concurrent damage | PROPOSED / NOT RUN |

### Queue continuation, terminal and clock

| ID | Preconditions | Exact proposed input | Expected result | Expected reason | Expected Actor State | Expected Queue State | Expected Round State | Expected Outcome | No-delta assertions | Decision dependency | Test feasibility | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M403-11 | F, current t unavailable after real p/n receipts | A | Unavailable disposition then next a | SLOT_UNAVAILABLE | t DOWN0 same | No t action token; cursor visits once | OPEN | Ø | Actor/clock/uses same | D15 | B | PROPOSED / NOT RUN |
| M403-12 | F[p=DOWN0/B2], before first round admission | open R3/Q3; A to n | Valid isolated continuation without Player command | ROUND_OPENED; SLOT_UNAVAILABLE | p DOWN, n ALIVE | n eligible; p disposition | OPEN R3/G1 | Ø | No fake HP/DEFEND/Guidance | D10/D15 | B | PROPOSED / NOT RUN |
| M403-13 | Same, valid n slot | Submit Player command/Guidance fixture request | Reject issuer unavailable | PLAYER_INPUT_UNAVAILABLE | same | n opportunity unchanged | OPEN | Ø | N-all; v1 untouched | D09/D10/D15 | B; production deferred | PROPOSED / NOT RUN |
| M403-14 | p token impacted; diagnostic p becomes DOWN | C(k) | Settle prior effect once | ACTION_COMPLETED | p DOWN0 unchanged by completion | Remaining n,a preserved | OPEN | Ø | N-effect/no second damage | D10/D15 | D+B | PROPOSED / NOT RUN |
| M403-15 | n action LOCKED; diagnostic p DOWN, n alive | I(k); C(k); A | Valid n effect/remaining slots continue | ACTION_COMPLETED; CONTINUE | p remains DOWN, intended n effect only | Next eligible ID, no rescue inserted | OPEN | Ø | N-unrelated, no Player input | D10/D15 | D+B | PROPOSED / NOT RUN |
| M403-16 | p skipped, n current, p DOWN B2 | rescue(n,p); A | p HP1; visited p not reinserted | RESCUED | p ALIVE1/retired episode; n use0 | Later IDs only | OPEN | Ø | No duplicate p slot/HELP delta | D10/D15; D08 policy excluded | B; fixture effect only | PROPOSED / NOT RUN |
| M403-17 | M403-16 then real remaining actions, both sides active | Z; E; O4 | Next eligible Player boundary only | ROUND_CLOSED; ROUND_OPENED | p ALIVE1, no tick retired p episode | Q4 p command-ready | CLOSED3 then OPEN4; G1 | Ø | Uses not reset; no old-round command | D10/D15/D09 | B; isolated boundary | PROPOSED / NOT RUN |
| M403-18 | p RETREATED; n ALIVE, Enemy alive | A through remaining; real actions; Z; E | No Player input; valid M403 close if full witness | SLOT_UNAVAILABLE; ROUND_CLOSED | p RETREATED/no clock; t grace B2 | Eligible n/a only | CLOSED3/G1 | Ø | No reentry/extra slot | D07/D10/D15 | B | PROPOSED / NOT RUN |
| M403-19 | F[p,n=DOWN0/B2], E>0 | class(V); approved initial freeze boundary | Terminal no-active Party | NO_ACTIVE_PARTY | All DOWN stay DOWN/B2 | STOPPED; no actions minted | ABORTED if opened, no close | DEFEAT frozen | No tick/heal/death | D10/D15/D11/D14 | B | PROPOSED / NOT RUN |
| M403-20 | All Party DEAD/PRESENT0, Enemy HP5 | class(V); freeze | Terminal classification | NO_ACTIVE_PARTY | DEAD0 retained | STOPPED | No natural close | DEFEAT frozen | No actor/clock delta | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-21 | All Party ALIVE/RETREATED, Enemy HP5 | class(V); freeze | Whole-party withdrawal | ALL_PARTY_RETREATED | All HP retained | STOPPED | No natural close | PARTY_RETREAT frozen | No forced departure/aftercare | D07/D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-22 | p current last active; n DOWN, t DEAD, a HP5 | L(p); I(k); C(k) | Mixed withdrawal; completion after freeze allowed | ESCAPED_WITH_LEFT_BEHIND; ACTION_COMPLETED | p RETREATED, n DOWN/t DEAD retained | TERMINAL_SETTLING then STOPPED | ABORTED, no close | MIXED_WITHDRAWAL frozen | Clock/uses/summary unchanged by C | D07/D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-23 | F[a=HP1], p current ATTACK | hit(p,a,5) | Final Enemy unavailable; victory before close | ENEMIES_UNAVAILABLE | a0 unavailable; t DOWN/B2 | Only causal token settles; rest cancelled terminally | ABORTED, no Z/E | VICTORY frozen | t clock/life same; Enemy no DEAD | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-24 | p rescue token to t LOCKED | Attempt n final-Enemy attack lock | Reject second active action | ACTION_IN_PROGRESS | All same | Original pending rescue retained | OPEN; Z blocked | Ø | N-all/no synthetic race | D10/D15 | B; exclusion, not M402-06 PASS | PROPOSED / NOT RUN |
| M403-25 | Last planned real action kills last Enemy | I(k); C(k); attempt Z | Terminal wins over round close | ENEMIES_UNAVAILABLE; OUTCOME_FROZEN | t DOWN budget same | STOPPED after C | ABORTED, never CLOSED | VICTORY frozen | No terminal tick/close count | D10/D15/D11/D14 | B | PROPOSED / NOT RUN |
| M403-26 | Detached complete V: P=0,R=0,E=0 | class(V) | Specific mutual classification | MUTUAL_INCAPACITATION | No mutation | No mutation | No mutation | Candidate DEFEAT only | N-all pure read | D10/D14 | D+B; no simultaneous-damage claim | PROPOSED / NOT RUN |
| M403-27 | V: P=0,E=0,p RETREATED,n DOWN,t DEAD | class(V) | Withdrawal precedence over mutual | ESCAPED_WITH_LEFT_BEHIND | same | same | same | Candidate MIXED_WITHDRAWAL | N-all pure read | D07/D10/D11/D14 | D+B | PROPOSED / NOT RUN |
| M403-28 | Valid frozen outcome/summary | classify/read same identity twice; attempt new lock | Same frozen data; mutation reject | OUTCOME_FROZEN | same | STOPPED | same | Same ID/reason/freeze revision | N-all incl counters/summary | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-29 | Full real witness, n DOWN entry2/B1, active p/a | Z; E; replay E | Batch death then duplicate reject | ROUND_CLOSED/BLED_OUT; DUPLICATE_ROUND_CLOSED | n DEAD0/B0; p/a unchanged | DRAINED | CLOSED3 once | Ø (active sides remain) | Replay N-all; no partial batch | D10/D15; D05/D06 semantics | B | PROPOSED / NOT RUN |
| M403-30 | No actionable Party or Enemy; no RETREATED | Attempt next-round admission after pure class | No empty round; terminal only at approved boundary | MUTUAL_INCAPACITATION | DOWN/DEAD retained | STOPPED, no slots | No new close | DEFEAT if freeze authorized | No clock/forced death | D10/D14/D15 | B | PROPOSED / NOT RUN |

### Summary, failures and compatibility

| ID | Preconditions | Exact proposed input | Expected result | Expected reason | Expected Actor State | Expected Queue State | Expected Round State | Expected Outcome | No-delta assertions | Decision dependency | Test feasibility | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M403-31 | Terminal fixture: p alive,n DOWN,t DEAD,a0 | freeze candidate; S | Separate exact domains | ENEMIES_UNAVAILABLE | Existing pairs/HP retained | STOPPED | Terminal boundary | VICTORY; 3 Party/1 Enemy rows | Enemy no lifecycle; no aftercare | D10/D11/D14 | B | PROPOSED / NOT RUN |
| M403-32 | Terminal fixture includes p RETREATED,n DOWN,t DEAD,a HP5 | S after valid freeze | All initial IDs once, disjoint/complete | OUTCOME_FROZEN | All retained | STOPPED | same | MIXED_WITHDRAWAL | No omitted/duplicate rows | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-33 | Valid terminal candidate; diagnostic deletes t row or duplicates p | Attempt publish, each fresh variant | Reject entire effect/outcome/summary | INVALID_CANDIDATE | Exact before effect | Exact before effect | Exact before effect | Ø | N-all, no partial retreat/death/use/summary | D10/D11/D14/D15 | D+B | PROPOSED / NOT RUN |
| M403-34 | Frozen S with nested final_down | Change caller row HP/episode/array then read S | Private frozen data identical | OUTCOME_FROZEN | same | same | same | Same frozen S | N-all deep-copy isolation | D11/D10/D14 | B | PROPOSED / NOT RUN |
| M403-35 | ACTIVE no outcome | summary_snapshot(current identity) | ABSENT; no partial final rows | SUMMARY_NOT_FROZEN | same | same | OPEN | Ø | N-all | D11/D10 | B | PROPOSED / NOT RUN |
| M403-36 | Frozen summary G1 | Valid Restart F; S(old outcome G1) | Reset; stale read rejected | RESTARTED; STALE_GENERATION | G2 F seeds | Fresh queue | G2 initial | Ø/ABSENT | Old copy cannot reattach | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-37 | LOCKED then separately APPLIED actions in fresh fixtures | Valid Restart F; old I/C | Reset at both boundaries; old callbacks reject | RESTARTED; STALE_GENERATION | G2 seeds | No old slot receipt | G2 initial | Ø | No old effect/terminal | D07/D10/D15 | B | PROPOSED / NOT RUN |
| M403-38 | Genuine action/close/Abort tokens G1, valid G2 reset | Replay each old token with reused actor IDs | Identity rejects all | STALE_GENERATION | G2 same | G2 same | G2 same | G2 same | N-all including summary | D10/D15 | B | PROPOSED / NOT RUN |
| M403-39 | Pending valid action; malformed last fixture row or duplicate actor ID | restart(badFixture,cap); then original valid I(k) | Reset rejected; legitimate old action still usable | INVALID_RESTART; original effect reason | Before reset same; then intended effect | No reset/partial grant loss | Same G/R | unchanged until valid I | Rejected reset N-all | D07/D10/D15 | B | PROPOSED / NOT RUN |
| M403-40 | Current eligible p/revisionV | L(p) expected_revision=V−1; forged token authorization_id | Reject before allocation/effect | STALE_REVISION; UNAUTHORIZED | same | same | OPEN | Ø | N-all | D07 | F | PROPOSED / NOT RUN |
| M403-41 | SEALED; owned E and pre-issued AB | Branch1 AB then E; branch2 E then AB | Abort-first no tick; close-first Abort wrong phase | ABORTED/INVALID_PHASE; ROUND_CLOSED/INVALID_PHASE | Branch1 same clocks; branch2 legitimate tick only | STOPPED or DRAINED | ABORTED or CLOSED | ABORTED frozen or Ø by active fixture | No reseal/reopen/extra outcome | D10/D11/D14/D15 | B | PROPOSED / NOT RUN |
| M403-42 | SEALED valid event | Attempt damage/new lock/complete/valid Restart; then AB→Restart | First calls reject; explicit recovery valid | INVALID_PHASE; ABORTED; RESTARTED | No rejected mutation; G2 seed on reset | No fake receipt | SEALED→ABORTED→new G | No leaked old summary | Each reject N-all; Abort N-effect | D10/D15 | B | PROPOSED / NOT RUN |
| M403-43 | Current p; issuer namespace reserved | L(p) request_id=slot_3_p and slot_4_p, each fresh; then valid L(p) | Reserved rejected; valid action unaffected | RESERVED_OPERATION_ID; RETREAT_LOCKED | same at locks | One legitimate token only | OPEN | Ø | Denials N-all/current+future keys free | D07 | F | PROPOSED / NOT RUN |
| M403-44 | V1 OPEN/nonterminal, fully disposed DRAINED queue, no outstanding work/no actual completion; V2 last finite round CLOSED/nonterminal with no next plan entry; valid capability/identity/current revision | V1 Z; V2 open next round beyond plan; repeat each exact request and read diagnostic twice; independently send expected_revision=liveRev−1 with earlier gates valid | All boundary requests REJECTED; identical retries repeat denial; diagnostic reads have no writes | NO_REAL_PROGRESS / PLAN_EXHAUSTED; stale variants STALE_REVISION before boundary check; repeat denial is not DUPLICATE_OPERATION | same | Published queue.phase/cursor/receipts exactly same; SUSPENDED only derived diagnostic with corresponding suspension_reason | V1 OPEN same; V2 CLOSED same; identities same/no new round | Ø unchanged; summary unchanged | N-all on every rejection/read: whole root/revision/grants/counters/consumption/clock/outcome/summary identical; no fake slot/event/tick | D10/D15 | B; two independent fixtures plus retry/stale variants, §4 precedence | PROPOSED / NOT RUN |
| M403-45 | Empty Party/Enemy initial roster, missing summary actor or wrong generation | restart invalid roster; independently validate malformed summary | Reject each whole candidate | INVALID_RESTART / INVALID_CANDIDATE | same | same | same | same | N-all/no empty-victory inference | D10/D11/D14 | B | PROPOSED / NOT RUN |
| M403-46 | Valid Enemy HP0 data; no lifecycle fields | Read Enemy summary; attempt Enemy L(a) at own slot | HP0 unavailable; Party-only retreat rejected | PARTY_ONLY | Enemy HP0 no DEAD | same on reject | same | existing frozen result unchanged | N-all/no domain coercion | D07/D11/D14/D10 | B; retreat rejection in fresh ACTIVE fixture | PROPOSED / NOT RUN |
| M403-47 | Unchanged Main/Guidance fixtures | Existing v1 strict8/R1/Pending→Frozen/Restart tests; protected hash compare | Existing expectations retained | Existing reasons, no new enum/field | Production unchanged | Production order unchanged | Existing round identity | Existing outcomes | No M403 writes into production | D09 preservation; full extension Pending | R | PROPOSED / NOT RUN |
| M403-48 | Future implementation committed + fresh canonical reference | Full existing all-flags runner incl M401/M402; fresh output; Legacy differential | All existing assertions/counts retained, new cases separate | Existing suite PASS expected, not observed here | HP/HELP/Guard/damage unchanged | Both kill orders/skips/locks/Restart covered | Single completion retained | Victory/defeat retained | Original source/tests/evidence not weakened | All selected decisions + task authorization | R | PROPOSED / NOT RUN |

M403-46 uses **two independent fresh fixtures**: frozen Enemy0 summary read and ACTIVE eligible Enemy own-slot retreat rejection (HP5). It does not attempt a lock after terminal and expect a domain reason that an earlier phase gate would mask. M403-10/14/15 are diagnostic revalidation variants; their legal injection seam must be reviewed before implementation. M403-26/27 classify detached snapshots only. No diagnostic is proof of a legal simultaneous gameplay path.

## 10. Recommended implementation decomposition — plan only

Keep A→B→C as three separately scoped/reviewed PRs. A isolates opportunity accounting, B isolates one atomic participation change, C adds interacting terminal/clock/summary gates. Combining them would hide scheduler failures behind outcome behavior. Each starts from then-current canonical only after preceding dependency is merged with **separate explicit merge instruction**; do not create stacked implementation branches in this task.

### M4-03A — Isolated Queue / Eligibility Foundation

**Current gate:** eligible for preparation of a separate reviewed Implementation Task; no implementation authorized. D10A/D15A design is approved only in the isolated scope.

- **Dependencies:** approved file/API task, D02 data model; review of passive skip/cursor identity contract. Any Player-unavailable automatic continuation or natural close requires D15 plus coherent D10 choice; A does not infer either.
- **Exact scope:** new finite isolated queue value/adapter, stable initial IDs/order, live eligibility reads, unique opportunities, authenticated dispositions/actual receipts, one active token, atomic reset/generation. Pure inspection/step foundation; reject at terminal/round-admission dependencies with N-all; progress diagnostics are read-only. No effect/terminal/NPC policy assumed.
- **Likely new files (proposed, do not create now):** `scripts/m4/m403_queue_adapter.gd`, `scripts/m4/isolated_queue_outcome_encounter.gd`, `tests/actors/m4_03_queue_foundation_proof.gd`; required `.gd.uid`; optional runner hook only with exact authorization, existing docs and new evidence directory then.
- **Forbidden files:** all production `scripts/combat/`, `scripts/npc/`, shared `scripts/actors/`, scenes/controller/presenter/UI/assets/config; original `scripts/m4/isolated_*` files already on baseline, M401/M402 tests/assertions/evidence. New aggregate path above is distinct from protected existing files.
- **New APIs:** read eligibility/opportunity snapshot, validated fixture restart, explicit advance/owned disposition and receipt; no production begin_round replacement or callable arbitrary receipt import.
- **Focused tests:** identity uniqueness/copy isolation, unknown/stale revision/generation, skip no action token, actual completion required, invalid roster atomicity, no empty-loop. M403-11/37–40/44/47/48 subsets only when their dependencies are approved; blocked end-to-end rows remain blocked.
- **Exit/review:** finite steps terminate or reject progress deterministically with N-all and read-only diagnostics, no duplicate opportunities or fabricated event, old generations harmless; independent review of authority/receipt schema and no-delta invariants before proceeding.
- **Risk:** accidentally calling fixture scheduling autonomy; scope must explicitly separate eligibility from NPC choice and actual terminal policy.

### M4-03B — Isolated RETREAT Transaction

**Current gate:** D07A Design Approved; requires separate explicit implementation authorization and reviewed prerequisite A. D10/D15 terminal design selection is complete; executable coverage still requires the authorized C task/prerequisites.

- **Dependencies:** reviewed/merged A, **D07-A approval and separate implementation task**. D10/D15 terminal-dependent implementation remains gated by the separate C task/prerequisites; first proof fixture retains another active Party/Enemy.
- **Exact scope:** current-slot self-target lock/impact/complete/cancel, atomic ALIVE/PRESENT→ALIVE/RETREATED, guard release, retained IDs, later exclusion, duplicate/stale/invalid/no-delta handling. No clock/outcome bypass for last-active retreat.
- **Likely files:** new aggregate from A, optional `scripts/m4/m403_effect_candidates.gd`, new `tests/actors/m4_03_retreat_proof.gd`/UID, narrowly authorized optional runner/docs/evidence.
- **Forbidden:** same production/original-M4/test/evidence files as A; no RETREAT/RESCUE button, new Guidance or NPC rescue/retreat choice, balance/animation change.
- **APIs:** `lock_self_retreat`, owned `impact/complete/cancel`, candidate validation; explicit action and issuer namespaces.
- **Focused tests:** M403-01–10/40/43 and compatible eligibility cases; split nonterminal portions from D10/D15 terminal coverage; do not mark whole rows passed if only a subset ran.
- **Exit/review:** success and denial retain exact unrelated state, completion works after RETREATED, no attack/reentry/extra slot, current/future namespace collisions rejected; independent transaction and original-M4 preservation review.
- **Risk:** cancellation becoming a free extra action, eligibility check blocking completion, partial guard/state commit, result masking invalid-phase reasons.

### M4-03C — Terminal / Summary / Continuation Proof

**Current gate:** D10A/D11A/D14A/D15A Design Approved; requires separate explicit implementation authorization and reviewed prerequisite tasks. D08/D16/full D09 production integration remain Pending.

- **Dependencies:** reviewed A/B, **D10/D11/D14/D15 chosen explicitly**, D07 for retreat cases, approved isolated adapter/witness schema/terminal settlement lane. D09 strict isolation preserved; **full D09 production integration remains BLOCKED**. D08/D16 are not supplied by this task: fixture action choices only, no new NPC policy.
- **Exact scope:** serial finite eligible-slot continuation, no Player input while unavailable, no extra rescued slot, D10 pure classifier and atomic terminal freeze, new witnessed round close with inherited clock semantics, terminal-before-close precedence, separated immutable summaries, Abort/Restart. End-to-end natural autonomous NPC rescue remains outside scope until M4-04 decisions/task.
- **Likely files:** A/B new aggregate/adapter, optional `scripts/m4/m403_outcome_classifier.gd` and `scripts/m4/m403_summary.gd`, `tests/actors/m4_03_outcome_summary_proof.gd`, test-only diagnostic file, UIDs/authorized optional runner/docs/evidence.
- **Forbidden:** original M402 issuer/contracts/schema behavior and original tests; all production/Main/Legacy/Guidance/controller/scene/UI/assets/config, save/permadeath/aftercare systems. A refactor needing original files requires a revised reviewed task, not blanket permission here.
- **APIs:** owned `open_round/seal/close/authorize_abort/abort`, pure classify, terminal settlement and detached summary accessor; distinct issuer/semantic identities.
- **Focused tests:** M403-12–39/41–46 plus full earlier proof. Mark diagnostic/unreachable cases accurately; M402-06 stays blocked, M402-24 stays partial. Do not use a fake completion to meet matrix counts.
- **Exit/review:** every chosen classifier branch and precedence case evidenced, full initial ID coverage, no partial aggregate publication, terminal exactly once, SEALED rejection/no reseal, all pending callbacks stale after Restart; independent design-to-code/test/evidence review before owner merge decision.
- **Risk:** highest interaction surface: last Enemy/Party impact, pending completion, post-tick classification, summary consistency and eligibility-versus-policy confusion. No playable/visual acceptance implied.

### Required regression and evidence for each future runtime PR

Each A/B/C task must run unchanged M4-01 and M4-02 plus **all existing flags**, fresh canonical baseline and Legacy differential per [combat guide](../tests/combat/README.md) and [PR #48 exact command record](../tests/actors/evidence/m4-02/run-record.json). Start with actual `/path/to/godot --version` then `python3 tests/combat/verify.py --godot /path/to/godot --output /tmp/wanderer-queue-check-unique`; add all relevant existing flags and reviewed new flag, not an invented present-day M403 flag. Resolve valid pre-cutover reference provenance as the existing runner requires; never pass a convenient mismatched reference.

Record actual engine/version, tested commit and delivery hashes, exact commands/fresh paths, expected/actual per case, raw snapshots/logs/engine logs/exits/results.json, import/parse/Main startup/gameplay/negative logs, failure history, original suite counts and source integrity. Unexpected errors fail even exit0; five expected negative errors separate. Preserve both kill orders, dead-enemy skips/living counters, command locks, fallback, ATTACK/DEFEND/NPC2 Guard, defeat/victory and Restart during actions. Existing counts are evidence to compare, not target constants to force. No test/constant weakening for PASS.

Presentation remains untouched. No headless run establishes pacing/feel/visual acceptance. If a later task changes presentation, require F6 at1280×720 with0.70 pacing,44px lunge, Compact Formation/readable intent/target/animations/saved homes and explicit evidence; no such runtime or GUI checks occurred in this planning task. Each future PR stops Draft after verification and independent review; approval, verification, merge and playable acceptance are separate gates.

## 11. Protected boundaries and risk register

**Implemented contracts protected:** production Main Autonomous via GuidedEncounter; Legacy F6 scripted rules; M4-01 data/state and M4-02 RESCUE/clock/death; HELP≤30%/+4/once, Guard and damage5/1/3; owned action tokens, queue order, target validity/fallback, locks, Restart and current victory/defeat; Guidance v1/eight fields, R1 Option A, Pending/Frozen; `combat_speed_scale=0.70`, `SHORT_LUNGE_DISTANCE=44.0`, Compact Formation, saved actor home positions. Homes: NPC1(320,480), NPC2(405,435), NPC3(475,509), Player(570,465), EnemyA(970,506), EnemyB(1100,424). No implementation in this PR changes any of these.

**D08/D09/D16:** D08 NPC rescue/retreat priority remains Pending; D16 helper refusal/recipient consent remains Pending. D09-A approval covers original isolated strict boundary only; full queue/target/Guidance integration remains unapproved. Player controls only self; NPC decides when its own slot begins; Guidance suggests and never grants command authority. No new Guidance types, changed strict request schema, same-round Pending re-arm or altered R1 revision. Pending→Frozen and new-round identity cannot be faked with a Player command while unavailable. Existing frozen decision stays immutable. Cases needing new rescue target ranking, Courage/Compassion retreat behavior, consent or independent response to Player DOWN go to **M4-04 after separate owner decisions/task**, not into this scheduler fixture. No M4-04 policy matrix is implemented or approved here.

| Risk | Level / dependency | Proposed mitigation / review gate |
|---|---|---|
| M402 fixture mistaken for production scheduler | High / D10,D15 | Preserve original issuer; separate exact M403 witness, authority and source hashes; review no fake receipts |
| Resolver Player HP0 shortcut blocks real autonomy | High / D08,D09,D16 | Label fixture-only choice; no fake HP/changed v1 can_act. Defer policy extension to separately approved M4-04 |
| Last-active exit deadlocks completion | High / D07,D10,D15 | Allow only causal impacted token settlement after freeze; prohibit effect replay/round close; test before/after Restart |
| Skips manufacture clock time or infinite rounds | High / D15,D05 | Dispositions distinct from action receipts; real-completion/nonempty witness; finite plan, no-progress rejection N-all; SUSPENDED diagnostic only |
| Terminal/clock ordering silently kills DOWN | High / D10,D17 | Terminal-before-seal abort, no aftercare; same-root tick/outcome/summary publication; explicit owner precedence |
| Caller ID preempts issuer slot/event | High / R48-01 lesson | Internal typed namespaces/reserved prefixes, current+future collisions N-all before allocation |
| Dual roots expose partial result | High / transaction design | One candidate/one root swap; never compose sequential live M402/queue writes; invalid final row N-all |
| Summary omits actor or calls Enemy0 DEAD | High / D11,D14 | Exact initial sets/domain validators, copy isolation, no unregister/aftercare |
| Restart callback matches recycled IDs | High / identity | Full session/generation/queue/slot/token auth before state lookup; old summary cannot attach |
| Strict Seal weakened for unreachable test | High / existing approvals | No unseal/reseal/fake close; M402-06 blocked/M402-24 partial; diagnostic labels cannot claim integration |
| Prototype policy mistaken for final game | Medium / vision | Isolated rules and fixture plans explicitly labelled; no final Speed Order/Turn System decision |
| Documentation status mistaken for verification | Medium / owner gate | Index current status, immutable historical records, all M403 rows NOT RUN, exact inherited provenance |

No projectile/animation system, full personality AI, Item System, inventory/economy/progression, persistent Trust, save deletion/permadeath, carry/stabilization/aftercare, lore rewrite or Starstone/Resonance integration is included.

## 12. Owner approval gate and learning notes

### Formal Owner Approval — 7 November 2026 (Asia/Bangkok)

**Owner Approval Source:** user's explicit chat task “WANDERER — M4-03 Owner Design Approval & Decision Register Update”, dated **7 November 2026 (Asia/Bangkok)**, identifying reviewed HEAD `90b9b5c510c06b55c9501fd009043eb9897e35c8`. Exact formal selections from that instruction:

> **D07 = Option A:** ถอนตัวสำเร็จเมื่อใช้ Self-RETREAT ถูกต้อง
>
> **D10 = Option A:** ตัดสิน Terminal Outcome จากสถานะ Party/Enemy
>
> **D11 = Option A:** แยก Party Lifecycle Summary และ Enemy Combat Summary
>
> **D14 = Option A:** Enemy ยังคงใช้ HP/Availability เดิม
>
> **D15 = Option A:** NPC/Enemy ที่มีสิทธิ์ยังเดินคิวต่อได้เมื่อ Player DOWN

All five are **APPROVED DESIGN / Option A — M4-03 Isolated Proof Scope Only**. Owner explicitly binds this approval to reviewed **§4–§9**, including Terminal Precedence, Strict Rejection/R49-01, Finite Scheduler and Summary Ownership. Those sections, their reason precedence and all 48 M403 rows are preserved byte-for-byte from the reviewed HEAD. Historical `B` feasibility markers mean owner-approval prerequisites at the review checkpoint; those five selections are now satisfied for isolated design only. They do not remove separate implementation-task/prerequisite gates, remaining full D09 dependencies, diagnostic/unreachable labels or NOT RUN status.

**Independent review attribution:** [Follow-up Design Review 5807203009](https://github.com/shanwinder/wanderer/pull/49#pullrequestreview-5807203009) reviewed `90b9b5c…` and recorded **R49-01 RESOLVED / M4-03 Design Consistency Review PASS (documentation scope)**. Reviewer inspected GitHub text/commits; did not run local checker, Godot, GUI or CI. Review acceptance is distinct from this explicit owner selection. This approval-record update awaits independent follow-up and separate owner merge authorization.

**D10/D15 coherence:** D10A classifies active Party/Enemy, so Player DOWN alone is nonterminal when an eligible NPC and Enemy remain; D15A permits finite eligible-slot continuation without a fake Player command. No-actionable-Party, terminal-before-close and post-terminal settlement follow the reviewed contract. Fixture action choice is not new NPC policy; Resolver/Guidance/Production remain unchanged.

**Pending boundaries:** D08 NPC Rescue/Retreat Decision Policy, D16 Refusal/Consent, full D09 Production Queue/Target/Guidance Integration, M4-04 Autonomous Decision Extension, M4-05 Playable Integration, Production Cutover and every extension outside isolated scope. Existing M4-01/M4-02 approvals/proofs remain unchanged. No fake receipt, round close or Player command; no inferred runtime, merge, branch-deletion or visual acceptance permission.

| Gate | Required evidence / current boundary |
|---|---|
| Design Approval | D07A/D10A/D11A/D14A/D15A APPROVED DESIGN — M4-03 isolated scope only; exact owner source above |
| Implementation Authorization | Separate reviewed task/file/API scope and explicit authorization for A/B/C; NOT GIVEN. A may prepare a task; B requires reviewed A; C requires reviewed prerequisite tasks |
| Automated Verification | M403-01–48 PROPOSED / NOT RUN; PR #48 evidence inherited only |
| Independent Review | Reviewed contract at90b9b5c passed follow-up; this approval-record amendment awaits independent follow-up |
| Merge Authorization | Separate explicit owner instruction for PR #49; NOT GIVEN; Draft/unmerged, no auto-merge |
| Playable / Visual Acceptance | NOT RUN; isolated design approval does not establish playable/visual acceptance |

### Thai learning notes — v0.4

1. **Goal:** วาดรอบที่ Player ล้มแต่ NPC ยังพร้อม แล้วตอบว่า “สิทธิ์กดปุ่ม” กับ “สิทธิ์เดินคิว” เป็นของใคร. Expected คือ Player input ปิด แต่การเดินคิวเป็นคำถาม D15 ไม่ใช่ผลอัตโนมัติจาก HP0.
2. **Concept:** LifeState ถามว่ายังมีชีวิตแบบใด; Participation ถามว่ายังอยู่สนามไหม; actionable ต้องดูทั้งสองและสิทธิ์ slot. RETREATED จึงเป็น ALIVE/RETREATED ไม่ใช่ DEAD และไม่ควรลบชื่อจาก Registry.
3. **Do:** ใช้กระดาษสามใบ “slot / action / round” เขียน p→n→t→a แล้วขีด t unavailable. นี่เป็นการข้ามโอกาส ไม่ได้สร้างการป้องกันปลอมและไม่ได้แปลว่ารอบจบแล้ว.
4. **Observe:** เดิน n RESCUE p หลัง p ถูกข้าม: p กลับ HP1 แต่ cursor ไม่ย้อนกลับ. ทดลองวาง Restart ก่อน impact/หลัง impact/ก่อน completion แล้วตรวจว่า token มี G เดิมหรือไม่. งานนี้เป็น walkthrough ไม่ใช่ Godot test.
5. **Explain:** Impact เปลี่ยนผลจริง; completion ปลดงานค้าง. คนที่เพิ่งหนีสำเร็จต้อง complete action เดิมได้ มิฉะนั้นคิวค้าง แต่ completion ต้องไม่หนีซ้ำหรือทำ damage รอบสอง.
6. **Adjust:** เปรียบเทียบ last Enemy HP0 ก่อน seal กับ close จริงหลังทุก action จบ. กรณีแรกเสนอ freeze โดยไม่ tick DOWN; กรณีหลังจึงนับ clock. Owner ต้องเลือก D10 ก่อนให้ expected กลายเป็นกฎที่อนุมัติ.
7. **Commit:** อ่าน diff เฉพาะเอกสาร ตรวจ Pending/NOT RUN ให้ตรงกัน ส่ง Draft และรอ independent review. หลังเลือก design แล้วค่อยขอ task implementation แยก; ช่วงนี้ยังไม่พิมพ์ GDScript.

คำถามตรวจความเข้าใจ: เหตุใด HP0 ของ Enemy จึงไม่ใช่ DEAD? ทำไม NPC eligibility ไม่พิสูจน์การเลือก RESCUE? ทำไม tuple G1/slot1 ใช้แทน G2/slot1 ไม่ได้? ทำไม skipped opportunity ไม่ใช่ completion receipt? ผู้เรียนอธิบายได้ก่อนค่อยเริ่ม proof ที่อนุญาต.

## 13. Documentation verification and stop

This task checks Git diff scope, Markdown file/fragment links, table widths, decision consistency, historical approval attribution, recorded M4-02 limits, unique M403 IDs and unchanged source/test/scene/config/asset/evidence blobs, plus `git diff --check`. Exact actual documentation check counts and delivered commit are recorded in the Draft PR. Temporary documentation integrity scripts are not new repository test code. No runtime/test/scene/config/asset/evidence files are authorized in this diff; architecture changes are pointer-only and its decision register/A01–A39 remain unchanged.

**Actual documentation checks — 6 November 2026:** `python3 /tmp/wanderer_m403_validate.py` and `git diff --check` passed. Checked16 Markdown files,407 local links including88 fragments,124 tables,48 unique M403 rows (all PROPOSED/NOT RUN) and5 pending decision rows; errors0. All304 pre-existing tracked blobs outside the four authorized Markdown paths equal canonical, including original M4-02 contract/test records/evidence;111/111 PR #48 source-manifest hashes match. Architecture body/register/A01–A39 after the pointer is byte-identical. Read-only JSON cross-check confirmed recorded55cases/1,188assertions/0failures,73final/69canonical PASS stages and5negative expected errors; this is evidence inspection, not engine execution. Temporary checker/output remain outside the repository.

**R49-01 documentation correction — 7 November 2026 (Asia/Bangkok):** owner requested Strict Rejection for [Independent Design Review 5796669669](https://github.com/shanwinder/wanderer/pull/49#pullrequestreview-5796669669) on `247912ab75d490a7d5ac92ed636cbfa9250efd47`. Corrected §4/§6/M403-44 and adjacent references: both boundary failures reject with N-all; SUSPENDED is a derived read-only diagnostic, not stored queue phase; retry/duplicate/stale-revision expectations are explicit. No new suspension publication API, runtime/test/runner/scene/evidence change or owner decision approval. Historical validation above remains attributed to the original delivery. Correction checks: `python3 /tmp/wanderer_m403_validate.py`, `python3 /tmp/r49_01_validate.py` and `git diff --check` PASS;16 Markdown files/407 local links/88 fragments/124 tables/errors0. Only this file differs from reviewed HEAD;307 other tracked blobs unchanged;111/111 recorded source hashes match. All48 M403 rows remain PROPOSED/NOT RUN; the other47 rows and five pending decision rows are byte-identical, as are §§5/7/8. Exact delivery HEAD is recorded in the same Draft PR. **Await Independent Follow-up Review**; the correction is not reviewer acceptance, implementation authorization or merge permission.

**Godot Runtime/Full Regression/GUI/Visual Acceptance NOT RUN — Design-Only Task.** No new engine result, performance, visual quality, playable autonomy or full M4 claim. Existing failed/partial/blocked records are not rewritten. Mermaid rendering is not required: state/transition tables are the review artifact.

**Owner approval-record validation — 7 November 2026:** temporary documentation checker `python3 /tmp/m403_approval_validate.py` and `git diff --check` PASS:16 Markdown files/408 local links/90 fragments/124 tables/errors0. D01–D17 register complete: only the five authorized status cells changed; other12 rows byte-identical. Reviewed §§4–§9 (including R49-01/reason precedence and all48 M403 rows) and Architecture A01–A39 byte-identical to90b9b5c. All304 tracked blobs outside the four authorized Markdown paths unchanged;111/111 PR #48 source hashes match. No runtime/test/runner/scene/config/asset/evidence changes. Godot NOT RUN — Documentation-Only Task; inherited evidence is not new verification. This record update awaits independent follow-up and separate merge authorization.

**Mandatory stop:** push the approval-record update to the same Draft PR #49; current index status is **M4-03 Design Decisions Approved / Awaiting Implementation Task Authorization**. Await Independent Follow-up Review of this documentation update and separate Owner Merge Authorization. No merge/auto-merge/branch cleanup, no implementation of A/B/C, no M4-04/M4-05 and no inferred approval.
