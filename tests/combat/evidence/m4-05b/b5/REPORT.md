# M4-05B B5 — หลักฐานฉากเล่นแยก

**IMPLEMENTED CANDIDATE · Independent Code, Contract, Evidence & Scene Review pending.** ฐาน `visual-combat-test-1` ตรงกันทั้ง HEAD, FETCH_HEAD, remote-tracking ref และ live remote ที่ `0148a31f37baad9dcd5c9524604d6d8270fbbdb5`. GitHub ยืนยัน [PR #66](https://github.com/shanwinder/wanderer/pull/66) merge เข้าฐานนี้ ก่อนสร้าง `codex/m4-05b-b5-playable-scene` ใน worktree แยก พบ PR เปิด #2/#17 และไม่พบ B5 branch, scene หรือ Draft เดิม

## ฉากและ authority

- [ฉาก](../../../../../scenes/combat/combat_m4_playable_optin.tscn) ใช้ sprite, เงา และ Compact Formation จาก baseline. [Controller](../../../../../scripts/combat/m4_playable_controller.gd) ประกอบ owner เดียวจาก catalog และรับเฉพาะคำสั่ง Player, Guidance และ Restart ผ่าน input adapter เดิม
- DRIVER อ่าน slot จาก `Rules.slot(owner.snapshot())` ซึ่งเป็นสำเนา detached เพราะ View ไม่มีฟิลด์ current slot. `ADVANCE` ตัดสิน disposition และ `DECIDE_LOCK` ใช้ observation ของ owner ขณะถึง slot จริง. Presenter รับ callback ที่ B4 ผูกกับ full token และ generation
- [HUD/adapter](../../../../../scripts/combat/m4_playable_presentation_adapter.gd) อ่าน View และ Presentation Events ตาม [§31](../../../../../docs/M4_05_Playable_Integration_Contract.md#31-b4-presentation-projection-and-restart). การข้าม slot ใช้ผล ADVANCE ของ owner ส่วน SKIPPED หลัง lock ใช้ IMPACT event. ใช้ visual Tween adapter เดิมกับ `0.70`, lunge `44px` และท่า Attack/Defend เดิม. RESCUE/RETREAT ใช้ท่า stationary แบบสั้น และอัปเดต pose/การปรากฏตัวเมื่อมี committed IMPACT
- Restart ที่สำเร็จจะเปลี่ยน callback epoch, หยุด Tween และคืนตำแหน่ง ก่อน render RESET. E5 แสดง stage/reason จริงและให้เปิด factory session ใหม่หลัง detach. การทดสอบ E5 ใช้ fault seam เดิมใน proof. UI ปกติให้เฉพาะคำสั่ง Player ATTACK/DEFEND และ Guidance v1
- [คู่มือเปิดฉากด้วย F6 และวิธีใช้ปุ่ม](../../../README.md#m4-05b-b5--opt-in-playable-scene). Default F5, Legacy F6, B1–B4, Guidance v1/R1, M403/M404, fixture และ `verify.py` ตรงกับ canonical ตาม [source manifest](source-hashes.json)

## Automated verification

Executable `/Applications/Godot.app/Contents/MacOS/Godot` รุ่น `4.7.2.stable.official.ed1daf0bf` · SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`. Tested source commit `6df88c3d8c6dc7d730ffe2e61befefe9f8681439`. เทียบ committed blobs กับ worktree และ candidate snapshot ตรงกัน 160 ไฟล์ รวม dependency เดิม 153 ไฟล์

| Gate | ผล |
|---|---|
| B5 standalone import, parse 3 scripts, startup | PASS · exit 0 · unexpected errors 0 |
| B5 scene proof | PASS · 1,521 checks · exit 0 · unexpected errors 0 |
| B1 Smoke / Expanded / Schema / Transaction | PASS · 86 / 97 / 1,907 / 354 |
| B2 / B3 / B4 | PASS · 1,031 / 2,507 / 4,238 |
| Fresh reference / canonical / candidate regression | 44 / 94 / 94 stages PASS · ทั้งสาม exit 0 |
| Legacy exact comparison | ทั้งสาม trace ตรงกันทุก frame · 6 cases / 5,892 frames |
| Negative engine diagnostics | 5 expected ต่อ regression run · unexpected 0 |

[ผลและคำสั่งราย stage](results.json) · [Logs, reports, transaction and presentation traces](logs-and-traces.zip). Trace ของ B5 เก็บ journal, tokens, receipts, queue dispositions, event stream และ Restart audit แยกตาม scenario. Proof ใช้ scene signals และ Tween จริงทีละ 1/60 วินาที. ทดสอบ fallback ด้วยคำขอ ATTACK ที่ระบุศัตรู known-but-unavailable ผ่าน input adapter เพื่อให้ owner เลือกศัตรูที่ยังพร้อมตามกฎ. Picker ปกติแสดงเฉพาะเป้าหมายพร้อมใช้

**VERIFIED:** actual Player ATTACK/DEFEND; strict Guidance ทั้งห้าแบบและ freeze; คิวเต็มและปิดรอบ; สอง kill orders; Last-Party DOWN; RESCUE โดยไม่คืน Player slot; HELP +4; ordinary RETREAT; Guard grant/mitigation/expiry; DOWN/DEAD/clock; SKIPPED; exhaustion; และ Restart ทั้งเจ็ดจังหวะ รวม rejected Restart ที่ callback ยังทำงานได้, E5 exit และ stale callbacks. Last-Party DOWN และ exhaustion ใช้ DRIVER CANCEL ก่อน IMPACT ตาม legal histories ของ B3. ผู้เล่นทั่วไปไม่มีปุ่ม CANCEL. B4 ยังคงตรวจ classifier, schema และ rejection สำหรับผลถอนตัว

## GUI และ keyboard smoke

เปิด executable จริงด้วย `--path . --resolution 1280x720 --position 40,60 res://scenes/combat/combat_m4_playable_optin.tscn` และควบคุมผ่านหน้าต่าง Godot บน macOS. [ภาพ 1280×720 จาก Godot renderer](startup-1280x720.png) เป็น startup frame จาก source สุดท้าย. การเล่นผ่านหน้าต่างใช้ revision ระหว่างพัฒนาก่อนปรับ contrast ของ log และเพิ่มข้อความ stage ใน E5. [ภาพจริงจากหน้าต่างระหว่างเล่น](gui-smoke.zip) มี Guidance, keyboard Attack, Guard, DOWN, VICTORY และ Restart พร้อม call ID และบรรทัดต้นทางใน transcript

| ทำซ้ำใน GUI | สิ่งที่เห็นจริง |
|---|---|
| เปิดฉากที่ 1280×720 | Compact Formation, Player 30/30, A 15/15, B 12/12, Thai controls และ focus เริ่มที่ช่องเป้าหมาย |
| เปิด Guidance ด้วยเมาส์ เลือก Focus Target A แล้วกด Tab ไปยังปุ่มส่ง จากนั้นกด Enter | Pending แสดง Focus A. ระหว่างลงมือขึ้นคำชี้นำของรอบและซ่อน controls |
| กด Tab ไป Attack แล้วกด Enter. ทำซ้ำด้วย Space หลัง Restart | A เสีย 5 HP ตอนกระทบ เห็น lunge และ hit feedback แล้วกลับตำแหน่ง |
| ปล่อยคิวเดินจบรอบ | NPC 3 ได้ Guard, ต่อมาล้มที่ 0 HP และแสดง budget 2. รอบ 2 เปิด input ใหม่. ต่อมาป้ายถอนตัวแสดงตาม participation |
| โจมตี A จนหมด แล้วโจมตี B ต่อ | เมื่อ A หมด picker เลือก B. รอบ 5 แสดง frozen VICTORY. เริ่มใหม่แล้วกลับรอบ 1 พร้อม HP, formation และ focus เริ่มต้น |

**NOT RUN:** Owner visual/UX acceptance, การวัด pacing ด้วยมือครบทุก pose, manual E5, §24.1 performance. การแยก Restart ระหว่าง WINDUP, IMPACT และ causal COMPLETE อาศัย scene proof. **DEFERRED — OWNER APPROVED:** positive Last-Party RETREAT ตาม §30.7 และ positive `NO_PLAYER_COMMAND` หลัง RESCUE ก่อน slot ที่ยังไม่ถูกใช้ตาม §30.6. Ordinary RETREAT และ real unavailable Player slot มีหลักฐานใน B5. ไม่มี Contract หรือ protected-file change ที่ต้องให้ Owner อนุมัติสำหรับ B5

## Hybrid AI Skills Usage Audit

ตรวจทั้ง worktree จริงและ `/Applications/wanderer/.agents/skills/` ก่อนเขียนโค้ด. สี่ไฟล์ที่ใช้มีใน checkout หลักและไม่มีใน B5 worktree. หลักฐานการอ่านคือ `functions.exec → tools.exec_command` ที่วน `wc -l` และ `cat` ตาม path ด้านล่าง จากนั้นตรวจ SHA-256 และ availability ซ้ำใน worktree. Transcript ของ session `01a1d541-50db-7dd1-a636-ca9ee24cd9b2` บรรทัด 34 (`call_1b69bb354b1243b7a540fe6b404f989b`) ระบุคำสั่งอ่าน และบรรทัด 54 (`call_544fdb97c672415dae0a5a5d0`) ระบุ availability/hash check. สถานะในตารางอ้างการใช้ไฟล์เป็น reference

| Skill / path | การนำไปใช้ | การตรวจ | สถานะ |
|---|---|---|---|
| `godot-gdscript` · `/Applications/wanderer/.agents/skills/godot-gdscript/SKILL.md` | typed dictionary/Variant boundary, `@onready` HUD, callback correlation | Godot parse/startup และ proof ตรวจ callback เก่าและ rejected Restart | READ AS REFERENCE / APPLIED |
| `godot-nodes-scenes` · `/Applications/wanderer/.agents/skills/godot-nodes-scenes/SKILL.md` | scene composition, actor NodePaths, script UID | ตรวจ source ของ checker แล้วรัน `check_godot_project.py --json` กับ B5 และ instantiate ฉากด้วย engine | READ AS REFERENCE / APPLIED |
| `godot-gdscript-headless-testing` · `/Applications/wanderer/.agents/skills/godot-gdscript-headless-testing/SKILL.md` | SceneTree runner, explicit failure counter/exit, timeout และ scan engine errors | report/exit ของ scene proof และ logs ของรอบพัฒนา | READ AS REFERENCE / APPLIED |
| `godot-ui-control` · `/Applications/wanderer/.agents/skills/godot-ui-control/SKILL.md` | แยก HUD Control, จัดปุ่มด้วย Containers, คืน keyboard focus ตาม owner boundary | ตรวจ layout 1280×720 ใน proof และ smoke ใน Godot จริง | READ AS REFERENCE / APPLIED |
| `router` · `/Applications/wanderer/.agents/skills/router/SKILL.md` | ตรวจ availability. งานระบุ engine และ skill ที่ต้องใช้ชัดเจน | ไม่มีการเปิดอ่าน | AVAILABLE ONLY |

## ขอบเขตและรอบพัฒนา

Allowlist มี scene ใหม่หนึ่งไฟล์, controller/adapter สองสคริปต์, scene proof หนึ่งไฟล์, UID สามไฟล์, README สามไฟล์ และหลักฐานใน directory นี้. Historical evidence ของ PR #64–66 คงเดิม

รอบแรกของ import ใน sandbox ขึ้น error ของ macOS certificate และสิทธิ์บันทึก editor settings. Import ยืนยันใหม่โดยให้ Godot ใช้สิทธิ์ปกติ. รอบพัฒนายังพบชื่อ `Projection` ชน built-in, syntax ของ test lambda และ index ของ battle log. เก็บ logs รอบนั้นไว้ใน archive. ปรับ proof ให้ก้าวทีละเฟรมเพื่อแยก windup/impact/return จากกัน. Review นี้ยังต้องตรวจภาพและภาษาไทยตาม M4-05C แยกจาก B5

Wrapper แรกใช้รูปแบบข้อความ PASS ของ B1 กับ B4. ตรวจผล B4 เดิมใหม่จาก exit 0, exact summary และ JSON ที่ผ่าน 4,238 checks, 474 transactions และ 28 streams โดยใช้ output เดิมและเก็บ raw wrapper record ไว้.
