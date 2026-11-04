# Wanderer Documentation Index

เอกสารในโฟลเดอร์นี้เป็นทั้ง **บันทึกการตัดสินใจทางออกแบบ (historical design record)** และ **กฎปัจจุบัน (current guidance)** ของ Wanderer กรุณาอ่านสถานะและขอบเขตของแต่ละฉบับก่อนนำไปเขียนโค้ด

## Recommended reading order

| เอกสาร | เนื้อหา | อำนาจ/ขอบเขต |
|---|---|---|
| [AGENTS.md](../AGENTS.md) | กติกาสำหรับ Codex/agents, ขอบเขต, tests และ PR | อ่านก่อนทำงานใน repository |
| [Current status and next roadmap](#current-status-and-next-roadmap) | ฐาน merged PR #41 และ M3A-03 isolated Guidance Decision Proof | จุดอ้างอิงสถานะปัจจุบัน; ไม่สร้างแผนฉบับซ้ำ |
| [01 — Game Development Plan v0.1](01_Wanderer_Game_Development_Plan_v0.1.md) | วิสัยทัศน์, โลก, gameplay loop, NPC autonomy, death, milestones | **ฐานเกมเดิม**; เก็บประวัติการออกแบบ |
| [02 — Visual Combat v0.2](02_Wanderer_Visual_Combat_Prototype_Update_v0.2.md) | Functional + visual prototype | ปรับ v0.1 เฉพาะงานภาพ/ต้นแบบ |
| [03 — Combat Presentation v0.3](03_Wanderer_Combat_Presentation_Direction_Update_v0.3.md) | Staging, depth, UI, M1.5B–D | เจตนา presentation และประวัติแผน; สถานะงานถัดไปในฉบับนี้ล้าสมัย |
| [04 — Learning Workflow v0.4](04_Wanderer_Learning_Development_Workflow_v0.4.md) | ผู้พัฒนาเรียนรู้ Godot ด้วยตัวเอง; AI เป็นโค้ช | **ล่าสุดสำหรับวิธีลงมือพัฒนาเสมอ** |
| **[05 — Starstone World Lore v0.5](05_Wanderer_Starstone_World_Lore_v0.5.md)** | คืนฟ้าแตก, ดาราศิลา, การพ้องพลัง, ความหายาก, สังคม, ความตาย, ความลับโลกเก่า | **ล่าสุดสำหรับ Low-Magic/Lore**; แทนความไม่ชัดใน v0.1 §5.5 |
| **[06 — Resonance Gameplay v0.5](06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)** | กฎอุปกรณ์, NPC, ต้นทุน, MRE-1, acceptance tests, roadmap integration | **ล่าสุดสำหรับ proposed magic gameplay**; ยังไม่ implement |
| [Pixelorama Handoff](Wanderer_Pixelorama_Training_Handoff.md) | บันทึกทักษะวาดและ asset | อ้างอิงการเรียนรู้/ประวัติ |

### Conflict resolution (ต้องอ่าน)

ไม่ใช้หลักว่า “เอกสารเลขสูงสุดชนะทุกเรื่อง” แต่ให้แยก **domain of authority**:

1. **Learning-first development:** v0.4 ควบคุมการทำงาน/ระดับความช่วยเหลือจาก AI ทั้งหมด
2. **Combat presentation:** v0.3 เป็นเจตนาการจัดฉาก; สถานะ implementation ให้ตรวจ scene/script บนฐานที่ merge แล้ว และใช้หัวข้อ Current status ด้านล่างสำหรับ milestone ปัจจุบัน ไม่เริ่ม M1.5B ซ้ำจากข้อความเก่า
3. **Low-magic/world canon:** v0.5 [05] กำหนดกฎโลกเหนือธรรมชาติแทน v0.1 §5.5 เฉพาะหัวข้อนั้น
4. **Magic gameplay integration:** v0.5 [06] เสนอวิธีทำงานและ *จุดที่จะเพิ่มได้เมื่อพร้อม*; ไม่แก้สถานะ milestone เดิม
5. **Original game vision:** v0.1 ยังมีผลกับ Player control, NPC autonomy, post-post-apocalypse, quests, journeys, class progression, Permadeath และมิติอื่นนอกเหนือข้อแก้ชัดเจน
6. สถานะ **[LOCKED — INTENT]** ใน v0.5 หมายถึงเจตนาที่ผู้สร้างระบุ; **[DESIGN BASELINE]** เป็นข้อเสนอทำงาน, **[OPEN]** ยังไม่ตัดสิน และ **[LATER]** เก็บไว้ภายหลัง
7. **โค้ดจริงบอกสิ่งที่ Implemented; หลักฐานทดสอบบอกสิ่งที่ Verified; แผนบอกสิ่งที่ Planned** โค้ดที่มีอยู่ไม่เปลี่ยนเจตนาออกแบบหรือปิด OPEN โดยอัตโนมัติ หากไม่ตรงกันให้รายงานช่องว่างและขอ review ก่อนเปลี่ยนระบบ

หากความขัดแย้งกระทบระบบหลัก: บันทึก decision และให้ผู้สร้างทบทวนก่อนแก้ อย่าข้ามไป implement เพราะเห็นชื่อไฟล์ v0.5

## Current status and next roadmap

ตรวจจากฐาน `visual-combat-test-1` หลัง merge [PR #28](https://github.com/shanwinder/wanderer/pull/28) (`e25f16f`) และ [PR #29](https://github.com/shanwinder/wanderer/pull/29) (`2926e5c`) ณ 3 พฤศจิกายน 2026 ผู้สร้างยืนยันอนุมัติ PR #29 แล้วในงาน P0 นี้

ฐานล่าสุดสำหรับ M2D-02 คือ `08f2a973ed39449b4afaeb0dbf88bf5264b01335` หลัง merge [PR #37](https://github.com/shanwinder/wanderer/pull/37) เมื่อ **4 พฤศจิกายน 2026 เวลา 05:30 น. Asia/Bangkok**. ตรวจงานนี้วันที่ 4 พฤศจิกายน 2026: initial working tree สะอาด, fetch สำเร็จ, local/remote HEAD และ merge-base ตรงกัน; open PRs มี #2/#17 และไม่พบ M2D-02 branch/PR ซ้ำ ก่อนสร้าง `codex/m2d-02-presentation-adapter` จาก merged base. #2/#17 ยัง open/Draft/unmerged ไม่ใช่ canonical และไม่แก้ไข. Main Combat ยังคง Legacy Flow.

เจ้าของรายงานตรวจ M2C-04 เองก่อน merge: **Owner-Reported Acceptance** ตาม task นี้ ไม่ใช่ Independent Verification ราย scenario. ผล inherited บน `9271aa5` ไม่ครอบคลุม scene metadata ที่เปลี่ยนภายหลัง: manifest เดิมตรง 54/55 ไฟล์; ต่างเฉพาะ `full_party_proof.tscn` (header, Scene UID, Script UID, root unique ID). งานนี้รัน Godot 4.7.2 บน merged `08f2a973` ใหม่ก่อน extraction: **37 stages PASS**, counts ทุก suite เท่าเดิม; [baseline/final evidence](../tests/combat/README.md#m2d-02--combat-presentation-adapter-foundation). M2A-03 owner acceptance ที่รายงานก่อนหน้านี้ยังเป็น owner-reported เช่นเดิม.

เจ้าของอนุมัติ **D1–D13 สำหรับ M2C-03** โดยชัดเจนใน chat วันที่ 3 พฤศจิกายน 2026 หลังแนบงาน Multi-NPC Decision & Turn Resolution Proof. ใช้ค่าตัวเลข Prototype ตาม task: Player/NPC/Enemy ATTACK 5/1/3, HELP4, DEFEND ลด2 ขั้นต่ำ1 (Player ทุก hit ในรอบ, NPC next valid hit เท่านั้น). นี่เป็น **PROTOTYPE — Owner Approved** สำหรับ proof นี้ ไม่ใช่ Final Balance/Final Turn System. ก่อนข้อความอนุมัตินี้ D1–D13 อยู่สถานะ **PROTOTYPE — Pending Owner Approval**. M2C-01 ยังเป็น **Design Only**; ไม่ได้แนบรายงาน architecture แยก จึงใช้ contract จาก task M2C-03 และโค้ดฐานที่ merge แล้ว.

**M2C-03 merge ผ่าน PR #36 แล้ว**: NPC ตัดสินใจเมื่อถึง slot จาก state ล่าสุด, action/target/reason แยกตาม ID, full queue Player→NPC→Enemy, locked token/generation, HELP ledger และ guard รายคน. [Contract/P1–P16 และหลักฐานเดิม](../tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).

**M2C-04 merged PR #37**: isolated Full Party proof. **M2D-01 Design Completed** ตาม owner design reference. **M2D-02 Implemented / merged [PR #38](https://github.com/shanwinder/wanderer/pull/38)** ที่ `c0dcc33f0ab89c8187b9cb0c025138b447a8c7e2`; **Owner-Reported Acceptance** ตาม task M2D-03 ไม่ใช่หลักฐานตรวจภาพครบทุก scenario โดย agent.

**สถานะปัจจุบัน ณ 4 พฤศจิกายน 2026 Asia/Bangkok — M3A-02:** GitHub ยืนยัน [PR #40](https://github.com/shanwinder/wanderer/pull/40) merged เข้าสู่ `visual-combat-test-1` ที่ `1facf144887a4c6778f2ed817aa49cab3675c73d` จริง; initial tree สะอาด, local/remote-tracking HEAD, GitHub remote HEAD และ merge-base ตรงกัน. Open PRs มี #2/#17 ซึ่งยัง unmerged และไม่ใช้เป็น canonical; ไม่พบ M3A-02 ซ้ำ. ข้อความฐาน M2D-02/M2D-03 ข้างบนเป็นประวัติ ไม่ใช่ฐานล่าสุด.

**M2D-04 Implemented / Merged:** F5 default คือ `res://scenes/combat/combat_autonomous_optin.tscn`; direct F6 ของ `combat_prototype.tscn` ยังเป็น Legacy. FullPartyEncounter เป็น sole gameplay authority ของ Autonomous; Legacy HP/queue/targets แยกเหมือนเดิม. Owner task M3A-02 ระบุว่า **F5 / F6 Autonomous / F6 Legacy ทั้งสาม gate ผ่าน — Owner-Reported Acceptance**; ไม่มีผลราย scenario/engine/media เพิ่มให้ตรวจอิสระ. ไม่เปลี่ยนผล PENDING ใน historical evidence ย้อนหลัง.

**M3A-01 Design Completed:** รายงานใน chat ได้รับ Owner Approval G1–G14 โดยชัดเจนในข้อความเริ่ม M3A-02 วันที่ 4 พฤศจิกายน 2026 ยกเว้น **G6 ไม่อนุมัติ HELP 50%**; threshold เดิม ≤30% ยังใช้. Approval ของ design ไม่ใช่ approval ให้ implement ทุก milestone.

| Gate ที่อนุมัติ | ข้อตกลง |
|---|---|
| G1–G4 | ATTACK / DEFEND / HELP / FOCUS_TARGET (NONE คือ absence), team-wide, one round, submit/change เฉพาะ command-ready; freeze เมื่อ Player command สำเร็จ |
| G5 | Safety และ urgent HELP เดิมมาก่อน Guidance; first-valid-hit limitation เดิมยังอยู่ |
| G6–G8 | Fixed enums ของ Discipline/Trust/Compassion/Courage, encounter-local profiles, deterministic; self-preservation เป็น safety rule; **HELP 50% ไม่อนุมัติ** |
| G9–G11 | แยก Action/Guidance response/effect reason ในงาน proof ภายหลัง, Encounter ownership, versioned extension ที่รักษา Legacy APIs; M3A-02 ยังไม่เพิ่ม guided Resolver |
| G12–G14 | แยก Player Command/Guidance feedback และ localization ในงาน UI ภายหลัง, reset/token/callback safety, แยก M3A-02→05 เป็นงาน/PR review ทีละขั้น |

**M3A-02 Implemented / merged [PR #41](https://github.com/shanwinder/wanderer/pull/41):** `cf5611ea71e68dcc9dbcac9a627df88f357d20c3` เพิ่ม data validation, pending/frozen Guidance และ fixed profiles ผ่าน accessor แยก. Existing `snapshot()`, `decision_context()`, Resolver APIs, Player Command API และ NPC decisions คงเดิม; ไม่มี UI หรือ follow/refuse policy. [Executable contract, D01–D28 coverage, evidence และบทเรียน](../tests/npc/README.md#m3a-02--guidance-data-foundation).

ก่อนแก้ runtime รัน fresh Godot `4.7.2.stable.official.ed1daf0bf`: disposable PR #39 reference (`1728c5e`) **44 stages PASS** แล้ว merged PR #40 (`1facf144`) **52 stages PASS**, inherited counts ตรง reference, Legacy **6 cases / 5,892 frames identical**, native configured startup/rollback ผ่าน. ผล M2D-04 เดิมบน `e802e62` เป็น inherited evidence แยกจาก fresh baseline นี้. Final M3A-02 บน committed source `be08f11`: **56 stages PASS**, Guidance **66,641 checks / 26 focused cases**, รวม D27/D28 จาก full regression เป็น28acceptance cases, inherited counts ครบ, Legacy6cases/5,892framesตรงทุกframe, zero unexpectederrors/timeouts. [Durable evidence](../tests/combat/README.md#m3a-02--guidance-data-verification).

**สถานะปัจจุบัน ณ 5 พฤศจิกายน 2026 Asia/Bangkok — M3A-03:** PR #41 merged ตาม checkpoint จริง; initial tree สะอาด, fetch สำเร็จ, local HEAD/remote HEAD/merge-base ตรง `cf5611ea71e68dcc9dbcac9a627df88f357d20c3`. Open PR #2/#17 ยัง Draft/unmerged ไม่เป็น canonical; ไม่พบ M3A-03 branch/PR ซ้ำก่อนเริ่ม. ใช้ branch เดียว `codex/m3a-03-guidance-decision-proof`. ข้อความวันที่ 4 พฤศจิกายนด้านบนเป็น historical checkpoint.

**Approval boundary:** Owner task อนุญาต M3A-03 data-only isolated proof และยืนยัน Decision Delta ใน chat นี้วันที่ 5 พฤศจิกายน: FOCUS เปลี่ยนเป้าหมายได้เมื่อ Discipline=PLAN_ORIENTED **หรือ** Trust=ESTABLISHED; discretionary DEFEND ต้องมี first valid declared self hit และ Courage=CAUTIOUS **ร่วมกับ** predicate ข้างต้น. Safety/urgent HELP มาก่อน; Compassion ยังไม่มีผลใหม่; **HELP50% ไม่อนุมัติ**. นี่เป็น approved proof predicates ไม่ใช่ final balance/full personality AI.

**M3A-03 implemented on feature branch / Draft review:** แยก Guidance Decision Layer, strict version1 envelope, baseline wrapper และ Guidance response metadata. Explicit proof subclass ใช้ effects/queue/token/completion ของ FullPartyEncounter เดิม; production Encounter ใช้ resolver เดิมและ Main ไม่มี Guided Policy/UI. [Executable contract / P01–P32 / บทเรียนภาษาไทย](../tests/npc/README.md#m3a-03--isolated-guidance-decision-proof). Final committed source `1ab6c73` ผ่าน60stages/30focusedcases/1,192checks, inheritedcountsคงเดิม, Legacy6cases/5,892framesตรง และ91/91sourcehashesตรง; full evidence อยู่ใน [verification record](../tests/combat/README.md#m3a-03--guidance-decision-verification).

ก่อนแก้ runtime รัน fresh PR #39 reference44stages และ merged PR #41 baseline56stages PASS ด้วย Godot `4.7.2.stable.official.ed1daf0bf`; Guidance66,641, cutover801,351/48cases, inheritedcountsครบ และ Legacy6cases/5,892framesตรงทุกframe. ไม่อ้างผลเก่าแทน baseline นี้. Sandbox reference attempt แรก FAIL เพราะ system certificate/editor settings permissions; เก็บ logs และรัน sourceเดิมด้วยสิทธิ์ปกติใน outputใหม่จนผ่านก่อน implementation.

**ขั้นต่อไป: review M3A-03 Draft PR เท่านั้น.** M3A-04 playable/UI integration และ M3A-05 Owner acceptance **ยังไม่เริ่ม** และต้องมี task แยก. Revision note เรื่อง system invalidation หลังถอด preferred Enemy เลื่อนไปทบทวน M3A-04; semantics เดิมไม่เปลี่ยน. Speed Order ยัง pending; queue Player→NPC→Enemy เป็น approved prototype ไม่ใช่ initiative calculation; Final Turn System ยัง OPEN. **M2B-03 Item Implementation Deferred**. ไม่ merge/auto-merge หรือเริ่มงานถัดไปอัตโนมัติ.

**Implemented** = มีอยู่ในโค้ดฐานที่ merge แล้ว; **Verified** = มีผลตรวจจริงพร้อมวิธี/ขอบเขต/หลักฐาน; **Planned** = ข้อเสนอหรือเจตนา ยังไม่ใช่ฟีเจอร์ที่เสร็จ สถานะเหล่านี้ไม่ใช้แทนกัน และการ merge ไม่เท่ากับผ่าน visual acceptance ทั้งหมด

| Milestone / ขอบเขต | Implemented | Verified / ข้อจำกัด |
|---|---|---|
| M1.5B — staging | Compact allied formation, depth ผ่านตำแหน่ง Y และ contact shadows ใน scene | ตรวจโครง scene; ยังไม่มีผล F6 visual review ในบันทึก PR #29 |
| M1.5C — attack feel | Lunge, recoil, HP flash, floating damage, hit spark และ active sprite emphasis | PR #29 ทดสอบ scene/Tween จริงแบบ headless; คุณภาพภาพและความรู้สึก pacing ยังต้องตรวจด้วยตา |
| M1.5D — NPC presentation | NPC1/2/3 ลงมือทีละตัว มี intent ATK/GUARD และผลต่อ HP/Guard จริง | PR #29 ตรวจลำดับและผล damage/Guard; **ยังไม่ใช่ NPC AI/autonomy** |
| M1.5E — action presentation refinements | Short Lunge 44px, sprite attack pose, Player Defend brace และ guarded-hit feedback | ตรวจค่าจาก script; ภาพ/animation/readability ยังต้อง F6 |
| M1.6A — turn-flow foundation | แยก action queue ใน `combat_turn_flow.gd` | PR #29 ตรวจลำดับ, lock, Restart และจบรอบครั้งเดียว |
| M1.6B–C — targets / dual enemy | Enemy A/B, target picker, แยก HP, retarget ตัวที่รอด, counter เฉพาะตัวที่ยังมีชีวิต และ victory เมื่อทั้งคู่ตาย | PR #29 ตรวจ A-first/B-first และแก้คิวค้างหลังข้ามศัตรูที่ตายแล้ว |
| M2A-02 — isolated decision/effect proof (merged PR #31, `8294d24`) | Resolver และ data-only Player/NPC/Enemy fixture แยกจาก combat หลัก; เจ้าของอนุมัติ D1–D9 และ implementation ใน chat วันที่ 3 พฤศจิกายน 2026 | ผลตรวจ commit/engine/command และ raw evidence อยู่ใน [proof tests](../tests/npc/README.md); ไม่ใช่ผล autonomy ของ main scene |
| M2A-03 — playable integration / reason UX (merged PR #32, `924748c`) | ฉากแยก post-Player, six presets, action/target/reason UX, Tween และ Encounter effects เดิม; ผู้สร้างสั่ง implementation แยกวันที่ 3 พฤศจิกายน 2026 | Headless scene integration ผ่าน 5,166 checks บน `6de034d`; Combat 14,395 / negative 983 / M2A-02 412 ผ่าน รายละเอียด engine/command/evidence และ manual checklist ใน [proof tests](../tests/npc/README.md#m2a-03--playable-integration-and-reason-ux); agent F6 ใน record เดิม **NOT RUN**; ต่อมา owner รายงาน manual acceptance โดยไม่มีผลราย scenario |
| M2B-01 — shared actor data (merged PR #33, `156df77`) | Definition baseline + independent Runtime HP, validated input and detached snapshots; fixture bridge to existing Resolver only | ผลเดิมบน `33e8238`: 122 checks; รายละเอียดใน [Actor tests](../tests/actors/README.md); ตอน M2B-01 ยังไม่ integrate Encounter |
| M2B-02 — single-source actor HP (merged PR #34, `90eb7d1`) | NPCProofEncounter ถือ RuntimeState ของ player/npc/enemy_a; effects ผ่าน damage/heal, snapshots schema เดิม, atomic candidate replacement และ duplicate-ID guard | Godot 4.7.2 บน `53029a0`: focused 219, combat 14,395, negative 983 + five expected errors, M2A-02 412, M2A-03 5,166, M2B-01 122 ผ่าน; [หลักฐาน/ข้อจำกัด](../tests/actors/README.md#m2b-02--single-source-encounter-hp); F6 NOT RUN |
| M2C-01 — Full Party design | **Design Only** | D1–D13 ได้รับอนุมัติเฉพาะ M2C-03 Prototype ใน task ใหม่ ไม่ใช่ Final Gameplay |
| M2C-02 — Registry / Encounter foundation (merged PR #35, `3354274`) | **Implemented**: independent RuntimeState, roster, snapshot isolation, lifecycle guard, tombstones และ atomic Restart | ผลทดสอบปัจจุบันและ evidence ใน [Actor tests](../tests/actors/README.md#m2c-02--multi-actor-registry-and-encounter-foundation); F6 NOT RUN (data-only) |
| M2B-03 — Item/Equipment design | Implementation deferred | ไม่มี item/equipment contract ใน M2C-02 |
| M2C-03 — Multi-NPC turn proof (merged PR #36, `737e380c`) | **Implemented**: data-only full queue, decisions/effects/resources/guard/token safety; ไม่ integrate main scene | Godot `4.7.2.stable.official.ed1daf0bf` บน `0f33e1b`: focused 1,250 + legacy ทั้งเจ็ดชุดจำนวนเดิมผ่าน; [ผล/หลักฐาน](../tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof); F6 NOT RUN |
| M2C-04 — Playable Full Party (merged PR #37, `08f2a973`) | **Implemented / Merged**: separate F6 scene, eight presets, snapshot HUD, reasons, real Tween impact/completion and epoch-safe Restart | Inherited `9271aa5`:260,800 checks/31cases; owner-reported acceptance before merge. Fresh merged-base37stages PASS on `08f2a973`; metadata difference recorded; [evidence](../tests/combat/README.md#m2d-02--combat-presentation-adapter-foundation) |
| M2D-01 — Presentation migration design | **Design Completed** (owner task reference) | ไม่ใช่ approval ให้ implement migration ทั้งชุด |
| M2D-02 — Presentation Adapter Foundation | **Implemented / merged PR #38**: Player ATTACK visuals + shared NPC/Enemy attack pose; Legacy authority | Inherited `84c80d5`:40stages PASS, presentation8,319checks,5,892exact trace frames; Owner-Reported Acceptance per M2D-03 task |
| M2D-03 — Opt-in Integration | **Implemented / merged PR #39** at `1728c5e`; D1–D13, inherited scene, Encounter authority, Normal NPC10/10/10 | **Owner-Reported F6 Acceptance** per M2D-04 request; inherited `6f4c4db`:44 stages/787,617 checks. Fresh merged-base44 stages PASS in M2D-04; owner scenario evidence not independently supplied |
| M2D-04 — Cutover | **Implemented / merged PR #40** (`1facf144`); F5 Autonomous / F6 Legacy | Owner-Reported Acceptance ทั้งสาม gate ตาม M3A-02 task; fresh merged baseline52stages PASS; [historical evidence](../tests/combat/README.md#m2d-04--autonomous-main-cutover-candidate) |
| M3A-01 — Guidance architecture | Design Completed / G1–G14 approved ยกเว้น HELP50% | Design report ใน chat; ไม่ใช่ runtime verification |
| M3A-02 — Guidance data | **Implemented / merged PR #41** (`cf5611e`); state only | [Fresh verification / D01–D28](../tests/npc/README.md#m3a-02--guidance-data-foundation); ไม่มี agent GUI run ใหม่ |
| M3A-03 — Guided decision | Implemented on feature branch / Draft review; isolated opt-in type, no Main policy/UI | [P01–P32/evidence](../tests/npc/README.md#m3a-03--isolated-guidance-decision-proof); no new GUI acceptance |
| M3A-04 / 05 | Not Started | ต้องได้รับ task implementation / acceptance แยก |

แหล่งตรวจโค้ด: [scene](../scenes/combat/combat_prototype.tscn), [combat controller](../scripts/combat/combat_prototype.gd), [turn flow](../scripts/combat/combat_turn_flow.gd), [targets](../scripts/combat/combat_targets.gd)

กฎ NPC ใน **Legacy F6** เป็น deterministic: Player Attack → NPC1/3 ATK, NPC2 GUARD; Player Defend → NPC1/2/3 ATK การโจมตีตาม Target ID ที่เลือกและ fallback อัตโนมัติยังไม่พิสูจน์ว่า NPC ประเมินสถานการณ์และเลือกเอง

หลักฐาน **Verified ที่บันทึกไว้** อยู่ใน [Combat regression](../tests/combat/README.md): Godot `4.7.2.stable.official.ed1daf0bf`, clean import, parse, main-scene startup, gameplay 14,395 checks และ negative tests 983 checks (ห้า errors ที่คาดไว้) ผ่านบน fix ของ PR #29 ส่วน baseline ก่อน fix ไม่ผ่าน B-first ตามที่คาด ตัวเลขนี้เป็นผลเดิม ไม่ใช่ผลทดสอบใหม่ของงาน P0 และ **Manual F6 ยัง NOT RUN**; PR เอกสารนี้ต้องระบุผลตรวจของตนแยกต่างหาก

### M2A — NPC Autonomy Proof [M2A-02 / M2A-03 merged]

เป้าหมายคือพิสูจน์ว่า **NPC เลือกเองและผู้เล่นเข้าใจเหตุผลได้** ก่อนสร้าง Full NPC AI ไม่ถือว่าปาร์ตี้สี่คนที่มีอยู่หรือกฎ NPC2 Guard ทำให้ M2A สำเร็จแล้ว

1. หลัง review P0 และได้รับงาน M2A แยก ให้ตกลงสถานการณ์ proof ขนาด **Player 1 + NPC 1 + Enemy 1** โดยรักษา dual-enemy prototype เดิมเป็น regression baseline; วิธีจัด test fixture/scene ยังรอ review
2. เสนอ decision function เล็กที่รับ state ขั้นต่ำและคืน action, target และ reason แยกจาก Tween/UI ทดลอง Attack / Defend / Help โดย **Help เป็นพฤติกรรม proof ที่ต้องนิยามก่อน** ไม่เปิดระบบ healing, Down หรือ permadeath ทั้งชุด
3. เสนอกรณีทดสอบ: ภาวะปกติ, NPC เสี่ยง, Player ต้องการความช่วยเหลือ, ไม่มีเป้าหมายที่ใช้ได้ และสถานการณ์ที่การเลือกต่างจากกฎ NPC2 เดิม ต้องไม่มีปุ่มสั่ง NPC โดยตรง และ reason ต้องสอดคล้องกับ state จริง
4. เกณฑ์รับงานที่เสนอ: input เดิมให้ผลอธิบายซ้ำได้, เปลี่ยน state แล้วเห็นการเลือกที่มีเหตุผลต่างกัน, target ใช้ได้หรือมี fallback ปลอดภัย, ผู้สร้างลองเล่นแล้วอธิบายเหตุผล NPC ได้ และ Godot regression เดิมยังผ่านโดยไม่เปลี่ยน damage/turn flow เพื่อให้ test ผ่าน
5. หลักฐานก่อน merge M2A: decision cases พร้อม expected/actual, Godot logs และ exit codes บน commit ที่เสนอ, regression ทั้ง A-first/B-first/Restart และ F6 เพื่อประเมินความเข้าใจ intent/reason แยกจากผล headless

ข้อเสนอด้านบนเป็นบันทึกจาก P0; ต่อมาเจ้าของอนุมัติ M2A-01 D1–D9 ทั้งชุดและสั่ง M2A-02 อย่างชัดเจนใน chat วันที่ 3 พฤศจิกายน 2026: HP ต่ำ ≤30%, HELP สูงสุด 4 HP หนึ่งครั้ง/encounter, self-DEFEND ลด 2 ต่ำสุด 1, self-first เมื่อเสี่ยงพร้อมกัน, ประเมินครั้งเดียวต้น NPC slot และ SKIP อย่างปลอดภัย รายละเอียด executable contract และหลักฐานอยู่ใน [M2A-02 proof tests](../tests/npc/README.md) ซึ่งใช้ NPC max HP 10 และ enemy target ที่ประกาศ/ล็อกไว้ ไม่เพิ่ม UI/animation หรือแก้ combat หลักในงานนี้ การอนุมัตินี้เป็นกฎ **prototype** ไม่ปิด OPEN ของเกมเต็ม ไม่เพิ่ม Trust/Guidance, inventory, progression, Starstone หรือ AI เต็มระบบ ต่อมาเจ้าของสั่ง M2A-03 แยกอย่างชัดเจนวันที่ 3 พฤศจิกายน 2026; merge ผ่าน PR #32 แล้วตามตารางข้างต้น; ผล headless เดิมไม่เท่ากับผล F6 ใหม่

- Side-view combat ยังเป็นแกนหลัก; ใช้แรงบันดาลใจจาก Octopath Traveler เฉพาะ staging/focus/pacing ไม่ลอกภาพ
- Turn System ยัง [OPEN] ให้ prototype ช่วยตัดสิน
- รักษา Combat Speed **0.70**, Short Lunge **44px** และ Compact Formation; ไม่เริ่ม staging ซ้ำหรือขยาย Full NPC AI จากการปรับเอกสาร
- **ห้ามเริ่ม coding ระบบ Starstone/Resonance เพียงเพราะ merge เอกสาร v0.5**
- เมื่อ M2–M4 พื้นฐานสมบูรณ์ ค่อยประเมิน **M4.R optional** ทดสอบ Pulse Pendant **หนึ่งชิ้น** ตาม [06]; ถ้ารบกวน learning/roadmap เลื่อนไปหลัง Vertical Slice ได้

### M2B-01 — Shared Actor Data Foundation [merged PR #33]

ขอบเขตที่อนุมัติ: ข้อมูลขั้นต่ำ Actor ID/display name/role/base max HP แยกจาก current/max HP ระหว่างเล่น, damage/heal/availability และ snapshot. ใช้ `RefCounted` ไม่เพิ่ม shared Resource, singleton หรือ event bus. HP 0 เป็น unavailable ใน fixture ไม่ตัดสิน Down/Death/permadeath; ค่า stats ทั้งชุดใน v0.1 §11 ยังเป็น design intent ไม่ได้ implement ในงานนี้

[Actor proof และคำอธิบายสำหรับผู้เริ่มต้น](../tests/actors/README.md) เป็น contract/test guide ไม่ใช่ roadmap คู่ขนาน. M2B-02 merge ผ่าน PR #34 แล้ว: NPCProofEncounter ถือ Actor states และรักษา snapshot/Resolver เดิม. M2C-02 merge ผ่าน PR #35 แล้ว; M2C-03 merge ผ่าน PR #36 แล้ว; M2C-04 merge ผ่าน PR #37 แล้ว; M2D-02 merge ผ่าน PR #38 แล้ว; M2D-03 merge ผ่าน PR #39 แล้ว; M2D-04 merged PR #40 แล้ว; M3A-02 merged PR #41 แล้ว; M3A-03 เป็น isolated proof review ตามสถานะข้างต้น. M2B-03 Item/Equipment ยังคงเลื่อน implementation; M3A-03 ได้รับ implementation task โดยตรง แต่ merge ยังต้องคำสั่ง owner ใหม่ ไม่ผูก final Turn System, full stats หรือระบบไอเท็มไว้ล่วงหน้า.

### PR #2 — documentation proposal, not canonical

ตรวจ [PR #2](https://github.com/shanwinder/wanderer/pull/2) ณ 3 พฤศจิกายน 2026: **open / Draft / unmerged**, head `fac99aa` บน `docs/thailand-worldbuilding-v0-1` เสนอรวมเอกสารเป็น `docs/GAME.md`, `docs/WORLD.md`, `docs/WORKFLOW.md` และคู่มือเรียน พร้อมลบเอกสารเก่า แผนใน diff มี M2A proof ขนาด Player 1 + NPC 1 + Enemy 1 แต่ยังระบุ M1.5B เป็น NEXT ซึ่งไม่ตรงกับโค้ดฐานปัจจุบัน

ข้อเสนอการรวมเอกสารช่วยลดความซ้ำซ้อนได้ แต่ต้อง reconcile milestone และทบทวนสถานะ lore/OPEN ก่อนรับเข้า ข้อความ APPROVED/LOCKED ภายใน PR นั้นไม่ทำให้เนื้อหาทั้ง PR เป็น canonical บนฐานนี้โดยอัตโนมัติ งาน P0 ไม่ merge/cherry-pick PR #2 ไม่สร้างไฟล์ canonical ชุดคู่ขนาน และไม่เปลี่ยน world lore ใช้เอกสารที่ merge แล้วตาม authority ด้านบนต่อไปจนมี review เฉพาะเรื่อง

## Low-Magic direction v0.5

โลก Wanderer มีพลังพิเศษจริงและเป็นความรู้สาธารณะ แต่หาอุปกรณ์ใช้ได้ยาก พลังต้องมีวัสดุจากอุกกาบาตโบราณอยู่ในอาวุธ/เครื่องมือ/เครื่องประดับซึ่งผ่านการขึ้นรูปและควบคุม โดยทุกครั้งที่ใช้มีต้นทุนและความเสี่ยง

ชื่อทำงาน: **ดาราศิลา (Starstone)**, **การพ้องพลัง (Resonance)**, **คืนฟ้าแตก (The Sundering Sky)**; ชื่อและรายละเอียดเชิงกลไกส่วนมากเป็น **[DESIGN BASELINE]** และแก้ได้ตามการทดลอง

อุกกาบาตโบราณ **อาจ** มีส่วนในการล่มสลายของโลกยุคปัจจุบัน แต่เหตุแท้จริงยัง **[OPEN]** และไม่ควรเฉลยในช่วงต้นเกม

- ไม่ใช้มือเปล่าร่ายเวททั่วไป
- ไม่กลายเป็นโลกที่ทุกคนถือดาบเรืองแสง
- ไม่ให้ไอเทมปกติชุบคนตาย และไม่ลบ Permadeath
- NPC ยังตัดสินใจเองแม้ครอบครองอุปกรณ์พิเศษ
- ใช้เรื่องเล่า/ข่าวลือก่อนเพิ่มระบบใหญ่ลง prototype

## Learning-first workflow

- ผู้พัฒนาลงมือใน Godot ให้มากที่สุด; AI เป็นคู่พัฒนา/โค้ช/ผู้ตรวจงาน
- ค่าเริ่มต้น Guided Steps อธิบายแนวคิด ให้ผู้พัฒนาลงมือทีละขั้น
- ใช้วงจร Goal → Concept → Do → Observe → Explain → Adjust → Commit
- Git diff และข้อผิดพลาดเป็นส่วนหนึ่งของการเรียนรู้
- งานภาพเล็ก ๆ เพื่อเสริมแรงจูงใจทำได้ โดยไม่ขยาย asset production จนกินเวลาออกแบบระบบ

## Maintenance policy

- เก็บเอกสารเก่าไว้เพื่อย้อนดูเหตุผลการตัดสินใจ ไม่รีไรต์ประวัติให้ดูเหมือนเคยตกลง v0.5 ตั้งแต่แรก
- อัปเดตเอกสาร authority ใน domain ที่เกี่ยวข้อง และบันทึกการเปลี่ยนสถานะทุกครั้ง
- ทุกความสามารถพิเศษต้องมีผล, cost, limitation, reason codes/UX warning, tests และ release gate
- ก่อนอ้างว่า implementation เสร็จ ต้องตรวจ scene/script ที่ทำงานจริงและบันทึกการรันทดสอบ
