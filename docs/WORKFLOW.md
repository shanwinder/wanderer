# WANDERER — Development & Learning Workflow

**Current plan, 10 Oct 2026.** Core rules: [GAME.md](GAME.md). World design: [WORLD.md](WORLD.md). This is the single source of truth for current development priorities; proposed content is not implemented content.

## 1. Status

Previous development notes report:
- **M0 Project Setup** complete; **M1 Basic Combat** basic phase complete.
- **M1.5A Visual Combat Test 1** passed: Player + 3 NPC sprites + Enemy A shown, baseline integer scale ×4, art and runtime sprites separated.
- **Next task: M1.5B Combat Staging.** M1.5C/D and M2–M7 are not reported finished. This cleanup did not rerun Godot, so the entries above are reports from prior development notes, not newly verified runtime results.

Active files: `res://scenes/combat/combat_prototype.tscn`, `res://scripts/combat/combat_prototype.gd`.

## 2. Visual Combat 1.5

| Step | Do | Acceptance |
|---|---|---|
| **M1.5B — NEXT** | Reposition Party with depth and room for actions; stage Enemy naturally; ground/contact shadows if helpful; shrink debug UI; test at **1280×720** | No flat four-person lineup, readable front/back, clear Player and targets, central action space |
| M1.5C | Add active indicator, lunge/step, hit flash, recoil, floating damage, HP change, return, enemy action, using Tween/placeholder sprites | Motion and result are readable; no sluggish pacing |
| M1.5D | Show deterministic NPC actions one by one, test action focus and pacing | Player stays central; NPC actions read as meaningful; informs future turn-system choice |

**First hands-on task (M1.5B-01):** inspect `Node2D`/`Sprite2D`/`Control` positions and transform spaces; adjust existing character positions in Godot Inspector; run scene at 1280×720; compare before/after; commit only an understood improvement. Do **not** start full NPC AI, Starstone, quests, new towns or final animation sets here.

## 3. Roadmap after 1.5

- **M2 — Party/NPC AI:** NPC chooses basic actions and can show understandable reasons.
- **M3 — Guidance:** Player suggests, NPC may obey/refuse based on trust/personality/risk.
- **M4 — Down/Help/Death/Retreat:** bleeding, rescue, retreat, permanent loss, no softlocks.
- **M4.R [OPTIONAL]:** after M4 (or postpone until after M7), one Pulse Pendant: equipped, Ready→Spent after helping Alive/Down, no Dead revival; test invalid targets and autonomous NPC decisions. No full magic crafting.
- **M5 — Journey:** node-based travel and 3–5 initial events; risk, food, NPC viewpoints.
- **M6 — Town Loop:** one menu/UI town for jobs, recruiting, rest, equipment and routes.
- **M7 — Vertical Slice:** **one Stonegate hub; six recruitable NPC candidates; three quests; two routes; 8–10 events; four enemy archetypes** integrated with combat and persistence. Other world regions remain lore only.

All features beyond those implemented are plans; don't claim tests passed until running them.

## 4. Learning-first contract

This project is meant to teach the developer Godot through hands-on work; AI is **coach and reviewer by default**, not autopilot implementing everything.

**Default help Level 2 — Guided Steps.** Level 1 = hint; Level 2 = small explained steps; Level 3 = short example code/node tree to adapt; Level 4 = direct file edit **only on explicit request or a justified technical blocker**, after explaining.

**Every task:** Goal → Concept → Do → Observe → Explain → Adjust → Commit.

- Developer normally handles node positions/anchors, imported assets, signals, Tween/AnimationPlayer, GDScript and running scenes.
- AI may review repository/code/diffs, clarify design, write docs, explain errors and propose tests without taking away learning.
- Developer checks visual result/errors and explains what each new part does before committing.
- Keep Git commits small; use branches for risky experiments and examine diffs before merge.
- A feature is “learned” only if the developer understands its function, reasons, tunable values, failure cases and recovery.

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

**Next playable work:** M1.5B-01 — learn and adjust combat Party staging directly in Godot.
