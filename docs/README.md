# Wanderer Documentation Index

เอกสารในโฟลเดอร์นี้เป็นทั้ง **บันทึกการตัดสินใจทางออกแบบ (historical design record)** และ **กฎปัจจุบัน (current guidance)** ของ Wanderer กรุณาอ่านสถานะและขอบเขตของแต่ละฉบับก่อนนำไปเขียนโค้ด

## Recommended reading order

| เอกสาร | เนื้อหา | อำนาจ/ขอบเขต |
|---|---|---|
| [01 — Game Development Plan v0.1](01_Wanderer_Game_Development_Plan_v0.1.md) | วิสัยทัศน์, โลก, gameplay loop, NPC autonomy, death, milestones | **ฐานเกมเดิม**; เก็บประวัติการออกแบบ |
| [02 — Visual Combat v0.2](02_Wanderer_Visual_Combat_Prototype_Update_v0.2.md) | Functional + visual prototype | ปรับ v0.1 เฉพาะงานภาพ/ต้นแบบ |
| [03 — Combat Presentation v0.3](03_Wanderer_Combat_Presentation_Direction_Update_v0.3.md) | Staging, depth, UI, M1.5B–D | **ล่าสุดสำหรับ presentation & active milestone** |
| [04 — Learning Workflow v0.4](04_Wanderer_Learning_Development_Workflow_v0.4.md) | ผู้พัฒนาเรียนรู้ Godot ด้วยตัวเอง; AI เป็นโค้ช | **ล่าสุดสำหรับวิธีลงมือพัฒนาเสมอ** |
| **[05 — Starstone World Lore v0.5](05_Wanderer_Starstone_World_Lore_v0.5.md)** | คืนฟ้าแตก, ดาราศิลา, การพ้องพลัง, ความหายาก, สังคม, ความตาย, ความลับโลกเก่า | **ล่าสุดสำหรับ Low-Magic/Lore**; แทนความไม่ชัดใน v0.1 §5.5 |
| **[06 — Resonance Gameplay v0.5](06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)** | กฎอุปกรณ์, NPC, ต้นทุน, MRE-1, acceptance tests, roadmap integration | **ล่าสุดสำหรับ proposed magic gameplay**; ยังไม่ implement |
| **[07 — Thailand-Region Worldbuilding v0.1](07_Wanderer_Thailand_Region_Worldbuilding_v0.1.md)** | 7 ภูมิภาคในอดีตไทย, การเปลี่ยนภูมิประเทศ, นครรัฐ/วัฒนธรรม, corridor, แนวสร้าง Atlas, Vertical Slice | **ข้อเสนอแผนที่โลก**; ยังไม่ล็อกชื่อ/พรมแดน/ภูมิประเทศ; ไม่เปลี่ยน Active Milestone |
| **[08 — Stonegate City MAP-02A v0.1](08_Wanderer_Stonegate_City_Design_MAP-02A_v0.1.md)** | เมืองนครประตูหิน: ผังเมือง เขตเมือง สภา กลุ่มอำนาจ NPC 6 คน เควส 3 เส้นทาง 2 และเกณฑ์ Vertical Slice | **ข้อเสนอ City Bible** ภายใต้ [07]; ยังไม่ implement และไม่แทน M1.5B |
| [Pixelorama Handoff](Wanderer_Pixelorama_Training_Handoff.md) | บันทึกทักษะวาดและ asset | อ้างอิงการเรียนรู้/ประวัติ |

### Conflict resolution (ต้องอ่าน)

ไม่ใช้หลักว่า “เอกสารเลขสูงสุดชนะทุกเรื่อง” แต่ให้แยก **domain of authority**:

1. **Learning-first development:** v0.4 ควบคุมการทำงาน/ระดับความช่วยเหลือจาก AI ทั้งหมด
2. **Combat presentation + active milestone:** v0.3 ควบคุม layout, staging, 1.5B–D
3. **Low-magic/world canon:** v0.5 [05] กำหนดกฎโลกเหนือธรรมชาติแทน v0.1 §5.5 เฉพาะหัวข้อนั้น
4. **Magic gameplay integration:** v0.5 [06] เสนอวิธีทำงานและ *จุดที่จะเพิ่มได้เมื่อพร้อม*; ไม่แก้สถานะ milestone เดิม
5. **Original game vision:** v0.1 ยังมีผลกับ Player control, NPC autonomy, post-post-apocalypse, quests, journeys, class progression, Permadeath และมิติอื่นนอกเหนือข้อแก้ชัดเจน
6. **Thailand-region geography & world map proposal:** [07] เพิ่มสมมติฐานแผนที่และพื้นที่เล่นที่ตั้งอยู่ในอดีตประเทศไทยภายใต้ v0.1 และ v0.5; เป็น [PROPOSED] ไม่แทน gameplay milestone หรือ canon ที่ล็อกแล้ว
7. **Stonegate City Design / MAP-02A:** [08] เพิ่มรายละเอียดเมืองและตัวละครโดยต่อยอด [07] §14; ข้อมูลใหม่ทั้งหมดเป็น [PROPOSED] และต้องอ่านควบคู่ข้อจำกัดการเล่นจาก v0.1, Starstone v0.5 และ Learning Workflow v0.4
8. สถานะ **[LOCKED — INTENT]** ใน v0.5 หมายถึงเจตนาที่ผู้สร้างระบุ; **[DESIGN BASELINE]** เป็นข้อเสนอทำงาน, **[OPEN]** ยังไม่ตัดสิน และ **[LATER]** เก็บไว้ภายหลัง

หากความขัดแย้งกระทบระบบหลัก: บันทึก decision และให้ผู้สร้างทบทวนก่อนแก้ อย่าข้ามไป implement เพราะเห็นชื่อไฟล์ v0.5

## Current direction — สิ่งที่ทำถัดไปจริง

**Visual Combat Test 1** ผ่านการทดสอบเบื้องต้น ตามบันทึก v0.3

**Milestone 1.5B — Octopath-inspired Combat Staging Pass** ยังเป็นงานถัดไป: ทดลองการจัดตำแหน่งแบบมีความลึก ไม่ใช้ flat baseline, ทำ Active Character เด่นขึ้น และรักษา readability; จากนั้น M1.5C (Attack Feel) และ M1.5D (NPC Turn Presentation)

- Side-view combat ยังเป็นแกนหลัก; ใช้แรงบันดาลใจจาก Octopath Traveler เฉพาะ staging/focus/pacing ไม่ลอกภาพ
- Turn System ยัง [OPEN] ให้ prototype ช่วยตัดสิน
- ยังไม่เพิ่ม Full NPC AI ก่อน staging และ attack feel ตามเกณฑ์แผน
- **ห้ามเริ่ม coding ระบบ Starstone/Resonance เพียงเพราะ merge เอกสาร v0.5**
- เมื่อ M2–M4 พื้นฐานสมบูรณ์ ค่อยประเมิน **M4.R optional** ทดสอบ Pulse Pendant **หนึ่งชิ้น** ตาม [06]; ถ้ารบกวน learning/roadmap เลื่อนไปหลัง Vertical Slice ได้

## Low-Magic direction v0.5

โลก Wanderer มีพลังพิเศษจริงและเป็นความรู้สาธารณะ แต่หาอุปกรณ์ใช้ได้ยาก พลังต้องมีวัสดุจากอุกกาบาตโบราณอยู่ในอาวุธ/เครื่องมือ/เครื่องประดับซึ่งผ่านการขึ้นรูปและควบคุม โดยทุกครั้งที่ใช้มีต้นทุนและความเสี่ยง

ชื่อทำงาน: **ดาราศิลา (Starstone)**, **การพ้องพลัง (Resonance)**, **คืนฟ้าแตก (The Sundering Sky)**; ชื่อและรายละเอียดเชิงกลไกส่วนมากเป็น **[DESIGN BASELINE]** และแก้ได้ตามการทดลอง

อุกกาบาตโบราณ **อาจ** มีส่วนในการล่มสลายของโลกยุคปัจจุบัน แต่เหตุแท้จริงยัง **[OPEN]** และไม่ควรเฉลยในช่วงต้นเกม

- ไม่ใช้มือเปล่าร่ายเวททั่วไป
- ไม่กลายเป็นโลกที่ทุกคนถือดาบเรืองแสง
- ไม่ให้ไอเทมปกติชุบคนตาย และไม่ลบ Permadeath
- NPC ยังตัดสินใจเองแม้ครอบครองอุปกรณ์พิเศษ
- ใช้เรื่องเล่า/ข่าวลือก่อนเพิ่มระบบใหญ่ลง prototype

## Parallel worldbuilding track (Atlas v0.1)

แผนที่โลกใหม่ครอบคลุมดินแดนที่เคยเป็นประเทศไทยและชายขอบที่สัมพันธ์กัน ใช้ลุ่มแม่น้ำ ที่ราบสูงโคราช เทือกเขา ชายฝั่ง และคาบสมุทรเป็นฐาน ขณะที่ชื่อต่าง ๆ และการเปลี่ยนแปลงในอนาคตเป็นสมมติฐานของโลกเกม

- อ่าน [07_Wanderer_Thailand_Region_Worldbuilding_v0.1.md](07_Wanderer_Thailand_Region_Worldbuilding_v0.1.md) ก่อนสร้างแผนที่หรือออกแบบเมือง
- อ่าน [08_Wanderer_Stonegate_City_Design_MAP-02A_v0.1.md](08_Wanderer_Stonegate_City_Design_MAP-02A_v0.1.md) สำหรับผังเมือง นครรัฐ สภา NPC/เควสและข้อจำกัด Town UI;
  **ชื่อ NPC กลุ่มการเมือง ประวัติและตำแหน่งเมืองยังเป็นข้อเสนอ**
- การแบ่ง 7 ภูมิภาคและชื่อ เช่น นครประตูหิน **ยังไม่ใช่ Final Canon**
- สร้าง Atlas rough map (MAP-01) แยกจากแผนที่เล่นจริง (MAP-05) และแยกแผนที่ลับเรื่องดาราศิลา
- ใช้โครงเส้นทางแบบ **node-based**; ไม่เปลี่ยน Wanderer เป็น open world
- การทำ worldbuilding เป็น track คู่ขนานเพื่อแรงบันดาลใจเท่านั้น; **M1.5B ยังคงเป็น milestone ที่ลงมือพัฒนาเกมต่อไป**
- แผนยังไม่ได้สร้างรูปแผนที่จริง และยังไม่ได้เขียนระบบ Journey ใน Godot

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
