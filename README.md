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
- **Planned:** M2A NPC Autonomy Proof is the next proposed development step, pending review of this documentation checkpoint and a separate implementation task. See the [current status and M2A proposal](docs/README.md#current-status-and-next-roadmap).

Read [AGENTS.md](AGENTS.md) before agent work. Current status lives in the [documentation index](docs/README.md); older design snapshots are not completion reports.


## Game world — low-magic direction (design v0.5)

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The combat prototype described above does not implement Starstone/Resonance, injuries or permadeath.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4. M1.5–M1.6 prototype work is integrated via [PR #28](https://github.com/shanwinder/wanderer/pull/28), with the dead-enemy queue fix in [PR #29](https://github.com/shanwinder/wanderer/pull/29). Integration does not imply every visual acceptance criterion has been verified. [PR #2](https://github.com/shanwinder/wanderer/pull/2) remains an unmerged documentation proposal, not automatically canonical. No new magic systems are scheduled for immediate implementation.
