# M2B-01 — Shared Actor Definition & Runtime State

งานนี้ได้รับอนุมัติ implementation โดยตรงใน task วันที่ 3 พฤศจิกายน 2026.
ฐาน `visual-combat-test-1` local/remote ตรงกันที่
`924748cf09a4c421c7c0c270995a512fa67ad281` หลัง PR #32 merged.
ไม่มี open M2B PR ซ้ำ; PR #2 ยัง unmerged ไม่ใช้เป็น canonical.
สถานะ milestone/ขั้นถัดไปอยู่ใน [documentation index](../../docs/README.md#current-status-and-next-roadmap).

## Architecture และ ownership

- [ActorDefinition](../../scripts/actors/actor_definition.gd): `actor_id`,
  `display_name`, `role` (`PLAYER`/`NPC`/`ENEMY`), `base_max_hp` เท่านั้น.
  Factory รับ Dictionary ครบสี่ field, ไม่มี field เกิน; ID ใช้ตัวอักษรเล็ก
  ตัวเลข/underscore เริ่มด้วยตัวอักษร, ชื่อแสดงผลต้องไม่ว่าง, max HP เป็น int > 0.
  ข้อมูล input ถูก copy แล้ว `make_read_only()`; snapshot เป็นสำเนาอีกชุด.
- [ActorRuntimeState](../../scripts/actors/actor_runtime_state.gd): ถือสำเนา ID,
  current HP และ max HP ที่ใช้จริง; เริ่มจาก base max หรือ initial HP ที่ระบุ.
  ไม่มี reference กลับไปแก้ Definition. การสร้างสอง state จาก Definition เดียวกัน
  ไม่แชร์ HP. Max HP ยังไม่มี modifier/setter ในงานนี้.
- `take_damage()`/`heal()` คืน status และ **delta ที่เกิดจริง**; clamp ก่อนบวก/ลบ
  ป้องกัน HP หลุดช่วงและ integer overflow จาก amount ขนาดใหญ่.
  Amount ต้องเป็น int ≥ 0; input ผิดคืน `INVALID_INPUT`, delta 0 และไม่เปลี่ยน state.
- `can_act()` คือ HP > 0 ใน fixture เท่านั้น. ไม่เพิ่มสถานะ death/alive ถาวร;
  `heal()` ใช้เลข HP ตาม fixture แม้เริ่ม 0 ไม่ใช่กฎคืนชีพของเกมเต็ม.
- `snapshot()` คืน Dictionary ของ scalar values ใหม่ทุกครั้ง ไม่มี Node/reference
  ไปยัง state ภายใน. UI ในอนาคตควรอ่านค่านี้จากเจ้าของ state ไม่เก็บ HP ซ้ำเอง.
  งานนี้ไม่มี UI ใหม่และไม่ได้ migrate UI เดิม.

เลือก **RefCounted** เพราะข้อมูล proof ไม่ต้องเป็น Node, ไม่มี lifecycle ใน scene,
ไม่ต้อง `.tres`/Inspector หรือ asset cache ของ Resource และถูกคืนเมื่อไม่มี reference.
ไม่ใช้ Resource จึงไม่เกิด shared mutable Resource HP; ถึงแชร์ Definition ก็แชร์เฉพาะ
baseline ที่อ่านผ่าน API ส่วน Runtime แต่ละตัวถูกสร้างใหม่. ไม่เพิ่ม singleton/event bus.

GDScript ใช้ `_` เป็นข้อตกลงว่า field ภายใน ไม่ใช่ security/private access control;
ผู้ใช้ API ต้องไม่เขียน `_data`/`_current_hp` โดยตรง. ใช้ `create()` เสมอและตรวจ null.
Bare `.new()` ไม่ใช่ validated actor; State factory ปฏิเสธ bare Definition และ bare
State ลง action/effect ไม่ได้. ไม่มี global registry บังคับ ID ไม่ซ้ำ: เจ้าของ encounter
ในอนาคตต้องตรวจ ID ซ้ำภายในกลุ่มก่อนใช้เป็น target; fixture นี้ให้ทั้งสาม ID ต่างกัน.

## ตัวอย่างและ GDScript สำหรับผู้เริ่มต้น

`preload()` โหลด script ไว้ก่อน; `const` ตั้งชื่ออ้างอิง script ที่ไม่เปลี่ยน.
`RefCounted` เป็น object ข้อมูลที่ไม่ต้อง `add_child()`. `static func create()` เรียก
ผ่าน script ได้และ validate ก่อนคืน object; `null` หมายถึงข้อมูลไม่ถูกต้อง.
`Variant` ที่ขอบเขต input ช่วยรับข้อมูลผิดชนิดเพื่อตรวจและคืนผลปลอดภัย;
`typeof()` แยก int จาก float/bool โดยไม่แปลงเงียบ ๆ. ภายในใช้ `String`/`int`/`bool`.
`Dictionary` เก็บ key/value; `duplicate(true)` คัดลอกแยกจากข้อมูลต้นทาง.

```gdscript
const Definition = preload("res://scripts/actors/actor_definition.gd")
const State = preload("res://scripts/actors/actor_runtime_state.gd")

var definition = Definition.create({
    "actor_id": "player", "display_name": "Adventurer",
    "role": "PLAYER", "base_max_hp": 30
})
# เมื่อรับ input ภายนอก ต้องตรวจ definition/state != null ก่อนใช้
var player = State.create(definition, 6)
player.take_damage(2) # APPLIED, hp_delta -2; 6 → 4
player.heal(4)        # APPLIED, hp_delta +4; 4 → 8
player.heal(100)      # APPLIED, hp_delta +22; 8 → 30
var view: Dictionary = player.snapshot()
view.current_hp = 0   # เปลี่ยนเฉพาะสำเนา; player ยัง 30
var fresh = State.create(definition) # restart แบบสร้างใหม่: 30/30
```

ตัวอย่าง state ใน integration fixture:

| Actor ID | Definition role / base max | Runtime current/max | can_act |
| --- | --- | --- | --- |
| player | PLAYER / 30 | 6/30 | true |
| npc | NPC / 10 | 10/10 | true |
| enemy_a | ENEMY / 15 | 10/15 | true |

Fixture สร้าง snapshot เข้า M2A ตาม schema เดิม:

```gdscript
var p: Dictionary = player.snapshot() # fresh fixture: 6/30
var n: Dictionary = npc.snapshot()    # 10/10
var e: Dictionary = enemy.snapshot()  # 10/15
var situation: Dictionary = {
    "player_hp": p.current_hp, "player_max_hp": p.max_hp,
    "npc_hp": n.current_hp, "npc_max_hp": n.max_hp,
    "living_enemy_ids": [e.actor_id] if e.can_act else [],
    "incoming_target_id": p.actor_id, "incoming_damage": 3,
    "help_enabled": true, "help_uses_remaining": 1, "guidance": "ATTACK"
}
var resolver = preload("res://scripts/npc/npc_decision_resolver.gd").new()
var decision: Dictionary = resolver.decide(situation)
# HELP → player → PLAYER_LOW_HP_HELP
```

[Executable fixture](actor_data_proof.gd) ตรวจค่าจริงและทดลอง HELP 4 แล้ว enemy hit 3
ผ่าน State API: Player 6→10→7; NPC/Enemy HP ไม่เปลี่ยน. นี่เป็น adapter ใน test เท่านั้น
ไม่สร้าง resolver ใหม่ ไม่เปลี่ยน policy และไม่อ้างว่า Encounter migrate แล้ว.

## Automated verification

รันจาก repository ด้วย output ใหม่:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2b-01-final --npc-proof --actor-proof
```

`--actor-proof` เป็น opt-in อิสระ; `--npc-proof` ยังคงรัน M2A ทั้งสองชุด และ
ค่า default ยังคง legacy suite เดิม. Clean import ตรวจ scripts ใหม่ด้วย.
รัน final หลัง commit implementation; commit/engine/command/source hashes
บันทึกใน [run record](evidence/m2b-01/run-record.json),
[results/exit codes/errors](evidence/m2b-01/results.json),
[raw logs](evidence/m2b-01/logs.txt) และ
[source hashes](evidence/m2b-01/source-sha256.json).

Engine จริง **4.7.2.stable.official.ed1daf0bf**; final ทุก stage exit 0:

| Automated stage | Expected | Actual |
| --- | --- | --- |
| Version / clean import / 12 script parses | 4.7.2, no unexpected errors | PASS |
| Main scene / M2A playable startup | No startup errors | PASS |
| Actor foundation | Independent state, correct limits, invalid input safe, unchanged Definition/snapshots, fresh state, Resolver bridge | PASS — 122 checks / 0 failures |
| M1.6/combat regression | Both kill orders, dead skips/live counters, single completion, locking/fallback, Attack/Defend/NPC2 Guard, victory/defeat, Restart | PASS — 14,395 checks / 0 failures |
| Legacy negative | Exactly five expected errors | PASS — 983 checks / 0 failures |
| M2A-02 | Existing decision/effect contracts | PASS — 412 checks / 0 failures |
| M2A-03 | Existing playable scene/Tween/Restart integration | PASS — 5,166 checks / 0 failures |
| Agent manual F6 / visual acceptance | Human review | NOT RUN ในงานนี้ |

ทั้ง 12 acceptance requirements ครอบคลุมโดย actor fixture ข้อ 1–11 และ regression
ข้อ 12. Actor cases ตรวจ ID ต่างกัน, shared-definition independence, damage, zero clamp,
heal cap, zero availability, baseline unchanged, detached input/output, malformed/missing
fields/types/IDs/HP, atomic rejection, recreation default/preset และ Resolver compatibility.
ไม่มี test framework ใหม่และไม่มีการแก้ constants เพื่อให้ PASS.

รอบ `/tmp/wanderer-m2b-01-first` **FAIL import แม้ exit 0** เพราะ macOS certificate/
editor settings ถูก sandbox ขวาง; ไม่ใช้เป็นหลักฐาน PASS. รอบ `check` และ `final`
รันนอก sandbox โดยคง unexpected-error checks เดิม. หลักฐาน final เก็บ log/exit ทุก stage;
run-record มี initial-failed results/log แยกเพื่ออธิบายความต่าง.

ผู้สร้างรายงานว่า manual M2A-03 ผ่านและอนุมัติไปต่อ: **owner-reported manual acceptance**
ใน task วันที่ 3 พฤศจิกายน 2026. ไม่มีผลราย scenario/commit/engine/media เพิ่ม จึงไม่
เติมผลที่ไม่มีหลักฐาน. ไม่อ้างว่า agent เปิด F6 ใหม่หรือ headless ยืนยันคุณภาพภาพ.

## ขอบเขตที่ยังไม่ได้ integrate และ review ก่อนงานต่อไป

Combat controller/scene/turn flow, NPC Resolver/Encounter/playable controller เดิม
ไม่มีการแก้; HP เจ้าของเดิมยังทำงานเหมือนเดิม. ไม่มี full stats ตาม v0.1 §11,
items/equipment/inventory, save/load, full AI/Trust/Guidance, Down/Death หรือ lore ใหม่.
ค่า speed 0.70, lunge 44px, formation/animation/HP balance คงเดิม.

ก่อน M2B-02 ให้ review factory/null/error contract, ID naming/uniqueness scope,
Definition sharing, restart ownership และการที่ UI อ่าน state จากเจ้าของเดียว.
ข้อเสนอ migration M2B-02/M2C อยู่ที่ [index](../../docs/README.md#m2b-01--shared-actor-data-foundation-pending-review)
และต้องได้รับ task review แยก. ไม่ลงมือ migration ใน PR นี้.
