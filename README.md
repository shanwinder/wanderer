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

As of the post-PR #29 baseline (`2926e5c` on `visual-combat-test-1`):

- **Implemented:** Player + NPC1/2/3 versus Enemy A (15 HP) and Enemy B (12 HP), target selection, surviving-target fallback, queued actions, victory/defeat and Restart.
- NPCs take real actions under deterministic prototype rules: after Player Attack, NPC1/3 attack and NPC2 guards Player; after Player Defend, all three attack. These rules are **not an autonomous NPC decision system**.
- Combat presentation includes compact formation, action/intent cues, hit feedback and short lunges. Preserve `combat_speed_scale = 0.70` and `SHORT_LUNGE_DISTANCE = 44.0`.
- **Verified (recorded):** PR #29's Godot 4.7.2 headless scene regression passed both enemy kill orders, queue completion, command locks, Restart and damage/Guard checks. Manual F6 visual review was **not run** in that record. See [test instructions and evidence](tests/combat/README.md); this is not a claim of a new run for every documentation update.
- **M2A-02 / M2A-03 merged via PR #31 / #32** (latest base `924748c`): isolated decision/effect proof and playable post-Player scene. Owner reports manual acceptance of M2A-03 and authorizes M2B-01; no scenario-level manual evidence was supplied. The original headless evidence remains in [NPC tests](tests/npc/README.md).
- **M2B-01 / M2B-02 merged via PR #33 / #34** (latest base `90eb7d1`): shared Actor Definition / Runtime State and single-source HP ownership in the isolated NPC proof Encounter. Main combat retains its existing state.
- **M2C-01: Design Only. M2C-02 / M2C-03 merged via PR #35 / #36**, latest merged base `737e380c`. M2C-03 supplies the owner-approved D1–D13 prototype: per-slot decisions, full party queue and exactly-once token effects. See [data contract and inherited evidence](tests/actors/README.md#m2c-03--multi-npc-decision-and-turn-resolution-proof).
- **M2C-04: isolated playable implementation, pending Draft review** on `codex/m2c-04-playable-full-party`. Open `res://scenes/combat/full_party_proof.tscn` and use **F6 / Run Current Scene**. Player ATTACK/DEFEND, live targets, three independent NPC reason rows, separate enemy slots, eight presets and epoch-safe Restart read the existing Encounter. Main scene and gameplay contract are unchanged.
- **Verified on `9271aa5` with Godot 4.7.2:** all **37 headless stages** pass; M2C-04 **260,800 checks / 31 cases**, all eight legacy suites retain their counts. Agent GUI smoke review covered startup, S1 DEFEND and S2 HELP at a 1280×720 project viewport; **owner visual acceptance is pending**, not inferred from headless checks or screenshots. [Architecture, Thai learning notes, evidence and owner checklist](tests/combat/README.md#m2c-04--playable-full-party-integration). M2B-03 Item/Equipment remains deferred; Main Combat Migration is not approved.

Read [AGENTS.md](AGENTS.md) before agent work. Current status lives in the [documentation index](docs/README.md); older design snapshots are not completion reports.


## Game world — low-magic direction (design v0.5)

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The combat prototype described above does not implement Starstone/Resonance, injuries or permadeath.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4. M1.5–M1.6 prototype work is integrated via [PR #28](https://github.com/shanwinder/wanderer/pull/28), with the dead-enemy queue fix in [PR #29](https://github.com/shanwinder/wanderer/pull/29). Integration does not imply every visual acceptance criterion has been verified. [PR #2](https://github.com/shanwinder/wanderer/pull/2) remains an unmerged documentation proposal, not automatically canonical. No new magic systems are scheduled for immediate implementation.
