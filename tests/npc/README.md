# M2A-02 — NPC Decision & Effect Proof

Owner explicitly approved **M2A-01 D1–D9** and implementation of M2A-02 in
the task chat on 2026-11-03. These are approved **prototype** rules, not final
balance or a decision on the game's OPEN Turn System. M2A-01 is the design
report in that chat; this file documents the executable proof, not a new roadmap.

## Purpose and architecture

The main combat scene still uses its original scripted NPC rules. This proof
models **Player 1 + NPC 1 + Enemy A 1** independently, without scene nodes,
sprites, animation, gameplay UI, inventory, Trust or a Guidance system.

`Situation Snapshot → Decision Resolver → Validation → Effect → Result data`

- [NPCDecisionResolver](../../scripts/npc/npc_decision_resolver.gd) is a
  `RefCounted` with pure Dictionary input/output. It rejects missing/unknown
  fields, incorrect types, invalid HP, unsupported targets and invalid resources.
- [NPCProofEncounter](../../scripts/npc/npc_proof_encounter.gd) is a separate
  `RefCounted` data fixture with real HP/resource changes and NPC/enemy slots.
  Input is the state **after the Player's action**; Player animation/action
  execution and integration with `combat_turn_flow.gd` are outside M2A-02.
- [Headless tests](decision_effect_proof.gd) exercise both parts, including real
  delayed SceneTree timer callbacks across Restart.

For learning: a snapshot records facts; `decide()` chooses without changing
them; `resolve_npc()` changes combat values; `complete_npc()` allows the enemy
slot and completes the round. Keeping those boundaries separate lets a test
change one fact and explain why the choice or its validity changed.

## Approved prototype contract

Priority: terminal state → unavailable NPC → self-defense against a declared
threat when NPC HP ≤30% or incoming damage is lethal → HELP if Player HP ≤30%
and usable → ATTACK. Low HP alone does not trigger self-defense. Low-HP reason
takes precedence over lethal-threat reason when both describe the same choice.

| Decision | Target / effect / cost | Reason |
| --- | --- | --- |
| ATTACK | Enemy A; damage 1; one NPC slot | `ATTACK_AVAILABLE_ENEMY` |
| DEFEND | Self; reduce next incoming hit by 2, minimum damage 1; expires at round end; one slot | `SELF_LOW_HP_THREAT` / `SELF_LETHAL_THREAT` |
| HELP | Living Player; restore up to 4 HP, clamp to maximum; one slot and one use on success; one use per encounter | `PLAYER_LOW_HP_HELP` |
| HELP unavailable → ATTACK | Same attack; details distinguish disabled ability / exhausted uses | `HELP_UNAVAILABLE_ATTACK` |
| SKIP | Control result; no effect/resource cost; completion still drains queue | Actor/target/terminal reason |

Self-defense wins when NPC and Player are both at risk. NPC max HP is 10;
Player max HP is 30; Enemy max HP is 15, default post-Player HP is 10. Enemy
damage is 3. Enemy target is declared before the NPC slot and locked. Restart
resets the fixture's HELP use, not an in-world healing/recharge system.
NPC HP 0 means unable to act; it does not introduce Down or permadeath.

Example pure snapshot (no Node references):

```json
{
  "player_hp": 6, "player_max_hp": 30,
  "npc_hp": 10, "npc_max_hp": 10,
  "living_enemy_ids": ["enemy_a"],
  "incoming_target_id": "player", "incoming_damage": 3,
  "help_enabled": true, "help_uses_remaining": 1,
  "guidance": "ATTACK"
}
```

Expected decision: `HELP → player / PLAYER_LOW_HP_HELP`; `reason_details`
contains a deep copy of the facts above, including the suggestion. HELP raises
Player HP 6→10, then the enemy counter lowers it to 7. Enemy HP is unchanged.
Guidance is only scenario data; it never overrides the priority rules.

The encounter copies and locks the decision at slot start. Returned token and
inspection copies cannot replace it. At effect time it rechecks actor/target,
terminal state, HP need and HELP availability. Invalidated actions SKIP without
re-deciding or charging resources. Malformed snapshots return `INVALID_INPUT`
with `action=INVALID`, distinct from valid `SKIP`; neither uses an empty
Dictionary as an action. Empty internal storage is not an executable action.

The generation/action ID token rejects old callbacks after Restart and tokens
from previous rounds. Separate resolved/completed flags prevent duplicate
effects, enemy counters and round completion. Victory/defeat drains pending
work without incrementing the round. Enemy target unavailability skips its hit.
`apply_fixture_change()` exists only to inject races in this isolated proof;
it cannot change enemy targeting or decision priority.

## Reproduction and evidence

Run from the repository with a fresh output directory:

```sh
python3 tests/combat/verify.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --output /tmp/wanderer-m2a-02-unique --npc-proof
```

The opt-in flag adds the three new parse checks and proof execution to the
unchanged legacy suite. All existing checks and its five exact expected negative
errors remain required. Every normal stage requires exit 0 and no engine/script
errors; proof execution also requires a zero-failure `RESULT` marker. The runner
stores each command, stdout/stderr log, engine log, exit code and `results.json`.

Recorded final verification: **2026-11-03**, implementation commit
`bea778a5c811e1b7453128068abebe62a43f51e1`, based on merged
`95eaf4cc43292728ce45d4e989b6c3248c21fcd6` (PR #29 + #30).
Actual engine: **4.7.2.stable.official.ed1daf0bf**. Final command used
`--output /tmp/wanderer-m2a-02-final --npc-proof` with the executable above.
Subsequent changes are documentation/evidence only.

| Stage | Expected | Actual |
| --- | --- | --- |
| Engine version, clean import, seven script parses, main startup | Exit 0; no unexpected errors | PASS; exit 0 each |
| Legacy gameplay | Both kill orders, locks, targets, damage/Guard, defeat/victory, Restart unchanged | PASS; 14,395 checks, zero failures; exit 0 |
| Legacy negative suite | Exactly five expected errors | PASS; 983 checks, zero failures; exit 0 |
| NPC proof | S1–S11 and supplemental contracts | PASS; 412 checks, zero failures; exit 0 |
| Manual F6 / reason readability / visual pacing | Human acceptance in M2A-03 | NOT RUN; no presentation claim |

All S1–S11 rows below are **PASS** in the final run; raw expected/actual assertions
are in the harness and the scenario results are in `npc-proof.log`.

| Scenario | Expected / actual outcome checked by harness |
| --- | --- |
| S1 | ATTACK; Enemy 10→9; Player 20→17 |
| S2 | HELP; Player 6→10→7; uses 1→0 |
| S3 | Self-DEFEND; NPC 3→2; unguarded control reaches 0; Player unchanged |
| S4 | Exhausted/disabled HELP explained; ATTACK; no healing or extra use |
| S5 | Enemy dies before effect; SKIP; zero damage/counter; victory, no added round |
| S6 | Suggested ATTACK still yields HELP; correct HP/resource effects |
| S7 | Both low, NPC threatened; self-DEFEND before HELP |
| S8 | Player 8/9/10 and NPC 2/3/4 boundary cases; deterministic decisions; lethal threat above threshold |
| S9 | Enemy dead before slot; terminal SKIP with no pending work |
| S10 | Real delayed effect/completion callbacks before/after effect for all three actions; old generation rejected; new encounter works |
| S11 | Duplicate effects/completions rejected; no second cost, counter or round increment; previous-round/invalid token rejected |

Additional coverage: missing fields and Node values for every field, invalid
types/ranges/IDs, snapshot immutability, caller mutation, HELP cap/maximum HP,
second-round HELP exhaustion, minimum damage, invalidated HELP/dead actor,
Player defeat, NPC killing blow, invalid restart atomicity and queue exhaustion.

Durable raw evidence: [m2a-02.zip](evidence/m2a-02.zip), containing final logs,
exit codes, results and source SHA-256 manifest; initial sandbox-failed logs and
the first successful run are retained in separate archive folders. The first
attempt failed import despite exit 0 due to macOS certificate/editor-settings
sandbox access. It supplies no PASS claims. Final verification ran outside that
sandbox; all unexpected-error checks remained enabled. The archive excludes
imported caches and asset snapshots; regenerate them with the command above.

M2A-03 integration, playable UX and F6 remain unimplemented/unverified. No claim
is made that users understand NPC reasons without a playtest. Stop at Draft PR;
do not merge automatically or start M2A-03.
