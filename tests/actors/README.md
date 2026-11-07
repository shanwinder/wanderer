# Actor Definition, Runtime State & Encounter Ownership

Proof ล่าสุด: [M4-03A — Isolated Queue / Eligibility Foundation](#m4-03a--isolated-queue--eligibility-foundation) — isolated candidate / รอ independent code/evidence review; current milestone authority อยู่ที่ index.

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

## M2C-02 — Multi-Actor Registry and Encounter Foundation

งาน data-only บน `codex/m2c-02-multi-actor-foundation` รอ review. ฐาน merged ที่ fetch/ตรวจ local/remote/merge-base ตรงกันคือ `90eb7d14a21b8349f4433cc48d4aeaa913613b07` หลัง PR #34. ไม่เปลี่ยน NPCProofEncounter/Resolver หรือ combat หลัก. สถานะ milestone อยู่ใน [docs index](../../docs/README.md#current-status-and-next-roadmap) เท่านั้น; M2C-01 เป็น Design Only ไม่ใช่การอนุมัติ D1–D13 ทั้งชุด.

### Contract and ownership

- [ActorRegistry](../../scripts/actors/actor_registry.gd) เป็น RefCounted เฉพาะ encounter เก็บ RuntimeState หนึ่งชุดต่อ ID พร้อม Definition และ membership. ใช้ validator ของ ActorDefinition เดิม; รับเฉพาะ validated Definition/RuntimeState ที่ ID/max HP ตรงกันและ HP ถูกต้อง. Register คัดลอก input เข้า ownership ของ registry จึงแก้ HP ผ่าน reference ที่ผู้เรียกเก็บไว้ไม่ได้. Public reads คืน Dictionary/Array/scalars เท่านั้น.
- [FullPartyEncounter](../../scripts/combat/full_party_encounter.gd) ถือ registry, `player_id`, `party_order` (NPC เท่านั้น), `enemy_order`, generation และ lifecycle booleans. Player อยู่ใน membership PARTY แต่มี identity แยก ไม่อยู่ใน NPC order. นี่ไม่ใช่ final turn order.
- Roster ต้องมี Player 1, NPC 0–3 และ Enemy 1–2. IDs ใช้ lowercase snake_case ตาม ActorDefinition ไม่บังคับชื่อเฉพาะ; fixture ใช้ `player`, `npc_01`–`npc_03`, `enemy_a`, `enemy_b`. Role PLAYER/NPC ใช้ membership PARTY; ENEMY ใช้ ENEMY. ID เดียวปรากฏได้ครั้งเดียวใน registry และ roster รวมทั้งหมด; ห้าม actor ตกหล่นจาก roster.
- `prototype_fixture(npc_count, enemy_count)` สร้าง Dictionary `{actors, player_id, party_order, enemy_order}`. แต่ละ actors entry ต้องมีเพียง `{definition, initial_hp}`; definition ใช้ schema M2B-01; initial_hp เป็น int 0..max เท่านั้น. Restart ไม่รับ null เป็น default HP. `restart(fixture)` คืน bool โดยไม่แก้ input.
- `register_actor(definition, runtime, membership)`, `unregister_actor(id)`, `reorder_party(order)` คืน bool. ห้ามเพิ่ม Player คนที่สอง/เกิน capacity/ลบ Player/ลบ Enemy ตัวสุดท้าย. NPC HP=0 ยังคงอยู่ใน roster; can_act=false ไม่แปลว่า Down/Death.
- Roster mutation ต้อง command_ready=true และ active_action=false. `set_lifecycle(bool, bool)` เป็น proof guard เล็ก ๆ ยังไม่มี action หรือ state machine. Restart ที่ถูกต้องทำได้แม้ locked และ reset booleans; input ผิดต้องรักษา lock เดิม.
- ถอด ID แล้ว registry เก็บ tombstone ใน session เดิมเพื่อป้องกัน remove→re-add reset HP. ข้อแลกเปลี่ยน: จะนำสมาชิก ID เดิมกลับไม่ได้จน Restart สร้าง session ใหม่; ยังไม่มี bench/recruitment/global database.
- `actor_snapshot(id)` / `snapshot()` คืนข้อมูลใหม่ทุกครั้ง แก้ nested dictionary/array แล้วไม่กระทบเจ้าของ. Unknown/wrong-type ID คืน `{}`. `available_enemy_ids()` derive จาก runtime.can_act ทุกครั้ง ไม่มี alive cache.
- `fixture_damage(id, amount, generation)` / `fixture_heal(...)` เป็น controlled data-proof boundary เท่านั้น (ไม่ใช่ Player/NPC combat execution). Amount เป็น int ≥0, clamp โดย RuntimeState เดิม; stale/wrong-type generation หรือ locked → REJECTED, unknown ID/amount ผิด → INVALID_INPUT, สำเร็จ → APPLIED + actual hp_delta. ไม่เพิ่ม Action/Effect framework หรือ party HELP resource.
- GDScript underscore เป็น convention ไม่ใช่ private access control. Tests จงใจอ่าน `_registry._actors` เพื่อพิสูจน์เจ้าของ/object identity; UI ต้องใช้ public snapshot API. Registry เก็บ current HP เฉพาะ RuntimeState ไม่มี authoritative HP Dictionary อีกชุด.

### ตัวอย่าง Reorder และ HP

Fixture เริ่ม Player 30/30, NPC1 10/10, NPC2 7/10, NPC3 3/10, A 15/15, B 12/12.
เรียก `fixture_damage("npc_02", 3, encounter.snapshot().generation)` ได้ NPC2 7→4 โดยอีกห้าตัว HP เท่าเดิม.
Reorder `[npc_01,npc_02,npc_03]` → `[npc_03,npc_01,npc_02]` เปลี่ยนเฉพาะ Array ของ IDs: NPC2 ยังเป็น npc_02, object เดิมและ HP 4.
Restart ด้วย fixture เดิมจึงได้ NPC2 HP 7 พร้อม RuntimeState ใหม่.

### Atomic Restart

ตรวจ schema → สร้าง registry candidate → validate IDs/roles/memberships/roster ทั้งชุด → commit registry + roster + generation. ถ้า actor ตัวสุดท้ายผิด จะทิ้ง candidate โดยไม่เปลี่ยนข้อมูล/object/generation/lock/tombstone เดิม. ถ้าผ่าน generation เพิ่มหนึ่ง, runtime ทุกตัวเป็น object ใหม่, tombstones ว่าง. Old runtime/registry references แก้ได้เฉพาะข้อมูลเก่าที่ไม่ใช่เจ้าของ encounter ใหม่; fixture callback ที่ถือ generation เก่าถูกปฏิเสธ.

### GDScript สำหรับผู้เริ่มต้น

- **Identity กับ Order:** ID เหมือนเลขประจำตัว; order เหมือนรายชื่อเรียงแถว ย้ายแถวไม่ควรเปลี่ยนเจ้าของ HP. การสร้าง RuntimeState ใหม่ตอน reorder จะเผลอล้างบาดแผล จึงเปลี่ยนแค่ Array.
- **Registry:** สมุดทะเบียนใช้ Dictionary ค้นจาก ID ไปยังเจ้าของข้อมูล ไม่ค้นจากตำแหน่งในแถว. `_actors[id]` จึงยังเป็นคนเดิมหลังสลับลำดับ.
- **Role กับ Membership:** Role บอกประเภท Player/NPC/Enemy ส่วน membership บอก PARTY/ENEMY. Player กับ NPC อยู่ฝ่ายเดียวกันแต่มีบทบาทต่างกัน; ไม่ใช้ตำแหน่ง Array เดา role.
- **RefCounted:** object ข้อมูลที่ไม่ต้องเป็น Node ใน scene; ถูกคืนหน่วยความจำเมื่อไม่มี reference ใช้แล้ว. ไม่ต้องเพิ่ม singleton/Resource/.tres สำหรับ proof นี้. ถ้า tests เก็บ reference เก่าไว้ มันยังมีชีวิตอยู่แต่ไม่ได้เป็นเจ้าของ encounter ใหม่.
- **Dictionary:** คู่ key→value เช่น actor_id→RuntimeState; **Array:** รายการมีลำดับ เช่น party_order. Dictionary ที่เก็บ object ไม่ใช่สำเนา object; จึงห้ามส่ง `_actors` ให้ UI.
- **Snapshot Isolation:** สร้าง dictionary จาก scalar snapshot ของแต่ละ object และสำเนา Array. ผู้เรียกแก้ snapshot ได้เพื่อทดลอง แต่แก้ของจริงไม่ได้. `duplicate(true)` ของ container ไม่ได้แปลว่าจะ clone RefCounted ข้างใน จึงต้องสร้าง snapshot จาก object ก่อน.
- **Atomic Mutation:** ตรวจให้ครบก่อนเขียนเหมือนตรวจใบรายการทั้งหมดก่อนบันทึก ห้ามลงทะเบียนครึ่งชุดแล้วค่อยพบ ID ซ้ำ. Restart ใช้ candidate ส่วน register/reorder ตรวจเงื่อนไขทั้งหมดก่อนเปลี่ยน field.
- **Runtime State Ownership:** Current HP อยู่ใน ActorRuntimeState เพียงที่เดียว; snapshot เป็นภาพข้อมูลตอนอ่าน ไม่ใช่เจ้าของ. ลอง damage 3 แล้วอ่านใหม่จะเห็น 4 แต่ snapshot เก่ายังคงค่าเดิมตามเวลาที่อ่าน.

### Focused acceptance mapping

[party_foundation_proof.gd](party_foundation_proof.gd) ใช้ทั้ง public contract และ white-box ownership probes; ไม่มีการแก้ assertions เดิม.

| Criteria | วิธีพิสูจน์ / expected |
| --- | --- |
| F01–F05 | NPC 0/1/2/3 × Enemy 1/2; Player หนึ่ง, unique IDs และ membership ครบ |
| F06–F08 | Role/membership/ID/max mismatch, duplicate Definition IDs, bare object, invalid types/bounds → reject ก่อน overwrite |
| F09–F12 | NPC2 7→4 independent; live RuntimeState probe; damage/heal clamp; HP0 อยู่ roster แต่ unavailable |
| F13–F14 | Snapshot ไม่มี object; แก้ nested/input container ไม่รั่ว; reorder ทุก actor values/object identity คงเดิม |
| F15–F17 | Invalid/duplicate/unknown reorder, locked register/unregister, capacity, remove→re-add tombstone → atomic rejection |
| F18–F20 | Valid restart เปลี่ยน roster/generation/runtime; invalid schema/last candidate ไม่เปลี่ยนอะไร; old references/stale generation inert |
| F21 | Enemy damage ถึง0 → available list ว่าง; heal → available กลับจาก runtime ไม่มี alive cache |
| F22 | รัน Combat/negative/M2A-02/M2A-03/M2B-01/M2B-02 เดิมครบ |

### Verification command and evidence

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2c-02-final \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof
```

เลือก output ใหม่ทุกครั้ง; flag ใหม่ใช้เดี่ยวได้โดยยังรัน baseline combat เสมอ. Manual F6 **NOT RUN** เพราะเป็น data-only; ไม่มี visual acceptance ใหม่. M2C-03/M2C-04/action resolution/multi-NPC decisions/playable scene/items/equipment/Down/Death/full AI/lore ไม่ได้ implement. Speed 0.70, lunge 44px และ Compact Formation คงเดิม.

ผลรันใหม่วันที่ 3 พฤศจิกายน 2026 บน tested commit `a7cf38d` ด้วย engine จริง `4.7.2.stable.official.ed1daf0bf`: **PASS 29 stages**, runner exit 0; ทุก stage exit 0, ไม่มี unexpected errors. Parse 18 ครั้ง (รวม dependency parses ของ flag ใหม่), clean import, main/playable startup ผ่าน. Subsequent HEAD เพิ่ม docs/evidence เท่านั้น; runtime/tests/scenes/assets/project bytes ตรงกับ tested commit และ imported snapshot ตาม manifest.

| Suite | Expected / Actual | Exit |
| --- | --- | --- |
| M2C-02 F01–F21 | PASS — 382 checks, 0 failures | 0 |
| Combat | 14,395 / 14,395 checks | 0 |
| Negative | 983 / 983 checks + exactly 5 expected errors | 0 |
| M2A-02 | 412 / 412 checks | 0 |
| M2A-03 | 5,166 / 5,166 checks | 0 |
| M2B-01 | 122 / 122 checks | 0 |
| M2B-02 | 219 / 219 checks | 0 |
| Manual F6 | NOT RUN | — |

หลักฐาน durable: [run record / full SHA / command / expected-actual](evidence/m2c-02/run-record.json), [stage results / exit codes / exact errors](evidence/m2c-02/results.json), [raw logs / engine logs / exits](evidence/m2c-02/logs.txt), [source SHA-256 manifest](evidence/m2c-02/source-sha256.json). ผล M2A/M2B เดิมในหัวข้อก่อนหน้าเป็น inherited evidence ตาม commit เดิม; ตารางนี้เป็นผลที่รันใหม่ของ M2C-02.

## M2C-03 — Multi-NPC decision and turn resolution proof

**Data-only feature branch, pending Draft review; ยังไม่ merge และไม่เชื่อม Combat หลัก.**
ฐานที่ยืนยันว่า merge แล้วคือ PR #35/M2C-02, `335427450026fcb4ef0c7d4f236df259f193dbe2`.
ตอนเริ่ม working tree สะอาด, local/remote HEAD/merge-base ตรงกัน, ไม่พบ branch/PR M2C-03 ซ้ำ.
Open PR #2/#17 ไม่ถูกใช้เป็น canonical หรือแก้ไข. ใช้ branch เดียว
`codex/m2c-03-multi-npc-turn-proof` ไปยัง `visual-combat-test-1`.
สถานะ milestone ปัจจุบันอยู่ใน [docs index](../../docs/README.md#current-status-and-next-roadmap);
หัวข้อ M2C-02 ด้านบนเก็บผล/ข้อจำกัดของงานครั้งนั้น ไม่ใช่สถานะล่าสุดของ M2C-03.

### Approved prototype decisions

ก่อนอนุมัติ ทั้งชุดมีสถานะ **PROTOTYPE — Pending Owner Approval**.
เจ้าของอนุมัติ “D1–D13 สำหรับ M2C-03” ใน chat วันที่ 3 พฤศจิกายน 2026;
ปัจจุบันเป็น **PROTOTYPE — Owner Approved** เฉพาะ proof นี้ ไม่ใช่ Final Gameplay/Balance.

| Decision | Contract ที่ใช้ |
| --- | --- |
| D1 | Stable Actor ID, unique ภายใน Encounter; ID ไม่เปลี่ยนตามตำแหน่งใน Array |
| D2 | Player → NPC ตาม Party Order → Enemy ตาม Enemy Order |
| D3 | NPC ตัดสินใจหนึ่งครั้งเมื่อตนถึง slot จาก state ล่าสุด |
| D4 | NPC ATTACK เลือก enemy ที่พร้อมตัวแรกตาม Enemy Order |
| D5 | NPC แต่ละคนมี HELP 1 use ต่อ Encounter |
| D6 | HELP ต่อกันได้หาก Player ยัง HP ≤30% เมื่อ NPC คนนั้นตัดสินใจ |
| D7 | HELP ให้ Player เท่านั้น; ไม่มี NPC-to-NPC HELP |
| D8 | HP0 unavailable; Player HP0 คือ Defeat; HELP ไม่คืนชีพ |
| D9 | Fallback ก่อน lock; หลัง lock เป้าหมายตายให้ SKIP ไม่เปลี่ยนเป้าหมาย |
| D10 | Encounter owns action token: identity/generation/round/action/actor; presentation epoch แยกเป็นงานภายหลัง |
| D11 | Data Fixture → Playable Proof → Review ก่อน Main Combat; PR นี้ทำเฉพาะ Data Fixture/turn proof |
| D12 | ตรวจ next still-valid declared hit ที่เล็ง NPC ตนเอง; ไม่รวม damage ของสอง hit เป็นก้อน |
| D13 | NPC Self-DEFEND ลด next valid hit2 ขั้นต่ำ1; guard ที่เหลือหมดอายุสิ้นรอบ |

ค่าตัวเลขใช้ Prototype Defaults ใน task ที่แนบ: Player ATTACK5, NPC ATTACK1,
Enemy ATTACK3, HELP4 (clamp Max HP), DEFEND ลด2 ขั้นต่ำ1.
Player DEFEND ลดทุก enemy hit ที่เกิดในรอบนั้น; NPC Self-DEFEND ลดเฉพาะ hit ถัดไปที่เล็งตน.
นี่ไม่ใช่ Legacy NPC2 Guard Player และไม่เปลี่ยน balance ของ main combat.

### Architecture / files changed

- [FullPartyEncounter](../../scripts/combat/full_party_encounter.gd) ต่อ foundation เดิมด้วย round, pending slots, locked action, generation/action ID, HELP ledger, guards, declared hits และ terminal result. Registry/RuntimeState เดิมเป็นเจ้าของ HP.
- [NPCDecisionResolver](../../scripts/npc/npc_decision_resolver.gd) เพิ่ม `decide_for_actor(actor_id, context)` กับ strict multi-actor schema และใช้ `_policy()` ร่วมกับ `decide(snapshot)` เดิม. Legacy `validate_snapshot()` ไม่เปลี่ยน; schema เดิมยัง reject multi-enemy IDs.
- [Focused harness](party_turn_proof.gd) + UID เพิ่ม P1–P16/edge cases; [verify.py](../combat/verify.py) เพิ่ม `--party-turn-proof` เป็น opt-in อิสระ.
- README, docs index, Actor/Combat test guide เดิมอัปเดตสถานะ/learning/evidence ในที่เดิม; evidence ใหม่อยู่ [m2c-03](evidence/m2c-03/run-record.json).

ไม่มีการแก้ Actor Definition/RuntimeState/Registry, legacy tests, legacy Combat
Controller/Turn Flow/Targets, NPCProofEncounter/playable controller, scenes, assets
หรือ project settings. Speed0.70, lunge44px และ Compact Formation คงเดิม.

### Public contract / multi-NPC decisions

`restart(fixture)`, `snapshot()`, `actor_snapshot(id)`, `reorder_party(order)` และ
ready-only register/unregister/fixture damage/heal ยังคงอยู่.
`set_lifecycle()` เป็น guard ของ foundation fixture เท่านั้น; ใช้ปลดล็อก live queue/terminal ไม่ได้.
Roster mutation ทำได้เฉพาะ command-ready ไม่มี action/round ที่กำลังรัน; reorder ไม่ reset HP/HELP.
Fixture schema เดิมคง strict; initial HELP1 ต่อ NPC และไม่เพิ่ม field ใหม่ใน fixture.

```gdscript
var encounter = preload("res://scripts/combat/full_party_encounter.gd").new()
# {} = Enemy A/B ประกาศโจมตี Player ตาม enemy order
encounter.begin_round("ATTACK", "enemy_a", {})
var token: Dictionary = encounter.begin_next_action()
encounter.resolve_action(token)
encounter.complete_action(token)
# เรียก begin_next_action() ต่อเมื่อ slot ก่อนหน้าจบ; ไม่เรียก complete_npc() เดิม
```

`begin_round(action, target_id="", enemy_targets={})` รับ Player ATTACK/DEFEND เท่านั้น.
Enemy declarations map จาก enemy ID → Player/NPC ID; ค่า default คือ Player.
Unknown ID/ผิด membership/type ถูก reject ก่อน state เปลี่ยน. Damage enemy คง3.
Known selected enemy ที่ HP0 fallback ก่อน Player lock ได้; unknown ID ไม่ fallback.
`begin_next_action()` เลือก NPC decision ตอนถึง slot; ไม่มีสาม decisions ที่คำนวณไว้ล่วงหน้า.

`decision_context()` คืน detached actors/roster/HELP/declarations/revision;
ก่อนเริ่มรอบ declarations ยังว่าง จึงยังไม่ใช่ valid resolver context.
`decide_for_actor()` คืน actor_id/action/target_id/reason_code/reason_details/snapshot_revision.
Resolver เป็น pure function: ไม่แก้ HP, resource หรือ queue; explanation เป็น historical snapshot
ที่แก้แล้วไม่กระทบ context. `snapshot_revision` เพิ่มเมื่อ command/effect/ready fixture mutation/roster
เปลี่ยน และ reset เมื่อ Restart; ใช้คู่ generation เพื่อแยก session.

Policy priority: Player defeated → no living enemy → actor unavailable → self low/lethal threat
→ Player low HP HELP (หรือ HELP_UNAVAILABLE_ATTACK) → ATTACK_AVAILABLE_ENEMY.
เก็บ reason codes เดิมสำหรับสถานการณ์เทียบเท่ากัน; self target ใช้ stable NPC ID จริง.
NPC0 ยังอยู่ Registry และได้ SKIP slot; ไม่ใช่ Party Defeat.

### Queue / locked action / token lifecycle

Queue เป็น Array ของ IDs ที่ยัง **PENDING**; เมื่อ pop slot จึงสร้าง record **LOCKED**.
`resolve_action(token)` เปลี่ยนเป็น **RESOLVED** หรือ **SKIPPED**;
`complete_action(token)` เปลี่ยนเป็น **COMPLETED** แล้วจึง dispatch slot ต่อได้.
มี active action ได้หนึ่งตัวเสมอ. Completion ไม่ลง effect และไม่ยิง enemy response เอง.
เมื่อคิวหมด completion สุดท้ายเพิ่ม round/completions ครั้งเดียวและปลด command lock.
Victory/Defeat ยกเลิก pending slots ไม่เพิ่ม round/counter/action ใหม่;
active effect ที่ทำให้ terminal ยังต้อง complete เพื่อปิด lifecycle.

Token ต้องตรงกับ internal record ทั้ง `encounter_id`, `generation`, `round_id`,
`action_id`, `actor_id` รวมชนิดข้อมูล. การส่ง token จาก Encounter อื่นแม้ generation/action ID
เท่ากันถูก reject. Early completion, duplicate resolve/completion, old slot หรือ old generation
ไม่เปลี่ยน HP/HELP/queue/round. Caller แก้ decision/action/target/reason/state ใน token ได้
แต่ effect อ่านค่าจาก locked internal record เท่านั้น. Token เป็น callback identity ภายใน process;
ไม่ใช่ security credential สำหรับ network/multiplayer.

Enemy declarations ถูก lock ตลอดรอบ. หาก declared target ไม่พร้อมที่ effect ให้ SKIP;
ไม่มี automatic retarget. NPC ถัดไปเลือก target ใหม่ก่อน lock ได้. Dead enemy ยังอยู่ Registry
แต่ไม่โจมตีและไม่นับเป็น threat. D12 ดู hit แรกที่ยังพร้อมและเล็ง NPC ตนเองตาม Enemy Order.

### HELP ownership / guard / Restart

HELP ledger keyed by NPC ID; หัก1 เฉพาะ effect ที่ heal ได้จริง ไม่หักเมื่อ invalid token,
actor/Player HP0 หรือ Player เต็ม. Decision ไม่ใช้ resource; reorder ไม่ reset.
Self-DEFEND keyed by NPC ID; hit ที่เล็งสมาชิกอื่นไม่ consume/ใช้ guard นั้น.
NPC guard ใช้หนึ่ง valid hit; Player guard ใช้ทุก hit ในรอบ; ทั้งหมด clear เมื่อจบรอบ/terminal/Restart.

Restart validate fixture และสร้าง candidate Registry/RuntimeState ครบก่อน commit.
Invalid candidate แม้ผิด actor สุดท้ายไม่เปลี่ยน session เดิม. Valid Restart เพิ่ม generation,
reset round1/completions0, queue/token/action IDs/HELP1/guards/result และสร้าง runtime objects ใหม่;
คำนวณ terminal จาก fixture ทันที หาก Player0 ให้ DEFEAT หรือ enemies0 ทั้งหมดให้ VICTORY และล็อก command.
Old timer callback + retained old Registry/RuntimeState เปลี่ยน Encounter ใหม่ไม่ได้.
Foundation fixture API ยังคง heal HP0 ได้เพื่อทดลอง data contract เดิม; combat HELP ตรวจ availability
ก่อน heal เสมอ. Terminal ตรวจตอน Restart และ command/dispatch/effect/completion.
Ready-only fixture damage/heal ยังเป็น data experiment ตาม contract เดิม; เมื่อเริ่ม command
จะตรวจ terminal จาก runtime อีกครั้งก่อนสร้าง queue.

### ตัวอย่างหนึ่งรอบเต็ม / expected = actual

Fixture Player6/30, NPC1/2/3 HP10/7/3, A15, B12; declarations A/B→Player.

| Slot | Action / Target / Reason | Effect / state หลังลงผล |
| --- | --- | --- |
| Player | DEFEND / player / PLAYER_COMMAND | guard Player ทั้งรอบ |
| NPC1 | HELP / player / PLAYER_LOW_HP_HELP | Player6→10; HELP NPC1:1→0 |
| NPC2 | ATTACK / enemy_a / ATTACK_AVAILABLE_ENEMY | อ่าน Player10; A15→14 |
| NPC3 | ATTACK / enemy_a / ATTACK_AVAILABLE_ENEMY | อ่าน Player10; A14→13 |
| A | ATTACK / player / ENEMY_DECLARED_TARGET | Player10→9 (3−2=1) |
| B | ATTACK / player / ENEMY_DECLARED_TARGET | Player9→8 (3−2=1) |
| Completion | Queue ว่าง | round2, completions1, ready; guards ว่าง, HELP NPC2/3 ยัง1 |

### Focused acceptance P1–P16 / actual results

[scenarios.json](evidence/m2c-03/scenarios.json) บันทึก input, expected, actual และ action traces;
[raw logs](evidence/m2c-03/logs.zip) มี full `SCENARIOS_JSON` และผล assertions เพิ่มเติม.
แต่ละแถวด้านล่างเป็น **PASS** จากรันปัจจุบัน ไม่ใช่อนุมานจาก code inspection.
P7/P8 ใช้ combined case; P16-policy ตรวจ API ส่วน full P16 regression อยู่ใน runner.

| Scenario | Input → Expected Decision / Target / Reason / Effect / Queue | Actual |
| --- | --- | --- |
| P1 | Player + NPC1 + A; Player ATTACK5, NPC ATTACK A1 (ATTACK_AVAILABLE_ENEMY), A→Player3; A9 Player27 round2 | PASS |
| P2 | Player + NPC3 + Enemy2; all NPC ATTACK A1 each; A7 B12 Player24; 6 slots, completion1 | PASS |
| P3 | NPCทั้งสาม ATTACK A / ATTACK_AVAILABLE_ENEMY หลัง Player ATTACK; A7 Player27 กับ enemy1 | PASS |
| P4 | Player6 DEFEND; NPC1 HELP→10; NPC2/3 ATTACK A; Player8 A13, ledger0/1/1, round2 | PASS |
| P5 | NPC1 HP3, A/B→NPC1: SELF_LOW_HP_THREAT DEFEND; NPC2/3 ATTACK; hit1 แล้ว hit3 clamp2; NPC1 HP0 ไม่ defeat; round2 | PASS |
| P6 | Player6, NPC1 HP3, A→NPC1 B→Player: NPC1 DEFEND, NPC2 HELP, NPC3 ATTACK; reasons ต่างกัน; NPC1 HP2 Player9 | PASS |
| P7 | Playerฆ่า A HP5; NPC1/3 เลือก B, A SKIP, B counter; B10 Player27 round2 | PASS |
| P8 | NPC2 HP0 → SKIP ACTOR_UNAVAILABLE ยังอยู่ registry; midround NPC0 ก่อน slot ก็ SKIP | PASS |
| P9 | Player1 → HELP1→5→9→13; ledgerแต่ละคน0; reorderคง resource; รอบถัดไป HP6 → HELP_UNAVAILABLE_ATTACK ทั้งสาม | PASS |
| P10 | NPC1 lock A แล้ว fixture ทำ A0: TARGET_DEAD_BEFORE_RESOLVE SKIP; ไม่ตี B; NPC2 เลือก B ใหม่; queueจบ | PASS |
| P11 | Restartระหว่าง NPC HELP ก่อน/หลัง effect; delayed old callbacks reject; new ledger/queue/HP ไม่เปลี่ยน; fresh roundผ่าน | PASS |
| P12 | Restartระหว่าง Enemy action ก่อน/หลัง effect; old runtime/callback inert; new session เล่นจบรอบได้ | PASS |
| P13 | early/duplicate resolve/completion + prior action ID reject; ATTACK/HELP/DEFEND/enemy effect ลงครั้งเดียว; roundครั้งเดียว | PASS |
| P14 | A-first/B-first แล้ว final kill; victoryหยุด slots; Player3 ถูก Aฆ่า → defeatหยุด B ไม่มี phantom round | PASS |
| P15 | Invalid PlayerAction/ID/membership/foreign token/wrong types/generation/busy mutation; rejectโดย HP/resource/queue/roundไม่เปลี่ยน | PASS |
| P16 | Legacy strict schema/reasons + Combat/M2A/M2B/M2C-02 เดิมครบ; ไม่มีลด assertions หรือแก้ expected เดิม | PASS |

Edge cases เพิ่ม: NPC0 roster, no available enemy, normal queue exhaustion,
unknown vs known-dead target, busy unregister/register/reorder และ bypass lifecycle,
HELP clamp MaxHP4, HELP invalidated เมื่อ Player defeated/full หรือ actor dead,
next-hit3 vs aggregate6 ที่ NPC HP4, SELF_LETHAL_THREAT ที่ HP3/Max5,
dead enemy threat ignored, two hits on same self guard, unused guard expiry,
enemy declared target HP0 (skip ไม่ retarget), external token action/target/reason mutation,
nested snapshot isolation, custom stable IDs และ strict malformed context fields.
Tests ใช้ white-box Registry mutations เฉพาะจำลองเป้าหมาย/actor เปลี่ยนหลัง lock;
ไม่มี public busy mutation escape hatch หรือ scene ใหม่.

### Verification / durable evidence / limitations

Tested commit: `0f33e1b1121ac49a297314477336d89f269d96e5`.
Actual engine: **`4.7.2.stable.official.ed1daf0bf`**. วันที่ 3 พฤศจิกายน 2026.
หลัง commit นี้เปลี่ยนเฉพาะ docs/evidence; Final HEAD รายงานใน Draft PR (ไม่ใส่ self-referential SHA ใน commit ของตัวเอง).

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2c-03-final-2 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof --party-turn-proof
```

| Suite/stage | Expected / Actual | Exit |
| --- | --- | --- |
| Version / clean import / 21 parses | PASS, zero unexpected errors | 0 each |
| Main + existing NPC playable startup | PASS | 0 each |
| M2C-03 | PASS — 1,250 checks, 0 failures | 0 |
| Combat | 14,395 / 14,395 checks | 0 |
| Negative | 983 / 983 checks + exactly five expected errors | 0 |
| M2A-02 | 412 / 412 checks | 0 |
| M2A-03 | 5,166 / 5,166 checks | 0 |
| M2B-01 | 122 / 122 checks | 0 |
| M2B-02 | 219 / 219 checks | 0 |
| M2C-02 | 382 / 382 checks | 0 |
| Manual F6 / presentation acceptance | **NOT RUN** — data-only, ไม่มี scene ใหม่ | — |

**33 stages PASS, runner exit0.** ไม่มี unexpected engine errors แม้ stage exit0.
จำนวน legacy checks ไม่เปลี่ยน; เพิ่ม 1,250 checks ใน harness ใหม่เท่านั้น.
รอบ exploratory แรก import FAIL เพราะ sandbox ปิด certificate/editor settings แม้ engine exit0;
ไม่ลบ error หรือเปลี่ยน expected เพื่อให้ผ่าน. รันใหม่ด้วยสิทธิ์ที่จำเป็นแล้วผ่าน.
[run-record.json](evidence/m2c-03/run-record.json) ระบุ engine/base/tested commit/command/exits,
[results.json](evidence/m2c-03/results.json) เก็บทุก stage,
[logs.zip](evidence/m2c-03/logs.zip) เก็บ stdout/engine logs/.exit ของ final run,
[source-sha256.json](evidence/m2c-03/source-sha256.json) ตรวจ source ตรงกับ tested commit และ imported snapshot.
[initial-failed-results.json](evidence/m2c-03/initial-failed-results.json) และ
[initial-failed-import.log](evidence/m2c-03/initial-failed-import.log) เก็บข้อจำกัดรอบแรก.

ข้อจำกัด: ไม่ใช่ full NPC AI; ไม่มี personality/trust/Guidance ใหม่, item/equipment,
Down/Death/permadeath, save/load, multiplayer, scene/Tween/animation integration หรือ visual proof.
ไม่มี presentation epoch เพราะยังไม่มี presentation callbacks ใน proof นี้; เมื่อทำ M2C-04 ต้องออกแบบ
แยกจาก encounter token ตาม D10 และผ่าน review ตาม D11 ก่อนแตะ main combat.
M2C-04 **NOT IMPLEMENTED**, M2B-03 Item Implementation **DEFERRED**.
หยุดหลัง Draft PR เพื่อ review; ไม่ merge/auto-merge/delete branch หรือเริ่ม milestone ใหม่.

### GDScript learning notes — ภาษาไทย

1. **Array/Dictionary สำหรับ Queue:** Array เก็บลำดับ เช่น `[player,npc_01,enemy_a]`; `pop_front()` เอา slot หน้าออก. Dictionary เก็บข้อมูลตาม key เช่น `_help_uses[npc_id]`. Queue ไม่เก็บ HP เพราะจะเสี่ยงมีค่าเก่าหลายชุด.
2. **Actor ID กับ Actor Order:** ID คือ “คนไหน” ส่วนตำแหน่งใน Array คือ “ถึงคิวเมื่อไร”. ย้าย NPC3 ไปก่อน NPC1 เปลี่ยนลำดับได้โดย HP/HELP ยังผูก ID คนเดิม.
3. **Snapshot และ Pure Resolver:** snapshot คือภาพข้อมูลตอนนั้น. Resolver อ่านภาพแล้วคืนคำตัดสิน ไม่เปลี่ยนเกม. NPC2 ต้องขอภาพใหม่หลัง NPC1 ลงผล จึงเห็น Player10 และเลือก ATTACK แทน HELP ซ้ำจาก HP6 เก่า.
4. **Action State Machine:** เหมือนบัตรงาน: รอ → ล็อก → ลงผล/ข้าม → เสร็จ. `resolve_action()` รับเฉพาะ LOCKED; `complete_action()` รับเฉพาะ RESOLVED/SKIPPED จึงกดจบก่อนลงผลไม่ได้.
5. **Locked Decision:** หลังเริ่ม action แล้วถือคำตัดสินภายในเป็นใบงานจริง. ต่อให้คนเรียกแก้ Dictionary ที่ส่งกลับ ก็เปลี่ยนการโจมตีเป็น HELP กลางทางไม่ได้. หากเป้าหมายตายให้ข้ามแทนย้ายเป้ากลาง animation ในอนาคต.
6. **Token/Generation:** Token เหมือนเลขใบงานที่บอก encounter/รอบ/คน/action; generation คือรุ่นของการเริ่ม Encounter. Restart เพิ่มรุ่น ทำให้ใบงานรุ่นเก่าถูกปฏิเสธแม้ action_id เริ่มนับใหม่.
7. **Exactly-Once Effect:** HP/resource เปลี่ยนใน resolve ครั้งแรกเท่านั้น; เปลี่ยน state ทันทีหลังลงผล. callback เดิมมาอีกครั้งเจอ state เปลี่ยนแล้วจึงไม่หัก HP/HELP ซ้ำ. Completion จัดคิวอย่างเดียว.
8. **Restart และ Stale Callback:** สร้างข้อมูลใหม่ใน candidate ก่อนตรวจครบแล้วค่อยสลับ owner. callback เก่าที่ timer ยังยิงจะเจอ generation ผิด; แม้มี reference runtime เก่าอยู่ก็เป็น object ของ session เก่า.
9. **Single Source of Truth:** HP จริงอยู่ `_current_hp` ใน ActorRuntimeState จุดเดียว. Registry/Encounter ขอ snapshot ตอนอ่านและลงผลผ่าน runtime damage/heal. Queue, decision explanation และ UI ในอนาคตเก็บได้เพียงข้อมูลอ่าน/ประวัติ ไม่เขียน current HP อีกชุด.

ลองไล่ P4 ใน `party_turn_proof.gd`: หา `begin_round("DEFEND")` → Player slot → NPC1 HELP
→ อ่าน HP10 → NPC2 ATTACK. จากนั้นดู P11/P12 ว่าทำไม callback เก่าจึงไม่เปลี่ยน HP ใหม่.

## M4-01 — Isolated Data/State Proof Candidate

> **Current status — 5 พฤศจิกายน 2026:** **M4-01 — Isolated Data/State Proof Implemented / Merged / Automated Proof Recorded**. [PR #46](https://github.com/shanwinder/wanderer/pull/46) merged ที่ `e6c3cab7291a3cd45dcacdf48406cf48f0d67118`; tested sourceยัง `0b3fd961b305e6c74027f35203b77505457f5409`. 78 cases/525 checks,69 stages PASS,Legacy6cases/5,892framesด้านล่างเป็น **Inherited Evidenceจาก PR #46 ไม่ใช่รันใหม่ใน M4-02**. ชื่อ Candidate/ข้อความ review pending/stop/“งานนี้” ด้านล่างเก็บ checkpointการส่ง PR #46และ original verification attribution. Historical PR #47 checkpoint: M4-02 มี scoped owner approval เฉพาะเอกสาร [reviewed design approval](../../docs/M4_02_Rescue_Clock_Death_Contract.md#10-owner-decision-register-and-exact-approval-wording); ไม่เปลี่ยน M4-01 proof code/tests/evidence, ไม่ใช่ Playable/Full M4. [Index](../../docs/README.md#current-status-and-next-roadmap) ถือสถานะล่าสุด.

วันที่ **5 พฤศจิกายน 2026 (Asia/Bangkok)**; owner อนุญาต implementation โดยตรงในคำสั่ง
“WANDERER — M4-01 Isolated Data / State Proof”. ฐาน canonical `visual-combat-test-1` คือ
`70922a60cdfcb10c2507bab6b6e8a434a213a037` หลัง PR #45 merged; local HEAD,
fetched remote/live remote และ merge-base ตรงกัน, working tree สะอาดก่อนเริ่ม.
ตรวจ open PR #2/#17, local/remote branches แล้วไม่มี M4-01 ซ้ำ; ไม่รวม PR เหล่านั้น.
Branch เดียว `codex/m4-01-isolated-data-state-proof`. **Candidate — implementation บน feature
branch และ automated data proof ผ่านแล้ว; ยังรอ Independent Code Review ไม่ใช่ merged/owner acceptance.**
[Milestone Authority](../../docs/README.md#current-status-and-next-roadmap) และ
[approved design / pending register](../../docs/M4_Down_Help_Death_Retreat_Architecture.md#14-open-decision-register).

### Goal / isolation strategy

พิสูจน์ D01 Option A, D02 Option B, D12 Option A เฉพาะข้อมูล/ownership/authorized fixture damage.
Source inspection พบว่า production ActorRuntimeState มีแต่ HP, `can_act()` อ่าน HP>0 และ raw
`heal()` เพิ่มจาก HP0 ได้; Registry reconstruct ด้วย original HP snapshot; FullPartyEncounter ใช้
classes เหล่านี้จริง; Resolver และ Guidance Layer ตรวจ exact schemas. จึงใช้ counterpart แยก:

| Source | หน้าที่ |
|---|---|
| [isolated_actor_state.gd](../../scripts/m4/isolated_actor_state.gd) | RuntimeState เฉพาะ Party; validated factory/snapshot reconstruction; ไม่มี raw damage/heal setter |
| [isolated_registry.gd](../../scripts/m4/isolated_registry.gd) | copy-in/copy-out; เก็บ owned runtime หนึ่งชุดต่อ ID; commit ต้องมี Encounter-owned capability |
| [isolated_encounter.gd](../../scripts/m4/isolated_encounter.gd) | validated Restart; session/generation/revision; explicit fixture grant และ exactly-once application |
| [m4_data_state_proof.gd](m4_data_state_proof.gd) | independent data cases, exact rejection/no-delta checks, production compatibility |

ทั้งหมดใช้ RefCounted ไม่ใช้ Resource/shared singleton. Production ไม่ preload M4 files,
ไม่แก้ original RuntimeState/Registry/FullPartyEncounter/GuidedEncounter/Resolver/Decision Layer,
scenes/UI/Tween/animation/sprites/config. ไม่มี HP authority สำรองใน Encounter;
Registry ถือ RuntimeState ส่วน snapshots เป็นข้อมูลที่คัดลอกเพื่ออ่าน.

### Data / snapshot contract

| LifeState | Participation | HP | Derived `eligible` |
|---|---|---|---|
| ALIVE | PRESENT | int 1..Max | true |
| DOWN | PRESENT | int 0 | false |
| DEAD | PRESENT | int 0 | false |
| ALIVE | RETREATED | int 1..Max; รักษาค่า fixture เดิม | false |

DOWN/RETREATED และ DEAD/RETREATED reject; ALIVE HP0, DOWN/DEAD HP>0 และ HP นอกช่วง reject.
`UNAVAILABLE` ไม่ใช่ LifeState. `eligible` หมายถึงข้อมูลความพร้อมใน proof เท่านั้น;
ไม่เพิ่ม action-specific targeting/queue/terminal rules ของ M4 ที่ยัง Pending.

`create(definition, fixture)` รับ exact fields `current_hp:int`, `life_state:String`,
`participation:String`; Definition ต้องผ่าน factory เดิมและ role PLAYER/NPC.
Invalid input คืน null โดยไม่คืน partial state; ไม่แปลง bool/float/string เป็น int.
Snapshot ใหม่มี **8 fields** เท่านั้น:

| Field | Type / constraint |
|---|---|
| `schema_version` | int = 1 |
| `actor_id` | String ตรง validated Definition |
| `role` | String PLAYER/NPC ตรง Definition |
| `max_hp` | int > 0 ตรง Definition.base_max_hp |
| `current_hp` | int 0..max_hp และสอดคล้อง LifeState |
| `life_state` | String ALIVE/DOWN/DEAD ตาม valid pair |
| `participation` | String PRESENT/RETREATED ตาม valid pair |
| `eligible` | bool คำนวณจาก ALIVE/PRESENT; caller เปลี่ยนค่าตอน reconstruction ไม่ได้ |

`from_snapshot()` ตรวจ exact fields/types/invariants/identity/derived value แล้วสร้าง object ใหม่.
Backing dictionary เป็น read-only scalar data; ทุก accessor คืน detached copy.
Registry row เป็น exact `definition`, `state`, `membership`; Encounter snapshot เป็น
`schema_version`, `session_id`, `generation`, `revision`, `actors`. Registry ไม่เปิด owned reference.
Duplicate ID/invalid runtime/foreign ID/role/max/derived field reject ก่อน publish.
ไม่มี unregister/archive/summary API ใน proof; unregister เดิมใน production ไม่ได้เปลี่ยนเป็น Death/Retreat.

Enemy ใช้ original ActorRuntimeState ที่ registry copy เข้าใหม่; HP0 คืน exact original fields
`actor_id/current_hp/max_hp/can_act=false` **ไม่มี LifeState/Participation และไม่มี DEAD mapping**.
Snapshot ใหม่นี้ไม่ถูกส่งเข้า Resolver หรือ Guidance v1. Production compatibility checks ยืนยัน
original runtime4fields / actor8fields / Guidance request8fields และ unknown life fields ยัง reject.

### Fixture authorization / atomicity / generation

Request ใหม่ต้องมี exact **6 fields**: `session_id:int`, `generation:int`, `revision:int`,
`operation_id:String` (stable lowercase ID), `actor_id:String`, `amount:int>=0`.
อ่าน identity จาก current snapshot แล้วเรียก `authorize_fixture_damage(request)` อย่างชัดแจ้ง;
ได้ `AUTHORIZED/FIXTURE_ONLY` พร้อม token (6 fields เดิม + `authorization_id:int>0`).
การ authorize ไม่เปลี่ยน HP/life/revision. นี่เป็น authority ของ opt-in test harness
ไม่ใช่ gameplay authentication หรือ NPC action ใหม่.

`apply_fixture_damage(token)` ตรวจ exact fields/types, known actor, session, generation,
operation ID/duplicate ledger, revision, Party ALIVE/PRESENT, amount และเทียบ token ทุก field
กับ Encounter-owned grant. Wrong/foreign/forged/altered/duplicate/stale request คืน
`REJECTED`, `reason_code`, `hp_delta=0`; ไม่มี partial HP/life/revision mutation.
Operation ID ที่ authorize แล้วออกซ้ำไม่ได้; rejected apply ไม่ consume grant ที่ยัง valid.
หากอีก operation commit ไปแล้ว grant revision เก่าจะ `STALE_REVISION`; ต้องอ่านภาพใหม่
และออก operation ID ใหม่ ไม่ reuse grant เก่า.

เมื่อผ่านทุก gate: clamp amount ก่อนลบเพื่อรองรับ INT64_MAX → คำนวณ HP ใหม่ → สร้าง candidate
ที่ ALIVE/PRESENT หรือ DOWN/PRESENT → Registry replace owned object ครั้งเดียว → Encounter
บันทึก used operation และเพิ่ม revision1. ไม่มี callback/await ระหว่าง commit จึงไม่มี observer
เห็น HP0 แต่ยัง ALIVE. Damage0 เป็น authorized no-op ของ HP แต่ consume operation/increment
revision ครั้งเดียว; replay ยัง reject. Model ไม่มี heal/rescue/retreat/death/bleed-out API.
DEAD และ ALIVE/RETREATED สร้างได้เฉพาะ validated fixtures เพื่อทดสอบ invariants.

Restart ตรวจทั้ง fixture roster ใน candidate Registry ก่อนสลับ; ถ้ารายการท้ายผิดก็ไม่เปลี่ยน
actor/generation/grants ใด ๆ. สำเร็จแล้ว generation+1, revision0, ล้าง grants/used ledger
และสร้าง state ใหม่จาก fixture. session คงเดิมใน Encounter เดิม; Encounter อีกตัวมี session ต่างกัน.
Authorization serial ไม่ recycle. Token เก่า reject `STALE_GENERATION` แม้ actor/operation ID
ถูกใช้ซ้ำ; snapshots/fixture references รุ่นเก่าแก้รุ่นใหม่ไม่ได้. ไม่เปลี่ยน production Restart/queue/Guidance revision.

### Verification / durable evidence

**Actual engine:** `4.7.2.stable.official.ed1daf0bf`, executable
`/Applications/Godot.app/Contents/MacOS/Godot`. **Tested commit:**
`0b3fd961b305e6c74027f35203b77505457f5409`; engine run ใช้ source ที่ commit แล้ว.
เอกสาร/evidence commit ภายหลังไม่ใช่การอ้างว่ารัน engine ใหม่บน documentation HEAD.
Source105/105files ของ snapshot/current tree/commit ตรงกัน; protected files จาก canonical81/81
ตรงทุก byte; inherited PR #43 manifest96/96ไม่เปลี่ยน (ยกเว้น runner ที่อนุญาต optional flag).

| Run / expected | Actual | Exit |
|---|---|---|
| Focused initial: invariants + compatibility ต้องผ่าน | FAIL:77cases/519checks/2failures; fixture ใหม่อ่าน context ก่อนมี enemy declarations | 1 |
| Focused corrected: ใช้ real production active-round context | PASS:78cases/525checks; ทุก gate เดิมคงอยู่ | 0 |
| Fresh canonical export `70922a6`, all existing flags | PASS:64stages | 0 |
| Final committed feature, all flags + `--m4-data-proof` | PASS:69stages; M4 **78 independent cases / 525 assertion checks / 0 per-frame checks** | 0 |
| Existing 18 executable suite counts เทียบ fresh canonical | ตรงทุกจำนวน; original assertions ไม่ลด | 0 |
| Legacy differential กับ fresh canonical และ inherited pre-cutover reference | **6 cases / 5,892 frames identical** | 0 |

ทุก stage ของ canonical/final exit0; **unexpected engine/script errors0, timeouts0**.
Negative suite **983checks และ exactly5expected errors** แยกจาก unexpected errors.
Guidance Main34cases/507,851checks; Guidance Data66,641; Decision1,192; Combat14,395;
counts ของ regression รวม per-frame checks จึงไม่ใช่ independent casesจำนวนเท่านั้น.
M4 case IDs/expected/actual/check counts อยู่ใน scenario JSON; data-driven inputs เป็น case แยก,
assertionsหลายรายการภายใน case เดียวไม่ถูกนับเป็น casesเพิ่ม.

Optional flag ไม่เปลี่ยน runner default; fresh output ทุกครั้ง:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m4-01-focused-20261105-2 --m4-data-proof

python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m4-01-final-20261105 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof \
  --autonomous-main-proof --main-cutover-proof --guidance-data-proof \
  --guidance-decision-proof --guidance-main-proof --m4-data-proof \
  --cutover-baseline /tmp/wanderer-m3a04-reference-20261105-2
```

คำสั่งข้างต้นเป็น exact commands ที่รันแล้ว; rerun ต้องเปลี่ยน output ให้ใหม่.
Cutover baseline44stages เป็น **inherited reference ของ PR #43** บน `1728c5e`, ไม่ใช่รัน reference
ใหม่ในงานนี้; ตรวจ results ตรง durable record เดิม. Fresh canonical64stages และ final69stages
เป็นผลใหม่ของงานนี้. สำหรับ reconstruct reference จากเครื่องใหม่ให้ใช้
[original reference command/setup](../combat/evidence/m3a-04/run-record.json).

หลักฐาน:

- [Run record: exact commands/commits/exit codes/engine/scope/limitations](evidence/m4-01/run-record.json)
- [Final results69](evidence/m4-01/final-results.json), [fresh canonical64](evidence/m4-01/canonical-results.json), [M4 scenarios / before-after](evidence/m4-01/m4-data-scenarios.json)
- [Final raw logs/engine logs/exits](evidence/m4-01/logs.zip), [canonical logs](evidence/m4-01/canonical-logs.zip), [failed+corrected development logs](evidence/m4-01/development-logs.zip)
- [Documentation/scope/archives/approval-boundary checks](evidence/m4-01/review-checks.json)
- [Source hashes](evidence/m4-01/source-sha256.json), [source comparison](evidence/m4-01/source-comparison.json), [unchanged18suite counts](evidence/m4-01/inherited-counts.json)
- [Legacy comparison](evidence/m4-01/trace-comparison.json), [full traces](evidence/m4-01/traces.zip), [regression scenarios](evidence/m4-01/regression-scenarios.zip), [cutover gates](evidence/m4-01/cutover-release-gates.json), [rollback](evidence/m4-01/rollback.json)

A01/A19/A21 อ้าง **เฉพาะ approved data subset**: HP0→DOWN; copy/ownership/no raw heal bypass;
invalid pairs/forged transition requests no-delta. ไม่มี B2/grace/RESCUE/death/Retreat/reentry/terminal
migration expected values. A01–A39 ทั้งแถวยังคง **Proposed / NOT RUN** ใน architecture matrix.

### Learning notes — ภาษาไทย ตาม v0.4

**Goal:** ทำนายข้อมูลหลัง operation และอธิบายว่าใครมีสิทธิ์เปลี่ยนได้.
**Concept:** HP เป็นจำนวน, LifeState/Participation เป็นความหมาย, Encounter เป็นผู้อนุญาต.
**Do:** เริ่ม factory→copy Registry→authorized damage→Restart ทีละชั้นใน files ข้างบน.
**Observe:** อ่าน expected/actual จาก engine จริง. **Explain/Adjust:** รอบแรก contextก่อนรอบยังไม่มี
enemy declarationsจึงถูก validatorปฏิเสธ; แก้เวลาตั้ง fixture ไม่แก้ validator. **Commit:**
source commitข้างบนและแยก documentation/evidenceออกจากข้ออ้างว่า gameplayผ่าน visual review.

1. **HP ต่างจาก LifeState:** HP3→0 คือคำนวณจำนวน; ALIVE→DOWN คือเปลี่ยนความหมายที่ D01 อนุมัติ.
   HP0อย่างเดียวบอกไม่ได้ว่า DOWN หรือ DEAD จึงห้ามใช้ `hp==0` แล้วเขียน DEAD อัตโนมัติ.
2. **LifeState ต่างจาก Participation:** “สภาพชีวิต” กับ “ยังอยู่สนามไหม” คน ALIVE/RETREATED
   ยังมี HPเดิมแต่ eligible=false. DOWN/RETREATED ไม่ผ่าน factoryเพราะเป็น invalid pair;
   ไม่ได้แปลว่างานนี้อนุมัติ carry/evacuationแล้ว.
3. **HP0 ไม่ใช่ DEAD:** case `authorized_down_player` รันจริงก่อน HP3/ALIVE/PRESENT;
   authorized damage10 clampลงได้3 → HP0/DOWN/PRESENT/eligible=false, delta−3.
   **Expected=Actual: PASS**; replayคืน DUPLICATE_OPERATION/delta0. NPCใช้กฎ dataเดียวกัน.
   DEADใช้ fixture HP0แยกเท่านั้น; ไม่มี clockหรือ triggerทำให้ตาย.
4. **เหตุใด Registryต้อง copy:** ถ้าเก็บ objectของ callerตรง ๆ callerอาจเปลี่ยน stateผ่าน referenceเดิม.
   Proofใช้ mutable snapshot providerที่ validตอน registerแล้วเปลี่ยนเป็น ALIVE/HP10ภายหลัง;
   owned DOWN/HP0ยังคงเดิม. Copy reconstructionต้องรักษา LifeStateด้วย ไม่สร้างใหม่จาก HPอย่างเดียว.
5. **Encounterอนุญาต Transition:** UIหรือ snapshotไม่มีข้อมูลว่าเป็น sessionไหนและ operationใช้แล้วหรือยัง.
   Grantที่ตรวจ identity/amountแล้วจึงเป็นขอบเขตการอนุญาต; tokenถูกแก้ amount/actorจะ UNAUTHORIZED.
6. **Atomic Mutation:** สร้างผลใหม่ที่ถูกต้องครบก่อน replace stateครั้งเดียว. ไม่เขียน HP0ก่อนแล้วค่อย
   validate DOWNภายหลัง เพราะถ้าขั้นหลังผิดจะเหลือ ALIVE/HP0ที่ผิด invariant.
7. **Snapshot Isolation:** snapshotเหมือนรูปถ่ายข้อมูล. แก้รูปให้ HP10ไม่ได้รักษาคนจริง;
   testsแก้ nested state/definitionและลบ dictionaryสำเนาแล้วเจ้าของข้อมูลยังเหมือนเดิม.
8. **Generationกันงานเก่า:** Restartเหมือนเปลี่ยนรุ่นเอกสาร คนชื่อ playerและ operationชื่อเดิมอาจอยู่ต่อ
   แต่ใบอนุญาตรุ่นเก่าไม่ใช่ใบรุ่นใหม่. Valid restartให้ generation+1; invalid restartไม่เพิ่มรุ่น
   และ grantเดิมยังใช้ได้เพราะไม่มีบางส่วนถูก resetไปแล้ว.
9. **Isolated Proofยังไม่ใช่ Playable M4:** dataรองรับ DOWN/DEAD/RETREATEDไม่ได้ให้ปุ่ม/actionหรือ
   NPC policyใหม่. Mainยัง HP0→DEFEAT, HELP≤30%/+4/once, Guidance v1/eight fields/R1เดิม.
   ต้อง reviewและอนุมัติงานถัดไปก่อนเชื่อม gameplay.

**Limitations / stop:** GDScript underscoreเป็นข้อตกลง internal ไม่ใช่ security/private enforcement;
ไม่อ้างป้องกัน hostile reflectionหรือ codeที่จงใจเขียน internal fields. Transactionเป็น synchronous
single-threaded proof ไม่รับรอง multiplayer/concurrency. Agent GUI/F5/F6/manual keyboard/visual
acceptance **NOT RUN**; headlessไม่พิสูจน์ visual quality. Speed0.70/lunge44px/Compact Formation/
saved homesไม่แก้. D03–D11/D13–D17ยัง Pending; M4-02–05ไม่เริ่ม.
**หยุดที่ Draft PR เพื่อ Independent Code Review; ไม่ merge/auto-merge/ลบ branch.**

## M4-02 — Isolated Atomic Effect / Clock Proof Candidate

**Implemented Candidate / independent review pending — 6 พฤศจิกายน 2026 (Asia/Bangkok).**
Owner authorization: task “WANDERER — M4-02 Isolated Atomic Effect / Clock Proof Implementation”
ใน chat วันที่นี้ อนุญาต isolated runtime/tests/runner/docs/evidence โดยตรง; ไม่อนุญาต merge.
Canonical local/tracking/live remote/merge-base ตรง `4969f32d5de1d1795968bdab5c3a85bbfe00c460`;
GitHub ยืนยัน PR #46/#47 merged. Initial tree สะอาด; local/live remote ไม่มี branches ของ
PR #46/#47 หรืองาน M4-02 implementation ซ้ำ; open PRs มี #2/#17 ซึ่งไม่ได้แก้.
Branch: `codex/m4-02-isolated-atomic-effect-clock-proof`.
[Binding contract](../../docs/M4_02_Rescue_Clock_Death_Contract.md) และ
[index](../../docs/README.md#current-status-and-next-roadmap) ถือ design/milestone authority ตามลำดับ.

### Design-to-code mapping and ownership

| Reviewed requirement | Implementation / boundary |
|---|---|
| Separate opt-in aggregate | [IsolatedRescueClockEncounter](../../scripts/m4/isolated_rescue_clock_encounter.gd), RefCounted composition; ไม่สืบ/แก้ production หรือ M4-01 Encounter |
| Single HP/LifeState/Participation owner | Published `_root.registry` owns validated Party/Enemy runtimes; snapshot ไม่มี runtime references. Episodes ไม่มี HP mirror |
| Candidate construction / publication | `snapshot` → scratch actors/ledgers → `_registry` reconstruct ด้วย M4-01 factories → `_valid_candidate` → inert diagnostic gate → `_root = candidate` ครั้งเดียว; ไม่มี await/signal/Tween/UI callback |
| RESCUE | `lock_rescue` → `impact` → `complete` หรือ `cancel`; owned grant ตรวจครบทุก field, lock revision เป็น audit; current eligibility/episode/use ตรวจซ้ำที่ impact |
| Finite fixture issuer | `lock_fixture_slot` → real fixture damage impact → completion receipt; `seal` ตรวจ owned witness/receipts/outstanding/availability แล้วออก exact event grants. Issuer อยู่ใน aggregate เดียว ลด authority ซ้ำ |
| Strict Seal | OPEN→SEALED→CLOSED หรือ OPEN/SEALED→ABORTED; `next_round` เฉพาะ CLOSED และ next identity ใน finite plan; ไม่ unseal/reopen/reseal |
| Single clock / batch death | `apply_round_closed`: authenticate → identity → event/semantic dedup → round/phase/witness/sealed revision → batch from pre-tick root → candidate validation → publish CLOSED |
| Abort / Restart | `authorize_abort` เฉพาะ OPEN, `abort_round` OPEN/SEALED; `restart` validate whole roster/plan/clock/use ก่อนเปลี่ยน generation; SEALED ต้อง Abort ก่อน valid reset |
| Diagnostic fault seam | [Test-only subclass](m4_02_diagnostic_encounter.gd) override inert validation/comparison hooks; no real root write, concurrency หรือ production reference |
| Proof / optional runner | [Focused scenarios](m4_02_atomic_effect_clock_proof.gd); `--m4-atomic-clock-proof` เพิ่ม parse3+execute1; JSON count/status validation; default runner/original expectations คงเดิม |

`schema_version=2` diagnostic root มี session/generation/revision/round/index/window/phase,
finite plan, registry-owned actors, episodes/serial, rescue uses, read-only HELP fixture reference,
action grants/results/consumption, witness expected slots/receipts/outstanding/abort/phase/revision,
event grants/consumption, semantic close keys, authorization serial และ Abort grants/consumption/count.
ทุก read เป็น detached copy. HELP reference เป็น fixture sentinel ไม่ใช่ production HELP authority.

### Exact schemas and API boundary

สำหรับ request/token/event: field ที่ไม่ได้ระบุเป็น int ต้องเป็น String; ไม่มี unknown fields/coercion.
Token/request version ต้องเป็น int1. Actor/operation/slot/event IDs ผ่าน existing valid-ID rules.

| Input | Exact fields / types |
|---|---|
| RESCUE request (8) | `version:int, session:int, generation:int, operation_id, kind=RESCUE, helper_id, target_id, window_id` |
| Owned action token (13) | request8 + `episode_id, lock_revision:int, authorization_id:int, slot_id, amount:int`; Rescue slot empty/amount0; fixture damage kind `FIXTURE_DAMAGE`/episode empty |
| Owned ROUND_CLOSED event (10) | `version:int, kind=ROUND_CLOSED, issuer_id=M402_FINITE_FIXTURE, session:int, generation:int, round_id:int, event_id, witness_id, sealed_revision:int, authorization_id:int` |
| Abort token (7) | `version:int, session:int, generation:int, operation_id, kind=ABORT, round_id:int, authorization_id:int` |
| Restart fixture (4) | `actors:Array, round_plan:Array, clocks:Dictionary, help_reference:Dictionary` |
| Actor fixture entry | `definition` existing exact4-field ActorDefinition; `state` M4-01 exact3-field Party seed or Enemy `{current_hp:int}` |
| Finite plan row | `{round_id:int, slots:Array, event_ids:Array[String]}`; consecutive increasing rounds, unique event IDs across generation; no automatic iteration |
| Fixture slot row | `{slot_id:String, helper_id:String, target_id:String, amount:int>=0}`; IDs must belong to Party, unique slots per round |
| Optional DOWN clock seed | actor-keyed `{entry_round:int>=1, budget:int∈[1,2]}`; current-entry requires B2; initial/default DOWN B2/current round; DEAD gets inactive B0 |
| Optional HELP reference | Party-ID keyed int0/1; omitted Party defaults1; cannot change through effects |

Fixture capability ต้องตรง object ที่ constructor รับสำหรับ restart/lock/fixture damage/slot/seal/
next-round/Abort authorization. Impact/completion/cancel/close/Abort ใช้ exact owned tokens.
Grant edits ไม่สร้างสิทธิ์; changed session/generation ตรวจเป็น identity reason ก่อน lookup reused IDs.
**Operation namespace (R48-01):** prefix `slot_` สงวนให้ fixture issuer ทั้งหมด รวม IDs ของรอบอนาคต.
Caller RESCUE ที่ใช้ prefix นี้รับ `REJECTED / M4_RESERVED_OPERATION_ID` ก่อน `_issue_action()`;
N-all รวม HP/state/episodes/resources/grants/authorization serial/witness/revision. Existing
shape/identity/authority/phase/ID-validity gates ยังมาก่อน namespace gate. Internal slot token
ยังมี operation ID `slot_<round>_<slot>` เดิม; request8/action13/event10 schemas ไม่เปลี่ยน.

Action identity อยู่ใน root ของ session/generation/operation; event key เป็น session/generation/issuer/event;
semantic key เป็น session/generation/round. Authorization serial ไม่ reset ข้าม generation.

RESCUE success: `DOWN/PRESENT HP0 → ALIVE/PRESENT HP1`, clock inactive และ helper use1→0
พร้อม consumed impact/result/revision+1. Completion ไม่ทำ effect ซ้ำ. Valid one-shot SKIP ใช้ revision1
และ settle operation แต่ไม่เปลี่ยน actors/episodes/uses/HELP; rejected call เป็น N-all ทั้ง root.
ไม่มี retarget, extra slot, item/MP/inventory cost, revival หรือ raw heal/retreat/death setter.

Fixture proof ใช้ actual declared damage1 ต่อ Player, impact และ completion จริงเพื่อสร้าง receipt.
นี่ไม่ใช่ DEFEND ปลอมหรือ production slot; slots มีจำนวนจำกัดและ effects ไม่เพิ่ม expected slots.
Seal ต้อง Player/active Party/Enemy available; dependency fail ไม่สร้าง rounds/outcome/death.
`seal` ออก finite event IDs สองใบสำหรับ round เดียวเพื่อทดสอบ semantic dedup ด้วย owned second grant;
ใบที่สองไม่ใช่ tick เพิ่ม. Caller boolean หรือ receipt dictionary ไม่ใช่ authorization input.

### Actual executable coverage and evidence

Actual executable/version: `/Applications/Godot.app/Contents/MacOS/Godot`,
`4.7.2.stable.official.ed1daf0bf`. Tested commit หลัง R48-01: `a8dda626aa268bc243dfaac827b70a5465eaa7e9`.
Expected ทุก executable suite ผ่าน/ไม่มี unexpected errors/Legacy ตรง canonical; actual ตรง expected:

| Fresh run / check | Recorded actual |
|---|---|
| Focused M4-02 | **55 independent cases / 1,188 assertions / 0 failures / 0 per-frame checks** |
| Original M4-01 | **78 independent cases / 525 checks**, original files unchanged |
| Canonical `4969f32` all existing flags | **69 stages PASS**, runner/stage exits0 |
| Feature tested commit all flags + M4-02 | **73 stages PASS**, runner/stage exits0 |
| Existing executable suite counts | **19/19 identical** to fresh canonical; per-frame checks remain part of inherited counts |
| Legacy differential | **6 cases / 5,892 frames identical** to fresh canonical and attributed pre-cutover reference |
| Error accounting | unexpected0/timeouts0; negative suite **5 expected errors** separately |
| Tested source hashes | **111/111** match committed source, tested snapshot and delivery source |
| Protected source | **89/89** canonical production/M4-01/config/scene/asset/test code files unchanged; **104/104** prior source-manifest entries unchanged excluding authorized runner |

Initial sandboxed import failed on system certificate/editor settings access (exit0 with errors,
correctly classified FAIL); no gameplay ran. Preserved logs, then reran with required system access.
Focused development runs2/3 passed52cases/1,021checks; initial full candidate passed73stages/
53cases/1,129checks. Final corrections add cross-round event-ID uniqueness and exact M402-30/37
ordering; reviewed delivery `36d6c9d` recorded53cases/1,137checks. That historical evidence is retained in [review-history.zip](evidence/m4-02/review-history.zip). R48-01 current run above passes55cases/1,188checks; original53 case assertion counts are identical. No production expectation weakened.

M402 matrix มีหลาย subcases จึงไม่ใช่ “45 executable cases”. `M402-06-validator-only`
ตรวจ detached DEAD eligibility เท่านั้น; end-to-end death-before-pending-rescue ยังคง **BLOCKED**.
M402-24 malformed/forged/wrong-round-shaped events ทดสอบได้; authenticated unused wrong-round event
ไม่มี issuance path ภายใต้ Strict Seal จึงไม่อ้างว่ารัน subcase นั้น. ไม่มี bypass/fake receipt/event.
M402-39 รวม snapshot-copy proof กับ unchanged M4-01 run; M402-40/41 อาศัย fresh full regression,
Guidance/R1 suites และ protected-source comparison แยกจาก focused-case counts.
M402-D01/D02/D04 **BLOCKED**; D03/D05 **DEFERRED** ตาม D10/D15/production integration.

Raw per-call before/after roots, exact inputs, actual effects/reasons และ assertions อยู่ใน
[scenario archive](evidence/m4-02/scenarios.zip); [scenario summary](evidence/m4-02/m4-02-scenarios.json)
เก็บ state/clock/resource before/after และ full-root no-delta results พร้อม archive pointer.
[Exact commands/engine/commit/exits](evidence/m4-02/run-record.json),
[final stages](evidence/m4-02/final-results.json), [fresh canonical](evidence/m4-02/canonical-results.json),
[raw logs](evidence/m4-02/logs.zip), [canonical logs](evidence/m4-02/canonical-logs.zip),
[development logs](evidence/m4-02/development-logs.zip),
[source manifest](evidence/m4-02/source-sha256.json), [source integrity](evidence/m4-02/source-comparison.json),
[Legacy differential](evidence/m4-02/trace-comparison.json), [traces](evidence/m4-02/traces.zip),
[inherited counts](evidence/m4-02/inherited-counts.json), [coverage mapping](evidence/m4-02/coverage.json),
[review checks](evidence/m4-02/review-checks.json).

### Thai learning notes — Goal → Concept → Do → Observe → Explain → Adjust → Commit

1. **M4-01 กับ M4-02:** M4-01 พิสูจน์ข้อมูลและ HP0→DOWN; M4-02 เพิ่มผล RESCUE และ clock
   ใน counterpart ใหม่ จึงไม่เปลี่ยนความหมาย snapshot/test เดิม.
2. **RESCUE ต่างจาก HELP:** HELP เดิมรักษา Player ที่ยังมีชีวิต ≤30%, +4, once.
   RESCUE นี้ฟื้น DOWN ที่0เป็น1HP ใช้ budget คนละเล่ม จึงไม่ consume/reset HELP.
3. **Down Episode:** คนเดิมล้มครั้งใหม่เป็น e2; grant ที่ล็อก e1 ใช้กับ e2 ไม่ได้.
   Observe: J ช่วย e1 → Tโดน damage1จน DOWN/e2 → Hใช้ e1 ได้ SKIP/episode-changed ไม่ช่วย e2.
4. **Atomic HP+budget:** ก่อนช่วย `(HP0,DOWN,B2 active,R1)`; หลังช่วย
   `(HP1,ALIVE,clock inactive,R0)`. หาก validate ไม่ผ่าน เหลือชุดก่อนทั้งหมด;
   ไม่มี HP1แต่ R1 หรือ R0แต่ยัง DOWN. Candidate เป็นกระดาษทด ไม่ใช่ HP owner อีกชุด.
5. **ROUND_CLOSED ต่างจาก animation completion:** callback ของ action ให้ receipt ได้
   แต่ไม่เดิน clock. ต้องครบ finite witness ไม่มี pending impact/completion แล้ว seal/close จริง.
6. **Strict Seal:** SEALED เหมือนปิดซองข้อมูลรอบนั้น รับเฉพาะ close หรือ Abort ที่ออกไว้ก่อน;
   damage/rescue/complete/cancel/new lock/reseal ไม่แก้ซอง. Next round ต้อง identity ใหม่หลัง CLOSED.
7. **Abort ต่างจาก rejected event:** rejected event ไม่เปลี่ยนอะไร; valid Abort เพิ่ม phase/revision/
   accounting เป็น ABORTED โดยไม่ tick/death/consume close หรือสร้าง completion ปลอม.
8. **Grace round:** Expected และ tested: down round3 B2 → close3 B2 → close4 B1 → close5 DEAD/B0.
   B2 ไม่ได้สัญญาว่าจะมีสอง playable rounds เพราะ scheduler/terminal ยัง pending.
9. **Batch atomic:** คำนวณ J/T จาก before เดียว; candidate อาจมี JDEAD/Ttick หรือสอง DEAD.
   Test-only failure หลังคำนวณ actorที่สองทิ้งทั้ง candidate รวม consumption; ไม่มีครึ่ง batch.
10. **DEAD ไม่ใช่ลบ save:** เก็บ actor/definition/HP0/clock0ใน encounter เดิมและไม่รับ RESCUE/HEAL;
    Restart สร้าง generation ใหม่ เป็น fixture reset ไม่ใช่ action คืนชีพ/permadeath implementation.
11. **Isolated ยังไม่ใช่ playable feature:** ไม่มีปุ่ม RESCUE/bleed UI/NPC rescue policy,
    Main ยัง Player HP0→DEFEAT; production/Guidance/Legacy ใช้ authority เดิม.
12. **D10/D15:** เมื่อ Player DOWN/all Party DOWN/no Enemy, fixture boundary หยุดด้วย dependency
    แทนแต่ง scheduler/terminal rules. ผล automated proof ไม่อนุมัติ pending decisions.

**Limits / final stop:** synchronous single-threaded correctness; GDScript underscores/capability
เป็น harness convention ไม่ใช่ hostile-code security/multiplayer guarantee. Full candidate registry
reconstruction เหมาะกับ proof ขนาดเล็ก ยังไม่มี production performance claim.
Agent GUI/F5/F6/manual keyboard/visual acceptance **NOT RUN**; native headless startup checks
ไม่ใช่ manual acceptance. No scene/asset/presentation changes. Independent review และ owner gate ถัดไปยังรอ.
หยุดหลัง Draft PR; ไม่ merge/auto-merge/cleanup branches, ไม่เริ่ม M4-03/Main/NPC/terminal integration.


### R48-01 — Operation ID namespace review fix

Owner task “PR #48 Review Fix R48-01”, 6 พฤศจิกายน 2026 (Asia/Bangkok), อนุญาต fix บน branch/PR เดิม.
อ่าน [Independent Review5795418762](https://github.com/shanwinder/wanderer/pull/48#pullrequestreview-5795418762)
บน `36d6c9dee54118614a845c6e1827315df9989127`; local/live remote ตรง reviewed HEAD, tree สะอาด,
canonical/merge-base ยัง `4969f32`. Draft/unmerged; #2/#17 ไม่แตะ.

**Root cause:** `lock_rescue()` ยอมรับ caller operation ID ที่มี prefix `slot_` ขณะที่ issuer สร้าง
key รูป `slot_<round>_<slot>` ใน `_root.actions` เดียวกัน. การ cancel/complete ไม่ลบ historical key
จึงจอง key ของ slot ปัจจุบันหรืออนาคตไว้ได้ ทำให้ real receipt ไม่ครบและ seal ไม่สำเร็จ.

**Fix:** ใช้ `SLOT_OPERATION_PREFIX` ร่วมกันใน issuer และ RESCUE admission; reject prefix นี้ทั้งหมด
ด้วย `M4_RESERVED_OPERATION_ID` ก่อนสร้าง grant/candidate/เพิ่ม serial. ไม่ล้าง ledger เพื่อแก้ deadlock,
ไม่เปลี่ยน tokens/requests/slot behavior หรือ bypass Strict Seal.

| Added regression ID | Exact input in OPEN round3 | Expected and actual |
|---|---|---|
| R48-01-current-round | RESCUE h→t, `operation_id=slot_3_damage_p` | REJECTED/reserved/N-all/no token; real round3 slot locks, applies damage, completes receipt, seals and closes normally |
| R48-01-future-round | RESCUE h→t, `operation_id=slot_4_damage_p` | REJECTED/reserved/N-all/no token; real round3 closes, validated next round4 opens, real round4 slot locks/applies/completes/seals/closes |

Both tests assert final CLOSED, exact issuer key belongs to COMPLETED FIXTURE_DAMAGE, real receipt
matches the key and outstanding is empty. Whole-root equality on rejection includes resource/episode/
authorization/consumption/revision accounting. Existing53 cases retain all1,137 assertions; added2 cases
supply51 assertions, giving **55 cases / 1,188 assertions / 0 failures** (zero per-frame assertions).
M402-01–45 matrix/statuses and blocked/deferred dependencies remain unchanged; supplemental IDs are
recorded in [coverage.json](evidence/m4-02/coverage.json), not renumbered into M402.

**Fresh verification:** actual Godot `4.7.2.stable.official.ed1daf0bf`; focused+M4-01 run passes;
committed source `a8dda626aa268bc243dfaac827b70a5465eaa7e9` full run **73/73 PASS**;
fresh canonical **69/69 PASS**. M4-01 **78 cases/525 checks**; all19 inherited counts identical;
Legacy **6 cases/5,892 frames identical**; final/canonical exits0, unexpected0/timeouts0,
negative suite exactly5 expected errors.111/111 tested hashes and89/89 protected canonical files match;
request/action/event schema lines and runner byte-identical to reviewed HEAD.

Pre-fix red run reproduces the current collision and fails11 assertions plus2 secondary missing-event/
receipt script errors; future case was not reached in that failed harness path. Logs and failed source
are preserved in [development logs](evidence/m4-02/development-logs.zip). The regression harness now
records failed admission without cascading missing-token errors. This is not counted as a successful
or complete55-case run. Both current/future cases pass in the corrected focused/full runs.
Reviewed17 evidence files are preserved losslessly in [history](evidence/m4-02/review-history.zip).
[Exact new commands/commits/exits](evidence/m4-02/run-record.json) and raw snapshots remain linked above.

Await independent follow-up review; no claim that the reviewer has accepted the fix. Existing
M402-06/D01–D05/M402-24 limitations and GUI/manual visual NOT RUN remain. No merge/auto-merge,
production change, M4-03 or branch cleanup.

## M4-03A — Isolated Queue / Eligibility Foundation

**Implemented Candidate / Awaiting Independent Code & Evidence Review — 7 November 2026.**
Separate owner task explicitly authorizes A runtime, focused tests, optional runner hook,
documentation and evidence. [PR #49](https://github.com/shanwinder/wanderer/pull/49)
merged at `67d68bb1f78fa8efedcb719079a4487c531c49d4`; its design approval alone was
not implementation authorization. Current milestone authority remains the
[index](../../docs/README.md#current-status-and-next-roadmap). Older Candidate and
NOT RUN statements above retain their historical attribution.

### Goal, source findings and ownership

Answer who exists, who is actionable, which opportunity they own, and whether an
invalid request can damage the queue. This is an executable foundation, not playable M4.

| Source inspected | Existing ownership / boundary preserved |
|---|---|
| M4-01 Party state / Registry / Encounter | Definition immutable baseline; four validated Party pairs; Registry validates/copies runtimes, detached snapshots; original fixture damage/revision/grant and Restart APIs unchanged |
| M4-02 aggregate / Strict Seal | One registry/root, episode/use/action/event ledgers; real fixture effect and completion issuer; session/G/revision/semantic close identity. OPEN→SEALED→CLOSED or explicit Abort; SEALED reset requires Abort. A never wraps its public mutations or borrows its receipts |
| FullParty / GuidedEncounter / NPC Resolver | Production owns action grants, HP/Guard/HELP, queue and terminal; slot decisions independent under approved policy. Resolver still returns PLAYER_DEFEATED at Player0; production SKIP tokens are not A's unavailable dispositions |
| Existing focused proofs / verify.py | Original M401/M402 assertions and reason codes untouched; fresh snapshot/import/parse/startup, optional proof flags, unexpected-error and timeout failure gates retained |

[Encounter](../../scripts/m4/isolated_queue_outcome_encounter.gd) owns one `_root`;
published `_root.registry` alone owns actor state. The
[adapter](../../scripts/m4/m403_queue_adapter.gd) has **no live state**, only pure
queue construction, eligibility, candidate validation and diagnostic calculations.
Candidate snapshots are temporary detached data, reconstructed through the unchanged
M4 factories/Registry before one root swap. No sequential writes to two aggregates.
Atomicity means synchronous single-threaded publication, not hostile-code security.
GDScript underscore fields/methods and fixture capability objects follow existing
repository conventions; callers must not write internal fields.

Snapshot exact18: `schema_version,session,generation,revision,phase,round_id,round_index,
plan,initial_party,initial_enemies,actors,queue,active_operation,authorizations,
action_receipts,clocks,outcome,summary`. `registry` objects are never returned.
A owns no effect producer: active_operation is null and all five final dictionary
domains are empty. The reserved empty domains cannot be populated by a fixture,
advance request or candidate. Empty outcome/summary do not claim a classifier ran.

**Roster source discrepancy:** M4-01 accepts valid unique actors without roster
counts. M4-02 requires exactly one Player but does **not** impose NPC≤3, Enemy≤2
or even a nonempty Enemy set. Those numeric caps belong to production FullParty's
validator. A follows isolated factories without inventing those caps, adds the
required nonempty Enemy roster, and tests the discrepancy explicitly. Example
fixtures retain Player+3NPC+2Enemy; minimum Player+Enemy and a larger finite fixture
are also proven. No dynamic unregister/addition exists within a generation.
Player first, then NPCs in fixture encounter order, then Enemies in fixture order;
Party/Enemy sets disjoint and complete. Every configured round must name that exact
order once; caller cannot supply slot/opportunity IDs.

### Exact API and protocol

`Encounter.new(capability)` starts session identity, G0/revision0/UNINITIALIZED.
No owner is issued through a read. Save the capability externally for authorized
fixture operations. All reads return detached copies; wrong actor ID/type returns
an empty actor row and five false eligibility predicates.

| API | Exact input / result |
|---|---|
| `snapshot()` / `queue_snapshot()` | Detached complete view / queue dictionary; no mutation |
| `actor_snapshot(id)` / `eligibility_snapshot(id)` | Detached M4 registry row / five derived predicates |
| `current_opportunity()` | Detached current exact3 `opportunity_id,slot_id,actor_id`, or empty at uninitialized/drained boundary; no consumption or token |
| `advance(request,capability)` | Exact5 `version:int=1,session:int,generation:int,expected_revision:int,queue_id:String`; either READY/SLOT_READY without publication, or one unavailable disposition and one cursor/revision increment |
| `restart(request,capability)` | Same exact5 plus `fixture:Dictionary`; validates all actors/plan then publishes G+1/revision0, new queue/cursor0/dispositions empty. Explicit envelope adds optimistic identity/revision to the suggested fixture-only notation |
| `progress_diagnostic()` | Derived read-only projection; never cached in root or recorded as queue phase |

Fixture exact2 `actors:Array,round_plan:Array`. Each actor row exact2
`definition,state`: original Definition exact4 and Party fixture exact3 or Enemy
`{current_hp:int}`. Plan nonempty, each row exact2 `round_id:int>0,actor_order:Array`;
subsequent round IDs consecutive, strictly typed, with overflow guarded. Order must
match the complete initial roster in **every** entry. A reserves only plan[0]; later
entries are validated but no open-next API executes them.

Queue exact5 `queue_id,phase,opportunities,cursor,dispositions`:
queue IDs include `m403/queue/session/generation/round`; each opportunity's slot and
opportunity IDs use separate internal suffixes plus ordinal, never actor-chosen
keys. Domain separation prevents
current/future `slot_3_p`/`slot_4_p` actor names from preempting issuer identities.
A queue is READY until all opportunities disposed, then DRAINED; READY means
foundation inspection, **not gameplay round admission**. No RUNNING/action lock
or effect authority is implied by READY. Round remains OPEN; no SUSPENDED stored.

Disposition exact4 `slot_id:String,actor_id:String,kind:String=UNAVAILABLE,
observed_revision:int` records the pre-advance revision. Each successful advance
moves one cursor position, no loop, never passes an eligible actor. A-only invariant
revision==cursor follows because no other within-generation writer exists. An
eligible opportunity is returned indefinitely without creating/consuming a grant.
A future real action/completion producer must be separately reviewed before it can
dispose an eligible opportunity; there is no caller completion import.

**Reason precedence:** exact request fields/version/types → session → generation →
owned capability → phase → queue identity → expected revision → fixture/domain →
complete candidate validation → publication. Session is a signed nonzero engine
instance identity; no positive-only assumption. Shapes/types use no coercion.

| Gate / result | Reason (`M403_` prefix) / revision |
|---|---|
| Missing/unknown fields, wrong scalar type/version | INVALID_FIELDS / N-all |
| Foreign session / old generation | FOREIGN_SESSION / STALE_GENERATION / N-all |
| Missing, wrong-type, foreign capability | UNAUTHORIZED / N-all |
| Advance before initialized; reset outside UNINITIALIZED/OPEN | INVALID_PHASE / N-all; SEALED is not legally reachable in A |
| Wrong queue / stale request revision | WRONG_QUEUE / STALE_REVISION / N-all |
| Malformed actor/roster/lifecycle/finite plan | INVALID_RESTART / N-all |
| Invalid detached candidate or forbidden transition | INVALID_CANDIDATE / N-all |
| Eligible current slot | READY / SLOT_READY / N-all |
| Unavailable current slot | APPLIED / SLOT_UNAVAILABLE / revision+1, cursor+1, disposition only |
| Drained queue | REJECTED / BOUNDARY_DEPENDENCY / N-all; no automatic seal/next round |
| Valid reset | APPLIED / RESTARTED / G+1, revision0 |

Repeated READY reads are identical; replay after a published unavailable disposition
gets STALE_REVISION (there is no request-ID/duplicate-action ledger in A). Repeated
boundary denials issue nothing and return the same reason. Invalid Restart preserves
the legitimate current opportunity and original fixture input. Old G requests reject
before looking up reused IDs. Entire-root equality covers actors, registry snapshots,
queue, cursor, G/revision, dispositions, plan/round identity and all inert domains.

### Eligibility and deferred boundaries

| Party state | actor_present | actor_actionable |
|---|---|---|
| ALIVE/PRESENT HP>0 | true | true |
| DOWN/PRESENT HP0 | true | false |
| DEAD/PRESENT HP0 | true | false |
| ALIVE/RETREATED HP>0 | false | false |

Enemy presence means retained Registry membership; HP>0 actionable, HP0 unavailable,
no DEAD inference. `actor_exists` is independent of presence/actionability.
`slot_eligible` additionally needs an undisposed owned opportunity;
`queue_opportunity_available` additionally requires the cursor's current slot and
OPEN/READY/no active operation. No duplicated gameplay eligibility switch exists.

**Receipt safety:** no impact, completion, seal/close, Abort, open-round/next-round,
Self-RETREAT, classifier, frozen-summary or arbitrary receipt import API exists.
Unavailable dispositions are not DEFEND/SKIP actions or receipts. Candidate tests
invoke internal validators/publication rejection with **invalid detached** data;
they do not publish fake effects, valid receipts, CLOSED/SEALED or terminal roots.
Legal SEALED→Abort→Restart and callback replay after real lock/impact are deferred
with their B/C producers. Pure phase-validator rejection is the only A evidence.

R49-01's pure adapter predicate takes exact7 diagnostic facts: `round_phase:String,
queue_phase:String,pending:bool,completed_actions:int,active_party:int,
active_enemies:int,has_next_round:bool`. On nonterminal active-side facts with no
pending work it projects NO_REAL_PROGRESS for OPEN/DRAINED/zero actual completions,
or PLAN_EXHAUSTED for CLOSED/no next entry. SUSPENDED is **derived only**. Synthetic
predicate inputs are labelled PURE_PREDICATE_NOT_GAMEPLAY; never imported or treated
as completion witnesses. A cannot naturally produce the full nonterminal drained or
CLOSED boundary. Both full boundary operations remain deferred; no M403-44
end-to-end PASS, no new operation added just to return its expected code. Fully
unavailable A rosters are not falsely labelled nonterminal suspension.

### Actual verification, coverage and reproduction

Godot `4.7.2.stable.official.ed1daf0bf`, executable
`/Applications/Godot.app/Contents/MacOS/Godot`, tested source `ad0e95c` (full SHA in
run record). **94 M403A cases / 1,165 assertions / zero failures / zero per-frame checks.**
Each assertion has an actual boolean record; counts match case detail and stdout.
Fresh canonical **73 stages**, final candidate **77 stages**, all PASS. Unchanged
M4-01 **78/525**; M4-02 **55/1,188**. Final unexpected errors/timeouts0; negative
suite's five expected errors separate. Legacy **6 cases / 5,892 frames identical**
to fresh canonical and the attributed pre-cutover reference. This is local Godot
verification, not CI/independent review or manual visual acceptance.

[Run record and exact commands](evidence/m4-03a/run-record.json),
[focused scenarios and assertion detail](evidence/m4-03a/m4-03a-scenarios.json),
[full coverage map](evidence/m4-03a/coverage.json),
[final results](evidence/m4-03a/final-results.json),
[fresh canonical](evidence/m4-03a/canonical-results.json),
[source integrity](evidence/m4-03a/source-comparison.json),
[inherited counts](evidence/m4-03a/inherited-counts.json),
[Legacy differential](evidence/m4-03a/trace-comparison.json),
[self-review checks](evidence/m4-03a/review-checks.json),
[final raw logs](evidence/m4-03a/logs.zip),
[canonical logs](evidence/m4-03a/canonical-logs.zip),
[development failures/source snapshots](evidence/m4-03a/development-logs.zip).

Coverage of M403-11/37/38/39/40 is **PARTIAL / FOUNDATION-ONLY**: unavailable Player
cursor/identity, stale advance/reset requests and pending opportunity retention;
no real action callbacks. M403-44 **DEFERRED TO B/C**, pure predicates only.
M403-47/48 **FULLY PROVEN for this A candidate's regression/preservation scope**;
no historical design matrix row rewritten. Other M403 gameplay scenarios deferred.
M402-06 remains BLOCKED end-to-end, M402-24 PARTIAL. Actual individual M403A case
expectations/inputs/results/before-after snapshots are in the scenario report.

```sh
python3 tests/combat/verify.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output /tmp/wanderer-m403a-new-focused --m4-queue-foundation-proof
```

Use a new directory each run. All-flags canonical/candidate reproduction and
reference provenance are in run-record; source checkout must match its tested SHA.
The opt-in hook adds three parse stages and one proof stage. Default and inherited
flag behavior is unchanged. It rejects malformed/duplicate-key/nonfinite JSON,
wrong types/counts/IDs, missing assertion detail, failures and stdout mismatches;
engine errors/nonzero exits/timeouts independently fail. Development failures are
separate from verified runs; no expectations or original assertions were weakened.

### Thai learning notes — Goal → Concept → Do → Observe → Explain → Adjust → Commit

1. **Roster กับ Queue:** roster คือรายชื่อเริ่มต้นที่ต้องเก็บครบ แม้ล้มหรือออกสนาม;
   queue คือโอกาสเรียงตามรายชื่อนั้นในรอบที่กำหนด ไม่ลบชื่อคนที่ไม่พร้อม.
2. **Opportunity กับ Action:** โอกาสบอกว่าใครอยู่ตำแหน่งนี้ แต่ยังไม่ได้โจมตีหรือ
   ป้องกัน การอ่าน NPC ที่พร้อมไม่ทำให้เกิด token หรือ damage.
3. **Eligibility กับ Decision:** ดู ALIVE/PRESENT/HP และสิทธิ์ slot ว่าทำได้หรือไม่;
   การเลือกช่วยหรือถอยเป็น policy อีกงานหนึ่ง ไม่มี NPC AI ใหม่ใน A.
4. **Disposition กับ Receipt:** ข้าม Player DOWN แล้ว cursor ไป NPC ได้ เป็นบันทึก
   ว่าโอกาสใช้ไม่ได้ ไม่ใช่ receipt ว่าทำ action เสร็จ และไม่ทำให้ clock เดิน.
5. **Revision กับ Generation:** revision นับ publication ใน encounter รุ่นเดียว;
   Restart เปลี่ยน generation แม้ใช้ actor ID เดิม จึงกัน request เก่าข้ามรุ่น.
6. **Atomic Restart:** ตรวจ actor สุดท้ายและแผนทั้งหมดก่อนเปลี่ยน root ถ้าผิด
   คนแรกก็ไม่ถูก reset และคิวเดิมยังเดินต่อได้ ทดลองดู rejected reset ใน report.
7. **Copy Snapshot:** เปลี่ยน HP/cursor ในสำเนาเป็นการเขียนบนกระดาษอีกใบ;
   authority ต้องคงเดิม ไม่เช่นนั้น UI จะเปลี่ยนผลรบได้โดยไม่มีสิทธิ์.
8. **ยังไม่ใช่ Playable M4:** ทำ → รัน → ดู assertion/before-after → อธิบาย →
   แก้ข้อผิดพลาดชนิดข้อมูล → commit source ที่ตรวจแล้ว เราพิสูจน์ฐานข้อมูล/คิว;
   ไม่มี RESCUE/RETREAT ใหม่ ไม่มีผลจบรบหรือฉากเล่นใหม่. หยุด Draft รอ review.


## M4-03B — Isolated RETREAT Transaction

**Implemented Candidate / Awaiting Independent Code & Evidence Review**,8November2026.
Canonical PR50 squash `5cf53e0d145d3a518fcedd458ba2a892eb52cb1f`; source tested
`c4a7c488726983e0d29fb3b085e34f5d855895cb`. Owner explicitly authorized B only and
selected an opt-in subclass because the **unchanged A test asserts B APIs absent**.
[Milestone authority](../../docs/README.md#current-status-and-next-roadmap) owns status;
[run record](evidence/m4-03b/run-record.json) owns commands/engine/outputs/delivery resolution.

### Architecture, exact APIs and schemas

Instantiate [m403_effect_candidates.gd](../../scripts/m4/m403_effect_candidates.gd)
for B. Despite its allowed filename, this is a thin **opt-in Encounter facade**;
it inherits [isolated_queue_outcome_encounter.gd](../../scripts/m4/isolated_queue_outcome_encounter.gd),
including the single `_root`, Registry and `_publish` gate. It does not wrap another
live Encounter. A retains its original public APIs. All candidate calculations are
pure in [m403_queue_adapter.gd](../../scripts/m4/m403_queue_adapter.gd).

| API | Exact input / result |
|---|---|
| `lock_self_retreat(request,capability)` | Exact9: `version:int=1, session:int, generation:int, expected_revision:int, queue_id:String, slot_id:String, request_id:String, actor_id:String, kind:String=RETREAT`; no target. AUTHORIZED / M403_RETREAT_LOCKED + detached token |
| `impact(token)` | Exact owned token; APPLIED / M403_RETREATED or semantic SKIPPED / M403_ACTOR_UNAVAILABLE; revalidate current authority/state, not `lock_revision` equality |
| `complete(token)` | APPLIED/SKIPPED only; APPLIED / M403_ACTION_COMPLETED; one real receipt, cursor+1; actor need not still be eligible |
| `cancel(token)` | LOCKED only; APPLIED / M403_ACTION_CANCELLED; cursor+1, no effect, receipt or clock |
| inherited `advance/restart` | Original exact5/exact6 envelopes; WAIT_ACTION advance rejects ACTION_IN_PROGRESS; restart clears all action ledgers/active token |

Exact15 immutable token fields:
`version:int,session:int,generation:int,round_id:int,queue_id:String,slot_id:String,
action_id:int,actor_id:String,kind:String,target_id:String,lock_revision:int,
authorization_id:int,window_id:String,request_id:String,episode_id:String`.
Version1/kindRETREAT/target=self/episode empty. Action/auth serials are issuer-owned
`authorizations.size()+1`, generation-bound; failed lock/publication consumes nothing.
Window=`slot_id + /retreat`. Entire `slot_` and `m403/` namespaces reserved, including
future slots/rounds. Request reuse rejects before allocation; owned full equality,
phase, current opportunity and consumption are checked before effect.

Root exact fields remain unchanged. Authorizations are keyed by integer action ID;
exact grant row=`token,phase,impact_reason,impact_revision,disposed_revision`.
Initial revisions−1 mean absent; impact/disposal revisions record **post-publication**
revision. Active operation is null or the owned action ID. Exact completion receipt:
`action_id:int,authorization_id:int,slot_id:String,actor_id:String,queue_id:String,
completed_revision:int,impact_reason:String`. Only COMPLETE creates it; no import API.
Receipt identity/result/revision must equal the corresponding completed grant.

UNAVAILABLE disposition keeps A's four fields and adds two:
`slot_id:String,actor_id:String,kind:String=UNAVAILABLE,observed_revision:int,
issuer_id:String=M403_ISOLATED_QUEUE,observed_actor:Dictionary`.
Observed actor is the exact detached Registry row (`definition,state,membership`),
validated using original factories; immutable definition/membership match current
roster, but historical state need not match live eligibility. `observed_revision`
is the actual **pre-publication** revision. COMPLETED/CANCELLED dispositions use
`slot_id,actor_id,kind,observed_revision,issuer_id,action_id:int`, without an observed
actor copy. They must match an owned grant/disposal revision. No old live root/import
compatibility is promised: restart constructs the new schema; historical evidence
stays unchanged. Original A scenario behavior/assertions/counts are retained.

### N50-INT-01 and lifecycle accounting

Revision counts every authorized publication; cursor counts dispositions. Lock and
Impact leave cursor unchanged; Complete, Cancel and unavailable Skip advance once.
Queue phases: READY (current opportunity, not automatic action admission), WAIT_ACTION
(owned pending action), DRAINED (finite queue consumed; no round close). Action phases:
NONE→LOCKED→APPLIED→COMPLETED, LOCKED→CANCELLED, LOCKED→SKIPPED→COMPLETED.

Whole-root validation reconstructs the exact receipt set, one active grant, unique
slots/requests, every historical disposition, and a gap-free, duplicate-free set of
revision events. B's serial lifecycle has lock at L+1, impact L+2 and completion L+3
(or cancel L+2); no legal concurrent producer exists here. C must extend this event
accounting when adding reviewed producers, rather than claiming B supports them now.
Every publication compares the **whole candidate** to the legal pure transition from
current authority. Historical plausible-but-forged observations may pass structural
checks but cannot be published. No validator disabled and no fake receipts.

- **N50-INT-01A PASS:** real publications/interleaved skips (B10–11), actual revision
  differs from cursor/index; stale/duplicate/forged requests reject N-all.
- **N50-INT-01B PASS — structural scope:** B02 proves previously disposed Player can
  be ALIVE in a pure future model without slot reinsertion; forged history rejected.
  No legal aggregate RESCUE producer; **M403-16 end-to-end not claimed**.
- **N50-INT-01C PASS:** original A source/assertions unchanged,94cases/1,165assertions.
  Preliminary pre-action gate is archived separately with its source snapshot.

### Atomicity, rejection and boundaries

Request precedence: exact types/shape/version/kind → session/generation → capability
→ duplicate request → phase/active/queue/current slot → expected revision → reserved
namespace → Party/actionability → P>1 AND E>0 boundary dependency → candidate validation.
Token precedence: shape/types/version → session/generation → full owned equality
→ duplicate/cancelled accounting → phase/current queue/slot → legal action phase
→ domain revalidation → current revision/candidate gate. Cancel replay is
DUPLICATE_OPERATION; impact/complete of cancelled action is ACTION_CANCELLED.
Lock_revision remains immutable audit. Rejection is **N-all**, including counters,
grants, receipts and root revision. Successful Lock/Complete/Cancel are N-effect;
Impact changes only self participation and derived eligibility, plus action accounting.
All unrelated actors, HP/maxHP/IDs/roster/round/clock/outcome/summary remain unchanged.

B has **no Guard ledger or production Guard field**. Exact root/actor schemas admit
no stale guard authority in this scope; production Guard is untouched. Guard-domain
release integration is deferred, not marked verified. Zero-active-Enemy and last-active-Party retreat
reject BOUNDARY_DEPENDENCY before lock/effect; changed availability before impact is
only a detached observation diagnostic (no legal live producer). Legal pending token
can still cancel; no partial retreat or encounter outcome is invented.

### Fresh verification and coverage limits

Engine `/Applications/Godot.app/Contents/MacOS/Godot`,
`4.7.2.stable.official.ed1daf0bf`. **150 independent cases /3,339 assertions /0 failures**,
zero per-frame checks. Fresh R51-01 canonical77/candidate82stages PASS; all exits0, no
unexpected errors/timeouts; five expected negative errors separate. A94/1,165,
M40178/525, M40255/1,188; all21 inherited suite counts identical. Legacy6cases/
5,892frames identical to fresh canonical and the provenanced inherited pre-cutover
reference. Failed development run retained (a no-op fault test, corrected without
changing runtime constants or inherited tests). GUI/F5/F6/keyboard/visual NOT RUN.

| M403 rows | Actual scope |
|---|---|
|01–07,09,40,43|FULLY PROVEN in B's isolated transaction domain; actual API lifecycle/replays/identity|
|08|NOT RUN / DEFERRED TO C; no legal SEALED producer, no fake sealed fixture|
|10|DIAGNOSTIC-ONLY / pure bounded candidate revalidation and completion; no legal mid-action damage producer|
|22|B rejection boundary proven; terminal outcome/freeze/settlement DEFERRED TO C|
|47–48|FULLY PROVEN for automated preservation/regression in this candidate; no manual/production adoption claim|

[Coverage and case mapping](evidence/m4-03b/coverage.json),
[every input/before-after/assertion](evidence/m4-03b/m4-03b-scenarios.json),
[compatibility gate](evidence/m4-03b/compatibility-gate.json),
[contract self-audit](evidence/m4-03b/review-checks.json),
[source hashes](evidence/m4-03b/source-comparison.json),
[Legacy](evidence/m4-03b/trace-comparison.json),
[raw logs/development history](evidence/m4-03b/run-record.json).
No terminal classifier/summary/settlement, new RESCUE/damage/HELP producers,
round seal/close/abort/next-round, autonomous policy, Guidance/UI or production changes.
SKIPPED Restart not executable through a legal producer; SEALED Abort/Restart deferred.
M402-06 remains BLOCKED / M402-24 PARTIAL. No C/M4-04/M4-05 work started.

### บทเรียนสั้น ๆ

Revision เปรียบเหมือนเลขรายการบันทึกทุกครั้งที่ระบบเผยแพร่ข้อมูล ส่วน Cursor คือ
ตำแหน่งสิทธิ์เล่นที่ยังไม่จบ จึงต้องแยกกัน: Lock จองสิทธิ์, Impact ให้ผลจริง,
Completion ปิดสิทธิ์, Cancel ใช้สิทธิ์ไปโดยไม่ให้ผล การข้าม Player ตอน DOWN เป็น
ประวัติว่า “ตอนนั้นทำไม่ได้” ไม่ใช่คำสั่งว่าต้อง DOWN ตลอดไป การฟื้นในอนาคตจึงต้อง
รักษาประวัติเดิมและไม่คืน slot ส่วน receipt ต้องมาจาก completion จริงเท่านั้น.


### R51-01 — Nonterminal RETREAT admission fix candidate

[Independent finding](https://github.com/shanwinder/wanderer/pull/51#pullrequestreview-5814945108)
on reviewed HEAD `f8dd844a80bd0a7cfb013fcacff4acf21eb0af45`: P>1 alone admitted
all-Enemy-HP0 fixtures, which require D10-A's VICTORY boundary. B does not implement
that classifier; new Lock must require **Active Party >1 AND Active Enemy >0**.
`active_enemies(view)` derives availability from authoritative initial Enemy IDs and
validated Registry rows (existing HP/can_act only; no Enemy lifecycle or mirror).

Public Lock preserves schema/session/generation/capability/duplicate/phase/queue/slot/
revision/reserved/domain precedence, then returns REJECTED/BOUNDARY_DEPENDENCY/N-all
for either boundary. Impact authenticates the owned token first, then blocks E=0;
when the actor remains actionable, P≤1 still blocks. The authoritative transition/
publication gate repeats these checks before building/publishing an effect. Existing
Complete/Cancel admission does not inspect this new boundary and remains unchanged.

B16 now cancels Party slots with Enemy A0/Enemy B10, skips A once, then returns B READY
without consumption; it no longer claims that actions may drain a terminal E=0 seed.
New **B139–150** cover repeated zero-Enemy Lock N-all, no grants/receipts/counters,
precedence variants, publication-gate refusal, restored legal nonterminal Lock/Impact/
Complete and bounded zero-Enemy pre-impact/settlement observations. The original
last-active tests remain. **Changing Enemy availability mid-action is diagnostic-only**;
no damage producer or fake terminal result is introduced.

[Current R51-01 evidence](evidence/m4-03b/r51-01.json) records150cases/3,339assertions,
reviewed→tested→delivery attribution and red/green history. Initial development harness
had a duplicate-local parse error (engine exit0 correctly failed the runner); corrected
harness against the reviewed runtime reproduced18failed assertions in150cases. Fixed
source passes; neither failed run is relabelled PASS. [Pre-fix evidence archive](evidence/m4-03b/pre-r51-evidence.zip)
preserves original138/3,138 records and logs exactly. Existing older-milestone evidence
is unchanged. **R51-01 awaits independent follow-up review**, not owner merge approval.


## M4-03C — Isolated Terminal / Summary / Continuation Proof

**Implemented Candidate / Awaiting Independent Code & Evidence Review**,8November2026.
This explicit owner task authorizes isolated C only. PR #51 is now merged at
`2c59e8d8e27c92c92344adcba9eded0d297cc547`, following the recorded independent
R51-01 follow-up PASS. The B candidate/pending wording above is its historical
record; B source/tests/evidence are unchanged. [Current milestone authority](../../docs/README.md#current-status-and-next-roadmap).

### One root and C51-ARCH-01

[m403_terminal_encounter.gd](../../scripts/m4/m403_terminal_encounter.gd) subclasses
the A authority directly, retaining the inherited `_root`, Registry reconstruction
and detached accessors. It does not instantiate a wrapped Encounter or second live
Registry/HP owner. Its override of `_publish` is the sole C root swap; original A/B
publication and validators are unchanged. Pure modules are
[classifier](../../scripts/m4/m403_outcome_classifier.gd),
[summary](../../scripts/m4/m403_summary.gd) and
[terminal rules](../../scripts/m4/m403_terminal_rules.gd).
The latter filename groups tightly coupled C transition/clock/fixture calculations
and replay validation, avoiding a circular clock/effect/summary authority. It holds
no live state; a separate round-clock owner is unnecessary.

C schema3 adds explicit admission, rescue uses/episode serial, declarations, frozen
witness, close/semantic ledgers, Abort grants/consumption, terminal stops, prior-round
queue/witness/declaration history, seed and journal to A's domain fields. `seed` is
immutable constructor provenance, not current HP; `journal` contains exact successful
operation/payload/post-revision records. Reconstructing from the validated seed and
each legal operation proves the entire candidate, including all original IDs,
actors/clock/resources, action grants/receipts/dispositions, phases and summaries.
Revision equals journal length; cursor counts opportunities only. Old action-only
L+2/L+3 accounting is never reused as global clock/event accounting.

Publication authenticates requests/tokens, calculates a detached candidate, validates
its full reconstruction, compares it with the exact legal transition from current
root, reconstructs the owned Registry and swaps once. No callback/await/signal occurs
between final validation and swap. No public root/receipt/witness/summary import or
raw state setter exists. Underscore methods follow the existing harness convention;
this is not an adversarial production security model. Full-history replay/copying is
appropriate to this finite proof; scalability/performance is not established.

**C51-ARCH-01 PASS:** original A94/1,165 and B150/3,339 pass unchanged; no C surface
added to A/B; C01–07 prove admission separation, invalid phases, revision/cursor and
larger finite rosters; C34–43 prove actual multi-round candidates/history/clock and
R49 boundaries. [Compatibility evidence](evidence/m4-03c/compatibility-gate.json).

### Exact C APIs

All scalar fields are strictly typed; version is integer1. Base request exact5 =
`version:int,session:int,generation:int,expected_revision:int,queue_id:String`.
Round request exact6 adds `round_id:int`. All capability arguments require the owned
fixture capability; it is a harness authority, not a Player-issued NPC command.

| API | Exact schema and behavior |
|---|---|
| `restart(request,capability)` | Base5 + `fixture:Dictionary` (exact6). Fixture exact3=`actors:Array,round_plan:Array,clocks:Dictionary`. Actors/plan use original A/B factories/order; optional per-DOWN seed in clocks exact2=`entry_round:int,budget:int`. Default DOWN B2/current first round; DEAD inactive0. Validate entire fixture before G+1/revision0/OPEN/READY/unadmitted/ABSENT. SEALED rejects; invalid frozen reset N-all |
| `open_round(request,capability)` | Round6. Initial request binds prepared round; after CLOSED names next finite plan round while authenticating current queue ID. Derive new Q internally, preserve G/actors/resources/history. Admission classifies terminal seeds before any action; finite exhaustion rejects N-all |
| `advance(request,capability)` | Base5; admitted OPEN only. One unavailable historical disposition/cursor step; eligible read READY/SLOT_READY is N-all. No fake command/action |
| `lock_self_retreat(request,capability)` | Base5 + `slot_id,request_id,actor_id,kind=RETREAT` (exact9, strings). Self target derived. B keeps P>1/E>0; C permits last-active exit only with full atomic terminal freeze |
| `lock_fixture_attack(request,capability)` | Lock9 + `target_id:String,amount:int` (exact11), kindATTACK. Current eligible slot, opposing target, positive amount≤target maxHP; bound into immutable token. No damage0/no-op receipt. Enemy target must equal admission declaration, even if it has since become unavailable |
| `lock_fixture_rescue(request,capability)` | Lock9 + `target_id:String` (exact10), kindRESCUE. Distinct DOWN Party/current episode, eligible Party helper/use1. HP1/retire episode/use0 atomically; no slot reinsertion/refund |
| `impact/complete/cancel(token)` | Exact owned full token equality. RETREAT/RESCUE token15 retains A/B identity fields; ATTACK adds `amount:int` (exact16). Immutable window/lock revision/episode; no caller effect/result import. Impact applies or settles SKIPPED once; only Complete creates real receipt; Cancel is pre-impact only |
| `seal(request,capability)` | Round6; OPEN/admitted/DRAINED, all opportunities owned/accounted, no pending,≥1 real completed receipt, active sides/nonterminal. Freeze owned witness12 and issue close event11 once; no clock/HP delta |
| `close(event)` | Exact11 M403-owned event; authenticate equality, unused primary/semantic identity, SEALED/current Q/R/witness/revision. One batch grace/tick/death + consumption + CLOSED, then classifier consistency gate, all one publication |
| `authorize_abort(request,capability)` | Round6 + `request_id:String,kind:String=ABORT` (exact8); admitted OPEN/no active action. Separate request namespace, reserved issuer prefixes. Return token10=`version,kind,issuer_id,session,generation,round_id,queue_id,authorization_id,request_id,issued_revision` |
| `abort(token)` | Exact owned token10, issuerM403_ISOLATED_ABORT. OPEN/SEALED current round only, grant pre-issued OPEN. ABORTED/STOPPED + administrative outcome/summary/consumption, no tick/effect/receipt. A LOCKED action is invalidated, never terminal-completed |
| `summary_snapshot(identity)` | Exact4=`version:int,session:int,generation:int,outcome_id:String`. Before freeze ABSENT/SUMMARY_NOT_FROZEN; matching frozen read returns detached outcome/summary with no mutation; stale G rejects |

Action token15 fields remain:
`version,session,generation,round_id,queue_id,slot_id,action_id,actor_id,kind,target_id,
lock_revision,authorization_id,window_id,request_id,episode_id`.
Attack `amount` is the only additional C token field. C does not widen original B
schema or M402 issuer/action/event schema. Request IDs reserve all `slot_`/`m403/`
keys including future identities; action and Abort request maps are separate domains.

Gate order: exact shape/types/version/kind → session/generation → capability or owned
full token equality → authenticated duplicate → phase/admission/current Q/slot →
expected request revision → actor/target/episode/resource → complete candidate.
Token lock revision is immutable audit; effect revalidates current root. Rejections
are N-all, including journal/counters/history/frozen result. Read-only eligible-slot
and summary/diagnostic calls do not publish.

### Terminal, summary, rounds and clocks

D10 exact precedence: P>0/E>0 ACTIVE; P>0/E0 VICTORY; no active Party/all retreated
PARTY_RETREAT; R>0 plus DOWN/DEAD MIXED_WITHDRAWAL; no active/retreated Party plus E0
DEFEAT/MUTUAL_INCAPACITATION; otherwise DEFEAT/NO_ACTIVE_PARTY. Malformed/empty
rosters reject. Classifier tests are separated from initial-boundary freezes and
legal effect-triggered freezes; none claims simultaneous damage.

Effect + outcome + summary freeze in one publication. OPEN terminal becomes ABORTED,
future opportunities receive terminal-stop accounting; only the exact APPLIED/SKIPPED
causal token retains TERMINAL_SETTLING. Current legal terminal producers apply effects;
a SKIPPED impact changes no P/E, so causal-SKIPPED terminal is unreachable here. Its one completion clears outstanding work,
creates one receipt and STOPPED, without changing effect/freeze revision/summary or
making ROUND_CLOSED. Abort has no causal lane for an unimpacted token.

Summary exact11 envelope/domainM403_ISOLATED_SUMMARY, Party row7/final_down exact4
(or empty), Enemy row4 follow approved §8 unchanged. Full initial stable roster once,
separate HP availability for Enemy (HP0 never DEAD), actual DOWN/DEAD/RETREATED retained;
no aftercare/save/UI. C25–32 include missing row/duplicate ID/wrong generation/freeze
revision rejection and detached-copy/frozen-reset tests.

Witness exact12: `session,generation,round_id,queue_id,witness_id,expected_opportunities,
action_receipts,dispositions,outstanding,aborted,phase,revision`.
Close event exact11: `version,kind,issuer_id,session,generation,round_id,event_id,
witness_id,sealed_revision,authorization_id,queue_id`; issuerM403_ISOLATED_QUEUE.
One derived queue key encodes the semantic `(session,generation,round_id)` identity;
a fresh unissued event cannot bypass it. Witness remains the frozen SEALED fact after
close; round history retains earlier queue/dispositions/declarations. No unseal/reseal.

Natural close alone ticks active DOWN episodes from one pre-close root: entry-round
B2 grace, next valid closeB1, nextB0/DEAD/PRESENT HP0 inactive, retained ID. Retired
RESCUE episodes and DEAD never tick. Enemy declaration is first active Party in stable
order at admission; no retarget after rescue/retreat. Unavailable declared target can
settle one genuine SKIPPED action, which still requires real completion.

M403-44 **V1 C42 / V2 C43 FULLY PROVEN**: actual fully cancelled OPEN/DRAINED queue
rejects NO_REAL_PROGRESS; actual final CLOSED nonterminal round rejects PLAN_EXHAUSTED.
Identical retries, diagnostics twice, stale revisions and whole-root N-all are checked;
no fake close, tick, slot, stored SUSPENDED or infinite generator.

### Reproducible verification and honest coverage

Godot `4.7.2.stable.official.ed1daf0bf`, source
`5b37e061027649c6ef4be5c61a963659a82ed939`: **97 cases /5,458 assertions /0 failures**,
zero per-frame checks. Fresh canonical **82/82**, candidate **88/88 stages PASS**;
A94/1,165, B150/3,339, M40178/525, M40255/1,188 unchanged. All inherited suite counts
retained; Legacy6cases/5,892frames identical. All final exits0, unexpected errors0,
timeouts0; exactly five expected negative-action errors separate.

[Run record / exact all-flags commands / engine / source and delivery resolution](evidence/m4-03c/run-record.json),
[case index / all assertion booleans](evidence/m4-03c/case-index.json),
[exact raw C scenario JSON with every input/before-after root, compressed](evidence/m4-03c/m4-03c-scenarios.zip),
[all48 M403 mappings](evidence/m4-03c/coverage.json),
[six-domain transition/contract audit](evidence/m4-03c/contract-audit.json),
[final88](evidence/m4-03c/final-results.json), [fresh canonical82](evidence/m4-03c/canonical-results.json),
[regressions](evidence/m4-03c/regression-comparison.json),
[source integrity](evidence/m4-03c/source-comparison.json),
[Legacy](evidence/m4-03c/trace-comparison.json),
[raw final logs/reports](evidence/m4-03c/logs.zip),
[raw canonical logs/reports](evidence/m4-03c/canonical-logs.zip),
[development failures and exact changing source](evidence/m4-03c/development-logs.zip),
[self-audit](evidence/m4-03c/review-checks.json).

| Boundary | Actual status |
|---|---|
| M403-08/16/22/44 | FULLY PROVEN in isolated C: legal SEALED rejection, actual RESCUE/no reinsert, last-active terminal settlement, both R49 operations |
| M403-10/14/15 | DIAGNOSTIC-ONLY C94–96: synthetic detached mid-action actor/Player DOWN, rejected as live history; no legal serial opposing producer |
| M403-13 | PARTIAL: unavailable Player fixture slot denied; production Player Command/Guidance API and new reason not introduced |
| M403-25 literal final planned Enemy slot killing last Enemy | UNREACHABLE BY DESIGN; opposing targets only and stable Party→Enemy order. Legal earlier last-Enemy impact/no close is proven |
| Clock-caused terminal after strict seal | UNREACHABLE BY DESIGN C97: P>0/E>0 seal; tick only prior DOWN, so P/E unchanged. Post-close classifier remains a guard |
| M403-26/27 | FULLY PROVEN pure precedence/seeded boundary only; no simultaneous damage claim |
| M403-42 | PARTIAL for a hypothetical pending SEALED action, excluded by strict seal; actual SEALED new-work/Restart denial and Abort recovery proven |
| Original M402-06 / M402-24 | BLOCKED end-to-end / PARTIAL historical statuses unchanged |
| Main/Legacy/Guidance/NPC policy/UI/manual visual | Protected unchanged source; automated regressions run. No integration/AI/GUI/keyboard/visual acceptance claim |

### บทเรียนตาม v0.4

Goal คือแยก “ผลเกิดแล้ว” ออกจาก “งานค้างจบแล้ว”: เมื่อโจมตี Enemy ตัวสุดท้าย
HP0 ผลและ summary ต้องปรากฏพร้อมกัน แต่ completion ของ token เดิมยังต้องจบได้
อีกครั้งเดียว โดยไม่ตีซ้ำหรือเดิน clock. Concept คือ root เดียวเผยแพร่ทั้ง transaction;
revision นับการเผยแพร่ ส่วน cursor นับโอกาสที่ใช้แล้ว จึงเป็นคนละตัวเลข.

Do/Observe: อ่าน C34 แล้วเดิน Player DOWN→ถูกข้าม→NPC RESCUE→Player HP1
แต่ไม่ย้อน cursor; ต่อเมื่อปิดรอบด้วยงานจริงและเปิดรอบใหม่ จึงได้โอกาส Player ใหม่.
Explain: การช่วยคนเปลี่ยนชีวิต ไม่ได้คืนโอกาสที่ผ่านไป และ Enemy ยังยึด target
ที่ประกาศตอน admission ไม่เปลี่ยนตามการฟื้น. Development runแรกจับ fixture
ที่พยายามเปลี่ยน target หลัง rescue; แก้ fixture ให้รอ admission ใหม่ ไม่แก้กฎให้ผ่าน.
Adjust/Commit: เทียบ before/after และ assertionจริง, commit source ที่ทดสอบ,
เก็บ failure เดิม แล้วส่ง Draft รอ Independent Code & Evidence Review.

หยุดหลัง Draft PR เท่านั้น: no merge/auto-merge/delete feature branch, M4-04/M4-05,
D08/D16/full D09, production integration, aftercare/persistence หรือ UI.
