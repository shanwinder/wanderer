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

The active development scene is:

`res://scenes/combat/combat_prototype.tscn`

As of merged PR #38 (`c0dcc33` on `visual-combat-test-1`), with M2D-03 on its review branch:

- **Implemented:** Player + NPC1/2/3 versus Enemy A (15 HP) and Enemy B (12 HP), target selection, surviving-target fallback, queued actions, victory/defeat and Restart.
- NPCs take real actions under deterministic prototype rules: after Player Attack, NPC1/3 attack and NPC2 guards Player; after Player Defend, all three attack. These rules are **not an autonomous NPC decision system**.
- Combat presentation includes compact formation, action/intent cues, hit feedback and short lunges. Preserve `combat_speed_scale = 0.70` and `SHORT_LUNGE_DISTANCE = 44.0`.
- **Verified (recorded):** PR #29's Godot 4.7.2 headless scene regression passed both enemy kill orders, queue completion, command locks, Restart and damage/Guard checks. Manual F6 visual review was **not run** in that record. See [test instructions and evidence](tests/combat/README.md); this is not a claim of a new run for every documentation update.
- **M2A-02 / M2A-03 merged via PR #31 / #32** (latest base `924748c`): isolated decision/effect proof and playable post-Player scene. Owner reports manual acceptance of M2A-03 and authorizes M2B-01; no scenario-level manual evidence was supplied. The original headless evidence remains in [NPC tests](tests/npc/README.md).
- **M2B-01 / M2B-02 merged via PR #33 / #34** (latest base `90eb7d1`): shared Actor Definition / Runtime State and single-source HP ownership in the isolated NPC proof Encounter. Main combat retains its existing state.
- **M2C-01: Design Only. M2C-02 / M2C-03 merged via PR #35 / #36**, latest merged base `737e380c`. M2C-03 supplies the owner-approved D1–D13 prototype: per-slot decisions, full party queue and exactly-once token effects. See [data contract and inherited evidence](tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).
- **M2C-04 implemented / merged via [PR #37](https://github.com/shanwinder/wanderer/pull/37)** at `08f2a973`. Its separate F6 scene uses FullPartyEncounter; Main Combat still uses Legacy HP/Guard/queue/targets. The owner reports checking it before merge; this is **owner-reported acceptance**, without scenario-level independent evidence.
- **Recorded PR #37 merged-base verification:** Godot `4.7.2.stable.official.ed1daf0bf`, **37 stages PASS** on `08f2a973`. The old M2C-04 manifest matched 54/55 files because scene UID/script UID/root unique ID/header changed after tested `9271aa5`; that baseline run verified the actual merged scene metadata.
- **M2D-01 design completed; M2D-02 implemented / merged [PR #38](https://github.com/shanwinder/wanderer/pull/38), owner-reported acceptance.** Legacy remains the Main default. Inherited evidence: 40 stages PASS, presentation 8,319 checks and 5,892 matching trace frames on `84c80d5`; this does not replace M2D-03 F6 review.
- **M2D-03 owner-approved D1–D13 / review branch:** `scenes/combat/combat_autonomous_optin.tscn` inherits the Main scene and uses the same controller/presenter with FullPartyEncounter as its sole gameplay authority. Normal NPC HP is 10/10/10 (max 10 each); independent per-slot decisions, HELP and self-DEFEND are prototype behavior. [Contract, current verification, limitations and owner F6 checklist](tests/combat/README.md#m2d-03--opt-in-main-autonomous-combat).
- **Fresh M2D-03 verification:** baseline **40 stages PASS** on merged `c0dcc33`; final **44 stages PASS** on `6f4c4db`, new integration **787,617 checks / 46 cases**, with **5,892 exact matching Legacy trace frames**. Agent F6 smoke review is partial; **Owner Visual Acceptance pending**.
- **M2D-04 cutover not started. M2B-03 Item Implementation deferred.** Default Main entry and `project.godot` remain Legacy. Stop opt-in and start a fresh Legacy battle to roll back.

Read [AGENTS.md](AGENTS.md) before agent work. Current status lives in the [documentation index](docs/README.md); older design snapshots are not completion reports.


## Game world — low-magic direction (design v0.5)

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The combat prototype described above does not implement Starstone/Resonance, injuries or permadeath.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4. M1.5–M1.6 prototype work is integrated via [PR #28](https://github.com/shanwinder/wanderer/pull/28), with the dead-enemy queue fix in [PR #29](https://github.com/shanwinder/wanderer/pull/29). Integration does not imply every visual acceptance criterion has been verified. [PR #2](https://github.com/shanwinder/wanderer/pull/2) remains an unmerged documentation proposal, not automatically canonical. No new magic systems are scheduled for immediate implementation.
