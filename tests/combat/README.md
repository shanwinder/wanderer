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
