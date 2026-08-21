# WANDERER
## ภาคปรับปรุงทิศทาง Combat Presentation และ Visual Staging

**เวอร์ชันเอกสาร:** 0.3  
**วันที่ปรับปรุง:** 21 สิงหาคม 2026  
**สถานะโครงการ:** Visual Combat Test 1 ผ่านการทดสอบเบื้องต้น และกำลังเข้าสู่ Combat Staging Pass  
**เอกสารฐาน:** `docs/01_Wanderer_Game_Development_Plan_v0.1.md` และ `docs/02_Wanderer_Visual_Combat_Prototype_Update_v0.2.md`

> เอกสารนี้เป็นภาคปรับปรุงอย่างเป็นทางการของแผนเดิม และให้ถือข้อความในเอกสารนี้แทนส่วนที่ขัดแย้งกันในเอกสาร 0.1 และ 0.2 โดยเฉพาะเรื่อง Combat Presentation, การจัดตำแหน่งตัวละคร, ภาษาภาพของฉากต่อสู้, ขนาดการแสดงผล Sprite, UI และลำดับงานของ Milestone 1.5

---

# 1. เหตุผลที่ต้องปรับทิศทาง

Visual Combat Test 1 ทำให้เห็น Player, NPC 3 คน และ Enemy A อยู่ร่วมกันใน Godot ที่ความละเอียด 1280 × 720 ได้จริง ผลการทดสอบยืนยันว่า Sprite ปัจจุบันสามารถอ่านได้ดี แยกตัวละครได้ชัด และใช้เป็นฐานพัฒนาต่อได้

อย่างไรก็ตาม การจัดตัวละครแบบเรียงแนวนอนบน baseline เดียว ทำให้ภาษาภาพของฉากเอนเข้าใกล้เกมที่เน้นการยืนเป็นแถวและการแบ่งฝ่ายแบบ rank-based มากเกินไป โดยเฉพาะความรู้สึกที่ใกล้กับ Darkest Dungeon มากกว่าทิศทางที่ต้องการ

ทิศทางที่ต้องการของ Wanderer คือ:

> **Combat แบบ Side-view ที่ให้ความรู้สึกเป็นเวที 2.5D / diorama มีมิติหน้า-หลัง มีการเน้นตัวละครที่กำลังกระทำ และมีจังหวะการนำเสนอที่ใกล้กับความรู้สึกของ Octopath Traveler มากกว่าการยืนเรียงเป็นแถวคงที่**

คำว่า “Octopath-inspired” ในเอกสารนี้หมายถึงการเรียนรู้หลักการด้าน staging, depth, focus, pacing และการจัด UI เท่านั้น ไม่ใช่การลอก asset, ฉาก, เอฟเฟกต์ หรือองค์ประกอบที่มีลิขสิทธิ์แบบตรงตัว

---

# 2. สิ่งที่ Visual Combat Test 1 พิสูจน์แล้ว

## 2.1 Sprite Scale

**[PROTOTYPE — ผ่านการทดสอบรอบแรก]**

- การแสดงผล Sprite แบบ integer scale ×4 ที่ 1280 × 720 อ่านได้ดี
- Player, NPC1, NPC2, NPC3 และ Enemy A แยก silhouette และบทบาทได้ชัด
- ยังไม่มีเหตุผลให้ลดกลับไปใช้ตัวละครสูงประมาณ 24–32 พิกเซลตามแผนเดิม
- หลีกเลี่ยง fractional scale เช่น ×4.3 หรือ ×4.7 เพื่อรักษาความคมของ Pixel Art

ดังนั้น ข้อกำหนด “ความสูงตัวละครชั่วคราวประมาณ 24–32 พิกเซล” ในเอกสาร 0.2 ไม่ถือเป็นข้อบังคับอีกต่อไป

## 2.2 Party Readability

**[PROTOTYPE — ผ่านการทดสอบรอบแรก]**

สีและอาวุธของสมาชิกปาร์ตี้ช่วยให้แยกตัวละครได้ชัด:

- Player — โทนน้ำเงิน / ดาบ
- NPC1 — โทนเขียว / ธนู
- NPC2 — โทนครีม / ไม้เท้าหรืออุปกรณ์สนับสนุน
- NPC3 — โทนแดง / หอก

Enemy A มี silhouette ใหญ่กว่ามนุษย์และอ่านเป็นภัยที่แตกต่างจากปาร์ตี้ได้ทันที

## 2.3 สิ่งที่ยังไม่ผ่าน

- Formation ยังให้ความรู้สึกเป็น lineup มากเกินไป
- Battlefield ยังแบนและไม่มีมิติหน้า-หลังเพียงพอ
- UI ยังมีลักษณะ Debug / Prototype มากกว่าภาษาของเกมจริง
- ยังไม่มี Active Character Emphasis
- ยังไม่มีจังหวะกล้อง แสง หรือการเน้นเป้าหมายระหว่าง Action

---

# 3. Combat Presentation Direction

## 3.1 Side-view ยังคงเดิม

**[LOCKED]**

Wanderer ยังคงใช้ฉากต่อสู้มุมมองด้านข้าง แต่จะไม่ตีความ “ด้านข้าง” ว่าตัวละครทุกคนต้องยืนเรียงบนเส้นเดียวกัน

เป้าหมายคือให้ Side-view มีความรู้สึกเป็นเวทีที่มีพื้นที่จริง ไม่ใช่แถวของช่องตำแหน่ง

## 3.2 Party Formation

**[PROTOTYPE]**

ปาร์ตี้ 4 คนต้องจัดเป็น “กลุ่ม” ที่มีการเยื้องหน้า-หลังและระยะลึก แทนการเรียงซ้ายไปขวาบน baseline เดียว

หลักการ:

- มีการเยื้องแกน Y เล็กน้อยเพื่อสร้าง depth
- ตำแหน่งแต่ละคนยังอ่านง่ายและไม่บังกัน
- Player ต้องไม่หายไปในกลุ่ม NPC
- อาวุธต้องไม่ชนหรือซ้อนกันจน silhouette เสีย
- Formation ต้องรองรับการก้าวออกมาทำ Action และกลับเข้าตำแหน่ง
- Formation ไม่ควรรู้สึกเป็น 4 ช่องคงที่แบบ rank lineup

ตัวอย่างเชิงแนวคิด:

```text
        NPC1

  Player       NPC2

          NPC3
```

ตำแหน่งจริงให้ตัดสินจากการทดลองใน Godot ไม่ยึดแผนผังนี้เป็นพิกัดตายตัว

## 3.3 Enemy Staging

**[PROTOTYPE]**

Enemy ต้องดูเหมือนอยู่ “ในพื้นที่ของมัน” ไม่ใช่ตัวละครที่ถูกวางไว้ปลายแถวตรงข้ามปาร์ตี้

- ศัตรูแต่ละตัวสามารถมีตำแหน่งลึกต่างกัน
- ศัตรูใหญ่สามารถกินพื้นที่สนามมากกว่ามนุษย์
- ระยะกลางระหว่างสองฝ่ายต้องเหลือไว้สำหรับ Action, Projectile, Charge และ Effect
- เมื่อเพิ่มศัตรูหลายตัว ให้จัดเป็นกลุ่มหรือชั้นความลึกแทนการเรียงเป็นเส้นเดียว

## 3.4 Battlefield Depth

**[PROTOTYPE]**

ฉากต่อสู้ควรพัฒนาไปสู่โครง 2.5D / diorama โดยมีอย่างน้อย:

- Background
- Midground
- Ground plane
- Foreground
- Contact shadow หรือเงาใต้เท้า
- Atmospheric layer เช่นหมอก ฝุ่น แสง หรืออนุภาคในภายหลัง

การมีพื้นที่ว่างด้านบนไม่ถือเป็นปัญหา หากพื้นที่นั้นมีหน้าที่สร้างโลก แสง ความลึก และบรรยากาศ

---

# 4. Active Character และ Action Focus

## 4.1 Active Character Emphasis

**[PROTOTYPE]**

เมื่อถึง Action ของตัวละครหนึ่งคน ผู้เล่นต้องรู้ทันทีว่าใครกำลังกระทำ โดยไม่ต้องอ่าน Combat Log

วิธีที่ทดลองได้:

- Active Character ก้าวออกจาก formation เล็กน้อย
- เพิ่มความสว่างหรือ contrast ชั่วคราว
- ลดความเด่นของตัวอื่นเล็กน้อย
- เลื่อนกล้องหรือซูมเพียงเล็กน้อย
- เน้นเป้าหมายด้วยแสง, marker หรือ hit focus

ไม่จำเป็นต้องใช้ทุกวิธีพร้อมกัน ให้เลือกเท่าที่จำเป็นต่อความชัดเจนและ pacing

## 4.2 Action Space

พื้นที่ว่างระหว่าง Party กับ Enemy มีหน้าที่เป็น “พื้นที่การแสดง Action” และต้องไม่ถูกบีบจนเกินไป

ใช้สำหรับ:

- Melee lunge
- Spear thrust
- Projectile
- Enemy charge
- Slash / impact effect
- Floating damage
- Knockback หรือ recoil

---

# 5. UI Direction

## 5.1 ลดความเป็น Debug Panel

**[PROTOTYPE]**

UI ฉากต่อสู้ต้องลดการแบ่งหน้าจอด้วย panel ขนาดใหญ่และข้อความสถานะที่ไม่จำเป็น

รายการต่อไปนี้เป็นข้อมูล Debug และควรถูกลดหรือนำออกจาก presentation จริง:

- `NPC1 — visual only`
- `NPC2 — visual only`
- `NPC3 — visual only`
- `Enemy B — not included in this test`
- Combat Log ที่กินพื้นที่มาก

## 5.2 หลัก UI ใหม่

- Battlefield เป็นจุดสนใจหลัก
- Command UI ปรากฏเมื่อผู้เล่นต้องตัดสินใจ
- HP / Status แสดงอย่างกระชับ
- Combat Log ถ้ามี ให้เป็นข้อความสั้นหรือพื้นที่รอง
- UI ต้องไม่ทำให้ฉากรู้สึกถูกแบ่งครึ่งบน/ครึ่งล่างอย่างแข็งเกินไป
- Active unit และ target ต้องอ่านได้ก่อนรายละเอียดตัวเลข

---

# 6. Gameplay Presentation กับ Turn System

## 6.1 ระบบเทิร์นยังไม่ล็อก

**[OPEN]**

ตัวเลือกหลักยังคงเป็น:

1. Classic Turn-based
2. Active Time Bar
3. Intent Round
4. ระบบอื่นที่เหมาะสมกว่า

ทิศทาง Octopath-inspired ไม่ได้หมายความว่า Wanderer ต้องคัดลอกระบบเทิร์นของ Octopath Traveler

## 6.2 สิ่งที่ต้องทดสอบจาก Presentation

ก่อนล็อกระบบเทิร์น ต้องใช้ Prototype ตอบคำถามต่อไปนี้:

- การดู NPC 3 คนตัดสินใจและแสดง Action ทีละคนช้าเกินไปหรือไม่
- ผู้เล่นยังรู้สึกว่าตัวละครของตนเป็นศูนย์กลางหรือไม่
- การแสดง Intent ก่อน Action ช่วยให้ NPC ดูมีเจตจำนงมากขึ้นหรือไม่
- Action sequence ที่มี camera focus และ animation สั้นทำให้ Classic Turn-based น่าสนใจพอหรือไม่
- ถ้าการแสดงผลทีละคนช้าเกินไป ควรเปลี่ยนไปใช้ Intent Round หรือระบบที่ resolve เร็วขึ้นหรือไม่

ดังนั้น Presentation Prototype เป็นเครื่องมือสำหรับตัดสิน Turn System ไม่ใช่เพียงงานตกแต่ง

---

# 7. Milestone 1.5 ฉบับปรับปรุง

Milestone 1.5 แบ่งเป็นช่วงย่อยเพื่อไม่ให้ระบบและภาพเปลี่ยนพร้อมกันมากเกินไป

## 1.5A — Visual Combat Test 1 — ผ่าน

- Player + NPC1 + NPC2 + NPC3 + Enemy A แสดงใน Godot ได้จริง
- Integer scale ×4 ใช้งานได้
- Party differentiation อ่านชัด
- Enemy A scale ใช้ได้สำหรับ Prototype
- Repository แยก runtime assets และ art source แล้ว

## 1.5B — Octopath-inspired Combat Staging Pass — งานถัดไป

**เป้าหมาย:** ลดความรู้สึกแบบ flat lineup และสร้างเวทีต่อสู้ที่มี depth

งานหลัก:

1. จัด Party formation ใหม่ให้มีหน้า-หลัง
2. จัด Enemy A ให้อยู่ในพื้นที่ของฉาก ไม่ใช่ปลายแถว
3. ปรับ ground / depth layers ขั้นต้น
4. เพิ่ม contact shadow ขั้นต้นถ้าจำเป็น
5. ลด Debug UI และคืนพื้นที่ให้ battlefield
6. เตรียม node structure สำหรับ Active Character Emphasis
7. ตรวจภาพที่ 1280 × 720

**ยังไม่เพิ่ม NPC AI ในช่วงนี้**

## 1.5C — Attack Feel / Motion Pass

หลัง Staging ผ่านแล้วจึงทำ:

1. Player active emphasis
2. Player lunge หรือ step-forward
3. Hit flash
4. Enemy recoil
5. Floating Damage
6. HP feedback
7. Player return to formation
8. Enemy counter-action
9. ตรวจ timing และ pacing

ยังใช้ Idle Sprite และ Tween ได้ก่อน ไม่ต้องรอ Attack Animation สมบูรณ์

## 1.5D — NPC Turn Presentation

หลัง Action ของ Player และ Enemy รู้สึกดีแล้วจึงเชื่อม NPC ทีละคน

- เริ่มจาก deterministic behavior
- ยังไม่ต้องใช้ Personality AI เต็มระบบ
- ตรวจว่าการดู NPC ลงมือเองสนุกหรือช้า
- ตรวจว่า Player ยังเป็นจุดโฟกัสของปาร์ตี้หรือไม่
- ใช้ผลลัพธ์ตัดสินว่าจะเดินหน้ากับ Classic Turn-based, Intent Round หรือระบบอื่น

---

# 8. Asset Priority ฉบับใหม่

## ทำก่อน

- Battlefield staging assets ขั้นต่ำ
- Ground / shadow ที่ช่วยสร้าง depth
- Active / target indicator ขั้นต้น
- Hit feedback แบบง่าย

## ทำเมื่อ Prototype เรียกร้อง

- Attack Pose
- Hurt Pose
- Down Pose
- Projectile
- Slash effect
- HP Bar แบบ final-ish

## ยังไม่ทำ

- Enemy B ก่อน Staging + Attack Feel ผ่าน
- Skill VFX จำนวนมาก
- Full NPC AI
- Guidance system เต็มรูปแบบ
- Injury / Permadeath presentation
- Final background art
- Full sprite sheets หลายเฟรม

หลักการคือ:

> **อย่าผลิต Asset เพิ่มเพียงเพราะทำได้ ให้ผลิตเมื่อ Prototype แสดงว่าจำเป็น**

---

# 9. เกณฑ์ผ่าน Combat Staging Pass

Milestone 1.5B ถือว่าผ่านเมื่อ:

1. ปาร์ตี้ไม่อ่านเป็นเส้นตรง 4 ช่อง
2. ตัวละครมีความรู้สึกหน้า-หลังโดยไม่บังกัน
3. Player ยังเป็นตัวละครหลักที่สายตาหาเจอทันที
4. Enemy A ดูเป็นส่วนหนึ่งของ battlefield ไม่ใช่ placeholder ที่ปลายแถว
5. พื้นที่กลางรองรับ Action ได้
6. Battlefield มีความสำคัญมากกว่า Debug UI
7. ภาพรวมเอนไปทางเวที 2.5D / diorama มากกว่า rank-based lineup
8. ยังอ่านฝ่ายเราและฝ่ายศัตรูได้ชัดที่ 1280 × 720

หลังผ่านเกณฑ์นี้จึงเริ่ม Attack Feel / Motion Pass

---

# 10. สิ่งที่ยังล็อกและสิ่งที่ยังเปิด

## [LOCKED]

- Player ควบคุมเฉพาะตัวเอง
- NPC 3 คนตัดสินใจเองในระบบเกมเต็ม
- Side-view combat
- Party size 4 คน
- Pixel Art เป็นภาษาหลักของตัวละคร
- Visual Combat Prototype ต้องพัฒนาควบคู่กับระบบ

## [PROTOTYPE]

- Octopath-inspired 2.5D / diorama staging
- Party formation แบบมี depth
- Integer scale ×4 ที่ 1280 × 720
- Active character emphasis
- Compact combat UI
- Tween-based action presentation

## [OPEN]

- Classic Turn-based vs Intent Round vs ATB
- รูปแบบกล้องในฉากต่อสู้
- ระดับการใช้ 3D จริงใน Godot
- รูปแบบ final ของ HP / Command UI
- จำนวน depth layer และ effect ที่เหมาะกับงบ Solo Developer

---

# 11. กฎการตัดสินใจด้าน Combat Presentation

1. หลีกเลี่ยง flat lineup ที่ทำให้ปาร์ตี้ดูเป็น rank-based formation โดยไม่ตั้งใจ
2. ทุกการเพิ่ม depth ต้องช่วย readability ไม่ใช่เพิ่มความซับซ้อนเพียงเพื่อความสวย
3. Active Character ต้องเด่น แต่ NPC ยังต้องดูเป็นบุคคลที่มีตัวตน ไม่ใช่ background prop
4. Effect และกล้องต้องสั้นและอ่านง่าย เพราะการต่อสู้มีหลายตัวละครต่อรอบ
5. Presentation ต้องรองรับ NPC autonomy ไม่ใช่กลบมัน
6. ทดสอบ pacing ก่อนวาด animation จำนวนมาก
7. ใช้ Tween, camera, light และ hit feedback เพื่อประหยัดจำนวนเฟรมวาดเมื่อเหมาะสม
8. Final art ลงทุนหลัง staging และ combat feel ผ่านเท่านั้น
9. ความคล้าย Octopath ต้องมาจากหลักการ staging และ presentation ไม่ใช่การคัดลอก asset หรือ composition แบบตรงตัว
10. ทุกการตัดสินใจต้องกลับไปตอบคำถามว่า “สิ่งนี้ทำให้ผู้เล่นรับรู้การตัดสินใจของตนเองและของ NPC ชัดขึ้นหรือไม่”

---

# 12. งานถัดไปอย่างเป็นทางการ

ไฟล์หลัก:

```text
res://scenes/combat/combat_prototype.tscn
```

ลำดับงานถัดไป:

1. ทำ Milestone 1.5B — Octopath-inspired Combat Staging Pass
2. ทดสอบ formation และ depth ที่ 1280 × 720
3. วิเคราะห์ภาพร่วมกันก่อนเพิ่ม motion
4. ทำ Milestone 1.5C — Attack Feel / Motion Pass
5. วิเคราะห์ timing และ action readability
6. ทำ Milestone 1.5D — NPC Turn Presentation
7. ใช้ผล Prototype ตัดสิน Combat Flow ระยะถัดไป

> **Prompt ถัดไปควรเริ่มจาก Milestone 1.5B โดยยังไม่เพิ่มระบบใหญ่หรือผลิต Asset จำนวนมาก**
