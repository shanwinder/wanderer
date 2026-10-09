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

Current visual test uses Player + NPC01 + NPC02 + NPC03 versus Enemy01 while retaining the original simple 1v1 combat logic for Player versus Enemy01.


## Game world — low-magic direction (design v0.5)

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The current visual combat test still uses basic Player-versus-Enemy logic, with NPCs shown visually.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Thailand-region world atlas & future cultures v0.1 — proposal](docs/07_Wanderer_Thailand_Region_Worldbuilding_v0.1.md)
- [Stonegate city design — MAP-02A v0.1 (proposal)](docs/08_Wanderer_Stonegate_City_Design_MAP-02A_v0.1.md)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4; the next active milestone remains **1.5B combat staging** (v0.3). No new magic systems have been scheduled for immediate implementation.
