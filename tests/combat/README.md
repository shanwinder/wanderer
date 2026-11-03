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
