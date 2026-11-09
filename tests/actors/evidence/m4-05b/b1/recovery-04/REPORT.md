# M4-05B B1 Recovery-04 — HOLD

วันที่ 10 พฤศจิกายน 2026 (Asia/Bangkok). หยุดตาม Owner Mandatory Stop; **ยังไม่ผ่าน B1 Acceptance, ไม่ commit/push/เปิด Draft PR**. ไม่มี merge/auto-merge/ลบ branch หรือเริ่ม B2–B5/M4-05C.

Gate F พบ assertion failure บน canonical snapshot. สาเหตุจากคำสั่ง baseline ของ agent ที่เรียก `--autonomous-main-proof` แต่ไม่เข้าโหมดที่ส่ง `--expect-autonomous-default`: harness จึงคาดหวัง Legacy ขณะที่ canonical ใช้ Autonomous. เป็นความผิดพลาดในการจัดคำสั่งทดสอบของ agent ไม่ใช่หลักฐานว่า B1 ทำให้ gameplay regression. หยุดโดยไม่แก้ protected test/config หรือ rerun เพื่อกลบ failure. [ผลรวม machine-readable](results.json), [failed engine log](F/canonical44/autonomous-main-proof.engine.log), [failed stage record](F/canonical44/results.json).

## Canonical และ preservation

- PR #59 MERGED ที่ `295dac9211486a4c2d3c5c5fa43baf065398e6a7`; Independent Review COMMENT/PASS ตรวจจาก GitHub จริง: [preflight metadata/review](github-preflight.json).
- Branch เดิม `codex/m4-05b-b1-single-authority-proof`; HEAD และ merge-base ปัจจุบันตรง canonical SHA ข้างต้น. ก่อนเริ่ม HEAD/remote-tracking เดิม `df04052cc8bf0d17510b55e75f3b357e7da9c00f`; live remote เป็น SHA ใหม่. ไม่พบ B1 runtime PR หรือ branch ซ้ำ; branch amendment #59 เป็นงานเอกสารคนละงาน.
- ก่อน fetch/fast-forward สำรอง worktree ทั้ง **631 files = tracked471 + untracked120 + ignored40**, ตรวจ hashes ของสำเนาครบ. สำรองอยู่นอก worktree: `/private/tmp/wanderer-b1-pre59-preservation-bcstuzsp`. [Inventory](preservation/manifest.json), [summary](preservation/summary.json), [Recovery-02/03 hash comparisons122/122](preservation/historical-hash-checks.json).
- ยืนยัน ancestor/ahead0-behind1, ไม่มี tracked edits และไม่มี untracked/ignored collision ก่อน `git fetch origin` / `git merge --ff-only origin/visual-combat-test-1`. Incoming changes เฉพาะ contract/index สองไฟล์; §28 มีอยู่จริง. [Post-FF:629/629 hashes unchanged](preservation/post-fast-forward.json).
- Final audit: **114 original evidence files และ40 ignored files ไม่เปลี่ยน; ไม่มีไฟล์สูญหาย**. Original parse failure, Recovery-01/02/03, manifests และ96/97 FAIL อยู่ครบ ไม่แก้ย้อนหลัง. [Final hash/protected audit](preservation/final-audit.json).

## Exact changed-file allowlist

Draft source ทั้งหกยัง untracked บน branch เดิม. Recovery นี้แก้เฉพาะ:

1. `scripts/m4/playable_contract.gd`
2. `scripts/m4/playable_rules.gd`
3. `scripts/m4/playable_encounter.gd`
4. `tests/actors/m4_05_playable_authority_proof.gd`

`playable_decision_adapter.gd` และ `playable_fixture_catalog.gd` เดิมไม่เปลี่ยน hash. เพิ่ม evidence เฉพาะ `tests/actors/evidence/m4-05b/b1/recovery-04/`; รายชื่อทุกไฟล์และ SHA-256 อยู่ใน [evidence manifest](evidence-sha256.json), [allowlist](changed-file-allowlist.json). เอกสารสองไฟล์เปลี่ยนเฉพาะจาก canonical fast-forward ไม่ใช่ local edits. Tracked diff เทียบ canonical ใหม่ว่าง; F5/F6, M403/M404, Guidance v1/R1, existing tests, `project.godot`, balance/formation/movement/pacing ไม่เปลี่ยน. `git diff --check` ผ่าน.

## Root cause 96/97 และ §28 implementation

Validator เดิมใช้ `Effect.reason = S` และตรวจ catalog เฉพาะ outer Response. SC09 เปลี่ยน nested reason เป็น `M405_FORGED_UNKNOWN_REASON` แล้วยังผ่าน. §28 ที่ merge แล้วทำให้ exact binding ชัดเจน; ไม่อ้างว่า source convention เดิมคือ approval. Original adversarial function/SC09 expectation byte-identical.

Named recursive `Effect` validation ใช้ status-specific catalog ของ IMPACT ทั้งหกคู่; unknown/empty/null/wrong-type/wrong-domain reasons และ wrong status pair ถูกปฏิเสธ. Successful IMPACT ต้องมี inner/outer status และ reason เท่ากัน. ทุก nonnull Effect ใน Response, ActionGrant, PresentationEvent และ Root ผ่าน validator เดียวกัน. SKIPPED ต้อง delta0 และ resource/guard/lifecycle arrays ว่าง. Nested rows ตรวจ exact keys/types/enums, resource decrement, Guard provenance shape, lifecycle transitions และ duplicate actor projection.

`Rules.impact_projection_valid` ตรวจ B1 ATTACK ที่ authorize จริง, token/target/damage, actual HP delta, lifecycle projection, unchanged resources/receipts และ stored grant เทียบ before/after. `candidate_valid` ตรวจ response/view กับ candidate. Owner เรียกก่อน root swap; replay เรียกกฎเดียวกันทุก operation แล้วเทียบ full Root. ไม่เพิ่ม wire field/reason หรือ effect producer ของ B2–B5. COMPLETE ยังคง `COMPLETED/M405_ACTION_COMPLETED`, effect=null, stored impact effect เดิม และออก receipt ครั้งเดียว.

## Verification ที่ทำจริง

Binary: `/Applications/Godot.app/Contents/MacOS/Godot`
Version: **4.7.2.stable.official.ed1daf0bf**
Binary SHA-256: `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`
Context: `macOS-27.0.1-arm64-arm-64bit` / `arm64`, approved unsandboxed exec/headless ตาม Recovery-02; ไม่ใช่ GUI Terminal. Runtime ทุก run ใช้ fresh disposable snapshot/output; worktree `.godot` ไม่ถูกใช้หรือเปลี่ยน.

Tested Git base คือ `295dac9211486a4c2d3c5c5fa43baf065398e6a7` **พร้อม uncommitted drafts** ไม่ใช่ claim ว่า merged SHA มี B1 runtime แล้ว. Exact tested source hashes/archive อยู่ในแต่ละ gate; final source ตรง ABC-final/D/E ครบหกไฟล์. [Context](E/context.json), [source manifest](E/source-sha256.json), [tested source ZIP](E/tested-source.zip).

| Gate | Expected | Actual / exit | Evidence |
|---|---|---|---|
| A Import/parse | Import + B1 scripts5, errors0 | PASS, exits0, errors0 | [ABC-final results/commands](ABC-final/results.json) |
| B Original smoke |86/86 unchanged assertions|86/86, exit0, clean logs|[smoke report](ABC-final/B-original-smoke-report.json)|
| C Original expanded |97/97 including original SC09|97/97, exit0, clean logs|[expanded report](ABC-final/C-original-expanded-report.json)|
| D Executed schema matrix |All asserted negatives reject|777/777, exit0, errors0; includes97 original +680 new|[D report](D/D-report.json), [commands/log exits](D/results.json)|
| E Executed transaction/replay matrix |Real effects/receipt once; invalid candidates no mutation|262/262, exit0, errors0; includes97 original +165 new|[E report](E/E-report.json), [commands/log exits](E/results.json)|
| F Existing regression |All baseline/candidate stages pass|**FAIL/INCOMPLETE**;10/11 completed baseline stages pass, Autonomous assertion exit1; candidate NOT RUN|[F run commands](F/run-record.json), [stage results](F/canonical44/results.json)|

D ตรวจ34 record shapes ที่ได้จาก genuine operations และ pure fixtures: missing/extra/wrong types/bool-as-int, six reason pairs, outer/inner mismatch, invalid SKIPPED deltas และ forged APPLIED projection/root. เป็น scoped executed matrix ไม่ใช่คำรับรองว่า record/semantic combinations ทุกชุดของ B1–B5 ครบถ้วน.

E เก็บ request/response/before/after roots จริง, APPLIED และ TARGET_UNAVAILABLE SKIPPED จริง, no receipt at IMPACT, receipt/status และ preserved effect ที่ COMPLETE, duplicate IMPACT/COMPLETE/request, capability/forged token/foreign session rejection, detached snapshots, nine candidate poison cases, final seam fault, root mutations และ journal digest rejection. Fault subclass เปลี่ยนเฉพาะ detached candidate ก่อน validation; ไม่ inject live `_root` และไม่อ้าง O7 producer. Rejected cases เทียบ **full root** รวม HP/resources/Guard/revision/journal/receipts.

Commands ที่รัน: `python3 /private/tmp/wanderer_b1_recovery04.py ABC-final`, mode `D`, mode `E` ตามลำดับ; runner ที่ใช้จริงอยู่ใน [runner.py](runner.py). ทุก subprocess command/exits/logs อยู่ใน results ของ gate. Smoke ใช้ harness86 เดิมจาก archived Recovery-01 ZIP พร้อม hash; expanded/default97 ไม่ลด assertions. [Initial intermediate A–C PASS](ABC/results.json) เก็บแยก ไม่เขียนทับ final-source evidence.

Gate F wrapper: `python3 /private/tmp/wanderer_b1_regression04.py`; [executed script](regression-runner.py). สร้าง canonical snapshot จาก `git archive` ของ SHA ที่กำหนดและใช้ unchanged `tests/combat/verify.py`. Failure: **787617 checks /1 failure**, `explicit expected project default`; unexpected engine errors0. Wrapper ตรวจพบ FAIL แล้ว terminate verifier: verifier exit **-15**, wrapper exit **1**; Godot failed stage exit **1**. เก็บ `gameplay.engine.log` ที่อาจเริ่มทันก่อน terminate ไว้ด้วย แต่ไม่มี completed stage result จึง **ไม่อ้าง PASS**. Negative five-error suite และcandidate94ยัง NOT RUN. ไม่มี trace equivalence/full combat PASS ใหม่.

## Remaining limits / Independent Review Checklist

- [ ] Review §28 recursive validation + actual-root projection และ candidate publication seam; automated PASS ไม่ใช่ Independent Acceptance.
- [ ] Review Gate F command plan ให้ตรง current Autonomous default โดยคง protected verifier/tests/config; failure นี้เป็น invocation mismatch ของ agent ไม่ใช่พิสูจน์ B1 regression. ต้องได้รับคำสั่ง recovery ต่อก่อน rerun หลัง Mandatory Stop.
- [ ] ตรวจ static concern เพิ่มเติม: draft Bootstrap/RestartPayload ใช้ `fixture_version:positive` แต่ corrected contract ระบุ `I=1`; ยังไม่มี focused runtime probe หรือการแก้หลัง HOLD. ไม่อ้าง complete recursive-schema acceptance.
- [ ] Review coverage completeness:34 schema shapes ที่รันไม่ครอบคลุมทุก deferred private record. ห้ามตีความ total assertion counts เป็น independent cases หรือ full B1 Acceptance.
- [ ] อีก4 SKIPPED reasons (ACTOR_UNAVAILABLE/EPISODE_CHANGED/RESOURCE_UNAVAILABLE/HELP_NO_HEAL) ทดสอบ pure schema เท่านั้น; ไม่มี legal B1 producer ที่อ้างว่า implement แล้ว. PresentationEvent เป็น pure fixture ไม่ใช่ B4 emitter.
- [ ] Complete existing regression/negative tests, exact source audit และ evidence หลัง recovery ที่ได้รับอนุญาต; retain this failed run unchanged.
- [ ] ตรวจ original evidence114 files และ external backup hashes. ไม่มี reset/clean/stash drop/rebase/cherry-pick/force checkout.
- [ ] B2 HELP/Guard, B3 Guidance/rounds, B4 terminal/Restart/presentation, B5 scene, M4-05C, GUI/F5/F6 visual/keyboard acceptance และperformance benchmark **NOT RUN/NOT IMPLEMENTED ในงานนี้**. ไม่เปลี่ยน historical evidence ให้เป็นผลใหม่.

**Mandatory stop: HOLD รอ Independent Review.** Source/evidence ทั้งหมดคงอยู่ branch เดิมและยังไม่ commit. ไม่มี Draft PR เพราะ acceptance ไม่ครบ.
