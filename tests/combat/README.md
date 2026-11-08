# Combat queue regression

Requires Godot **4.7.2** and Python 3 (standard library only).
Run from any directory:

```sh
python3 tests/combat/verify.py --godot /path/to/godot --output /tmp/wanderer-queue-check
```

Choose a new output directory for each run. The runner copies Git-tracked and
non-ignored source files into a fresh `snapshot/`, excluding `.godot` and `.git`.
It imports assets, parses all combat scripts and the harness, starts the configured
main scene, then runs the gameplay and negative tests. Each step preserves its
command, stdout/stderr `.log`, Godot `.engine.log`, exit code `.exit`, and a record
in `results.json`. Unexpected engine/script errors fail verification even if
Godot exits 0. A timeout is recorded as exit 124.

The gameplay suite instantiates the actual combat scene, emits button/target
selection signals, and waits for real engine Tweens and callbacks. By default,
`--fixed-fps 60` advances simulated time without wall-clock synchronization;
it does not change `combat_speed_scale = 0.70`, animation durations, damage or HP.
Use `--real-time` to run with wall-clock synchronization. Only the defeat check
uses a low-player-HP fixture; both enemy kill orders use the original HP values.
Frame checks verify command locking while every action Tween is active.

After importing a project, the harness can also be run directly:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/combat/queue_regression.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat/queue_regression.gd -- --invalid-actions
```

The second command intentionally emits five errors: an empty queued action, an
unexpected player action, and three invalid dispatch attempts (idle, during a
Tween, and after round completion). The Python runner checks their exact messages
and counts separately from normal gameplay, where no errors are permitted.

## Recorded verification — 2026-11-03

Engine: `4.7.2.stable.official.ed1daf0bf` (macOS, headless).
Baseline: `e25f16fa58f76c78be4804d5dd749d7076294694` on
`visual-combat-test-1`.

The unchanged baseline **FAILS** the same gameplay suite (exit **1**, one failed
check: round does not reach idle after killing B). A direct two-attack reproduction
also exits **1** and records:

```text
Round 1: turn=2 A=15 B=5 player=25 pending=0 busy=false attack_disabled=false
ERROR: Combat Turn Flow: ไม่มี Action ถัดไปหลัง NPC
Round 2: turn=2 A=13 B=0 player=23 pending=0 busy=false attack_disabled=true
REPRODUCED
```

Root cause: `combat_turn_flow.gd:64` correctly returns `{}` when exhausted.
At baseline `combat_prototype.gd:1073`, finishing A sees B still pending and calls
`_start_next_npc_action()`. That method skips dead B recursively at line 729, then
treats normal exhaustion as an error at line 722. The round-end code is only in
the counteraction completion path, so the round never increments or unlocks.

The fix checks `pending_count()` before consuming an action and uses one round-end
helper after all actions, including dead-tail skips. A queued empty dictionary
still reports the original error. Dispatch requires an active round and no active
Tween; command locking remains set across enemy handoffs until actual exhaustion.
Victory/defeat short-circuit dispatch and keep the existing result handling.

| Verification on fix | Status | Exit |
| --- | --- | --- |
| Engine version | PASS | 0 |
| Clean import | PASS | 0 |
| Parse prototype, turn flow, targets, regression harness (separate runs) | PASS | 0 each |
| Configured main scene startup, 120 frames | PASS | 0 |
| Automated gameplay, 14,395 checks including per-frame locks | PASS | 0 |
| Negative tests, 983 checks and exactly five expected errors | PASS | 0 |
| Manual F6 visual/gameplay review | NOT RUN | — |

| Requested regression | Observed result |
| --- | --- |
| B dies before A; play continues | PASS — after two attacks: turn 3, A=13, B=0, Player=23; next round works |
| A dies before B; play continues | PASS — after three attacks: turn 4, A=0, B=10, Player=18; next round works |
| Dead enemies cannot counterattack | PASS — per-enemy counter logs and exact HP checked |
| Living enemies keep queued actions | PASS — full Player/NPC1/NPC2/NPC3/A/B order and surviving B after skipped A |
| Normal exhaustion starts the next round once | PASS — exact increment, drained queue, idle wait and duplicate-dispatch rejection |
| Both enemies dead means victory, no new round | PASS — both kill orders, result panel after final Tween, commands stay locked |
| Restart during action cancels the old queue | PASS — player, NPC1, NPC2 Guard, Enemy A and Enemy B; wait 12 simulated seconds, then play a fresh round |
| Attack, Defend, NPC2 Guard and Damage unchanged | PASS — exact HP, single-use Guard, Defend reduction for both counters; defeat also checked |

No gameplay constants, scene layout, Target UI, assets or animations were changed.
Early attempts were retained in the local evidence directory: the sandbox blocked
Godot editor settings/certificate access; an initial harness attempt incorrectly
read `RichTextLabel.text` instead of `get_parsed_text()`. The final clean run has
neither issue. Only the final run supplies the PASS results above.

## Manual F6 review

1. Open `scenes/combat/combat_prototype.tscn` in Godot 4.7.2 and press F6.
2. Select Enemy B. Attack twice, waiting for each full round. Confirm B=0, A=13,
   Player=23, round 3, and command buttons available; B must not counter in round 2.
3. Attack A twice more. Confirm victory in round 4, no new round, and the result
   panel appears after the final action returns to formation.
4. Restart. Attack A three times. Confirm A=0, B=10, Player=18 and round 4;
   B still counterattacks in the round that A dies. Continue to victory.
5. Restart and Defend: A=12, B=12, Player=28; all NPCs attack. Restart and Attack A:
   A=8, B=12, Player=25; NPC2 guards and reduces only the first counter by 1.
6. Restart during player/NPC/enemy motion. Wait, then issue another command;
   no old damage/action should resume. Check command locking and the existing
   44px lunge, compact formation, pacing and animation visually.

## Optional M4-01 isolated data/state proof

Add `--m4-data-proof` to parse the isolated Party lifecycle model/registry/Encounter
and run the data harness. It works independently and adds five stages; default
runner behavior and all existing expectations remain unchanged. Current candidate:
78 independent cases / 525 checks (zero per-frame checks); full69stages PASS.
See [contract, exact commands, fresh evidence and Thai learning notes](../actors/README.md#m4-01--isolated-datastate-proof-candidate).
This does not enable lifecycle gameplay in Main or Legacy.

## Optional M2B-01 actor data proof

Add `--actor-proof` to parse and execute the isolated actor data tests. Use both
`--npc-proof --actor-proof` for legacy combat, M2A-02, M2A-03 and M2B-01 together.
Neither flag changes the default legacy suite or its five expected negative errors.
See [Actor architecture, examples and current run evidence](../actors/README.md).

## Optional M2B-02 ownership proof

Add `--ownership-proof` to parse/run the isolated Encounter ownership harness.
It is independent of `--actor-proof` (the unchanged M2B-01 suite) and `--npc-proof`.
Use all three flags for the complete M2B-02 regression. See
[ownership architecture and current evidence](../actors/README.md#m2b-02--single-source-encounter-hp).

## Optional M2C-02 party foundation proof

Add `--party-foundation-proof` to parse ActorDefinition, ActorRuntimeState,
ActorRegistry, FullPartyEncounter and the focused harness, then run the harness.
This opt-in works independently; combine it with `--npc-proof --actor-proof
--ownership-proof` for F22 full regression. Existing suites and assertions are unchanged.
See [contract, acceptance mapping and evidence](../actors/README.md#m2c-02--multi-actor-registry-and-encounter-foundation).


## Optional M2C-03 party turn proof

Add `--party-turn-proof` to parse the shared Resolver, FullPartyEncounter and
`tests/actors/party_turn_proof.gd`, then execute P1–P16 and edge cases. This flag
works independently. Combine all five opt-in flags for the complete regression:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2c-03-final-2 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof --party-turn-proof
```

Use a fresh output path. On `0f33e1b` with Godot
`4.7.2.stable.official.ed1daf0bf`, all 33 stages pass, runner exit 0:
M2C-03 1,250; Combat 14,395; negative 983 + exactly five expected errors;
M2A-02 412; M2A-03 5,166; M2B-01 122; M2B-02 219; M2C-02 382 checks.
Legacy harnesses/expected counts are unchanged. Manual F6 **NOT RUN**.
See [contract, scenario results, Thai learning notes and durable evidence](../actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).

## M2C-04 — Playable Full Party Integration

**สถานะภายหลัง record นี้:** merged ผ่าน PR #37 (`08f2a973`) แล้ว. เจ้าของรายงานตรวจเองก่อน merge
โดยไม่มีหลักฐานราย scenario เพิ่ม; จัดเป็น Owner-Reported Acceptance. ข้อความ pending ใน record
ด้านล่างคือสถานะ ณ งาน M2C-04. M2D-02 ตรวจ merged metadata และ runtime ใหม่ตามหัวข้อถัดไป.

งานวันที่ **4 พฤศจิกายน 2026 Asia/Bangkok**, implementation mode. ฐาน clean
`visual-combat-test-1` local/remote/merge-base `737e380c8549a2ef6bc306184973d2e8dbb3f757`;
GitHub ยืนยัน PR #36 merged. ตรวจ open PRs #2/#17 และ branch แล้วไม่มี M2C-04 ซ้ำ.
Branch เดียว `codex/m2c-04-playable-full-party` → Draft PR ไป `visual-combat-test-1`.
สถานะ milestone ปัจจุบันอยู่ที่ [docs index](../../docs/README.md#current-status-and-next-roadmap).

### Scene และ ownership

เปิด [full_party_proof.tscn](../../scenes/combat/full_party_proof.tscn) แล้วกด **F6 / Run Current Scene**.
Root Control ต่อ [full_party_proof.gd](../../scripts/combat/full_party_proof.gd); สร้าง HUD และ
Sprite จาก assets เดิมเมื่อ `_ready()`. ไม่กำหนด Main Scene ใหม่ ไม่แก้ combat หลัก,
FullPartyEncounter, Registry, RuntimeState หรือ Resolver. ไม่คัดลอก controller เดิมทั้งไฟล์.

| เจ้าของ | หน้าที่ |
| --- | --- |
| FullPartyEncounter → Registry → ActorRuntimeState | HP หนึ่งชุด, actor IDs, queue, decisions, HELP, Guard, tokens, effect/completion, round/terminal |
| Presentation Controller | Buttons, target/scenario pickers, Sprite/tween, labels/log, epoch, local locked-token copy และ visual phase |

Controller อ่าน `encounter.snapshot()` เท่านั้นสำหรับ HP/HELP/Guard และ readiness;
ไม่มี local authoritative HP/resource/guard. Preset เปลี่ยน `initial_hp` ก่อน `restart(fixture)`;
S3 ส่ง enemy declarations ผ่าน `begin_round(action, target, enemy_targets)`.
ไม่มีปุ่มสั่ง NPC. Target Picker มีเฉพาะศัตรูที่พร้อม; ตรวจ metadata ซ้ำก่อนส่ง Player ATTACK.
ATTACK/DEFEND/Target/Scenario ล็อกขณะ busy; Restart ใช้ได้เสมอ. Victory/Defeat ล็อก Player
จน Restart (ยังเลือก preset ใหม่ได้เมื่อ motion จบ).

### Flow และ visual lifetime

```text
Player command → begin_round → begin_next_action
→ WINDUP (locked actor/action/target/reason)
→ resolve_action(token) at IMPACT → snapshot HUD / real effect feedback
→ SETTLING / return saved home → complete_action(token)
→ HANDOFF → Encounter's next slot, or READY / VICTORY / DEFEAT
```

ไม่มี presentation queue อีกชุด. `_advance()` ขอเพียง slot ถัดไปจาก Encounter;
NPC2/3 ยังแสดง **Waiting to decide** จนถึง slot จริง. Reason map เป็นคำอธิบายเท่านั้น.
NPC row เก็บ action/target/reason และ effect/delta ของ slot ที่ทำแล้ว; snapshot ล่าสุดเป็นผู้ตัดสินใจ
slot ถัดไป. Log บันทึกลำดับ, round, reason, effect และ HP before→after.

คง Speed0.70, Lunge44px และ Homes NPC1(320,480), NPC2(405,435), NPC3(475,509),
Player(570,465), A(970,506), B(1100,424). ATTACK lunge0.24s → impact → hold0.42s
→ return0.22s (หารด้วย speed0.70 ตาม Tween); DEFEND/HELP ใช้ช่วงเตรียมเดียวกันแต่ไม่ lunge.
Guard เป็นสีฟ้า/คำว่า GUARD, HELP สีเขียว/HP+, damage สีแดง/HP− เฉพาะ effect ที่ลงจริง;
SKIP แสดงเหตุผล/delta0 ไม่มี hit flash. HUD ใช้หกคอลัมน์ใต้สนามเพื่อไม่ให้ HP ซ้อนใน compact formation.
Floating delta อยู่ใกล้เท้าเป้าหมายและลอยขึ้น24px ไม่ทับ global reason/effect rows.

`_current()` ตรวจ epoch, busy, phase, Encounter generation/active state และเทียบ
encounter_id/generation/round_id/action_id/actor_id/decision กับทั้ง local token และ locked record.
IMPACT รับเฉพาะ LOCKED; SETTLING/finish รับ RESOLVED/SKIPPED. Early/duplicate/forged callbacks
จบก่อน side effect. Restart เพิ่ม epoch, kill Tween เดียวที่ถือทั้ง motion/popup/callbacks,
restart Encounter ผ่าน public API, ล้าง token/feedback/tint/popup/phase, คืน home และ refresh snapshot.
`_exit_tree()` เพิ่ม epoch/kill Tween เช่นกัน. Token contract เดิมไม่เปลี่ยน.

### Presets และ expected result

| Preset | วิธีลอง / expected เมื่อใช้คำสั่งที่ระบุ |
| --- | --- |
| S1 Normal | ATTACK A: Player30→24, A15→7, B12; DEFEND: Player30→28, A15→12, B12; หก slots |
| S2 Player Needs HELP | DEFEND: Player6→10จากNPC1 HELP แล้ว NPC2/3 ATTACK A; enemy hits−1ทั้งคู่ → Player8, A13; HELP NPC1=0, คนอื่น1 |
| S3 Self-DEFEND | DEFEND: NPC1 HP3 ถูก A เล็งจึง DEFEND; A hit3ลดเหลือ1 → NPC1=2; B hit Playerเหลือ1 → Player29 |
| S4 Multiple HELP | DEFEND: Player1→5→9→13, NPCทั้งสามใช้ HELP คนละครั้ง; enemies−1ทั้งคู่ → Player11 |
| S5 A Falls / B Alive | ATTACK A5→0; NPCทั้งสามเลือก B ก่อน lock → B9; A SKIP, B hit Player30→27 |
| S6a Victory | ATTACK A5→0 เมื่อ B0; จบหลัง Player return, queueหยุด, no new round |
| S6b Defeat | NPCทั้งสาม0, Player1; ATTACK A แล้ว NPC SKIP; A hit Player→0, Bไม่ลง effect; terminalหลังreturn |
| S7 Unavailable / Restart | NPC1/A0; pickerเฉพาะB; dead slots SKIP; ใช้ดู Restart ได้ทุกช่วง |

Restart รีเซ็ต target picker กลับศัตรูตัวแรกที่พร้อม ไม่จำค่า target จาก encounter เก่า.

### HELP threshold semantics ของ M2C-03

**คง gameplay contract เดิม:** ≤30% ตรวจครั้งเดียวตอน NPC ตัดสินใจต้น slot.
Effect boundary ตรวจ token/state, terminal, actorพร้อม, targetยังมีชีวิต, HELPเหลือ และ HPไม่เต็ม;
ไม่ตรวจ threshold30% ซ้ำ. Focused scene test ล็อก HELP เมื่อ Player6/30 แล้วจำลอง healก่อนimpact
ให้เป็น11/30; callbackจริงยัง heal4 เป็น15/30 และใช้ HELPครั้งเดียว. ถ้าขึ้นเต็ม30/30ก่อนimpact
จะ SKIP `HELP_UNAVAILABLE` และไม่ใช้ resource. นี่เป็น semantics ที่บันทึก ไม่ใช่ silent policy fix.
การเปลี่ยนให้ threshold ตรวจซ้ำต้องขอ owner approval แยก.

เฉพาะ harness ใช้ white-box Registry interruption เพื่อจำลอง actor/target ตายหรือ heal ระหว่าง
lock/impact (production ไม่มีทางทำเช่นนี้ และ public fixture mutations ถูกล็อกขณะ busy).
Controller ไม่แก้ Registry/internal state. Target ตายหลังlockให้ SKIP ไม่ retarget.

### Integration coverage และ verification

[harness จริง](party_playable_integration.gd) instantiate scene, emit button/picker signals,
รอ process frames/Tweens แบบ bounded; timeout เป็น failure, runner timeout exit124 ไม่ใช่ PASS.
ทุก frame ตรวจ HUD HP/HELP/Guard, locked reason และ command locks. ต่อ slot ตรวจ actual feedback,
44px lunge และ popup separation. 31 case records ครอบคลุม:

| Cases | Acceptance |
| --- | --- |
| I1 | Startup/6 actors, resolution, ATTACK/B picker, invalid metadata, command/scenario lock, full order, HUD, homes, single completion |
| I2 ×3 | Player DEFEND, HELP6→10→fresh ATTACK, independent multiple HELP1→5→9→13, NPC selfguard3→1 damage |
| I3–I4 | A killed before NPC lock→B, A dead skip/B alive counter; unavailable NPC/enemy no effect, picker excludes dead |
| I5 ×6 | Victory/Defeat queue halt and Restart; Restart at terminal IMPACT/SETTLING |
| I6 | Forged epoch/generation/action/actor/encounter/round/decision; early/duplicate impact/settle/complete; no extra effect or queue step |
| I7 ×12 | Restart Player/NPC1/A/B × WINDUP/IMPACT/SETTLING; killed Tween, unchanged HP/HELP/queue/UI after stale callbacks and elapsed time; fresh action with repeating action IDs safe |
| I8 ×6 | Actor/target invalidated afterlock, enemy unavailable/dead target, no retarget/no false hit, HELP threshold/full HP semantics |

ใช้ flag opt-in อิสระ `--party-playable-proof`; เพิ่ม **4 stages** จาก baseline33เป็น37:
controller/harness parses, proof startup และ scene integration. ไม่ลด/แก้ legacy assertions.

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2c-04-final-1 \
  --npc-proof --actor-proof --ownership-proof \
  --party-foundation-proof --party-turn-proof --party-playable-proof
```

ผลจริงบน tested commit **`9271aa5`**, engine **`4.7.2.stable.official.ed1daf0bf`**,
runner exit0; version/clean import/23 parse stages/main+NPC+fullparty startups ผ่าน,
**37 stages PASS** และไม่มี unexpected engine errors. Negative errors5รายการแยกตามเดิม.

| Suite | Expected / Actual checks | Failures / exit |
| --- | --- | --- |
| Combat | 14,395 / 14,395 | 0 / 0 |
| Negative | 983 / 983 + exactly5 expected errors | 0 / 0 |
| M2A-02 | 412 / 412 | 0 / 0 |
| M2A-03 | 5,166 / 5,166 | 0 / 0 |
| M2B-01 | 122 / 122 | 0 / 0 |
| M2B-02 | 219 / 219 | 0 / 0 |
| M2C-02 | 382 / 382 | 0 / 0 |
| M2C-03 | 1,250 / 1,250 | 0 / 0 |
| M2C-04 scene/Tween | 31 cases / 260,800 frame and boundary checks | 0 / 0 |

[Run record](evidence/m2c-04/run-record.json), [37 stage results/commands/exits](evidence/m2c-04/results.json),
[31 scenario expected/actual/action traces](evidence/m2c-04/scenarios.json),
[raw logs/engine logs/exits archive](evidence/m2c-04/logs.zip),
[source SHA-256](evidence/m2c-04/source-sha256.json),
[development failure/fix record](evidence/m2c-04/development-record.json).
จำนวน frame checks เป็นผล `--fixed-fps 60` ของ run นี้ ไม่ใช่เป้าหมายให้แก้ constants เพื่อให้ได้ตัวเลข.
Final documentation/evidence commit เปลี่ยนเฉพาะ docs/evidence หลัง tested commit;
ตรวจ runtime/tests/scenes/assets/project hash ตรง snapshot และ Final HEAD ก่อนส่ง PR.

Initial sandbox import FAIL แม้ exit0 เพราะ macOS certificates/editor settings; เก็บ raw failure,
ไม่กรอง errors. Dev2 พบ preset target จำ B ข้ามRestart และการตรวจ SKIP empty target;
แก้ให้ Restart clear picker และแสดง none สำหรับ no target แล้ว Dev3ผ่าน.
GUI smoke พบ floating HELPทับ globalfeedback; ย้าย popup ลงใกล้เท้าและเพิ่ม assertion.
Final runทดสอบ layoutแก้ล่าสุดรวม terminal restart gates. Python py_compile เคยถูก sandboxบล็อก
cache path; syntax checkแบบcompileโดยไม่เขียนcacheผ่าน และ runnerจริงผ่าน.

### บทเรียนภาษาไทยจาก GDScript ที่ใช้จริง

1. **Encounter กับ Presentation:** `encounter.resolve_action(locked)` ตัดสินผล HP/HELP/Guard;
   `_impact()` ทำหน้าที่อ่านผลแล้วแสดงสี/ข้อความ. ถ้า UIลบHPเองอีกครั้งจะเกิด damageซ้ำ.
2. **Snapshot:** `_refresh()` เริ่ม `var view: Dictionary = encounter.snapshot()` แล้วอ่าน
   `view.actors[id].current_hp`, `view.help_uses`, `view.guards`. ค่าที่แสดงจึงมาจากเจ้าของเดียว;
   snapshot เป็นสำเนาข้อมูล ไม่ใช่ RuntimeState ที่ UIเอาไปแก้ได้.
3. **Tween → effect boundary:** `_advance()` ต่อ `tween_callback(_impact.bind(epoch, locked))`
   หลัง windup. ก่อน callback HPยังเดิม; `_impact()` resolveครั้งเดียวแล้ว refresh. `_finish()`
   เรียก completeหลังreturnและไม่ได้ลงdamageซ้ำ. แยก “โดนแล้ว” กับ “แสดงจบแล้ว”.
4. **Epoch:** `epoch += 1` ใน Restart ทำให้ callbackที่จำเลขเก่าถูก `_current()`ปฏิเสธ.
   `motion.kill()`หยุดทั้งตำแหน่ง/popup/callback; epochยังกัน callbackที่ถูกเรียกซ้ำหรือค้างอยู่นอกTween.
5. **Token vs epoch:** token/generation กัน gameplayข้ามEncounter/actor/action; epochกันvisualข้ามฉากที่Restart.
   `_current()`ตรวจสองชั้นพร้อมphase; action_idเริ่มใหม่หลังRestartได้ แต่generation/epochเปลี่ยน.
6. **ตัดสินใจที่ slot:** `_advance()` ขอ `begin_next_action()` ทีละคน. S2 NPC1เห็นHP6แล้วHELP→10;
   NPC2เริ่มภายหลังจึงATTACK. ถ้าคำนวณสามคนล่วงหน้าจะโชว์HELPที่ไม่ตรงสถานการณ์ปัจจุบัน.
7. **Action ต้องตรง effect:** descriptionใช้ `locked.decision` เดียวกับEncounter ไม่เดาจากTween.
   EffectอาจSKIPแม้ล็อกATTACK; `_impact()`แสดง `effect.status/reason_code/hp_delta` จริง
   และflashเฉพาะAPPLIEDที่deltaไม่เป็น0. GuardแสดงGUARDโดยไม่มีdamageที่ยังไม่เกิด.
8. **Debug เมื่อภาพกับ HPไม่ตรง:** ดู log actor/action_id + phase → ตรวจ locked decision/target/reason
   → เปรียบ snapshotก่อน/หลังimpactกับ effect.hp_delta → ดู generation/epochและTweenkillตอนRestart
   → ตรวจ completeเกิดหลังreturnครั้งเดียว. ใช้ I6/I7 replay callbacksเพื่อแยกว่า effectซ้ำหรือUIเก่า;
   ห้ามแก้ damage/HP/constantsเพื่อกลบอาการ. เพิ่ม logชั่วคราวแล้วนำออกเมื่อเข้าใจสาเหตุ.

### GUI smoke review และ Owner F6 acceptance

Agent เปิด Godot4.7.2 editor แล้วใช้ **Run Current Scene toolbar (คำสั่งเดียวกับ F6)**;
physical F6 keyส่งผ่านUI automationไม่เริ่มเกม จึงใช้toolbar. Project viewport1280×720;
embedded game frameรายงาน1475×719พร้อมblackbars, เนื้อหาใกล้1:1. ตรวจด้วยตาจากGUIจริง:
startupครบ6sprites/compactformation/HUD, S1 DEFEND→NPC attacks→Player28/round2,
S2 HELPสีเขียว/6→10/HELP1→0 และ NPC2/3ยังWaitingก่อนslot. หลังแก้ popupทับfeedback
เปิดsceneใหม่แล้วตรวจ HELPซ้ำว่าข้อความแยกกัน. ไม่ได้บันทึกวิดีโอหรือ screenshotไฟล์ถาวร;
ภาพอยู่ในtool transcriptเท่านั้น. นี่เป็น **limited GUI smoke review** ไม่ใช่ owner acceptance.

**Owner visual acceptance: PENDING / NOT RUN โดยเจ้าของใน taskนี้**.
ยังไม่ได้ตรวจ GUIครบทุกpreset/ทุกRestartboundary, measured pacing/lungeด้วยvideo,
fullvisualquality หรือ maincombatใหม่; headlessใช้ยืนยันbehavior/positionเท่านั้น.

Owner checklist (บันทึก engine/commit/date/expected/actual และภาพ/videoเมื่อมี):

1. เปิด `res://scenes/combat/full_party_proof.tscn` ในGodot4.7.2 → F6 ที่1280×720.
   ตรวจ6ตัว, compactformationไม่ทับกัน, HP/HUDครบและtargetชัด. ดู44pxlunge/returnและpacing0.70ด้วยตา.
2. S1 ATTACK A/BและDEFEND; Playerควบคุมตัวเองเท่านั้น. สังเกต orderPlayer→NPC1→NPC2→NPC3→A→B,
   controlsล็อกระหว่างTweenแต่Restartใช้ได้. หลังreturnจบรอบreadyครั้งเดียว.
3. S2 DEFEND: NPC1 HELP6→10/HELP0; NPC2/3Waitingก่อนslotแล้วATTACK.
   อ่านactor/action/target/reason code+คำอธิบายและeffectได้จริง ไม่มีข้อความทับspriteหรือHUD.
4. S3 DEFENDดูNPC1guard/Ahit3→1; S4 DEFENDดูสามHELP; S5 ATTACK AดูAล้ม/NPCเปลี่ยนBก่อนlock/Bยังโจมตี;
   S7ดูSKIPไม่มีhitปลอม. เทียบค่าตารางpresets.
5. S6a/S6bดูVictory/Defeatชัด, queueไม่ค้าง/ไม่เปิดPlayerรอบใหม่, Restartกลับready.
6. S2หรือS1กดRestartระหว่างPlayerwindup, NPCwindup, NPCหลังeffectก่อนcompletion,
   A/Bwindup, enemyหลังeffect และsettling/return; รออย่างน้อย2วินาทีแล้วเล่นใหม่.
   ต้องไม่มีHP/HELPซ้ำ, motion/tint/popupเก่ากลับมา หรือcallbackข้ามEncounter.
7. จดคำอธิบายNPCที่อ่านไม่ทัน/สับสนและความรู้สึกpacing ส่งreviewก่อนปิดmilestone.

ขอบเขตคงเดิม: prototype D1–D13 ไม่ใช่ fullAI/finalturnsystem; ไม่มี items/equipment,
Trust/Guidanceใหม่, Down/Death, save/load, multiplayerหรือloreใหม่. Main Combat Migrationยังไม่อนุมัติ,
M2B-03deferred. หยุดหลังDraftPR; ไม่merge/enableauto-merge/deletebranchหรือเริ่มงานถัดไป.


## M2D-02 — Combat Presentation Adapter Foundation

ส่วนนี้เป็นบันทึก checkpoint ของ M2D-02 ก่อน merge PR #38; สถานะปัจจุบันและการอนุมัติ M2D-03
อยู่ใน [documentation index](../../docs/README.md#current-status-and-next-roadmap) และหัวข้อ M2D-03 ด้านล่าง.

งานวันที่ **4 พฤศจิกายน 2026 Asia/Bangkok**. ฐาน/merge-base/local/remote HEAD ตรงกันที่
`08f2a973ed39449b4afaeb0dbf88bf5264b01335` หลัง PR #37; working tree สะอาดก่อนเริ่ม,
fetch และตรวจ open PRs #2/#17 แล้วไม่มีงาน M2D-02 ซ้ำ. Branch
`codex/m2d-02-presentation-adapter` → Draft PR ไป `visual-combat-test-1` เพื่อรอ review.
Milestone authority อยู่ที่ [docs index](../../docs/README.md#current-status-and-next-roadmap).
M2D-01 Design Completed ตาม task เจ้าของ; งานนี้อนุมัติ D1/D9 และ extraction ที่จำเป็นเท่านั้น.
D2–D8/D10–D13 ยังไม่อนุมัติใน Main Combat. M2D-03/M2D-04 ไม่เริ่ม; M2B-03 Item deferred.

### Baseline ใหม่และ scene metadata

Inherited M2C-04 ทดสอบ `9271aa5` แต่ `full_party_proof.tscn` เปลี่ยน header/Scene UID,
Script UID และ root unique ID ภายหลัง; manifest เดิมตรง54/55ไฟล์บน merged base.
จึงรัน **ก่อนแก้ runtime** บน merged `08f2a973` จริง: Godot
`4.7.2.stable.official.ed1daf0bf`, **37 stages PASS / runner exit0**, zero unexpected errors.
ครั้งแรกภายใต้ sandbox import มี CA/editor-settings errors แม้ exit0 จึงเป็น FAIL;
เก็บหลักฐานไว้และรัน fresh directory ด้วยสิทธิ์ที่จำเป็นจนผ่านก่อน extraction.
ไม่กรอง engine errors และไม่แก้ assertions ของ suite เดิม.

เจ้าของรายงานตรวจ M2C-04 เองก่อน merge: **Owner-Reported Acceptance**;
ไม่มี scenario-level independent visual evidence เพิ่มจากเจ้าของ.

### Architecture, extracted และ remaining

[combat_presentation_adapter.gd](../../scripts/combat/combat_presentation_adapter.gd) เป็น
`RefCounted` ขนาดเล็ก. `owner.create_tween()` ผูก lifecycle กับ scene จริงโดยไม่เพิ่ม Node Tree.
รับ locked actor/target IDs, views ที่มี Node/home/sprite transform/tint, ค่า presentation จาก
Main Combat และสอง `Callable`. ไม่มี HP, Damage, Guard, NPC decision, target selection,
queue, terminal, ActorRuntimeState หรือ FullPartyEncounter ใน adapter.

| ส่วน | เจ้าของปัจจุบัน |
| --- | --- |
| Player ATTACK lunge0.18s → windup0.10s → strike0.10s → recoil0.14s → hold0.08s → return0.22s → handoff0.16s | Adapter; copy ลำดับ/property/easing/parallel groups เดิม |
| Sprite attack pose สองช่วงของ NPC/Enemy | Adapter primitive `append_attack_pose()` บน Tween เดิม; ไม่ย้าย flow/impact ของ NPC/Enemy |
| HP/actual damage/Guard/target validity/fallback/queue/locks/terminal | Legacy Controller + CombatTurnFlow + CombatTargets ตามเดิม |
| Damage popup, hit spark, HP flash, their cleanup | Legacy feedback functions เดิม เรียกจาก impact controller เดิม |
| Player DEFEND, NPC Guard/intents, remaining NPC/Enemy sequences, result panel/status/log/picker | Legacy Controller; remaining work ไม่ย้ายทั้งหมดใน foundation นี้ |
| Restart | Adapter cancel visual lifetime ก่อน; Controller ฆ่า remaining Tweens/feedback และคืนทุก home/tint ตามเดิม |

คง speed0.70, lunge44px, Compact Formation, idle, B tint/scale, shadows/Y-sort, visual timing เดิม.
ไม่แก้ scene, project settings, Encounter, Resolver, Registry/RuntimeState, turn-flow หรือ targets.

### Tween / Impact / Completion contract และ safety

Player command วางแผน Legacy queue และล็อก target ก่อนเรียก adapter:
`WINDUP → _impact(epoch,actor,target) → IMPACT → recoil/return/handoff → _complete → COMPLETED`.
`_impact` ตรวจ visual epoch/IDs/phase/Tween/node lifetime และตำแหน่งปลาย strike ก่อนเรียก
`_apply_player_hit()` **หนึ่งครั้ง**. Controller เดิมลง HP/feedback/terminal ที่จังหวะนี้.
`_complete` ต้อง IMPACT และทั้งสอง roots กลับ home แล้ว; จึงเรียก `_finish_player_attack()`
หนึ่งครั้งเพื่อคืนภาพและเดิน Legacy queue ต่อ. Completion ไม่ลง damage.

`phase` เปลี่ยนและล้าง Callable ก่อนเรียกออกไปเพื่อกัน reentrancy/duplicates.
`visual_epoch` เพิ่มเมื่อ cancel/new Player attack; เป็น visual lifetime เท่านั้น ไม่ใช่ Encounter
Action Token. Restart ฆ่า owning Tween, ทิ้ง callbacks/views ก่อน reset Legacy state.
`_exit_tree()` cancel เมื่อออก scene. Shared NPC/Enemy pose ไม่ถือ callback/queue ใหม่;
Restart ยัง kill `action_tween` ของแต่ละ action ตามเดิม.

### Verification และ acceptance mapping

```sh
# Pre-extraction on merged 08f2a973 (37 stages)
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-02-baseline-20261104-2 \
  --npc-proof --actor-proof --ownership-proof \
  --party-foundation-proof --party-turn-proof --party-playable-proof

# Final on committed source/tests 84c80d5 (40 stages)
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-02-final-20261104-1 \
  --npc-proof --actor-proof --ownership-proof \
  --party-foundation-proof --party-turn-proof --party-playable-proof --presentation-proof
```

เลือก output directory ใหม่เสมอ. `--presentation-proof` เป็น opt-in อิสระ เพิ่ม2parse+1runtime stage.
เวอร์ชัน/import/parse/main+proof startups ผ่าน; ทุก stage exit0, runner exit0.
Exactly5 expected errors เฉพาะ negative suite; unexpected engine errors0.

| Suite | Baseline checks / failures | Final checks / failures |
| --- | --- | --- |
| Combat | 14,395 / 0 | 14,395 / 0 |
| Negative | 983 / 0 +5 expected errors | 983 / 0 +5 expected errors |
| M2A-02 | 412 / 0 | 412 / 0 |
| M2A-03 | 5,166 / 0 | 5,166 / 0 |
| M2B-01 | 122 / 0 | 122 / 0 |
| M2B-02 | 219 / 0 | 219 / 0 |
| M2C-02 | 382 / 0 | 382 / 0 |
| M2C-03 | 1,250 / 0 | 1,250 / 0 |
| M2C-04 | 260,800 / 0 (31 cases) | 260,800 / 0 (31 cases) |
| New presentation boundary | Trace-only observer4,312 / 0 | 8,319 / 0 |

[presentation_boundary.gd](presentation_boundary.gd) instantiate scene จริง ไม่ mock Tween/balance.
ดูตำแหน่ง/HP **ภายใน impact callback** เพราะ frame observer อาจเห็น recoil เริ่มภายในเฟรมเดียวกันแล้ว.
Dev1 ทดสอบ pose ผิดจังหวะ2assertions; แก้เครื่องมือสังเกตโดยไม่เปลี่ยน expected pose/timing/HP.
Final เพิ่ม Restart แบบ reentrant ภายใน impact และหลัง lethal Player impact ก่อน result panel.

| Acceptance | Evidence / ขอบเขต |
| --- | --- |
| A01–A07 | Legacy suite unchanged + exact traces: AttackA/B, Defend, NPC2 Guard, NPC1/3 and A/B order, fallback, both kill orders |
| A08–A10 | Focused callback snapshots: HP ก่อน/หลัง strike เท่านั้น, duplicate/completion inert, homes restored |
| A11–A12 | Node pose/recoil/squash/popup/spark/HP flash/idle/speed0.70/lunge44 checks + trace equality; visual quality ยังรอ owner |
| A13–A15 | A/B × windup/impact/return Restart, old epoch replay during new attack, wrong IDs/duplicates/early completion, stale effects cleanup; reentrant/lethal impact Restart |
| A16–A18 | Legacy victory/defeat/result/locks + all inherited M2A/M2B/M2C suites count เดิมผ่าน |

**Before/after:** รัน observer เดียวกันบน merged snapshot ด้วย `--legacy-trace-only`,
แล้วเทียบ exact JSON กับ final: **6 cases /5,892 frames ตรงกันทั้งหมด**.
A-first victory2,498; B-first victory1,970; DEFEND600; defeat530; Restart windup133;
Restart after impact161. บันทึก HP/Guard/queue/round/target/locks/terminal/result visibility,
status/log, feedback counts และ15node transforms/tints. ไม่มี timing/HP override ยกเว้น defeat fixture1HP.
นี่ไม่ใช่ pixel/audio/animation-frame comparison และไม่พิสูจน์ visual quality จาก headless.

### Manual F6 — agent status และ owner checklist

Agent เปิด Godot4.7.2 editor ใช้ Run Current Scene toolbar (F6 action) บน snapshot ก่อน/หลัง.
Project viewport1280×720; embedded game areaแสดง1278×719ที่1.0×พร้อมขอบดำ.
ตรวจ startup/idle formation, shadows และ EnemyB tint/scale; baseline ATTACKA จบPlayer25/A8/B12,
after ATTACKA ค่าเดิม, after ATTACKB Player25/A15/B5, DEFEND Player28/A12/B12,
และกด Restart ทันทีหลัง ATTACK กลับPlayer30/A15/B12/round1โดยไม่มีผลค้างเมื่อดูภายหลัง.
Screenshots อยู่ tool transcript เท่านั้น; ไม่มี durable video/image. Runtime+asset GUI hashesตรง final;
GUI snapshot มี test harness เวอร์ชันก่อนเพิ่ม test-only cases ซึ่งไม่กระทบ runtime.

**Owner M2D-02 acceptance PENDING.** ยังไม่ตรวจ GUIครบkill orders/victory/defeat/every Restart phase,
ไม่ได้ video-measure44px/pacing หรือยืนยัน motion/readability ทุกช่วง. Battle Log มีพื้นที่แสดงจำกัด
ตามภาพก่อน/หลังเดิม; owner ควรประเมิน readability. ไม่มีการแก้ UI ใน refactor นี้.

- [ ] เปิด `res://scenes/combat/combat_prototype.tscn` → F6 ด้วย Godot4.7.2, viewport1280×720.
- [ ] ดู Player idle, Compact Formation, shadows/depth และ EnemyA/B identity/B tint+scale เทียบก่อน/หลัง.
- [ ] ATTACK A และ B หลัง Restart: ตรวจ pose/windup44px lunge/recoil/squash/return, spark/damage/HP flash และ active emphasis; HPตามตารางด้านบน.
- [ ] DEFEND: brace/Guard feedback; NPCทุกคนATTACK; Player28/A12/B12. ATTACK: NPC2GUARDลดเฉพาะ counterแรก; A/Bลงมือแยกตามลำดับ.
- [ ] Target picker ล็อกระหว่าง action, อ่าน target/intent/status/log ได้, actorกลับhomeก่อนส่งต่อคิว.
- [ ] เล่นทั้ง A-first/B-first จน victory; ดู resultหลังreturn. ตรวจ defeat ใน fixture/debugที่แยกจาก production balance.
- [ ] Restart ช่วง windup, หลังimpact, ระหว่างreturn, NPC2Guard, A/Bcounter และresultfade; รอ2วินาทีแล้วเริ่มรอบใหม่ ไม่มีmotion/popup/flash/HP/queueเก่า.
- [ ] บันทึก owner scenario/expected/actual, engine, commit, screenshot/video และความเห็นpacing0.70แยกจาก automated PASS.

### Source SHA และ durable evidence

Tested source/test commit **`84c80d5119c0cdb5f30b920202f63674aaf18009`**.
หลังจากนั้นเปลี่ยนเฉพาะ docs/evidence; Final HEAD ระบุใน Draft PR. Manifest59ไฟล์ตรง snapshot
และ worktree; ต้องตรวจเทียบอีกครั้งก่อนส่ง PR. ไม่แก้ source/tests หลัง final run.

- [Run record / commands / expected-actual / baseline source manifest](evidence/m2d-02/run-record.json)
- [Baseline37 stage results](evidence/m2d-02/baseline-results.json), [Final40 stage results](evidence/m2d-02/final-results.json)
- [Raw logs / engine logs / exit codes / GUI logs](evidence/m2d-02/logs.zip)
- [Before-after trace comparison](evidence/m2d-02/trace-comparison.json), [raw traces + baseline observer + M2C-04 scenarios](evidence/m2d-02/traces.zip)
- [Final source SHA-256](evidence/m2d-02/source-sha256.json)
- [Development failures and correction](evidence/m2d-02/development-record.json), [development raw logs](evidence/m2d-02/development-logs.zip)

### Learning notes — โค้ดจริงของ M2D-02

1. **Gameplay กับ presentation:** `_apply_hit_to_active_enemy()` ใน Controller คำนวณ
   `var new_hp: int = maxi(previous_hp - damage, 0)` แล้วเปลี่ยน Legacy HP.
   Adapter ใช้ `_motion.tween_property(actor.root, "position", actor.home + Vector2(settings.SHORT_LUNGE_DISTANCE, 0.0), settings.SHORT_LUNGE_TIME)`
   เพื่อเลื่อนภาพ. การเลื่อนภาพไม่ต้องรู้ว่าดาบทำdamageกี่หน่วย.
2. **Adapter คือผู้จัดลำดับภาพ:** `play_player_attack()` รับ views/ค่าการนำเสนอ/Callable;
   Controller เรียกด้วย `_presentation_settings(), _apply_player_hit, _finish_player_attack`.
   จึงดึงภาพหนึ่งเส้นทางออกได้โดยไม่สร้างcombat controllerใหม่.
3. **Tween callback และ Signal:** `_motion.tween_callback(_impact.bind(visual_epoch, actor_id, target_id))`
   รอให้ Tweenก่อนหน้าจบแล้วส่งIDsที่ล็อกไว้. `attack_button.pressed.connect(_on_attack_button_pressed)`
   ใน `_ready()` คือ Signalจากปุ่มเรียกฟังก์ชัน. งานนี้เลือกCallableสองตัวสำหรับขอบเขตภาพ ไม่เพิ่มevent bus.
4. **Impact boundary:** `_impact()` ตั้ง `phase = "IMPACT"` ก่อน `callback.call()`;
   callbackจริงคือ `_apply_player_hit()`. HPจึงเปลี่ยนหลังstrikeและก่อนrecoil ตามLegacyเดิม.
   `_complete()` เรียกอีกCallableหลังกลับhome ไม่เรียกdamageซ้ำ.
5. **ทำไม adapter ไม่เก็บ HP:** ถ้ามีHPอีกชุด ภาพอาจอ่านค่าหนึ่งแต่queue/terminalใช้อีกค่า.
   โค้ดนี้ส่งแต่Node/home/scale/tint; `player_hp`, `enemy_hp`, `enemy_b_hp` ยังอยู่ที่เดิม.
6. **ID แยกจาก Node:** `actor_id = locked_actor_id` / `target_id = locked_target_id`
   เก็บว่าใครกำลังทำอะไรกับใคร; `_actor.root` และ `_target.sprite` บอกว่าต้องขยับภาพไหน.
   `_current()` ตรวจทั้งID/epochและ `is_instance_valid(...)`; Node referenceอย่างเดียวไม่บอกtarget identity.
7. **Restart ต้องยกเลิก Tween:** `cancel()` ทำ `visual_epoch += 1` และ `_motion.kill()`
   แล้วล้างCallable. ถ้าresetเฉพาะHPแต่Tweenเก่ายังเดิน มันอาจขยับภาพ/เรียกhitหลังเริ่มใหม่.
   Controllerจึงเรียก `presentation_adapter.cancel()` ก่อน cleanup/Legacy reset.
8. **Refactor ยังต้อง regression:** ลำดับ `parallel()`/callbackที่เปลี่ยนเพียงนิดเดียวอาจทำให้hitเร็ว,
   Guardใช้ผิดครั้งหรือqueueส่งต่อซ้ำ. งานนี้ใช้scene/Tweensจริงและเทียบ5,892framesพร้อมsuiteเดิม
   เพื่อวัดพฤติกรรม ไม่อ้างว่าโค้ดย้ายไฟล์แล้วต้องเหมือนเดิมเสมอ.
9. **ช่วย M2D-03 อย่างไร:** contractภาพตอนนี้ไม่ต้องพึ่งHP/Encounter. งานในอนาคตอาจส่ง
   callbackจาก authorityอื่นหลังได้รับapproval โดยตรวจimpact/returnได้แยกกัน.
   ปัจจุบันยังส่งLegacy callbacksเท่านั้น; shared poseไม่ทำให้NPCเป็นautonomousหรือเริ่มcutover.

## M2D-03 — Opt-in Main Autonomous Combat

**สถานะปัจจุบัน:** merged ผ่าน PR #39 (`1728c5e`) และ **Owner-Reported F6 Acceptance** ตาม task M2D-04. ข้อความ review/pending ด้านล่างเป็นบันทึก ณ M2D-03; ผลตรวจ M2D-04 และ gate ใหม่ของ F5 อยู่หัวข้อถัดไป.

วันที่ **4 พฤศจิกายน 2026 Asia/Bangkok**. เจ้าของอนุมัติ D1–D13 สำหรับ Migration นี้โดยตรง
พร้อม Normal Opt-in NPC HP **10/10/10**, max10ต่อคน. งานบน
`codex/m2d-03-autonomous-main-optin` เพื่อ Draft review เท่านั้น.
สถานะ milestone อยู่ที่ [documentation index](../../docs/README.md#current-status-and-next-roadmap).
PR #38 merge จริงที่ `c0dcc33f0ab89c8187b9cb0c025138b447a8c7e2`;
M2D-02 **Implemented / Owner-Reported Acceptance** ตาม owner task ไม่เท่ากับ independent visual acceptance.

### Approved decisions และ behavior

| Decision | สิ่งที่ทำใน Opt-in / ผลต่อ gameplay |
| --- | --- |
| D1 Authority/Adapter | Main Controller เรียก Encounter public API; Adapter จัดภาพและส่ง callback |
| D2 TurnFlow | สร้างเฉพาะ Legacy; Opt-in ไม่มี Legacy queue instance |
| D3 Targets | Legacy ใช้ CombatTargets; Opt-in อ่าน available IDs จาก Encounter |
| D4 NPC2 | ใช้ Resolver เช่น NPCอื่น ไม่มี scripted Guard Player |
| D5 Enemy target | Normal A/Bเล็งPlayer; NPC threat ใช้ presetประกาศชัดก่อนรอบ |
| D6 Guard | Playerลด2ทุกvalid hitในรอบ; NPCลด2เฉพาะnext valid self hit, ขั้นต่ำ1 |
| D7 HP | ActorRuntimeState ผ่าน Registry เป็นเจ้าของ; Legacy HPเป็นnullในOpt-in |
| D8 Callback | Encounter identity/generation/full token/decision/state + visual epoch/phase/IDs/Tween/node lifetime |
| D9 Presentation | Main scene/assets/idle/shadow/depth/B identity, speed0.70, 44px และ Main timing constants |
| D10 Entry | thin inherited `combat_autonomous_optin.tscn`, modeก่อน_ready; default Legacy |
| D11 Rollback | หยุดOpt-inแล้วเปิดLegacyเริ่มbattleใหม่; ไม่แปลงHP/queueกลางรอบ |
| D12 Acceptance | Automated regression + Owner F6; headlessไม่ปิดvisual gate |
| D13 Prototype | Player30, A15/B12, damage5/1/3, HELP4ต่อNPCหนึ่งครั้ง; NPC10/10/10 max10 |

NPCเลือกศัตรูตัวแรกที่ยังพร้อมตาม Enemy Order เมื่อถึง slot จริง. Player Target Picker เป็นคำสั่งของ
Playerเท่านั้น. HELPตรวจ≤30%ที่decision ไม่ตรวจthresholdซ้ำที่impact; ไม่ฟื้นPlayer HP0และไม่เกินmax.
Self-DEFENDอ่านfirst still-valid declared hitตามResolverเดิม. Preset M2C HP10/7/3อยู่แยก;
ทุกตัวเลขเป็น prototype ไม่ใช่ final Main balance. ไม่แก้Encounter/Resolver/Registry/RuntimeState policy.

### Git baseline และ file scope

Initial treeสะอาด, fetchแล้ว local/remote/merge-baseตรง `c0dcc33`; PR #38merged;
open PR #2/#17ยังDraft/unmergedและไม่เป็นcanonical. ไม่พบM2D-03 branch/PRซ้ำ.
อ่านMain/proof/Encounter/Resolver/data/testsและเอกสารv0.1/v0.3/v0.4ก่อนImplementation.
M2D-01อ้างอิงจากowner-approved proposalและmerged M2D-02 contract; ไม่มีoriginal design reportไฟล์แยกในrepository/attachmentนี้.

Runtime/test6ไฟล์: Main Controller, presentation adapter, thin inherited entry, newintegrationtest+UID,
runnerflag. เอกสารเดิม3ไฟล์และevidenceอยู่PRเดียวกัน. ไม่แก้`project.godot`, Main scene tree/assets,
LegacyTurnFlow/Targets, existing tests/expected results, Encounterpolicy, loreหรือitems.

### Session isolation และ action mapping

[Controller](../../scripts/combat/combat_prototype.gd) เลือกmodeก่อน_ready:
Legacyสร้างTurnFlow+TargetsและLegacyHP; Autonomousสร้างEncounterเท่านั้น. setterปฏิเสธการเปลี่ยนmode
หลังready. Controllerเดียวไม่มีสำเนาทั้งไฟล์หรือControllerตัวที่สาม. LegacyHPเป็นnullและLegacyqueue/
registryเป็นnullตลอดOpt-in; testsตรวจทุกframe. Snapshotเป็นdetached value ไม่ใช่mutable HP mirror.

`begin_round → begin_next_action → locked decision → windup → resolve_action(token) → actual feedback
→ return home → complete_action(token) → next slot/round/result`.
PlayerATTACK/DEFEND, NPCATTACK/DEFEND/HELP/SKIP และEnemyA/Bใช้lifecycleเดียวกัน;
NPCแต่ละคนยังแสดงWaiting to decideก่อนslotของตน. Terminalอ่านsnapshot.resultและแสดงresultpanelเดิม
หลังreturnโดยไม่เรียกLegacy_finish_round/_end_battle.

[Adapter](../../scripts/combat/combat_presentation_adapter.gd) ไม่มีHP/Encounter/Resolver/queue.
`play_action()`รับstableIDs, action, node/home/scale/tint, MainpresentationvaluesและCallables.
สร้างTweenทั้งหมดก่อนเริ่ม; `_action_impact()`รับvisual facts `hit/guarded`จากactualeffect.
`tween_method(_action_reaction...)`จึงไม่สร้างrecoil/flash/spark/damagepopupเมื่อeffectSKIP.
HELPใช้greenactor/popup/HPflashและactualdelta; DEFENDใช้brace/blueguardfeedback.
LegacyPlayerATTACKpathและsharedposeเดิมคงอยู่พร้อมexacttraceverification.

Restartเรียกadapter.cancelก่อนreset: เพิ่มepoch, killTween, ทิ้งcallbacks, killresult/HPflash,
ล้างboundpopup/spark, restartEncounterเพิ่มgenerationด้วยfreshfixture, ล้างtoken,
คืนทุกactorhome/pose/tint/scale แล้วrefreshHUD/controlsจากsnapshot. Guard/HELP/availabilityไม่คำนวณซ้ำในUI.
Completionตรวจทั้งstate/identity/phaseและhome; impactตรวจเวลาที่visualboundaryมาถึง.
Callbacksเก่าใช้actionIDซ้ำก็ไม่ผ่านgeneration/epoch. Wrongdecision/token, early/duplicate/reentrantcallbacks
มีfocusedtests. Fixture raceเขียนRegistryเฉพาะในtestsเพื่อจำลองconcurrentinvalidationที่playablecontrolsไม่มี.

### Verification และ differential

Actual engine **`4.7.2.stable.official.ed1daf0bf`**.
Tested source/test commit **`6f4c4db57953a423b83809719370f774b57ede10`**.
FinalHEADอยู่DraftPR; หลังtestedcommitเปลี่ยนเฉพาะdocs/evidence. Manifest64ไฟล์ต้องตรงfinaltree.

```sh
# ก่อนแก้ runtime บน merged c0dcc33 — 40 stages PASS
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-03-baseline-20261104-2 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof

# Final committed source/tests — 44 stages PASS
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-03-final-20261104-2 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof
```

ทุกครั้งใช้freshoutputdirectory. Finalrunnerexit0; ทั้ง44stagesexit0, timeout0,
unexpectedengineerrors0. Negative5expectederrorsแยกชัด. Flagใหม่เป็นopt-inอิสระ:
เพิ่มadapter/testparse2stages, inheritedentrystartup1stageและruntimeproof1stage.
Cleanimportตรวจscript/sceneทั้งหมด; startupทั้งMainและOpt-inผ่าน.

| Suite | Baseline checks | Final checks / failures |
| --- | --- | --- |
| Combat | 14,395 | 14,395 / 0 |
| Negative | 983 +5expectederrors | 983 / 0 +5expectederrors |
| M2A-02 / M2A-03 | 412 / 5,166 | 412 / 5,166; failures0 |
| M2B-01 / M2B-02 | 122 / 219 | 122 / 219; failures0 |
| M2C-02 / M2C-03 | 382 / 1,250 | 382 / 1,250; failures0 |
| M2C-04 | 260,800 /31cases | 260,800 /31cases; failures0 |
| M2D-02 | 8,319 | 8,319 /0 |
| M2D-03 | — | **787,617 /0; 46cases** |

Legacybaseline→final exacttraceเท่ากัน **6cases/5,892frames** รวมkillorders, DEFEND, defeat,
Restartwindup/afterimpact. Invariants: speed/lunge/formation/home, Playercontrols/locks, Restart,
exactly-onceeffect/completion, terminaldrainsqueue. Intentionaldifferences: NPC2ไม่GuardPlayer,
NPCมีHP/HELP/self-DEFEND/availabilityและเลือกtargetเอง; PlayerHPหลังATTACKจึงต่างกัน.

| Normal command | Legacy expected = actual (Player/A/B) | Autonomous expected = actual |
| --- | --- | --- |
| ATTACK A | 25 /8 /12 | 24 /7 /12 |
| ATTACK B | 25 /15 /5 | 24 /12 /7 |
| DEFEND | 28 /12 /12 | 28 /12 /12 |

### S01–S22 coverage และ evidence

[New test](autonomous_main_integration.gd) ใช้inheritedscene/realTweens; ทุกcaseมีexpected/actual/finalHP/
actiontrace. SnapshotHUDchecksรวมvisibility/viewportbounds; headlessไม่พิสูจน์visualquality.

| Scenario | Focused case / expected behavior |
| --- | --- |
| S01 | inheritedentrymodeก่อนinit, sixactors, NPC10/10/10 |
| S02 | projectMainยังLegacy, noEncounter, modeimmutable |
| S03 / S04 / S05 | ATTACK A/B/DEFEND actualHPตามdifferentialtable |
| S06 | NPC2/3Waiting; หลังNPC1HELP6→10, NPC2/3เลือกATTACKที่slot |
| S07 | HELP4/actualgreenfeedback; thresholddecision-only; clamp/noHP0revival |
| S08 | NPC1selfguard3HP, firsthit3→1, secondhitclamped2→0; Playerไม่ได้รับhit |
| S09 | Player1:สามHELPแยกresources, guardedroundจบPlayer11 |
| S10 / S11 | AหรือBตาย, deadslotSKIP, livingenemycounterแยกPlayer27 |
| S12 | HP0NPC/enemySKIP, nofakehit |
| S13 | actor/targetตายหลังlock:SKIP, noretarget/recoil/spark/popup |
| S14 / S15 | victory/defeatกลางรอบ, resultหลังreturn, queueหยุด, commandslocked |
| S16 / S17 | 6actors×WINDUP/IMPACT/RETURN=18cases; reentrant/terminal/resultfadeRestart |
| S18 | stale/forged/wrongdecision/duplicate/earlycallback; validvisualphaseforgeryprobe |
| S19 | HUDHP/HELP/guardตรงsnapshot, visible/bounds, actualdelta |
| S20 | noLegacyqueue/targets/HPmirrorทุกobservedframe, detachedsnapshotmutationinert |
| S21 | unchangedLegacysuite + differentials +5,892exacttraceframes |
| S22 | Mainidle/shadow/depth/scale/tint/resultstructure; agentF6partial, OwnerF6pending |

- [Run record / commands / commit / expected-actual / manual status](evidence/m2d-03/run-record.json)
- [Baseline40stages](evidence/m2d-03/baseline-results.json), [Final44stages](evidence/m2d-03/final-results.json)
- [Scenario expected/actual + action traces](evidence/m2d-03/scenarios.json)
- [Raw stdout/engine logs/exit codes](evidence/m2d-03/logs.zip), [full traces](evidence/m2d-03/traces.zip)
- [Exact Legacy comparison](evidence/m2d-03/trace-comparison.json), [source SHA-256](evidence/m2d-03/source-sha256.json)
- [Development failures/corrections](evidence/m2d-03/development-record.json), [raw development logs](evidence/m2d-03/development-logs.zip)

### Manual F6 — owner checklist / limitations

**Owner Visual Acceptance PENDING.** Agentใช้GodoteditorRunCurrentScene(F6action),
project1280×720; embeddedgamearea1278×719at1.0×พร้อมขอบดำ. บันทึกส่วนที่ตรวจจริงอยู่runrecord;
screenshotsในtooltranscript ไม่มีdurablevideo. ไม่ใช้screenshotsอย่างเดียวอ้างruntimePASS.

- [ ] เปิด `res://scenes/combat/combat_prototype.tscn` → F6: Legacyเดิม, idle/shadow/depth/Bidentity;
  ATTACK A25/8/12, ATTACK B25/15/5, DEFEND28/12/12; NPC2GuardหลังATTACK.
- [ ] เปิด `res://scenes/combat/combat_autonomous_optin.tscn` → F6: NormalNPC10/10/10, HP/HELPครบ,
  Waiting to decide, compactformation, speed0.70/44pxlunge/returnhomeและreadability.
- [ ] Restartระหว่างroundเพื่อแยกATTACK A/B/DEFEND; ตรวจHPตามตารางและNPCเลือกAเองเมื่อPlayerเลือกB.
- [ ] เลือกPlayerneedsHELPแล้วDEFEND: NPC1HELP6→10, greenfeedback/HELP0; NPC2/3ATTACK;
  จบรอบPlayer8/A13/B12. อ่านreasoncode+explanationและactualdeltaได้ทัน.
- [ ] NPCself-DEFENDแล้วDEFEND: NPC1brace/selfguard, firstenemyhit1แล้วsecondactual2; NPC1HP0,
  Player30, A13/B12. ไม่มีscriptedNPC2GuardPlayer.
- [ ] MultipleHELPแล้วDEFEND: HELP4แต่ละNPCแยกกัน, resources0ทุกคน, Player11.
- [ ] A/BfallsและUnavailablepresets: deadslotsSKIPโดยไม่มีfakehit, liveenemyยังcounter;
  ทั้งkillordersเล่นจนจบ, targetpickerfallbackเฉพาะก่อนlock.
- [ ] VictorypresetATTACK: lethalPlayerhitแล้วreturnก่อนresult. DefeatpresetATTACK:
  HP0NPCskip, EnemyAทำให้Playerแพ้, Bไม่ลงมือหลังterminal.
- [ ] Restartระหว่างPlayer/NPC1/2/3/A/Bก่อนimpact/หลังimpact/return/resultfade;
  รอ2วินาทีแล้วเล่นใหม่ ไม่มีHP/resourceซ้ำหรือoldmotion/popup/spark/flash/tint/scale.
- [ ] จดengine/commit/scenario/expected/actualพร้อมscreenshot/videoและความเห็นpacing/readability.

Reasonsเป็นEnglishprototypeบนUIเดิมภาษาไทย; ยังไม่เพิ่มlocalizationsystem. CombatLogพื้นที่สั้นตามMainlayout,
บางบรรทัดก่อนหน้าถูกตัดในscrollarea แต่latestdecision/effectและ3NPCreasonsแสดงแยกด้านบน.
Result panel อยู่เหนือ reason rows แล้ว; พื้นหลังโปร่งแสงเดิมยังเห็นข้อความด้านหลังจาง ๆ จึงให้ owner ประเมิน readability เพิ่ม.
ไม่มีvideo-measuredpacingหรือcompleteownerF6ทุกscenario. AutomatedS22เป็นstructure/motionevidence,
ไม่ใช่visualqualityapproval. HP0เป็นfixtureavailability ไม่ตัดสินDown/Death/permadeath.

Rollback: StopOpt-in → เปิดLegacyentry → F6/newbattle. ไม่copyHP/queueระหว่างmode.
M2D-04cutoverยังไม่เริ่ม; M2B-03deferred. ไม่merge/auto-merge/deletebranchหรือเริ่มfollow-onเอง.

### Learning notes — ตัวอย่างจากโค้ดจริง

1. **Session Mode** คือการเลือกกติกาหนึ่งชุดก่อนเริ่มbattle:
   `if session_mode == SessionMode.AUTONOMOUS: encounter = FullPartyEncounter.new()`.
   ฉากinheritedกำหนด`session_mode = 1`ก่อน_ready จึงไม่ต้องcopyNodeTree.
2. **หนึ่งBattleหนึ่งAuthority:** อีกทางของifสร้าง`CombatTurnFlow.new()`/`CombatTargets.new()`.
   ถ้าสองชุดเดินพร้อมกัน อาจหักHPหรือจบรอบสองครั้ง; testsจึงตรวจnullของLegacyในOpt-inทุกframe.
3. **ActorRuntimeStateเป็นเจ้าของHP:** Encounter→Registry→`take_damage()`/`heal()`เปลี่ยนHPจริง;
   Mainอ่าน`encounter.snapshot().actors[id].current_hp`. `player_hp`ของLegacyเป็นnullในOpt-in.
4. **Queueต่างกันอย่างไร:** Legacy`plan_round()`วางNPCrulesล่วงหน้า;
   Encounter`begin_next_action()`ค่อยเรียกResolverเมื่อถึงactorIDนั้น. Presentationไม่ต้องนับ`npc_action_index`.
5. **Adapterเชื่อมอย่างไร:** `play_action(..., _autonomous_impact.bind(locked), _autonomous_complete.bind(locked))`
   ส่งCallableแทนการย้ายdamageไปไว้ในTween. Callbackแรกลงผล; callbackหลังreturnเดินคิว.
6. **Token/Generation/Epoch:** tokenระบุEncounter/round/action/actor/decision; generationแยกbattleก่อน/หลังRestart;
   `visual_epoch += 1`ในcancelแยกlifetimeของภาพ. ActionIDเริ่ม1ใหม่ได้แต่callbackเก่าไม่ผ่านgeneration.
7. **Decision Timing:** `_autonomous_advance()`เรียกbegin_next_actionเพียงslotเดียว.
   NPC1HELP6→10ก่อนNPC2ตัดสิน ทำให้NPC2เลือกATTACK; ถ้าคำนวณก่อนทั้งสามจะเห็นHP6เหมือนกันผิดจังหวะ.
8. **ทำไมUIอ่านSnapshot:** `_refresh_autonomous_ui()`ใช้`view.guards`/`view.help_uses`และHPที่Encounterคืน.
   UIแสดงผลไม่คำนวณdamageหรือHELPpolicyซ้ำ; snapshotที่แก้ภายนอกไม่เปลี่ยนstateจริง.
9. **กันDuplicateEffect:** adapterเปลี่ยน`phase = "IMPACT"`และล้าง_on_impactก่อนcall;
   Controllerตรวจlockeddecision/state แล้วEncounterยอมresolveเฉพาะLOCKED.
   หลังRESOLVEDcallbackซ้ำจึงไม่ใช้HELPหรือหักHPซ้ำ. Recoveryสร้างก่อนTweenเล่นและอ่านvisualfactsหลังimpact.
10. **RollbackกับOpt-in:** Opt-inเปิดทางทดลองโดยdefaultไม่เปลี่ยน;
    rollbackคือหยุดsessionแล้วเปิดentryLegacyใหม่. ไม่ใช่เปลี่ยนenumหรือแปลงsnapshotระหว่างanimation.


## M2D-04 — Autonomous Main Cutover Candidate

วันที่ **4 พฤศจิกายน 2026 Asia/Bangkok**. Candidate บน `codex/m2d-04-autonomous-main-cutover`
จาก merged PR #39 `1728c5e678c5065278d1251d50449a8820eb5dae`. Initial tree สะอาด; fetch แล้ว
local/remote HEAD/merge-base ตรงกัน; open PR #2/#17 ยัง unmerged และไม่พบ M2D-04 ซ้ำ.
**M2D-03 Implemented + Owner-Reported F6 Acceptance** มาจาก owner task นี้; ไม่มี owner scenario record ใหม่ให้ตรวจอิสระ.
สถานะ/งานถัดไปมีแหล่งเดียวใน [docs index](../../docs/README.md#current-status-and-next-roadmap).

### Candidate entry และขอบเขต

`project.godot` เปลี่ยน `application/run/main_scene` จาก `uid://bn6oc55gryn7`
(ฉาก Legacy ที่ตรวจจาก clean import) เป็น `res://scenes/combat/combat_autonomous_optin.tscn`.
ใช้ path ที่ Godot โหลดได้จริงหลัง clean import; ไม่สร้าง UID ใหม่ให้ scene หรือ copy Node Tree.
Canonical `visual-combat-test-1` ที่ `1728c5e` ยัง default Legacy จนกว่า owner จะสั่ง merge candidate.

F5 Candidate สร้าง FullPartyEncounter เท่านั้น: HP ผ่าน Registry/ActorRuntimeState,
queue/decisions/HELP/Guard/effect/completion ผ่าน Encounter API และ HUD อ่าน snapshot.
F6 `combat_prototype.tscn` ยังสร้างเฉพาะ Legacy TurnFlow/Targets/HP และ NPC2 Guard Player เดิม.
`session_mode` ของ controller เริ่ม LEGACY เหมือนเดิม; inherited scene กำหนด AUTONOMOUS ก่อน `_ready()`.
ไม่มี runtime controller/adapter/Encounter/Resolver/data/scene tree/assets เปลี่ยนใน M2D-04.
Normal Player30, NPC10/10/10, A15/B12; damage5/1/3, HELP4ครั้งเดียวต่อNPC, threshold≤30%ตอนdecision,
PlayerDEFENDลด2ทุกvalid hitในรอบและNPCselfDEFENDลด2next valid self hitขั้นต่ำ1คงเดิมตาม D1–D13.
M2C10/7/3 อยู่ fixture แยก; ตัวเลขทั้งหมดเป็น prototype ไม่ใช่ final balance/Turn System.

ไฟล์ implementation/test 7 ไฟล์: `project.godot`, runner `verify.py`, test เดิม
`autonomous_main_integration.gd`, [cutover harness](main_cutover_proof.gd)+UID,
[startup observer](main_cutover_startup_probe.gd)+UID. เอกสารเดิม3ไฟล์และ evidence อยู่ task เดียวกัน.
เปลี่ยน assertion เดิมเรื่อง project default ให้รับ `--expect-autonomous-default` อย่างชัดเจน;
เมื่อไม่ส่ง flag ยัง expect Legacy. ทุก gameplay assertion/expected value และจำนวน checks เดิมคงอยู่.

### วิธีรันซ้ำและผลจริง

Actual engine **`4.7.2.stable.official.ed1daf0bf`**.
Baseline ทดสอบบน merged `1728c5e`; candidate source/test commit
**`e802e62aa1debcf66b0d4359a2361e1960428f9f`**. Final HEAD ดูจาก Draft PR และ `git rev-parse HEAD`;
หลัง tested commit เปลี่ยนเฉพาะ docs/evidence. ตรวจ SHA-256 ทั้ง **81 source/test/asset files ตรงกัน**.

```sh
# ก่อนแก้ไฟล์ บน merged base หลัง PR #39 — 44 stages PASS
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-04-baseline-20261104-2 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof

# Committed candidate — 52 stages PASS; ต้องใช้ baseline output ที่ผ่านจริง
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2d-04-final-20261104-1 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof \
  --main-cutover-proof --cutover-baseline /tmp/wanderer-m2d-04-baseline-20261104-2
```

ใช้ output directory ใหม่ทุกครั้งและเก็บ baseline ไว้สำหรับ comparison.
Attempt แรกใน sandbox FAIL ที่ clean import: Godot เขียน editor settings ไม่ได้ (exit0แต่พบunexpectederrors).
ไม่มีการแก้ production default ตอนนั้น; รัน merged base ใหม่โดยให้ Godot เข้าถึง settings ที่ต้องใช้แล้วผ่าน44stages.
เก็บ failure log ไว้ ไม่กลบเป็น PASS. Development candidate และ final run ผ่าน52stagesทั้งคู่.
Final52stages exit0ทั้งหมด, timeout0, unexpectederrors0; negativeมี5expectederrorsแยกต่างหาก.

| Suite | Pre-cutover actual | Candidate actual |
| --- | ---: | ---: |
| Combat Regression | 14,395 | 14,395 |
| Negative | 983 + 5 expected errors | 983 + 5 expected errors |
| M2A-02 / M2A-03 | 412 / 5,166 | 412 / 5,166 |
| M2B-01 / M2B-02 | 122 / 219 | 122 / 219 |
| M2C-02 / M2C-03 | 382 / 1,250 | 382 / 1,250 |
| M2C-04 | 260,800 / 31 cases | 260,800 / 31 cases |
| M2D-02 | 8,319 | 8,319 |
| M2D-03 | 787,617 / 46 cases | 787,617 / 46 cases |
| M2D-04 configured entry | — | **801,351 / 48 cases** |
| Native configured startup / rollback startup | — | 9 / 5 |
| Rollback full Legacy regression | — | 14,395 |

### C01–C22 acceptance mapping — Headless แยกจาก GUI

[ผล C01–C22 expected/actual และ counts](evidence/m2d-04/cutover-release-gates.json)
ใช้ PASS สำหรับการตรวจ headless เท่านั้น; manual owner F5/F6 ยัง PENDING.
Cutover harness สืบทอด test helpers/matrix M2D-03 แล้ว instantiate **ค่าจริงจาก ProjectSettings**;
ไม่ preload Autonomous เพื่ออ้างว่า project default ถูกต้องเพียงเพราะฉากมีอยู่.

| Case | Expected / automated actual |
| --- | --- |
| C01 | Config ชี้ Autonomous path และ clean-import resource โหลดได้ — PASS |
| C02 | Modeก่อนready/Encounterเป็นauthorityเดียว; native project startup observerยืนยันentryจริง — PASS |
| C03 | Normal NPC current/max HP10ทุกคน — PASS |
| C04 | LegacyHP/TurnFlow/Targetsเป็นnullทุกobservedframe; snapshotmutationไม่เปลี่ยนstate — PASS |
| C05 | Player ATTACK A/B ใช้targetpickerและHPตามdifferential — PASS |
| C06 | Player DEFENDลด2ทั้งสองvalidhits — PASS |
| C07 | NPC1/2/3ตัดสินแยกslot/reasonตรงstateล่าสุด — PASS |
| C08 | HELP4/threshold/clamp/resourceคนละครั้ง/ไม่revive/ownership — PASS |
| C09 | Self-DEFEND next valid self hitลด2ขั้นต่ำ1 — PASS |
| C10 | Enemy A/B separate slots/normalเล็งPlayer — PASS |
| C11 | Pickerfallbackก่อนlock/deadactorSKIP/lockedtargetไม่retarget — PASS |
| C12 | Victory/Defeatหลังreturn/terminalไม่ลงactionเพิ่ม/Restartได้ — PASS |
| C13/C14/C15 | Restart WINDUP/afterIMPACT/RETURN ×6actors — PASS |
| C16 | stale/forged/early/duplicate/reentrant callbacks และ reusedactionID1 — PASS |
| C17 | Direct Legacy sceneเริ่มLEGACY/noEncounter — PASS; GUI F6 owner pending |
| C18 | LegacyHP/Guard/queue, regression14,395และexacttraces — PASS |
| C19 | 1280×720/speed0.70/44px/home/compactformation/idle/shadow/depth/B/resultstructure — PASS; visual quality pending |
| C20 | Fresh rollback config/import/native startup/fullLegacyregression — PASS |
| C21 | ทุกstagePASS/no unexpectederrors/timeouts; negative5expected — PASS |
| C22 | 11 inheritedsuitecountsไม่ลดและ6cases/5,892framesตรงbaseline — PASS |

Native F5-equivalent gate แยกจาก F6 opt-in startup: runnerเพิ่ม **read-only observer autoload เฉพาะ snapshot**,
เรียกGodotโดยไม่มี`--script`และไม่มีsceneoverride, อ่าน`get_tree().current_scene`หลังready แล้วบันทึกpath/mode/HP/authority.
เก็บconfigที่ใช้ทดสอบและคืนsnapshotconfigใน`finally`; productionไม่มีautoloadนี้.
Configured startupปกติ120framesยังรันโดยไม่injectobserverด้วย. Native gateนี้ไม่ใช่การกดF5โดยowner.

### Differential และ rollback ที่รันจริง

[Exact comparison](evidence/m2d-04/trace-comparison.json): baseline→candidate Legacy **6cases/5,892framesตรงทุกframe**,
รวมA-first/B-first/DEFEND/defeat/Restartwindup/afterimpact. Rawทั้งสองชุดอยู่traces.zip.

| Command | Legacy expected = actual Player/A/B | Autonomous expected = actual |
| --- | --- | --- |
| ATTACK A | 25 / 8 / 12 | 24 / 7 / 12 |
| ATTACK B | 25 / 15 / 5 | 24 / 12 / 7 |
| DEFEND | 28 / 12 / 12 | 28 / 12 / 12 |

ความต่างATTACKเป็นเจตนา D1–D13: LegacyNPC2GuardPlayer แต่AutonomousNPC2ตัดสินเอง.
ไม่ได้แก้expectedLegacyให้ตรงAutonomous.

[Rollback record: configก่อน/หลังและstages](evidence/m2d-04/rollback.json):
runnerจบcandidateprocessก่อนสร้าง`rollback-snapshot/`แยกโดยไม่มี`.godot`; คืนmain_sceneเป็น
`res://scenes/combat/combat_prototype.tscn`, cleanimportใหม่, native startupตรวจLEGACY/noEncounter/HP30/15/12,
แล้วรันLegacyregression14,395checksผ่าน. Candidateconfigไม่เปลี่ยนและไม่ลบLegacyระบบใด.

วิธีrollbackที่ownerทำได้จริงในworkingcopyแยก: **Stop (F8)** → เปลี่ยนProject Settings > Application > Run > Main Scene
เป็นLegacypathข้างบน → ปิด/เปิดprojectใหม่ → F5เริ่มbattleใหม่ → รันsmoke/regressionตามคำสั่งพื้นฐานต้นเอกสาร.
เปิดLegacysceneแล้วF6เป็นทางทดลองfallbackทันทีโดยไม่แก้projectconfig.
ไม่ย้ายHP/Guard/HELP/queueระหว่างsession; candidatecommitเก็บไว้ตรวจdiff/กลับมาทดลองได้.

### Owner Visual Acceptance — แยกสาม gate

**ทั้งหมด PENDING สำหรับ M2D-04** จนownerตรวจจริงและรายงานengine/commit/scenario/expected/actual/evidence.
Owner-reported M2D-03 F6 ไม่ปิด F5 gateใหม่และไม่เท่ากับacceptancecandidateนี้.

**A. F5 — Run Project (gate ใหม่)**

- [ ] ตรวจbranch/HEADเป็นcandidate; Godot4.7.2; projectviewport1280×720; Stopก่อนเริ่ม.
- [ ] กดF5โดยไม่เปิดฉากบังคับ: เข้าAutonomousทันที, Player30/NPC10×3/A15/B12, HELP1คนละresource,
  Waiting to decide, formation/idle/contactshadow/depth/EnemyBtintscaleเดิม.
- [ ] RestartแยกATTACK A24/7/12, ATTACK B24/12/7, DEFEND28/12/12;
  targetpickerA/Bใช้ได้, NPCเลือกAเอง, enemyทั้งคู่ลงมือ, commandlocksจนreturnและกลับhome.
- [ ] ทดสอบHELP/selfDEFEND/deadslot/victory/defeatและRestartระหว่างactionจากpresetsตามBข้างล่าง;
  ไม่มีcallbackเก่า, panelไม่บังRestart/เล่นต่อ, Reason/HP/HELPอ่านทัน.
- [ ] ประเมินlunge44px, pose/impact/recoil/guardedrecoil/popupสีdamage-heal/spark/HPflash,
  log/actionstatus/resultpanel และpacing0.70; บันทึกvideoถ้าจะอ้างtimingเชิงสายตา.

**B. F6 — Autonomous current scene**

- [ ] Stopแล้วเปิด`combat_autonomous_optin.tscn`→F6; ตรวจNormalเหมือนF5โดยไม่อาศัยdefaultentry.
- [ ] ATTACK A/B/DEFENDแยกbattle, killordersทั้งสอง; deadenemiesไม่counterและlivingenemyไม่หายคิว.
- [ ] PlayerneedsHELP+DEFEND: NPC1HELP6→10/HELP0, NPC2/3ATTACK; finalPlayer8/A13/B12.
- [ ] NPCselfDEFEND+DEFEND: firstselfhit1, secondactual2, NPC1HP0/Player30/A13/B12;
  ไม่มีNPC2GuardPlayer. MultipleHELP+DEFEND: resource0แต่ละNPC/Player11.
- [ ] A/Bfalls, Unavailableslots: SKIPไม่มีfakehit/falsepopup/retargetหลังlock.
- [ ] Victory/Defeatpresets: resultหลังreturn, ไม่มีactionเพิ่ม; panelอ่านได้และRestartใช้ได้.
- [ ] Restartระหว่างPlayer/NPCทั้งสาม/A/Bช่วงwindup/impact/return/resultfade,
  รออย่างน้อย2วินาทีแล้วเล่นใหม่; ไม่มีoldHP/resource/motion/feedbackกลับมา.
- [ ] ประเมินformation/readability/reason/target/lunge/pose/impact/return/pacingและfeedbackทั้งหมดเช่นA.

**C. F6 — Legacy current scene**

- [ ] Stopแล้วเปิด`combat_prototype.tscn`→F6: ไม่มีAutonomouspreset/HELP UI, ใช้Legacyเดิม.
- [ ] ATTACK A25/8/12, ATTACK B25/15/5; NPC2ยังGuardPlayer, DEFEND28/12/12.
- [ ] เล่นkillordersทั้งสอง, targetfallback/deadskips/livingcounter/victory/defeat/commandlocks.
- [ ] Restartระหว่างactionแล้วเล่นใหม่; formation/44px/pose/impact/return/feedback/pacing/resultpanelเหมือนเดิม.

Agent GUI smoke บนdisposablecandidate snapshotเป็น **partial**: Run Project toolbar (F5 action),
project1280×720, embeddedgame1278×719at1.0×มีขอบดำ. เห็นNormalstartup, ATTACK B24/12/7,
DEFEND28/12/12, HELP8/13/12พร้อมNPC1HELP0 และVictorypanel/Restartใช้ได้จริง. รายละเอียดอยู่run-record;
screenshotsอยู่tooltranscript ไม่มีdurablevideo/ภาพวัดpacing. ไม่ถือเป็นOwnerAcceptanceหรือcompleteF6review.
KnownUXจากM2D-03ยังอยู่: logพื้นที่สั้น, Reasonsภาษาอังกฤษ, resultpanelโปร่งแสง และtitle/presetยังเขียนOPT-IN.
ไม่พบreleaseblockerในการตรวจอัตโนมัติ/GUIส่วนที่ทำ แต่ส่วนที่ยังไม่ได้ตรวจต้องให้ownerตัดสิน;
ไม่ขยายเป็นUIredesignหรือเปลี่ยนgameplayเพื่อแก้ภาพ.

### Durable evidence และ commit identity

- [Run record: engine/commit/commands/results/manual status](evidence/m2d-04/run-record.json)
- [Baseline44stages](evidence/m2d-04/baseline-results.json), [Final52stages](evidence/m2d-04/final-results.json)
- [C01–C22 expected/actual/count gate](evidence/m2d-04/cutover-release-gates.json)
- [Native configured F5-equivalent entry](evidence/m2d-04/main-cutover-f5-startup.json), [Rollback](evidence/m2d-04/rollback.json)
- [Source SHA-256](evidence/m2d-04/source-sha256.json), [tested-source/current-tree comparison](evidence/m2d-04/source-comparison.json)
- [Exact Legacy trace comparison](evidence/m2d-04/trace-comparison.json), [raw before/after traces](evidence/m2d-04/traces.zip)
- [Full cutover/inherited scenario snapshots/action traces/differentials](evidence/m2d-04/scenarios.zip)
- [Raw logs/engine logs/exit codes/configs including sandbox failure and development run](evidence/m2d-04/logs.zip)

FinalHEADหลังtestedcommitต้องต่างเฉพาะdocs/evidence. หากแก้runtime/scene/test/config/assetต่อ ต้องรันใหม่.
No merge/auto-merge/branchcleanup/releasetag/deployment; หยุดหลังเปิดDraftPRรอcode reviewและownerF5/F6.
M2B-03deferred; ไม่เริ่มงานถัดไป.

### GDScript / Godot learning notes — ภาษาไทย

1. **F5 กับ F6:** F5ใช้Main Sceneของproject ไม่ขึ้นกับแท็บsceneที่กำลังดู;
   F6ใช้current scene. F6opt-inผ่านจึงยังไม่พิสูจน์ว่าF5เข้าAutonomous.
2. **Main Sceneอยู่ที่ไหน:** `[application] run/main_scene` ใน`project.godot`กำหนดentry.
   งานนี้ใช้`res://...tscn`ที่cleanimportโหลดได้จริง; UIDเดิมยังชี้Legacyสำหรับประวัติrollback.
3. **Scene Inheritance:** opt-insceneอ้างPackedSceneLegacyแล้วoverrideแค่`session_mode=1`.
   Node Tree, controllerและpresentationใช้ชุดเดียว; เปลี่ยนentryจึงไม่ต้องcopyโค้ดหรือnodeใหม่.
4. **Session Modeกับauthority:** enum`LEGACY/AUTONOMOUS`เลือกก่อน`_ready()`.
   ทางหนึ่งสร้างTurnFlow/Targets อีกทางสร้างEncounter; testsดูinstance/HPnullและทุกframeเพื่อจับสองauthority.
   ไม่สลับmodeกลางbattleเพราะHP/Guard/HELP/queueมีความหมายต่างกัน.
5. **ทำไมเก็บLegacy:** เป็นfallbackที่เล่นได้และอ้างอิงregressionเก่า.
   `session_mode`defaultยังLEGACYทำให้F6Legacyไม่แอบใช้Encounterแม้projectdefaultเปลี่ยน.
6. **ทำไมต้องมีregressionใหม่:** การเปลี่ยนentryอาจเปิดfixtureผิด, modeช้าไปหลังready,
   UIDไม่resolveหรือcallbackข้ามRestart. ทดสอบconfiguredentryและnative startupเพิ่มจากฉากopt-in.
7. **Cutoverต่างจากrefactor:** cutoverเปลี่ยนจุดเริ่มใช้ระบบที่มีอยู่;
   refactorเปลี่ยนโครงภายในระบบ. งานนี้ไม่แก้controller/Encounterหรือbalanceและตรวจdiffเพื่อยืนยันขอบเขต.
8. **Rollback:** หยุดprocessเก่า คืนmain_sceneในcopyแยก แล้วเปิดproject/battleใหม่.
   ไม่copyEncounter.snapshot()ไปใส่LegacyHP; nativeprobeกับfullLegacyregressionพิสูจน์ว่าคืนทางเก่าได้จริง.
9. **Headlessกับภาพ:** process_frame/TweenตรวจHP/token/queue/ตำแหน่งได้ละเอียด,
   แต่ไม่ตอบว่าreasonอ่านทันหรือpanelบังภาพหรือไม่. ownerF5/F6ที่1280×720เป็นgateอีกชุด.
10. **CommitและSHA-256:** commitบอกชุดsourceที่ทดสอบ; hashรายไฟล์จับการเปลี่ยนหลังทดสอบ
    รวมUID/scene metadata. FinalHEADอาจเพิ่มdocs/evidenceได้ แต่ต้องรายงานdiffและยืนยัน81sourcefilesเดิม;
    ถ้าtest/runtimeเปลี่ยนแม้หนึ่งไฟล์ ผลเดิมไม่พอ ต้องรันใหม่.

## M3A-02 — Guidance Data Verification

M3A-02 is Encounter-owned **data/lifecycle only**. The owner approved G1–G14 with **HELP50% not approved**, and authorized only M3A-02. No Resolver policy, UI, controller, scene, balance or default entry changes. [Request contract / lifecycle / D01–D28 / Thai learning notes](../npc/README.md#m3a-02--guidance-data-foundation). Current status belongs to the [documentation index](../../docs/README.md#current-status-and-next-roadmap).

Pre-implementation: fresh PR #39 `1728c5e` reference **44 stages PASS** in a disposable export, followed by fresh merged PR #40 `1facf144` **52 stages PASS**. Engine `4.7.2.stable.official.ed1daf0bf`, all inherited counts match, negative exactly five expected errors, Legacy6cases/5,892frames identical. Source was not changed until both runs passed.

The attached owner M3A-02 task reports **M2D-04 F5 / F6 Autonomous / F6 Legacy acceptance passed**. This updates current status as **Owner-Reported Acceptance** only; older pending records above are historical, and no independent scenario-level visual evidence or new agent GUI run is claimed here.

Add `--guidance-data-proof` to the full cutover command. It adds three parse stages and one data proof; all existing assertions/gates and the required 44-stage cutover reference remain intact. D01–D26 are focused data tests; D27/D28 are mapped to actual full regression results. Expected/actual, commands, exits, engine logs and source hashes must accompany any claimed final PASS.

Final source commit **`be08f11`**: **56 stages PASS**, all exit0, zero timeouts/unexpected errors, negative exactly five expected errors. Guidance **66,641 checks / 26 focused cases**; D27/D28 verified by full regression, for **28 acceptance cases**. No runtime/test changes after this run; later Markdown/evidence updates match all **85 source hashes**.

| Suite | Fresh merged baseline | Final actual |
|---|---:|---:|
| Combat | 14,395 | 14,395 |
| Negative | 983 + 5 expected errors | 983 + 5 expected errors |
| M2A-02 / M2A-03 | 412 / 5,166 | 412 / 5,166 |
| M2B-01 / M2B-02 | 122 / 219 | 122 / 219 |
| M2C-02 / M2C-03 | 382 / 1,250 | 382 / 1,250 |
| M2C-04 | 260,800 | 260,800 |
| M2D-02 | 8,319 | 8,319 |
| M2D-03 | 787,617 | 787,617 |
| M2D-04 | 801,351 / 48 cases | 801,351 / 48 cases |
| M3A-02 Guidance data | — | 66,641 / 26 focused cases |
| Legacy exact traces | 6 cases / 5,892 frames | identical |

Durable evidence:

- [Run record / authorization / commands / limitations](evidence/m3a-02/run-record.json)
- [Fresh PR #39 reference44stages](evidence/m3a-02/reference-results.json), [fresh merged PR #40 baseline52stages](evidence/m3a-02/baseline-results.json), [final56stages](evidence/m3a-02/final-results.json)
- [D01–D28 expected/actual coverage](evidence/m3a-02/coverage.json), [Guidance focused cases](evidence/m3a-02/guidance-data-scenarios.json), [inherited count comparison](evidence/m3a-02/inherited-counts.json)
- [C01–C22 cutover gates](evidence/m3a-02/cutover-release-gates.json), [native configured startup](evidence/m3a-02/main-cutover-f5-startup.json), [rollback](evidence/m3a-02/rollback.json)
- [Legacy trace equality](evidence/m3a-02/trace-comparison.json), [raw reference/baseline/final traces](evidence/m3a-02/traces.zip), [scenario snapshots](evidence/m3a-02/scenarios.zip)
- [All raw logs / engine logs / exits / snapshot startup configs, including development failure](evidence/m3a-02/logs.zip)
- [Final source SHA-256](evidence/m3a-02/source-sha256.json), [baseline source SHA-256](evidence/m3a-02/baseline-source-sha256.json), [85/85 comparison and source scope](evidence/m3a-02/source-comparison.json)

Development proof initially failed because the new validator assumed positive Encounter IDs. Corrected the validator to accept **non-zero signed RefCounted IDs** and require exact current identity; Encounter/token IDs and all gameplay expectations remain unchanged. The successful development rerun and final committed run are recorded separately. Initial disposable export setup also encountered an older host Python API; corrected the export setup before starting Godot or editing runtime.

At the original M3A-02 checkpoint it was ready for Draft code review and not yet merged (subsequently merged via PR #41). No new agent F5/F6 visual acceptance was run; current change is data-only. Existing OPT-IN naming, English reasons, short log and translucent result panel remain known presentation limitations. The original stop boundary was Draft review, with no M3A-03 or automatic merge in that task.


## M3A-03 — Guidance Decision Verification

M3A-03 adds opt-in `--guidance-decision-proof`: three parse stages and one isolated proof stage. It does not enable Guided Policy in existing Main integration tests. See [contract, owner-approved predicates, P01–P32 and Thai learning notes](../npc/README.md#m3a-03--isolated-guidance-decision-proof).

On **5 November 2026 (Asia/Bangkok)**, actual engine `/Applications/Godot.app/Contents/MacOS/Godot --version` returned **`4.7.2.stable.official.ed1daf0bf`**. Before runtime edits, exported merged PR #39 `1728c5e678c5065278d1251d50449a8820eb5dae` to a disposable local Git repo and ran its unchanged runner: **44 stages PASS**. The cutover runner requires this passing44-stage reference, not the56-stage current base. Then verified merged PR #41 **`cf5611ea71e68dcc9dbcac9a627df88f357d20c3`**: **56 stages PASS**, Guidance Data66,641checks, all reference counts and exact Legacy6cases/5,892frames.

The first sandbox reference import was correctly marked FAIL despite exit0 due to OS certificate/editor-settings permissions. Re-ran identical source with normal system access in a fresh output directory before implementation; did not suppress errors. Development proof1 failed a new Legacy API fixture (two-enemy input to the original single-enemy API). Corrected only that fixture; no inherited tests/constants changed. Raw failed and successful attempts are retained.

Committed source **`1ab6c7367b27ff4eb2fdba9da0b173b84ec0d8a4`** passed **60 stages / all exit0**, including **30 focused cases / 1,192 checks / zero failures**. P29/P30 are separately evidenced full-regression gates, totaling32acceptance items. No unexpected errors/timeouts; negative suite has exactly five expected errors. Subsequent changes are Markdown/evidence only; **91/91 source/test/asset/config hashes match** the tested source.

| Suite | Fresh PR #41 baseline | Final actual |
|---|---:|---:|
| Legacy gameplay | 14,395 | 14,395 |
| Negative | 983 +5expectederrors | 983 +5expectederrors |
| M2A-02 / M2A-03 | 412 / 5,166 | 412 / 5,166 |
| M2B-01 / M2B-02 | 122 / 219 | 122 / 219 |
| M2C-02 / M2C-03 / M2C-04 | 382 / 1,250 / 260,800 | 382 / 1,250 / 260,800 |
| M2D-02 / M2D-03 | 8,319 / 787,617 | 8,319 / 787,617 |
| M2D-04 cutover | 801,351 / 48cases | 801,351 / 48cases |
| M3A-02 Guidance Data | 66,641 | 66,641 |
| M3A-03 Guided decisions | — | 1,192 / 30focusedcases |

Reference→baseline→final Legacy traces are identical in every frame: **6 independent cases / 5,892 frames**. Counts are assertions/frame observations, not independent scenarios. Native configured startup and disposable Legacy rollback/import/startup/full regression pass. Production/Main receives Guidance data yet still uses the original resolver; direct Legacy F6 remains Legacy. No Main/UI/scene/config/presentation change was made.

Exact final command (reference and baseline commands in run record):

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m3a03-final-20261105-1 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof \
  --autonomous-main-proof --main-cutover-proof --guidance-data-proof \
  --guidance-decision-proof \
  --cutover-baseline /tmp/wanderer-m3a03-reference-20261105-2
```

For another run choose a new output directory; create the disposable PR #39 reference using `git archive` and its original runner. Canonical project config/branch is never changed to produce that reference. All test processes use fresh source snapshots/imports. Final HEAD and the exact tested commit are recorded separately in the Draft PR description to avoid claiming documentation commits were independently rerun.

- [Run record / commands / approval / expected-actual / limitations](evidence/m3a-03/run-record.json)
- [Reference44stages](evidence/m3a-03/reference-results.json), [merged PR #41 baseline56stages](evidence/m3a-03/baseline-results.json), [final60stages](evidence/m3a-03/final-results.json)
- [P01–P32 mapping](evidence/m3a-03/coverage.json), [30focusedcase reports](evidence/m3a-03/guidance-decision-scenarios.json), [all scenario snapshots](evidence/m3a-03/scenarios.zip)
- [All13inheritedsuitecounts](evidence/m3a-03/inherited-counts.json), [22cutoverreleasegates](evidence/m3a-03/cutover-release-gates.json), [Legacy rollback](evidence/m3a-03/rollback.json)
- [Three-way exact trace comparison](evidence/m3a-03/trace-comparison.json), [raw traces](evidence/m3a-03/traces.zip), [all raw stage/engine logs/exit codes including failed attempts](evidence/m3a-03/logs.zip)
- [Final SHA-256 manifest](evidence/m3a-03/source-sha256.json), [baseline manifest](evidence/m3a-03/baseline-source-sha256.json), [91/91 source comparison and scope](evidence/m3a-03/source-comparison.json)

**Limitations:** no GUI F5/F6 visual acceptance in this task; no visual/pacing claim from headless results. Guidance UI/playable Main integration remains M3A-04/05 and is not started. Compassion has no new policy effect; HELP50% is not implemented. Revision system-invalidation note is analyzed and deferred without changing submit-only semantics. Await one Draft PR review; no merge/auto-merge authorization.

<a id="m3a-04--playable-guidance-candidate"></a>

## M3A-04 — Playable Guidance Implemented

**M3A-04 — Implemented / Merged / Owner Accepted.** [PR #43](https://github.com/shanwinder/wanderer/pull/43) merged เข้า `visual-combat-test-1` ที่ [`a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34`](https://github.com/shanwinder/wanderer/commit/a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34). ตรวจ fetch/local HEAD/remote HEAD/merge-base ตรง SHA นี้ก่อนแก้ closure Markdown วันที่ 5 พฤศจิกายน 2026. Owner accepted ตามคำยืนยันในงานปิด M3A-05 ด้านล่าง ไม่ใช่ agent independent visual verification. สถานะหลักและข้อเสนองานถัดไปอยู่ที่ [documentation index](../../docs/README.md#current-status-and-next-roadmap).

**Historical implementation baseline:** งาน PR #43 เริ่มจาก merged [PR #42](https://github.com/shanwinder/wanderer/pull/42) `2d3b1e110c3957531a3faaa402b37d963009405a` บน `codex/m3a-04-playable-guidance-integration`. Owner อนุมัติ **R1 Option A** ใน chat วันที่ 5 พฤศจิกายน 2026 ก่อน runtime edits. Commands/results/GUI limitations ด้านล่างเป็น record เดิมของ PR #43 ไม่ใช่การรันใหม่ใน closure task.

### Architecture / R1 / policy preservation

[Production GuidedEncounter](../../scripts/combat/guided_encounter.gd) สืบทอด FullPartyEncounter และใช้ Guidance Decision Layer เดิมจาก M3A-03. Test-only proof subclass เปลี่ยนเป็น subclass บาง ๆ ของ production adapter; Main ไม่ import proof class. มี Gameplay Authority ชุดเดียว: Encounter ถือ queue/Guard/HELP/Guidance/token, ActorRuntimeState ถือ HP; Controller ถือ draft selections และ visual views; Presentation Adapter เดิมถือ Tween/impact/completion. ไม่มี shadow combat state.

R1 เปลี่ยนจาก submit-only เป็น Pending Content Revision: accepted submission +1; ล้าง Pending FOCUS_TARGET หลังถอน preferred Enemy สำเร็จ +1 ก่อนสร้าง NONE record. Reads/rejects/HP0/unrelated actor removal ไม่เพิ่ม. Freeze/round completion/terminal ใช้ round/lifecycle identity เดิม; Restart generation ใหม่/revision0. [Current contract และผลต่อ stale client/frozen state/roster](../npc/README.md#r1-option-a--current-m3a-04-contract). ใช้ request version1/eight fieldsเดิม ไม่เพิ่ม schema/counter แบบ Option B.

NONE เท่ากับ unguided baseline; safety, urgent HELP ≤30%, HELP+4/once, cooperation predicate และ Courage เดิมไม่เปลี่ยน. **HELP50% NOT APPROVED**, Compassion ไม่มี policy ใหม่, first valid hit เดิม, ไม่เพิ่ม randomness/Speed forecast/initiative. Player/NPC/Enemy damage5/1/3, Guard reduction2/min1, Combat Speed0.70/Lunge44px/Compact Formation และ saved homes เดิม. Scene/assets/project config/Resolver/Layer/Presentation Adapter ไม่แก้. Default ยังคง Autonomous และ direct Legacy F6 ยังเล่นได้.

Controller อ่าน identity/revision ล่าสุดก่อน submit; ถ้าไม่ ACCEPTED จะไม่ begin_round. ถ้า accepted แล้ว Player command reject จะแสดง Pending จริงพร้อม error. Begin STARTED จึง Frozen; queue ปิด selectors. NPC ประเมินตอน slot จริง; response/decision metadata lock แยกจาก actual effect. `_autonomous_current()` เปรียบเทียบ Guidance metadata กับ Encounter locked token ด้วย. Restart ใช้ visual epoch/generation และ cleanup เดิม. Controller อ่าน snapshots เท่านั้น ไม่มี API ให้ UI เขียน locked decision/profile.

### วิธีเล่นและบทเรียน GDScript ภาษาไทย

ใช้ Goal → Concept → Do → Observe → Explain → Adjust → Commit โดยลองทีละ scenario:

1. **F5/F6:** เปิด project ด้วย Godot4.7.2 แล้ว F5 เพื่อเปิด Main. เปิด `res://scenes/combat/combat_autonomous_optin.tscn` แล้ว F6 ได้ flow เดียวกัน. เปิด `combat_prototype.tscn` แล้ว F6 คือ Legacy ซึ่งไม่มี Guidance. ไม่สลับ authority ระหว่าง session.
2. **Player Command:** Target Picker ด้านล่างเลือกเป้าหมายโจมตีของ Player แล้วกดโจมตี/ตั้งรับ. ผู้เล่นควบคุมเพียงตนเอง; `begin_round()` เป็นเจ้าของการเริ่ม queue จริง.
3. **Guidance เป็นคำแนะนำ:** selector ด้านซ้ายบนเลือก NONE/ATTACK/DEFEND/HELP/FOCUS_TARGET. การเปลี่ยน selector เก็บเพียง Draft ใน controller; ยังไม่เขียน Encounter และไม่มีปุ่มบังคับ NPC ลงมือทันที.
4. **Draft/Pending/Frozen:** Draft = ยังไม่ส่ง; Pending = Encounter รอเริ่มรอบ; Frozen = accepted และ round เริ่มแล้ว. กด Player command จึงสร้าง request จาก snapshot ล่าสุด → submit → ตรวจ ACCEPTED → begin_round. จบรอบกลับ NONE; terminal ปิด input. คำขอถูกปฏิเสธต่างจาก NPC ปฏิเสธ Guidance.
5. **FOCUS_TARGET:** เลือก Focus EnemyB ด้านบนและ Player Target EnemyA ด้านล่างได้พร้อมกัน. `guidance_draft_target` แยกจาก `autonomous_selected_target`. NPC1/2 อาจเลือก B, NPC3 อาจเลือก A ตาม policy. HP0 preference อาจใช้ไม่ได้เมื่อถึง slot.
6. **NPC ตัดสินใจเอง:** Normal + FOCUS B เห็นการร่วมมือและ profile refusal; Player needs HELP + ATTACK เห็น NPC1 ช่วย Player ก่อน; NPC self-DEFEND + ATTACK เห็น safety มาก่อน. สอง preset เพิ่มเติม “Guidance: mixed responses” และ “Guidance: cautious DEFEND” ใช้ค่าตัวเลขเดิมเพื่อสังเกต predicate ที่อนุมัติ ไม่ใช่ balance ใหม่.
7. **FOLLOWED กับ MATCHED:** FOLLOWED แปลว่า Action/Target เปลี่ยนจาก baseline เพราะคำชี้นำ; MATCHED_INDEPENDENTLY แปลว่าเดิมก็ตัดสินใจแบบนั้น. ลอง Normal + ATTACK หรือ FOCUS A เทียบ FOCUS B. `guidance_response` อยู่ข้าง `decision` ไม่เปลี่ยน original schema.
8. **Decision กับ Effect:** บรรทัด NPC แสดง Action/Target, action reason, response/reason และ APPLIED/SKIP/HP delta. HELP consumption และ guard อยู่ใน actual effect/log/tooltip. เป้าหมายตายหลัง lock อาจยัง FOLLOWED แต่ SKIP HP0 ตอน impact; ไม่มี damage/retarget ที่แอบเกิด. ภาษาไทยอยู่ใน [message mapping](../../scripts/combat/guidance_messages.gd) แยกจาก policy; English codes ดูใน tooltip/scrollable log.
9. **Restart/Revision:** Restart คืน NONE/rev0 พร้อม generation ใหม่และยกเลิก Tween/popups/flash. `guidance_revision` ป้องกัน stale client ใน round เดิม; generation ป้องกันคำขอและ callback ข้าม session. R1 เพิ่ม revision เมื่อระบบถอน Enemy ที่ pending focus ด้วย; การอ่าน snapshot ไม่เพิ่ม.
10. **เรียนรู้ผ่าน preset:** ลอง HELP, safety, multiple HELP, unavailable slots, victory/defeat และ kill order ทั้งสอง. สังเกต NPC1 HELP6→10 ทำให้ NPC2 ไม่อยู่ urgent region แล้ว; resolver อ่าน state ใหม่ตอนแต่ละ slot ไม่ precompute ทั้งทีม. ห้ามตีความ fixed traits ว่าเป็น persistent personality เต็มระบบ.
11. **อ่าน Evidence:** `results.json` บอก stage/command/exit/errors/timeout; scenario report มี expected/actual/locked tokens/effects; trace comparison เทียบ Legacy ทุก frame; source manifest ยืนยัน source ที่ทดสอบ. จำนวน checks รวม per-frame assertions ไม่ใช่จำนวน independent cases. Headless ไม่ยืนยันความรู้สึกหรือ owner comprehension.
12. **ข้อจำกัด:** ข้อความ debug ยาวถูก clip ในแถวหลักและอ่านเต็มผ่าน tooltip/log; log เลื่อนดูได้และไม่ทับ controls. Queue ยัง Player→NPC→Enemy ตาม prototype; Final Turn System OPEN, Speed Order Pending, M2B-03 Deferred. ไม่มี HELP50%, Compassion effect, trust progression, items, retreat หรือ permadeath ใหม่.

### Focused integration / assertion migration

`--guidance-main-proof` เพิ่มสาม parse stages และ real Main scene proof. I01–I34 คือ34 focused cases; I35/I36 เป็น full-regression/error gates แยก ไม่อ้างเป็น focused cases.

| Cases | Expected |
|---|---|
| I01–I07 | F5 config/production guided type/single authority/NONE; Player A vs Focus B; draft→accepted→freeze→NONE; malformed draft blocks round; accepted-but-rejected command stays Pending |
| I08–I16 | Main ATTACK independent; Focus B followed/A independent; discretionary DEFEND; safety/urgent HELP refusals; HELP40% not applicable; urgent HELP independent; profile refusal |
| I17–I22 | Three independent responses; focus dead before slot/after lock; system invalidation/UI refresh; R1 both enemy IDs/stale/fresh/frozen/Restart; detached nested snapshots/token and unavailable NPC explanation |
| I23–I28 | Restart windup/impact/return; delayed old and forged metadata callbacks; guided victory/defeat; HELP+4/once and next-hit self Guard exactly once |
| I29–I34 | Distinct 1280×720 controls/hitboxes/focus links/log; all actual Layer reason codes mapped Thai/English; independent rows; Legacy no UI;18paired NONE rounds vs unguided base; presentation baseline |
| I35/I36 | All inherited suites/counts retained, exact Legacy traces, native startup/rollback; no unexpected errors/timeouts |

**Intentional migration:** M3A-03 P31 used to assert Main unguided / FOCUS ignored→A. M3A-04 requires production GuidedEncounter (not proof subclass) / FOCUS B→FOLLOWED B. Same three checks remain, no lowered coverage/count. P21 still proves **base FullPartyEncounter unguided**, P01 preserves NONE exact decisions/effects, and I33 adds18paired real-Main NONE rounds. M3A-02 Data Proof remains base/data-only; only round-completion assertion wording changes, its predicate stays exact. [Before baseline](evidence/m3a-04/baseline-results.json), [final](evidence/m3a-04/final-results.json), [focused coverage](evidence/m3a-04/guidance-main-scenarios.zip).

### Verification and durable evidence

**Verified — Recorded (PR #43):** ผลและ engine version ต่อไปนี้มาจาก record เดิม. Documentation closure ไม่รัน Godot/full regression, F5/F6, keyboard หรือ visual acceptance ใหม่; ไม่อ้างว่าทดสอบ merge commit อีกครั้ง. **64/64 stages PASS**, **34 focused Guidance Main cases / 507,851 Main checks**, zero unexpected failures, Legacy6cases/5,892frames identical และ97/97source hashes matching เป็นผลที่บันทึกบน tested source ด้านล่าง. 507,851 รวม per-frame assertions ไม่ใช่ independent test cases. Negative five expected errors แยกจาก unexpected errors. หลักฐาน logs/JSON/ZIP และ pending GUI ข้างล่างไม่ถูกแก้ย้อนหลัง.

Actual executable `/Applications/Godot.app/Contents/MacOS/Godot --version` returned **4.7.2.stable.official.ed1daf0bf**. Before runtime edits: disposable unchanged PR #39 `1728c5e` reference44stages PASS, then actual merged PR #42 `2d3b1e1` baseline60stages PASS. Sandbox import first attempt had an unexpected macOS CA-certificate error despite exit0; classified FAIL and preserved. Same source with normal OS access in a fresh output passed before implementation. Export setup initially hit host Python's unsupported tar filter argument, corrected before Godot ran.

Final tested source commit **`5e54b6f`**: **64 stages PASS / 34 focused Main cases / 507,851 Main checks**, Guidance Data66,641 / Decision1,192 and all inherited counts retained; Legacy6cases/5,892frames identical,97/97source hashes equal, zero unexpected errors/timeouts (negative five expected errors). Exact results/counts, command lines and GUI scope are in the records below; final PR head may add only Markdown/evidence. Full run includes fresh import, parse, configured Main startup, Legacy startup/gameplay, negative suite (five expected errors), all M2A/B/C/D and M3A-02/03/04 proofs, native configured startup, fresh rollback, trace/count release gates.

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m3a04-final-20261105 \
  --npc-proof --actor-proof --ownership-proof --party-foundation-proof \
  --party-turn-proof --party-playable-proof --presentation-proof \
  --autonomous-main-proof --main-cutover-proof --guidance-data-proof \
  --guidance-decision-proof --guidance-main-proof \
  --cutover-baseline /tmp/wanderer-m3a04-reference-20261105-2
```

Create the PR39 reference with `git archive 1728c5e` into a disposable directory, initialize a local Git index, then run its original runner with all flags through `--autonomous-main-proof` only; that runner yields the required44-stage reference. Never edit canonical config/expected counts to fabricate a reference. Choose fresh output paths on later runs.

- [Run record / engine / tested commit / commands / limitations](evidence/m3a-04/run-record.json)
- [Reference44 results](evidence/m3a-04/reference-results.json), [merged-base60](evidence/m3a-04/baseline-results.json), [final results](evidence/m3a-04/final-results.json), [inherited counts](evidence/m3a-04/inherited-counts.json)
- [Focused I01–I34 report](evidence/m3a-04/guidance-main-scenarios.zip), [all scenario reports](evidence/m3a-04/scenarios.zip), [I35/I36 gates](evidence/m3a-04/coverage.json)
- [Exact Legacy comparison](evidence/m3a-04/trace-comparison.json), [raw three-way traces](evidence/m3a-04/traces.zip), [rollback](evidence/m3a-04/rollback.json)
- [SHA256 manifest](evidence/m3a-04/source-sha256.json), [final source equality](evidence/m3a-04/source-comparison.json), [scope/link/artifact checks](evidence/m3a-04/review-checks.json)
- [All raw stage/engine logs and exits, including failed development/import attempts](evidence/m3a-04/logs.zip), [agent GUI screenshots](evidence/m3a-04/gui.zip), [GUI observations/scope](evidence/m3a-04/gui-smoke.json)

Development focused attempt1 had a read-only constant mutation in a new test, a missing test-only HUD refresh after direct race mutation, and mismatched actor display names in the paired fixture. Fixed fixtures using a test-only rejecting Encounter / snapshot HUD refresh / matching names; no balance/Resolver change. Attempt2:34cases/495,410checks/0failures. Added explicit unavailable-NPC metadata coverage before final rerun; final report is authoritative. Full development run:64stages PASS; all inherited counts unchanged. Failed logs are retained, not removed from the record.

Agent GUI smoke observed F5/Autonomous F6/Legacy F6 through editor toolbar equivalents at project logical1280x720,1.0x embedded (host panel1475x719 with letterboxing). Final-source F5 FocusB/PlayerA round produced Player24/A9/B10 and next-roundNONE; F6 urgentHELP produced Player8/A13/B12 with NPC1 HELP0; Legacy Attack produced Player25/A8/B12. Thai responses/log and Restart cleanup were observed. This is limited smoke: manual keyboard focus transition was **UNVERIFIED** after CUA Tab/Enter did not establish it; calibrated standalone capture, full visual matrix, manual discretionary-DEFEND/SKIP races and owner comprehension remain pending. No visual acceptance PASS is inferred from headless tests or screenshots.

<a id="m3a-05-owner-acceptance-checklist--pending-separate-milestone"></a>

### M3A-05 Owner Acceptance — COMPLETED

**M3A-05 — Owner-Reported Acceptance: PASS.** แหล่งคำรับรองคือเจ้าของโครงการใน ChatGPT request “M3A-05 Owner Acceptance Closure & Next Milestone Preparation” วันที่ **5 พฤศจิกายน 2026 (Asia/Bangkok)**: ยืนยันว่า merge PR #43, ลบ feature branch และตรวจรับ M3A-05 โดยรวมผ่านแล้ว พร้อมอนุญาตให้บันทึก acceptance/ปรับเอกสาร/เสนอ milestone ถัดไป. Agent ยืนยัน merge และฐาน Git แยกจากคำรับรองการเล่นของเจ้าของ.

**Owner-reported acceptance; per-scenario independent evidence not supplied.** ไม่มีผลราย scenario, engine/commit ที่ owner ใช้เล่น, screenshot หรือวิดีโอแนบมากับคำยืนยัน; ไม่สมมุติรายละเอียดเหล่านั้น. Engine/tested commit ของ automated record ด้านบนไม่ใช่หลักฐานว่า owner ใช้ executable/commit เดียวกัน. การปิดนี้เป็น overall Owner-Reported Accepted ไม่ใช่ Independent Verification โดย agent และไม่ใช่ผล automated ใหม่.

Acceptance matrix เดิมมีขอบเขตดังนี้; ทุกแถวอยู่ภายใต้ **คำยืนยันรวมว่า PASS** เท่านั้น ไม่มี independent result รายแถวให้บันทึก:

| Acceptance area | ขอบเขตที่อยู่ใน matrix |
|---|---|
| F5 Guided Main | Run Project ใช้ production GuidedEncounter / Main entry |
| F6 Autonomous | Run Current Scene ของ Autonomous entry |
| F6 Legacy | Legacy entry, no Guidance และกฎ NPC2 Guard เดิม |
| Guidance and Focus selection | คำแนะนำทีม/Focus แยก Player Command/Player Target |
| NPC response readability | คำขอ, decision, reason, response และ actual effect อ่านเข้าใจ |
| FOLLOWED vs MATCHED_INDEPENDENTLY | แยกการเปลี่ยนเพราะ Guidance จากการเลือกเหมือนกันเอง |
| Profile refusal | การปฏิเสธจาก fixed prototype profiles |
| Urgent HELP and Safety Priority | HELP≤30%/+4/once และ safety มาก่อน Guidance |
| Discretionary DEFEND | cautious/cooperation/valid self threat predicates เดิม |
| Target invalidation and SKIP | ก่อน slot vs หลัง lock; ไม่อ้าง effect ที่ไม่ได้เกิด |
| Restart and stale callbacks | lifecycle/generation/revision/cleanup และผลเก่าไม่ข้าม session |
| Victory and Defeat | terminal result, queue/input locking และ Restart |
| Keyboard navigation | การเข้าถึง controls ด้วย keyboard |
| Thai UI readability | label, explanation, tooltip และ log ภาษาไทย |
| Combat pacing and presentation | speed0.70, 44px lunge, Compact Formation, animation/feedback/return homes |
| Owner comprehension | เข้าใจคำแนะนำ เหตุผลที่ NPC เลือกเอง และ applied/skipped effect |

**Evidence classification:** Implemented = merged code ของ M3A-04; Verified — Recorded = automated PR #43 บน `5e54b6f5bcc5ada73cbd07c4dbdeca99256d2378`; Owner-Reported Accepted = คำรับรองรวมวันที่ข้างต้น. Agent GUI smoke เดิมยังมีข้อจำกัดเรื่อง keyboard/full visual matrix/manual DEFEND/SKIP races และ calibrated capture ตาม record; ไม่เปลี่ยนเป็น agent PASS เพราะ owner รับรองภายหลัง.

**Documentation closure validation — 5 November 2026:** ตรวจ diff เทียบ `a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34` ด้วย `git diff --name-only` และ `git diff --check`: เปลี่ยนเฉพาะ Markdown5ไฟล์ (AGENTS/root README/docs index/combat guide/NPC guide), whitespace check ผ่าน. ตรวจ Markdown13ไฟล์ทั้ง repository: local file/fragment links255รายการ รวม Markdown anchors58รายการ, broken0; รองรับ explicit historical anchor aliases. ตรวจ PR #43/merge SHA จาก GitHub เทียบ local/remote/merge-base; ตรวจ current status/owner attribution/roadmap approval boundaries ด้วยตนเอง. SHA-256 ของ source/test/config/assets ทั้ง97ไฟล์ตรง manifestเดิม — เป็น source-integrity check ใหม่ ไม่ใช่ runtime verification ใหม่. Historical combat recordsก่อน M3A-04, checklistด้านล่าง และ exact R1 contract ใน NPC guideคงเดิม; ไม่แก้ evidence JSON/ZIP, test assertions หรือ expectations. **Godot/full regression/GUI/manual keyboard/visual acceptance: NOT RUN ในงาน closure นี้.** ผล runtime PASS อ้างอิง PR #43 เท่านั้น.

**Historical checklist ณ PR #43 (เก็บช่องเดิม ไม่ใช่สถานะ PENDING ปัจจุบัน):** ข้อความและช่องว่างข้างล่างสะท้อนสิ่งที่ record เดิมยังไม่ได้บันทึกโดย owner ในงานนั้น. คำสั่งให้คง pending ใน checklist เป็นประวัติก่อนคำรับรอง 5 พฤศจิกายน ไม่ลบ/ติ๊กย้อนหลังเป็น independent verification. Original checklist introduction: Agent GUI smoke is limited evidence; it does not complete these owner gates. Record engine, commit, expected/actual, pacing/readability and media/notes for each when separately authorized:

- [ ] F5 and F6 Autonomous at1280×720: Guidance/Focus/Player Target labels, hitboxes, Tab/keyboard navigation, long Thai messages/tooltips/log scroll readable and separate from controls.
- [ ] Normal + ATTACK/FocusA/FocusB: explain MATCHED_INDEPENDENTLY vs FOLLOWED; NPC3 profile refusal; Player target independent.
- [ ] Player needs HELP + ATTACK: NPC1 REFUSED/urgent HELP+4/use once, later NPC decisions refresh; HELP40% never heals.
- [ ] NPC self-DEFEND and both new Guidance presets: safety priority, discretionary cautious guard, same team suggestion/different responses, next-valid-hit semantics.
- [ ] Target dies before slot vs after lock: latest decision vs immutable lock; SKIP/HP0 clearly distinguishable from successful attack.
- [ ] Restart before/after impact/during return: no old popup/text/flash/damage/callback; NONE/rev0/new session.
- [ ] Victory/defeat result panel, input locking, new round NONE; no stale Frozen claim on failed command.
- [ ] F6 Legacy: no Guidance controls; NPC2 Guard Player; original HP/target fallback/both kill orders/queue, direct scene remains available.
- [ ] Compare0.70pacing/44pxlunge/Compact Formation, idle/poses/guarded recoil, floating damage/heal/flash/spark, EnemyB tint/scale, return homes. Exact pixel/timing assertions are automated; owner judges feel.
- [ ] Owner can explain requested Guidance, actual NPC choice, response reason and actual applied/skipped effect without reading source. Keep M3A-05 pending until owner records acceptance.

## Optional M4-02 isolated atomic effect / clock proof

Add `--m4-atomic-clock-proof` to parse the new isolated aggregate, its test-only
fault subclass and focused harness, then execute the proof (four additional stages).
It works independently; keep `--m4-data-proof` for the unchanged original proof.
The runner checks exit status, unexpected Script/Engine errors, the success marker,
and machine-readable scenario counts/status. Default behavior and all existing
flags/negative error expectations are unchanged.

For complete reproduction, use the all-flags commands and reference provenance in
[the M4-02 run record](../actors/evidence/m4-02/run-record.json). Commands require a
fresh output directory and the actual Godot 4.7.2 executable. The pre-cutover
44-stage reference is inherited and verified against its durable record; current
canonical and feature runs are fresh. See [schemas, actual coverage, evidence and
Thai learning notes](../actors/README.md#m4-02--isolated-atomic-effect--clock-proof-candidate).
This isolated proof enables no production RESCUE/clock/death or UI.


R48-01 refresh: the same optional flag also executes the current/future operation-ID
collision regressions. Current total is55focused cases/1,188assertions; original
M4-01 remains78cases/525checks. Fresh full73/canonical69stages pass and Legacy
6cases/5,892frames match. See [namespace fix and actual evidence](../actors/README.md#r48-01--operation-id-namespace-review-fix).
No runner code or existing expectations changed in this review fix.

## Optional M4-03A isolated queue foundation proof

`--m4-queue-foundation-proof` adds three parse checks and the new focused executable
proof. It does not alter default behavior or existing proof/negative-test gates.
Its report validation requires exact JSON shape/types, unique sequential M403A
case IDs, actual assertion details and matching counts/stdout. Duplicate keys,
nonfinite constants, errors, failures, nonzero exits and timeouts fail verification.
No real action, completion receipt, seal/round close, retreat or terminal API exists
in this foundation. [API, Thai notes and actual coverage](../actors/README.md#m4-03a--isolated-queue--eligibility-foundation).

```sh
python3 tests/combat/verify.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output /tmp/wanderer-m403a-new-full --npc-proof --actor-proof --ownership-proof --party-foundation-proof --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof --main-cutover-proof --guidance-data-proof --guidance-decision-proof --guidance-main-proof --m4-data-proof --m4-atomic-clock-proof --m4-queue-foundation-proof --cutover-baseline /tmp/wanderer-m3a04-reference-20261105-2
```

Use fresh paths and an available, provenanced pre-cutover reference. The local
44-stage reference above is inherited; its results match the durable M4-01 record,
and 77 tracked source files match commit `1728c5e678c5065278d1251d50449a8820eb5dae`.
It is not a newly executed reference. Fresh canonical `67d68bb` all-flags run has
73 PASS stages; candidate `ad0e95c` adds four for77 PASS. Focused94cases/1,165assertions,
M40178/525 and M40255/1,188 unchanged; Legacy6cases/5,892frames identical.
[Exact engine/commands/commits, exits and limitations](../actors/evidence/m4-03a/run-record.json),
[canonical](../actors/evidence/m4-03a/canonical-results.json),
[final](../actors/evidence/m4-03a/final-results.json),
[raw logs](../actors/evidence/m4-03a/logs.zip).
GUI/keyboard/visual acceptance NOT RUN; M403-44 full boundary proof deferred to B/C.


## Optional M4-03B isolated RETREAT transaction proof

Add `--m4-retreat-transaction-proof` for four parse stages plus the focused B suite.
Uses the owner-selected opt-in subclass; A's unchanged absent-B-API assertions still
run through `--m4-queue-foundation-proof`. B report validation is separate/additive;
existing runner lines/gates remain unchanged. Exact JSON fields, unique sequential
case IDs, actual assertion booleans/count sum, stdout summary and CASE lines must agree.

Fresh8November2026 on source `c4a7c488726983e0d29fb3b085e34f5d855895cb`:
Godot4.7.2, B150cases/3,339assertions, canonical77/candidate82stages PASS;
A94/1,165, M40178/525, M40255/1,188, Legacy6cases/5,892frames identical.
Unexpected errors/timeouts0, all exits0; negative exactly5 expected errors separate.
[Exact API/schema/limits](../actors/README.md#m4-03b--isolated-retreat-transaction),
[durable run record and full commands](../actors/evidence/m4-03b/run-record.json).

```sh
python3 tests/combat/verify.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output /tmp/wanderer-r51-final-20261108 --npc-proof --actor-proof --ownership-proof --party-foundation-proof --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof --main-cutover-proof --guidance-data-proof --guidance-decision-proof --guidance-main-proof --m4-data-proof --m4-atomic-clock-proof --m4-queue-foundation-proof --m4-retreat-transaction-proof --cutover-baseline /tmp/wanderer-m3a04-reference-20261105-2
```

Choose a fresh output path; the reference path above is inherited pre-cutover evidence,
not the77-stage canonical run. [Reference provenance](../actors/evidence/m4-03b/reference-provenance.json)
checks its44 results against durable M401 evidence and source against its own commit.
No new pre-cutover reference run claimed. SKIPPED interleaving is diagnostic-only;
SEALED/terminal/last-active outcome deferred to C. Guard integration/manual visual
acceptance NOT RUN. Stop at Draft PR; no merge/auto-merge or next milestone.


R51-01 refresh uses the same Draft PR #51 and the actual post-fix source above.
RETREAT Lock/Impact now require a nonterminal Enemy availability boundary; the B
count is **150/3,339**, not the old138/3,138. [Red/green evidence and exact commands](../actors/evidence/m4-03b/r51-01.json)
retain both the initial harness parse failure and the genuine old-runtime reproduction.
Original A94/1,165 and all prior M4/production assertions remain unchanged. Completion/
Cancel are not subject to the new admission gate. No terminal classifier or production
integration; await independent follow-up review.


## Optional M4-03C isolated terminal / summary / continuation proof

`--m4-outcome-summary-proof` adds five C parse stages and one focused proof stage.
Original default/A/B/M401/M402/Main/Legacy/Guidance gates remain unchanged; the runner
diff is additive only. C report validation separately enforces exact JSON schema,
sequential unique C IDs, actual Boolean assertions/count sum, zero failures and exact
stdout/JSON CASE/RESULT agreement. Duplicate JSON keys/nonfinite constants, missing
reports, nonzero exits, unexpected Godot errors (even exit0) and timeouts fail.

```sh
python3 tests/combat/verify.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output /tmp/wanderer-m403c-new-full --npc-proof --actor-proof --ownership-proof --party-foundation-proof --party-turn-proof --party-playable-proof --presentation-proof --autonomous-main-proof --main-cutover-proof --guidance-data-proof --guidance-decision-proof --guidance-main-proof --m4-data-proof --m4-atomic-clock-proof --m4-queue-foundation-proof --m4-retreat-transaction-proof --m4-outcome-summary-proof --cutover-baseline /tmp/wanderer-m3a04-reference-20261105-2
```

Choose a fresh output path. The reference is the verified original pre-cutover
44-stage record/source, inherited, not a rerun or a substitute for fresh canonical.
[Exact commands/commits/reference provenance/evidence](../actors/evidence/m4-03c/run-record.json).
Focused reproduction can use just `--m4-outcome-summary-proof`; full regression above
is required for delivery.

Verified Godot4.7.2 on `d583b4b6fdd3226178e4f5b4e916c874a82d83c4`:
**115 C cases/6,054 assertions**, fresh canonical **82/82**, candidate **88/88 PASS**;
A94/1,165, B150/3,339, M40178/525, M40255/1,188 retained, Legacy6cases/5,892frames
identical. All final exits0/unexpected errors0/timeouts0; negative five expected errors
separate. A failed development fixture attempted to change an admission Enemy target
after rescue; raw failure/source is retained, then corrected without weakening runtime
or inherited assertions.

[API/schema/Thai notes and explicit partial/diagnostic/unreachable coverage](../actors/README.md#m4-03c--isolated-terminal--summary--continuation-proof).
No production/Main/Legacy/Guidance/NPC policy, balance, scene or presentation change;
manual GUI/F5/F6/keyboard/visual NOT RUN. Independent review remains pending.


R52-01 refresh: same Draft PR #52, tested source above, **115 C cases /6,054 assertions**. All original A/B/M401/M402 and M2/M3/Main/Guidance flags rerun; canonical82/candidate88 PASS and Legacy6/5,892 identical. [Exact request correction, run history and hashes](../actors/evidence/m4-03c/r52-01.json). The sandboxed import failure is retained; manual GUI/visual NOT RUN. Await independent follow-up; do not merge.

## Optional M4-04 autonomous decision proof

Use `--m4-autonomous-decision-proof` for additive exact-schema/provenance/pure-policy/supported C transaction verification. [API, coverage and Thai learning notes](../actors/README.md#m4-04--isolated-autonomous-decision-proof), [actual engine/commits/complete commands/results/failure history](../actors/evidence/m4-04/run-record.json). Fresh canonical88/candidate94 stages; M404128cases/458assertions. Runner requires 128 unique sequential case IDs, boolean assertions and exact totals/stdout, matching expected/actual step reasons, case classification, strict JSON and matching source hashes; nonzero exit/unexpected errors/timeouts reject. Malformed-report/stdout tests are archived separately. Original proofs/Legacy semantics unchanged. O4 deferred; HELP/DEFEND effects BLOCKED DEPENDENCY, live HELP source unknown; no fake effects/receipts. O7 mid-action producers diagnostic/deferred; manual GUI/visual NOT RUN. Stop at Draft PR for independent code/evidence review.
