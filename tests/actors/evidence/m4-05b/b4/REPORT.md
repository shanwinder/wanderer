# M4-05B B4 — รายงาน implementation และ verification

**IMPLEMENTED CANDIDATE / INDEPENDENT REVIEW PENDING.** Owner มอบอำนาจให้แก้ feasibility findings และทำ B4 ต่อจนจบ ใช้ §31 โดยให้ IMPACT และ TERMINAL ออกจาก publication เดียวกันตามลำดับนี้ ส่วน causal COMPLETE ออก COMPLETION พร้อม Receipt จริงเมื่อ commit สำเร็จเท่านั้น ถ้า Restart ระหว่างสองจังหวะ เหตุการณ์ถัดไปคือ RESET ของ generation ใหม่ [Contract §31](../../../../../docs/M4_05_Playable_Integration_Contract.md#31-b4-presentation-projection-and-restart)

- Owner replay journal ที่ตรวจสอบแล้วเพื่อส่ง detached events ของ generation ปัจจุบัน RESET ต้องมี audit จาก Restart ที่ commit จริง
- Restart ใช้ owner/session เดิมและ seed จาก catalog พร้อม generation +1 และ revision 0 เก็บ root เดิมใน audit แบบ detached
- Callback adapter ผูก epoch กับ session, generation และ Token จริง คำขอที่ส่งถึง owner ยังต้องผ่าน capability และ token validation
- E5 คง SEALED และ diagnostic เดิม เมื่อออกให้ detach callback แล้ว bootstrap opt-in session ใหม่ เงื่อนไขนี้ตรวจผ่าน harness แบบ headless

## Restart regression follow-up

Tested source commit `22b070d3f7c382ab7cd4402ce91d3ce002d30222` ตรง tested SHA-256 ทั้ง189ไฟล์ [Commit resolution](restart-regression-fix/commit-resolution.json)

**PASS on Godot 4.7.2.stable.official.ed1daf0bf.** B1 smoke86 / expanded97 / schema1,907 / transaction354, B2 **1,031**, B3 **2,507 assertions /630 requests**, B4 **4,238 assertions /474 requests /28 streams** ผ่านทั้งหมด exit0 และ engine errors0. Binary SHA-256 ตรงกับ initial run และบันทึกใน results ด้านล่าง


Owner ขอให้แก้ปัญหาที่พบให้เสร็จสมบูรณ์ จึงปรับเฉพาะ expectations และลำดับทดสอบที่ผูกกับ Restart ตาม Contract §25.1/§31 ใน B2/B3 โดยเก็บผลรันและ failures ครั้งแรกไว้ในหัวข้อ Historical ด้านล่าง

B2 ตรวจ generation +1/revision0, seed จาก catalog, detached audit และ request generation เก่าที่ต้องถูกปฏิเสธ ครบทั้ง 7 fixture pairs ส่วน B3 ใช้ stale revision เพื่อทดสอบ rejection ขณะยังต้องตรวจ terminal root แล้วค่อยทดสอบ successful Restart หลังตรวจ last-Enemy, Guard cleanup และ Last-Party DOWN ครบ วิธีนี้ทำให้ frozen Outcome และ causal receipt ถูกตรวจจนจบก่อนเปลี่ยน generation

[Follow-up commands, exits and engine errors](restart-regression-fix/results.json) · [Assertion migration audit](restart-regression-fix/assertion-audit.json) · [Raw logs and reports](restart-regression-fix/logs-and-reports.zip) · [Source SHA-256](restart-regression-fix/tested-source-sha256.json)

Combat 44/94/94 และ Legacy 6 cases/5,892 frames ใช้ผลรันที่บันทึกไว้ก่อนการแก้ tests ครั้งนี้ โดยตรวจ hash ของ runtime, scenes และ dependency sources ว่าตรงเดิมทั้งหมด รอบนี้รัน focused B1/B2/B3/B4 ใหม่ ส่วน GUI/visual/performance และ Independent Review ยัง NOT RUN/PENDING ตามขอบเขตเดิม

## Historical initial candidate verification

Tested source commit `8ac140c2ca2b0a081533f2972dc79ac46ad14a69` ตรง SHA-256 ของไฟล์ที่บันทึก 189 รายการ [Git blob audit](commit-resolution.json)

| Suite | ฐาน PR #65 | B4 candidate |
|---|---:|---:|
| B1 smoke / expanded / schema / transaction | 86 / 97 / 1,907 / 354 PASS | 86 / 97 / 1,907 / 354 PASS |
| B2 effect | 1,010 PASS | exit 1, 14 assertions ต่างจากฐานเฉพาะ 7 กรณี Restart |
| B3 lifecycle | 2,486 PASS / 627 requests | exit 1, 6 failures หลัง Restart สำเร็จใน 3 terminal histories |
| B4 focused | — | 4,238 assertions / 474 requests / 28 streams PASS |
| Combat reference / canonical / candidate | 44 / 94 PASS | 94 PASS |
| Legacy | 6 cases / 5,892 frames | ตรงกันทุก frame |

B1 schema เปรียบเทียบ label multiset สดได้ 1,907 ตรงกันทั้งหมด ซึ่งสืบจาก 1,846 labels เดิมกับ 61 Decision checks ที่ B3 เพิ่มจาก data จริง [B3 schema count audit](../b3/runtime/schema-count-audit.json)

B2 เดิมถือว่าทุก APPLIED เพิ่ม revision และ journal ใน generation เดิม และคาด INVALID_PHASE สำหรับ Restart ทั้ง 7 fixture pairs จึงเกิดสอง failures ต่อ pair ใน candidate ส่วน B3 เดิมคาด REJECTED ใน terminal ที่ COMPLETE แล้ว เมื่อ Restart สำเร็จจึงมี assertions และ engine errors ต่อเนื่องจากการอ่าน terminal root เดิม (สามข้อความ รวม empty array และ Nil) เก็บ raw failures ไว้ครบและคงไฟล์ proof เดิม B4 ทดสอบพฤติกรรมใหม่โดยตรงพร้อม histories ของ last enemy, last party, RESCUE/RETREAT และ six-close clock ส่วน combat suite แยก 5 expected negative errors ต่อ run และไม่พบ unexpected errors [Commands, exits, failure labels, binary SHA-256, fixture digests](results.json) · [Logs และ transaction/event traces](logs-and-traces.zip) · [Archive SHA-256](archive-sha256.json) · [Tested source hashes](tested-source-sha256.json)

การทดลองระหว่างพัฒนาพบชื่อชน built-in `Projection` และ sandbox certificate/settings errors รอบสุดท้ายผ่านด้วย engine ตัวจริงและสิทธิ์ปกติ Wrapper รอบแรกบน Python 3.9 จบด้วย error ในขั้นเขียน manifest เพราะไม่มี `hashlib.file_digest` จึงสร้าง manifest จากผลและ logs ที่รันจบแล้วด้วย SHA-256 แบบอ่านเป็น blocks

**DEFERRED — OWNER APPROVED:** positive Last-Party RETREAT (§30.7). Ordinary RETREAT และ Last-Party DOWN ตรวจผ่าน B4 **NOT RUN:** GUI, keyboard, visual/pacing, 44px acceptance และ performance §24.1. รอ Independent Code, Contract & Evidence Review และ Owner Decision

## Historical checkpoint — feasibility HOLD

วันที่ 13 พฤศจิกายน 2026 (Asia/Bangkok). **HOLD / NOT IMPLEMENTED** ตาม mandatory contract feasibility gate ใน task ของ Owner ไม่ใช่ผลทดสอบ runtime ล้มเหลว.

## Preflight

- PR #65 ตรวจผ่าน GitHub connector: merged=true, squash SHA `9ae5df61a31083e5d55cba324f9ecd0189ca34b5`.
- `git status --short --branch`: checkout หลักสะอาดบน `visual-combat-test-1`; `git fetch origin` และ `git ls-remote --heads origin` ยืนยัน canonical SHA ตรง required. Network ครั้งแรกติด sandbox DNS; elevated retry สำเร็จ.
- ตรวจ `git worktree list`, local/remote branches และ open PRs: มีเพียง PR #2/#17 ที่ไม่เกี่ยวข้อง; ไม่พบ B4 branch/PR เดิม. ไม่ลบหรือแก้งานเดิม.
- สร้าง `codex/m4-05b-b4-events-restart` ที่ `/private/tmp/wanderer-m4-05b-b4-events-restart` จาก SHA ข้างต้น.
- หลักฐานการอ่านและการใช้ Skill ใน B4 อยู่ในหัวข้อ [Hybrid AI Skills Usage Audit](#hybrid-ai-skills-usage-audit).

## Finding B4-C01 — event protocol ยังไม่ครบ

[Contract §§25/28/30](../../../../../docs/M4_05_Playable_Integration_Contract.md) กำหนด envelope, ผลจริง และ terminal freeze แต่ไม่กำหนดว่า TERMINAL ต้องออกหลัง IMPACT ทันทีหรือรอ causal COMPLETE. ทั้งสองแบบอ่าน frozen Outcome เดียวกันได้ แต่ event stream ต่างกันเมื่อ Restart แทรกก่อน COMPLETE. จึงไม่ควรเลือกเองเป็น implementation detail.

Source evidence บน required SHA:

- `scripts/m4/playable_contract.gd`, `valid("PresentationEvent", ...)`: บังคับ identity=view.identity, Effect iff IMPACT, Receipt iff COMPLETION; ยังไม่บังคับ per-kind token หรือ event order/cardinality.
- `scripts/m4/playable_rules.gd`, `apply`: terminal freeze อยู่ที่ accepted IMPACT; COMPLETE เพิ่ม receipt และไม่มี Effect. `step` บันทึก accepted operation; ยังไม่มี event producer.
- `scripts/m4/playable_rules.gd`, `close_step`: COMMIT_CLOSE เตรียมรอบใหม่พร้อม View identity ใหม่ใน closes1–5; close6 เก็บ CLOSED/Queue. Event ต้องมี mapping ที่ไม่ปะปน closed-round identity กับ next-round View.
- `scripts/m4/playable_encounter.gd`, `transact`: owner เดิมและ capability checks ยังเป็น authority เดียว; ไม่มี B4 Restart implementation.
- `tests/actors/m4_05_playable_lifecycle_proof.gd`, terminal/failure scenarios และ [B3 runtime report](../b3/runtime/REPORT.md): causal terminal completion และ E5 มี proof เดิมแล้ว; ไม่ต้องสร้าง gameplay ใหม่เพื่อ presentation.

**ข้อเสนอพร้อม review:** [Contract §31](../../../../../docs/M4_05_Playable_Integration_Contract.md#31-b4-presentation-projection-and-restart) ระบุ producer/event matrix, IMPACT→TERMINAL ณ revision เดียว, causal COMPLETE→COMPLETION เท่านั้น, nullability, post-close identity, deterministic IDs และ Restart provenance/callback boundary. ทุกข้อเป็น PROPOSED ไม่ใช่ Owner approval. ไม่เพิ่ม protocol fields, fixtures หรือ gameplay policy.

Restart same-session G+1/revision0, nullable Queue binding และ E5 fresh-session exit มี authority เพียงพออยู่แล้ว; ไม่ถือเป็น blocker เพิ่ม. รูปแบบ private epoch และ ID spelling เป็น technical details. HOLD เกิดจาก observable event semantics และความสัมพันธ์ payload ที่ต้อง review.

## Verification และข้อจำกัด

ตรวจ source/contract เท่านั้น; ไม่ได้รัน Godot version/import/parse/runtime หรือ B4 focused/B1/B2/B3/combat/Legacy suites. Performance, GUI, keyboard, animation, 44px lunge และ visual acceptance **NOT RUN**. ไม่มี binary SHA ใหม่หรือ runtime PASS ในงานนี้.

Inherited B3 evidence จาก PR #65: tested source `858a7a8bb02dd170bd8bae32adc1a38fa310b455`, Godot `4.7.2.stable.official.ed1daf0bf`, B3 2,486 checks /627 requests, B2 1,010, B1 schema1,907 (original1,846 +61), regressions44/94/94 และ Legacy6cases/5,892frames. ตัวเลขเหล่านี้มาจาก report เดิม ไม่ใช่การรันใหม่หรือ independent rerun. Positive Last-Party RETREAT ยังคง DEFERRED — OWNER APPROVED ตาม §30.7.

งานที่เปลี่ยนมีเพียงเอกสารสถานะสามไฟล์, proposed amendment ใน contract เดิม และ report นี้. Runtime/scenes/project.godot/fixtures/original tests/evidence ไม่เปลี่ยน. ยังไม่ commit/push หรือเปิด implementation Draft PR เพราะ mandatory gate ไม่ผ่าน. หยุดรอ Independent Contract Review และ Owner decision; ไม่ merge/auto-merge หรือเริ่ม B5/M4-05C.

### Documentation audit

`git diff --check` ผ่าน; merge-base ตรง required SHA. ตรวจ local link targets 348 รายการ: ไม่มีไฟล์ปลายทางหาย. Lightweight anchor checker แจ้งสาม anchor เดิมใน docs index ให้ตรวจด้วยมือ (ไม่ใช่ลิงก์ใหม่); ลิงก์ใหม่ของ §31 และ B4 report resolve ได้. เปรียบเทียบ tracked files ใน scripts/scenes/tests/project.godot กับ HEAD จำนวน953ไฟล์ (ยกเว้น Actor Test Guide ที่อนุญาตให้แก้): ไม่พบความต่าง รวม original proof/evidence. ผลนี้เป็น static preservation check ไม่ใช่ runtime verification.

## Hybrid AI Skills Usage Audit

ตรวจที่ feasibility checkpoint วันที่ 13 พฤศจิกายน 2026 (Asia/Bangkok) บน `codex/m4-05b-b4-events-restart` จากฐาน PR #65 ที่ `9ae5df61a31083e5d55cba324f9ecd0189ca34b5` สถานะ **HOLD** ตาม gate เดิม เพราะลำดับ TERMINAL เทียบกับ IMPACT/COMPLETE ยังรอ Independent Contract Review และ Owner decision ตาม [ข้อเสนอ §31](../../../../../docs/M4_05_Playable_Integration_Contract.md#31-b4-presentation-projection-and-restart)

**Discovery.** Transcript บรรทัด 5 แสดงทั้งสี่ Skill ในรายการ Available Skills ของ B4 session โดยชี้ไปยังไฟล์ใน checkout หลักตามตาราง และบรรทัด 1/10 ระบุ CWD `/Applications/wanderer` การตรวจ filesystem ณ checkpoint พบไฟล์ต้นทางทั้งสี่เป็น **Available** ส่วน `/private/tmp/wanderer-m4-05b-b4-events-restart/.agents/skills/` เป็น **Missing** รวมถึง `<skill>/SKILL.md` ของทั้งสี่รายการใน worktree นั้น Codex เปิดอ่านสองไฟล์จาก checkout หลักผ่าน shell เพื่อใช้อ้างอิงในงาน B4

**หลักฐานต้นทาง.** Session `01a1d38a-0c42-7512-a79d-136ea14c9afd` อยู่ที่ `/Users/depa/.codex/sessions/2026/11/13/rollout-2026-11-13T13-13-22-01a1d38a-0c42-7512-a79d-136ea14c9afd.jsonl` หมายเลขด้านล่างคือบรรทัด JSONL จริงบนเครื่องนี้ Call ID ของการอ่านทั้งสองไฟล์คือ `call_13d67530c2e341f7861e3577b433f67f` ผล shell ออก 0 และบันทึกมีเนื้อหาของทั้งสองไฟล์ แม้ output รวมถูกตัดบางช่วง

| Skill | Source Path | Invocation Evidence | Applied Behavior | Verification | Status |
|---|---|---|---|---|---|
| `godot-gdscript` | `/Applications/wanderer/.agents/skills/godot-gdscript/SKILL.md` (Available) | `functions.exec` → `tools.exec_command` รัน `cat .agents/skills/godot-gdscript/SKILL.md` ใน checkout หลัก บรรทัด 23/26 ยืนยันคำสั่งและผลลัพธ์ที่มีเนื้อหา Skill | ตรวจ typed event/owner boundary สำหรับ B4-C01 โดยอ่าน signature `Variant`/`Dictionary` ใน `scripts/m4/playable_encounter.gd` และ validator ใน `scripts/m4/playable_contract.gd` สอดคล้องกับ Workflow ข้อ 2 และหัวข้อ Variant | บรรทัด 31 ระบุการใช้ Skill กับ typed event/owner boundary และ 54/58, 72/77 แสดงการอ่าน owner และ validator จริง เทียบกับ finding B4-C01 และข้อเสนอ §31 ตรวจได้จากซอร์ส ไม่มี compile check ใหม่ | `READ AS REFERENCE / APPLIED` |
| `godot-gdscript-headless-testing` | `/Applications/wanderer/.agents/skills/godot-gdscript-headless-testing/SKILL.md` (Available) | `functions.exec` → `tools.exec_command` รัน `cat .agents/skills/godot-gdscript-headless-testing/SKILL.md` ใน call เดียวกัน บรรทัด 23/26 ยืนยันคำสั่งและผลลัพธ์ที่มีเนื้อหา Skill | ประเมิน coverage ของ causal completion และ E5 จาก proof เดิม `tests/actors/m4_05_playable_lifecycle_proof.gd` ตัว runner ที่ตรวจมี `SceneTree`, การนับ failure และ exit status ตาม Workflow ข้อ 3–4 | บรรทัด 31 ระบุการใช้ Skill กับ proof coverage, 89/92 แสดงการอ่าน runner ที่เก็บ checks และเรียก `quit(int(failures > 0))`, 72/77 แสดงการอ่านผล B3 ตรวจย้อนได้จาก [B3 report และ run records](../b3/runtime/REPORT.md) B4 headless **NOT RUN** | `READ AS REFERENCE / APPLIED` |
| `godot-nodes-scenes` | `/Applications/wanderer/.agents/skills/godot-nodes-scenes/SKILL.md` (Available) | ไม่พบการเปิดอ่านหรือ invoke ใน B4 session | Checkpoint ตรวจ owner, schema และ proof เดิม โดยไม่มีงาน scene tree, scene loading หรือ path/UID repair | ตรวจรายการ tool calls จนถึง `task_complete` บรรทัด 129 และ scope ที่ checkpoint | `NOT USED` |
| `router` | `/Applications/wanderer/.agents/skills/router/SKILL.md` (Available) | ไม่พบการเปิดอ่านหรือ invoke ใน B4 session | Engine และหัวข้อ technical review ระบุชัดใน B4 จึงเลือก reference ได้โดยตรง | ตรวจรายการ tool calls จนถึง `task_complete` บรรทัด 129 | `NOT USED` |

สถานะ `APPLIED` สองรายการจำกัดที่ static feasibility review ตามคำอธิบายของ Agent ในบรรทัด 31 ประกอบกับคำสั่งอ่านซอร์สและ proof ที่ตามมา การอ้างหัวข้อ Workflow เป็นการจับคู่เนื้อหา Skill กับงานที่เห็นใน transcript ไม่มีหลักฐานการ invoke ผ่านระบบ Skill การเขียน B4 runtime หรือการรัน helper ของ Skill ใน checkpoint นี้ ไม่มีการติดตั้ง Skill เปลี่ยนแผนทดสอบ หรือรัน Godot ใหม่ในการทำ Audit
