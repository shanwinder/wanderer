# Effect.reason contract gap — HOLD

ตรวจบน canonical `df04052cc8bf0d17510b55e75f3b357e7da9c00f`; live remote/HEAD/fetched ref ตรงกัน. Branch เดิม `codex/m4-05b-b1-single-authority-proof`. Runtime/test source hashes ตรง recovery-02 และ protected tracked diff ว่าง. เพิ่มเฉพาะหลักฐาน recovery-03; ไม่มีการแก้ source, test expected หรือ canonical contract.

## Findings and attribution correction

- Contract §19 line388 และ corrected §25 line532 นิยาม Effect.reason เป็น `S` (nonempty string), Effect.status เป็น APPLIED/SKIPPED.
- §25.1 IMPACT row line555 ระบุ **outer operation response** APPLIED/EFFECT_APPLIED และ SKIPPED พร้อมห้า reason. Line563 กำหนดให้ unknown reason/status หรือ impossible pairing ถูก reject โดยรวม แต่ไม่ได้ประกาศ exact nested catalog หรือ equality relation ระหว่างสอง record โดยตรง.
- §25.2 ต้องการ review operation/reason cross-product และ root replay completeness; §27 แก้ queue binding/fresh command ไม่มี reason amendment.
- Source `playable_contract.gd:48` ใช้ `S`; `response_valid()` lines159–170 ตรวจ outer pairing โดยไม่ตรวจ nested equality. Producer `playable_rules.gd:241,259` ปัจจุบันสร้างค่า inner/outer ตรงกันสองกรณี แต่ implementation นี้ไม่ใช่หลักฐานการอนุมัติ protocol.
- Test lines105–107 เปลี่ยนเฉพาะสำเนา Effect.reason เป็น `M405_FORGED_UNKNOWN_REASON`; validator ยอมรับจริงตาม recovery-02. ไม่ได้ import response กลับเข้า live Root. Failure 96/97 exit1 คงเดิม.

**แก้ความชัดเจนของรายงานเดิม:** recovery-02 แสดง validator acceptance จริง แต่การเรียกว่าเป็น defect เทียบ *explicitly approved nested catalog* อย่างเดียวแรงเกินหลักฐาน. มี contract ambiguity ที่ต้องปิดก่อนเลือก exact fix. ไม่ลบหรือเปลี่ยน failure เป็น PASS และไม่แก้ expected result.

## Reason domains

| Field | Current source of meaning | Boundary |
|---|---|---|
| Response.reason | §25.1 operation/status matrix and rejection catalog | Outer M405 protocol/operation result |
| Effect.reason | §§19/25 `S`; missing explicit nested membership/mapping | Actual IMPACT effect only; cannot assume all rejection reasons legal |
| Effect.status | §§19/25 APPLIED/SKIPPED | Effect result, not Decision candidate status |
| Decision.decision_reason.code | M4-04 §§3–4 and approved policy vocabulary | Existing decision domain; not imported into Effect reasons |
| Response.guidance_reason | §25.1 existing v1 validation detail | Preserve v1/R1 reasons; not imported into M405 Effect catalog |

## Proposed amendment for separate authorization and Independent Review

**PROPOSED ONLY — NOT APPROVED / NOT APPLIED.** Add normative wording in the existing canonical contract, not a replacement protocol or new roadmap:

1. Explicitly bind `Effect.reason` to this closed table derived from the existing §25.1 IMPACT row:

| Effect.status | Proposed exact permitted Effect.reason |
|---|---|
| APPLIED | `M405_EFFECT_APPLIED` |
| SKIPPED | `M405_ACTOR_UNAVAILABLE`, `M405_TARGET_UNAVAILABLE`, `M405_EPISODE_CHANGED`, `M405_RESOURCE_UNAVAILABLE`, `M405_HELP_NO_HEAL` |

2. For successful IMPACT only, require `Response.status == Effect.status` and `Response.reason == Effect.reason`. Reject unknown, empty, null, wrong-type and mismatched values. Explicitly decide whether this equality is the intended protocol before implementation.
3. Stored ActionGrant.effect and replayed effects use the same nested catalog. COMPLETE retains the original impact effect; its outer ACTION_COMPLETED reason is not compared for equality to the stored effect reason. Receipts keep their existing effect_status and schema; add no reason field.
4. Preserve §25 effect invariants: SKIPPED has zero HP delta and empty resources/guards/lifecycle; APPLIED deltas reflect actual authorized before/after roots and action semantics. Table membership alone does not authorize any effect or bypass replay/capabilities.
5. Keep Guidance/Decision/Outcome domains separate. These six proposed names already occur in the outer IMPACT catalog; assigning them to the nested field and requiring equality is the clarification needing review. No new reason/action/damage/resource rule or B2 implementation is proposed.

After separate documentation authorization, amend the existing contract and obtain Independent Review before implementing this mapping. Then run all ten requested recovery cases, original smoke, expanded adversarial matrix and full regression in the verified unsandboxed Godot environment. Do not fabricate live paths for deferred B2–B5 cases; distinguish pure value-validator tests from actual authorized transactions.

## Verification and stop

This recovery performed static contract/source/evidence inspection and hash/diff checks only. **Godot/import/parse/smoke/adversarial/regression NOT RUN in this recovery.** Prior clean 86-assertion smoke and failed 96/97 expanded run retain recovery-02 source/commands/engine attribution. All ten requested focused recovery cases remain pending; no fixed-test result exists.

HOLD follows Owner request §3: absent an explicit relationship, do not create an enum/protocol; record a gap and propose a documentation amendment. No commit/push/Draft PR/merge. Owner action: authorize the contract clarification task and Independent Review separately. B1 implementation stays on its existing branch; B2–B5 remain unauthorized.
