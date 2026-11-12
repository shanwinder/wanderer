# M4-05B B3 — Feasibility HOLD

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
