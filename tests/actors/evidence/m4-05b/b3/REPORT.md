# M4-05B B3 — Feasibility HOLD

**สถานะล่าสุดวันที่ 13 พฤศจิกายน 2026** — Owner อนุมัติเลื่อนเฉพาะ positive Last-Party RETREAT transaction proof ตาม [§30.7](../../../../../docs/M4_05_Playable_Integration_Contract.md#307-narrow-last-party-retreat-coverage-deferral--13-november-2026). HOLD เฉพาะ coverage นี้ปิดด้วยสถานะ DEFERRED. Classifier, Schema, rejection/negative replay, NPC RETREAT ปกติและ Last-Party DOWN ยังต้องทดสอบครบ ข้อความ HOLD และรอ Owner disposition ในบันทึกด้านล่างเป็นสถานะก่อนการตัดสินครั้งนี้.

**บันทึก feasibility วันที่ 12 พฤศจิกายน 2026 (Asia/Bangkok)**

ข้อแก้ไขจากคำสั่งติดตามของ Owner อยู่ใน [Contract §30](../../../../../docs/M4_05_Playable_Integration_Contract.md#30-b3-terminal-dependency-correction--proposed-for-independent-review) โดยเสนอให้ B3 รับผิดชอบ atomic terminal settlement และ causal COMPLETE พร้อมข้อกำหนด queue/replay ที่ชัดเจน สถานะข้อเสนอยังรอ Independent Contract Review และ Owner Decision. ผลรันด้านล่างเป็นหลักฐาน preflight เดิม ไม่มี Godot run เพิ่มในขั้นแก้สัญญา.

GitHub ยืนยัน canonical `visual-combat-test-1` ที่ `6bb7fddf787199fcd43f2759743c65b40670a51a` และยืนยัน merge ของ [B2 PR #62](https://github.com/shanwinder/wanderer/pull/62) ที่ `144d93bbba4f6a054b2a2189d29a01fcd5fce926` และ [Skills PR #63](https://github.com/shanwinder/wanderer/pull/63) ที่ canonical SHA ข้างต้น พบ PR เปิด #2 และ #17 ใน repository โดยไม่มี PR หรือ branch B3 ซ้ำ Local HEAD และ remote-tracking ref ตรงกับ GitHub และ checkout เดิมสะอาดก่อนเริ่ม เนื่องจาก sandbox ปฏิเสธการเขียน `.git/index.lock` ใน checkout เดิม จึงสร้าง branch `codex/m4-05b-b3-command-guidance-lifecycle` จาก SHA เดียวกันใน clone แยก Clone นี้ไม่มี `.agents/skills/` ใช้ `godot-gdscript` และ `godot-gdscript-headless-testing` ที่มีใน checkout เดิมเป็นเอกสารอ้างอิง ใช้ verifier ของโครงการโดยตรง

## ขอบเขต B3 ที่ชนกับ terminal

หลังเปิด natural close และ round preparation ตาม T05-02 A แล้ว ผู้เล่นสามารถทำให้ Enemy ตัวสุดท้าย HP0 ใน fixture V1 เดิมได้ภายในรอบ 6 ตาม [§18.2](../../../../../docs/M4_05_Playable_Integration_Contract.md#182-t05-0204-proposed-exact-lifecycle) และ [E2](../../../../../docs/M4_05_Playable_Integration_Contract.md#232-e2--weakest-eligible-party-declarations)

ใช้ `m405-demo/main` ด้วย Party HP 30/10/7/3 และ Enemy HP 15/12 ทุกครั้งเลือกคำสั่ง ATTACK ใหม่ตามรอบ ทำ Player LOCK → IMPACT → COMPLETE จริง ส่วน NPC/Enemy ที่ยังพร้อมให้ owner ออก token ตาม slot และนโยบายจริงแล้วใช้ CANCEL ก่อน IMPACT ตาม [§25.1](../../../../../docs/M4_05_Playable_Integration_Contract.md#251-request--status--reason--authority-matrix) เมื่อ Enemy A HP0 ใช้ ADVANCE เพื่อบันทึก UNAVAILABLE สำหรับ slot ของ A การ CANCEL จัดการ opportunity และไม่ออก receipt รอบ 1–5 มี Player receipt หนึ่งใบต่อรอบ พร้อมทั้งสองฝ่ายยัง active จึงเข้าเงื่อนไข close ที่สัญญาระบุ

| รอบ | คำสั่ง Player ใหม่ | Enemy HP A/B หลัง impact | ขอบเขตหลักฐาน |
|---|---|---|---|
| 1 | ATTACK A | 10/12 | รันบนฐาน B2 จริง ได้ IMPACT −5, COMPLETE และ 5 CANCEL จน DRAINED; CLOSE_ROUND ถูกปฏิเสธ INVALID_PHASE ตามขอบเขต B2 |
| 2 | ATTACK A | 5/12 | ผลที่อนุมานหลัง B3 close1 และ prepare2 |
| 3 | ATTACK A | 0/12 | Enemy B ยัง active; NPC ที่โจมตีจะเลือก Enemy ที่เหลือและถูก CANCEL ก่อน impact |
| 4 | ATTACK B | 0/7 | Enemy A ได้ UNAVAILABLE; Enemy B ยังเป็นฝ่าย active |
| 5 | ATTACK B | 0/2 | ยังมีความคืบหน้าและครบ dispositions สำหรับ close5 |
| 6 | ATTACK B | 0/0 หาก commit impact | [§7 และ SC10](../../../../../docs/M4_05_Playable_Integration_Contract.md#7-g05-03--proposed-player-down-and-terminal-migration) ต้อง freeze VICTORY และ summary ณ IMPACT, หยุด slot ที่เหลือและให้ causal token COMPLETE ครั้งเดียว ไม่มี natural close/tick รอบนี้ |

รอบ 2–6 เป็นการวิเคราะห์จากตัวเลขและกฎข้างต้น ไม่มีการสร้าง root, receipt, witness หรือ journal แทน owner. การทำซ้ำเป็นไปได้เพราะการ CANCEL ไม่เปลี่ยน HP/ทรัพยากร ส่วน natural close รักษา HP ของผู้ที่ยัง ALIVE และสร้าง prepared identity รอบใหม่ ผู้เล่นยัง ALIVE/PRESENT ตลอด จึงรับคำสั่งจริงได้ทุกครั้ง

[Rules เดิม](../../../../../scripts/m4/playable_rules.gd) ปฏิเสธ IMPACT ที่จะทำให้ outcome ออกจาก ACTIVE ด้วย `M405_INVALID_PHASE` ก่อน publication ซึ่งเป็นขอบเขตที่ระบุในซอร์ส B2 หลังเพิ่มรอบใหม่ คำขอในรอบ 6 มี phase OPEN/WAIT_ACTION, token จริง, actor และ target ยัง eligible ก่อน hit และ ATTACK5 ทำให้เกิด terminal โดยตรง [§20](../../../../../docs/M4_05_Playable_Integration_Contract.md#20-proposed-m4-05b-task--bounded-work-packages-not-authorization) จัดการบันทึกผล terminal จาก action และ causal completion ไว้ใน B4 ส่วน [§25.1](../../../../../docs/M4_05_Playable_Integration_Contract.md#251-request--status--reason--authority-matrix) ไม่มี disposition หรือผลตอบกลับเฉพาะ B3 สำหรับธุรกรรมชนขอบเขตนี้ การใช้ rejection เดิมในเส้นทาง B3 ใหม่ต้องมีคำวินิจฉัยเรื่องสัญญา เพราะผู้เล่นจะทำ ATTACK ที่ถูกต้องแต่ไม่สามารถ commit ผลตาม §7 ได้ การอ้าง SKIPPED หรือปิดรอบต่อจาก terminal จะทำให้ Effect/Clock ผิดสัญญา

**สิ่งที่ต้องตัดสินก่อนเริ่ม implementation** ให้ Independent Contract Review และ Owner ระบุว่าขอบเขต B3 ต้องปฏิเสธ terminal-causing impact แบบใด พร้อม reason, root/token invariants และทางเดินต่อจาก LOCKED หรืออนุมัติการจัดลำดับงาน terminal ขนาดที่จำเป็นในงานแยก การโจมตี Party ในหนึ่งรอบสร้าง damage รวมได้สูงสุด 8 เทียบ Enemy HP รวม 27 ใน active fixtures ฐาน B2 เปิดเพียงรอบเดียว การเพิ่ม natural rounds ทำให้เส้นทาง last-Enemy impact ข้างต้นเข้าถึงได้ การแก้ HP/fixture เพื่อหลบเส้นทางจะไม่แก้ความหมายของ transaction

## ขอบเขต Player commandless และประวัติที่ fixture รองรับ

- ใน V1 `player-down` Player เริ่ม DOWN/PRESENT, R1/B2 และ Command/Guidance ถูกล็อก ADMIT ใช้ NONE จาก owner; ADVANCE ที่ slot แรกสร้าง UNAVAILABLE พร้อม `action_id=null` โดยไม่มี token/receipt ของ Player ต่อมา NPC1 ล็อก RESCUE ต่อ episode จริงของ Player นี่คือเส้นทางที่รันบนฐาน B2 ได้จนถึง lock ฐานปฏิเสธ RESCUE IMPACT ด้วย INVALID_PHASE และ root คงเดิม
- ด้วย Player เป็น slot แรกในทุก admission, Strict Boundary A และไม่มี producer ระหว่าง ADMIT กับ ADVANCE แรก ตัวแสดงที่ unavailable ตอน admission จะยัง unavailable ที่ slot ของตน NPC RESCUE เกิดหลัง disposition จึงไม่มี slot ที่ Player กลับมา eligible แต่ยังไม่ถูก dispose ภายในรอบเดียวกัน [§18.2](../../../../../docs/M4_05_Playable_Integration_Contract.md#182-t05-0204-proposed-exact-lifecycle) อนุญาต UNAVAILABLE ในประวัติจริงนี้ หากผู้ตรวจต้องการ live proof ของ `NO_PLAYER_COMMAND` สำหรับ Player ที่ฟื้นก่อน slot จะต้องทบทวน producer/ลำดับ และคงกรณีนั้นเป็น unreachable ภายใต้สัญญาปัจจุบัน
- V2 `b2-player-low` มีธุรกรรม B2 จริงให้ Player DEFEND แล้ว DOWN จากสอง hit เมื่อ CANCEL NPC HELP ตามประวัติหนึ่ง และมีประวัติอื่นที่ HELP สองครั้งทำให้ NPC3 ล็อก RETREAT เมื่อ Enemy ประกาศตี Player ผล RESCUE และ RETREAT ยังต้องมี IMPACT/COMPLETE ของ B3 ก่อนอ้างว่าทำสำเร็จ [หลักฐาน PR #62](../b2/runtime/REPORT.md)
- เส้นทาง six-close ที่ไม่มี terminal มีอยู่ตามกฎโดยใช้ Player DEFEND จริงในแต่ละรอบเพื่อได้ Guard/receipt และ CANCEL ที่ได้รับอนุญาตสำหรับ slot อื่น ถ้าใช้ `main` ให้ศัตรูทำ NPC3 DOWN จริงในรอบแรกตาม trace B2 แล้ว CANCEL RESCUE ในรอบถัดไป จะมีเงื่อนไขสำหรับทดสอบ GRACE ที่ close1, B2→B1 ที่ close2 และ B1→B0/DEAD ที่ close3 โดย Party ที่เหลือและ Enemy ยัง active เส้นทางเหล่านี้เป็นแผน proof จนกว่า B3 จะสร้าง SEAL/COMMIT_CLOSE และตรวจ witness ได้จริง
- V1 `main` รองรับการทดสอบ FOCUS_TARGET ที่เปลี่ยนตัวเลือกของ NPC1 ภายใต้ fixed profile, ATTACK match ที่ independent baseline และ safety refusal ของ NPC3 ส่วน V1 `npc-down` มี Player ที่ส่ง Guidance ได้และ NPC slot ที่เห็น Party DOWN สำหรับ NOT_APPLICABLE ทั้งหมดเป็นแผนทดสอบ B3; trace ในงานนี้ไม่ได้ publish Pending/Frozen ที่ไม่ใช่ NONE

## การตรวจบนฐาน merged

ใช้ `/Applications/Godot.app/Contents/MacOS/Godot` รุ่น `4.7.2.stable.official.ed1daf0bf` SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf` ใน checkout และ output แยก [คำสั่งเต็ม, commit, expected/actual และ exit codes](results.json), [SHA-256 ของไฟล์ source 124 รายการ](source-sha256.json), [รายงานและ logs ฉบับเต็ม](logs-and-reports.zip), [SHA-256 ของ ZIP และรายการใน archive](archive-sha256.json)

| การตรวจ | Expected | ผลรันใหม่ |
|---|---|---|
| Canonical `6bb7fdd` import / parse | import และ 8 script parses | ผ่าน, exit 0 |
| B1 original smoke / expanded / schema / transaction | 86 / 97 / 1,846 / 354 assertions | ตรงทุกชุด, exit 0 |
| B2 focused effect | 1,010 assertions | 1,010, exit 0 |
| Feasibility prefix บน B2 | 22 รายการ, ทุก rejection คง whole root, ทุก snapshot replay เท่ากัน | 22, rejection 4 รายการ root เท่าเดิม, replay เท่ากันทั้ง 22, exit 0 |
| Historical reference `1728c5e` และ canonical `6bb7fdd` | 44 stages และ 94 stages ด้วย cutover flags ที่ตรงกับแต่ละฐาน | 44/44 และ 94/94 PASS, exit 0, expected negative errors 5 รายการต่อ run, unexpected errors และ timeouts 0 |
| Legacy | exact trace equality | 6 cases / 5,892 frames ตรงกัน |

ทั้งสอง Catalog digests ตรงกับ PR #62. แยกผลรันรอบแรกที่ macOS sandbox ขัดขวาง certificate API และ Godot editor settings ไว้ใน archive ตามอาการที่บันทึกใน [B1 Recovery-02](../b1/recovery-02/REPORT.md). ผลตารางมาจากการรันใหม่ด้วย binary เดิมนอก sandbox. Wrapper รอบใหม่ระบุ output probe ซ้ำหนึ่งส่วน ทำให้ตัวอ่านรอบแรกหา JSON ผิดตำแหน่ง ตรวจ raw report และ engine log ที่ตำแหน่งจริงแล้วบันทึกผลไว้ใน manifest.

B3 IMPACT สำหรับ RESCUE/RETREAT, natural close, clock, Pending/Frozen/R1 ใน M4Playable และ pre-publication fault ของ B3 ยังไม่ได้รันเพราะไม่มี candidate. GUI/keyboard/visual และ performance ยังไม่ได้รัน.

## สถานะส่งมอบ

ณ checkpoint preflight เดิม งานหยุดก่อน runtime, commit, push และ PR. คำสั่งติดตามให้วินิจฉัยและแก้ไขนำไปสู่ข้อเสนอ Contract §30 เพื่อส่ง Draft documentation PR บน branch เดิม. รอ Independent Contract Review และ Owner Decision ของข้อเสนอ ก่อนดำเนิน B3 runtime ต่อ.

## Owner approval follow-up — terminal feasibility

**12 November 2026.** Independent Contract Review on PR #64 at `425196f01ec95f069dae96a077e5819aeacd5862` returned TECHNICAL CONTRACT PASS. The Owner subsequently adopted the four points recorded in [§30.6](../../../../../docs/M4_05_Playable_Integration_Contract.md#306-owner-adoption-and-retained-feasibility-gate--12-november-2026). This follow-up performs source analysis and documentation checks. It adds no Godot run, runtime producer or transaction PASS.

### Last-Party RETREAT — unreachable under current rules

The proof uses the existing [Enemy declarations and slot order](../../../../../scripts/m4/playable_rules.gd), [NPC safety/RETREAT selection](../../../../../scripts/m4/playable_decision_adapter.gd), and Contract §§7, 19, 23.2–23.3 and 30.2.

1. Every ACTIVE admission has at least one eligible Party actor and one available Enemy. All available Enemies declare the same eligible Party target T. The declarations remain fixed throughout the round.
2. Party opportunities precede every Enemy opportunity. During this portion, authorized ATTACKs hit Enemies, HELP/RESCUE only improve Party HP/eligibility, DEFEND grants Guard and CANCEL consumes an opportunity without changing Party eligibility. Clocks run only at natural close. The bounded API has no external damage/removal producer. Thus T cannot become DOWN or DEAD before the Party portion ends.
3. If T is Player, Player's command choices ATTACK/DEFEND cannot make T retreat. If T is NPC and still has HP above 30%, the RETREAT predicate is false. At HP≤30%, at least one still-available Enemy's declared hit sets incoming>0, and the higher-priority safety rule selects DEFEND before RETREAT. Higher-priority RESCUE/HELP and Guidance delegation also cannot produce a RETREAT for T.
4. Every Enemy still available during the Party portion was available at admission, since the rules have no Enemy resurrection. If all declaring Enemies are eliminated, that earlier impact freezes terminal and stops later slots before a RETREAT could execute.
5. Consequently T remains eligible throughout every nonterminal Party portion. Any other NPC's RETREAT leaves T active. This remains true if another Party actor was rescued earlier in the round. Serial LOCK→IMPACT has no external actor-state mutation, so a RETREAT cannot lose its remaining eligible companion between selection and impact.

Therefore no policy-issued RETREAT token can become the last-active-Party exit in any V1/V2 fixture history under these rules, irrespective of the six-round cap. A larger fixture catalog alone with the same targeting/order/policy does not remove this invariant. Ordinary nonterminal NPC RETREAT remains reachable, as the V2 Player-low B2 lock evidence already shows.

**Disposition required under Owner point 4.** Classify positive Last-Party RETREAT runtime coverage as UNREACHABLE/HOLD. Independent Contract Review and Owner must explicitly accept its deferral while retaining the general terminal invariant, or authorize a separate producer/policy change. The approval for the Player `NO_PLAYER_COMMAND` case does not supply that waiver. Pure classifier/schema cases and a caller-created RETREAT token cannot replace the missing owned history.

### Last-Party DOWN — candidate legal history, runtime NOT RUN

V2 `m405-demo/b2-player-low` starts Party HP 2/10/7/3 and Enemy HP 15/12. In round1 submit a real Player command, admit, lock and CANCEL it. In every round lock each eligible NPC's independently selected action and CANCEL before impact. Traverse unavailable actors through real dispositions. Execute both Enemy opportunities through actual IMPACT and COMPLETE, including the legitimate second-hit TARGET_UNAVAILABLE skips. This leaves both Enemy HP values intact and provides real Enemy receipts for natural close1–5.

| Round | Admission target | Target HP at Enemy impacts | Natural-close consequence |
|---|---|---|---|
| 1 | Player | 2→0, then second hit SKIPPED | Player DOWN episode entry1 receives grace. |
| 2 | NPC3 | 3→0, then second hit SKIPPED | Player budget2→1; NPC3 entry2 receives grace. |
| 3 | NPC2 | 7→4→1 | Player budget1→0/DEAD; NPC3 budget2→1. |
| 4 | NPC2 | 1→0, then second hit SKIPPED | NPC3 budget1→0/DEAD; NPC2 entry4 receives grace. |
| 5 | NPC1 | 10→7→4 | NPC2 budget2→1. NPC1 remains the sole eligible Party actor. |
| 6 | NPC1 | 4→1→0 | Enemy B's last-Party DOWN impact must freeze DEFEAT/NO_ACTIVE_PARTY. Causal COMPLETE follows once; closed_rounds stays5 and NPC2 clock remains budget1. |

NPC actions in this derivation are selected by the owner, including HELP, RESCUE and safety DEFEND as applicable, then legitimately cancelled. No Guard is applied and no HELP/RESCUE is spent. All DOWN episodes except the final NPC1 episode receive the listed real-boundary ticks only after B3 supplies its close producer. The table is a source-backed feasibility plan. It is not an executed B3 trace, and all receipt/episode/witness IDs must be obtained from the implementation during the required proof.

## Owner coverage deferral — 13 November 2026

Owner อนุมัติเลื่อนเฉพาะการพิสูจน์ Last-Party RETREAT ด้วยธุรกรรมจริง หลัง Independent Contract Review follow-up บน `8b9228e` รับรองการวิเคราะห์จาก source. Coverage ต้องลง DEFERRED — OWNER APPROVED; ไม่บันทึก runtime PASS สำหรับกรณีนี้.

Terminal Classifier, Schema, rejection/negative replay และ ordinary NPC RETREAT ผ่าน owner LOCK/IMPACT/COMPLETE ยังคงเป็นข้อบังคับ. Last-Party DOWN ยังต้องพิสูจน์ประวัติจริงตามแผนข้างต้น. ไม่มี authorization ให้เปลี่ยน Enemy Targeting, NPC Safety Priority หรือ Fixture เพื่อสร้างสถานการณ์ที่เกิดไม่ได้ตามกฎปัจจุบัน. [Owner decision และขอบเขตเต็ม](../../../../../docs/M4_05_Playable_Integration_Contract.md#307-narrow-last-party-retreat-coverage-deferral--13-november-2026).

ขั้นบันทึกนี้แก้ Markdown เท่านั้น ไม่มี Godot/import/parse/runtime/GUI หรือ benchmark run เพิ่ม ผลรันและ audit เดิมเก็บตาม checkpoint ที่ระบุในไฟล์. B3 runtime ยังไม่ implement และ PR #64 ยังรอคำสั่ง merge โดยชัดแจ้ง.
