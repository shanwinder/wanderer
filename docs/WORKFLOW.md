# WANDERER — Development & Learning Workflow

**Current plan, 10 Oct 2026.** Core rules: [GAME.md](GAME.md). World design: [WORLD.md](WORLD.md). This is the single source of truth for current development priorities; proposed content is not implemented content.

## 1. Status

Previous development notes report:
- **M0 Project Setup** complete; **M1 Basic Combat** basic phase complete.
- **M1.5A Visual Combat Test 1** passed: Player + 3 NPC sprites + Enemy A shown, baseline integer scale ×4, art and runtime sprites separated.
- **Next task: M1.5B Combat Staging.** M1.5C/D and M2–M7 are not reported finished. This cleanup did not rerun Godot, so the entries above are reports from prior development notes, not newly verified runtime results.

Active files: `res://scenes/combat/combat_prototype.tscn`, `res://scripts/combat/combat_prototype.gd`.

## 2. เหตุผลของลำดับใหม่ [APPROVED DIRECTION — 11 Oct 2026]

**Combat-first ยังถูกต้อง**: เริ่มจากฉากต่อสู้เพื่อพิสูจน์ว่าเกมอ่านง่ายและน่าเล่น ไม่ทิ้งงาน M1.5 ที่ลงทุนแล้ว. แต่ Wanderer มีจุดเสี่ยงเชิงความสนุกมากกว่าการสร้าง Inventory: **NPC มีสิทธิเลือกเองอาจกลายเป็นเรื่องสนุกหรือสร้างความหงุดหงิด** ต้องพิสูจน์ด้วยสถานการณ์เล็กก่อนลงทุนเต็มรูปแบบ

**แนวทางใหม่ = Risk-first + Dependency-aware.** ลำดับความเสี่ยง: (1) Combat staging/action readable → (2) NPC autonomy proof → (3) ระบบข้อมูลและ inventory/equipment ที่หลายระบบต้องใช้ร่วมกัน → (4) party/guidance/progression/death → (5) เงิน เสบียง การเดินทาง/เมือง → (6) ทดสอบการเล่นและตลาด. **M2A** ใช้ข้อมูล Actor ขั้นต่ำเพียงพอสำหรับต้นแบบ NPC; **M2B** จึงออกแบบโครง Actor/Item/Inventory ที่นำกลับใช้ได้ เพื่อหลีกเลี่ยงการทำ data model ขนาดใหญ่ก่อนรู้ว่าการเล่นหลักสนุกหรือไม่

**สี่เสาหลักที่อนุมัติ:** Combat, NPC Autonomy, Management & Survival, Character Progression ([GAME.md](GAME.md)). ผู้เล่นบริหารตัวละครและปาร์ตี้ รวมฐานพัก/คลัง **แต่ไม่อัปเกรดสิ่งปลูกสร้าง**; เงิน เสบียง น้ำหนัก ความทนทานส่งผลต่อการอยู่รอด; มี Weapon Mastery กับ Profession Unlock. **Skill Tree implementation [OPEN]**, ทดลอง Hybrid แบบเล็กก่อนเลือกจะอิงอาวุธหรืออาชีพเป็นหลัก

### 2.1 งานต่อทันที: Visual Combat 1.5 (ลำดับเดิมคงไว้)

| ขั้น | งาน/บทเรียน | ตรวจว่าผ่านจริงเมื่อ |
|---|---|---|
| **M1.5B — NEXT** | Party/Enemy staging แบบ side-view front/back, action space, shadows, debug UI; **Inspector ก่อน GDScript**, ลองที่ 1280×720 | ตัวละครไม่เรียงแบนหรือทับกัน, รู้ว่า Player อยู่ไหน, กด Attack/Defend/Restart ยังทำงาน |
| M1.5C | Tween/AnimationPlayer สำหรับ lunge, hit flash, recoil, damage UI, return position | feedback อ่านได้, ไม่ทำให้ input/scene ค้าง, จัดการกรณี enemy ตายกลาง animation |
| M1.5D | แสดง Action ของ NPC ทีละตัวจาก scripted/deterministic order **ไม่ใช่ AI decision system ที่เสร็จแล้ว** | Player ยังคงเป็นจุดสนใจ และ NPC action มีภาพ/ข้อความอ่านง่าย |

**M1.5B-01:** เปิด \`res://scenes/combat/combat_prototype.tscn\` ใน Godot → สำรวจ \`Node2D\`/\`Sprite2D\`/\`Control\` และ parent/local/global position → ขยับตำแหน่งใน Inspector → รันดูจริงและเปรียบเทียบ screenshot → commit เมื่อผลผ่าน. ยังไม่สร้างระบบไอเทมหรือ Skill Tree ระหว่างจัดฉาก

## 3. Roadmap ฉบับปรับโครงสร้าง (แผนสำหรับลงมือ ไม่ใช่ฟีเจอร์ที่เสร็จแล้ว)

**Notation:** [LOCKED INTENT] สิ่งที่ผู้สร้างยืนยัน; [PROPOSED IMPLEMENTATION] วิธี/จำนวนตัวอย่างเพื่อพิสูจน์; [OPEN] สูตรจริง/สมดุล/หน้าตา UI; [DEFERRED] หลัง demo/release.

| Milestone | Proof to build | วิธีประเมินสำเร็จ / ความรู้ GDScript ที่ต้องฝึก |
|---|---|---|
| **M2A — NPC Autonomy Proof** | Player + **NPC 1** + Enemy 1; NPC เลือก Attack/Defend/Help จากเหตุการณ์และอธิบายเหตุผล แยกการตัดสินใจจาก animation | สถานการณ์เพื่อนเจ็บ/ผู้เล่นเสี่ยง/ไม่มี target ให้ผลเข้าใจได้; \`func\`, \`if\`, basic Actor state |
| **M2B — Shared Data Foundation** | Actor/Stats/Item/Equipment/Inventory แบบเล็ก **แยกจาก UI**, อิง HP/role/action data ร่วมกัน; ยังไม่ทำ catalogue | Actor 2 ตัวมีข้อมูลไม่ปน, item ส่งผลต่อ action จริง; class/Resource, typed data, ownership |
| **M2C — Full Party Combat** | Player + NPC สูงสุด 3 คน, ลำดับ action และเลือกเป้าหมาย, ใช้ item/Stats ขั้นต่ำจาก M2B | สมาชิกเพิ่ม/ตาย/ไม่มี target ไม่ทำลาย turn; Array, loops, states |
| **M3A — Guidance & Trust** | คำชี้นำเป็นข้อเสนอ ไม่บังคับ; NPC รับ/ปฏิเสธและมีเหตุผล; Trust ผูกเฉพาะ Player character | กรณีเหตุผลสวนคำชี้นำ/Trust ต่างกันผ่าน; signals, decisions, logging |
| **M3B — Inventory & Equipment** | กระเป๋า น้ำหนัก โอน/แบ่ง/ทิ้งของ สวม/ถอดอุปกรณ์ ความทนทานและซ่อมพื้นฐาน; ผูก Combat จริง | ของเกินน้ำหนัก/สวมผิดชนิด/ซ่อมไม่ได้/ไอเทมสูญหลังตาย; data UI separation, validation |
| **M3C — Weapon Mastery & Profession Unlock** | ทดลองอย่างน้อยหนึ่งสายอาวุธ + หนึ่งอาชีพ/เงื่อนไขปลด; **Hybrid เป็น prototype ไม่ใช่คำตอบ Skill Tree ถาวร** | ใช้ทักษะจริง→ได้ความก้าวหน้า/ปลดตามเกณฑ์; data-driven conditions, progression tests |
| **M4 — Injury, Down, Help, Retreat & Permadeath** | Down/bleed-out, ช่วยเหลือ, บาดเจ็บ, การถอย, Player/NPC death, ของและ Trust ที่สูญ; ความก้าวหน้าระดับโลกคงอยู่ | death ไม่ทำ save เสีย/softlock, NPC ตัดสินใจช่วยเองได้; enum/state, serialization guards |
| **M4.5 — Money, Loot, Shop & Storage Foundations** | เงินรางวัล ไอเทมดรอป/ของพบ ซื้อ–ขาย ซ่อม–รักษา ค่าที่พัก คลังส่วนตัวอย่างง่าย; **ไม่ทำ market simulator** | เงินไม่พอ, loot เกินน้ำหนัก, ขายแล้วจำนวนถูก, รับรางวัลซ้ำไม่ได้; transactions, Dictionaries, state/save |
| **M5 — Journey & Survival Resources** | Node Route A/B, อาหาร/น้ำ/ยา/น้ำหนัก/ความเสี่ยง, เดินทางและพัก, เริ่มเหตุการณ์ **3–5** เรื่อง, NPC มีความเห็น | ขาดเสบียง/เปลี่ยนทาง/ถอย/ไม่อยากร่วมทางทำให้ผลต่างจริง; graph, events, resource usage |
| **M6 — Town + Personal Rest Base Loop** | Stonegate เมืองเดียวผ่าน Town UI: quest/recruit/supply/trade/heal/repair; **ฐานพัก/คลังส่วนตัว** สำหรับจัดทีม/เก็บของ/พักฟื้น; **ไม่มี base building** | เมือง→ฐาน→ทาง→กลับเมืองวนได้, หาย/บาดเจ็บ/เสียเงิน/ฝากของถูกต้อง; UI, signals, quest states |
| **M7 — Integrated Vertical Slice** | **1 Stonegate, ผู้ร่วมทีมเสนอ 6 คน, 3 quests, 2 routes, events 8–10, enemy archetypes 4**; รวม Combat, Management, Progression, Death, Journey, Town, Save/Load | playthrough จากรับงาน→เตรียม→เดินทาง→เหตุการณ์→ต่อสู้→กลับ→บันทึกผล, มี failure path ไม่ softlock |
| **M8 — External Demo & Market Validation** | Build ที่คนไม่เคยเล่นทดสอบได้, onboarding ของ NPC autonomy, difficulty/retention feedback, คลิปสื่อจุดเด่น, storefront plan | บันทึกจุดที่ผู้เล่นงง การเลือกกลับมาเล่นต่อ, debug/crash issues; ไม่อ้างยอดขายจากการทดสอบภายใน |
| **M9 — Content Production** | เพิ่มศัตรู อาวุธ อาชีพ/ทักษะ/เควส/เมืองตามระบบที่ผ่าน playtest; บาลานซ์น้ำหนัก/เงิน/ความทนทาน | เพิ่มข้อมูลได้โดยไม่ต้องแก้โค้ดหลายที่, ตรวจลูปการเล่นซ้ำ |
| **M10 — Polish & Release** | Localization อังกฤษ/ไทย, UI accessibility, sound/settings, save migration, performance, regression, export, Steam readiness | Release checklist ผ่านจริง; ทดลอง clean install/load/แพ้/ชนะ/กดซ้ำ/เปลี่ยนภาษา |

**M4.R [OPTIONAL / DEFERRED]** หลัง M4 มั่นคงหรือหลัง M7: ทดลอง **Pulse Pendant** ชิ้นเดียว (Ready→Spent, ช่วย Alive/Down ไม่ชุบ Dead); อาจเลื่อนออกหากรบกวน core. ห้ามแทรกใน M1.5B หรือทำเหมือง/ระบบเวทเต็ม

### 3.1 Risk gates ก่อนลงทุนทำ content เพิ่ม

- **Gate A (หลัง M2A):** NPC เลือกช่วยคนเจ็บแทนคำชี้นำ/การโจมตีด้วยเหตุผลที่ผู้เล่นเข้าใจ; มีอย่างน้อย 1 scenario ให้ลองซ้ำ **ไม่ใช่เพียงสุ่ม/ไม่เชื่อฟังอย่างไร้เหตุผล**. ถ้าไม่สนุก ให้แก้ autonomy ก่อนระบบ Inventory ขนาดใหญ่
- **Gate B (หลัง M4.5):** ในภารกิจทดสอบหนึ่งงาน ผู้เล่นต้องเลือกจริงระหว่างการซ่อม/ยา/น้ำหนัก/เงิน/การช่วยคนเจ็บ; ผลลัพธ์ต่างกันและ UI สื่อข้อตัดสินใจชัด. ถ้าไม่ต่าง ให้แก้ design ไม่เติมของ 100 ชิ้น
- **Gate C (หลัง M7):** ให้ผู้เล่นภายนอกทดลอง loop เตรียม→ผจญภัย→กลับ/ล้มเหลว; ดูความเข้าใจ NPC autonomy, การจัดการที่มีความหมาย, ความอยากเริ่มอีกครั้ง; บันทึกผลจริงก่อนเข้าสู่ content/ขาย

### 3.2 Commercial validation [NOT A REVENUE FORECAST]

เกมเทียบเคียงมีตลาดจริง เช่น *Battle Brothers*, *Wartales*, *Darkest Dungeon*, *Our Adventurer Guild*, *Wildermyth* แต่ **ไม่ได้แปลว่า Wanderer จะขายได้แน่**. ตำแหน่งทางการตลาดแบบทำงาน: **"A party-based RPG where your companions have a will of their own."** จุดที่ต้องพิสูจน์ก่อนลงทุน content คือความสนุกของการตัดสินใจ NPC + cost ของ Management. ค่าเงิน ราคาและยอดขายที่เคยยกตัวอย่างเป็น **scenario ไม่ใช่ forecast**; ไม่บรรจุยอดขาย/จำนวน wishlist เป้าหมายแบบมั่นใจโดยยังไม่มี demo. ตรวจข้อมูลตลาดปัจจุบันและกฎ Steam เมื่อถึง M8 จริง

### 3.3 รายการไม่ทำใน First Release [DEFERRED]

- บริหารหรืออัปเกรดศูนย์นักผจญภัย; Base-building และขยายสิ่งปลูกสร้าง (ฐานส่วนตัวเป็น **ที่พัก/คลัง** เท่านั้น)
- Economy simulator ของ 7 ภูมิภาค, จ้างแรงงาน/คุมเมือง, game-wide procedural world, multiplayer, ระบบคราฟต์ใหญ่, Starstone shop ตามตลาด
- Skill Tree หลายร้อยจุดหรืออาชีพหลายสิบสายก่อนทดสอบ 1+1 prototype; เดินสำรวจทุกเมืองแบบ open-world
- ห้ามตีความว่า 7 ภูมิภาคใน WORLD.md = 7 playable towns ใน M7

## 4. Learning-first contract

This project is meant to teach the developer Godot through hands-on work; AI is **coach and reviewer by default**, not autopilot implementing everything.

**Default help Level 2 — Guided Steps.** Level 1 = hint; Level 2 = small explained steps; Level 3 = short example code/node tree to adapt; Level 4 = direct file edit **only on explicit request or a justified technical blocker**, after explaining.

**Every task:** Goal → Concept → Do → Observe → Explain → Adjust → Commit.

- Developer normally handles node positions/anchors, imported assets, signals, Tween/AnimationPlayer, GDScript and running scenes.
- AI may review repository/code/diffs, clarify design, write docs, explain errors and propose tests without taking away learning.
- Developer checks visual result/errors and explains what each new part does before committing.
- Keep Git commits small; use branches for risky experiments and examine diffs before merge.
- A feature is “learned” only if the developer understands its function, reasons, tunable values, failure cases and recovery.

**คู่มือเรียนฉบับละเอียดสำหรับใช้กับ AI ใดก็ได้:** [learning/GDSCRIPT_WANDERER_SELF_STUDY.md](../learning/GDSCRIPT_WANDERER_SELF_STUDY.md) — แผน 17 บท พร้อมโจทย์ Godot, เกณฑ์ผ่าน, Debugging, prompt ส่งต่อ และเช็กลิสต์; เป็นไฟล์เรียนประกอบ **ไม่ใช่ canonical game design ฉบับที่สี่**. เปิดอ่านเฉพาะบทที่กำลังฝึกเพื่อประหยัด token

### 4.1 GDScript learning checkpoint — ผู้พัฒนาเรียนถึงไหนแล้ว

**บันทึก ณ 10 ต.ค. 2026 (รายงานโดยผู้พัฒนา ไม่ใช่ผลสอบ):** ผู้พัฒนาเรียน GDScript **มาถึงเรื่องการใช้งาน `function` (`func`)** แล้ว และประสงค์จะ **เรียนภาษาไปพร้อมกับเขียน Wanderer จริง** ไม่แยกเรียนหลักสูตรยาวให้จบก่อนลงมือทำเกม

- **[REPORTED CURRENT TOPIC]** `function`: กำลังเรียนรู้การประกาศและเรียกใช้ฟังก์ชัน; ยัง **ไม่ได้ยืนยัน** ว่าคล่องเรื่อง parameters, `return`, return types หรือ scope แค่ไหน
- **[NOT YET VERIFIED]** เนื้อหาก่อนหน้านี้ เช่น ตัวแปร/ชนิดข้อมูล, `if/else`, loop, Array/Dictionary, การใช้งาน `Node` และ signal: **ห้ามสรุปว่าเรียนครบแล้ว** เพียงเพราะเปิดโค้ดเกมเดิมได้หรือพบคำสั่งเหล่านั้นใน repository
- **[LEARNING MODE]** ทุกครั้งที่งานเกมต้องใช้ syntax ใหม่ ให้สอนแนวคิดเท่าที่จำเป็น → ผู้พัฒนาเขียนเอง → รัน/สังเกต → อธิบายโค้ดและผลลัพธ์ → ปรับ → commit
- **[BOUNDARY]** โค้ดที่มีอยู่ใน GitHub หรือที่ AI ช่วยเขียนในอดีต **ไม่ใช่หลักฐานว่าเจ้าของโปรเจกต์เข้าใจ syntax ทั้งหมด**; ก่อนสั่งให้เขียนฟังก์ชันซับซ้อน ให้สำรวจความเข้าใจจากตัวอย่างเล็กที่สัมพันธ์กับงานที่กำลังทำ

**Micro-lesson ถัดไปที่เหมาะกับระดับปัจจุบัน (ยังไม่อ้างว่าเรียนผ่าน):** อ่าน `func` หนึ่งตัวที่อยู่ใน `combat_prototype.gd`, บอกให้ได้ว่า *ชื่อฟังก์ชัน/พารามิเตอร์/ส่วนคำสั่ง/จุดที่ถูกเรียก/ผลลัพธ์* คืออะไร จากนั้นลองเขียนฟังก์ชันสั้น ๆ ในงานเกมเมื่อถึงจุดที่จำเป็นจริง; ถ้าพบ `return` หรือ type annotation ให้เรียนเพิ่มจากตัวอย่างนั้นก่อนต่อขั้นถัดไป

| ช่วงพัฒนา | ความรู้ที่หยิบมาเรียนตามงานจริง | เกณฑ์สังเกตความเข้าใจ |
|---|---|---|
| **M1.5B (ปัจจุบัน)** | Scene tree, `Node2D`, `Sprite2D`, local/global position; อ่านฟังก์ชันเดิมใน script โดยยังไม่ต้องแก้โค้ด | จัดตัวละครใน Inspector ได้และอธิบายว่า script เรียกฟังก์ชันตรงไหน |
| **M1.5C** | การเขียน/เรียก `func`, parameter, `return` เมื่อจำเป็น, method calls และ Tween | สร้างการเคลื่อนไหวเล็ก ๆ ได้เองและอธิบายคำสั่งทีละบรรทัด |
| **M1.5D** | แยกฟังก์ชันสำหรับการแสดง action, เงื่อนไขพื้นฐาน, การส่งข้อมูลระหว่างฟังก์ชัน | NPC แสดง action ที่กำหนดได้โดยไม่ใช้โค้ดคัดลอกซ้ำ |
| **M2 เป็นต้นไป** | `if/match`, Arrays/Dictionaries, state, references, signals และการดีบัก **ตามลำดับความจำเป็นจริง** | ผู้พัฒนาอ่าน/แก้โค้ด AI ของ NPC ได้และบอกผลเมื่อเปลี่ยนค่าหรือเงื่อนไข |

**รูปแบบบันทึกความก้าวหน้า (สั้น ไม่สร้างไฟล์ใหม่):** หลังแต่ละบทเรียน อัปเดตบรรทัดสถานะในหัวข้อนี้ด้วย **วันที่ | หัวข้อ | ทดลองทำเองอะไร | ผลที่สังเกต/อธิบายได้ | ยังติดอะไร/หัวข้อถัดไป**. เปลี่ยนเป็น **[PRACTICED]** เมื่อผู้พัฒนาลงมือทำจริง และ **[UNDERSTOOD]** เฉพาะเมื่ออธิบายและปรับแก้เองได้ ไม่เลื่อนสถานะจากการอ่านอย่างเดียว

**หมายเหตุ:** การเรียน GDScript เป็นเป้าหมายร่วมของทุก Milestone ไม่ใช่ Milestone ใหม่ ไม่ต้องเร่งขึ้นหัวข้อขั้นสูงหรือให้ AI เขียนแทนจนผู้พัฒนาไม่ได้ฝึก

## 5. Pixel-art learning notes worth retaining

- Reference / character concept → compact guide & direct color blocking → base colors → shadow/highlight → detail cleanup → inspect at actual gameplay size. **A solid silhouette study is optional**, not mandatory.
- Octopath-like inspiration means readable stylized pixel people and coherent staging; don't claim a precise production process of another studio. Don't shrink HD art automatically as the main pixel-art method.
- **Old practice guide** (not a mandatory asset spec): canvas **64×96**, origin top-left `(0,0)`; compact character guide `x=20..43, y=16..59`, center x=32, height about 40–46 px. Horizontal anchors `y=16/26/30/36/41/45/51/55/59` broadly map to hair/chin/shoulder/chest/waist/hips/knee/boots/soles. Hair/cloak/weapons may extend outside the guide.
- Concept for one practice character: tousled dark hair, muted navy shoulder cape, lighter tunic, diagonal strap, belt, gloves, tall boots, slim sword and sheath. **Training reference, not a mandatory Player class or appearance**.
- Keep `art/` originals and `assets/sprites/` game exports separate. Avoid overly tall sprites, unnecessary dark outlines, crowded details, and art production that outruns gameplay proof.
- Small drawing breaks can restore motivation; bring relevant new art back into a running scene rather than creating dozens of unused assets.

## 6. Working rules

- Make the smallest playable/testable increment; use placeholders first and more elaborate assets when justified.
- Mark requirements **[LOCKED]**, **[PROTOTYPE]**, **[OPEN]**, **[LATER]** and never silently turn a proposal into completed code.
- Keep **only GAME.md, WORLD.md, WORKFLOW.md** as canonical design docs, plus this folder's short README index and optional SVG sketches.
- Update those files *in place*; no numbered follow-up planning docs. Obsolete versions remain in Git history only.
- For any specific task, read the relevant single file plus code/scene under change; **do not load the entire docs directory**, which wastes context.
- Public GitHub is not a private spoiler vault; restrict player-visible and shipped content per WORLD.md.

## 7. Open choices

Final combat turn model, presentation camera/real-3D depth, damage/balance formulas, NPC behavior weight, detailed magic cost, geography/reveal evidence and economic simulation remain decisions for prototype/playtest stages. None should delay M1.5B.

**Next playable work:** M1.5B-01 — เรียน Node/Inspector แล้วจัด Combat Party Staging; อย่าแทรก Inventory/Skills ก่อนขั้นพิสูจน์ NPC Autonomy

**Roadmap decision — 11 Oct 2026:** ผู้สร้างรับแผน M2A/M2B/M2C, M3A/B/C, M4, M4.5, M5–M10 ตาม §3; ยังคง M1.5B active. ฝึก GDScript ตามบทที่สัมพันธ์กับระบบใน [คู่มือเรียนแบบพกพา](../learning/GDSCRIPT_WANDERER_SELF_STUDY.md); ปรับบทตามความก้าวหน้าจริง ไม่อ้างว่าผ่าน syntax ล่วงหน้า.
