# M4-05B B2 — หลักฐาน HELP และ Guard จากธุรกรรมจริง

**12 พฤศจิกายน 2026 (Asia/Bangkok) · Candidate ผ่าน automated gates · รอ Independent Code, Contract & Evidence Review**

## ฐานและขอบเขต

[PR #60](https://github.com/shanwinder/wanderer/pull/60) merge ที่ `7898b9b0fd69068eb0798c11bd4b7cb0ebb23e77` และ [PR #61](https://github.com/shanwinder/wanderer/pull/61) squash merge ที่ `6b68bf563833fb31fbb8df4b15034f3fd26f60da` หลัง [Independent Contract Review](https://github.com/shanwinder/wanderer/pull/61#pullrequestreview-5865853792). Local fetched ref และ live `visual-combat-test-1` ตรงกับ SHA หลัง squash. ตอน preflight มี open PR #2/#17 และไม่มี implementation branch/PR ซ้ำ

Branch `codex/m4-05b-b2-runtime-help-guard` แยก worktree จาก canonical SHA เดียวกับ merge-base. Branch เอกสารเดิมอยู่ที่ `2c579289b3afa175d0e617efa9f86f3cc35e1895` และมี tree ตรงกับ squash commit. Working tree เดิมสะอาด จึงไม่มี uncommitted/untracked source ที่ต้องย้าย. ตรวจไฟล์ protected 982 รายการ รวมหลักฐานเดิม 796 รายการ. การเปลี่ยนแปลงอยู่ที่ Catalog/Contract/Rules/Encounter, Effect Rules ใหม่, B2 proof และ UID สองไฟล์, เอกสารสามไฟล์ และหลักฐานชุดนี้. Adapter เดิม, B1 harness, M403/M404, Guidance v1/R1, combat verifier, project, Main F5 และ Legacy F6 ตรงกับ canonical. [Changed-file audit](scope-audit.json)

## Fixture และการผูก schema

| Partition | Contract revision | Canonical catalog SHA-256 |
|---|---:|---|
| V1 เดิม 5 fixtures | 2 | `09f773cd96f7bb61bfd42226f1324b863a3eec484a684b88e85709bf5afeb28c` |
| V2 ใหม่ 2 fixtures | 3 | `f797cf7d11e20a0070eec3de7f2bb776e70ff36c1b95afed6192079703e7077e` |

ค่า V1 เท่ากับ digest ในรายงาน B1 เดิมและคำนวณจาก serialization ของทั้ง partition. V2 เลือก `m405-demo/b2-player-low` (Party HP 2/10/7/3) หรือ `m405-demo/b2-npc-guard-down` (30/10/7/1). Enemy HP 15/12, roster, profiles, capacity, damage5/1/3 และ weakest-target policy ตรงกับ B1. Fixture V2 เริ่มโดยไม่มี episode, Guard, spent ledger, token, effect, receipt หรือ journal. [B1 original digest provenance](../../b1/recovery-05/ABC/C-original-expanded-report.json)

Bootstrap และ RestartPayload ตรวจ exact ID/strict int version. ID เดิมกับ V2, ID ใหม่กับ V1, unknown/V2 และ version ที่ผิดชนิดหรือไม่รองรับได้ INVALID_SCHEMA. Unknown/V1 คง factory UNKNOWN_FIXTURE. SeedReference ผูก contract revision กับ ID/version; root validation และ replay ตรวจ canonical seed และ digest ของ partition ที่เลือก. Replay ปฏิเสธ digest สลับ partition และ unknown seed. V2 RestartPayload ผ่าน schema และถูกปฏิเสธที่ phase ตามขอบเขต B2

## ธุรกรรมที่เกิดขึ้นจริง

หลักฐานมี 25 IMPACT (24 APPLIED, 1 SKIPPED), 25 COMPLETE receipts และ 5 pre-impact CANCEL จากห้า scenario. Action ID ด้านล่างเป็นลำดับภายในแต่ละ session. แต่ละรายการมี token identity, authorization ID, slot, signed delta, journal digest และ receipt ซึ่งผูกกับ impact/completion revision จริง. [Token → Effect → Receipt traces](transaction-traces.json)

| Scenario | Action ID และผลที่สังเกต |
|---|---|
| HELP จริงสอง NPC | #2 NPC1 HELP ทำ Player HP 2→6 และ HELP 1→0. #3 NPC2 เลือก HELP ใน slot ของตน ทำ HP 6→10 และ HELP 1→0. แต่ละครั้งมี +4, RESCUE คง 1, episode คง null และมี receipt หนึ่งใบ |
| Player Guard คงอยู่สอง hit | #1 Player DEFEND ให้ ROUND Guard, HP delta 0. หลัง HELP สองครั้ง #5/#6 Enemy ATTACK ทำ HP 10→9→8 และ Guard ยังผูกกับ grant #1 |
| Player Guard ล้างเมื่อ DOWN | #1 DEFEND แล้ว CANCEL HELP ที่ล็อกจริงทั้งสาม NPC. #5 ทำ HP 2→1 และ Guard คงอยู่. #6 ทำ HP 1→0 พร้อม DOWN episode และ Guard → null ด้วย cause DOWN ใน IMPACT เดียว |
| NPC Guard ใช้ครั้งเดียวใน V1 | #4 NPC3 เลือก DEFEND และได้ NEXT_ENEMY_HIT Guard. #5 hit แรกทำ HP 3→2 และ Guard → null ด้วย CONSUME. #6 hit ถัดมาใช้ damage3 โดยไม่ลดด้วย Guard ทำ HP 2→0/DOWN (HP delta ที่บันทึก −2) |
| NPC Guard + DOWN ใน V2 | #4 NPC3 DEFEND. #5 hit ที่ลดเหลือ 1 ทำ HP 1→0/DOWN และ Guard → null ด้วย GuardChange เดียว cause DOWN. #6 ใช้ target ที่ประกาศไว้เดิม ได้ TARGET_UNAVAILABLE SKIPPED (HP delta 0 และไม่มี change rows) แล้ว COMPLETE ด้วย receipt SKIPPED |

Focused proof ตรวจ schema ของ effect/resource/guard, forged token/receipt, duplicate IMPACT/COMPLETE, detached snapshots และ journal digest. Fault ก่อน publish และ candidate ที่ถูกแก้ resource หรือ Guard provenance ถูกปฏิเสธโดย root เท่าเดิมทุกฟิลด์ ก่อน retry ด้วย token เดิมสำเร็จ. CANCEL ก่อน impact เก็บ disposition จริงโดยไม่มีการใช้ทรัพยากรหรือสร้าง receipt. ทุก scenario สร้าง full root เดิมได้จาก seed และ journal

## การรันทดสอบ

ใช้ `/Applications/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official.ed1daf0bf`, SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`. Snapshot/output แต่ละกลุ่มเป็นชุดใหม่. [คำสั่งเต็ม, path, exits และ expected/actual](results.json)

| Gate | Expected | Actual |
|---|---:|---:|
| A · import / script parse | import + 8 script parses | ผ่านทั้งหมด, exit 0 |
| B · B1 original smoke | 86 | 86/86 |
| B · B1 original expanded | 97 | 97/97 |
| B · B1 recursive schema | 1,846 | 1,846/1,846 |
| B · B1 transactions/replay | 354 | 354/354 |
| C · focused B2 | §29 legal histories, schema, faults, replay | 1,010/1,010 assertions, exit 0 |
| D · historical pre-cutover `1728c5e678c5065278d1251d50449a8820eb5dae` | 44 stages | 44/44 |
| D · canonical + current cutover proof | 94 stages | 94/94 |
| D · B2 candidate + current cutover proof | 94 stages | 94/94 |

B1 smoke ใช้ไฟล์เดิมจาก [Recovery-01 source archive](../../b1/recovery-01/tested-source.zip) โดย SHA-256 ตรงกับ [Recovery-05 smoke hash](../../b1/recovery-05/ABC/smoke-harness-sha256.txt). Expanded/schema/transactions ใช้ไฟล์ B1 ที่ติดตามใน Git โดยตรง. Focused B2 มี 502 assertions ของธุรกรรมจริง, 331 ของ pure schema/policy และ 177 ของ adversarial rejection. จำนวนเหล่านี้เป็น assertions. มี dependency อีก 7 รายการที่บันทึก deferred แยกจากผลผ่าน

Combat ใช้ runner และ flags เดิมจาก [PR #60](../../b1/recovery-05/F/run-record.json) รวม `--main-cutover-proof` สำหรับ canonical/candidate และอ้าง fresh 44-stage reference สำหรับ cutover. Legacy 6 cases / 5,892 frames เท่ากันครบทั้งสาม run. ทุก stage exit0, timeout0, unexpected error0. แยก expected negative errors 5 รายการต่อ run ที่ `invalid-actions`. Main F5 startup, Legacy F6 headless path, M403/M404 และ Guidance v1/R1 อยู่ใน regression เดิม. การเตรียม wrapper รอบแรกแก้ความต่างของ Python และใช้ detached worktree เพราะ verifier ต้องอ่าน Git index. การเตรียมสองครั้งนั้นสิ้นสุดก่อนเรียก Godot

รันทดสอบบน candidate ก่อน commit. [Tested SHA-256 manifest](tested-source-sha256.json) ผูก source ที่ทดสอบกับไฟล์ส่งมอบ. [Logs, exits, source manifests, replay reports และ command records](logs-and-reports.zip) เก็บไฟล์จากผลรันเต็ม. [SHA-256 ของ ZIP และทุกรายการข้างใน](archive-sha256.json)

## Deferred และการตรวจอิสระ

- **B3** ต้องมี slot ในรอบถัดไปเพื่อทดสอบ HELP หลัง use หมดและ DEFEND grant ซ้ำโดยไม่ stack. การหมดอายุ Guard ที่ natural round close รอ B3 ด้วย
- **O7** ต้องมี producer ที่ได้รับอนุญาตสำหรับ target mutation หลัง lock
- **Capped HELP** มี pure arithmetic coverage. ที่ MaxHP30 และเกณฑ์ HP≤9 การฟื้น 4 HP ไปไม่ถึง cap ใน legal B2 history
- **Lifecycle ขั้นถัดไป** รอ actual RESCUE, DEAD และ RETREATED. Terminal/Restart cleanup รอ B4
- GUI, keyboard, visual/pacing และ performance benchmarks ยังไม่ได้รัน

- [ ] ตรวจ merge-base, changed-file allowlist, preservation และ tested-to-committed SHA-256
- [ ] ตรวจ V1 serialization/digest และ exact V2 ID/version/revision binding ทุกชั้น
- [ ] ตรวจ token ที่ owner ออกจริง, HELP spend, Guard precedence, HP/lifecycle และ receipt ของแต่ละ trace
- [ ] ตรวจ rejected/fault root equality, exact replay และ expected negative errors จาก logs
- [ ] ตรวจ dependency ที่ยัง deferred และหยุดที่ Draft B2 PR เพื่อรอ Owner Decision
