# M4-05B B3 runtime candidate — 13 November 2026

**IMPLEMENTED CANDIDATE / AUTOMATED GATES PASS / INDEPENDENT CODE, CONTRACT & EVIDENCE REVIEW PENDING.** ไม่มีการ merge, auto-merge, ลบ branch/worktree หรือเริ่ม B4/B5/M4-05C.

## ฐานและขอบเขต

Canonical/local/live/merge-base ตรง `7f2e3807f18c91416c8380c5b3369711c65cdc5a`; PR #62/#63/#64 merged แล้ว [GitHub preflight](preflight-github.json). Feature `codex/m4-05b-b3-runtime` อยู่ `/private/tmp/wanderer-m4-05b-b3-runtime` แยกจาก checkout เดิมและ worktrees เก่า ไม่มีงาน B3 runtime ซ้ำก่อนเริ่ม. Read-only network check ครั้งแรกติด sandbox DNS; elevated retry ตรวจ SHA ได้ตรงก่อนสร้าง worktree.

เพิ่ม input/Guidance adapters และ lifecycle proof; แก้เฉพาะ `playable_contract`, `playable_decision_adapter`, `playable_effect_rules`, `playable_encounter`, `playable_rules`, README สามไฟล์และ evidence ใหม่นี้. Contract, fixtures/digests, original B1/B2 tests, M403/M404, production Guidance v1/R1, Main/Legacy, scenes และ combat constants คงเดิม. Snapshot import สร้าง UID ให้ไฟล์ B1 เก่าที่ไม่มี UID; เก็บ metadata เหล่านั้นใน archive เท่านั้น ไม่เพิ่มเข้า commit. มี UID ใหม่เฉพาะสอง adapters และ B3 proof.

ใช้ `godot-gdscript` ตรวจ typing/schema/transaction และ `godot-gdscript-headless-testing` ตรวจ runner, exit/error logs และ replay. Worktree ไม่มีชุด skills; อ่านสำเนา `/Applications/wanderer/.agents/skills/` ตามที่ Owner อนุญาต ไม่มีการติดตั้ง/คัดลอก skill หรือเรียก helper ภายนอก. [Hashes และเหตุผล](results.json). Approved Contract มีอำนาจเหนือคำแนะนำทั้งหมด.

## IMPLEMENTED

- Player command และ exact8 Guidance/R1 อยู่ใน single owner เดิม. COMMAND ไม่ปลอม Player; rejected ADMIT ไม่ล้าง command ที่ยังใช้ได้. Pending freeze เฉพาะ admission. NPC Frozen/Profile/observations เป็นของ owner; v1 adapter ส่ง `current_hp` จริง. Decision/relation ถูก derive จาก authenticated lock journal.
- RESCUE/RETREAT ผ่าน policy→LOCK→IMPACT→COMPLETE จริง; ไม่คืน command slot หลัง rescue. แยก HELP/RESCUE resources และ episode retirement/re-DOWN.
- CLOSE_ROUND มีสอง publications จริง SEAL→COMMIT_CLOSE, witness/progress/dispositions และ clock/Guard boundary. หกรอบสูงสุด; exhaustion ไม่ใช่ Outcome.
- Terminal IMPACT commit effect, cleanup และ frozen Outcome พร้อม terminal WAIT_ACTION. เฉพาะ causal COMPLETE เพิ่ม receipt หนึ่งใบแล้ว STOPPED โดยไม่แก้ frozen state หรือสร้าง close/tick. Candidate/replay ตรวจทั้ง root; fault/retry ไม่เพิ่ม effect/receipt ซ้ำ.
- E5 failed-close ถือ SEALED พร้อม diagnostics; no retry/reset bypass. RESTART/new generation และ presentation events ยังไม่ implement.

## VERIFIED

Godot binary `/Applications/Godot.app/Contents/MacOS/Godot`, version **4.7.2.stable.official.ed1daf0bf**. [ทุก command, exit, expected/actual, SHA และ stage record](results.json); [tested source SHA-256](tested-source-sha256.json); [source archive](tested-source.zip); [logs/reports/journals](logs-and-reports.zip); [archive hashes](archive-sha256.json).

| Gate | Actual result |
|---|---|
| Fresh import / parses | PASS; 11 parses; final unexpected errors0 |
| B3 lifecycle | **2,486 assertions / 627 requests / eight named scenarios**, failures0; whole-root replay |
| Original B1 | Smoke86, expanded97, transaction354 PASS; schema **1,907** PASS, all canonical **1,846** labels retained +61 real Decision checks |
| Original B2 | **1,010** PASS; unchanged proof source |
| Historical / canonical / candidate combat | **44 / 94 / 94 stages PASS**; actual runner counts inspected |
| Legacy comparison | **6 cases / 5,892 frames exact equality** across all three runs |
| Negative suite | Exactly five expected errors per regression; unexpected errors0 |

[Coverage manifest](coverage.json) records categories, terminal receipt counts and deferrals. `focused-final2/lifecycle.json` inside the log archive contains actual request/response traces, pre/post canonical root digests and complete final journals/roots. Replays and equality assertions execute on typed in-memory values; JSON is audit output, not an import API. Session IDs may be signed64 negative and must not be round-tripped through a floating-point JSON reader as authority.

Last-Enemy VICTORY executes real Player commands/receipts in rounds1–5 and five closes; round6 B HP2→0 freezes VICTORY at IMPACT. A separate terminal history proves cleanup of a real Player Guard by an NPC kill. Both have one causal COMPLETE and closed_rounds5. Six-natural-close history separately proves Guard expiry, DOWN grace/B1/B0→DEAD, twelve internal entries, honest DEMO_LIMIT_REACHED and round7 rejection.

V2 Last-Party DOWN executes admission targets Player/NPC3/NPC2/NPC2/NPC1/NPC1, real enemy impacts and legitimate skips; independently expected HP/life/episode/clock values are checked at each relevant hit/close. Final Enemy B makes NPC1 HP1→0 in round6, freezes DEFEAT/NO_ACTIVE_PARTY, and preserves NPC2 clockB1 / closed_rounds5 through COMPLETE. No fixture/policy change or live-root injection supplies these histories.

RESCUE restores HP1, retires the real episode and spends only RESCUE; later DOWN has a new ordinal. Ordinary NPC RETREAT retains ID/HP and changes participation. Guidance covers all five types and actual FOLLOWED/MATCHED_INDEPENDENTLY/REFUSED/NOT_APPLICABLE. Terminal and ordinary rejection/fault cases preserve whole root. E5 is the documented compound-operation exception: successful SEAL remains published when COMMIT_CLOSE fails; that failed commit changes no sealed state, HP, receipt or clock.

## Development failures retained

Initial parse before import failed from the missing class cache. An initial long proof run was interrupted (exit130); the candidate now reuses an internal schema table rather than reconstructing every shape at every nested validation. This is not a benchmark PASS.

The next proof found two failed checks and a downstream Nil diagnostic: the pre-existing new-domain adapter built v1 actor dictionaries with `hp`, while the unchanged Layer requires `current_hp`. Corrected only that adapter, preserving actual values. Focused Guidance then passed494 checks; final full proof passes. Logs remain archived.

The first final wrapper expected exactly1,846 schema checks and therefore exited1 although the unchanged Godot schema runner passed1,907. A fresh canonical run passed1,846; a label-multiset audit proves all originals plus61 extra Decision checks. [Full comparison](schema-count-audit.json). The final wrapper expects the measured1,907 and all19 stages pass. Original tests and their assertions were not reduced or edited. Both wrapper versions and results are preserved.

## DEFERRED / HOLD / NOT RUN

- **DEFERRED — OWNER APPROVED:** positive Last-Party RETREAT through real transactions (§30.7). No runtime PASS claimed; classifier/schema/negative replay and ordinary RETREAT remain covered.
- §30.6 separately accepts no positive NO_PLAYER_COMMAND producer under Player-first ordering; real UNAVAILABLE-before-RESCUE is covered.
- **HOLD behavior verified:** failed COMMIT_CLOSE retains genuine SEALED. No unresolved implementation gate is reported; independent code/contract/evidence review and Owner decision are pending.
- **NOT RUN:** GUI, keyboard, visual/pacing, performance benchmarks. B4 presentation/Restart, B5 scene and M4-05C acceptance are separate tasks. Headless startup/Legacy regression is not manual F5/F6 acceptance.
- No legal arbitrary external mid-action mutation producer is added. Existing O7 and capped HELP limitations are not relabelled as new runtime PASS.

## Review / reproducibility

Inspect [scope audit](scope-audit.json), [source hashes](tested-source-sha256.json), replay/frozen roots in the archive and the exact §30 terminal queue relation. Use the commands in results with the source archive or committed source. The tested base plus exact content hashes identify the tested candidate; after committing, delivery-head resolution is linked from the Draft PR to avoid a self-referential SHA. Historical B1/B2 and the seven pre-runtime B3 evidence files are preserved verbatim. Stop at Draft PR for Independent Review and Owner decision.
