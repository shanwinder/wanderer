# B1 Recovery 02 — HOLD

Environment จัดเป็น **A — resolved** สำหรับ unsandboxed execution: Godot binary เดียวกันบน macOS 27.0.1 (26A434) / arm64 ให้ certificate API status -50 ใน sandbox และ 0 นอก sandbox. Minimal project ทำซ้ำ error ได้โดยไม่มี Wanderer source; unsandboxed run สะอาด. ไม่ได้เปลี่ยน TLS/trust store/keychain/Gatekeeper/SIP หรือใช้ whitelist. ไม่ได้รันจาก GUI Terminal จริง; การเปรียบเทียบเป็น sandboxed/unsandboxed exec โดยตรง. ไม่ระบุว่ายืนยัน sandbox policy rule ภายใน macOS ได้แล้ว.

Parse fix เดิมคงอยู่: seed_reference_snapshot และ 3 call sites; source scripts ทั้ง 5 hash ตรง recovery-01. Fresh import และ parse ทุกสคริปต์ผ่าน; focused smoke เดิม 86/86 ผ่าน exit0 พร้อม clean stdout/stderr/engine logs. Full commands, paths, exits และ manifests อยู่ใน [clean-smoke/results.json](clean-smoke/results.json).

Expanded proof ได้ 96/97 assertions, exit1, ไม่มี engine error. **SC09 FAIL:** สำเนาของ genuine IMPACT response ที่เปลี่ยน effect.reason เป็น M405_FORGED_UNKNOWN_REASON ยังผ่าน response_valid(). Schema กำหนด nested reason เป็นเพียง S และตรวจ status/reason pairing เฉพาะชั้นนอก. เป็น implementation defect เทียบ approved closed-reason contract; ไม่ได้เปลี่ยน protocol. ดู [adversarial logs/commands](adversarial/results.json) และ [full transaction/root evidence](adversarial/focused-report.json). Copies ถูกใช้เป็น input ของ pure validator เท่านั้น ไม่ได้นำกลับเข้า Owner.

หยุดตามคำสั่งข้อ7 เมื่อพบ Schema Error. Full adversarial matrix, existing regression/negative suite, performance และ GUI ยัง NOT RUN. B2–B5/M4-05C deferred. ยังไม่ commit/push/เปิด Draft PR.

Independent review ที่ต้องทำต่อ:

- ทบทวน nested Effect reason/status และการผูกกับ outer response ตาม SC09
- ทบทวน recursive validators ทั้งชุดก่อนขยาย adversarial matrix
- พิสูจน์ atomic failure, token/receipt provenance และ replay ครบตาม B1
- รัน full existing regression ใน execution context ที่ตรวจแล้ว

หลักฐานแรกและ recovery-01 ไม่ถูกเขียนทับ. การแก้ source ในรอบนี้มีเฉพาะ test harness เพิ่ม adversarial assertions; protected tracked diff ว่าง. งานทั้งหมดอยู่ branch เดิม codex/m4-05b-b1-single-authority-proof บน df04052cc8bf0d17510b55e75f3b357e7da9c00f. [ผลรวมและข้อจำกัด](results.json), [before/after hashes](before-after-hashes.json), [tested source](tested-source.zip).
