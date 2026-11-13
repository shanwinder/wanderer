# Event, Receipt and Journal evidence

## Focused rerun on the PR #67 merge SHA

The unchanged [B5 scene proof](../../m4_05_playable_scene_proof.gd) ran after import on `fd1d00d7a63603d637f900730927a6a59e01f675` with Godot `4.7.2.stable.official.ed1daf0bf`. Expected 1,521 checks, zero failures and no unexpected engine errors. Observed **1,521 checks, 0 failures, exit 0, 0 unexpected errors**. The proof instantiates the real B5 scene, exercises its signals and advances the real Tween in 1/60-second steps. It is controlled scene evidence.

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
EVIDENCE=tests/combat/evidence/m4-05c
"$GODOT_BIN" --headless --path . --log-file "$EVIDENCE/logs/b5-proof-engine.log" \
  --script res://tests/combat/m4_05_playable_scene_proof.gd \
  -- --report="$EVIDENCE/b5-proof.json" > "$EVIDENCE/logs/b5-proof-console.log" 2>&1
```

[Raw report ZIP](b5-proof.zip) contains the original `b5-proof.json`, including all checks and 18 traces. [Unaltered console and engine logs](engine-logs.zip) · [Hash and command manifest](run.json). Use `traces[scenario].events`, `.root.journal`, `.root.receipts`, `.previous_events` and `.restart_audit` as applicable. Event revision is the committed post-revision. Use generation and action ID together within the same session. A Receipt belongs to the completion event; a Journal row retains the actual operation and publication revision.

| §31 event / case | Authenticated trace | GUI correlation |
|---|---|---|
| INTENT → IMPACT → COMPLETION | `real-input-and-round`: action 1 locks at revision 8, applies the Player-selected Attack to B at rev9 (−5), completes at rev10 with receipt. NPC actions and two counters follow in order. | In a separate GUI run Player chose A; visible intent, flash and HP−5 preceded completion. [Impact](screens/b5-impact.jpg) |
| RESCUE, HELP and RETREAT | `rescue` action 1 rev4 restores Player HP1 and spends NPC1 RESCUE 1→0 after the Player's unavailable slot. `help-guard-retreat` rev7/10 apply HELP +4 and debit different helpers; rev13 commits ordinary NPC3 retreat. | Default GUI proved rescue of NPC3 and its later ordinary retreat. Actual Player rescue and HELP remained in the controlled proof. [NPC3 restored](screens/b5-npc3-rescue.jpg) · [NPC3 retreat](screens/b5-npc3-retreat.jpg) |
| TERMINAL shares IMPACT publication | `victory-impact-enemy_a`: action20 INTENT rev81 → IMPACT rev82 → TERMINAL rev82, 19 existing receipts. `victory-settled-enemy_a`: COMPLETION rev83, receipt20, frozen outcome unchanged. The opposite kill order is interrupted in `terminal-causal-lane` with old impact retained in the audit. | GUI action24, independent playthrough, shows HP0 and VICTORY before its later completion line. [Impact](screens/b5-victory-impact.jpg) · [Complete](screens/b5-victory-complete.jpg) |
| Real ROUND_CLOSED | `real-input-and-round`: six COMPLETE/receipts followed by SEAL/COMMIT_CLOSE, event rev27 with next round2 PREPARED. `six-close-with-legal-driver-cancels`: COMMIT_CLOSE rev114, round6 CLOSED, no Outcome/TERMINAL. | GUI saw grace 2→2, 2→1, 1→0 and natural stop without defeat/victory. [Clock](screens/b5-npc2-dead.jpg) · [Exhaustion](screens/b5-exhaustion.jpg) |
| RESET provenance | `post-impact`: G5/R1/rev0, sole event RESET, no new journal/receipt; `restart_audit` retains old APPLIED action without receipt. Windup, before-lock, terminal causal lane, terminal settled and post-exhaustion covered. Checks verify canceled Tween and inert old callbacks. Rejected Restart during windup leaves the pending callback able to complete once. | GUI reset sampled after impact and after exhaustion. [Old impact](screens/b5-before-in-action-restart.jpg) · [New generation](screens/b5-after-in-action-restart.jpg) |
| E5 failed close | `e5-held`: SEALED at revision21; last Journal operation SEAL, 6 prior receipts and no ROUND_CLOSED. Scene assertions check actual `M405_CLOSE_FAILED` and visible Exit. Direct Restart gives `M405_SEALED_RESTART` with equal old root. `e5-fresh`: different session, G1/rev0 PREPARED, zero events/journal/receipts, old root preserved. | **MANUAL E5 NOT RUN.** Authorized scene harness uses the actual driver fault capability. Public B5 has no fault action. |

The GUI's normal six-Defend run used no development cancellation. The controlled six-close and Last-Party DOWN proof histories use legal pre-impact DRIVER CANCEL. GUI captures show HUD order and effects. The owner trace records come from the focused runner's own sessions.

## Inherited results

PR #67 tested source `6df88c3d8c6dc7d730ffe2e61befefe9f8681439` on the same engine version and SHA-256. B1 86/97/1,907/354, B2 1,031, B3 2,507 and B4 4,238 passed. The reference/canonical/candidate runs recorded 44/94/94 passing stages, Legacy exact equality across six cases and 5,892 frames, and five expected negative diagnostics per run with zero unexpected errors. This task performed fresh import, native GUI checks and focused B5 proof only. Full combat regression and B1–B4 focused suites were inherited. [PR #67 report](../m4-05b/b5/REPORT.md) · [Historical results and commands](../m4-05b/b5/results.json) · [Historical traces](../m4-05b/b5/logs-and-traces.zip)

For authentic Frozen ATTACK after Player re-DOWN and the four Guidance causal relations, use the B3 lifecycle proof's `_rescue_retreat` and `_guidance` in the final B3 runtime record. [Final B3 evidence and commands](../../../actors/evidence/m4-05b/b3/runtime/REPORT.md) · [B4 regression rerun](../../../actors/evidence/m4-05b/b4/REPORT.md)
