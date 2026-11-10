# M4-05B B1 Recovery-05 — automated gates PASS, independent review pending

วันที่ 10 พฤศจิกายน 2026 (Asia/Bangkok). **แก้ปัญหา B1 และผ่าน Gates A–F แล้ว** ในขอบเขต Single Authority/API and Schema Recovery. ยังไม่ใช่ Owner Acceptance/Independent Review PASS และไม่ใช่ Full M4 playable integration. งานหยุดที่ Draft PR ตามคำสั่งเดิม; ไม่ merge/auto-merge/ลบ branch/เริ่ม B2–B5 หรือ M4-05C.

Owner สั่งต่อหลัง Recovery-04: “วิเคราะห์ ตรวจสอบ วินิจฉัยปัญหาอย่างละเอียด แล้วจงแก้ไขปัญหา B1 ให้ผ่านจงได้” และ “ทำงานต่อให้สำเร็จ”. ใช้คำสั่งนี้แก้ execution plan และ B1 validator/test ต่อ โดยคงขอบเขต protected files และ failed evidence เดิมทั้งหมด.

## 1. Canonical, B1 HEAD และ preservation

Canonical / merge-base: `295dac9211486a4c2d3c5c5fa43baf065398e6a7` (PR #59 squash merge); branch เดิม `codex/m4-05b-b1-single-authority-proof`. ตรวจ live remote แล้วยังตรง SHA นี้และไม่พบ B1 runtime PR/branch ซ้ำ. Recovery-04 fast-forward ที่ปลอดภัยยังคงเดิม ไม่มี rebase/reset/clean/cherry-pick/force checkout. [GitHub merge/review evidence](../recovery-04/github-preflight.json).

ขณะรันทดสอบ HEAD คือ canonical ข้างต้นพร้อม uncommitted B1 source. **ไม่อ้างว่า canonical commit มี B1 runtime อยู่แล้ว**. Source manifest/ZIP ระบุ bytes ที่ทดสอบจริงทุกไฟล์; commit source หลัง gates ผ่านตาม Owner instruction. B1 implementation HEAD คือ `a07bca91ca7b01651010c8733ea3e0eee0e76b84`; วิธีผูก tested bytes กับ delivery อยู่ใน [delivery-head resolution](delivery-head-resolution.json). PR HEAD อาจมี evidence-only commit ตามหลัง; ดู diff และ manifest แทนการอ้างว่า test เกิดบน SHA ที่ยังไม่สร้าง.

ก่อนแก้รอบนี้ตรวจ Recovery-04 evidence manifest211 entries และ source6 hashes ตรงทั้งหมด แล้วสำรอง **843 files** นอก worktreeที่ `/private/tmp/wanderer-b1-r05-preservation-f2sbjopj` พร้อมตรวจ SHA-256 ทุกสำเนา. [Inventory](preservation/manifest.json), [preflight context](preservation/context.json). Backup ก่อน PR59 integration เดิมยังอยู่ `/private/tmp/wanderer-b1-pre59-preservation-bcstuzsp`.

Original Parse Failure, Recovery-01/02/03 รวม96/97 FAIL, Recovery-04 และ source archives ไม่เขียนทับ/ลบ/เปลี่ยนผลย้อนหลัง. [Final source/protected preservation audit](final-audit.json), [source manifests](source-audit.json), [evidence inventory](evidence-sha256.json).

## 2. Diagnosis และการแก้

| Finding | พิสูจน์สาเหตุ | การแก้และหลักฐาน |
|---|---|---|
| SC09 unknown nested reason (Recovery-02:96/97) | เดิม Effect.reason เป็นเพียง nonempty string ขณะที่ outer Response ตรวจ closed catalog; §28 ทำ binding ชัดเจนภายหลัง | รักษา fix Recovery-04: recursive status-specific six-pair catalog + inner/outer equality เฉพาะ successful IMPACT; original SC09 expectation/function ไม่เปลี่ยน; C97/97 |
| Recovery-04 Gate F failure | `verify.py` ส่ง `--expect-autonomous-default` เฉพาะโหมด `--main-cutover-proof`; agent รัน canonical Autonomous ด้วย pre-cutover baseline mode จึง fail `explicit expected project default` | แก้ **คำสั่ง/แหล่ง baseline**: fresh historical pre-cutover reference `1728c5e678c5065278d1251d50449a8820eb5dae` 44 stages; fresh current canonical/candidate ใช้ current cutover flags94 stages. ไม่แก้ protected test, assertion, default scene หรือ gameplay constant |
| fixture_version ใช้ positive แทน exact1 | focused diagnostic พบ Bootstrap และ RestartPayload ยอมรับ2/999 ที่ระดับ schema; factoryอาจปฏิเสธภายหลังด้วยเหตุอื่น แต่ recursive contract/precedenceไม่ตรง | เปลี่ยนสอง schema เป็น strict integer enum `[1]` เช่น SeedReference เดิม; ทดสอบ0/-1/2/999/bool/float/string/null ทั้ง pure และ real API; invalid bootstrapไม่ publish, invalid nested Restartปฏิเสธก่อน deferred lifecycle |
| Outbound receipt ไม่ผูกกับ candidate เต็มชุด | focused diagnostic เปลี่ยน authorization_id ของ COMPLETE.response.receipt ในสำเนา โดยคง valid Root/view; candidate_valid เดิมยังรับได้. เป็น validator fault probe ไม่ใช่ข้ออ้างว่า callerเคย import/ได้ fake receipt ใน live runtime | candidate_valid เทียบ **ทั้ง result.root และ result.response** กับ pure deterministic step จาก prior root/requestจริง; จึงครอบคลุม lock token และ COMPLETE receipt ไม่ใช่เพียง shape. ยังตรวจ actual IMPACT projection และ full root replayก่อน atomic swap |

เก็บ pre-fix run **DIAG102 checks /5 failures /exit1**, clean engine logs: [diagnostic report](DIAG/DIAG-report.json), [commands/results](DIAG/results.json). สี่ failure คือ Bootstrap/RestartPayload version2/999 และอีกหนึ่งคือ forged outbound receipt. Assertionทั้งห้ายังคงอยู่และผ่านใน final Gate D. ไม่มีการแก้ expectedผลเพื่อให้ PASS.

เพิ่ม relational validation ตาม contractเดิม: BootstrapReply status/reason/view, non-ATTACK token amount0 และRESCUE episode binding, Receipt completionหลังimpact, ActionGrant effect/revision/disposalตามphase, PresentationEvent effect/receipt placement, JournalEntry external/internal exclusivityและrevision, InternalClose.origin=CLOSE_ROUND. ไม่เพิ่ม wire fields, reason codes, fixture content/version หรือ gameplay producer.

## 3. Single authority / §28 / atomicity / replay

`playable_encounter.gd` ถือ live `_root` เพียงชุดเดียว; factory/input/driver/presenter ใช้ object capabilityจริง ไม่ใช่ serialized issuer string. Rules/Contract/Catalog/DecisionAdapter เป็น pure computations/detached candidates. ไม่มี second Encounter/registry synchronization และไม่มี Root/Effect/Receipt import API. GDScript underscore/capability handles เป็น trusted in-process API boundary ไม่ใช่ sandboxป้องกัน hostile script ที่เข้าถึง private internals.

Effect ทุกตำแหน่งใช้ recursive validatorเดียวกัน: successful IMPACT Response, stored ActionGrant, PresentationEvent และ reconstructed Root. APPLIED/APPLIED ใช้ M405_EFFECT_APPLIED; SKIPPED/SKIPPED ใช้ห้าเหตุที่อนุมัติ. Inner/outer reasonและstatusตรงกันเฉพาะ IMPACT; reject arbitrary/empty/null/wrong-type/domain/wrong-pair. SKIPPED delta0/listsว่าง. APPLIED ตรวจ authorized ATTACK, target/damage/HP/lifecycle/resources/receipt เทียบ before/afterจริง ไม่เชื่อ reasonอย่างเดียว.

COMPLETE ยังคง `COMPLETED/M405_ACTION_COMPLETED`, effect=null; เก็บ impact effectเดิมและออก genuine receiptหนึ่งครั้ง. Full result bindingป้องกัน corrupted outbound token/receiptที่ไม่มีผลใน rootจริง. Journalเก็บ operation/request ไม่รับ caller-authored effect; replayเริ่ม immutable seed, reconstructผลเดิม, validate nested recordsและcompare full candidateก่อน synchronous root swap. Failureไม่ publish HP/resources/Guard/receipt/revision/journalแม้แต่บางส่วน.

## 4. Verification — fresh engine evidence

Binary `/Applications/Godot.app/Contents/MacOS/Godot`, version **4.7.2.stable.official.ed1daf0bf**; SHA-256 `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`. `macOS-27.0.1-arm64-arm-64bit` / `arm64`. ใช้ approved unsandboxed headless executionตาม environmentที่ Recovery-02ตรวจแล้ว; ไม่ใช่ GUI Terminal และไม่เปลี่ยนระบบ certificate/security. ทุก runมี fresh snapshot/output, stdout/stderr/engine logs, exitและcommand. [Context](E/context.json).

| Gate | Expected | Actual | Evidence |
|---|---|---|---|
| A |import+parse five B1 scripts; unexpected errors0|PASS / exits0|[ABC commands/results](ABC/results.json)|
| B |original86 assertions|86/86 /exit0|[original smoke](ABC/B-original-smoke-report.json)|
| C |original97 assertions รวม SC09|97/97 /exit0|[original expanded](ABC/C-original-expanded-report.json)|
| D |exact record/recursive Effect/schema mutation checks|**1846/1846 /exit0**, errors0|[D report](D/D-report.json), [commands](D/results.json)|
| E |actual B1 transaction/provenance/atomic replay|**354/354 /exit0**, errors0|[E report](E/E-report.json), [commands](E/results.json)|
| F reference |fresh historical pre-cutover comparison44|44/44 /exit0|[reference results](F/reference44-results.json)|
| F canonical |fresh required canonical full suite94|94/94 /exit0|[canonical results](F/canonical94-results.json)|
| F candidate |unchanged full suite94 against B1|94/94 /exit0|[candidate results](F/candidate94-results.json)|

D/E totals include original97 each; **ไม่รวมยอดเป็น independent cases**. D ครอบคลุม55 M4Playable named records + GuidanceRequest/FrozenRecord/Profileเดิม = **58 shapes**: positive, every required key missing/extra/wrong type, bool-as-intและclosed-enum mutationเมื่อมี. Pure fixturesของ deferred recordsพิสูจน์ shape ไม่ใช่ runtime acceptanceของ B2–B5. Six reason pairs/outer-inner mismatch/invaliddelta/nestedmutationแยกจาก actual operationsชัดเจน.

E เก็บ actual request/response/before/after roots; real APPLIED และ Enemy B TARGET_UNAVAILABLE SKIPPED หลัง Enemy A ทำ declared target DOWN; genuine completionหนึ่งครั้งทั้งสองผล, duplicate impact/completion/request, no receiptก่อนimpact, capability/foreign-session/forgedtoken/mixedobservation rejection, detached copy isolation, READY no-write, catalogbootstrapทั้ง5 และ seededterminal admissionไม่มี fake progress. Nine candidate poison modes + final pre-publication faultเดิม และเพิ่มเติม outbound token/receipt poison ถูกปฏิเสธพร้อม full-root equality. Fault subclassแก้เฉพาะ detached candidate ไม่ mutate live `_root` และไม่สร้าง O7 producer.

F ใช้ existing verifier/tests **byte-identical**. ครบ Main startup/Legacyทั้งkill orders/deadskip/livingcounter/commandlock/targetfallback/Attack/Defend/NPC2Guard/defeat/victory/Restartระหว่างactions รวม Guidance v1/R1 และM4-01–04. Legacy **6 cases /5892 frames identical** ทั้งcandidate/currentcanonicalและhistorical reference. [Current canonical comparison](F/current-canonical-comparison.json), [cutover gates](F/candidate94-cutover-release-gates.json). Unexpected errors0/timeouts0; **negative suite5 expected errorsต่อrun** แยกใน [negative record](F/negative-errors.json).

Exact top-level commandsและall flagsอยู่ใน [F run record](F/run-record.json); F snapshot/source manifestsแยกcanonical/reference/candidate. [Archive749 logs/reports/exit/commands entries](F/logs-and-reports.zip), [entry hashesและarchive SHA](F/archive-manifest.json). แตก ZIP แล้วเก็บ relativepathsเดิมเพื่ออ่าน results.jsonคู่logs. B1 [tested source ZIP](E/tested-source.zip) และ [source hash manifest](E/source-sha256.json) ตรง finalsourceทั้ง6ไฟล์และF candidate. Historical runnersที่แนบเป็น execution record; ห้าม rerunทับ evidence mode/outputเดิม.

## 5. Exact changed-file scope / protected audit

Source/test ใหม่เทียบcanonicalมี6ไฟล์:

- `scripts/m4/playable_contract.gd`
- `scripts/m4/playable_encounter.gd`
- `scripts/m4/playable_rules.gd`
- `scripts/m4/playable_decision_adapter.gd`
- `scripts/m4/playable_fixture_catalog.gd`
- `tests/actors/m4_05_playable_authority_proof.gd`

Recovery-05 แก้เพิ่มเฉพาะ Contract/Rules/Proofสามไฟล์; Owner/Adapter/CatalogตรงRecovery-04. เพิ่ม historical/new evidenceใต้ `tests/actors/evidence/m4-05b/b1/` โดยรักษา bytesเดิม. Documentation updateเฉพาะ `README.md`, `docs/README.md`, `tests/actors/README.md` เพื่อสถานะปัจจุบัน/guide/evidence links; ไม่แก้ contract approvalหรือroadmap/lore. [Exact allowlist and inventory](changed-file-allowlist.json).

Protected existing runtime/tests/scenes/config/assetsทั้งหมดไม่มีdiffจากcanonical; source/test manifestsและbackupตรวจทุกไฟล์. F5/F6/Guidance v1/R1/M403/M404/damage/Guardbalance/speed0.70/lunge44/Compact Formationคงเดิม. ไม่มีnewscene, controller, autoload, project entryหรือproductionhook. UIDที่engineสร้างอยู่ในdisposable snapshots; ไม่มีsceneอ้างUIDใหม่. Markdown links/staged scope ตรวจแยกใน [final audit](final-audit.json). `git diff --check` สำหรับ authored source/docs ผ่าน; raw staged evidence มี838 whitespace warningsใน141 log/patch/txt files (exit2) จึงรักษา bytes เดิมตาม preservation requirement ไม่ trim หรือเขียนทับหลักฐาน. [Exact whitespace audit](whitespace-audit.json). ไม่มี warning นอก evidence และไม่เกี่ยวกับ engine error gates.

## 6. Limits และ Independent Review Checklist

- [ ] ตรวจcontract §§19/25–28 กับ exactschemasและstatus/reason domains; ไม่มีnewreason/newfield/fixturechange.
- [ ] ตรวจsingle live root/capabilityrouting/full-result binding/independent effect projection/replay publication; fault probesต้องคง full-root equality.
- [ ] ตรวจ originalSC09/86/97 assertionsและfailedarchives; DIAG5 failuresก่อนแก้ตรงกับfinalpositive denial checks.
- [ ] ตรวจ58 shape coverageและclassification; schema fixturesไม่ใช่legal runtime producer. APPLIEDและTARGET_UNAVAILABLE SKIPPEDพิสูจน์จริง;อีก4 SKIPPED reasonsเป็นpure schema only.
- [ ] ตรวจfreshreference44/currentcanonical94/candidate94และ749 archiveentries; ไม่ใช่การใช้canonicalปัจจุบันกับolddefaultmodeดังRecovery-04.
- [ ] ตรวจsourcehash→implementationcommit→PR HEAD mapping และexact allowlist/protected diff.
- [ ] พิจารณาB1 code/schema/evidence acceptanceอย่างอิสระ. AutomatedPASSนี้ไม่ใช่reviewapprovalและไม่อนุญาตmerge.

**ยังไม่ implement/ไม่อ้างPASS:** B2 HELP/Guard bridge, B3 full Guidance/round/RESCUE/RETREAT integration, B4 action-terminal/Restart/presentation events, B5 playable scene, M4-05C. B1พิสูจน์ATTACK/legitimateSKIP/COMPLETE/CANCELและminimalcommand/admissionเท่าที่ต้องใช้API proof; non-ATTACK effectและdeferredlifecycleยังrejectตามboundary. SeededVICTORY/DEFEATไม่ใช่combat-terminal acceptance. ไม่มีarbitrarymid-actionmutationproducer, no persistentNPC AI. GUI/F5/F6visual/keyboard/animation/pacingและperformancebenchmark **NOT RUN**; ไม่มีpresentationchangeในtaskนี้.

คำสั่งถัดไปที่อนุญาตคือส่ง **Draft B1 PR** แล้วหยุดรอ Independent Review. **DO NOT MERGE/AUTO-MERGE/DELETE BRANCH/START B2–B5.**
