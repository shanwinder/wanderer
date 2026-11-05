# Wanderer Documentation Index

เอกสารในโฟลเดอร์นี้เป็นทั้ง **บันทึกการตัดสินใจทางออกแบบ (historical design record)** และ **กฎปัจจุบัน (current guidance)** ของ Wanderer กรุณาอ่านสถานะและขอบเขตของแต่ละฉบับก่อนนำไปเขียนโค้ด

## Recommended reading order

| เอกสาร | เนื้อหา | อำนาจ/ขอบเขต |
|---|---|---|
| [AGENTS.md](../AGENTS.md) | กติกาสำหรับ Codex/agents, ขอบเขต, tests และ PR | อ่านก่อนทำงานใน repository |
| [Current status and next roadmap](#current-status-and-next-roadmap) | M3A-05 Owner-Reported PASS; M4 Architecture — Design Reviewed / Partially Owner Approved | จุดอ้างอิงสถานะปัจจุบัน; ไม่สร้างแผนฉบับซ้ำ |
| [01 — Game Development Plan v0.1](01_Wanderer_Game_Development_Plan_v0.1.md) | วิสัยทัศน์, โลก, gameplay loop, NPC autonomy, death, milestones | **ฐานเกมเดิม**; เก็บประวัติการออกแบบ |
| [02 — Visual Combat v0.2](02_Wanderer_Visual_Combat_Prototype_Update_v0.2.md) | Functional + visual prototype | ปรับ v0.1 เฉพาะงานภาพ/ต้นแบบ |
| [03 — Combat Presentation v0.3](03_Wanderer_Combat_Presentation_Direction_Update_v0.3.md) | Staging, depth, UI, M1.5B–D | เจตนา presentation และประวัติแผน; สถานะงานถัดไปในฉบับนี้ล้าสมัย |
| [04 — Learning Workflow v0.4](04_Wanderer_Learning_Development_Workflow_v0.4.md) | ผู้พัฒนาเรียนรู้ Godot ด้วยตัวเอง; AI เป็นโค้ช | **ล่าสุดสำหรับวิธีลงมือพัฒนาเสมอ** |
| **[05 — Starstone World Lore v0.5](05_Wanderer_Starstone_World_Lore_v0.5.md)** | คืนฟ้าแตก, ดาราศิลา, การพ้องพลัง, ความหายาก, สังคม, ความตาย, ความลับโลกเก่า | **ล่าสุดสำหรับ Low-Magic/Lore**; แทนความไม่ชัดใน v0.1 §5.5 |
| **[06 — Resonance Gameplay v0.5](06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)** | กฎอุปกรณ์, NPC, ต้นทุน, MRE-1, acceptance tests, roadmap integration | **ล่าสุดสำหรับ proposed magic gameplay**; ยังไม่ implement |
| [M4 — Architecture & Acceptance Design](M4_Down_Help_Death_Retreat_Architecture.md) | Down/Help/Rescue/Death/Retreat, alternatives, decisions และ future acceptance | **Design Review Completed / D01, D02, D12 Owner Approved**; runtime NOT STARTED |
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

**สถานะล่าสุด — M4 Architecture — Design Review Completed / D01, D02, D12 Owner Approved, 5 พฤศจิกายน 2026 (Asia/Bangkok).** [PR #45](https://github.com/shanwinder/wanderer/pull/45) เป็น **Architecture Design Only / Partially Owner Approved**. Owner Approval Source คือคำสั่ง “WANDERER — M4 Architecture Owner Approval & PR #45 Closure” ใน chat วันที่ข้างต้น: **D01 = APPROVED DESIGN / Option A** (Party HP0→DOWN), **D02 = APPROVED DESIGN / Option B** (แยก LifeState/Participation, 4 valid pairs, RuntimeState owns / Encounter authorizes / Registry copy isolation / snapshot-only UI), **D12 = APPROVED DESIGN / Option A** (เริ่ม isolated Data/State Proof). [Specification / approval scope / decision register](M4_Down_Help_Death_Retreat_Architecture.md) บันทึก attribution และข้อจำกัดครบ.

**D03–D11 และ D13–D17 ยัง PENDING OWNER APPROVAL.** Rescue/HP/resource, bleed-out/death timing, retreat success, NPC priority, target/Guidance extension, terminal/survivor summary, Enemy lifecycle extension, scheduler, consent/carry/Down attack/stabilization/aftercare ยังเป็น **PROPOSED RULE**. D01/D02 จำกัด first proof ไม่เพิ่ม Enemy lifecycle แต่ไม่อนุมัติ D11/D14 summary gameplay ทั้งชุด. A01–A39 = **Proposed / NOT RUN**.

**M4-01 = NOT STARTED / NOT IMPLEMENTED; M4 Runtime = NOT STARTED; ไม่มี M4 VERIFIED.** D12 อนุมัติทิศทาง/ลำดับเท่านั้น; ต้อง task specification และ implementation authorization แยกก่อนเขียนโค้ด. Existing Main/Legacy unchanged รวม Player HP0→DEFEAT, HELP≤30%/+4/once, Guidance v1/eight fields และ R1 Option A. M3A-05 ยังคง **OWNER-REPORTED ACCEPTANCE: PASS** ตาม source เดิม ไม่ใช่ agent verification ใหม่.

**PR #45 Design Review Completed:** [follow-up review 5779998593](https://github.com/shanwinder/wanderer/pull/45#pullrequestreview-5779998593) ยอมรับ corrections ที่ HEAD `a82c81f90987dd63cebc1736a1987fb1ca014abc`: D11/D14 แยก Party lifecycle rows กับ Enemy HP/availability (HP0 ไม่ใช่ DEAD), D09 แยก normal Pending→Frozen→new round identity กับ exceptional reject/isolate โดยคง R1. Review corrections ไม่อนุมัติ gameplay proposals ของ D09/D11/D14. Owner closure request อนุญาต merge/cleanup หลัง validation; ไม่ต้องขอ merge ซ้ำและไม่ enable auto-merge.

**Actual base ของ closure PR #45:** `9cb5e8dced6aa6e1719b4c86c04c23c00c46ef60` ([PR #44](https://github.com/shanwinder/wanderer/pull/44)); initial local/remote PR HEAD ตรง expected `a82c81f`, canonical/merge-base ไม่เปลี่ยนหลังเปิด PR และ working tree สะอาด. ใช้ branch/PR เดิม; open PR #2/#17 ไม่รวม/ไม่แตะ. Closure เปลี่ยน Markdown 3 ไฟล์เดิมเท่านั้นและไม่รัน Godot ใหม่. [หลักฐานเดิมและข้อจำกัด](M4_Down_Help_Death_Retreat_Architecture.md#16-risks--dependencies--verification-record) เป็น **Inherited Evidence จาก PR #43** ไม่ใช่ M4 verification. ขั้นถัดไปคือเตรียม/ทบทวน task specification M4-01; ยังไม่เริ่ม implementation.

**Historical checkpoint — M3A-05 closure ก่อน PR #44 merge:** [PR #43](https://github.com/shanwinder/wanderer/pull/43) ยืนยันจาก GitHub ว่า merged เข้า `visual-combat-test-1` ที่ [`a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34`](https://github.com/shanwinder/wanderer/commit/a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34) (5 พฤศจิกายน 2026 เวลา 05:22:55 น. Asia/Bangkok). ก่อนแก้เอกสาร working tree สะอาด; fetch สำเร็จ; local HEAD, remote-tracking HEAD, live remote HEAD (`git ls-remote`) และ merge-base ตรง SHA นี้ทั้งหมด. ไม่พบ branch/PR ปิด M3A-05 เดิม; สร้าง `codex/m3a-05-acceptance-closure` จาก canonical ล่าสุด. PR #2/#17 ยัง open/Draft/unmerged ไม่รวมเข้าฐาน. Owner รายงานว่าลบ feature branch ของ PR #43 แล้ว; ตรวจ local/remote ไม่พบ branch เดิม. Checkpoint M2A–M3A ด้านล่างเป็นประวัติ ไม่ใช่ฐานล่าสุด.

| ประเภทข้อสรุป | สถานะและขอบเขตหลักฐาน |
|---|---|
| **Implemented** | **M3A-04 — Implemented / Merged / Owner Accepted**: production [GuidedEncounter](../scripts/combat/guided_encounter.gd) ใช้ Guidance Decision Layer; Autonomous Main UI มี Guidance/Focus selectors แยก Player Command; Pending/Frozen lifecycle; NPC ตัดสินใจอิสระต่อ slot; FOLLOWED / MATCHED_INDEPENDENTLY / REFUSED พร้อมคำอธิบายไทย; locked decision แยก actual effect; revision/stale-request และ Restart/callback safety; Legacy คงอยู่. ยืนยันการมี implementation จากโค้ดที่ merge แล้ว ไม่ใช่การรันใหม่ |
| **Verified — Recorded** | หลักฐานเดิมของ PR #43 ทดสอบ source `5e54b6f5bcc5ada73cbd07c4dbdeca99256d2378`, Godot `4.7.2.stable.official.ed1daf0bf`: **64/64 stages PASS**, **34 focused Guidance Main cases / 507,851 Main checks**, zero unexpected failures/errors/timeouts, Legacy **6 cases / 5,892 frames identical**, **97/97 source hashes matching** ใน record เดิม. Checks รวม per-frame assertions ไม่ใช่ 507,851 independent cases; negative suite มีห้า expected errors แยกต่างหาก. [คำสั่งและหลักฐานเดิม](../tests/combat/README.md#verification-and-durable-evidence) |
| **Owner-Reported Accepted** | **M3A-05 — COMPLETED; Owner-Reported Acceptance: PASS** ตามคำยืนยันโดยรวมใน ChatGPT request ของเจ้าของวันที่ **5 พฤศจิกายน 2026** ซึ่งอนุญาตให้ปิดงานนี้. ไม่ใช่ Independent Verification โดย agent. **Owner-reported acceptance; per-scenario independent evidence not supplied.** [Acceptance matrix และ historical checklist](../tests/combat/README.md#m3a-05-owner-acceptance--completed) |

**ขอบเขตงานปิด M3A-05 เดิม (historical):** แก้ Markdown เท่านั้น ไม่รัน Godot/full regression, F5/F6, keyboard หรือ visual acceptance ใหม่. ผล PASS ข้างบนเป็น inherited PR #43; ไม่สร้างผลราย scenario หรือสื่อแทนเจ้าของ และไม่เปลี่ยน historical pending/failed records ให้เป็น agent verified. R1 Option A, request schema v1/eight fields และ gameplay contract ทั้งหมดคงเดิม. ณ checkpoint นั้นเสนอ [สองทางเลือก](#next-milestone-proposals--pending-owner-approval); ต่อมา PR #44 merged และเจ้าของเลือก Option A สำหรับงานออกแบบ M4 ตามสถานะล่าสุดด้านบน. ยังไม่มี implementation authorization หรือรหัส M3A-06/M3B-01 ที่อนุมัติ.

### Historical checkpoints — M2A through M3A

ตรวจจากฐาน `visual-combat-test-1` หลัง merge [PR #28](https://github.com/shanwinder/wanderer/pull/28) (`e25f16f`) และ [PR #29](https://github.com/shanwinder/wanderer/pull/29) (`2926e5c`) ณ 3 พฤศจิกายน 2026 ผู้สร้างยืนยันอนุมัติ PR #29 แล้วในงาน P0 นี้

ฐานล่าสุดสำหรับ M2D-02 คือ `08f2a973ed39449b4afaeb0dbf88bf5264b01335` หลัง merge [PR #37](https://github.com/shanwinder/wanderer/pull/37) เมื่อ **4 พฤศจิกายน 2026 เวลา 05:30 น. Asia/Bangkok**. ตรวจงานนี้วันที่ 4 พฤศจิกายน 2026: initial working tree สะอาด, fetch สำเร็จ, local/remote HEAD และ merge-base ตรงกัน; open PRs มี #2/#17 และไม่พบ M2D-02 branch/PR ซ้ำ ก่อนสร้าง `codex/m2d-02-presentation-adapter` จาก merged base. #2/#17 ยัง open/Draft/unmerged ไม่ใช่ canonical และไม่แก้ไข. Main Combat ยังคง Legacy Flow.

เจ้าของรายงานตรวจ M2C-04 เองก่อน merge: **Owner-Reported Acceptance** ตาม task นี้ ไม่ใช่ Independent Verification ราย scenario. ผล inherited บน `9271aa5` ไม่ครอบคลุม scene metadata ที่เปลี่ยนภายหลัง: manifest เดิมตรง 54/55 ไฟล์; ต่างเฉพาะ `full_party_proof.tscn` (header, Scene UID, Script UID, root unique ID). งานนี้รัน Godot 4.7.2 บน merged `08f2a973` ใหม่ก่อน extraction: **37 stages PASS**, counts ทุก suite เท่าเดิม; [baseline/final evidence](../tests/combat/README.md#m2d-02--combat-presentation-adapter-foundation). M2A-03 owner acceptance ที่รายงานก่อนหน้านี้ยังเป็น owner-reported เช่นเดิม.

เจ้าของอนุมัติ **D1–D13 สำหรับ M2C-03** โดยชัดเจนใน chat วันที่ 3 พฤศจิกายน 2026 หลังแนบงาน Multi-NPC Decision & Turn Resolution Proof. ใช้ค่าตัวเลข Prototype ตาม task: Player/NPC/Enemy ATTACK 5/1/3, HELP4, DEFEND ลด2 ขั้นต่ำ1 (Player ทุก hit ในรอบ, NPC next valid hit เท่านั้น). นี่เป็น **PROTOTYPE — Owner Approved** สำหรับ proof นี้ ไม่ใช่ Final Balance/Final Turn System. ก่อนข้อความอนุมัตินี้ D1–D13 อยู่สถานะ **PROTOTYPE — Pending Owner Approval**. M2C-01 ยังเป็น **Design Only**; ไม่ได้แนบรายงาน architecture แยก จึงใช้ contract จาก task M2C-03 และโค้ดฐานที่ merge แล้ว.

**M2C-03 merge ผ่าน PR #36 แล้ว**: NPC ตัดสินใจเมื่อถึง slot จาก state ล่าสุด, action/target/reason แยกตาม ID, full queue Player→NPC→Enemy, locked token/generation, HELP ledger และ guard รายคน. [Contract/P1–P16 และหลักฐานเดิม](../tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).

**M2C-04 merged PR #37**: isolated Full Party proof. **M2D-01 Design Completed** ตาม owner design reference. **M2D-02 Implemented / merged [PR #38](https://github.com/shanwinder/wanderer/pull/38)** ที่ `c0dcc33f0ab89c8187b9cb0c025138b447a8c7e2`; **Owner-Reported Acceptance** ตาม task M2D-03 ไม่ใช่หลักฐานตรวจภาพครบทุก scenario โดย agent.

**Historical checkpoint ณ 4 พฤศจิกายน 2026 Asia/Bangkok — M3A-02:** GitHub ยืนยัน [PR #40](https://github.com/shanwinder/wanderer/pull/40) merged เข้าสู่ `visual-combat-test-1` ที่ `1facf144887a4c6778f2ed817aa49cab3675c73d` จริง; initial tree สะอาด, local/remote-tracking HEAD, GitHub remote HEAD และ merge-base ตรงกัน. Open PRs มี #2/#17 ซึ่งยัง unmerged และไม่ใช้เป็น canonical; ไม่พบ M3A-02 ซ้ำ. ข้อความฐาน M2D-02/M2D-03 ข้างบนเป็นประวัติ ไม่ใช่ฐานล่าสุด.

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

**Historical checkpoint ณ 5 พฤศจิกายน 2026 Asia/Bangkok — M3A-03:** PR #41 merged ตาม checkpoint จริง; initial tree สะอาด, fetch สำเร็จ, local HEAD/remote HEAD/merge-base ตรง `cf5611ea71e68dcc9dbcac9a627df88f357d20c3`. Open PR #2/#17 ยัง Draft/unmerged ไม่เป็น canonical; ไม่พบ M3A-03 branch/PR ซ้ำก่อนเริ่ม. ใช้ branch เดียว `codex/m3a-03-guidance-decision-proof`. ข้อความวันที่ 4 พฤศจิกายนด้านบนเป็น historical checkpoint.

**Approval boundary:** Owner task อนุญาต M3A-03 data-only isolated proof และยืนยัน Decision Delta ใน chat นี้วันที่ 5 พฤศจิกายน: FOCUS เปลี่ยนเป้าหมายได้เมื่อ Discipline=PLAN_ORIENTED **หรือ** Trust=ESTABLISHED; discretionary DEFEND ต้องมี first valid declared self hit และ Courage=CAUTIOUS **ร่วมกับ** predicate ข้างต้น. Safety/urgent HELP มาก่อน; Compassion ยังไม่มีผลใหม่; **HELP50% ไม่อนุมัติ**. นี่เป็น approved proof predicates ไม่ใช่ final balance/full personality AI.

**M3A-03 completed / merged [PR #42](https://github.com/shanwinder/wanderer/pull/42) ที่ `2d3b1e110c3957531a3faaa402b37d963009405a`:** แยก Guidance Decision Layer, strict version1 envelope, baseline wrapper และ Guidance response metadata. Explicit proof subclass ใช้ effects/queue/token/completion ของ FullPartyEncounter เดิม; base FullPartyEncounter ใช้ resolver เดิม; ข้อความ Main unguided/no UI เป็นขอบเขตประวัติของ M3A-03 ซึ่ง M3A-04 เปลี่ยนอย่างตั้งใจ. [Executable contract / P01–P32 / บทเรียนภาษาไทย](../tests/npc/README.md#m3a-03--isolated-guidance-decision-proof). Final committed source `1ab6c73` ผ่าน60stages/30focusedcases/1,192checks, inheritedcountsคงเดิม, Legacy6cases/5,892framesตรง และ91/91sourcehashesตรง; full evidence อยู่ใน [verification record](../tests/combat/README.md#m3a-03--guidance-decision-verification).

ก่อนแก้ runtime รัน fresh PR #39 reference44stages และ merged PR #41 baseline56stages PASS ด้วย Godot `4.7.2.stable.official.ed1daf0bf`; Guidance66,641, cutover801,351/48cases, inheritedcountsครบ และ Legacy6cases/5,892framesตรงทุกframe. ไม่อ้างผลเก่าแทน baseline นี้. Sandbox reference attempt แรก FAIL เพราะ system certificate/editor settings permissions; เก็บ logs และรัน sourceเดิมด้วยสิทธิ์ปกติใน outputใหม่จนผ่านก่อน implementation.

**Historical pre-implementation checkpoint — M3A-04, 5 พฤศจิกายน 2026 Asia/Bangkok:** GitHub ยืนยัน PR #42 merged จริงที่ `2d3b1e1`; ก่อนเริ่ม clean tree, local/remote-tracking HEAD และ merge-base ตรงกัน, fetch สำเร็จ. Remote M3A-03 branch ถูกลบ; open PR #2/#17 ยัง Draft/unmerged, ไม่รวมเข้าฐาน, ไม่พบ M3A-04 branch/PR ซ้ำ. สร้าง branch เดียว `codex/m3a-04-playable-guidance-integration` จากฐานนี้.

### M3A-04 merged contract and recorded evidence

**R1 Owner Approved — Option A** ตามข้อความ owner ในงาน M3A-04 วันที่ 5 พฤศจิกายน 2026: Guidance revision เป็น Pending Content Revision ภายใน round/generation เดิม เพิ่มหนึ่งเมื่อรับ user submission (แม้เนื้อหาเหมือนเดิม) และเมื่อระบบล้าง Pending FOCUS_TARGET เพราะถอน preferred Enemy สำเร็จ. Reads, rejected requests, HP0 อย่างเดียว, ถอน actor อื่น ไม่เพิ่ม. Freeze/round reset/terminal ใช้ lifecycle identity เดิม; Restart generation ใหม่/revision0. Request schema version1/eight-field contract คงเดิม. Stale client หลัง system clear ถูก reject; frozen state ไม่ถูก roster edit เพราะ running-round lock. Option B จะเพิ่ม counter/schema ใหม่ ซึ่งไม่เลือกในงานนั้น. Closure นี้ไม่เปลี่ยน semantics. Regression และ contract ใน [NPC tests](../tests/npc/README.md#r1-option-a--current-m3a-04-contract).

**M3A-04 — Implemented / Merged / Owner Accepted (PR #43):** production GuidedEncounter สืบทอด FullPartyEncounter และใช้ Layer ที่อนุมัติใน M3A-03; proof subclass ใช้ shared implementation เดียวกัน, Main ไม่ import test-only class. Controller/UI ถือเพียง draft/visual views; Encounter/ActorRuntimeState ยังคุม HP/queue/token/Guard/HELP. Main F5 และ Autonomous F6 มี Guidance NONE/ATTACK/DEFEND/HELP/FOCUS_TARGET, Player Target แยก Focus, accepted submit ก่อน begin_round, Pending/Frozen/round/revision และ NPC response/effect ภาษาไทยแยกกัน. Direct Legacy F6 ไม่มี Guidance และคง resolver/queue เดิม. HELP ≤30%/+4/once, Compassion ไม่มี policy ใหม่, 0.70/44px/Compact Formation คงเดิม.

**Verified — Recorded จาก PR #43 (ไม่รันใหม่ใน closure นี้):** fresh PR #39 reference44 และ merged PR #42 baseline60 stages PASS ก่อน runtime edits ด้วย Godot `4.7.2.stable.official.ed1daf0bf`. Current final evidence/counts/hash และ agent GUI smoke อยู่ใน [M3A-04 verification/play guide](../tests/combat/README.md#m3a-04--playable-guidance-implemented). Headless PASS และ agent smoke ไม่ใช่ Owner Acceptance.

**ขั้นต่อไป: review Draft PR ของ M3A-05 documentation closure และเลือกข้อเสนองานถัดไปที่ยังรอ Owner Approval. M3A-05 Owner-Reported Acceptance: PASS.** คำยืนยันเจ้าของวันที่ 5 พฤศจิกายน 2026 ปิด overall acceptance โดยไม่เพิ่มหลักฐานอิสระราย scenario; historical checklist คงเดิม. Speed Order pending; Final Turn System OPEN; M2B-03 Item Implementation Deferred. ไม่ merge/auto-merge, ไม่ลบ branch หรือเริ่ม milestone ถัดไปอัตโนมัติ.

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
| M3A-03 — Guided decision | Completed / merged PR #42 (`2d3b1e1`); isolated proof and approved policy | [P01–P32/evidence](../tests/npc/README.md#m3a-03--isolated-guidance-decision-proof); no new GUI acceptance |
| M3A-04 — Playable Guidance | **Implemented / Merged / Owner Accepted**, PR #43 (`a84c8d4`); R1 Option A unchanged | **Verified — Recorded:** 64/64 stages, 34 cases / 507,851 checks; [original evidence / Thai guide](../tests/combat/README.md#m3a-04--playable-guidance-implemented); no new run |
| M3A-05 — Owner Acceptance | **COMPLETED — Owner-Reported Acceptance: PASS**, 5 November 2026 | Owner overall statement, not agent independent verification; [matrix / evidence limits](../tests/combat/README.md#m3a-05-owner-acceptance--completed) |
| M4 Architecture | **Design Review Completed / D01, D02, D12 Owner Approved**; PR #45 Design Only | [Approval source / register / A01–A39 Proposed NOT RUN](M4_Down_Help_Death_Retreat_Architecture.md); D03–D11/D13–D17 Pending |
| M4-01 / M4 Runtime | **NOT STARTED / NOT IMPLEMENTED**; D12 approved direction only | Separate task specification + implementation authorization required; Main/Legacy unchanged |

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

[Actor proof และคำอธิบายสำหรับผู้เริ่มต้น](../tests/actors/README.md) เป็น contract/test guide ไม่ใช่ roadmap คู่ขนาน. M2B-02 merge ผ่าน PR #34 แล้ว: NPCProofEncounter ถือ Actor states และรักษา snapshot/Resolver เดิม. M2C-02 merge ผ่าน PR #35 แล้ว; M2C-03 merge ผ่าน PR #36 แล้ว; M2C-04 merge ผ่าน PR #37 แล้ว; M2D-02 merge ผ่าน PR #38 แล้ว; M2D-03 merge ผ่าน PR #39 แล้ว; M2D-04 merged PR #40 แล้ว; M3A-02 merged PR #41 แล้ว; M3A-03 merged PR #42 แล้ว; M3A-04 merged PR #43 แล้ว; M3A-05 Owner-Reported Acceptance PASS ตามสถานะล่าสุดข้างต้น. M2B-03 Item/Equipment ยังคงเลื่อน implementation; งาน/merge ถัดไปยังต้องคำสั่ง owner ใหม่ ไม่ผูก final Turn System, full stats หรือระบบไอเท็มไว้ล่วงหน้า.

<a id="next-milestone-proposals--pending-owner-approval"></a>

### M4 design review and pending implementation decisions

**Roadmap facts:** merged [v0.1 §23](01_Wanderer_Game_Development_Plan_v0.1.md#23-roadmap-การพัฒนา) เรียง M2 Party/NPC AI → M3 Guidance → **M4 Down, Help, Death, Retreat** → M5 Journey → M6 Town → M7 Vertical Slice. [v0.5 §10](06_Wanderer_Resonance_Gameplay_Integration_v0.5.md#10-roadmap-แบบแทรกเฉพาะจุด-ไม่เร่ง-milestone) รักษาลำดับ M2–M7 และวาง M4.R เป็น optional หลังพื้นฐาน M2–M4; ป้าย NEXT/ยังไม่เริ่มใน snapshots เก่าไม่ใช่สถานะปัจจุบัน. ตาราง index นี้ยังบันทึก Speed Order pending และ M2B-03 implementation deferred; Guidance prototype ที่ผ่าน acceptance ไม่ได้ปิด M2/full NPC AI หรือ final Turn System ทั้งหมด. PR #2 เสนอ M3B Inventory/Equipment แต่ยัง unmerged จึงไม่ใช้เป็นลำดับที่อนุมัติ และไม่ตั้ง M3A-06/M3B-01 เป็น milestone ที่อนุมัติเอง.

**การประเมิน:** หลังรับ Guidance แล้วควรพิสูจน์ผลของการตัดสินใจอิสระต่อความอยู่รอด ก่อนขยาย personality หรือเพิ่มทั้ง Journey/Town พร้อมกัน. HELP ปัจจุบันเป็น heal ให้ actor ที่ยังมีชีวิต; HP0 เป็น unavailable ไม่ใช่ Down. จึงต้องออกแบบ state/lifecycle และ safety ก่อนให้ NPC เลือกช่วยหรือถอย. Player ยังควบคุมเฉพาะตนเอง; Guidance ต้องเป็นคำแนะนำที่ปฏิเสธและอธิบายได้. ตารางสองทางเลือกด้านล่างเก็บเหตุผลจาก PR #44; **ต่อมา owner เลือก A และอนุญาตเฉพาะ Design Only ในงานนี้แล้ว**. B ยังไม่ได้เลือก; implementation ของทั้งสองยังไม่อนุมัติ. Specification M4 ข้างต้นเป็นผลของ A ไม่ใช่ roadmap authority ชุดใหม่.

| หัวข้อ | ทางเลือก A — M4 architecture / acceptance design | ทางเลือก B — ทบทวน M2B-03 Item/Equipment contract design |
|---|---|---|
| Objective | นิยามขอบเขต proof เล็กสำหรับ Down/Help/Death/Retreat ตาม M4 ก่อนแตะ combat ที่รับรองแล้ว | ลดความไม่ชัดเรื่อง ownership ของ item/equipment ก่อนระบบทรัพยากรใน Journey/Town |
| Scope | ออกแบบ state transitions, HP0 vs Down, HELP เดิม vs proposed rescue, bleed-out timing, Player/NPC retreat choice, terminal outcome, reason/effect UX และ cancellation; แบ่ง implementation ทีละ proof เพื่อ review ภายหลัง | ตรวจ intent เดิมและเสนอ immutable definition / runtime instance / ownership / equip validation / snapshot contract ขั้นต่ำ; เปรียบเทียบผลต่อ NPC decisions โดยไม่เพิ่ม policy หรือ item effects |
| Dependencies | ฐาน PR #43 และ M3A-05 owner statement; inspect Encounter/ActorRuntimeState/Resolver/Layer/token/queue; owner ต้องตัดสิน timing เมื่อ Speed Order pending และ Turn System OPEN | M2B-01/02 actor data และ Registry ปัจจุบัน; owner ต้องกำหนด item scope, slots และผลต่อ combat; ไม่ยก roadmap PR #2 ขึ้นเป็น canonical |
| Risks | HP0/unavailable อาจขัด Down; HELP ชื่อเดียวมีสอง semantics; bleed-out/retreat อาจผูก final turn systemโดยไม่ตั้งใจ; race/terminal/restart และ internal subclass coupling | ขยายเป็น inventory/economy/durability/loot ก่อนจำเป็น; equipment modifiers อาจกระทบ deterministic decisions และ balance; ยังไม่ทดสอบ consequence ของ autonomy |
| Expected Deliverables | Reviewed transition/ownership contract, OPEN decision register, bounded proof plan, scenario acceptance matrix และบทเรียนตาม v0.4 ในเอกสารเดิมที่เกี่ยวข้อง; ไม่มี runtime deliverable | Reviewed definition/instance/ownership schema, rejected/atomic transaction cases, deferred-decision list, later proof plan และบทเรียนในเอกสารเดิม; ไม่มี item implementation |
| Acceptance Criteria | ทุก transition มี trigger/owner/precondition/result/reason; แยก heal/rescue และ token impact/completion; ครอบคลุม no resurrection/duplicate effects, NPC refusal, simultaneous danger, Restart และ victory/defeat; owner อนุมัติ OPEN ที่จำเป็นก่อน implementation; legacy regression/presentation gates คงเดิม | แยก definition/runtime/actor ownershipชัด, invalid equip/duplicate ownership/rollback/snapshot isolation มี expected outcomes; ไม่มี combat changeหรือการอนุมัติ effectโดยปริยาย; owner อนุมัติ contract และ implementation task แยก |
| Estimated complexity | **Medium** สำหรับ design; implementation ของ M4 ทั้งชุดมีความเสี่ยง **High** และต้องแยกงาน | **Medium** สำหรับ design; implementation ยังไม่ประเมินจน scope ได้รับอนุมัติ |
| Why next | สอดคล้องลำดับ merged roadmap และแกน autonomy → consequence → game loop; ลดความเสี่ยงก่อน state ใหม่ | เหมาะหาก owner ให้ความสำคัญกับ resource/data foundationก่อน M4; รองรับ game loop ภายหลัง แต่เลื่อน proofเรื่องชีวิต/ถอย |

**Selected design task — M4 Architecture: Design Review Completed / Partially Owner Approved (D01/D02/D12).** D12 อนุมัติแนวทาง **M4-01 — Isolated Data/State Proof**; ยัง **NOT STARTED** และต้อง task specification/implementation authorization แยก. [Preparation / dependencies / likely files / risks / proof boundaries / tests / deliverables / sequence](M4_Down_Help_Death_Retreat_Architecture.md#15-recommended-first-proof-และ-implementation-breakdown) อยู่ใน specification เดิม ไม่สร้าง roadmap คู่ขนาน. M4-02–05 ยัง Proposed; ไม่มี runtime branch/PR จาก closure นี้. ใช้ Goal → Concept → Do → Observe → Explain → Adjust → Commit ตาม [v0.4](04_Wanderer_Learning_Development_Workflow_v0.4.md).

**Remaining technical risks (จาก inspection/record ไม่ใช่ test failures ใหม่):** GuidedEncounter พึ่ง underscore fields ของ FullPartyEncounter; controller รวม Legacy/Guided/UI จึงมี coupling เมื่อเพิ่ม state; HP0/terminal เดิมยังไม่มี Down/retreat; Speed Order ยังไม่ทำ; fixed encounter profiles ไม่ใช่ persistent Trust/full personality AI. Long Thai debug text ยังอาศัย tooltip/log. Agent keyboard/full visual/pixel-timing review ของ PR #43 มีขอบเขตจำกัด; owner overall acceptance ปิด gateโดยคำรับรอง ไม่ได้สร้างหลักฐานราย scenario หรือยกเลิกข้อจำกัดของ record เดิม.

**Pending owner decisions:** D03–D11 และ D13–D17 ตาม register; โดยเฉพาะ Rescue/resource, clock/Death, Retreat, NPC priorities, target/queue/Guidance, terminal/survivors, Enemy extension, Player-unavailable scheduler และ consent/carry/aftercare. D01/D02/D12 เป็น APPROVED DESIGN เท่านั้น; implementation ต้องงานแยก. ไม่เปลี่ยน HELP≤30%/+4/once, Guard, deterministic queue/token safety, speed0.70/lunge44/Compact Formation หรือ Legacy. HELP50%, Compassion behavior ใหม่, speed initiative/final Turn System, M2B-03 implementation, persistent Trust, full Personality AI, permadeath และ Starstone/Resonance gameplay ยังไม่อนุมัติในงานนี้. **หยุดหลัง closure/merge/cleanup PR #45; M4-01 ยังไม่เริ่ม.**

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
