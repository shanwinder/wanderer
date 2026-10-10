# Wanderer — Documentation

**เริ่มที่นี่ แต่ไม่ต้องอ่านทุกไฟล์**  
มี **3 เอกสารออกแบบหลัก** เท่านั้น; เปิดเฉพาะฉบับที่เกี่ยวกับงานปัจจุบันเพื่อลด context/token

| อ่านเมื่อ | เอกสาร |
|---|---|
| แก้ Combat, NPC, ความตาย, Progression, ระบบพลัง | **[GAME.md](GAME.md)** — ข้อกำหนดและเกมเพลย์ |
| เขียนเมือง เควส แผนที่ ตัวละคร Lore และจังหวะซ่อนที่ตั้งโลกเก่า | **[WORLD.md](WORLD.md)** — World Bible (มี **developer spoilers**) |
| ทำงานใน Godot เรียน GDScript ตรวจ Milestone/Art/ขั้นตอนถัดไป | **[WORKFLOW.md](WORKFLOW.md)** — Roadmap, Learning และบันทึก GDScript (ล่าสุด: เรียนถึง `function`) |

**งานพัฒนาเกมที่ทำถัดไป:** **M1.5B Combat Staging** ใน `res://scenes/combat/combat_prototype.tscn`. โลก/เมือง/Starstone เป็นงานออกแบบ ไม่ได้ implement จากการเพิ่มเอกสาร

**คำกำกับสถานะ:** [LOCKED] หลักที่ตกลง; [PROTOTYPE] สำหรับทดสอบ; [PROPOSED] ยังไม่ล็อก; [OPEN] รอข้อสรุป; [LATER] ไม่ทำในช่วงนี้

## Map sketches (ไฟล์ภาพ ไม่ต้องโหลดเป็นข้อความ)

- [Stonegate designer schematic](maps/stonegate_map02b_layout_v0.1.svg) — ผัง 9 เขตและเส้นทาง, ไม่ใช่มาตราส่วนจริง
- [Early player route sketch](maps/stonegate_player_route_R0_v0.1.svg) — แสดงเมืองกับสองเส้นทางโดยไม่เฉลยโลกเก่า

## Maintenance

1. **แก้ไฟล์หลักที่เกี่ยวข้องในที่เดิม** อย่าสร้าง `13_...`, `14_...` หรือเอกสารฉบับแก้ต่อท้ายเรื่อย ๆ
2. เมื่อเริ่มงาน ให้ AI อ่าน **เพียงหนึ่งเอกสารหลัก + ไฟล์ code/scene ที่เกี่ยวข้อง**; ถ้าเกี่ยวหลาย domain ค่อยเปิดเพิ่มเฉพาะส่วนจำเป็น
3. เอกสาร v0.1–v0.5, MAP-01/02/03, old reveal audit และ Pixelorama handoff **ถูกยุบแล้ว**; หากต้องตรวจเหตุผลเก่า ให้ดู **Git history ก่อนการรวมเอกสาร** แทนการโหลดทั้งหมด
4. `WORLD.md` มีรายละเอียดที่ไม่ควรปรากฏในเกมช่วงต้น และ repo เป็น **public**; “developer-only” ไม่ใช่การจำกัดสิทธิ์เข้าถึงจริง
5. แยกสิ่งที่ **เอกสารวางแผน** จากสิ่งที่ **รัน Godot ทดสอบผ่านแล้ว** เสมอ
