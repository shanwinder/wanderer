# WANDERER — คู่มือเรียน GDScript ผ่านการสร้างเกมจริง
## Self-Study & AI Tutor Handoff · ฉบับพกพา

**อัปเดต:** 11 ตุลาคม 2026  
**เจ้าของแผน:** ผู้สร้างเกม Wanderer (เรียนด้วยการลงมือเขียนเอง)  
**สถานะ:** Learning curriculum — ไม่ใช่เอกสารกติกาเกมฉบับที่ 4  
**ใช้กับ:** Godot 4.x / GDScript 2.0 โดยต้องตรวจเวอร์ชันที่ติดตั้งจริงก่อนใช้ตัวอย่าง  
**เอกสารเกมที่ควรอ่านเมื่อจำเป็น:** [GAME.md](../docs/GAME.md), [WORLD.md](../docs/WORLD.md), [WORKFLOW.md](../docs/WORKFLOW.md)

> **เป้าหมาย:** ผู้สร้าง Wanderer สามารถอ่าน อธิบาย เขียน ทดสอบ แก้บั๊ก และค่อย ๆ ออกแบบ GDScript สำหรับเกมของตนเองได้ โดยใช้ AI ใดก็ได้เป็น **ครู/ผู้ตรวจงาน** ไม่ใช่ผู้เขียนเกมแทนทั้งหมด

---

# 0. อ่านตรงนี้ก่อนส่งแผนให้ AI ตัวใหม่

## 0.1 จุดเริ่มต้นที่ยืนยันได้ (อย่าคิดเอาว่าเรียนครบแล้ว)

- **ผู้เรียนรายงานว่าเรียน GDScript ถึงหัวข้อ `function` (`func`) แล้ว**; ยังไม่ได้ทดสอบว่าเข้าใจ parameters, `return`, scope หรือ typed signatures แค่ไหน
- **ยังไม่ยืนยันความคล่อง** เรื่อง variables, constants, `if`, loop, Array, Dictionary, signals หรือ class ถึงแม้จะพบ syntax เหล่านี้ในโปรเจกต์เดิม
- ผู้เรียนต้องการ **เรียนไปพร้อมพัฒนา Wanderer** โดยตนเองลงมือใน Godot; หากบทไหนยาก ให้ชะลอและฝึกตัวอย่างที่เล็กลงก่อน ไม่ต้องเริ่มใหม่ทั้งหลักสูตร
- **สถานะการพัฒนาตามบันทึกเดิม (ไม่ได้ทดสอบสดสำหรับคู่มือนี้):** M0/M1 ขั้นต้นเสร็จ, M1.5A ผ่านการจัดภาพต้นแบบ, **งานถัดไป M1.5B Combat Staging**; M1.5C–M7 ยังไม่ใช่ระบบที่ยืนยันว่าทำแล้ว
- **โค้ดจริงที่ตรวจเมื่อร่างแผน:** `scripts/combat/combat_prototype.gd` มี **245 บรรทัด / 9 ฟังก์ชัน** และเริ่มด้วย `extends Control`. มีปุ่ม Attack/Defend/Restart, `const`, `var`, `@onready`, `if`, `pressed.connect` และ UI update; ต้นแบบยังมี **Player vs Enemy A** เป็น logic หลัก, NPC อีก 3 คนแสดงเป็นภาพ. ไม่พบการใช้ loop หรือ Array/Dictionary ในสคริปต์นั้น
- `project.godot` ระบุ `config_version=5`, viewport **1280×720** และ `config/features` มี **"4.7"** — ข้อความนี้ **ไม่ใช่การตรวจเวอร์ชัน executable ของ Godot ที่เครื่องผู้เรียน**. ให้เปิด **Help → About Godot** หรือใช้คำสั่ง `godot --version` / executable ที่ติดตั้ง แล้วอ้าง docs ตรงรุ่น; อย่าอัปเกรดโปรเจกต์อัตโนมัติ

## 0.2 ข้อตกลงการสอนที่ต้องรักษาแม้เปลี่ยน AI

1. **ครูแบบ Guided Steps เป็นค่าเริ่มต้น** — อธิบายแนวคิดสั้น ๆ → สั่งให้ผู้เรียนลงมือ **ทีละหนึ่งงานเล็ก** → รอภาพ/โค้ด/ผลรัน → ให้ผู้เรียนบอกความเข้าใจ → ค่อยไปงานต่อไป
2. **ไม่ส่งไฟล์ script สำเร็จทั้งก้อน** หรือแก้ระบบให้โดยไม่ขออนุญาต. ตัวอย่างโค้ดสั้น 5–15 บรรทัดได้เมื่อติดจริงหรือเพื่อสอนแนวคิด
3. อธิบายคำสั่งด้วยการโยงให้เห็น **ผลบนเกม** เสมอ (เช่น HP ลด, ตัวละครขยับ, NPC ไม่ยอมตาม, ข่าวเส้นทางเปลี่ยน)
4. เมื่อมี error ให้ขอ **ข้อความ error เต็ม + path/line + ผลที่คาด/ผลที่เห็น + code บริเวณนั้น** ก่อนแก้; อย่าเดาหรือเปลี่ยนหลายระบบพร้อมกัน
5. **ห้ามทำเป็นว่าระบบออกแบบในเอกสาร implement แล้ว**; ความต่างระหว่าง design/prototype/verified runtime ต้องระบุชัด
6. ใช้ **GDScript 4.x**: `@onready`, `await`, signal property `button.pressed.connect(...)`. ห้ามยกตัวอย่าง Godot 3.x เช่น `onready var` หรือ `yield()` มาใช้โดยไม่บอกความแตกต่าง
7. ปฏิบัติตาม **Goal → Concept → Do → Observe → Explain → Adjust → Commit**; 1 บทเรียนไม่จำเป็นต้องได้ 1 commit หากยังเป็นการลองที่ไม่ผ่าน
8. **ไม่ข้าม Milestone** เพื่อไล่เรียน syntax ขั้นสูง. งานโลก / 7 ภูมิภาค / เวท / เมืองอื่น ยังไม่เกี่ยวกับ M1.5B

## 0.3 วิธีอ่านคู่มือนี้ให้ไม่เปลือง token

- ครู AI อ่าน **§0 + §1 + บทที่กำลังเรียน + §7 (ข้อความส่งต่อ)** ก่อน; เปิด §2–§6 เฉพาะเมื่อใช้
- **ไม่ป้อนคู่มือทั้งหมดทุกครั้ง**; ส่งแค่สถานะการเรียนล่าสุด + path ใน GitHub + ไฟล์ `.gd` ที่กำลังแก้
- หาก AI เข้า GitHub ไม่ได้ คัดลอกเพียงบทปัจจุบัน และบทสรุปจาก `docs/WORKFLOW.md`
- ให้ผู้เรียนทำซ้ำโจทย์ 1 รอบ **โดยไม่ดูเฉลย** ก่อนนับว่าผ่าน

---

# 1. แผนที่การเรียน: เรียนตามระบบที่จะสร้าง ไม่ใช่ตามจำนวนสัปดาห์

**ไม่มี deadline บังคับ** — คนมีเวลา 20 นาทีหรือ 2 ชั่วโมงต่อครั้งใช้หลักสูตรเดียวกันได้. แต่ละหัวข้อมีป้ายสถานะ:

- **[NEW]** ยังไม่ได้ลอง
- **[SEEN]** เคยพบหรืออ่านได้บางส่วน แต่ยังไม่ผ่านการฝึก
- **[PRACTICED]** ทดลองเขียน/แก้และรันด้วยตนเอง
- **[UNDERSTOOD]** อธิบายด้วยคำตนเอง ดัดแปลงโจทย์ และแก้ error ตัวอย่างได้
- **[BUILT]** ใช้กับงานเกมจริงที่รันทดสอบและตรวจ Git diff แล้ว

**เกณฑ์ผ่านบท:** (1) อธิบายแนวคิดโดยไม่อ่านตามตำรา (2) ลงมือสร้าง/แก้ตัวอย่างเล็กโดยไม่คัดลอกทั้งหมด (3) ทดสอบกรณีปกติและผิดเงื่อนไขอย่างน้อยอย่างละหนึ่ง (4) อธิบายผลเมื่อเปลี่ยนค่าหนึ่งตัว (5) ระบุความเข้าใจที่ยังขาดได้

| กลุ่มบท | หัวข้อ | เกมที่นำไปใช้ | Milestone |
|---|---|---|---|
| 00 | ตั้งค่าและวิธีอ่านโปรเจกต์ | แกะ scene/script เดิม ไม่ทำลายงาน | ก่อน M1.5B |
| 01 | ตัวแปร ชนิดข้อมูล ค่าคงที่ เงื่อนไข | HP / Defend / ตรวจจบศึก | เตรียม M1.5B/C |
| **02 (เริ่มจริง)** | **ฟังก์ชัน params, return, scope** | แยก logic ลด HP / combat log | M1.5B→C |
| 03 | Node, scene, lifecycle, signal | กดปุ่มแล้วฟังก์ชันทำงาน | M1.5B/C |
| 04 | Vector2, transform, node path | จัด formation บนหน้าจอ | **M1.5B** |
| 05 | Tween, await, feedback & animation | ขยับโจมตีและกลับตำแหน่ง | M1.5C |
| 06 | Array, Dictionary, for, match | จัดลำดับ combat actions / actors | M1.5D→M2 |
| 07 | Script class, Resource, object reference | แยกข้อมูลตัวละครจาก UI | M2 |
| 08 | State machine, turn flow | Actor เลือกแล้ว resolve ทีละคน | M2 |
| 09 | NPC decision rules & tests | ตัดสินใจ Attack/Help/Retreat | M2 |
| 10 | Guidance, signals, UI messaging | Player แนะนำได้แต่ไม่บังคับ | M3 |
| 11 | Injury, Down, Death, Retreat | ระบบแพ้/ช่วย/สูญเสียที่มีเหตุผล | M4 |
| 12 | Persistence & serialization | World memory ต่างจาก player trust | M4–M6 เมื่อพร้อม |
| 13 | Journey graph, events & data | เส้นทาง A/B และเหตุการณ์ | M5 |
| 14 | Town UI, quests, party | Stonegate เมืองเดียว | M6 |
| 15 | Integration & regression | Vertical Slice 1 town/2 routes | M7 |
| 16 (optional) | Resource item & Resonance | Pulse Pendant 1 ชิ้น | M4.R **เมื่อได้รับอนุญาต** |

*ลำดับ 01/02/03/04 ยืดหยุ่นตามงานจริง; ไม่จำเป็นต้องเรียนทุกคำสั่งก่อนจัดฉาก M1.5B ซึ่งใช้ Inspector ได้*

---

# 2. บทเรียนแต่ละบท (โจทย์จริงและหลักฐานผ่าน)

## บท 00 — รู้จักสภาพแวดล้อมและป้องกันงานเสีย

**ก่อนเรียน:** ตรวจเวอร์ชัน Godot ที่เปิดโปรเจกต์ได้จริง, Git branch และ working tree; เปิด scene ต้นแบบได้  
**รู้จัก:** Scene Tree, Inspector, Script, FileSystem, Output, Debugger, Remote scene tree, การรัน scene (F6) กับรันทั้งโปรเจกต์ (F5)  
**ลงมือ:** (A) สำรวจฉากและบอกว่า Node ไหนแสดง sprite ไหนแสดง UI (B) เปิดสคริปต์ combat และหา `_ready()`, `_update_ui()` (C) สร้าง Git branch ทดลอง/commit checkpoint **เมื่อจำเป็น**, ไม่แก้ไฟล์หลักโดยไม่รู้  
**ทดสอบ:** รันต้นแบบได้, Attack/Defend/Restart ยังทำงานตามเดิม; เช็กว่าไม่มี uncommitted files ที่ไม่ตั้งใจ  
**ผ่านเมื่อ:** บอกความต่าง scene, script, node, property, method และ signal ได้; บอกวิธีกลับ commit ล่าสุดโดยไม่ทำลายงานอื่นได้

## บท 01 — ตัวแปร ชนิดข้อมูล ค่าคงที่ และเงื่อนไข (ตรวจพื้นฐานก่อน)

**รู้จัก:** `var`, `const`, `int`, `float`, `bool`, `String`, `=`, `+=`, `-=`, comparison, `and/or/not`, `if/elif/else`, indentation, type hints `var hp: int`.  
**ของจริงใน repo:** `PLAYER_MAX_HP`, `ENEMY_MAX_HP`, `player_hp`, `enemy_hp`, `player_is_defending`, `battle_is_over`.  
**แบบฝึก A:** คาดผล HP หลังโจมตี 3 รอบจากค่าเริ่มต้นใน script โดย **ไม่รันก่อน** แล้วค่อยรันเพื่อตรวจ  
**แบบฝึก B:** เขียน logic บนกระดาษ/ไฟล์ฝึกให้ `hp` ไม่ต่ำกว่า 0 และไม่เกิน max; ทดสอบค่า -5, 0, 12, max+10  
**แบบฝึก C:** อธิบายว่า `=` กับ `==` ต่างกันอย่างไร และทำไม `const` ไม่ควรเปลี่ยนระหว่างเกม  
**ผ่านเมื่อ:** อธิบาย flow ของ `_on_attack_button_pressed()` และ `_enemy_turn()` ได้; แยก compile/syntax กับ bug ตรรกะได้

## บท 02 — FUNCTIONS: บทปัจจุบันของผู้เรียน [START HERE]

**อ่านในโค้ดจริง:** `_ready()` (ประมาณบรรทัด 67), `_start_new_battle()` (81), `_on_attack_button_pressed()` (107), `_enemy_turn()` (163), `_update_ui()` (208), `_add_log(message: String)` (223), `_end_battle(player_won: bool)` (230). หมายเลขบรรทัดจาก revision ที่ตรวจ อาจเปลี่ยนภายหลัง

**ชุดย่อย F1 — นิยามและเรียกใช้**
- รูปแบบ `func function_name() -> void:`; รู้ว่า **นิยาม** ไม่ได้แปลว่า **ถูกเรียก**
- ลากลูกศร Call chain: `_ready() → _start_new_battle() → _update_ui()`
- อธิบายว่า `_ready()` เป็น lifecycle callback ของ Godot แต่ `_start_new_battle()` เป็นชื่อฟังก์ชันที่โปรเจกต์ตั้งเอง

**ชุดย่อย F2 — Parameter**
- หา `_add_log(message: String)` และเหตุผลที่การส่งข้อความเข้า function ดีกว่าทำฟังก์ชันใหม่ทุกข้อความ
- เปรียบเทียบ `_end_battle(player_won: bool)` เมื่อรับ `true` กับ `false`
- ฝึกออกแบบฟังก์ชัน `format_hp(current: int, maximum: int) -> String` โดยระบุ input/output ก่อนเขียน

**ชุดย่อย F3 — Return**
- `return` ที่ไม่มีค่าหมายถึงหยุดฟังก์ชันทันทีใน callback เมื่อ `battle_is_over`
- `return result` ส่งค่ากลับให้ผู้เรียก ต่างจากฟังก์ชัน `-> void`
- ฝึกแบบไม่แก้ code เกมก่อน:

```gdscript
func safe_damage(base_damage: int, reduction: int) -> int:
    var result: int = base_damage - reduction
    if result < 1:
        result = 1
    return result
```

**Test ที่ผู้เรียนต้องทำนายก่อน:** `safe_damage(5, 2)` ได้ 3; `safe_damage(2, 5)` ได้ 1; `safe_damage(4, 0)` ได้ 4. อธิบายว่า minimum 1 นี้เป็น **กฎสมมติเพื่อฝึก** ไม่ใช่ข้อกำหนด combat ถาวร

**ชุดย่อย F4 — Scope & responsibility**
- `var damage` ภายใน `_enemy_turn()` ไม่ใช่ `player_hp` ที่เก็บเป็น member ของ script
- แยกฟังก์ชัน `calculate` (คืนข้อมูล), `apply` (เปลี่ยน HP), `update_ui` (แสดงข้อความ); ยังไม่ต้อง refactor script จริง
- ตรวจความเข้าใจ: ถ้าเรียก `_update_ui()` แต่ไม่เปลี่ยน `player_hp` ตัวเลขควรเปลี่ยนไหม? ถ้าแก้ label อย่างเดียวแล้ว Restart ทำไมค่าถึงกลับได้?

**โจทย์ประเมินอิสระ:** ออกแบบฟังก์ชันสั้น ๆ รับ `hp` กับ `healing`, คืนค่า HP หลังรักษาโดยไม่เกิน maximum; อธิบายเหตุผลของ param/return; ทดลอง input ที่ขอบเขต. **ยังไม่ต้องเพิ่มปุ่ม Heal ในต้นแบบจริง**

**ผ่านเมื่อ:** อ่าน 4 signatures ได้, ไล่จุดเรียกได้, เขียน function มีพารามิเตอร์+ผลลัพธ์เอง, อธิบาย scope กับ `return` ได้, แก้ตัวเลขโจทย์ได้โดยไม่รื้อ script

## บท 03 — Node, Scene, Lifecycle, Signal

**รู้จัก:** `extends Control`, `Node2D`, `Sprite2D`, `Label`, `Button`, `@onready`, `$Path/To/Node`, `get_node()`, `_ready()`, `_process(delta)` (**ยังไม่ต้องใช้ทุก frame ถ้าไม่จำเป็น**), `signal`, `connect`.  
**งานจริง:** ไล่ว่า `attack_button.pressed.connect(_on_attack_button_pressed)` ทำให้กดปุ่มเรียกฟังก์ชันได้อย่างไร และทำไม `_update_ui()` จึงเปลี่ยน label  
**โจทย์:** ใช้ UI sandbox เล็กหรือ Node ใหม่ชั่วคราว สร้างปุ่ม Test 1 อันกดแล้ว Output มีข้อความ; ทดลอง path ผิดแล้วอ่าน debugger; **อย่าทำสัญญาณซ้ำสองทาง** (เชื่อมใน editor และ script ซ้ำโดยไม่ตั้งใจ)  
**ผ่านเมื่อ:** อธิบาย Node ownership, signal sender/receiver, และ `@onready` ที่จับ node หลังเข้า tree ได้

## บท 04 — Transform, Vector2 & M1.5B Combat Staging [ACTIVE MILESTONE]

**รู้จัก:** position vs global_position, local parent space, `Vector2(x,y)`, z_index, Sprite2D scale, Control anchors/margins, aspect/readability.  
**งานจริง:** **เริ่มด้วย Inspector ก่อนเขียน GDScript** จัด Player + NPC 3 คนให้มีหน้า–หลังแบบอ่านชัด, Enemy A อยู่บนสนามอย่างสมเหตุผล, เว้น action space, debug panel ไม่กินส่วนสำคัญ, ตรวจ viewport 1280×720  
**โจทย์ขยายเมื่อพร้อม:** ให้ครู AI อธิบายว่าทำไมการย้าย parent ทำให้ global vs local position ต่างกัน; ลองปรับตำแหน่ง node ใน sandbox/สำเนาฉากและบันทึกก่อน–หลัง  
**ห้าม:** ไม่แทรกฟีเจอร์ AI NPC, เวท, turn manager, cinematic camera หรือแอนิเมชันทั้งเกมเพื่อผ่าน M1.5B  
**ผ่านเมื่อ:** มี screenshot ก่อน/หลัง, รัน scene แล้วตัวละครไม่ทับกันผิดปกติและผู้เรียนอธิบายการวางได้

## บท 05 — Tween, Animation, await & M1.5C

**รู้จัก:** `create_tween()`, `tween_property()`, `await tween.finished`, easing/transitions เบื้องต้น, แยกตำแหน่งเริ่มกับตำแหน่งปัจจุบัน, ปิด input ขณะ action ทำงาน  
**ฝึก A:** ให้ Player ขยับเล็กน้อยไปหา Enemy แล้วกลับที่เดิม (ใน sandbox ก่อนหรือใน staging ที่ผ่านแล้ว); ทำด้วย Tween แทนการกระโดดตำแหน่ง  
**ฝึก B:** ใช้สี/scale ชั่วคราวบอกเป้าหมายถูกโจมตีและคืนค่า; ต่อไปเพิ่ม HP/log หลัง action ตาม flow ที่ตกลง  
**ทดสอบ:** attack 3 ครั้งติด, enemy ตายกลาง animation, restart ขณะ animation, target ไม่ valid, จบศึกแล้วไม่เกิด tween ค้าง  
**ผ่านเมื่อ:** อธิบาย `await` เป็นการรอเหตุการณ์ ไม่ใช่หยุดเกมทั้งเกม, แยก visual effect กับ damage calculation ได้. อย่าทำ `_process()` tween ใหม่ทุก frame

## บท 06 — Collections, Loops & M1.5D

**รู้จัก:** `Array`, `Array[Node]`, `Dictionary`, `for`, `while` เฉพาะจำเป็น, `match`, `enum`, การอ่าน key/index และ empty case  
**ฝึก:** สร้างรายชื่อ actor 4 ตัวใน sandbox; วนพิมพ์ลำดับ action; เทียบ Array ที่มีลำดับกับ Dictionary ที่เก็บข้อมูลเป็นคู่ key/value  
**โจทย์:** ผู้ร่วมทีมถูกลบ 1 คน; ลำดับแสดง action ต้องไม่ error. ทดลองทีมว่าง, ข้อมูลผิดชนิด และ duplicate actor  
**เชื่อมเกม:** M1.5D ให้ NPC visual action แยกคนและมี log ที่อ่านได้ **ยังไม่ใช่ NPC AI ที่ตัดสินเองทั้งหมด**  
**ผ่านเมื่อ:** แก้โจทย์วนรายชื่อด้วยตนเองได้และไม่ใช้ loop ไม่รู้จบ

## บท 07 — Classes, Resources & ownership

**รู้จัก:** script เป็น class, `class_name`, `extends`, `Resource`, `RefCounted`, `Node`, `@export`, typed references, instance vs shared resource, `is_instance_valid()`  
**ฝึก:** แยก model ข้อมูล actor อย่างเล็กใน sandbox (ชื่อ, max HP, current HP, defending); UI เป็นผู้แสดง ไม่ใช่แหล่งความจริงของ HP  
**ทดสอบ:** actor 2 ตัวเปลี่ยน HP แยกกัน, scene reset ไม่ทิ้ง reference ชี้ node เก่า, resource ถูก share โดยไม่ได้ตั้งใจหรือไม่  
**ผ่านเมื่อ:** อธิบาย “ข้อมูลหนึ่งชุดมีเจ้าของหนึ่งที่” และความต่างระหว่าง Node กับ Resource ได้. **อย่าทำ framework class ซับซ้อนก่อนมี actor มากพอ**

## บท 08 — Combat turn/state flow

**รู้จัก:** state diagram, `enum`, guard conditions, queue, action intent, resolve, end condition, determinism  
**ฝึก:** วาด flow ก่อน: `START → PLAYER_CHOICE → ACTION_RESOLVE → ENEMY_ACTION → CHECK_END → NEXT_TURN`; เพิ่ม NPC เพียงเท่าที่ระบบ M2 ต้องพิสูจน์  
**กรณีทดสอบ:** เลือกโจมตีเมื่อ battle over, HP ถึง 0 ก่อน enemy attack, กด action สองครั้งติด, action target หาย, Restart ระหว่างเฟส  
**ผ่านเมื่อ:** สามารถบอกว่า state อยู่ตรงไหนและเหตุใด action ถูกปฏิเสธได้; UI ไม่เป็นตัวกำหนด state หลัก

## บท 09 — Rule-based NPC decision making (M2)

**รู้จัก:** input→candidate actions→guard→score/priority→choice→reason; `RandomNumberGenerator` พร้อม seed หากใช้สุ่ม; แยก logic ออกจาก animation  
**แบบฝึก A:** actor ตัวอย่างเลือก Help เมื่อเพื่อนใกล้หมด HP และมีเงื่อนไขช่วยได้, ไม่เช่นนั้น Defend/Attack ตามสถานการณ์  
**แบบฝึก B:** ใส่ความกล้า เมตตา วินัย และ survival instinct แบบค่าต้นแบบ **ไม่ล็อก AI design ถาวร**; log ว่าเลือกเพราะอะไร  
**ทดสอบ:** เพื่อนบาดเจ็บ, ไม่มีเพื่อนบาดเจ็บ, NPC บาดเจ็บเอง, ไม่มี target, ทางเลือกไม่ถูกกฎหมาย, ทุก action ถูกปิด  
**ผ่านเมื่อ:** เห็น NPC เลือกทำเอง และผู้เรียนอธิบายเหตุผลของแต่ละการตัดสินใจได้ ไม่ใช่เพียงสุ่มคำสั่ง

## บท 10 — Guidance & trust (M3)

**รู้จัก:** state data per NPC, player input, signal to controller, requested action ≠ forced action, trust linked to **specific player character**, transparent reason log  
**แบบฝึก:** ส่งคำชี้นำ Attack ให้ NPC ที่ Compassion สูงแต่มีคนกำลัง Down; ให้ NPC มีสิทธิเห็นต่างและแจ้งเหตุผล ไม่ใช่เขียน if บังคับเชื่อฟังเสมอ  
**ทดสอบ:** trust ต่ำ/สูง, คำสั่งขัดกับความปลอดภัย, leader ตายแล้วสร้างตัวละครใหม่, log ไม่หลอกว่าทำตามเมื่อปฏิเสธ  
**ผ่านเมื่อ:** เขียน/อธิบายระบบคำแนะนำหนึ่งคำสั่งได้ด้วยตนเอง โดยไม่แปลง NPC เป็นตัวละครที่ Player คุมโดยตรง

## บท 11 — Down, help, retreat, death (M4)

**รู้จัก:** alive/down/dead states, bleed-out counter, separate combat vs persistent data, guard & event sequence, edge-case state transitions  
**ฝึก:** HP 0 → Down; Help ภายในเงื่อนไขก่อนตาย; Dead แล้ว Help แบบธรรมดาไม่ฟื้น; retreat แบบมีความเสี่ยง/ผลตามสถานการณ์  
**ทดสอบ:** Down แล้วถูกซ้ำ, ถูกช่วยทันเวลา, NPC เลือกช่วยหรือหนี, ไม่มีผู้รอด, Player ตายแล้วโลกยังดำเนิน, double-death bug  
**ผ่านเมื่อ:** สถานะไม่ขัดแย้งกันและแยก **combat rescue** จาก **future resurrection mystery** ชัด. ไม่ implement เวทชุบฟรี

## บท 12 — Persistence & safe saves (เมื่อระบบต้องจำผลจริง)

**รู้จัก:** `user://`, `FileAccess`, `JSON`, schema version, dictionaries, data validation, save/load, world vs character ownership  
**ฝึก:** sandbox เก็บ–โหลดเพียง `visited_route` กับ `death_ledger` แล้วโหลดกลับได้. **อย่าทำระบบเซฟเต็มรูปแบบก่อน M4/M5 ต้องใช้**  
**กรณีทดสอบ:** ไฟล์ยังไม่มี, JSON เสีย, version ไม่ตรง, save หลังตัวละครตาย, trust ของตัวละครใหม่ไม่รับของเดิม, ชื่อ key หาย  
**ผ่านเมื่อ:** รู้ว่าไฟล์จริงอยู่ใน user data path และมีวิธีสำรอง/กู้ โดยไม่เขียนทับ progression ในทุกกรณีผิดพลาด

## บท 13 — Journey nodes & events (M5)

**รู้จัก:** graph nodes/edges, route data, simple event selection, basic randomness, path availability, separation of UI and travel state  
**ฝึก:** แผนที่ทดสอบ **Stonegate → Route A / Route B** แต่ละเส้นมีความเสี่ยงและข่าวที่อาจไม่แน่นอน; เปิด event pool แรกเพียง 3–5 เรื่อง  
**ทดสอบ:** route ถูกปิด, ผู้เล่นถอยกลับ, event ซ้ำ, ข่าวเก่าไม่ใช่ข้อมูลจริง, ไม่มีเสบียง, ตัวละครในปาร์ตี้ไม่ยอมเสี่ยง  
**ผ่านเมื่อ:** Player เลือกทางได้และเหตุผล NPC แสดงได้; ไม่ต้องทำ open world หรือ network C1–C8 จริง

## บท 14 — Town UI, quest & party (M6)

**รู้จัก:** `Control` layout, containers, signals, data binding แบบง่าย, scene transitions, quest states, recruitment UI, inventory แบบจำกัด  
**ฝึก:** เมือง Stonegate หน้าจอเดียว/เมนูง่าย ๆ มี รับงาน, ชักชวน NPC, เตรียมเสบียง, รักษา, เลือก Route A/B  
**กรณีทดสอบ:** ปาร์ตี้เต็ม 3 NPC, NPC ปฏิเสธเข้าร่วม, quest accepted/completed, ไม่สามารถรับรางวัลซ้ำ, กลับเมืองหลังล้มเหลว, โลจิสติกส์พื้นฐานไม่ softlock  
**ผ่านเมื่อ:** เมือง→ทาง→เหตุการณ์→กลับเมืองวนลูปได้ และไม่มี walkable town ที่ต้องสร้างเพิ่ม

## บท 15 — Vertical Slice integration (M7)

**ขอบเขตเดิม ห้ามขยายเอง:** 1 Town, 6 recruitable NPC candidates, 3 Quests, 2 Routes, 8–10 events, 4 enemy archetypes รวมระบบต่อสู้และความทรงจำที่จำเป็น  
**แบบฝึกเชิงวิศวกรรม:** รวมระบบแบบ **ครั้งละส่วน**, แยก state/model/UI, จัด main menu/load-safe, ติดตาม bugs, เขียน test checklist โดยเน้น game loop  
**End-to-end tests:** รับงาน→ร่วมทีม→ออกทาง A/B→เลือก event→combat→Down/Help/Retreat→กลับเมือง→save/load→ตรวจข่าว/ความไว้ใจ/การตาย; test เล่นซ้ำ, input ผิด, แพ้ และกดปุ่มรัว  
**ผ่านเมื่อ:** ผู้เรียนสามารถอธิบายลำดับการทำงานข้ามอย่างน้อย 3 scripts และแก้ bug ที่เจอจริงได้โดยไม่ให้ AI เดาตอบล้วน ๆ. **อย่าเรียกว่า “เสร็จ M7” จนมีผลรันและ playtest จริง**

## บท 16 — Rare item Resonance [OPTIONAL, NOT CURRENT]

เรียน `Resource`, enum Ready/Spent, target validation, signal feedback และเงื่อนไขการใช้เฉพาะเมื่อ M4 พร้อมแล้ว หรือเลื่อนไปหลัง M7  
**ต้นแบบที่อนุญาตให้ลอง:** Pulse Pendant 1 ชิ้นช่วย Alive/Down ใน encounter แบบมีต้นทุน/ครั้งเดียว; **ไม่คืน Dead**  
**ห้าม:** ระบบเวทหลายสาย, เหมือง, craft economy, Full Starstone skill tree ใน M1.5B

---

# 3. ตัวอย่างชั่วโมงเรียนหนึ่งครั้ง (ไม่ใช่ตารางเวลาบังคับ)

**รอบสั้น 25–40 นาที**
1. 3 นาที: บอกสถานะล่าสุดและงานที่กำลังจะเรียน
2. 5–8 นาที: ครูถาม 1–2 คำถามวัดพื้นฐานและอธิบาย syntax ที่จำเป็น
3. 10–20 นาที: ผู้เรียนแก้โจทย์เล็กเองใน sandbox หรือฉากจริง
4. 5 นาที: รัน, ดู Output/Debugger, อธิบายผลและ error
5. 3 นาที: บันทึกว่าเรียนถึงไหน; commit เฉพาะเมื่อผลทดสอบมั่นคง

**รอบยาว 60–90 นาที** แบ่งออกเป็น 2–3 micro-lessons; แต่ละอันจบด้วยการรัน/ทวนเหตุผล แล้วหยุดเมื่อเริ่มแก้แบบเดาสุ่ม. พักได้ทุกเมื่อ; ไม่ต้องฝืนเพื่อให้ตรงแผนรายสัปดาห์

### เงื่อนไขให้ AI เพิ่มความยาก
- ต้องตอบโจทย์เดิมได้เองอย่างน้อย 2 กรณี
- ดัดแปลงพารามิเตอร์แล้วทำนายผลได้
- อธิบาย error สำคัญได้หนึ่งกรณี
- ยังอยากเรียนต่อ; ไม่เปลี่ยนเป็นการให้ AI ทำงานแทนเมื่อเหนื่อย

---

# 4. แบบทดสอบตั้งต้นให้ AI ใช้ก่อนบท FUNCTION

**ไม่ใช่ข้อสอบเพื่อให้คะแนนผู้เรียน; ใช้หาช่องว่างความเข้าใจ โดยถามทีละข้อและหยุดเมื่อพบจุดต้องฝึก**

1. อธิบายด้วยภาษาตนเองว่า `var hp: int = 30` เก็บอะไร
2. ถ้า `hp -= 5` สองครั้งจะเหลือเท่าไร และทำไม
3. `if battle_is_over: return` ป้องกันอะไร
4. `func _ready() -> void:` ถูกเรียกโดยใคร
5. `func _add_log(message: String) -> void:` รับอะไรและคืนอะไร
6. `_add_log("Hello")` ต่างจากการประกาศฟังก์ชันอย่างไร
7. เมื่อกด Attack แล้ว function ไหนใน script เดิมทำงานต่อเป็นลำดับคร่าว ๆ
8. `var damage: int` ที่อยู่ใน `_enemy_turn()` ใช้ได้จากทุก function หรือไม่
9. ทำไมจึงไม่เปลี่ยน `Label.text` เป็นวิธีเก็บ HP หลัก
10. หากต้องทำให้ความเสียหายต่ำสุด 1 ต้องทดสอบตัวเลขอะไรบ้าง

**หลักการประเมิน:** ไม่รู้ไม่เป็นไร; ครูต้องไม่บอกว่า “พื้นฐานผ่านหมดแล้ว” เพราะตอบได้บางข้อ. อย่าให้เฉลยครบในทันทีถ้าผู้เรียนยังคิดอยู่

---

# 5. การทดสอบและ Debugging ที่ต้องใช้ทุก Milestone

## 5.1 วงจรค้นบั๊ก
1. เขียน **Expected** และ **Actual** ให้ชัด
2. Reproduce เป็นขั้นตอนสั้น ๆ ที่ทำซ้ำได้
3. อ่าน error กับ stack trace **บรรทัดแรกที่เป็นของโปรเจกต์**
4. ใช้ breakpoint/step over/step into และดูค่า variables; print ชั่วคราวถ้าจำเป็น
5. ตั้งสมมติฐานทีละหนึ่งข้อ; แก้สิ่งเดียวแล้วรันทดสอบเดิม
6. ตรวจ regressions (Attack/Defend/Restart ยังคงใช้ได้หรือไม่)
7. ลบ log Debug ที่รก, ตรวจ `git diff`, commit พร้อมบอกผลจริง

## 5.2 ตัวอย่าง edge-case suite ที่ควรเก็บ
- HP = 0, HP ติดลบ, HP มากกว่า Max
- กด action เมื่อศึกจบ, กดปุ่มถี่, restart ระหว่าง action
- ไม่มี target/target ตาย/target ออกจาก scene
- NPC ไม่มีคำสั่งที่ทำได้ตามเงื่อนไข
- Damage/Heal มีขอบเขตผิดปกติ
- ฉากถูกลบ แต่ signal/Tween ยังทำงาน
- Save ไม่มี/Save เสีย/Save version เปลี่ยน
- เปลี่ยนผู้เล่นหลัง permadeath แล้ว **Trust** ไม่ถูกย้ายผิดตัว

## 5.3 ทำ Git ให้เป็นนิสัย
- เช็ก branch และ `git status` ก่อนเริ่ม; หลีกเลี่ยงแก้บน branch หลักโดยไม่ได้ตั้งใจ
- ชื่อ commit ตัวอย่าง: `learn: practice typed damage function`, `combat: stage party positions`, `combat: animate basic attack feedback`
- 1 commit = งานเล็กที่ตรวจเหตุผลได้; ไม่รวมเอกสารโลก, asset ปริมาณมาก, refactor และบทเรียน GDScript ใน commit เดียว
- ก่อนสลับ AI ให้บันทึก SHA ล่าสุดที่ผ่านการทดสอบ, สิ่งที่ยังไม่ผ่าน และ branch ที่ทำอยู่
- หาก AI สั่ง `git reset --hard`, force-push, ลบ scene หรือเปลี่ยนเวอร์ชัน Godot ให้หยุดและตรวจผลกระทบก่อนเสมอ

---

# 6. บันทึกความก้าวหน้าถาวร: เก็บสั้นและตรวจสอบได้

**Source of truth สำหรับสถานะเรียนล่าสุด:** หัวข้อ 4.1 ใน [docs/WORKFLOW.md](../docs/WORKFLOW.md). คู่มือนี้เป็น **แผนหลักสูตรที่คงรูป**; อย่าเปลี่ยนข้อความยาวทุกบทเรียน ให้แก้เพียงบันทึกสั้น ๆ หลังจบบท

| วันที่ | บท/เรื่อง | สถานะ | สิ่งที่ทำเอง | หลักฐานรัน/Commit | ยังติด / ต่อไป |
|---|---|---|---|---|---|
| 2026-10-10 | GDScript: `function` | **[SEEN / REPORTED]** | ผู้เรียนรายงานว่าเรียนมาถึงแล้ว | ยังไม่ได้ประเมินด้วยโจทย์ | F1→F4 ในบท 02 |
| _(เติม)_ | _(เติม)_ | [NEW/SEEN/PRACTICED/UNDERSTOOD/BUILT] | _(ตัวอย่าง)_ | _(Git SHA/ผลจริง)_ | _(หนึ่งหัวข้อ)_ |

**แบบฟอร์ม 5 บรรทัดที่ส่งให้ AI ใหม่ครั้งถัดไป:**

```text
หัวข้อที่เพิ่งเรียน:
ผมเขียนเองและทดสอบแล้ว:
ผมอธิบายได้ว่า:
ผมยังติดตรง:
Branch / Commit / ไฟล์ที่เกี่ยวข้อง:
```

**ไม่ต้องทำ log ประจำวันในไฟล์ใหม่เพิ่มไม่สิ้นสุด**; หากเอกสารยาว ให้เหลือ 3–5 แถวล่าสุด + milestone ผ่านแล้ว โดยประวัติละเอียดมีใน Git

---

# 7. Prompt สำหรับใช้กับ AI ใดก็ได้ (คัดลอกและส่งได้ทันที)

## 7.1 Initial tutor handoff — เริ่มคุยกับ AI ใหม่

```text
คุณคือครู GDScript/Godot 4.x และผู้ตรวจงานเกม Wanderer ไม่ใช่โปรแกรมเมอร์ที่เขียนทุกอย่างแทนผม

โปรเจกต์ GitHub: https://github.com/shanwinder/wanderer
คู่มือเรียน: learning/GDSCRIPT_WANDERER_SELF_STUDY.md
กติกาเกม: docs/GAME.md
สถานะ Milestone และการเรียน: docs/WORKFLOW.md
เนื้อเรื่อง (มี spoiler): docs/WORLD.md — อ่านเมื่อเกี่ยวข้องเท่านั้น

สถานะที่ผมแจ้งล่าสุด: ผมเรียน GDScript มาถึงเรื่อง function (func)
อย่าเหมาว่าผมคล่อง parameter, return, var, if, loop, array, signal หรือ class; ขอทดสอบทีละน้อย
งานพัฒนาเกมถัดไปคือ M1.5B Combat Staging; ยังไม่ต้องสร้าง AI NPC หรือระบบ magic
โค้ดเดิมสำคัญ: scripts/combat/combat_prototype.gd
ฉากเดิม: scenes/combat/combat_prototype.tscn

กติกาการสอน:
1) ตรวจเวอร์ชัน Godot จริงก่อนใช้ API ที่อาจต่างรุ่น
2) สอนสั้น ๆ แล้วให้ผมเขียนเองทีละ 1 กิจกรรม
3) เชื่อม GDScript ทุกบทกับปัญหาเล็กของ Wanderer
4) ถ้าผมทำผิด ให้ถามวิธีคิด/ชี้ตำแหน่งผิดก่อนให้เฉลย
5) อย่าส่งโค้ดสำเร็จทั้งไฟล์หรือเปลี่ยน milestone โดยพลการ
6) หลังทดลอง ให้ช่วยผมทำนายผล ทดสอบ edge cases และสรุปสิ่งที่เข้าใจ
7) อัปเดต docs/WORKFLOW.md หัวข้อ GDScript progress เมื่อผมยืนยันว่าฝึกแล้ว; ไม่สร้างไฟล์บันทึกใหม่
8) ใช้ Git เฉพาะงานเล็กที่ผ่านการทดสอบแล้ว; อย่า merge/force push โดยไม่ขออนุญาต
9) ห้ามอ้างว่า design docs เป็นโค้ดเกมที่เสร็จแล้ว
10) ถ้าคุณเข้า GitHub ไม่ได้ ให้ขอผมส่งเฉพาะ script/section ที่กำลังเรียน

เริ่มจากตรวจความเข้าใจ function ใน _ready(), _add_log() และ _end_battle()
ถามผม 1 คำถามก่อน อย่าเฉลย/แก้ code ทั้งหมดทันที
```

## 7.2 Prompt เมื่ออยากให้ AI ช่วย debug

```text
ช่วยเป็นครู Debugging สำหรับ Godot/GDScript 4.x โดยไม่แก้ให้ทั้งไฟล์
Milestone: [เติม]
ไฟล์/บรรทัด: [เติม]
สิ่งที่คาดว่าเกิด: [เติม]
สิ่งที่เกิดจริง: [เติม]
Error เต็ม: [วาง]
โค้ดรอบจุดนั้น: [วาง]
สิ่งที่ผมลอง: [เติม]
ขอ 1) อธิบายความเป็นไปได้ 2) ให้ตรวจทีละขั้น 3) ถามผมให้คาดผล 4) ค่อยให้ตัวอย่างโค้ดสั้นเมื่อจำเป็น
```

## 7.3 Prompt จบบท / Handoff

```text
สรุปบทเรียน Wanderer ครั้งนี้แบบไม่เกิน 12 บรรทัด:
- ผมทำอะไรด้วยตัวเองจริง
- syntax และแนวคิดที่ผมอธิบายได้ / ยังไม่แน่ใจ
- ผลทดสอบจริง (อย่าเดาว่าผ่าน)
- Code/Scene/Commit ที่เปลี่ยน
- Edge case ที่ทดสอบและยังไม่ได้ทดสอบ
- งานเล็กบทถัดไปเพียงงานเดียว
ช่วยร่างบันทึกหนึ่งแถวสำหรับ docs/WORKFLOW.md แต่ไม่ทำเครื่องหมาย UNDERSTOOD หากผมยังอธิบายเองไม่ได้
```

---

# 8. Checklist ก่อนย้ายครูหรือเปลี่ยน AI

- [ ] มีลิงก์ repo และ **branch** ที่ใช้งานจริง
- [ ] ส่ง `docs/WORKFLOW.md` เฉพาะ §4.1 และ Milestone ปัจจุบัน
- [ ] ส่ง `scripts/combat/combat_prototype.gd` เฉพาะส่วนที่กำลังเรียน/ไฟล์เต็มเมื่อจำเป็น
- [ ] ยืนยัน Godot executable/version จริง; ไม่เชื่อแต่ข้อความใน project.godot
- [ ] มี last passing commit และข้อความ error ล่าสุด
- [ ] ระบุสถานะความรู้ [SEEN/PRACTICED/UNDERSTOOD] ที่ตรงความจริง
- [ ] ตกลงโหมด Guided Steps, ห้ามให้ AI ทำทั้งระบบโดยไม่ขอ
- [ ] ก่อนสร้างฟีเจอร์ใหม่ ตรวจว่าตรง M1.5B/M1.5C/... ใน WORKFLOW
- [ ] ถ้าจะปรับหลักสูตรครั้งใหญ่ ให้แก้ **ไฟล์นี้ในที่เดิม** ไม่แตกเป็นหลายเวอร์ชัน

---

# 9. แหล่งอ้างอิงฟรี (Godot Official Docs)

ใช้เว็บทางการ และเลือกเอกสารรุ่นตรงกับ Godot ที่ติดตั้งจริง (หน้า `latest` อาจเป็นรุ่นพัฒนา ไม่ตรง API ที่มี)

1. **Step-by-step fundamentals:** https://docs.godotengine.org/en/stable/getting_started/step_by_step/
2. **GDScript syntax & functions:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
3. **Static typing:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
4. **Signals:** https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
5. **Godot debugging:** https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html
6. **Data and saving:** https://docs.godotengine.org/en/stable/tutorials/io/
7. **GDScript style guide:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

**หลักปิดท้าย:** ไม่ต้องเชี่ยวชาญทุก feature ของ GDScript ก่อนสร้างเกม; ให้เกมเป็นโจทย์จริงของการเรียน และให้การเรียนทำให้ผู้สร้างแก้เกมด้วยตัวเองได้มากขึ้นทุกครั้ง
