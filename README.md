# WANDERER

Solo-developed Godot RPG prototype focused on a party where the player controls only their own adventurer while NPC companions decide for themselves.

## Repository layout

```text
assets/                  Runtime assets used by Godot
  sprites/
    characters/
    enemies/
art/                     Development art; ignored by Godot via .gdignore
  source/                Aseprite and legacy Pixelorama source files
  references/            Generated concepts, references, and screenshots
docs/                    Design plans and project handoffs
scenes/                  Godot scenes
scripts/                 GDScript source
project.godot            Godot project configuration
```

## Asset naming

- Use lowercase `snake_case`.
- Number reusable NPCs/enemies with two digits: `npc_01`, `enemy_01`.
- Keep runtime PNGs under `assets/`.
- Keep editable art sources and reference material under `art/`.
- Do not place screenshots, AI references, Aseprite files, or Pixelorama training files at repository root.

## Current prototype

**F5 / Run Project** starts Autonomous Main Combat (default since [PR #40](https://github.com/shanwinder/wanderer/pull/40), with production Guidance merged in [PR #43](https://github.com/shanwinder/wanderer/pull/43)):

`res://scenes/combat/combat_autonomous_optin.tscn`

The canonical `visual-combat-test-1` defaults to Autonomous. Open `res://scenes/combat/combat_prototype.tscn` with **F6** for the preserved Legacy entry.

Current status (13 November 2026):

**M4-05B B2 — isolated HELP/Guard runtime merged in [PR #62](https://github.com/shanwinder/wanderer/pull/62).** Godot 4.7.2 verification covers genuine HELP, DEFEND and guarded hits with replay-bound receipts. **B3 terminal contract passed Independent Review and received Owner approval.** The Owner approved deferring only positive Last-Party RETREAT transaction coverage. Classifier/schema/rejection checks, ordinary NPC RETREAT and Last-Party DOWN proofs remain required. [Current milestone status](docs/README.md#current-status-and-next-roadmap), [B3 feasibility evidence](tests/actors/evidence/m4-05b/b3/REPORT.md).

- **Implemented:** Player + NPC1/2/3 versus Enemy A (15 HP) and Enemy B (12 HP), target selection, surviving-target fallback, queued actions, victory/defeat and Restart.
- **Legacy F6:** NPCs take real actions under deterministic prototype rules: after Player Attack, NPC1/3 attack and NPC2 guards Player; after Player Defend, all three attack. These rules are **not an autonomous NPC decision system**.
- Combat presentation includes compact formation, action/intent cues, hit feedback and short lunges. Preserve `combat_speed_scale = 0.70` and `SHORT_LUNGE_DISTANCE = 44.0`.
- **Verified (recorded):** PR #29's Godot 4.7.2 headless scene regression passed both enemy kill orders, queue completion, command locks, Restart and damage/Guard checks. Manual F6 visual review was **not run** in that record. See [test instructions and evidence](tests/combat/README.md); this is not a claim of a new run for every documentation update.
- **M2A-02 / M2A-03 merged via PR #31 / #32** (latest base `924748c`): isolated decision/effect proof and playable post-Player scene. Owner reports manual acceptance of M2A-03 and authorizes M2B-01; no scenario-level manual evidence was supplied. The original headless evidence remains in [NPC tests](tests/npc/README.md).
- **M2B-01 / M2B-02 merged via PR #33 / #34** (latest base `90eb7d1`): shared Actor Definition / Runtime State and single-source HP ownership in the isolated NPC proof Encounter. Legacy combat retains its existing state.
- **M2C-01: Design Only. M2C-02 / M2C-03 merged via PR #35 / #36**, latest merged base `737e380c`. M2C-03 supplies the owner-approved D1–D13 prototype: per-slot decisions, full party queue and exactly-once token effects. See [data contract and inherited evidence](tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).
- **M2C-04 implemented / merged via [PR #37](https://github.com/shanwinder/wanderer/pull/37)** at `08f2a973`. Its separate F6 scene uses FullPartyEncounter; Legacy Combat uses its original HP/Guard/queue/targets. The owner reports checking it before merge; this is **owner-reported acceptance**, without scenario-level independent evidence.
- **Recorded PR #37 merged-base verification:** Godot `4.7.2.stable.official.ed1daf0bf`, **37 stages PASS** on `08f2a973`. The old M2C-04 manifest matched 54/55 files because scene UID/script UID/root unique ID/header changed after tested `9271aa5`; that baseline run verified the actual merged scene metadata.
- **M2D-01 design completed; M2D-02 implemented / merged [PR #38](https://github.com/shanwinder/wanderer/pull/38), owner-reported acceptance.** Legacy remains the canonical Main default before M2D-04 merge. Inherited evidence: 40 stages PASS, presentation 8,319 checks and 5,892 matching trace frames on `84c80d5`; M2D-04 has separate verification and visual gates.
- **M2D-03 Implemented / merged [PR #39](https://github.com/shanwinder/wanderer/pull/39)** at `1728c5e678c5065278d1251d50449a8820eb5dae`. **Owner-Reported F6 Acceptance** per the M2D-04 request; no independent scenario-level owner evidence was supplied. The inherited scene uses the existing controller/presenter and FullPartyEncounter as its sole authority. Normal NPC HP10/10/10, per-slot decisions, HELP and self-DEFEND remain prototype rules.
- **M2D-04 Implemented / merged PR #40** at `1facf144887a4c6778f2ed817aa49cab3675c73d`: Autonomous Main is the project default; Legacy F6 remains available. The M3A-02 owner task reports **F5 / F6 Autonomous / F6 Legacy acceptance passed**; this is Owner-Reported Acceptance, without independent scenario-level evidence supplied in this task. Historical pending records remain in the old evidence.
- **M3A-01 Design Completed / G1–G14 Owner Approved** in the 4 November 2026 task, with the explicit exception that **HELP 50% is NOT approved**. Existing HELP threshold remains ≤30%.
- **M3A-02 Guidance Data Foundation implemented / merged [PR #41](https://github.com/shanwinder/wanderer/pull/41)** at `cf5611ea71e68dcc9dbcac9a627df88f357d20c3`: Encounter-owned pending/frozen Guidance, strict requests, fixed session profiles and lifecycle safety. Fresh verification of that merged source in M3A-03 passed **56 stages / 66,641 Guidance Data checks**; Legacy **6 cases / 5,892 frames identical**.
- **M3A-03 isolated Guidance Decision Proof completed / merged [PR #42](https://github.com/shanwinder/wanderer/pull/42)** at `2d3b1e110c3957531a3faaa402b37d963009405a`. A separate Layer and test-only Encounter subclass prove causal FOLLOWED, MATCHED_INDEPENDENTLY and REFUSED responses with safety/urgent HELP preserved. The owner approved the explicit Discipline/Trust/Courage predicates on 5 November 2026; Compassion has no new effect and HELP remains ≤30%. Final committed-source verification: **60 stages PASS / 30 focused cases / 1,192 checks**, all inherited counts retained and **91/91 source hashes matched**. [Contract, coverage, evidence and Thai learning notes](tests/npc/README.md#m3a-03--isolated-guidance-decision-proof).
- **M3A-04 — Implemented / Merged / Owner Accepted:** [PR #43](https://github.com/shanwinder/wanderer/pull/43) merged at `a84c8d4deaa759f0f0937e6ff58c3f4ba4612a34`. Production GuidedEncounter connects the approved Decision Layer to Main, with separate Player Command/Guidance/Focus selectors, Pending/Frozen lifecycle, independent per-slot NPC decisions, Thai explanations, locked decisions versus actual effects, revision/stale-request and Restart/callback safety, preserving Legacy. **R1 Option A is unchanged**; [exact contract](tests/npc/README.md#r1-option-a--current-m3a-04-contract).
- **Verified — Recorded (PR #43, not a new run):** Godot `4.7.2.stable.official.ed1daf0bf`, tested source `5e54b6f5bcc5ada73cbd07c4dbdeca99256d2378`: **64/64 stages PASS / 34 focused Guidance Main cases / 507,851 checks**, zero unexpected failures; Legacy **6 cases / 5,892 frames identical**, **97/97 source hashes matching**. Checks include per-frame assertions, not 507,851 independent cases. [Original commands and evidence](tests/combat/README.md#verification-and-durable-evidence).
- **M3A-05 — COMPLETED; Owner-Reported Acceptance: PASS.** Source: owner's closure request in ChatGPT dated **5 November 2026 (Asia/Bangkok)**, reporting merge and overall acceptance. **Owner-reported acceptance; per-scenario independent evidence not supplied.** No new agent Godot, GUI, keyboard or visual acceptance run was performed for this documentation task. [Acceptance closure and preserved historical checklist](tests/combat/README.md#m3a-05-owner-acceptance--completed).
- **M4 Architecture — Design Review Completed / D01, D02, D12 Owner Approved:** [PR #45](https://github.com/shanwinder/wanderer/pull/45); D03–D06/D09/D13/D17 มี scoped Isolated Proof approval ตามรายการถัดไป; D07A/D10A/D11A/D14A/D15A approved เฉพาะ M4-03 isolated scope วันที่7พฤศจิกายน2026; D08 priority / D16 direction / isolated D09 direction approved วันที่8พฤศจิกายน2026; O1-A/O2-A/O3-A/O5-A approved สำหรับ isolated implementation; full D09 production extensions ยังนอก approval. [Specification / approval scope](docs/M4_Down_Help_Death_Retreat_Architecture.md).
- **M4-01 — Isolated Data/State Proof Implemented / Merged / Automated Proof Recorded:** [PR #46](https://github.com/shanwinder/wanderer/pull/46) merged ที่ `e6c3cab7291a3cd45dcacdf48406cf48f0d67118`. **Inherited Evidence จาก PR #46 ไม่ใช่ผลรันใหม่:** Godot `4.7.2.stable.official.ed1daf0bf`, tested `0b3fd961b305e6c74027f35203b77505457f5409`, **78 cases / 525 checks / 69 stages PASS**, Legacy **6 cases / 5,892 frames identical**. [Contract / exact commands / evidence](tests/actors/README.md#m4-01--isolated-datastate-proof-candidate). ไม่ใช่ Playable/Full M4; Main Player HP0→DEFEAT คงเดิม.
- **M4-02 — Isolated Atomic Effect / Clock Proof Implemented / Merged / Automated Proof Recorded:** [PR #48](https://github.com/shanwinder/wanderer/pull/48), merge `383598f946bbe0f9747e3b81b82b07dfb5c6b8bf`; R48-01 follow-up review passed in the isolated scope. Recorded evidence and remaining M402-06/M402-24/manual acceptance limits are attributed in the [Milestone Authority](docs/README.md#current-status-and-next-roadmap); no production integration or new runtime verification is claimed here.
- **M4-03A — Implemented / Merged:** [PR #50](https://github.com/shanwinder/wanderer/pull/50) squash merge `5cf53e0d145d3a518fcedd458ba2a892eb52cb1f`; recorded independent Code/Evidence Review PASS with N50-INT-01 future-integration gate.
- **M4-03B — Implemented / Merged:** [PR #51](https://github.com/shanwinder/wanderer/pull/51), squash `2c59e8d8e27c92c92344adcba9eded0d297cc547`; independent follow-up recorded **R51-01 resolved / isolated Code & Evidence Review PASS**. B-only RETREAT still requires P>1/E>0; its runtime/tests/evidence remain unchanged in C.
- **M4-03C — Implemented / Merged PR #52** at `5b870953cc88773ecbfb005cf274c2e40f3f719d`; [independent follow-up](https://github.com/shanwinder/wanderer/pull/52#pullrequestreview-5816854644) resolved R52-01 / isolated source-evidence review PASS (no reviewer rerun). Inherited C-only implementation: opt-in subclass, pure transition journal validation, legitimate fixture ATTACK/RESCUE/RETREAT, atomic D10 outcome + separate Party/Enemy summary, causal completion, finite round admission, real witnessed strict seal/close, batch B2/grace/death, Abort/Restart. Inherited evidence, not a new run: Godot4.7.2 on tested `d583b4b6fdd3226178e4f5b4e916c874a82d83c4`: **115 C cases /6,054 assertions**, fresh canonical **82/82**, candidate **88/88 stages PASS**; original A94/1,165, B150/3,339, M40178/525, M40255/1,188 retained; Legacy6cases/5,892frames identical. [Milestone authority / honest coverage limits](docs/README.md#current-status-and-next-roadmap), [API and evidence](tests/actors/README.md#m4-03c--isolated-terminal--summary--continuation-proof). Serial fixture scheduling is not NPC policy or production integration; mid-action external damage diagnostic-only, clock-caused terminal unreachable under strict seal. Manual visual acceptance NOT RUN. M4-04 is merged as recorded below; M4-05A is design only and production implementation remains outside scope.
- **M4-04 — Isolated Autonomous Decision Extension IMPLEMENTED / MERGED PR #55:** O1-A/O2-A/O3-A/O5-A retained from PR #54. [API and coverage](tests/actors/README.md#m4-04--isolated-autonomous-decision-proof), [inherited post-rebase evidence](tests/actors/evidence/m4-04/post-r54-rebase.json): tested `abb0727a`, 128 cases/458 assertions; not a new run on squash SHA. O4 deferred, O6 HELP/DEFEND effect bridge blocked, O7 diagnostic/deferred. No full production integration or manual GUI/visual acceptance. PR #56 design is merged; current T05/E decision-gate task stops at its own Draft PR. B/C and production cutover require separate Owner authorization.

Read [AGENTS.md](AGENTS.md) before agent work. Current status lives in the [documentation index](docs/README.md); older design snapshots are not completion reports.


## Game world — low-magic direction (design v0.5)

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The combat prototype described above does not implement Starstone/Resonance, injuries or permadeath.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4. M1.5–M1.6 prototype work is integrated via [PR #28](https://github.com/shanwinder/wanderer/pull/28), with the dead-enemy queue fix in [PR #29](https://github.com/shanwinder/wanderer/pull/29). Integration does not imply every visual acceptance criterion has been verified. [PR #2](https://github.com/shanwinder/wanderer/pull/2) remains an unmerged documentation proposal, not automatically canonical. No new magic systems are scheduled for immediate implementation.
