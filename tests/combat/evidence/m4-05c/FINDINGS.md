# Findings and proposed corrections

**Agent recommendation — HOLD for correction.** Independent review and the Owner’s decision remain pending. Source inspection identifies likely UI causes. Proposed changes require separate authorization.

## C-01 — BLOCKER — Battle log traps focus

- **Scenario and evidence.** P05-21, P05-14. Complete a battle, Tab from Restart into the read-only log, Page Up, then try Tab, Shift+Tab and Escape. [Tab capture](screens/b5-log-tab-trapped.jpg) · [Shift+Tab capture](screens/b5-log-shift-tab-trapped.jpg) · [Mouse recovery](screens/b5-after-victory-restart.jpg)
- **Expected / actual.** Full reasons remain keyboard-readable and both directions lead back to usable controls. Page Up reads history. The focus border remains on the log after both Tab directions and Restart cannot be reached using those tested keys. Clicking Restart recovers.
- **Likely cause.** The focusable read-only `TextEdit` consumes Tab navigation. The HUD has no explicit exit path for its handled key events. [HUD source](../../../../scripts/combat/m4_playable_presentation_adapter.gd)
- **Minimal correction and files.** In the B5 HUD adapter, allow normal forward/reverse focus navigation at the log boundary or use a focusable read-only log control that preserves Page Up/Down and supports both directions. Keep Restart and diagnostic Exit as valid neighbors when those are the only actions.
- **Regression and decision.** Approve the B5 HUD correction separately. Recheck real keyboard traversal at prepared, NPC DOWN, active, terminal, exhaustion and approved held states. Include a focused keyboard regression and run the existing focused B5 and full combat suites. Verify old reasons and Reset/Exit behavior.

## C-02 — BLOCKER — A second Enter on Attack restarts the battle

- **Scenario and evidence.** P05-14, P05-21. From initial target focus Tab to Attack, then press Enter twice quickly. Reproduced with and without Focus B submitted. [Attack focused](screens/b5-attack-ready.jpg) · [First reset](screens/b5-double-enter-first.jpg) · [Repeated reset](screens/b5-double-enter-repeat.jpg)
- **Expected / actual.** Extra activation during command lock leaves the accepted round running. The second Enter resets to round 1/new generation. Separate single Enter shows damage and a visible Restart focus during the queue. The extra key produced a reset rather than a second Player action. [After single Enter](screens/b5-impact.jpg)
- **Likely cause.** HUD hides the focused command on acceptance and immediately focuses Restart when the focus owner becomes null. The next `ui_accept` hits the newly focused button. [HUD source](../../../../scripts/combat/m4_playable_presentation_adapter.gd)
- **Minimal correction and files.** Land post-command focus on a stable, non-activating battle-status/log control with an explicit Tab route to Restart, or require deliberate focus navigation to arm Restart after command focus disappears. Keep intentional Restart available at approved phases. Coordinate C-01 in the same B5 HUD adapter and keep owner transaction behavior intact.
- **Regression and decision.** Approve B5 HUD work separately. Recheck rapid Enter/Space and key repeat, intentional Restart by keyboard at each phase, no duplicate command/receipt, no stale callbacks, next-round focus and the existing focused/full suites.

## C-03 — MINOR — VICTORY reason exposes an internal code

- **Scenario and evidence.** P05-08. Final impact shows “ชัยชนะ / VICTORY” and both enemies unavailable. The reason line renders `M403_ENEMIES_UNAVAILABLE` inside brackets. [Terminal frame](screens/b5-victory-impact.jpg)
- **Expected / actual.** Owner should be able to explain why the encounter ended. The result is clear and the roster corroborates it. The cause line itself requires interpreting the raw code or inferring it from the roster.
- **Cause and minimal correction.** The B5 HUD translates the outcome result and formats the raw reason. If Owner confirms confusion, map the existing reason enum to a short Thai explanation in the B5 presentation adapter or existing message catalog. Preserve underlying terminal record and evidence.
- **Regression and decision.** Owner can accept as a limitation or request the small display change. Check all approved results against authentic reason values, long Thai text at 1280×720 and the terminal event sequence.

Legacy's narrow bottom log showed a partially clipped older line in sampled captures. Its current line, Guard cue and controls remained legible in the sampled run. Legacy presentation is outside the proposed B5 fixes. Positive Last-Party RETREAT and the unreachable pre-slot `NO_PLAYER_COMMAND` positive path retain their §30.7 and §30.6 deferrals. Manual E5 and the §24.1 benchmark remain unrun gates.
