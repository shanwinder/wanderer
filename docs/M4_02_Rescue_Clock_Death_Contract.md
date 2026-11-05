# M4-02 — Rescue / Bleed-out / Death Contract & Owner Decision Gate

**M4-02 Contract Proposed / Awaiting Owner Decisions** • 5 พฤศจิกายน 2026 (Asia/Bangkok)

งานนี้ได้รับอนุญาตเฉพาะ **Design Review & Owner Decision Package** จากคำสั่ง owner “WANDERER — M4-02 Rescue / Bleed-out / Death Contract & Owner Decision Gate”. ไม่ใช่การอนุมัติ D03–D06/D09/D13/D17 หรือ M4-02 implementation. ทุกกฎ/ค่า/reason/schema ที่เสนอด้านล่างยัง **PROPOSED / PENDING OWNER APPROVAL**; ทุก M402 test ยัง **NOT RUN**. [Index](README.md#current-status-and-next-roadmap) ถือ Milestone Authority; เอกสารนี้ขยาย contract เฉพาะ M4-02 จาก [Architecture](M4_Down_Help_Death_Retreat_Architecture.md) ไม่สร้าง roadmap ใหม่. A01–A39 เดิมคงเป็น historical proposed scenarios.

## 1. Current implementation baseline and evidence attribution

| รายการ | ข้อเท็จจริงที่ตรวจในงานนี้ |
|---|---|
| Repository / canonical | `shanwinder/wanderer` / `visual-combat-test-1` |
| Actual canonical SHA | `e6c3cab7291a3cd45dcacdf48406cf48f0d67118`; ตรง expected baseline และ local HEAD / fetched origin / live remote head / merge-base ก่อนสร้าง branch |
| M4-01 merge | GitHub ยืนยัน [PR #46](https://github.com/shanwinder/wanderer/pull/46) merged เข้า canonical ที่ SHA ข้างบน วันที่ 5 พฤศจิกายน 2026 เวลา 13:54:38 Asia/Bangkok; PR head `841286b70fb11372805a21d7d48c4e8ad1720f22` |
| M4-01 current status | **M4-01 — Isolated Data/State Proof Implemented / Merged / Automated Proof Recorded**; ไม่ใช่ Playable M4, Full M4 Completed หรือ owner visual acceptance |
| Duplicate / working tree | initial tree สะอาด; open PRs มี #2/#17; local/remote branches และ GitHub M4-02 branch search ไม่พบงานซ้ำ; ไม่แก้/merge/cherry-pick #2/#17 |
| Task branch | `codex/m4-02-contract-owner-decision-gate` จาก canonical ข้างบน; documentation only |

**Inherited Evidence จาก PR #46 เท่านั้น ไม่ใช่การรันใหม่ใน M4-02:** actual engine `4.7.2.stable.official.ed1daf0bf`, executable `/Applications/Godot.app/Contents/MacOS/Godot`, tested source `0b3fd961b305e6c74027f35203b77505457f5409`. Expected คือ data/compatibility proof และ regression ผ่าน ไม่มี unexpected errors และ Legacy trace ตรงฐาน; recorded actual คือ **78 independent cases / 525 checks / 0 per-frame checks**, **69 stages PASS**, all stage exits0, unexpected errors0/timeouts0; negative suite มี **5 expected errors** แยก. Fresh canonical ของงาน M4-01 (`70922a6`) ผ่าน64 stages; Legacy **6 cases / 5,892 frames identical**. ไม่อ้างว่ารัน engine บน merge SHA หรือเอกสาร HEAD นี้.

คำสั่ง final เดิมเริ่ม `python3 tests/combat/verify.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output /tmp/wanderer-m4-01-final-20261105` พร้อม all proof flags และ reference path; **exact complete command**, expected/actual, commit, exits และข้อจำกัดอยู่ใน [run-record](../tests/actors/evidence/m4-01/run-record.json). ดู [69-stage results](../tests/actors/evidence/m4-01/final-results.json), [case results](../tests/actors/evidence/m4-01/m4-data-scenarios.json), [logs](../tests/actors/evidence/m4-01/logs.zip), [Legacy comparison](../tests/actors/evidence/m4-01/trace-comparison.json) และ [Actor guide](../tests/actors/README.md#m4-01--isolated-datastate-proof-candidate). เก็บ failed/corrected development records เดิม ไม่แก้ JSON/ZIP เพื่อเปลี่ยนประวัติ.

### Existing approved/implemented behavior vs proposed extension

| Existing contract inspected on canonical | Proposed M4-02 gap; ยังไม่มี runtime |
|---|---|
| [Isolated Party state](../scripts/m4/isolated_actor_state.gd): exact8-field snapshot, ALIVE/PRESENT HP>0, DOWN/PRESENT HP0, DEAD/PRESENT HP0, ALIVE/RETREATED HP>0; eligible derived; no raw heal | Episode/clock/resource ไม่อยู่ใน snapshot นี้; ห้ามเติม unknown fields ลง schema เดิม |
| [Isolated Registry](../scripts/m4/isolated_registry.gd): owned copied runtime ต่อ ID; capability-gated damage; validated object replacement | ยังไม่มี transaction ครอบคลุม runtime + encounter ledgers; M4-02 ต้องออกแบบ publication point เพิ่มโดยไม่สร้าง HP/LifeState authority ซ้ำ |
| [Isolated Encounter](../scripts/m4/isolated_encounter.gd): exact6-field fixture damage request /7-field grant; strict current revision; generation/used ledger; atomic Restart | ไม่มี RESCUE, episode, clock, phase, queue, terminal policy, death trigger หรือ event issuer; DEAD/RETREATED เป็น seeded fixtures เท่านั้น |
| [M4-01 proof](../tests/actors/m4_data_state_proof.gd): data subsets A01/A19/A21; assertions รวม absent rescue/clock APIs | ต้องใช้ opt-in M4-02 counterpart/harness ใหม่ใน task ภายหลัง ไม่เพิ่ม API จนทำให้ M4-01 assertion เดิมเสียหรือแก้ test ให้ผ่าน |
| [Production FullPartyEncounter](../scripts/combat/full_party_encounter.gd) / [GuidedEncounter](../scripts/combat/guided_encounter.gd): impact once, completion once, fixed queue, Player HP0→DEFEAT; `_finish_round()` ไม่ใช่ M4 event API | ห้ามต่อ production round callback/terminal migration ใน isolated proof; ไม่มี production `ROUND_CLOSED` ที่พิสูจน์แล้ว |
| HELP ของ NPC รักษา ALIVE Player ≤30%, +4 HP, one use/NPC/encounter; Guard/damage เดิม | RESCUE ไม่ใช่ HELP จาก HP0; ไม่แก้ HELP threshold/target/ledger/meaning |
| Guidance [Request v1](../scripts/npc/guidance_data_contract.gd) exact8 fields; [R1 Option A](../tests/npc/README.md#r1-option-a--current-m3a-04-contract) | ไม่มี RESCUE/RETREAT type; M4-02 ไม่เรียก/แก้ Pending/Frozen หรือ NPC policy |

Facts จาก source inspection ไม่ใช่ runtime verification ใหม่. D01 A/D02 B/D12 A เท่านั้นที่มี Owner Approval เดิมตาม Architecture §1. M4-01 merge ไม่อนุมัติค่าหรือ policy ของ M4-02.

## 2. D03–D06 alternatives and recommendation

| Decision | Option A | Option B | Recommendation / trade-off / risk |
|---|---|---|---|
| D03 | HELP overloaded: heal ALIVE หรือ rescue DOWN | คง HELP และเพิ่ม RESCUE แยก; candidate recovery1 HP | **B**: ความหมาย/หลักฐานชัด; 1 HP ทำให้พิสูจน์ขั้นต่ำ 0→1 ได้ง่าย แต่เปราะมากต่อ next hit และไม่ใช่ final balance; ค่าอื่นหรือ %HP ต้องแก้ matrix ก่อน implement |
| D04 | shared HELP/RESCUE use | RESCUE budget1/helper/encounter แยกจาก HELP | **B**: ไม่ทำให้ HELP ที่ใช้แล้วปิด rescue; เพิ่ม ledger และ chain rescue ได้หลาย helpers แต่จำนวนสำเร็จถูกจำกัดด้วยผลรวม initial rescue uses; ไม่ reset use เมื่อฟื้น |
| D05 | ROUND_CLOSED event, budget2, entry-round grace | N completed slots หรือ non-round whitelisted events | **A**: deterministic และไม่ไวต่อ actor count/animation; ต้องมี issuer/witness/idempotency; isolated witness ไม่พิสูจน์ production completion และ D10/D15 ยังจำกัดการเดิน clock |
| D06 | eligible tick ทำ B1→0 และ DOWN→DEAD ใน commit เดียว | คง DOWN จนระบบอื่น/post-combat ตัดสิน | **A เฉพาะ encounter-local proof**: ผลชัดและทดสอบ no resurrection ได้; ไม่อนุมัติ persistence/permadeath และไม่แก้ full-game lore |

ทุกแถว **PENDING OWNER APPROVAL** รวม 1 HP, one use, budget2 และ grace. คำว่า recommendation ไม่ใช่ approval.

### D03 eligibility and target identity

RESCUE lock ได้เฉพาะ helper และ target คนละ stable Party ID; helper ALIVE/PRESENT HP>0, target DOWN/PRESENT HP0 มี live episode, helper use1, fixture action window เปิด. ตรวจทั้ง lock และ impact; target ที่ lock ผิด reject ไม่สร้าง token/ไม่กิน use. Target ที่ valid ตอน lock แต่เปลี่ยนก่อน impact → legitimate operation **SKIP** โดยไม่ retarget. Helper unavailable มี precedence ก่อน target checks; target ไม่ PRESENT ก่อน DEAD ก่อน not-DOWN ก่อน episode mismatch แล้วจึง budget check. Validation ลำดับนี้เป็น proposed reason contract ไม่เปลี่ยน production reason codes.

สำเร็จที่ impact: DOWN/PRESENT HP0→ALIVE/PRESENT **HP1 (delta+1)**; retire active clock ของ episode; decrement เฉพาะ helper rescue use1→0; HELP และ uses ของทุกคนที่เหลือเท่าเดิม. ไม่ reserve/consume use ตอน lock, ไม่คืน use ที่ใช้ไปแล้ว, ไม่เพิ่ม slot หรือ reinsert actor. Isolated fixture ไม่มี production queue จึงพิสูจน์ได้เพียงไม่มี extra-slot effect/request; queue re-entry จริงยัง deferred.

- Target ฟื้นแล้ว → `M4_TARGET_NOT_DOWN`; target DEAD → `M4_DEAD_NOT_RESCUABLE`; target RETREATED → `M4_TARGET_NOT_PRESENT`; ID หาย/ไม่ใช่ Party → `M4_INVALID_TARGET`. ไม่มี fallback และไม่รักษา ALIVE แทน rescue.
- Target ฟื้นแล้วล้มใหม่ก่อน impact: episode เปลี่ยน → `M4_DOWN_EPISODE_CHANGED` แม้ ID/HP0 เหมือนเดิม. Episode key = `(session, generation, actor_id, down_sequence)`; sequence เพิ่มเฉพาะ fresh entry DOWN โดยไม่ recycle ใน generation. Retire episode เก่าแต่ไม่คืน budget; new entry ได้ B2 ตาม candidate D05. Initial DOWN fixture ต้องสร้าง episode ด้วย authorized constructor ไม่รับ caller-chosen episode authority.
- Helper2คน/targetเดียวกัน: future fixture อาจเก็บ grants2รายการเพื่อทดสอบ serialization แต่ไม่อ้าง simultaneous production actions. Commit แรกชนะ; อีก impact อ่าน current state แล้ว SKIP, ไม่ลด use. หาก target ล้มใหม่ให้ออก grant ใหม่หลัง fresh lock; grant episode เก่าช่วยใหม่ไม่ได้.
- Player ช่วย NPC ในอนาคต: effect contract อาจ role-neutral สำหรับ Party helper ใน fixture; **ไม่เพิ่ม Player RESCUE command** หรือ UI/action slot ในงานนี้. ต้อง task แยก review command validation/target selection/queue/input locking. NPC เลือก rescue/priorities/refusal/consent ต้อง D08/D16 และ versioned policy context แยก; fixture grant ไม่ใช่คำสั่ง puppet NPC.

## 3. D09 / D13 / D17 proof boundaries

| Decision / recommended Option A | จำกัดเฉพาะ isolated proof ที่เสนอ | ยังไม่ได้อนุมัติกฎเต็มเกม |
|---|---|---|
| D09 strict boundary | คง R1 Option A และ Request v1/eight fields; ไม่มี Guidance types/unknown fields ใหม่; M4-02 ไม่อ่านเขียน Pending/Frozen. Exceptional pre-round issuer change ต้อง reject ก่อน state change หรือ isolate fixture จาก command-ready path; valid Restart เท่านั้นเป็น recovery boundary ที่ proof นี้รู้จัก | ไม่เพิ่ม same-round Pending invalidation/revision/re-arm; ไม่อนุมัติ target/queue/Guidance migration ทั้ง D09; future production strict gate ยังไม่ได้ implement |
| D13 no Down evacuation | DOWN/RETREATED ยัง invalid; ไม่มี Carry/Evacuation/Retreat action; ALIVE/RETREATED seed ใช้ rejection tests เท่านั้น | ไม่ตัดสิน consent/carry/resource หรือการหนีของเกมเต็ม |
| D17 defer Down attack/aftercare | ไม่มี Attack DOWN, Stabilization, auto recovery, auto death หลัง abort/terminal, persistence/permadeath; fixture abort ปิดรับ effects โดยไม่เปลี่ยน DOWN เป็น DEAD | ไม่ยกเลิก v0.1/v0.5 intent; ไม่อนุมัติ terminal classifier D10 หรือ post-combat fate |

ข้อจำกัดทั้งสามยัง **PENDING OWNER APPROVAL** สำหรับ future M4-02 scope. Preservation ของ approved R1/schema เป็น compatibility requirement ปัจจุบัน ไม่ใช่ต้องขออนุมัติ R1 ใหม่.

## 4. State/resource ownership and publication model

| Owner ที่เสนอ | Sole mutable responsibility | Read/copy boundary |
|---|---|---|
| Registry-owned M4 Party RuntimeState | HP/LifeState/Participation ต่อ stable ID ชุดเดียว | immutable validated state object; detached snapshots; no raw resurrection setter |
| M4-02 isolated Encounter aggregate | registry reference, episode/entry-round/remaining clock ledger, rescue-use ledger, owned action grants/phases, event grants/consumption, generation/revision, explicit fixture phase | episode ledger **ไม่เก็บ authoritative HP/LifeState ซ้ำ**; eligible derive จาก runtime; HELP compatibility sentinel เป็น read-only fixture assertion ไม่สร้าง production HELP authority ใหม่ |
| Test-only Fixture Event Issuer | ออก grant ตาม finite scripted boundary witness ให้ Encounter ตรวจ | immutable copied event; ไม่อาศัย UI timer หรือ caller dictionary ว่า completed=true |
| Future Resolver/controller/presenter | ไม่มี mutation authority ใน proof | snapshots/actual effect เท่านั้น; no await/UI/signal ใน commit |

**Recommended atomic publication:** future M4-02 counterpart เก็บ owned aggregate root หนึ่งตัว. สร้าง candidate registry ด้วย validated copies และ candidate ledgers/grant phase/event ledger จาก root ปัจจุบัน; ตรวจครบก่อน **swap root เพียงครั้งเดียว**. Candidate เป็น scratch data ไม่ใช่ mutable authority ตัวที่สอง; old roots เป็น immutable detached history และไม่มี writer. Registry ยังเป็นเจ้าของ HP/state เพียงชุดใน published root. ห้าม Registry commit state ก่อนแล้วค่อยเขียน budget/clock ที่อาจ fail/emit callback. ไม่ต้องเพิ่ม mutable HP mirror, singleton หรือ event bus.

Reusing M4-01 factories/copy contract ทำได้ตาม future review; **คง M4-01 exact schemas, damage semantics, absent-API assertions และ evidence**. แนะนำ new opt-in M4-02 Encounter/harness ที่ compose validated registry/state types ไม่ขยาย existing M4-01 encounter โดยตรง. Exact new versioned diagnostic accessor/root layout ต้อง review ใน implementation task; ไม่ append episode/clock/use ลง original M4-01/production snapshot. Atomic หมายถึง synchronous single-threaded publication; ไม่ใช่ multiplayer, hostile-code security หรือ multi-thread isolation.

## 5. RESCUE atomic transaction and failure contract

Proposed action grant มี exact reviewed fields ของ isolated namespace: schema version, session/generation, operation ID, authorization ID, kind=RESCUE, helper ID, target ID, down episode ID, fixture window ID, lock revision. Values ต้อง typed/validated และตรง Encounter-owned grant ทุก field. Client เปลี่ยน destination/amount/recovery HP/budget ไม่ได้; candidate policy เป็นของ Encounter. นี่เป็น **schema proposal** ไม่ใช่แก้6/7-field M4-01 damage request/token หรือ production token.

1. Authenticate shape/types, owned grant และ operation/token identity; reject forged/altered/unissued.
2. Validate session/generation ก่อน state lookup ของ ID ที่อาจถูก reuse.
3. ตรวจ unused operation/current phase/window; consumed action → duplicate reject. Fixture abort → reject closed phase. Lock revision เป็น audit; impact อ่าน current owned revision และสร้าง candidate ที่ revisionนั้น ไม่เชื่อ caller-supplied current revision.
4. Validate helper ALIVE/PRESENT/HP>0 และ Party.
5. Validate target Party/life/participation ตาม precedence ใน §2.
6. Validate current episode ตรง locked episode.
7. Validate rescue use เป็น int1; use0 → `M4_RESCUE_EXHAUSTED`.
8. Calculate HP1/ALIVE, retired clock, unchanged episode serial, helper use0 และ operation result.
9. Validate complete candidate: HP bounds/pairs/identity/roster/copy/episode-clock consistency/use0..1, unchanged unrelated resources; no intermediate HP0/ALIVE.
10. Publish aggregate atomically รวม state/clock/resource; successful impact revision+1.
11. Mark operation consumed **inside same publication**, ไม่ใช่ขั้น mutation ที่อาจล้มหลัง state publish. ขั้น10–11เป็น logical parts ของ commit เดียว.
12. คืน detached Actual Effect: status/reason, helper/target/episode identity, actual HP delta, life before/after, clock before/after, rescue-use delta, committed revision; decision-at-lock ไม่ถูก rewrite.
13. Reject duplicate/stale operations; completion รับได้ครั้งเดียวหลัง APPLIED/SKIP แต่ไม่ทำ effect อีก.

**Revision distinction:** M4-01 fixture damage ยังคง exact current revision. Future rescue lock revision ไม่ใช่ requirement ว่า world revisionต้องเท่าเดิมที่ impact เพราะ valid target death/rescue/helper damage อาจเกิดระหว่าง lock→impact ใน fixture. ตรวจ owned grant/phase/window/episode และ revalidate live state แทน; candidate ต้องสร้างจาก current root และเทียบ root revisionก่อน publish (ถ้าเปลี่ยนให้ reject `M4_STALE_REVISION`, no delta). ห้ามแก้ token caller เพื่อให้ผ่าน revision. ไม่มี await/reentrant mutation ใน critical section. Event sealed revision ใช้กฎเข้มกว่าใน §6.

| Outcome / failure | Effect and accounting | No-delta invariant |
|---|---|---|
| APPLIED / `M4_RESCUED` | HP+1, DOWN→ALIVE, clock retired, helper use−1; consumed impact; revision+1 | unrelated actor/resources/HELP/roster/queue/Guidance ไม่เปลี่ยน |
| SKIP / actor unavailable, target invalid/not present/dead/not down/episode changed, use exhausted | valid grant one-shot settles SKIPPED; revision+1/actual result recorded; no resource charge; completion may drain once | **N-effect:** HP/life/participation/clock/all uses/roster unchanged relative to just-before-impact; phase/consumption/result/revision เท่านั้นที่เปลี่ยน |
| REJECTED / malformed, unauthorized, foreign/stale generation, duplicate, wrong phase/window/revision | ไม่ consume legitimate unused grant, ไม่เพิ่ม revision; caller ต้อง fresh lock/request เมื่อเหมาะสม | **N-all:** entire published root รวม grants, consumption, counters, episodes, clocks, budgets, phase/revision/generation และ roster ตรง before; log/output ไม่ใช่ authority |
| Invalid candidate / `M4_INVALID_CANDIDATE` | reject publication ทั้งชุด; injected validation failure ใน future test | N-all; ห้าม HP1 แต่ use1 หรือ HP0/ALIVE หรือเสีย use โดยไม่ฟื้น |
| Cancel before impact | authorized fixture cancellation closes action once (`M4_ACTION_CANCELLED`); no rescue effect; old impact → phase reject | N-effect; cancellation accountingเท่านั้นเปลี่ยน ไม่มี refund เพราะยังไม่ consume use |

เหตุผล lifecycle ใช้ proposed `M4_ACTOR_UNAVAILABLE`, `M4_INVALID_TARGET`, `M4_TARGET_NOT_PRESENT`, `M4_DEAD_NOT_RESCUABLE`, `M4_TARGET_NOT_DOWN`, `M4_DOWN_EPISODE_CHANGED`, `M4_RESCUE_EXHAUSTED`. Protocol reasons ที่เสนอ: `M4_INVALID_FIELDS`, `M4_UNAUTHORIZED`, `M4_FOREIGN_SESSION`, `M4_STALE_GENERATION`, `M4_DUPLICATE_OPERATION`, `M4_INVALID_PHASE`, `M4_STALE_REVISION`. ตรวจ protocol ก่อน domain, จึง replay สำเร็จแล้วได้ duplicate ไม่ใช่ target-not-down. ทั้งหมดไม่เปลี่ยน existing production/M4-01 reason strings.

## 6. Bleed-out event and encounter-local death contract

**Single clock source:** encounter-authorized `ROUND_CLOSED` หลัง natural round completion เท่านั้น. ไม่ใช้ seconds, completed-slot count เป็น cadence, speed initiative, animation duration หรือ UI timer. Fixture อาจตรวจ completion witness ของ slot เพื่ออนุญาต close แต่ไม่ได้ tick ตามจำนวน slot.

M4-01 ไม่มี queue/clock authority. **Future isolated proof ต้องมี test-only Fixture Event Issuer** และ finite script ของรอบที่ระบุชัดเจนล่วงหน้า. Issuer เก็บ owned round witness: session/generation/round ID, non-empty expected fixture slot IDs, completion set ที่ไม่ซ้ำ, outstanding operation set, abort flag และ explicit reviewed fixture phase. Receipt ของ slot ใช้ opaque owned fixture operation ไม่รับ caller count/boolean; ไม่เรียก production queue. ต้องครบทุก receipt, no pending impact/completion, no abort, no earlier close, current generation, Player ALIVE/PRESENT, active Party และ Enemy HP>0 อย่างน้อยหนึ่ง ก่อน seal. Preconditions นี้เป็น **conservative admission boundary ของ fixture**, ไม่ใช่อัลกอริทึมตัดสิน VICTORY/DEFEAT. Wrong/empty witness reject; ไม่มี auto-begin/auto-close หรือ while-loop สร้าง rounds.

Proposed event fields: version, kind=`ROUND_CLOSED`, issuer ID, session, generation, round ID, event ID, witness ID, sealed revision, authorization ID; exact validated typed fieldsตรง owned issued grant. Authenticate issuer capability + compare grant + current witness ก่อน apply. Caller ส่ง `ROUND_CLOSED` string/round numberเองไม่สร้างสิทธิ์. Opaque identity/underscore API เป็น test harness convention ไม่ใช่ production security system.

- **Event ledger แยก action token:** operation consumed keys และ event consumed keys ไม่ใช้แทนกัน. Event primary key `(session,generation,issuer,event_id)`; semantic close key `(session,generation,round_id)` กัน event ID ใหม่ close รอบเดิมซ้ำ. ทั้ง grace-only และ no-DOWN close ต้อง consume semantic key เพื่อกัน late entry/replay. Duplicate key → `M4_DUPLICATE_ROUND_CLOSED` no delta.
- **Ordering/phase:** accept เฉพาะ current sealed natural boundary; out-of-order/old/future round → `M4_INVALID_ROUND`; wrong kind/types/issuer/witness → `M4_INVALID_EVENT`; pending work → `M4_ROUND_NOT_CLOSABLE`. Event sealed revision ต้องตรง current root; ถ้า fixture effect เปลี่ยน root ให้ reject `M4_STALE_REVISION` และ revalidate/reseal fresh event โดยยังไม่ consume close key. หลัง sealไม่อนุญาต new rescue lock; valid pending rescue ต้อง settle ก่อน seal. Late fixture race ใช้ explicitly ordered scripts ไม่อ้าง concurrency.
- **Tick calculation:** อ่าน pre-tick set ของ DOWN/PRESENT episodes ทั้งหมด; entry round==closing round → grace Bคง2 (`M4_BLEED_GRACE`); older entry → decrement1 floor0 (`M4_BLEED_TICK`); ไม่มี episodeใน future round. ALIVE/DEAD/RETREATED ไม่ tick. Batchทุก episode ใน candidateเดียว; event revision+1ครั้งเดียว; return `M4_ROUND_CLOSED` พร้อม per-episode results. Event failure ไม่ partially tick actorแรก.
- **Death:** เมื่อ eligible B1→0 ให้ Encounter-authorized DOWN/PRESENT→DEAD/PRESENT และ HP0เดิม ใน publicationเดียวกับ clock+event consumed (`M4_BLED_OUT`). Death clock view retain0 แต่ inactive, ไม่ tickติดลบ; retire rescue eligibility. ห้ามเรียก damage0/write HP0ซ้ำเพื่อสั่ง DEAD. ไม่ลบ ID/unregister/definition/save file, ไม่มี revival/rescue, animation, aftercare หรือ permadeath implementation. DEAD เป็น irreversible life state เฉพาะ generation/encounter; valid Restart เป็น session reset ไม่ใช่ resurrection action.
- **Rescue:** ถ้าฟื้นก่อน boundary clock retired จึงไม่ tick; new DOWN ได้ new episode/entry round/B2 แต่ rescue usesที่ใช้แล้วไม่คืน. ต่อให้ eventอ้าง roundถูกต้องต้องคำนวณจาก current episodes ไม่ replay cached actor deltas. ไม่มี per-actor external tick API ข้าม event ledger.

| Ordered fixture event | Life / HP | Active clock |
|---|---|---|
| Authorized NPC entry DOWN ระหว่าง round3 | DOWN/PRESENT HP0, episode e1 | B2, entry3 |
| Natural close3 ผ่าน witness | DOWN/PRESENT HP0 | B2, grace; close3 consumed |
| Natural close4 | DOWN/PRESENT HP0 | B1 |
| Natural close5 | DEAD/PRESENT HP0 | B0 inactive; `M4_BLED_OUT` |
| Alternative: RESCUE impact ก่อน seal close5 | ALIVE/PRESENT HP1 | e1 retired; close5 ไม่มี tick สำหรับ e1 |
| Alternative: fresh rescue request หลัง close5 death | DEAD/PRESENT HP0 | B0; reject lock `M4_DEAD_NOT_RESCUABLE` |

Clock apply ใช้ pipelineใน §5 โดยแทน helper/target/resource validation ด้วย issuer/witness/event identity/current episode batch validation. Candidate root มี event ledgersกับทุก clock/deathผล; commitและconsumeใน swapเดียว. Event outer resultบอก closeสำเร็จ; per-episode reasonบอก grace/tick/death; duplicate/invalid/stale event N-all.

## 7. Restart, generation and episode safety

**Valid Restart:** validate entire new fixture roster + paired HP/life + new phase/witness/episode/use candidates ก่อน publish; generation+1, revision0, new rescue budget1/helper, HELP fixture reference resetเฉพาะค่าตั้งต้นที่ taskกำหนด, new ledgers/episodes/witnesses, no reused authorization serial. Session ID คงใน Encounter instanceเดียว; foreign instance reject. Initial DOWN seedสร้าง B2/new entry roundโดย explicit validated fixture setup. Retain old snapshotsได้แต่อ่าน/แก้ copyไม่กระทบ authority. ทุก action/event/cancel/completionเก่าต้อง `M4_STALE_GENERATION` ก่อนดู IDsใหม่.

**Invalid Restart:** malformed last row/duplicate ID/invalid pair/invalid episode-clock pair/budget type rejectทั้งหมด (`M4_INVALID_RESTART`). Actor HP/life, roster, session/generation/revision, budgets, action/event grants, outstanding witness receipts, consumed keys และ authorization countersต้องไม่เปลี่ยน; legitimate pending action/eventจากก่อน invalid Restartยัง applyได้. ไม่ล้าง ledgerก่อน validate. Restartไม่ทำให้ ALIVE/RETREATED seedกลายเป็น action re-entryใน encounterเดิม.

## 8. Clock and terminal interaction — D10/D15 remain pending

Architecture §7–8 ordering/outcomeเป็น **full proposed design**; ไม่ import terminal evaluationหรือ autonomous continuationมา M4-02โดยเงียบ ๆ. ใน proofมีเพียง explicit fixture phase/witness ไม่ตั้ง `VICTORY`, `DEFEAT`, survivor summary หรือ Player continuation policy ใหม่.

| Boundary situation | Future isolated test allowed after seven scope decisions | Blocked/deferred production question |
|---|---|---|
| Natural close; Player/active Party/Enemy remain available | finite non-empty completed fixture witness → authorized event, grace/tick/death batch | Production `_finish_round` emits exactly onceและ adapter orderingต้อง future reviewed integration |
| Terminal result reached at action impact | fixture explicit ABORT before seal → reject close/effects, preserve Down; no synthetic natural close | เมื่อใดถือ terminal/precedence/effect-vs-completion ต้อง D10; fixtureไม่ได้พิสูจน์ classifier |
| Last active Party becomes DOWN | block issuer admission `M4_BOUNDARY_DEPENDENCY`; no clock delta/no outcome/no new round | D10 decides defeat/suspend; D15 scheduler cannot be invented |
| All remaining Party DOWN | same block; no eligible helper, no empty-round loop, no auto death | Down fate/continuationต้อง D10/D15/D17; ไม่เรียก B2ว่า guaranteed two playable rounds |
| All enemies unavailable before completion | block close `M4_BOUNDARY_DEPENDENCY` หรือ explicit fixture abort; no fake receipts/clock | Victory/abort boundaryต้อง D10; productionเดิมยัง HP0→unavailable ไม่ใช่ DEAD |
| Player DOWN แต่ NPC/Enemyยังพร้อม | isolated RESCUE effect on Playerทำได้โดย fixture; round issuance blocked | Natural next roundเมื่อไม่มี Player inputต้อง D15/D09/D10; ไม่สร้าง fake DEFEND |
| Rescue and bleed-out near same boundary | order R: valid rescue impact→complete→seal→close = ALIVE1/no tick; order C: close→death→new rescue lock rejects | No simultaneous tie-break/animation scheduling claim; real runtime adapterต้อง settle actionsก่อน close |

**Blocked/Deferred Test** ต้องคงเป็นเช่นนั้นจน ownerตัดสิน D10/D15และ task integrationแยก. Abort behaviorพิสูจน์แค่ no synthetic close/no auto aftercare; ไม่อนุมัติ full terminal freeze policy/outcome. หาก implementationต้องอาศัย terminal decisionจึงทำ testผ่าน ให้หยุดส่วนนั้นและรายงาน dependency; ห้ามสร้าง infinite empty rounds, UI-authoritative timer หรือ fake completion.

## 9. Future M4-02 proof acceptance matrix — Proposed / NOT RUN

Namespace **M402-xx** ไม่แทน/renumber A01–A39. ตารางเป็น executable test design ภายใต้ recommendations; ไม่มี actual PASS. Defaultsทุกแถว: fresh sessionS/generationG, Party Player P ALIVE10/PRESENT, helper H ALIVE10/PRESENT, target T NPC DOWN0/PRESENT episode e1 entry3/B2, rescue uses `R(H)=1`, `R(J)=1` สำหรับ helper Jถ้าใช้; HELP sentinel `U(H)=1`; Enemy A HP10; current fixture round3/no abort. MaxHP10ทุก Party; named actorอื่นไม่เปลี่ยนเว้นแต่ setupระบุ. Rescue grant `r1` เป็น owned grant H→T/e1; event `cN` เป็น owned authorized natural closeN with full finite witness; setupต้องให้ round/entryสอดคล้อง. ก่อน applyทุก stepเก็บ entire before snapshotรวม private diagnostic ledgersเพื่อ no-delta comparison; setup deltasไม่ใช่ effect deltas. `R`=rescue resource, `B`=bleed budget, `∅`=inactive retired clock, `D`=D03B/D04B/D05A/D06A/D09A/D13A/D17A + separate implementation authorization. “No extra slot” ใน proofหมายถึง effectไม่ออก schedule request; production schedulingอยู่ deferred.

| ID / preconditions | Exact input / event | Expected result / reason code | Expected HP / LifeState | Expected clock / resource | No-delta assertions | Owner dependency |
|---|---|---|---|---|---|---|
| M402-01 default | lock r1; impact r1; complete r1 | APPLIED `M4_RESCUED`; complete once | T0DOWN→1ALIVE/PRESENT | B2→∅; R(H)1→0; U1 | no extra slot; unrelated IDs/uses/HELP unchanged | D |
| M402-02 T=Player P DOWN0/e1; H healthy | fixture lock/impact H→P | APPLIED `M4_RESCUED`; no Player command | P1ALIVE; H10ALIVE | P clock∅; R(H)0 | UI/Guidance/production untouched | D; D15 integration deferred |
| M402-03 T rescued once, R(H)=0; authorized new DOWN e2 | fresh H→T/e2 lock | REJECTED `M4_RESCUE_EXHAUSTED` | T0DOWN | e2 B2; R0/U1 | N-all vs just before lock; no refund | D |
| M402-04 U(H)=0 from fixture; R(H)=1 | lock/impact r1 | APPLIED `M4_RESCUED` | T1ALIVE | B∅; R0; U stays0 | HELP exhaustion independent; no HELP reset | D |
| M402-05 M402-01 impact applied | replay impact r1; then replay completed callback | REJECTED `M4_DUPLICATE_OPERATION` / `M4_INVALID_PHASE` for completed callback | T1ALIVE | B∅; R0/U1 | N-all per replay; HP+1/use−1 only once | D |
| M402-06 r1 lock before T death would require close with pending impact | proposed late r1 after death; separately pure eligibility check on detached DEAD0 snapshot | **BLOCKED end-to-end fixture ordering**; pure validator expected `M4_DEAD_NOT_RESCUABLE` | T0DEAD in validator input; no runtime transition claimed | B0/R1 unchanged in validator; no event bypass | pure check writes nothing; natural issuer must reject pending-r1 close | D; reviewed fixture seam needed; no production race claim |
| M402-07 T initially DEAD0/B0 | fresh rescue lock | REJECTED `M4_DEAD_NOT_RESCUABLE` | T0DEAD | B0; R1 | N-all; no grant | D |
| M402-08 r1 locked; fixture J rescue T before r1 | impact r1 | SKIP `M4_TARGET_NOT_DOWN` | T1ALIVE | B∅; R(H)1/R(J)0 | N-effect at H impact | D |
| M402-09 r1 locked; J rescues T then authorized damage downs T as e2 | impact r1/e1 | SKIP `M4_DOWN_EPISODE_CHANGED` | T0DOWN/e2 | new B2/entry current; R(H)1/R(J)0 | N-effect; e2 not retired by e1 | D |
| M402-10 H/J grants target same e1 before either impact | impact H then J; repeat fresh fixture opposite order | first APPLIED `M4_RESCUED`; second SKIP `M4_TARGET_NOT_DOWN` | T1ALIVE | B∅; winner R0/other R1 | only one HP delta; no simultaneous production claim | D |
| M402-11 r1 locked; authorized helper damage H10→0DOWN | impact r1 | SKIP `M4_ACTOR_UNAVAILABLE` | T0DOWN; H0DOWN | T B2; H new B2; R(H)1 | N-effect; target untouched | D |
| M402-12 H seeded DOWN0 / DEAD0 / ALIVE7 RETREATED, separate fixtures | H→T lock | REJECTED `M4_ACTOR_UNAVAILABLE` | H seeded; T0DOWN | T B2; R1 | N-all for every fixture | D |
| M402-13 target ID missing / Enemy A / self H, separate inputs | lock RESCUE to each ID | REJECTED `M4_INVALID_TARGET` | all HP/life unchanged | B2/R1/U1 | N-all incl roster | D |
| M402-14 T ALIVE7/RETREATED seed | rescue lock T | REJECTED `M4_TARGET_NOT_PRESENT` | T7ALIVE/RETREATED | no active clock; R1 | N-all; no re-entry | D |
| M402-15 T ALIVE4/PRESENT seed | rescue lock T | REJECTED `M4_TARGET_NOT_DOWN` | T4ALIVE | clock∅; R1 | N-all; no healing substitute | D |
| M402-16 r1 owned unused | alter target/episode/helper/auth ID; unissued rX; missing/extra/type field, each copy | REJECTED `M4_UNAUTHORIZED` or `M4_INVALID_FIELDS` by protocol gate | T0DOWN | B2/R1/U1 | N-all; original r1 still valid | D |
| M402-17 r1 owned unused | foreign-session r1; old-generation r1 after valid Restart, separate calls | REJECTED `M4_FOREIGN_SESSION` / `M4_STALE_GENERATION` | receiving fixture unchanged | receiving clocks/uses unchanged | N-all incl new IDs/grants | D |
| M402-18 r1 locked unused | authorized cancel r1; delayed impact r1 | cancel `M4_ACTION_CANCELLED`; impact REJECTED `M4_INVALID_PHASE` | T0DOWN | B2; R1 | N-effect on cancel; N-all late impact | D |
| M402-19 r1 valid; inject complete-candidate validation failure | impact r1 | REJECTED `M4_INVALID_CANDIDATE` | T0DOWN | B2; R1 | N-all incl revision/consumed ledger | D |
| M402-20 r1 valid | impact and read every published snapshot before/after | `M4_RESCUED`; no partial observation | only T0DOWN or T1ALIVE | only (B2,R1) or (∅,R0) | no HP0/ALIVE, HP1/DOWN or free rescue | D |
| M402-21 default entry3 | issue/apply c3; replay c3 | `M4_ROUND_CLOSED`/per-T `M4_BLEED_GRACE`; replay reject duplicate | T0DOWN | B2 stays2/R1 | first only close ledger/revision changes; replay N-all | D |
| M402-22 after close3, finite nonempty round4/5 witnesses | c4 then c5 | close/per-T `M4_BLEED_TICK`, then `M4_BLED_OUT` | T0DOWN→0DEAD | B2→1→0 inactive; R1 | no HP write/rescue use; one batch/revision per close | D |
| M402-23 c4 already applied at B1 | replay same event; forged fresh event ID with round4 | REJECTED `M4_DUPLICATE_ROUND_CLOSED` for semantic key after valid identity gate; forged grant `M4_INVALID_EVENT` | T0DOWN | B1/R1 | N-all; not double tick | D |
| M402-24 current round4 after close3 | valid-looking c2/c5 or wrong kind/issuer/witness/type/extra fields | REJECTED `M4_INVALID_ROUND` for authenticated wrong round; otherwise `M4_INVALID_EVENT` | T0DOWN | B2/R1 | N-all; no event key consumed | D |
| M402-25 c4 sealed; valid fixture transition changes root before event apply | apply old c4; then revalidate/reseal fresh c4 | reject `M4_STALE_REVISION`; fresh close may succeed once | current target state retained on reject | no clock/use delta on reject | N-all; old seal not trusted; no duplicate close | D |
| M402-26 T B1 entry2; rescue settled before seal3 | impact r1; complete; c3 | `M4_RESCUED`; close `M4_ROUND_CLOSED` no T tick | T1ALIVE | B∅; R0 | close no new HP/use delta | D |
| M402-27 T B1 entry2, no pending rescue | c3 death; attempt fresh rescue lock | `M4_BLED_OUT`; REJECTED `M4_DEAD_NOT_RESCUABLE` | T0DEAD | B0 inactive; R1 | lock N-all; cannot undo death | D |
| M402-28 T DEAD0 after B0; P/H active, Enemy available | next valid cN, then unauthorized raw HP0/death request | close no T tick; raw request REJECTED `M4_INVALID_FIELDS` | T0DEAD | B0, never−1; R1 | T unchanged; only valid close accounting changes | D |
| M402-29 J/T DOWN B1/B2 entry2; both eligible | c3 batch; alternate inject candidate failure on second row | success: T tick/Jdeath; failure: `M4_INVALID_CANDIDATE` all rejected | success J0DEAD/T0DOWN; failure bothDOWN0 | success J0/T1; failure J1/T2; all R unchanged | all-or-none root/event ledger | D |
| M402-30 after rescue e1; T down again round4 e2 | c4 then c5; r1/e1 late replay | grace then tick; replay duplicate (or episode mismatch for unused old grant) | T0DOWN/e2 | B2 then1; used R not restored | old episode cannot change e2 | D |
| M402-31 action r1 and event grant outstanding in separate valid fixtures | valid Restart then old impact/event/complete | old inputs REJECTED `M4_STALE_GENERATION` | exact new fixture HP/life | new clocks/uses, revision0/gen+1 | N-all for old calls; no old clock death | D |
| M402-32 pending r1 / sealed c3, separate fixtures | invalid Restart with malformed final row / duplicate ID / invalid pair / inconsistent clock; then original operation | `M4_INVALID_RESTART`; original r1 or c3 still valid | before unchanged on reject | grants/witnesses/B/R/U unchanged | N-all incl counters/generation/revision; no premature reset | D |
| M402-33 r1 rescue succeeded; old event consumed | valid Restart valid roster; fresh lock/close | new generation accepted; `M4_RESCUED`/`M4_ROUND_CLOSED` | new fixture exact; fresh rescue1ALIVE | R initialized1 then0; old ledgers isolated | Restart not in-encounter revive/refund | D |
| M402-34 T DOWN B1; explicit authorized fixture abort before seal | attempt cN and pending r1 | REJECTED `M4_INVALID_PHASE` | T0DOWN | B1/R1; no auto death/recovery | N-all after abort; no natural completion emitted | D; D10 classifier deferred |
| M402-35 incomplete or duplicate slot receipts / outstanding impact or completion | request seal/close current round | REJECTED `M4_ROUND_NOT_CLOSABLE` | unchanged HP/life | unchanged B/R/U | N-all; receipt duplicate cannot satisfy another slot | D |
| M402-36 empty fixture slot script / all Party DOWN / no active Enemy / Player DOWN, separate cases | attempt fixture round start/seal repeatedly (bounded attempts) | empty `M4_ROUND_NOT_CLOSABLE`; availability `M4_BOUNDARY_DEPENDENCY` | seeded state preserved | no B/use delta | N-all; no auto rounds/loop/outcome | D; D10/D15 integration deferred |
| M402-37 ALIVE/RETREATED seeded plus DOWN T | c3 then invalid DOWN→RETREATED request | close excludes retreated; transition REJECTED `M4_EVACUATION_UNSUPPORTED` | seeded state; T0DOWN | grace B2; R unchanged | invalid request N-all | D |
| M402-38 DOWN/DEAD T | unauthorized heal, attack-DOWN, stabilize, aftercare/revive requests (separate inputs) | REJECTED `M4_TRANSITION_UNSUPPORTED`; DEAD rescue uses exact dead reason | T0DOWN or0DEAD unchanged | B/R/U unchanged | N-all; no persistence/ID deletion | D |
| M402-39 original M4-01 snapshot/copies retained | run unchanged original78-case proof; mutate detached proposed M4-02 read views | original exact contracts; copies cannot publish | owned HP/life unchanged by copies | B/R/episode/grants unchanged | no M4-01 assertion/schema weakening | D; future runtime evidence required |
| M402-40 canonical production/Legacy | run full existing runner flags + future opt-in proof; A-first/B-first, guards/HELP, Restart/actions, lock/fallback, terminal/startup and Legacy traces | existing exact baseline reasons/results retained | existing expected HP; Main Player0→DEFEAT | production HELP unchanged; no M4 clock/resource fields | counts/assertions not lowered; speed0.70/lunge44/Compact Formation source preserved | D; headless not visual acceptance |
| M402-41 original Guidance v1/R1 / Pending and Frozen fixtures | existing strict-schema/R1 tests incl unknown field reject; compare protected production hashes | original reasons/revision behavior | production HP/actors unchanged | M4-02 cannot mutate Guidance/queue | exact8 fields/types, no RESCUE enum or Pending/Frozen writes | D; full D09 extension deferred |
| M402-42 no DOWN actors; current valid nonempty witness | c3; later attempt second close3 with another event ID | close consumed with empty episode results; second duplicate reject | all ALIVE HP unchanged | no clock, uses unchanged | second N-all; no late entry can reuse close3 | D |
| M402-43 r1 locked in windowW | genuine token applied outside W; completed token reused as event | REJECTED `M4_INVALID_PHASE` / `M4_INVALID_EVENT` | T0DOWN unless setup differs | B/R/U unchanged | N-all; action/event ledgers not interchangeable | D |
| M402-44 fixture event valid; candidate compares different root revision at final publish gate | apply close | REJECTED `M4_STALE_REVISION` | entire current state retained | clocks/uses unchanged | N-all; no partial batch/consumed key | D |
| M402-45 same H owns r1→T/e1 and r2→J/eJ in revalidation fixture; both targets DOWN | impact r2 success then r1 | r2 APPLIED `M4_RESCUED`; r1 SKIP `M4_RESCUE_EXHAUSTED` | J1ALIVE; T0DOWN | Jclock∅; TB2; R(H)0 stays0; U1 | r1 N-effect; no resource underflow; fixture not production multi-slot claim | D |

**M402-06 design finding:** ภายใต้ proposed serialized natural-close contract เป้าหมายตายด้วย bleed-outขณะ rescue impactค้างอยู่ไม่ได้ เพราะ issuerต้องปฏิเสธ close. จึง **BLOCKED end-to-end** จน review fixture seam/orderingได้โดยไม่ bypass gate. Future pure eligibility-validator test ใช้ detached DEAD0/current episode snapshotเพื่อพิสูจน์ `M4_DEAD_NOT_RESCUABLE` และ no writesได้ แต่ไม่เรียกว่า authorized death-before-impact integrationผ่าน. ไม่เพิ่ม direct death mutationหรือfake closeเพื่อทำ caseนี้; M402-27 พิสูจน์ authorized deathก่อน fresh rescueได้. Domain contractยังต้อง defensive revalidate DEADที่ impactสำหรับ future adapter; clock orderingไม่ใช่เหตุให้ลบ guardนี้.

### Blocked / deferred tests — no expected production outcome imported

| ID / preconditions | Exact future input | Expected result / reason | HP/life; clock/resource expectation | No-delta / current safe boundary | Owner dependency |
|---|---|---|---|---|---|
| M402-D01 last active Party ALIVE1; others DOWN | production lethal impact | **BLOCKED**, outcome/reason undecided | after authorized data damage0DOWN; whether scheduler continues undecided; no synthetic B tick | fixture admission rejects `M4_BOUNDARY_DEPENDENCY`; no auto death | D10/D15 + separate queue task |
| M402-D02 all Party DOWN | request actual next production round | **BLOCKED**, terminal/suspend reason undecided | DOWN0 retained by data boundary; B unchanged by denied close | no infinite empty rounds/no fake DEFEND | D10/D15/D17 |
| M402-D03 last Enemy HP1, Party DOWN ally | production final hit before remaining slots | **DEFERRED**, terminal/close precedence undecided for M4 | Enemy0 unavailable, not DEAD; allyDOWN0; no fixture clock tick | test-only ABORT does not prove victory classification | D10/D11/D14 integration |
| M402-D04 Player DOWN; active NPC/Enemy | production automatic next round and NPC rescue Player | **BLOCKED**, scheduler and declaration/Guidance boundaries undecided | rescue isolated effect can be1ALIVE; no guarantee extra rounds/slots | existing Main still HP0→DEFEAT; no code changed | D09/D10/D15; D08/D16 for policy |
| M402-D05 Player recovered after skipped slot | actual queue resume/command-ready next boundary | **DEFERRED**, no-extra-slot runtime reason unassigned | HP1 if rescue; budget already consumed; schedule undecided | isolated effect emits no schedule request; not production proof | D09/D10/D15 + command integration |

Future proof recordต้องเก็บ per-test preconditions/exact input, before/after snapshots, expected/actual reason, no-delta ledger assertions, engine/version/commit/exact command/fresh output/logs/exits/results/source hashes. Blocked/deferredไม่ใช่ PASS; 69-stage inherited PASSไม่ใช่ผล M402 matrix. Test countsใหม่ต้องรายงานตามจริงไม่ตั้งเป้าว่าต้องเท่า matrix rowsซึ่งบางแถวมีหลาย inputs.

## 10. Owner decision register and exact approval wording

Ownerเลือกทีละข้อหรือแก้ option/ค่าก่อนอนุมัติได้. Tableนี้เป็น recommendation package **ไม่ใช่บันทึก approval**. D09/D13/D17เลือกเฉพาะ proof boundary ไม่ปิด full architecture decisionทั้งข้อ. D07/D08/D10/D11/D14/D15/D16ยัง pendingและไม่รวมในถ้อยคำนี้.

| Decision | Recommended | Scope | Approval | Exact wording proposed for owner |
|---|---|---|---|---|
| D03 | Option B — Separate RESCUE +1 HP | Isolated Party effect proof | **PENDING** | “อนุมัติ D03 Option B เฉพาะ M4-02 isolated proof: คง HELP เดิม; RESCUE helper ALIVE/PRESENT ไปยัง Party DOWN/PRESENT คนละ ID, success HP0→1/ALIVE, no DEAD/RETREATED rescue, no extra action/refund; ตรวจ target/episode ที่ lock และ impactตาม contract; ยังไม่เพิ่ม Player command หรือ NPC policy” |
| D04 | Option B — Separate1-use budget | Isolated resource proof | **PENDING** | “อนุมัติ D04 Option B: RESCUE1use/helper/encounter แยกจาก HELP, consume เฉพาะ successful impact ใน atomic commit, failed/rejected/skipped/duplicateไม่เสียuse, valid Restartสร้าง ledgerใหม่/invalid Restartไม่มีdelta; ไม่ใช้ MP/item/inventory/currency” |
| D05 | Option A — ROUND_CLOSED/Budget2/Grace | Test-only authorized fixture event proof | **PENDING** | “อนุมัติ D05 Option A เฉพาะ finite isolated fixture: single ROUND_CLOSED source,2 eligible ticks, entry-round grace, authenticated witness/event identity/semantic round dedupe/generation; ไม่มี production queue/clock completion claim; D10/D15 cases blocked/deferredตาม §8–9” |
| D06 | Option A — DOWN→DEAD at budget0 | Encounter-local Party lifecycle | **PENDING** | “อนุมัติ D06 Option A เฉพาะ isolated proof: eligible tickทำ DOWN/PRESENT→DEAD/PRESENT HP0 ที่B0ใน atomic idempotent transition; no heal/rescueจากDEAD, no unregister/save deletion/permadeath/animation/aftercare” |
| D09 | Option A — Strict Boundary | Scope-limited preservation/isolation | **PENDING** | “อนุมัติ D09 strict boundaryเฉพาะ M4-02 proof: คง R1 Option A/Request v1/eight fields/types, ไม่แตะ Pending/Frozen; reject/isolate exceptional pre-round issuer changes; no same-round re-arm; ไม่อนุมัติ full target/queue/Guidance integration” |
| D13 | Option A — No Down Evacuation | Scope-limited exclusion | **PENDING** | “อนุมัติ D13 Option Aเฉพาะ M4-02: DOWN/RETREATED invalid, no Carry/Evacuation/Retreat implementation; full evacuation designยังเปิด” |
| D17 | Option A — Defer Attack/Aftercare | Scope-limited exclusion | **PENDING** | “อนุมัติ D17 Option Aเฉพาะ M4-02: no Attack DOWN/Stabilization/auto recovery/auto deathหลังterminal/persistence/permadeath; ไม่อนุมัติ D10 terminal classifier หรือ aftercare rulesของเกมเต็ม” |

**Exact implementation gate (แยกจากการเลือก decisions):** หลัง ownerตอบเรื่องเจ็ดข้อแล้ว ต้องคำสั่งใหม่ เช่น “อนุญาต implement M4-02 isolated Atomic Effect / Clock Proof ตาม contractที่ reviewแล้ว เฉพาะ nonterminal finite fixture cases; คง blocked D10/D15และ productionทั้งหมด; เก็บ fresh evidenceและเปิด Draft PRเพื่อ review”. ข้อความตัวอย่างนี้ **ยังไม่ได้รับจาก owner**. หากอนุมัติบางข้อเท่านั้น ให้ยังไม่ implementส่วนที่ dependencyไม่ครบ; ไม่มี approvalโดย silenceหรือ mergeเอกสาร.

## 11. Recommended future implementation scope, risk and learning notes

เมื่อมี separate authorization จึง review exact new schema/API/publication plan → isolated episode/resource state → owned RESCUE transaction → finite event issuer/witness → grace/batch death → Restart/idempotency/failure injection → unchanged M4-01 + full regression → evidence/documentation/Draft review. Likely additionsจำกัด new opt-in M4-02 module/harness และ optional runner hook **ต้องมี file-level scopeใน taskใหม่**; ไม่แก้ production classes, original M4-01 proof, scenes/controller/presenter/UI/NPC decisions. ไม่เริ่ม M4-03หรือสร้าง next taskอัตโนมัติ.

Preserve production ActorRuntimeState/Registry, FullPartyEncounter, GuidedEncounter/Resolver/Layer, HELP/Guard/damage, deterministic queue/action tokens/command locking/target fallback/Restart/victory-defeat, Main Player HP0→DEFEAT, Legacy F6, `combat_speed_scale=0.70`, `SHORT_LUNGE_DISTANCE=44.0`, Compact Formation/saved homes. ไม่มี engine runหรือvisual acceptanceใหม่ใน design gate; future runtimeงานต้องใช้ actual engine/fresh outputตาม [combat guide](../tests/combat/README.md), ไม่แก้ expected constants/assertionsเพื่อ PASS. Presentationถ้าเปลี่ยนในงานอื่นต้อง F6 1280×720/owner evidenceแยก.

**Risks / deferred:** 1HPอาจ rescueแล้วล้มทันที; separate budgetsเพิ่ม survival chainแต่มี finite successful uses; graceไม่รับประกัน real rescue opportunityเมื่อ terminal/scheduler pending; episode mismatch/reused IDs/revision gatesอาจกลบเหตุผลถ้าไม่กำหนด precedence; multi-actor clockต้อง batch all-or-none; fixture issuerอาจตรวจเพียงcaller booleanหากออกแบบผิด; critical publicationห้าม callback/reentrancy; backward-compatible snapshotต้องแยก accessor; no visual/queue/NPC consent/security/permadeath claims. M402-06 fixture interleavingและ production D10/D15เป็น review risksที่ต้องไม่ซ่อนด้วย bypass/test weakening. ไม่เปลี่ยน lore, Turn System OPEN, Speed Order, Trust/personality, inventory/economy, Journey/Townหรือ Starstone/Resonance.

### Thai learning notes — วงจร v0.4

1. **Goal:** ให้ ownerทำนายได้ว่าใครช่วยได้ ใช้ทรัพยากรเมื่อใด และ clockเดินเพราะอะไร ก่อนเขียน Godot.
2. **Concept:** HP0เหมือนกันแต่ DOWNช่วยได้/DEADช่วยไม่ได้; LifeStateเป็นสิทธิ์ของ transition ไม่ใช่ชื่อที่อนุมานจากเลข HP.
3. **Do:** วาด H→T/e1ที่ lock แล้วแทรก Jช่วย/Tล้มใหม่ e2; ลองตอบว่า grantเก่ายังควรช่วยได้ไหม. Episodeเทียบเสมือนเลขครั้งที่ล้ม ไม่ใช่ IDคนใหม่.
4. **Observe:** เดิน round3 DOWN B2→close3 B2→close4 B1→close5 DEAD0; แทรก rescueก่อน seal5 แล้วเทียบกับหลัง death. ภาพเดินกลับช้าหรือเร็วไม่เปลี่ยน boundary.
5. **Explain:** Atomicเหมือนส่งใบรายการชุดเดียว: HP1/ALIVE/clock retired/use0ต้องเห็นพร้อมกัน. Scratch candidateไม่ใช่สมุด HPอีกเล่ม; ถ้า validateไม่ผ่านทิ้ง candidateทั้งหมด.
6. **Adjust:** ให้ ownerเลือก D03–D06และขอบเขต D09/D13/D17; ถ้าเปลี่ยน1HP/B2/graceให้อัปเดต expected matrixก่อน implement ไม่ปรับ testให้ผ่านตามโค้ด.
7. **Commit:** งานนี้ commitเอกสารและหยุด Draft review. Future implementationค่อยรัน proofเก็บ actual evidence; คำว่า merged/expected/recorded PASSเป็นคนละคำถาม.

## 12. Documentation validation and mandatory stop

Validationของงานนี้ตรวจ Markdown links/anchors/tables, documentation-only diff, `git diff --check`, state pairs/transition/episode/atomic event contracts, approval attribution และ milestone consistency. ตรวจ section A01–A39 และ architecture decision registerให้คงเดิม; source/scenes/tests/config/assets/evidenceต้อง byte-identicalกับ canonical. ผลจำนวน checksและคำสั่ง validationที่ทำจริงจะบันทึกใน Draft PR; ไม่ใช้ future matrixเป็นผลรัน.

**Actual documentation validation (5 พฤศจิกายน 2026):** session checker `python3 /tmp/wanderer_m402_validate.py` ตรวจ Markdown15ไฟล์ / local links342 / fragment links75 / tables101; broken links/anchors/table-width errors0. `git diff --check` exit0. Architecture A01–A39, D01–D17 register และ §11 R1/Guidance boundary byte-identicalกับ canonical; M402-01–45ครบไม่ซ้ำ และ M402-D01–D05แยก namespace, owner register7แถวเป็นPENDING. SHA-256ตรง inherited M4-01 source manifest **105/105** และ tracked non-Markdown blobs **268/268** ตรง canonical. Diffจำกัด Markdown5ไฟล์: root/index/architecture/Actor guide/current contract. นี่เป็น integrity/documentation check ไม่ใช่ผล engineใหม่. Session checkerอยู่ temporary pathไม่ใช่ test suiteใหม่ของ repository.

**Godot/import/parse/runtime/regression/F5/F6/keyboard/visual acceptance: NOT RUN** ในงาน documentation-onlyนี้. Inherited PR #46 evidenceระบุ source/engine/exact command/expected-actualข้างต้น; ไม่มี M4-02 verificationหรือใหม่ playable claim.

**Stop: M4-02 Contract Proposed / Awaiting Owner Decisions.** หลัง commit/push/open Draft PRให้รอ review. ไม่ merge/auto-merge/cleanup branches, ไม่เปลี่ยน PENDINGเป็นAPPROVED, ไม่แก้ M4-01 proof code, ไม่เริ่ม M4-02 runtime/M4-03.
