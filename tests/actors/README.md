# Actor Definition, Runtime State & Encounter Ownership

หัวข้อ M2B-01 ด้านล่างเป็นบันทึกขอบเขต/ผลเดิมจาก PR #33. สถานะปัจจุบันและ migration ใหม่อยู่ที่ [M2B-02](#m2b-02--single-source-encounter-hp); milestone authority อยู่ที่ [index](../../docs/README.md#current-status-and-next-roadmap).

## M2B-01 — Shared Actor Definition & Runtime State

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
ข้อเสนอ migration M2B-02/M2C อยู่ที่ [index](../../docs/README.md#m2b-01--shared-actor-data-foundation-merged-pr-33)
และต้องได้รับ task review แยก. ไม่ลงมือ migration ใน PR นี้.

## M2B-02 — Single-source Encounter HP

### ฐานและไฟล์ที่เปลี่ยน

Task วันที่ 3 พฤศจิกายน 2026 อนุมัติ implementation โดยตรง. เริ่มจาก clean tree บน
`visual-combat-test-1`; fetch แล้ว local/remote/merge-base ตรงกันที่
`156df771a17ae9aaf5b83032e8ff58f51b3d7a47` (PR #33 merged ตาม GitHub).
Open PRs #2/#17 ไม่มีงาน M2B ซ้ำ; GitHub issue-search คืนรายการว่าง จึงตรวจซ้ำด้วย
recent open PR listing แล้วได้สองรายการนี้. ไม่ใช้เอกสาร unmerged เป็น canonical.
ใช้ branch เดียว `codex/m2b-02-actor-state-ownership`.

ไฟล์ runtime ที่แก้มีเพียง [npc_proof_encounter.gd](../../scripts/npc/npc_proof_encounter.gd).
เพิ่ม [focused harness](actor_ownership_proof.gd) และ `.uid`; ขยาย
[verify.py](../combat/verify.py) ด้วย opt-in `--ownership-proof` อิสระเพื่อแยกผล
ownership จาก M2B-01 เดิม. อัปเดต root README, docs index, Actor/Combat/NPC guides
ในไฟล์เดิม และเพิ่ม raw evidence ใต้ `evidence/m2b-02/`.
ActorDefinition/ActorRuntimeState, Resolver, playable controller, main combat,
scenes, assets, project settings และ legacy test scripts ไม่เปลี่ยน.

### Architecture ก่อนและหลัง / GDScript สำหรับผู้เริ่มต้น

ก่อน: Encounter เก็บ current/max HP ใน `_state` Dictionary และหัก/เพิ่มค่าเอง;
ActorRuntimeState ของ M2B-01 ใช้ใน test fixture แยกเท่านั้น.
หลัง: Encounter ถือ `_actors` registry ที่มี `player`, `npc`, `enemy_a`;
แต่ละค่าคือ ActorRuntimeState คนละ object. `_state` เหลือข้อมูล HELP, incoming
attack และ Guidance; generation/action/queue/round/self-defend ยังเป็นของ Encounter.

**Definition** เป็นข้อมูลตั้งต้น: ID, display name, role และ base max HP.
`_build_actor_candidates()` สร้าง Definition ด้วย role PLAYER/NPC/ENEMY และ max HP
จาก validated restart preset แล้วส่งเข้า `RuntimeState.create(definition, initial_hp)`.
**Runtime State** เก็บ current/max HP ที่กำลังใช้จริง แยกจาก Definition;
ไม่เพิ่ม setter หรือ RuntimeState อีก class.

**Single Source of Truth** หมายถึงแต่ละ actor มี object เดียวที่เป็นเจ้าของ HP ปัจจุบัน.
Encounter เปลี่ยน HP ผ่าน API ของ object นี้; ไม่มี current/max HP ค้างใน metadata.
โค้ดจริงใน `_state_snapshot()`:

```gdscript
var view: Dictionary = _state.duplicate(true)
for spec in ACTORS:
    var actor: Dictionary = _actors[spec[1]].snapshot()
    view[spec[0] + "_hp"] = actor.current_hp
    view[spec[0] + "_max_hp"] = actor.max_hp
return view
```

`for` ทำซ้ำตาม actor mapping; `spec[0]` คือ prefix เช่น `enemy`, `spec[1]` คือ ID
เช่น `enemy_a`. จุดนี้แปลง schema เท่านั้น ไม่เก็บ HP เพิ่ม. Snapshot เป็นสำเนา
เพื่ออ่านหรือส่งให้ Resolver; แก้ `view.player_hp` จะไม่เปลี่ยน RuntimeState.
`inspect().state.player_hp/npc_hp/enemy_hp` ยังใช้ schema เดิมครบ;
`situation_snapshot()` ยังคงไม่มี enemy HP fields และให้ `living_enemy_ids` ตามเดิม.
Locked decision/reason_details อาจมี HP ตอนเลือก action เป็นประวัติ แต่ไม่ถูกนำมา
ใช้เป็นเจ้าของ HP ปัจจุบันหรือเขียนกลับ. UI เดิมเรียก `encounter.inspect()` ใน
`_refresh()` จึงอ่านผลจริงโดยไม่ต้องแก้ controller หรือเก็บ HP ของตัวเอง;
การเก็บ HP แยกใน UI จะเสี่ยงลืม sync เมื่อ HELP, enemy response หรือ Restart.

โค้ด effect จริง:

```gdscript
# ATTACK
effect.hp_delta = _actors["enemy_a"].take_damage(ATTACK_DAMAGE).hp_delta
# HELP
var healed: int = _actors["player"].heal(HELP_AMOUNT).hp_delta
# Enemy response หลังคำนวณ guard ตามเดิม
_actors[target].take_damage(damage)
```

ตัวอย่างผลที่ทดสอบ: ATTACK enemy 10→9 ครั้งเดียว แล้ว enemy hit Player 20→17;
HELP Player 6→10, resource 1→0 แล้ว enemy hit 10→7; DEFEND NPC 3→2 เพราะ hit 3
ลด 2 และขั้นต่ำ 1, guard หมดหลัง completion. `hp_delta` คือผลที่เกิดจริงหลัง clamp;
HELP Player 1/max4 ได้ +3. Player HP 0 จบเป็น defeat ก่อน HELP จึงไม่คืนชีพ.
Priority/target/reason codes, damage 1/help 4/reduction 2, speed 0.70, lunge 44px
และ compact formation ไม่เปลี่ยน.

### Registry / Atomic validation / Restart

`_register_actor()` ตรวจ factory คืน null และ `registry.has(id)` ก่อนเขียน;
ID ซ้ำคืน false โดยไม่ทับ object เดิม. Registry ยังเป็น local candidate จนสร้างครบ
ทั้งสามตัว. API ไม่มี input เปลี่ยน ID; focused test เรียก helper ภายในเพื่อยืนยัน
เส้นทางปฏิเสธ duplicate ที่ production builder ใช้จริง.

Restart ตรวจ unknown fields, HP types/ranges และ Resolver schema เดิมทั้งหมดก่อน
สร้าง candidates. หากผิด จะไม่เปลี่ยนแม้ generation, resource, queue หรือ actor
object เดิม. เมื่อผ่านจึงเพิ่ม generation, commit metadata ที่ลบ HP fields แล้ว
พร้อม registry ใหม่, ล้าง active/pending/self-defend/result และคืน round 1 ตามเดิม.
ไม่มี await/callback ระหว่าง commit. สร้าง object ใหม่เพื่อไม่ให้ HP จาก encounter เก่า
หรือ reference เก่ารั่วเข้า session ใหม่; callback generation เก่าถูกปฏิเสธก่อน effect.

Fixture change ใช้ snapshot ชั่วคราว + whitelist เดิม, validate ทุก field แล้วสร้าง
candidate RuntimeStates ใหม่ทั้งชุดก่อน commit โดยไม่เพิ่ม generation หรือเปลี่ยน
locked action. วิธีนี้ไม่ต้องมี setter ที่ข้าม validation; invalid multi-field change
ไม่สามารถเขียนได้เพียงบาง actor. ทั้ง input/snapshot/candidate เป็นข้อมูลชั่วคราว
ไม่ใช่แหล่ง mutable HP ที่ Encounter เก็บคู่กับ RuntimeState.

GDScript `_` เป็นข้อตกลง field ภายใน ไม่ใช่ private access control. ผู้เรียก production
ต้องใช้ API; focused harness เข้าถึง `_actors` เพื่อพิสูจน์ identity/ownership โดยตรง
และตรวจ metadata ไม่มี HP. ไม่เพิ่ม public mutable actor accessor.

### Focused acceptance / Expected และ Actual

| กลุ่ม focused test | Acceptance ที่ตรวจ | Actual |
| --- | --- | --- |
| registry-snapshot-ownership | Definition role/ID, RuntimeState type, independent HP, duplicate ID ไม่ overwrite, invalid factory, runtime-backed adapters, detached snapshots, metadata ไม่มี HP | PASS |
| effects-duplicates-bounds | ATTACK/HELP ครั้งเดียว, resource, DEFEND/minimum damage/expiry, enemy targets ทั้งสอง, cap/zero, duplicate effect/completion, defeat | PASS |
| atomic-fixture-restart-stale | Invalid multi-field restart/fixture ไม่เปลี่ยนข้อมูลหรือ object, valid fixture ไม่ปลด locked action, fresh restart objects, old references/stale callbacks ไม่แตะ HP/resource/queue | PASS |
| terminal-races-no-revival | Enemy ตายก่อน resolve, killing blow victory, queue drain/no counter, HELP ไม่ revive/cost หลัง Player defeat | PASS |

รวม **219 checks / 0 failures**. Acceptance S1–S11 และ playable presets/reasons/Tweens
ตรวจซ้ำด้วย harness M2A เดิมด้านล่าง; focused suite เพิ่มใหม่แยก ไม่ตัด assertion
หรือแก้ expected results ใน legacy suites.

### Verification — 2026-11-03

Tested implementation commit: `53029a0b2843f87149ee0a762cb677c496103b2a`.
Final HEAD เพิ่มเฉพาะเอกสาร/evidence; ดู SHA ใน PR/Git history.
Engine executable จริง: `/Applications/Godot.app/Contents/MacOS/Godot`,
version **4.7.2.stable.official.ed1daf0bf**.

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2b-02-final \
  --npc-proof --actor-proof --ownership-proof
```

| Stage | Expected / Actual | Exit |
| --- | --- | --- |
| Version / clean import / 13 parses | 4.7.2, zero unexpected errors / PASS | 0 each |
| Main scene / playable startup | No errors / PASS | 0 each |
| M2B-02 ownership | All focused acceptance / PASS — 219 checks | 0 |
| Combat regression | Both kill orders, dead skips/live counters, queue/lock/fallback, Attack/Defend/NPC2 Guard, victory/defeat, Restart / PASS — 14,395 checks | 0 |
| Negative suite | Exactly five expected errors / PASS — 983 checks | 0 |
| M2A-02 | S1–S11 and original effect contract / PASS — 412 checks | 0 |
| M2A-03 | Original playable HP/reason/scene/Tween/Restart / PASS — 5,166 checks | 0 |
| M2B-01 | Original actor foundation / PASS — 122 checks | 0 |
| Manual F6 at 1280×720 | Pacing, 44px lunge, compact formation, intent/target readability, animation | NOT RUN |

23 stages ผ่าน. จำนวน checks ของ baseline ทั้งห้าชุดเท่าเดิมทั้งหมด.
[Run record](evidence/m2b-02/run-record.json) เก็บ base/tested commit, command,
engine, evidence scope และข้อจำกัด;
[results](evidence/m2b-02/results.json) เก็บ command/exit/expected errors แต่ละ stage;
[raw logs](evidence/m2b-02/logs.txt) และ
[source manifest](evidence/m2b-02/source-sha256.json) ผูก source กับ snapshot.
ชุดแรกใน sandbox `/tmp/wanderer-m2b-02-first` import FAIL แม้ exit 0 เพราะ certificate
และ editor-settings permissions; เก็บ [failed results](evidence/m2b-02/initial-failed-results.json)
และ [failed import log](evidence/m2b-02/initial-failed-import.log). ไม่ผ่อนการตรวจ errors;
รอบ check/final รันนอก sandboxและไม่มี unexpected engine errors.

Headless ไม่ยืนยันคุณภาพภาพ/ความเข้าใจเหตุผลของผู้เล่น. Owner-reported M2A-03 manual
acceptance เป็นข้อมูลเดิมจาก task M2B-01 ไม่ใช่ agent F6 ของงานนี้.
ไม่มี main combat migration, UI/scene ใหม่, stats/items/inventory/equipment, AI framework,
Trust/Guidance ใหม่, save/load, Down/Death หรือ lore change.
หยุดที่ Draft PR เพื่อ review; ไม่ merge/enable auto-merge/delete branch หรือเริ่ม M2B-03/M2C.
