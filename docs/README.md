# Wanderer Documentation Index

เอกสารในโฟลเดอร์นี้เป็นแผนและบันทึกทิศทางของโครงการ Wanderer โดยให้ใช้ลำดับความสำคัญดังนี้เมื่อมีข้อความขัดแย้งกัน

1. `04_Wanderer_Learning_Development_Workflow_v0.4.md`
2. `03_Wanderer_Combat_Presentation_Direction_Update_v0.3.md`
3. `02_Wanderer_Visual_Combat_Prototype_Update_v0.2.md`
4. `01_Wanderer_Game_Development_Plan_v0.1.md`
5. `Wanderer_Pixelorama_Training_Handoff.md`

## Current direction

สถานะล่าสุดของโครงการคือ Visual Combat Test 1 ผ่านการทดสอบเบื้องต้นแล้ว และงานถัดไปคือ Milestone 1.5B — Octopath-inspired Combat Staging Pass

หลักสำคัญของทิศทางล่าสุด:

- Side-view combat ยังคงเป็นแกนหลัก
- หลีกเลี่ยงการจัด Party เป็น flat rank / baseline เดียวแบบถาวร
- ทดลอง staging แบบมี depth และความรู้สึก 2.5D / diorama
- ใช้ Octopath Traveler เป็นแรงบันดาลใจด้าน staging, focus และ pacing ไม่ใช่การคัดลอก asset หรือ composition แบบตรงตัว
- Runtime sprite scale ×4 ที่ 1280 × 720 ผ่านการทดสอบรอบแรก
- Turn system ยังเป็น [OPEN] และต้องให้ Prototype ช่วยตัดสิน
- ยังไม่เพิ่ม Full NPC AI ก่อน Staging และ Attack Feel ผ่าน

## Learning-first workflow

การพัฒนา Wanderer ตั้งแต่นี้ไปใช้แนวทางเรียนรู้ไปพร้อมกับการสร้างเกม:

- ผู้พัฒนาเป็นคนลงมือใน Godot ให้มากที่สุด
- AI ทำหน้าที่หลักเป็นคู่พัฒนา / โค้ช / ผู้ตรวจงาน
- ค่าเริ่มต้นของการช่วยเหลือคือ Guided Steps: อธิบายแนวคิด เหตุผล และให้ผู้พัฒนาลงมือทีละขั้น
- งาน gameplay code และ scene สำคัญไม่ควรถูก AI แก้เสร็จทั้งก้อนโดยอัตโนมัติ เว้นแต่ผู้พัฒนาร้องขอ
- ใช้วงจร Goal → Concept → Do → Observe → Explain → Adjust → Commit
- Git และการอ่าน diff เป็นส่วนหนึ่งของกระบวนการเรียนรู้

รายละเอียดเต็มอยู่ใน `04_Wanderer_Learning_Development_Workflow_v0.4.md`

## หมายเหตุ

เอกสารเวอร์ชันเก่ายังคงเก็บไว้เพื่อรักษาประวัติการตัดสินใจของโครงการ ไม่ควรลบเพียงเพราะมีข้อกำหนดบางส่วนถูกแทนที่ในเอกสารใหม่กว่า
