# M4-05B B2 — Fixture Feasibility HOLD

10 พฤศจิกายน 2026 (Asia/Bangkok). **HOLD ก่อน implementation ตาม authorization §§3/9/12/14 ของ Owner**: immutable v1 catalog ไม่มี legal producer สำหรับ B2-01 living low-HP Player HELP. งานนี้ตรวจ source/contract และเก็บ preflight เท่านั้น ไม่สร้าง HELP/Guard effect, token, receipt, fixture, test script หรือ runtime producer ใหม่ และไม่เปิด PR โดยอ้างว่า B2 PASS.

## 1. Preflight และขอบเขตหลักฐาน

| รายการ | ผลที่ตรวจจริง |
|---|---|
| Required / live / fetched / local canonical | `7898b9b0fd69068eb0798c11bd4b7cb0ebb23e77` ตรงกัน |
| PR #60 | Squash merged 10 Nov 2026 07:54:41 Asia/Bangkok; [metadata/source](https://github.com/shanwinder/wanderer/pull/60) |
| Independent B1 Review | [Review 5834090129](https://github.com/shanwinder/wanderer/pull/60#pullrequestreview-5834090129): technical review PASS, ไม่ใช่ new engine rerun หรือ B2 approval |
| Initial worktree | Clean รวม untracked; branch B1 `codex/m4-05b-b1-single-authority-proof`, HEAD `57bf127a37d159ba4968955c0252718b9c16d667`; merge-base กับ canonical `295dac9211486a4c2d3c5c5fa43baf065398e6a7` |
| Existing work | Fetch/live/local branch inventory ไม่มี B2; open PRs มีเพียง #2/#17; ไม่รวม/แก้/ลบงานเดิม |
| B2 branch / HEAD / merge-base | `codex/m4-05b-b2-help-guard-effect-bridge`; HEAD และ merge-base เป็น required canonical ข้างต้น; ไม่เริ่มจาก old B1 feature HEAD |
| New source / commit / push / PR | ไม่มี; เก็บ uncommitted docs/evidence ใน branch B2 |

[Preflight JSON](preflight.json) เก็บ live metadata, review text, remote inventory และ environment events. Restricted sandbox DNS และ `.git/index.lock` write ล้มเหลวครั้งแรก; fetch/branch creation สำเร็จด้วย authorized escalation. ไม่มี automatic approval rejection ค้างอยู่ และไม่มี destructive reset/rebase/clean/cherry-pick.

อ่าน AGENTS, root/index, actor guide, contract §§6/18.1/19–20/22–28 และ merged B1 Owner/Rules/Contract/Adapter/Catalog/Proof พร้อม Recovery-05 source/evidence attribution. [Source manifest](source-manifest.json) ผูก canonical bytes ที่ inspect; hash equality ไม่ใช่ runtime verification. [Audit](audit.json) บันทึก changed-file allowlist, link/anchor checks และ protected/source/evidence equality.

## 2. Exact contract gap และ reachability proof

**Classification: STATIC SOURCE/CONTRACT ANALYSIS. ไม่ใช่ REAL LEGAL TRANSACTION execution หรือ PURE SCHEMA test PASS.** การสรุปว่าไม่มี producer ใช้ invariant ของ catalog และ closed operation set ไม่ใช่การสร้าง snapshot ปลอมแล้วเรียก runtime proof.

| Source authority บน canonical | ข้อเท็จจริงที่ inspect |
|---|---|
| [Contract §23.1](../../../../../../docs/M4_05_Playable_Integration_Contract.md#231-e1--immutable-fixture-catalog), [Catalog](../../../../../../scripts/m4/playable_fixture_catalog.gd) lines7–22/41–55 | MaxHP Player30; main/npc-down/victory ให้ HP30; player-down/defeat ให้ HP0/DOWN. ไม่มี seed HP1–9; initial Guard=N, NPC HELP1/RESCUE1 |
| [Rules](../../../../../../scripts/m4/playable_rules.gd) lines90–98/161–185 | Weakest comparator และ declarations ที่ admission; queue Player→NPC1/2/3→EnemyA/B. GUIDANCE/CLOSE_ROUND/RESTART reject ใน B1 |
| Rules lines233–257/293–322 | B1 IMPACT publish เฉพาะ ATTACK; non-ATTACK token เป็น intention ที่ยังไม่สร้าง effect. Candidate projection ต้องตรง ATTACK และ full replay |
| [Decision adapter](../../../../../../scripts/m4/playable_decision_adapter.gd) lines69–101 | HELP ต้อง Player eligible, hp×100≤maxHP×30 และ helper HELP1; safety มาก่อน HELP |
| [Contract §23.2](../../../../../../docs/M4_05_Playable_Integration_Contract.md#232-e2--weakest-eligible-party-declarations) | Target fixed ตลอดรอบ; ไม่มี retarget หรือ external mid-action producer |

1. main/npc-down เป็น active fixtures ที่ Player ALIVE30/30; npc_03 เป็น weakest3/10. ทั้ง EnemyA/B จึงประกาศโจมตี npc_03 ไม่ใช่ Player. victory classify ที่ admission ก่อน action; อีกสอง fixture ให้ Player DOWN และ ordinary HELP ฟื้นไม่ได้.
2. NPC ทุก slot เกิดก่อน Enemy damage; pre-impact CANCEL ไม่เปลี่ยน HP. COMMAND/ADMIT/ADVANCE/LOCK/COMPLETE/reads ไม่ลด Player HP. B2 HELP เพิ่ม HP เท่านั้น และ DEFEND ให้ Guard เท่านั้น. ไม่มี Party ATTACK Player ที่ถูกต้องตาม command/policy.
3. ไม่มี legal round close เพื่อวนกลับ NPC หลัง Enemy และ RESCUE ยังเป็น B3 dependency ไม่ใช่ B2 producer. จึงไม่มี transition จาก living Player30 ไป living1–9 ก่อน NPC decision. แม้สมมติให้ Enemy สอง hit โดน Player ผิด policy ก็ลดได้มากสุด6 เหลือ24 ไม่ถึง threshold.
4. ดังนั้น HELP token จาก living low-HP Player ไม่มีทางเกิดในขอบเขต B2+v1; การเพิ่ม effect handler อย่างเดียวไม่ทำให้ B2-01 executable. Source inspection นี้ครอบคลุมเหตุผลที่การ cancel/เปลี่ยน Enemy kill order ไม่ช่วย ไม่ได้อ้าง exhaustive runtime exploration.

**Guard feasibility:** B2 สามารถเพิ่ม real Player DEFEND จาก command และ NPC3 DEFEND จาก safety policyได้ตาม authorization เมื่อ gate คลี่คลาย แต่ยังไม่ implement. main มี Enemy pressure ที่ NPC3 จึงเหมาะกับ NPC grant→first hit1/consume→second hit3/DOWN. Player Guard จะไม่ถูก hit ใน v1. NPC3 เริ่ม HP3: hit แรกที่ Guard ลดเหลือ1 ทำให้ HP2 และ consume; hitถัดไปลง DOWN ตอน Guard=N แล้ว จึงไม่ใช่ consume+DOWN ใน hitเดียว. Seed ใหม่จำเป็นสำหรับ Player same-round hits และ consume+DOWN precedence ที่ต้องการ.

## 3. State transitions และ traces ที่ยังไม่เกิด

ตารางนี้เป็น **approved semantics / expected future behavior** ไม่ใช่ผล execute ในงานนี้:

| Effect | Before → after ที่ต้อง publish atomically |
|---|---|
| HELP | Player ALIVE/PRESENT HP h→min(30,h+4), helper HELP1→0 เมื่อ delta>0; RESCUE/lifecycle/episode คงเดิม |
| DEFEND | Eligible self Guard=N→actual grant(actor,round,action,role mode), HPdelta0, HELP/RESCUE คงเดิม |
| Enemy hit / NPC Guard | Damage3→max(1,3−2)=1; NEXT_ENEMY_HIT grant→N ครั้งเดียว; Player ROUND grantคงอยู่ |
| Guarded hit causes DOWN | Damage/HP/DOWN episode/Guard cleanup publicationเดียว; one actor GuardChange, cause DOWN ชนะ CONSUME |
| SKIPPED / REJECTED / pre-impact CANCEL | ไม่มี heal/resource use/Guard grant; REJECTED ต้อง full-root equality; CANCEL เป็น actual disposition ไม่สร้าง receipt |

**Real Token→IMPACT→COMPLETE→Receipt traces สำหรับ B2: ไม่มี / NOT RUN.** ไม่ยก B1 ATTACK receipt มาแทน HELP/Guard. B1 มี actual ATTACK และ TARGET_UNAVAILABLE SKIPPED ตาม inherited evidence; non-ATTACK records/guards/resources ใน schema ไม่ใช่ effect implementation. Replay/fault/full-root proof ของ B2 ยัง NOT RUN; source manifest ไม่ปิด gate เหล่านี้.

## 4. B2-01–20 classification ณ HOLD

ทุกแถว **NOT RUN ในงานนี้**. “feasible” หมายถึง source-backed proposal หลัง approved B2 implementation ไม่ใช่ PASS. ไม่มีกรณี PURE SCHEMA/POLICY หรือ ADVERSARIAL REJECTION ใหม่ที่ execute แล้ว.

| ID | Real-transaction feasibility / dependency |
|---|---|
| B2-01 | **BLOCKED**: ไม่มี living low-HP Player seed/producer; main HP30, down HP0. Real HELP +4/use1→0 ทำไม่ได้ |
| B2-02 | BLOCKED positive spend เพราะ B2-01; หลัง seed approval จึงทดสอบ duplicate/reuse rejection ได้. Legitimate later NPC opportunity หลังใช้หมดต้อง B3; CANCEL ไม่สร้าง slotใหม่ |
| B2-03 | DOWN seed มีแต่ไม่มี legal HELP lock ใส่ DOWN. Pre-lock no-HELP และ forged-token rejection เป็นคนละ proof; DEAD/RETREATED producers deferred |
| B2-04 | **DEFERRED DEPENDENCY**: ไม่มี legal target-unavailability mutation ระหว่าง HELP lock/impact; fixture ใหม่อย่างเดียวไม่ปิด O7 gap |
| B2-05 | Feasible grant ผ่าน Player command/slot บน main หลัง B2 implementation; ปัจจุบัน non-ATTACK IMPACT reject |
| B2-06 | Feasible NPC3 safety DEFEND ใน main หลัง B2 implementation |
| B2-07 | Feasible NPC guarded reduction3→1 บน main; Player-hit variant ต้อง seedใหม่ |
| B2-08 | Feasible main: NPC3 first hit consumes, secondไม่ได้ reduction หลัง B2 implementation |
| B2-09 | **BLOCKED** qualifying Player hits ใน v1; ไม่มี persistence-across-rounds acceptance, round expiry รอ B3 |
| B2-10 | Duplicate request/IMPACT rejection feasible หลัง grant; legitimate second DEFEND slot ของ actor เดิมรอ B3; ไม่มี stacked-grant runtime PASS |
| B2-11 | main ทำ grant→consume→later DOWN ได้ แต่ same-hit CONSUME+DOWN ไม่มี seed; ต้อง reviewed addition |
| B2-12 | Positive HELP separation blocked; RESCUE effects ไม่เพิ่มใน B2. Pure enum/ledger checks ไม่ใช่ real rescue proof |
| B2-13 | Existing rejection framework รองรับ focused forged actor/target/token checks แต่ B2 testsยังไม่เขียน/ไม่รัน |
| B2-14 | Duplicate Guard IMPACT/COMPLETE feasible หลัง implementation; positive HELP variant blocked |
| B2-15 | DEFEND pre-impact CANCEL legal ใน B1 framework; HELP cancelต้อง legal HELP token ก่อน; ไม่รันใหม่ |
| B2-16 | Existing publication fault seam ใช้ได้ แต่ B2 partial-mutation proofต้อง actual effects; ไม่รัน |
| B2-17 | Existing replay/copy framework ใช้ได้ แต่ HELP/Guard full-root proofยังไม่มี; ไม่รัน |
| B2-18 | Nested Guard/Resource schema มีแล้ว; corruption checksจะเป็น PURE SCHEMA/ADVERSARIAL แยกจาก actual effect proof; ไม่รัน |
| B2-19 | **DEFERRED DEPENDENCY B3** natural close; ไม่สร้าง fake close |
| B2-20 | **DEFERRED DEPENDENCY B4** terminal/Restart cleanup; ไม่สร้าง fake terminal/reset |

**Cap limitation:** maxHP30 และ lock HP≤9 ทำให้ HELP ณ serial impactเพิ่มสูงสุดเป็น13; ไม่มี legal heal หลัง lock เพื่อให้ชน cap30. Clamp arithmetic ทดสอบแบบ PURE POLICY ได้ แต่ไม่ใช่ real capped-heal transaction. ห้ามเปลี่ยน MaxHP หรือเพิ่ม external producerเพื่อทำให้ rowดูผ่าน. Owner/Reviewer ต้องรับ classification นี้หรืออนุมัติ dependencyแยก.

## 5. Concrete proposal สำหรับ Owner และ Independent Contract Review

**Option A — แนะนำให้ review เป็น versioned addition ก่อนกลับมา B2; ยังไม่อนุมัติ/ไม่ implement.** เพิ่ม immutable v2 catalog partition สำหรับสอง fixture IDใหม่เท่านั้น; คง v1 ทั้งห้า seed/content/canonical serialized digest byte-for-byte. MaxHP/roles/order/damage/target policy/profiles/resources/Guard initial rules คงเดิม:

| Proposed ID / version | Party HP Player/NPC1/NPC2/NPC3; EnemyA/B | Expected legal producers หลัง B2 implementation |
|---|---|---|
| `m405-demo/b2-player-low` / 2 | 2/10/7/3; 15/12 | Weakest Player2/30. NPC1 HELP2→6/use1→0, NPC2 HELP6→10/use1→0. เลือก Player DEFEND และ CANCEL NPC HELP ก่อน impactเพื่อเก็บ HP2: Enemy hit1→HP1/Guardคงอยู่, hit2→HP0/DOWN/clear Guardโดยไม่ terminal เพราะ NPCยัง active |
| `m405-demo/b2-npc-guard-down` / 2 | 30/10/7/1; 15/12 | Weakest NPC3; real safety DEFEND แล้ว Enemy hitลด3→1 ทำ HP1→0/DOWN พร้อมconsume/clearใน impactเดียว; second declared hit SKIPPEDจริง |

ไม่มี initial Guard, spent-resource seed, prebuilt token/receipt หรือ hidden root import. ตัวเลขนี้เป็นการวิเคราะห์ expected history ไม่ใช่ actual trace. Main v1 ยังคงใช้พิสูจน์ NPC consume hit1 แล้ว hit2ไม่มี Guard; v2 ไม่แทนที่ reference/B1 fixtures.

**Schema/replay compatibility ต้อง review พร้อม fixture:** [Contract implementation](../../../../../../scripts/m4/playable_contract.gd) lines26/34/69 กำหนด fixture_version exact1; [original B1 proof](../../../../../../tests/actors/m4_05_playable_authority_proof.gd) lines323–326/392–395/408–425 ตรวจให้ main/version2 และ SeedReference/RestartPayload version substitution ถูก reject. การเปลี่ยน enumเป็น1-or-2อย่างเดียวจะลด strength และทำ regressionfail. Review proposal ต้องกำหนด exact ID/version pairs (oldIDs accept1 only; newIDs accept2 only), version-specific content/digests และ propagate selected versionผ่าน bootstrap/initial/seed/replay โดยไม่ทำให้ main/version2 valid. พิสูจน์ original B1 checks unchanged พร้อม new positive/cross-pair negatives. ไม่เพิ่ม wire field/reason หรือเปลี่ยน original test expectations. ถ้าทำ compatibilityนี้ไม่ได้ต้องกลับมา Owner ไม่ใช่แก้ testsให้ผ่าน.

ต้องอนุมัติ expanded allowlist ของ Catalog และ contract amendment โดยชัดเจนก่อนแก้จริง; งานนี้ไม่แตะ [canonical integration contract](../../../../../../docs/M4_05_Playable_Integration_Contract.md). Approval ของ fixtureไม่อนุมัติ B3/B4 หรือ arbitrary interleaving. Legitimate repeat-slot exhaustion/nonstacking, capped heal, post-lock target change, DEAD/RETREATED/RESCUE และ boundary cleanup ต้องคง classification/dependency ที่ตรงจริง.

**Option B — คง v1 และ HOLD B2** จนมี separately authorized/reviewed dependency task หรือ Ownerกำหนด reduced acceptanceใหม่. Grant-only หรือ pure-policy deliveryไม่ผ่าน B2-01/09 และไม่อาจเรียกว่า B2 complete. ไม่เริ่ม B3/B4 อัตโนมัติ.

## 6. Verification, manifests และ protected scope

| Check | ผล / provenance |
|---|---|
| Actual engine | `/Applications/Godot.app/Contents/MacOS/Godot --version`; exit0; `4.7.2.stable.official.ed1daf0bf` |
| Import/parse/new B2 proof/B1 suites/full combat | **NOT RUN**; mandatory HOLD ก่อน implementation. ไม่มี stdout/stderr/engine/results จาก testที่ไม่เกิด |
| Inherited B1 baseline | PR #60 tested source implementation `a07bca91ca7b01651010c8733ea3e0eee0e76b84`, delivery `57bf127a37d159ba4968955c0252718b9c16d667`, manifestsผูก pre-commit tested bytes; ไม่อ้าง rerunบน squash7898b9b |
| Inherited results ไม่ใช่ runปัจจุบัน | smoke86/86, expanded97/97, schema1846, transaction354; historical reference44/currentcanonical94/candidate94 stages; Legacy6cases/5892frames identical; five expected negative errorsแยกตาม PR60 records |
| GUI/F5/F6/manual/keyboard/visual/performance | **NOT RUN** |
| New changes | `README.md`, `docs/README.md`, `tests/actors/README.md`, new filesใต้ `tests/actors/evidence/m4-05b/b2/feasibility/` เท่านั้น |
| Protected equality | ดู [audit](audit.json): all tracked filesนอก allowlistตรง canonical; source dependenciesตรง [manifest](source-manifest.json); B1 evidenceไม่เปลี่ยน |

ไม่มี scene/controller/presenter/new UID, source/test/verifier/assertion change, Second Authority, production hook หรือ catalog mutation. F5/Legacy/M403/M404/Guidance v1/R1/project.godot/damage5-1-3/speed0.70/lunge44/Compact Formationคงเดิม. ไม่มี B2 runtime verification claim; Gate A–D ต้องรัน freshหลัง dependency resolved และ implementationจริงตาม authorization.

## 7. Independent review checklist / stop

- [ ] ยืนยัน canonical/merge/review/preflight และ source manifest ตรง checkpointนี้.
- [ ] ตรวจ invariant ว่า v1ไม่มี living low-HP HELP producer, Player targeted hit หรือ same-hit NPC consume+DOWN; แยก source proofจาก runtimeexecution.
- [ ] Review exact proposed v2 seed pairs, all-v1 digest preservation, strict pair-bound schema/replay และ unchanged B1 rejection compatibility.
- [ ] Ownerตัดสิน fixture/expanded allowlist; Independent Contract Reviewก่อน implement; proposalในรายงานนี้ไม่เป็น canonicalโดยตัวเอง.
- [ ] รับหรือแก้ remaining dependency classifications โดยไม่ fabricate O7/cap/repeat-slot/death/close/reset proof.
- [ ] เมื่ออนุมัติแล้วจึง implement B2, run actual positive/adversarial traces, full replay/fault proof และ original/full regressionด้วย fresh outputs/manifests; independent B2 reviewยัง mandatory.

**STOP: HOLD รอ Owner Direction และ Independent Contract Review.** ไม่ commit/push/open implementation PRเพราะ required B2 acceptanceยังไม่ครบ; ไม่ merge/auto-merge/delete branches/start B3–B5/M4-05C.
