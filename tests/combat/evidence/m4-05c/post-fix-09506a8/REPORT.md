# M4-05C — post-fix acceptance and verification pack

**Disposition: HOLD for §24.1 closure. OWNER ACCEPTANCE PENDING.** The fresh keyboard results support lifting the original C-01/C-02 defect HOLD at the tested scope. This pack is for Independent Evidence & GUI Review; production F5 cutover is **NOT AUTHORIZED**.

**14 November 2026 (Asia/Bangkok).** [PR #67](https://github.com/shanwinder/wanderer/pull/67) merged at `fd1d00d7a63603d637f900730927a6a59e01f675`; [PR #69](https://github.com/shanwinder/wanderer/pull/69) squash merged at `09506a822a7e6e600727f7bec70119bc2153f2a7`. Required SHA, local HEAD, origin tracking ref and live GitHub branch agreed. [PR #69 Technical Review PASS](https://github.com/shanwinder/wanderer/pull/69#pullrequestreview-5899421295) was a COMMENT review of submitted evidence; the runs below are new on the merged source. Preflight found three open Draft PRs (#2, #17 and #68); only #68 is in scope. Its prior head `bfab1224df330df6d980da6c4ba225e9c89cb907` contains the pre-fix record. Two README conflicts were resolved in isolated preparation using canonical text plus the refreshed status. Historical evidence from both branches is byte-preserved and no runtime path differs from canonical.

[Updated P05-01–26 matrix](MATRIX.md) · [Native GUI interaction sequences](GUI.md) · [เช็กลิสต์ภาษาไทยสำหรับ Owner](OWNER.md) · [Benchmark assessment](PERFORMANCE.md) · [Raw logs, exits, results, journals and manifests](run-evidence.zip) · [Keyboard assertions and observations](keyboard.json) · [Artifact checksums](SHA256SUMS)

## Original failures and fresh evidence

| Finding | Pre-fix failure on PR #67 merge SHA | PR #69 correction | Fresh result on merged canonical |
|---|---|---|---|
| C-01 | Read-only TextEdit trapped Tab/Shift+Tab at victory. Log occupied space by default. | Hidden-by-default ScrollContainer and wrapping Label; visible toggle, explicit focus links and paging. Review measured header 210→124px and roster 87px higher. | **VERIFIED — ACTUAL GUI** for hidden/readable layout, L/Esc, genuine scroll, forward/reverse traversal, history retention and terminal Restart. **VERIFIED — AUTOMATED** for E5 Exit while held. |
| C-02 | A second Enter on Attack could activate Restart during the queue. | After acceptance, focus goes to non-activating BattleStatus; Restart requires deliberate focus or click. | **VERIFIED — ACTUAL GUI** for all four Enter/Space pairs, a held-key interaction, visible BattleStatus, next-round target and deliberate keyboard/mouse resets. **VERIFIED — AUTOMATED** for actual key echo, stable owner snapshot under repeat, exactly one command/impact/receipt, and phase-specific restart. |
| C-03 | VICTORY reason exposed an internal code. | Outside PR #69 scope. | Still seen in actual expanded terminal log: `M403_ENEMIES_UNAVAILABLE`. Minor; Owner decides whether to keep or display “ชนะเพราะไม่มีศัตรูที่สู้ต่อได้” with the original code retained in diagnostics. |

[Original findings and captures](../FINDINGS.md) · [PR #69 submitted correction evidence](../hud-keyboard-fix/REPORT.md). Native GUI also sampled B5 motion and return, NPC choice and lifecycle, Guard, victory and six-round exhaustion, plus F5 and Legacy. The same runs distinguished DOWN (timer), DEAD (dimmed), RETREAT (sprite absent with retained HP/status) and RESCUE (+1/standing). The archived native engine logs and interaction sequences support the sampled claims; standalone GUI captures were viewed during testing but are not exported here. Exact 44 px, phase timing in the proof and formation at rest are automated checks. Calibrated native timing and several seeded paths are **NOT RUN**; see the matrix.

## Regression on Godot 4.7.2

Actual binary: `/Applications/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official.ed1daf0bf`, SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

| Fresh run | Expected and actual | Basis |
|---|---|---|
| B1 Smoke / Expanded / Schema / Transaction | **86 / 97 / 1,907 / 354** checks, exit 0 | Smoke harness byte-matched the historical archive; expanded ran with committed runner; schema `--gate=D`, transaction `--gate=E`. Initial harness selection returned the expanded 97 and was retained separately. |
| B2 Effects | **1,031** checks; 0 failures | Separate B2 proof. |
| B3 Lifecycle | **2,507** checks / 630 transactions, 0 failures | Separate B3 proof. |
| B4 Presentation / Restart | **4,238** checks / 474 transactions / 28 streams, 0 failures | Separate B4 proof. |
| B5 Scene / B5 Keyboard | **1,521** checks / 18 traces and **81** checks, all pass | Imported/parsed merged B5, standalone headless startup, real scene and focused keyboard proof. |
| Reference / Canonical / Candidate | **44/44, 94/94, 94/94**, exit 0, no timeouts | Reference `1728c5e678c5065278d1251d50449a8820eb5dae`; canonical and candidate are independent clean runs of the identical merged source `09506a8` (evidence branch has no runtime delta). |
| Legacy | Six cases, **5,892 frames byte identical** across all three | Trace SHA-256 `cf1b4874c4538b96af5976e11a0431a7ae5308c09eebdafaacc5a11ece37cba6`. |

Successful reruns: zero unexpected engine errors. Five expected negative diagnostics **per full regression** in `invalid-actions`: 1 “ไม่มี Action ถัดไปหลัง NPC”, 1 “ลำดับ Action ไม่ถูกต้อง”, 3 “ยังไม่พร้อมเปลี่ยน Action”. Counts are assertions, not independent scenarios. The failed sandbox preflight had an unexpected macOS CA lookup error in import despite Godot exit 0; retained as a failed attempt, corrected by rerunning with native OS access in fresh outputs. Subsequent native import, GUI windows and regressions had zero such errors. A rejected request prefix in the discarded benchmark harness attempt is recorded separately; corrected harness used the existing authorized request syntax, without editing runtime.

The archive contains `regression/commands.json`, per-stage commands/results, stdout/engine logs/exits, source manifests, and `focused/results.json`. Regression and main focused wrapper used a 300 s timeout per stage (no timeout fired); the original Smoke rerun used its existing short harness without an additional per-process timeout. Reference trace content matches the two merged-source copies exactly.

## E5 — failed SEALED close

**VERIFIED — AUTOMATED.** The existing safe keyboard proof calls `inject_failure_before_close_commit` using the proper driver capability. The proof holds the same immutable root after a real seal and rejected Restart (`M405_SEALED_RESTART`), then uses Tab to bypass disabled Restart, selects Exit with Space, and verifies a different factory session ID, generation 1, revision 0, empty journal and receipts, and an inert old callback. The separate B5 Scene proof preserved `e5-held` (`SEALED`, journal 21) and `e5-fresh` (`PREPARED`, journal 0) in `focused/b5.json`. The final keyboard observation records the retained old-owner handle before the proof reacquires the controller's new owner; the explicit final assertion and separate B5 roots verify the new identity.

**MANUAL E5 NOT RUN.** Normal B5 has no fault trigger. The approved committed proof injects and steps close and keys internally; no approved separate native interactive harness with wall-clock play was identified. Do not reinterpret the headless keyboard path as operating native GUI, or add a fault control or SEALED bypass.

## Remaining gates

- **§24.1 — BLOCKED** for the independently reviewed worst-legal workload; complete catalog, stress and GUI campaigns **NOT RUN**. Discovery preserved five fixture results and a separate cold sample. Longest observed legal journal was 123 entries across six closes; its replay was 1,317.053 ms in that one discovery sample. This is not a formal p95 or proof of a legal maximum.
- Independent Evidence & GUI Review should check native focus/readability and trace scope. The Owner then decides C-03, whether native E5 needs an approved development harness, and whether the remaining sampled GUI/fixture limits satisfy their acceptance needs. Player DOWN/RESCUE, actual HELP and DEFEAT lacked native samples; corresponding authenticated proofs are preserved.
- Positive pre-slot `NO_PLAYER_COMMAND` (§30.6) and positive Last-Party RETREAT (§30.7) remain **DEFERRED — OWNER APPROVED**. No contract change, no gameplay change and no promotion to default F5.
