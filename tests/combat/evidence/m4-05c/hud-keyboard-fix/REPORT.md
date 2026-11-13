# B5 HUD — แก้บันทึกการต่อสู้และโฟกัสคีย์บอร์ด

**IMPLEMENTED / VERIFIED ตามขอบเขตด้านล่าง · รอ Independent Code, Contract, Evidence & GUI Review.** ฐาน `visual-combat-test-1` ที่ HEAD, FETCH_HEAD, remote tracking, live remote และ merge base ตรงกัน: `40dd5f0d4070b491d4944811474528701da4f09d`. Working tree เดิมสะอาด; PR เปิด #2, #17, #68 ไม่มีงานซ้ำ; สร้าง branch `codex/m4-05c-b5-hud-keyboard-fix` ใน worktree แยกใต้ `~/Development/wanderer-worktrees/`. [Draft PR #68 เดิม](https://github.com/shanwinder/wanderer/pull/68) และ [FINDINGS.md เดิม](https://github.com/shanwinder/wanderer/blob/bfab1224df330df6d980da6c4ba225e9c89cb907/tests/combat/evidence/m4-05c/FINDINGS.md) ยังเป็นหลักฐานประวัติ ไม่ถูกแก้ในงานนี้.

ทดสอบโค้ด `4c99aa0172bab5bfde6bde9ad20178835b470c19` (เอกสารและหลักฐานเพิ่มใน commit ถัดมา). Godot ที่รันจริง: `/Applications/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official.ed1daf0bf`, SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`. อ้างอิง [สัญญา §14, §20, §31](../../../../../docs/M4_05_Playable_Integration_Contract.md) และ [คู่มือ B5](../../../README.md#m4-05b-b5--opt-in-playable-scene).

## สาเหตุและสิ่งที่แก้

- **C-01:** `TextEdit` แบบอ่านอย่างเดียวรับโฟกัสและรับ Tab/Shift+Tab ไว้เอง; HUD เดิมไม่มีทางออกด้วย Escape. ทดสอบกับฐานจริงจาก Player Target → Shift+Tab ×4 → Page Up → Tab → Shift+Tab → Esc; กรอบยังอยู่ที่บันทึก [Tab](screens/before-tab-trap.jpg) · [Shift+Tab / Esc](screens/before-reverse-tab-escape-trap.jpg). ตอนนี้ใช้ `Label` ตัดบรรทัดใน `ScrollContainer` ที่มีกรอบโฟกัส และกำหนดเพื่อนบ้านจากปุ่มที่มองเห็นและใช้งานได้ในสถานะปัจจุบัน. ตัวอ่านจัดการ Page Up/Down; L/Esc ทำงานจาก `_unhandled_key_input` หลัง GUI และข้าม popup ของตัวเลือก. [Godot input dispatch](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html).
- **C-02:** เมื่อรับ Attack แถวคำสั่งถูกซ่อน โฟกัสหลุด แล้ว render เดิมส่งโฟกัสให้ Restart. ทดสอบฐานจริงจาก Player Target → Tab → Return ×2: [รุ่น 2 ปรากฏ](screens/before-double-enter-reset.jpg) แม้ไม่ได้เลือก Restart. ตอนนี้โฟกัสสำรองอยู่ที่สถานะการต่อสู้ซึ่งกดใช้งานไม่ได้. การเริ่มใหม่หรือออกจาก HOLD ต้องเลื่อนไปที่ปุ่มเองหรือคลิก. เมื่อเริ่มรอบถัดไป คืนโฟกัสที่ Player Target หากไม่ได้เปิดอ่านบันทึก. ไม่เพิ่ม delay หรือปรับจังหวะคิว.
- ปิดบันทึกไว้ตอนเริ่มและยกแถว HP ขึ้น 87 px ใน viewport 1280×720. [ก่อน](screens/before-layout.jpg) · [หลัง](screens/after-default.jpg). สถานะ/เจตนาของผู้กระทำและผลล่าสุดแสดงแยกกัน. HP, Guard, DOWN/DEAD/RETREAT และคำชี้นำยังเห็นที่ HUD; ผลสำเร็จมาจากเหตุการณ์หรือผลที่ owner ยืนยันแล้ว. บันทึกภาษาไทยเต็มยังเปิดอ่านได้; การปิดไม่ลบข้อความ การ Restart ที่ owner รับจริงล้างบันทึกที่แสดงของรุ่นเดิมตามเดิม. ไม่มีการแก้ journal, receipt, fixture, controller, scene, shared presentation, combat authority, Default F5 หรือ Legacy F6.
- **C-03:** ผล “ชัยชนะ / VICTORY” เห็นทันทีใน HUD แบบย่อ. รหัส `M403_ENEMIES_UNAVAILABLE` ยังอ่านได้ในบันทึก แต่เป็นศัพท์ภายในและอาจอ่านยาก [ภาพจริง](screens/after-victory-log-reason.jpg). ข้อเสนอแยก: ถ้า Owner ต้องการ ให้แสดง “ไม่มีศัตรูที่ยังต่อสู้ได้” ใน UI โดยคงค่ารหัสเดิม. **DEFERRED** ในงานนี้.

## VERIFIED — หน้าต่าง Godot จริง

ทดสอบวันที่ 14 พฤศจิกายน 2026 (Asia/Bangkok) บน macOS 27.0.1 (26A434) / Apple M1 / OpenGL Compatibility. ส่งปุ่มและคลิกผ่าน Computer Use. ภาพ JPEG จากหน้าต่างจริงขนาด 1280×784 รวม chrome ของ macOS 64 px; พื้นที่เกม 1280×720. [ลำดับปุ่ม พิกัดคลิก เวลา call ID และ hash รายภาพ](captures.json). สังเกตโฟกัสจากกรอบในหน้าต่าง; โฟกัสจริงและข้อมูล owner มาจาก proof แยกด้านล่าง.

| กรณี | คำสั่งและผลจริง |
|---|---|
| A — HUD เริ่มต้น | [บันทึกซ่อน, HP/คำชี้นำ/เป้าหมายอ่านได้](screens/after-default.jpg) และเห็นฉากหลังเพิ่มก่อนถึงแถวตัวละคร. |
| B — อ่านประวัติ | `L` → [กรอบที่ตัวอ่าน](screens/after-log-reader-focus.jpg) → [Page Up ย้อนอ่านข้อความไทย](screens/after-page-up.jpg) → Page Down / [Tab ไป Guidance](screens/after-page-down-tab-guidance.jpg) → [Shift+Tab ผ่านตัวอ่านไปปุ่มบันทึก](screens/after-reverse-tab-toggle.jpg) → [Esc คืน Player Target](screens/after-escape-target.jpg). คลิกปุ่ม [เปิด](screens/after-mouse-open.jpg) / [ปิด](screens/after-mouse-close.jpg) ได้. |
| C — กดซ้ำ | รอบแรก Tab/Return/Return → [สถานะถือโฟกัส, A เหลือ HP10](screens/after-double-enter.jpg); รอบสอง Tab/Space/Space → [คิวยังเดินและ NPC3 ได้ RESCUE](screens/after-double-space-rescue.jpg). ไม่พบ reset; จำนวนคำขอ/receipt และ key echo ตรวจแยกใน proof. |
| D — ตั้งใจ Restart | ที่ผลชนะ Esc → Shift+Tab จากสถานะ → [Restart ได้โฟกัส](screens/after-victory-closed-log-restart-focus.jpg) → Return → [รุ่น 2 / รอบ 1 / HP seed / Player Target](screens/after-victory-restart-generation2.jpg). |
| E — ผลจบ | Attack ปกติห้ารอบ A,A,A,B,B → [VICTORY, A/B HP0](screens/after-victory.jpg) → L [อ่านเหตุผล](screens/after-victory-log-reason.jpg) → [Tab ไป Restart ได้](screens/after-victory-tab-restart.jpg) → Shift+Tab / Esc / Shift+Tab / Return ตาม D. |
| F — รอบถัดไป | หลังคิวรอบแรกจบ [Player Target ได้โฟกัสและ NPC3 DOWN](screens/after-round2-down-target-focus.jpg) ขณะบันทึกยังปิด. |
| ครบหกรอบ | Defend ×6: [Guard](screens/after-defend-guard.jpg), [ลดความเสียหาย](screens/after-guard-mitigation.jpg), [ครบหกรอบโดยศัตรูยังมี HP และไม่มี VICTORY](screens/after-exhaustion.jpg). L [อ่านประวัติ](screens/after-exhaustion-log.jpg) → Esc / Shift+Tab / Space → [รุ่น 3](screens/after-exhaustion-restart-generation3.jpg). |

## VERIFIED — การทดสอบอัตโนมัติ

[คำสั่งและผลรัน](run.json) · [ผลราย stage, engine/console logs, exit และรายงาน](logs-and-reports.zip) · [แฮช dependency และไฟล์ที่ตรวจ](source-sha256.json) · [แฮชหลักฐาน](SHA256SUMS).

- **Focused keyboard:** 81 checks, 0 failures. ส่ง press/release/echo ผ่าน `Window.push_input(InputEventKey)` เข้าสู่ UI จริง. ครอบคลุม Enter/Enter, Space/Space และทั้งสองลำดับผสม. แต่ละชุดเริ่ม generation 1 / revision 0 / journal 0 / receipt 0 → กด Attack ครั้งแรก generation 1 / revision 1 / journal 1 / receipt 0 / BattleStatus → กดซ้ำและ echo แล้ว snapshot เท่ากันทั้งชุด → Tween ทำ HP −5 และออก receipt 1 ครั้ง. ยืนยันว่าการอ่านและเลื่อนบันทึกไม่เปลี่ยน owner. ข้อมูล focus/revision/journal/receipt ของแต่ละปุ่มอยู่ใน [keyboard.json](keyboard.json).
- **HOLD:** ใช้จุดฉีดความล้มเหลวที่มีอยู่แล้วใน test เท่านั้น เพื่อให้ owner เข้า `SEALED` จริง; เห็น `M405_CLOSE_FAILED` ในสถานะและประวัติ. Restart ที่เรียกทดสอบถูกปฏิเสธด้วย `M405_SEALED_RESTART` และ held snapshot เท่ากัน. Tab ข้าม Restart ที่ disabled ไป Exit; Space บน Exit สร้าง session ID ใหม่, generation 1 / revision 0 / journal และ receipts ว่าง. callback เก่าไม่มีผลทั้งหลัง Exit และหลัง Restart. ทดสอบ DEFEAT ด้วย immutable fixture และทดสอบ VICTORY/ครบหกรอบด้วยคำสั่งจริง.
- **B1–B5:** B1 Smoke 86 / Expanded 97 / Schema 1,907 / Transaction 354; B2 Effects 1,031; B3 Lifecycle 2,507; B4 4,238 checks / 474 transactions / 28 streams; B5 Scene 1,521 checks. ตัวเลขเป็น assertions จาก proof เดิม; ไม่รวมเป็นจำนวนสถานการณ์. ตรวจ import, parse และ B5 startup แยก. B5 เดิมตรวจ lunge 44 px ที่ impact และกลับบ้านหลังจบ action.
- **Full regression:** Reference 44/44, canonical 94/94, candidate 94/94. Legacy เท่ากัน 6 cases / 5,892 frames ทั้งสามรัน (ไฟล์ trace ตรงกันทุกไบต์). ห้า negative errors ที่คาดไว้ต่อรันอยู่ใน `invalid-actions`; unexpected errors 0. ตรวจ SHA-256 ของ source snapshot และตรวจว่าไฟล์ gameplay/fixture/scene เดิมเท่าฐาน.

**NOT RUN:** Owner acceptance, native GUI ของ E5/Rejected Restart และ seeded DEFEAT, การวัดเวลาแอนิเมชันแบบเทียบเฟรม, benchmark §24.1 และการทวน F5/Legacy ด้วย GUI ใหม่. ตรวจ F5/Legacy ด้วย automated suite; มีภาพจาก B5 สำหรับการเคลื่อนไหวและตำแหน่งตามตัวอย่างเท่านั้น. ขอบเขตที่ Owner อนุมัติให้เลื่อนตาม §§30.6–30.7 ยัง **DEFERRED**.

## Hybrid AI Skills Usage Audit

อ่านไฟล์จริงใน checkout หลัก; ไม่ได้ invoke เป็น native Skill. ใช้คำสั่งของโครงการและ engine โดยตรง. ไม่ได้เรียก third-party helper; UI skill อ้างถึง `game-ui-ux` แต่ไม่พบในชุดที่ติดตั้ง และขอบเขต UI มาจาก Owner อยู่แล้ว. ไม่ต้องใช้ router เพราะระบุทั้งสี่ Skill ตรงงาน.

| Skill ที่อ่าน | นำมาใช้และวิธีตรวจ |
|---|---|
| `/Applications/wanderer/.agents/skills/godot-ui-control/SKILL.md` | ตรวจ viewport/stretch; ทำ focus order ชัดเจน, แสดงกรอบ และตรวจ 1280×720 ด้วย GUI. |
| `/Applications/wanderer/.agents/skills/godot-nodes-scenes/SKILL.md` | คง wiring ของฉากเดิม; ทดสอบ instantiate ฉากจริงและ standalone startup. ไม่มีการแก้ `.tscn`/`.tres`. |
| `/Applications/wanderer/.agents/skills/godot-gdscript/SKILL.md` | ใช้ type ของ Control/InputEventKey และตรวจ parse ด้วย engine จริง. |
| `/Applications/wanderer/.agents/skills/godot-gdscript-headless-testing/SKILL.md` | SceneTree proof นับ failures และคืน exit nonzero; แยก import, parse, stdout, engine errors และ runtime evidence. |

ขั้นถัดไป: Independent Code, Contract, Evidence & GUI Review ของ Draft นี้ แล้วให้ Owner ลอง F6 ที่ 1280×720 โดยเน้นความชัดของโฟกัสและข้อความระหว่าง action. การรวม PR, M4-05C final acceptance และ production cutover ต้องมีคำสั่งแยก.
