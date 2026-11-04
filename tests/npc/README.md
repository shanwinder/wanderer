# M2A-02 — NPC Decision & Effect Proof

Owner explicitly approved **M2A-01 D1–D9** and implementation of M2A-02 in
the task chat on 2026-11-03. These are approved **prototype** rules, not final
balance or a decision on the game's OPEN Turn System. M2A-01 is the design
report in that chat; this file documents the executable proof, not a new roadmap.

## Purpose and architecture

The main combat scene still uses its original scripted NPC rules. This proof
models **Player 1 + NPC 1 + Enemy A 1** independently, without scene nodes,
sprites, animation, gameplay UI, inventory, Trust or a Guidance system.

`Situation Snapshot → Decision Resolver → Validation → Effect → Result data`

- [NPCDecisionResolver](../../scripts/npc/npc_decision_resolver.gd) is a
  `RefCounted` with pure Dictionary input/output. It rejects missing/unknown
  fields, incorrect types, invalid HP, unsupported targets and invalid resources.
- [NPCProofEncounter](../../scripts/npc/npc_proof_encounter.gd) is a separate
  `RefCounted` data fixture with real HP/resource changes and NPC/enemy slots.
  Input is the state **after the Player's action**; Player animation/action
  execution and integration with `combat_turn_flow.gd` are outside M2A-02.
- [Headless tests](decision_effect_proof.gd) exercise both parts, including real
  delayed SceneTree timer callbacks across Restart.

For learning: a snapshot records facts; `decide()` chooses without changing
them; `resolve_npc()` changes combat values; `complete_npc()` allows the enemy
slot and completes the round. Keeping those boundaries separate lets a test
change one fact and explain why the choice or its validity changed.

## Approved prototype contract

Priority: terminal state → unavailable NPC → self-defense against a declared
threat when NPC HP ≤30% or incoming damage is lethal → HELP if Player HP ≤30%
and usable → ATTACK. Low HP alone does not trigger self-defense. Low-HP reason
takes precedence over lethal-threat reason when both describe the same choice.

| Decision | Target / effect / cost | Reason |
| --- | --- | --- |
| ATTACK | Enemy A; damage 1; one NPC slot | `ATTACK_AVAILABLE_ENEMY` |
| DEFEND | Self; reduce next incoming hit by 2, minimum damage 1; expires at round end; one slot | `SELF_LOW_HP_THREAT` / `SELF_LETHAL_THREAT` |
| HELP | Living Player; restore up to 4 HP, clamp to maximum; one slot and one use on success; one use per encounter | `PLAYER_LOW_HP_HELP` |
| HELP unavailable → ATTACK | Same attack; details distinguish disabled ability / exhausted uses | `HELP_UNAVAILABLE_ATTACK` |
| SKIP | Control result; no effect/resource cost; completion still drains queue | Actor/target/terminal reason |

Self-defense wins when NPC and Player are both at risk. NPC max HP is 10;
Player max HP is 30; Enemy max HP is 15, default post-Player HP is 10. Enemy
damage is 3. Enemy target is declared before the NPC slot and locked. Restart
resets the fixture's HELP use, not an in-world healing/recharge system.
NPC HP 0 means unable to act; it does not introduce Down or permadeath.

Example pure snapshot (no Node references):

```json
{
  "player_hp": 6, "player_max_hp": 30,
  "npc_hp": 10, "npc_max_hp": 10,
  "living_enemy_ids": ["enemy_a"],
  "incoming_target_id": "player", "incoming_damage": 3,
  "help_enabled": true, "help_uses_remaining": 1,
  "guidance": "ATTACK"
}
```

Expected decision: `HELP → player / PLAYER_LOW_HP_HELP`; `reason_details`
contains a deep copy of the facts above, including the suggestion. HELP raises
Player HP 6→10, then the enemy counter lowers it to 7. Enemy HP is unchanged.
Guidance is only scenario data; it never overrides the priority rules.

The encounter copies and locks the decision at slot start. Returned token and
inspection copies cannot replace it. At effect time it rechecks actor/target,
terminal state, HP need and HELP availability. Invalidated actions SKIP without
re-deciding or charging resources. Malformed snapshots return `INVALID_INPUT`
with `action=INVALID`, distinct from valid `SKIP`; neither uses an empty
Dictionary as an action. Empty internal storage is not an executable action.

The generation/action ID token rejects old callbacks after Restart and tokens
from previous rounds. Separate resolved/completed flags prevent duplicate
effects, enemy counters and round completion. Victory/defeat drains pending
work without incrementing the round. Enemy target unavailability skips its hit.
`apply_fixture_change()` exists only to inject races in this isolated proof;
it cannot change enemy targeting or decision priority.

## Reproduction and evidence

Run from the repository with a fresh output directory:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2a-02-unique --npc-proof
```

The opt-in flag adds the three new parse checks and proof execution to the
unchanged legacy suite. All existing checks and its five exact expected negative
errors remain required. Every normal stage requires exit 0 and no engine/script
errors; proof execution also requires a zero-failure `RESULT` marker. The runner
stores each command, stdout/stderr log, engine log, exit code and `results.json`.

Recorded final verification: **2026-11-03**, implementation commit
`bea778a5c811e1b7453128068abebe62a43f51e1`, based on merged
`95eaf4cc43292728ce45d4e989b6c3248c21fcd6` (PR #29 + #30).
Actual engine: **4.7.2.stable.official.ed1daf0bf**. Final command used
`--output /tmp/wanderer-m2a-02-final --npc-proof` with the executable above.
Subsequent changes are documentation/evidence only.

| Stage | Expected | Actual |
| --- | --- | --- |
| Engine version, clean import, seven script parses, main startup | Exit 0; no unexpected errors | PASS; exit 0 each |
| Legacy gameplay | Both kill orders, locks, targets, damage/Guard, defeat/victory, Restart unchanged | PASS; 14,395 checks, zero failures; exit 0 |
| Legacy negative suite | Exactly five expected errors | PASS; 983 checks, zero failures; exit 0 |
| NPC proof | S1–S11 and supplemental contracts | PASS; 412 checks, zero failures; exit 0 |
| Manual F6 / reason readability / visual pacing | Human acceptance in M2A-03 | NOT RUN; no presentation claim |

All S1–S11 rows below are **PASS** in the final run; raw expected/actual assertions
are in the harness and the scenario results are in `npc-proof.log`.

| Scenario | Expected / actual outcome checked by harness |
| --- | --- |
| S1 | ATTACK; Enemy 10→9; Player 20→17 |
| S2 | HELP; Player 6→10→7; uses 1→0 |
| S3 | Self-DEFEND; NPC 3→2; unguarded control reaches 0; Player unchanged |
| S4 | Exhausted/disabled HELP explained; ATTACK; no healing or extra use |
| S5 | Enemy dies before effect; SKIP; zero damage/counter; victory, no added round |
| S6 | Suggested ATTACK still yields HELP; correct HP/resource effects |
| S7 | Both low, NPC threatened; self-DEFEND before HELP |
| S8 | Player 8/9/10 and NPC 2/3/4 boundary cases; deterministic decisions; lethal threat above threshold |
| S9 | Enemy dead before slot; terminal SKIP with no pending work |
| S10 | Real delayed effect/completion callbacks before/after effect for all three actions; old generation rejected; new encounter works |
| S11 | Duplicate effects/completions rejected; no second cost, counter or round increment; previous-round/invalid token rejected |

Additional coverage: missing fields and Node values for every field, invalid
types/ranges/IDs, snapshot immutability, caller mutation, HELP cap/maximum HP,
second-round HELP exhaustion, minimum damage, invalidated HELP/dead actor,
Player defeat, NPC killing blow, invalid restart atomicity and queue exhaustion.

Durable raw evidence: [m2a-02.zip](evidence/m2a-02.zip), containing final logs,
exit codes, results and source SHA-256 manifest; initial sandbox-failed logs and
the first successful run are retained in separate archive folders. The first
attempt failed import despite exit 0 due to macOS certificate/editor-settings
sandbox access. It supplies no PASS claims. Final verification ran outside that
sandbox; all unexpected-error checks remained enabled. The archive excludes
imported caches and asset snapshots; regenerate them with the command above.

The M2A-02 record above predates playable integration. M2A-03 is documented
below; its implementation does not retroactively verify visual acceptance or
reason comprehension in the M2A-02 record.

## M2A-03 — playable integration and reason UX

ผู้สร้างอนุมัติ implementation แยกวันที่ 3 พฤศจิกายน 2026. ฐานที่ fetch แล้วคือ
`8294d24ce351e5d02ca26a4ace96469f7081e31d` (PR #31 merged); working tree สะอาด
ก่อนสร้าง `codex/m2a-03-playable-npc-autonomy`. ตรวจ PR ที่เปิดแล้วไม่มีงานซ้ำ;
PR #2 ยัง Draft/unmerged head `fac99aa` จึงไม่ได้ใช้เป็น canonical.

### Architecture และคำอธิบาย GDScript

[Scene](../../scenes/npc/npc_autonomy_proof.tscn) เป็น Control root ที่เปิดตรงด้วย
F6; [controller](../../scripts/npc/npc_autonomy_proof.gd) สร้าง child UI/Sprite2D
ตอน `_ready()` โดยใช้ภาพเดิม จึงเห็นโครง UI หลังรันฉาก ไม่ได้วาง child ทั้งหมดใน editor.
ไม่มีการเปลี่ยน main scene, combat scripts/queue/targets, HP/damage/Guard,
formation, project settings หรือ assets. Scene นี้ไม่มี Player action execution.

`Preset post-Player state → Encounter.begin_npc_slot() → Resolver decision
→ bound action/target/reason → NPC Tween → resolve_npc(token)
→ return home → enemy windup → complete_npc(token) → enemy return → unlock`

- `preload()` โหลด script/ภาพเดิมไว้ใช้; `Encounter.new()` สร้างเจ้าของ state
  ซึ่งเป็น `RefCounted` เดิม ไม่ได้สร้าง resolver/effect system ใหม่.
- Dictionary `PRESETS` เก็บ input ตามสถานการณ์ ไม่ได้กำหนด action ที่ NPC ต้องเลือก.
  แต่ละ Run ล็อก decision จาก `begin_npc_slot()` เพียงครั้งเดียว; guidance เป็น input.
- `REASONS` แปล `reason_code` เป็นข้อความ prototype ภาษาอังกฤษ พร้อมแสดง action,
  target และ log ของ code/details จริง ไม่เลือกคำอธิบายตามชื่อ preset.
- `create_tween().set_speed_scale(0.70)` สร้างลำดับภาพ; `tween_property()` ขยับ
  sprite 44px หรือเปลี่ยนสี DEFEND ฟ้า / HELP เขียว; ATTACK ทำ enemy flash.
  `tween_callback(...bind(epoch, token))` ส่ง generation/token ที่ล็อกไว้ไปยังจุด effect.
- `resolve_npc()` ลงผล NPC ที่จังหวะกระทบ; controller อ่าน `hp_delta` และ
  `help_use_delta` เพื่อแสดง feedback. Controller ไม่หัก HP หรือ HELP เอง.
- **Contract เดิม:** `complete_npc()` ลง Enemy Response และจบรอบแบบ atomic.
  จึงเรียกหลัง enemy windup ที่จังหวะ hit; ตัวเลข HP/round เป็น state ใหม่ทันที
  แต่ Run ยังล็อกจน enemy กลับบ้าน. ไม่เรียก complete ซ้ำหลัง animation.
- `inspect()` คืนสำเนาข้อมูล; `_refresh()` อ่าน HP/HELP/round/result จากข้อมูลนั้น.
  ผล NPC และ enemy เก็บใน scrollable log แยกกัน ไม่จำลอง damage/healing ใน UI.
- `epoch` เป็นเลขรุ่นของ presentation. Restart เพิ่ม epoch, `kill()` Tween,
  เรียก Encounter.restart(), ล้าง token/feedback/log และคืนตำแหน่ง/สีทั้งหมด.
  Callback ต้องตรงทั้ง epoch และ encounter generation/action token และ phase;
  resolved/completed flags กัน effect/counter ซ้ำ. `_exit_tree()` ยกเลิก Tween ด้วย.

Guard สีฟ้าคงอยู่ผ่าน Enemy Response; S3/S7 hit ลด 3 เหลือ 1 ตาม Encounter.
S6 แสดง Guidance ATTACK พร้อม HELP decision จึงเห็นคำแนะนำที่ NPC ไม่ทำตาม.
Run อีกครั้งบน state ปัจจุบันได้เพื่อดู HELP หมด; เป็น NPC+enemy slot proof เท่านั้น
ไม่มี Player action ระหว่างรอบและยังไม่ใช่ final Turn System.

### Automated verification — 2026-11-03

Implementation commit: `6de034d1023cff82bc5d9a35bfd8cab420901bee`.
Engine ตรวจจาก executable: **4.7.2.stable.official.ed1daf0bf**.
Command (fresh source snapshot, fixed 60 FPS simulation, speed constants unchanged):

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2a-03-final --npc-proof
```

`--npc-proof` ขยายให้รันทั้ง M2A-02 และ M2A-03; checks เดิมยังอยู่ครบ.
[Integration harness](playable_integration.gd) instantiate Scene จริง, emit UI
signals และรอ Tween/callback จริง ไม่ได้ทดสอบ resolver ซ้ำแทน scene.

| Stage | Expected | Actual / exit |
| --- | --- | --- |
| Version, clean import, nine script parses | No unexpected errors | PASS / 0 each |
| Main scene startup / new proof startup (120 frames each) | No startup errors | PASS / 0 each |
| Combat regression | Both kill orders, dead skips/live counters, locks, targets, Attack/Defend/Guard, Restart, victory/defeat | PASS — 14,395 checks / 0 |
| Legacy negative suite | Exactly five specified errors | PASS — 983 checks / 0 |
| M2A-02 S1–S11 + contracts | Existing decision/effect safety | PASS — 412 checks / 0 |
| M2A-03 real scene integration | Presets, state/UI binding, callbacks and safety below | PASS — 5,166 checks / 0 |
| Manual F6 / visual pacing / human reason comprehension | Separate human acceptance | **NOT RUN — Manual Visual Review Required** |

| Scene integration | Expected and actual (PASS) |
| --- | --- |
| S1 | ATTACK → enemy_a / ATTACK_AVAILABLE_ENEMY; Enemy 10→9; Player 20→17 |
| S2 | HELP → player / PLAYER_LOW_HP_HELP; Player 6→10 at NPC effect →7 after enemy; HELP 1→0 |
| S3 | DEFEND → npc / SELF_LOW_HP_THREAT; NPC 3→2; Player unchanged |
| S4 | ATTACK / HELP_UNAVAILABLE_ATTACK; no HELP; Enemy 10→9; Player 6→3 |
| S6 | Guidance ATTACK ignored in favor of HELP / PLAYER_LOW_HP_HELP; Player 6→10→7 |
| S7 | Both low + enemy targets NPC; DEFEND before HELP; NPC 3→2, Player stays 6, HELP stays 1 |
| HP/resource/action/reason binding | Actual UI text and reason_code log; intermediate healing and action colors; exact 44px NPC lunge; actors return home |
| Duplicate input/effect/completion | Locked token unchanged, no duplicate damage/cost/counter/round; commands locked every active frame |
| Restart ATTACK/HELP/DEFEND | Each at windup, post-effect, enemy windup and post-enemy effect; wait 5 simulated seconds; exact reset HP/UI; fresh turn completes once |
| Stale callbacks | Explicitly invoke all four old callbacks after reset; no state/UI mutation |
| Target dies during windup | Encounter SKIP TARGET_DEAD_BEFORE_RESOLVE; no counter; queue drains; victory adds no round |
| Terminal/unavailable actor | Killing blow, enemy-induced defeat, no new terminal turn; unavailable NPC safely SKIPs |
| HELP exhausted next turn | Second turn chooses fallback ATTACK; no second HELP or negative resource |

Durable, small text evidence (no new ZIP/binary logs):
[commands, statuses and exit codes](evidence/m2a-03/results.json),
[raw stdout, engine logs and exit files combined](evidence/m2a-03/logs.txt),
[source/snapshot SHA-256 manifest](evidence/m2a-03/source-sha256.json).
Original separate files and imported snapshot remain in `/tmp/wanderer-m2a-03-final`;
temporary paths in recorded commands describe that run, not permanent hosting.
Documentation/evidence commits after implementation do not change tested source;
manifest confirms source equals the final snapshot.

Earlier attempts are retained locally: `/tmp/wanderer-m2a-03-first` failed import
because sandbox blocked macOS certificates/editor settings, despite engine exit 0.
`/tmp/wanderer-m2a-03-debug` passed runtime scenarios but failed one harness log
assertion: RichTextLabel must be read via `get_parsed_text()` rather than `.text`.
Fixed that assertion before the final run; no rules/constants were changed to pass.
Final run used approved execution outside sandbox with unexpected-error checks on.

### Manual F6 / playtest checklist — NOT RUN

Native Godot UI access was attempted but no running application window could be
obtained through the UI tool. No screenshot, visual quality or user comprehension
PASS is claimed. Automated property/text assertions do not supply this acceptance.

1. เปิด project ด้วย Godot 4.7.2 แล้วเปิด
   `res://scenes/npc/npc_autonomy_proof.tscn`; กด **F6** ที่ 1280×720.
   ตรวจว่า Player/NPC/Enemy A, ปุ่ม, HP, reason และ log อ่านได้ ไม่ซ้อน/ตัดขอบ.
2. เลือก S1 แล้วกด Run NPC Turn: ATTACK → Enemy A, lunge 44px, hit feedback,
   กลับบ้าน; enemy ตี Player. เทียบผลตามตาราง.
3. เลือก S2 แล้ว Run: NPC ช่วย Player, สีเขียว, HP 6→10, HELP 1→0,
   จากนั้น enemy ทำให้เหลือ 7. Run อีกรอบต้อง ATTACK เพราะ HELP หมด.
4. เลือก S3 แล้ว Run: NPC สีฟ้าตั้งรับตนเอง, enemy โจมตี NPC ตามที่ประกาศ,
   NPC 3→2. เปรียบเทียบกับ damage ที่ประกาศ 3 เพื่อเข้าใจผลลดเหลือ 1.
5. เลือก S4 แล้ว Run: HELP unavailable, ATTACK ต่อ, ไม่มี heal/ใช้ HELP เพิ่ม.
6. เลือก S6 แล้ว Run: Guidance ATTACK แต่ NPC HELP และอธิบายว่า Player บาดเจ็บ.
7. เลือก S7 แล้ว Run: NPC ป้องกันตัวก่อนช่วย Player เพราะทั้งคู่เสี่ยงและตนถูกเล็ง.
8. Restart ระหว่าง ATTACK, DEFEND, HELP และ enemy windup/return; รอเกิน
   5 วินาที แล้ว Run ใหม่. ห้ามมีข้อความ/HP/animation เก่ากลับมา.
9. ตรวจ pacing ที่ 0.70, lunge 44px, คืนตำแหน่ง และความชัดของ target/intent/
   HP/healing/guard ทั้งระหว่าง motion และหลังจบรอบ; จับ screenshot/video ถ้ามีปัญหา.
10. ทำ combat หลัก F6 checklist ใน [combat tests](../combat/README.md#manual-f6-review)
    เพื่อยืนยัน compact formation, animation และพฤติกรรมเดิมด้วยตา.
11. ให้ผู้ทดลองที่ไม่อ่าน source เล่นทั้งหก preset แล้วบันทึกคำตอบเองก่อนเทียบตาราง:
    NPC ทำอะไร? เลือกช่วย/ป้องกันใคร? เพราะอะไร? สถานการณ์ไหนไม่ทำตาม Guidance?
    ผลของทางเลือกนี้ต่างจาก ATTACK/HELP/DEFEND อีกทางอย่างไร?
    บันทึกชื่อ scenario, คำตอบ/ความเข้าใจผิด, pacing/readability, engine, commit,
    expected/actual และลิงก์ภาพ/วิดีโอ. เว้นผล comprehension เป็น NOT RUN จนมีคำตอบจริง.

### ข้อจำกัดและ review gate

Prototype ใช้หนึ่ง companion, หนึ่ง enemy, deterministic priorities และ snapshots
หลัง Player action; ไม่มี full NPC AI, personality/Trust, full Guidance UI,
inventory/healing framework หรือ lore changes. คำอธิบายเป็น prototype ภาษาอังกฤษ;
ยังไม่ทดสอบ localization/ความเข้าใจผู้เล่น. UI สร้างใน `_ready()` เหมาะกับ proof
แต่การออกแบบต่อใน editor อาจต้องแยก node tree ในงานที่อนุมัติภายหลัง.

Enemy effect/completion ยังเป็น atomic contract เดิม; ก่อนเชื่อม combat หลักต้อง
review action timing, queue ownership, target multiplicity และ NPC policy ใหม่
พร้อม tests และ human acceptance. ไม่ถือว่า M2A ผ่านด้านความรู้สึกเพียงเพราะ
headless PASS. หยุดที่ Draft PR เพื่อ review; ไม่ merge, ไม่เริ่ม M2B และไม่นำ
NPC autonomy ไปแทน scripted combat หลักอัตโนมัติ.

### Subsequent owner-reported acceptance — M2B-01 checkpoint

PR #32 merged as `924748cf09a4c421c7c0c270995a512fa67ad281`. In the
2026-11-03 M2B-01 task the owner reports having manually tested and accepted
M2A-03, and authorizes proceeding. This is **owner-reported manual acceptance**;
no scenario-by-scenario results, engine, tested commit or new media were supplied.
It does not rewrite the agent's historical NOT RUN record above. No new manual
F6/reason-comprehension acceptance was performed by the M2B-01 agent.
New automated regression evidence is recorded in [Actor tests](../actors/README.md).

### M2B-02 — subsequent Encounter HP ownership migration

The proof Encounter now owns three ActorRuntimeStates while retaining the same
public snapshot schemas, Resolver decisions and playable controller. This does
not migrate main combat. The original M2A-02/M2A-03 harnesses and expectations
are unchanged; current regression results and manual F6 NOT RUN status are in
[Actor ownership evidence](../actors/README.md#m2b-02--single-source-encounter-hp).

## M3A-02 — Guidance Data Foundation

### Authorization / scope

Owner approved M3A G1–G14 in the 4 November 2026 task, with **HELP 50% explicitly NOT approved**, and authorized implementation **only of M3A-02**. M3A-01 is the preceding chat design report. Current milestone authority remains [docs index](../../docs/README.md#current-status-and-next-roadmap).

This is data-only: no Guidance UI, guided NPC policy, follow/refuse effects, persistent relationships, Speed/Retreat or balance changes. HELP stays at **≤30%, amount4, once per NPC per encounter**. Resolver, actor definitions/runtime, controller, presentation, scenes and project default are unchanged. M3A-03/04/05 are not started.

### Code and ownership

- [GuidanceData contract](../../scripts/npc/guidance_data_contract.gd) validates values only; it has no mutable session state or decision policy.
- [FullPartyEncounter](../../scripts/combat/full_party_encounter.gd) owns pending/active Guidance, Guidance revision and fixed profiles. It exposes `submit_guidance(request)` and `guidance_snapshot()`.
- Existing `snapshot()`, `decision_context()`, Player command signatures, Resolver schemas and action token/effect contract are unchanged. Guidance does not advance combat `snapshot_revision` or enter Resolver input.
- [Data proof](guidance_data_proof.gd) uses RefCounted data objects and SceneTree timers only, with no GUI dependency.

### Strict request version1

All **eight keys are required**, with no extra fields. An optional target is represented by the empty string, never a missing key/null.

| Field | Type / bounds | Validation |
|---|---|---|
| `schema_version` | int, exactly1 | bool/float rejected |
| `guidance_type` | String | NONE / ATTACK / DEFEND / HELP / FOCUS_TARGET |
| `issuer_player_id` | String, stable actor ID | Must equal current Encounter Player ID |
| `preferred_target_id` | String | FOCUS_TARGET requires a known enemy ID; other types require `""` |
| `encounter_id` | non-zero signed int | Exact current Encounter ID; RefCounted IDs can be negative |
| `generation` | int ≥1 | Exact current generation |
| `round_id` | int ≥1 | Exact current round |
| `expected_guidance_revision` | int ≥0 | Exact current Guidance revision |

A known enemy at HP0 is still a valid **data preference**. Unknown/non-enemy IDs are rejected. Whether the preference is applicable belongs to M3A-03. FOCUS_TARGET never forces an NPC target or changes Enemy declared targets in this milestone.

```gdscript
var game = preload("res://scripts/combat/full_party_encounter.gd").new()
var data: Dictionary = game.guidance_snapshot()
var request: Dictionary = {
    "schema_version": 1, "guidance_type": "FOCUS_TARGET",
    "issuer_player_id": game.snapshot().player_id,
    "preferred_target_id": "enemy_b", "encounter_id": data.encounter_id,
    "generation": data.generation, "round_id": data.round_id,
    "expected_guidance_revision": data.guidance_revision
}
var reply: Dictionary = game.submit_guidance(request) # ACCEPTED
# NPC policy still chooses independently under exactly the pre-M3A rules.
```

Reply shape follows the existing `status` / `reason_code` convention:

- `ACCEPTED`, empty reason: data stored; revision increments once.
- `REJECTED`: `COMMAND_LOCKED`, `INVALID_GUIDANCE_FIELDS`, `INVALID_GUIDANCE_VERSION`, `INVALID_GUIDANCE_TYPE`, `INVALID_GUIDANCE_ID`, `INVALID_GUIDANCE_TARGET`, `INVALID_GUIDANCE_IDENTITY`, `FOREIGN_ENCOUNTER`, `STALE_GENERATION`, `WRONG_ROUND`, `INVALID_ISSUER`, `STALE_GUIDANCE_REVISION` or `UNKNOWN_GUIDANCE_TARGET`.
- `TERMINAL`, reason VICTORY/DEFEAT: no request accepted.

Validation precedence: terminal → lifecycle lock → request schema/types/ranges → encounter/generation/round/issuer/revision → enemy membership. Every rejection leaves combat and Guidance/profile/revision state unchanged. This is request rejection, not an NPC refusing a suggestion.

### Round lifecycle and revision

| Transition | Pending | Active | Guidance revision |
|---|---|---|---|
| Normal Restart | NONE with new generation/round identity | empty | reset0 |
| Valid submit while command-ready | accepted record | empty | +1 |
| Invalid/replayed submit | unchanged | unchanged | unchanged |
| Rejected Player command | preserved | empty | unchanged |
| Successful `begin_round()` | empty | deep copy of pending, frozen | unchanged |
| Any point in running queue, including gaps between actions | no edits accepted | frozen | unchanged |
| Round completion | NONE bound to next round | empty | retained |
| Terminal, including terminal impact before return | empty | empty | retained |
| Invalid Restart | unchanged | unchanged | unchanged |

Only accepted submissions increment Guidance revision. Round/generation identities prevent requests crossing lifecycle boundaries even when revision numbers coincide. Repeating identical content with a **fresh** expected revision is a valid edit; replaying the original request is rejected. Successful Restart resets the revision and increments generation, so an old request cannot become valid again.

Removing a preferred enemy through the existing command-ready roster API clears that obsolete pending preference to NONE. HP changes alone do not clear a known preference. Profiles follow stable IDs through reorder; register/remove keeps the profile map aligned with the NPC roster. No new roster mutation API is added.

### Fixed profile fixtures

Profiles use exact fields `schema_version`, `actor_id`, `player_id`, `discipline`, `trust`, `compassion`, `courage`. Actor/Player IDs must be valid and different. Version is integer1; enum values are strict.

| Stable ID | Discipline | Trust | Compassion | Courage |
|---|---|---|---|---|
| npc_01 | PLAN_ORIENTED | ESTABLISHED | ORDINARY | BOLD |
| npc_02 | FLEXIBLE | ESTABLISHED | HIGH | CAUTIOUS |
| npc_03 | FLEXIBLE | CAUTIOUS | ORDINARY | BOLD |
| Other valid NPC IDs | FLEXIBLE | CAUTIOUS | ORDINARY | CAUTIOUS |

These are explicit **test fixtures**, not established character personalities or final balance. Each profile's `player_id` binds Trust to the current session Player. Restart regenerates profiles; it does not inherit a relationship with a different Player. Self-preservation remains the unchanged safety policy, not a configurable trait score. Profiles are separate from ActorDefinition/ActorRuntimeState and are not read by decisions in M3A-02.

The accessor returns only detached dictionaries/scalars. Pending/active records contain type, issuer, preferred target, encounter/generation/round and accepted Guidance revision. Profiles are deep-copied on snapshot. No public API accepts arbitrary profile edits; external profile dictionaries cannot write session state.

### D01–D28 verification mapping

D01–D26 are focused cases with expected/actual results in `guidance-data-scenarios.json`. D27/D28 are full-regression gates, not fabricated focused assertions.

| Cases | Expected coverage |
|---|---|
| D01–D05 | Initial NONE; valid ATTACK/DEFEND/HELP/FOCUS A/B |
| D06–D09 | Strict enum/version/fields/types/issuer/target/foreign encounter |
| D10–D13 | Wrong generation/round/revision and replay; fresh NONE edit |
| D14–D16 | Pending/active/profile isolation; profile validation and stable-ID/Player binding |
| D17–D20 | Freeze after valid command only, no mid-round edit, next round NONE |
| D21 | Initial and mid-action victory/defeat clear Guidance and reject input |
| D22–D23 | Restart at six actors before/after effect; real delayed stale callbacks; invalid Restart atomic |
| D24 | NONE equivalence and strict Resolver context; Player40% + HELP still ATTACK |
| D25 | 1,600 paired rounds across all five data types, HP boundaries, both Player actions and enemy states; entire decisions/effects/gameplay snapshots equal (only independent Encounter ID normalized) |
| D26 | HP/HELP/guards/queue/token unchanged; known HP0 preference; removed target cleanup |
| D27 | Existing gameplay14,395 / negative983+five expected errors / exact Legacy presentation traces |
| D28 | Every inherited proof count retained, M2D-04 configured cutover / startup / rollback / release gates pass |

The paired comparison is supplemented by all unchanged inherited suites against the independently tested pre-implementation baseline; it does not replace that baseline. Existing tests/assertions/expected results were not weakened.

### Commands / evidence / acceptance

Use a new output directory for every run. `--guidance-data-proof` is opt-in and also works alone with the base combat suite. Full verification:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m3a02-final-UNIQUE \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof \
  --autonomous-main-proof --main-cutover-proof --guidance-data-proof \
  --cutover-baseline /tmp/wanderer-m3a02-pr39-reference-20261104-2
```

The cutover reference must be a passing **44-stage PR #39** run. This task exported `1728c5e` into a disposable source directory with a local Git index, then ran the original runner before touching runtime. It did not change the canonical branch or reuse imports. Fresh merged PR #40 `1facf144` then passed **52 stages** with all recorded reference counts and 6 cases / 5,892 equal Legacy trace frames before implementation.

Final results, source identity, commands and raw logs are linked in the [M3A-02 combat evidence section](../combat/README.md#m3a-02--guidance-data-verification). No new agent GUI/F5/F6 review is claimed for this data-only change. Owner-reported M2D-04 three-gate acceptance comes from the attached owner task; no independent scenario-level visual evidence was supplied. Historical M2D-04 pending evidence is preserved.

Final committed source **`be08f11`** passed **56 stages / exit0**, Guidance **66,641 checks / zero failures**, D01–D26 focused + D27/D28 full-regression gates. All inherited counts and Legacy6cases/5,892frames were preserved. [Expected/actual D01–D28](../combat/evidence/m3a-02/coverage.json), [Guidance case details](../combat/evidence/m3a-02/guidance-data-scenarios.json), [run record and exact commands](../combat/evidence/m3a-02/run-record.json). Later edits are documentation/evidence only, with [85/85 source hashes matched](../combat/evidence/m3a-02/source-comparison.json).

### Learning notes — ภาษาไทย

ใช้วงจร **Goal → Concept → Do → Observe → Explain → Adjust → Commit** ทีละขั้น:

1. **Data Contract:** `_fields()` ตรวจชื่อ key ครบและไม่มีเกิน ก่อนอ่านค่าจริง ลองลบ `round_id` แล้วดูว่า request ถูกปฏิเสธโดย state ไม่เปลี่ยน.
2. **Schema Version:** `schema_version = 1` บอกว่าผู้ส่งกับผู้รับใช้ข้อตกลงเดียวกัน การเพิ่มข้อมูลในอนาคตต้อง review version ไม่แอบยอมรับทุก key.
3. **Encounter Ownership:** `_guidance_pending` อยู่ใน Encounter ส่วน UI ในอนาคตมีหน้าที่ส่ง request และอ่านผล ไม่ถือสำเนาที่มีอำนาจเปลี่ยน gameplay.
4. **Pending / Active / Frozen:** ก่อนเริ่มรอบแก้ Pending ได้ เมื่อ `begin_round()` สำเร็จจะ copy ไป Active และปิดการแก้ จึงไม่เปลี่ยนคำชี้นำระหว่าง animation.
5. **Round Scope:** `_finish_round()` ล้าง Active และสร้าง NONE ที่มี round ใหม่ ลองส่งรอบ1 แล้วไม่ส่งรอบ2 ต้องเห็น NONE.
6. **Generation:** Restart เพิ่ม generation แม้ actionID หรือ Guidance revision จะเริ่มใหม่ request เก่าก็ถูกปฏิเสธเพราะ generation ไม่ตรง.
7. **Guidance Revision:** รับ request แล้วเพิ่มหนึ่ง ผู้ส่งที่ยังอ้าง revision เดิมจึงเขียนทับการแก้ใหม่ไม่ได้ และส่ง request ซ้ำไม่ได้.
8. **Deep Copy:** `duplicate(true)` แยก nested dictionaries ลองแก้ `view.profiles.npc_02.trust` จาก accessor แล้วอ่านใหม่ ค่าใน Encounter ต้องเหมือนเดิม.
9. **Atomic Validation:** `submit_guidance()` ตรวจทุกเงื่อนไขก่อนเพิ่ม revision/เขียน Pending; `restart()` สร้าง candidate registry/profiles ก่อนสลับ state จริง.
10. **Data ก่อน Policy:** โค้ดยังเรียก Resolver เดิมด้วย context เดิม จึงพิสูจน์ lifecycle ได้แยกจากการเปลี่ยนการตัดสินใจ ไม่เพิ่ม HELP50% หรือ follow/refuse logic ในขั้นนี้.

บทเรียนจาก development test: Godot RefCounted instance ID เป็น signed int และอาจติดลบได้ จึงตรวจ non-zero + identity equality แทนการบังคับให้เป็นบวก โดยไม่เปลี่ยน Encounter/token ID เดิม. เก็บ failed development run ไว้ใน evidence; ใช้ final committed-source run เป็นผลรับงาน.
