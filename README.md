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

> **World mystery:** Early story and public presentation intentionally avoid identifying the geographic origin of the setting. Linked development documents contain spoilers about the ancient world; do not use them as player-facing lore or promotional copy.

Wanderer takes place thousands of years after the collapse of present-day civilization. Its new societies resemble a late-medieval / early-modern world built among misunderstood ancient ruins. The game remains a **low-magic, party-based RPG with consequential injuries, permadeath, and autonomous NPC companions**.

People know that rare supernatural effects exist, but most never see them firsthand. Special weapons, tools, and ornaments depend on **Starstone**, an unusual meteorite-derived material used through crafted devices and **Resonance**. These powers have strict costs, limitations, and risks. An ancient meteorite event may have contributed to the old world's collapse; its actual causal role remains unresolved in the lore.

**These are worldbuilding and future feature plans, not implemented gameplay.** The current visual combat test still uses basic Player-versus-Enemy logic, with NPCs shown visually.

- [World lore & Starstone canon v0.5](docs/05_Wanderer_Starstone_World_Lore_v0.5.md)
- [Resonance gameplay integration & future tests v0.5](docs/06_Wanderer_Resonance_Gameplay_Integration_v0.5.md)
- [Regional world atlas & future cultures v0.1 — development spoilers](docs/07_Wanderer_Fallen_World_Regional_Atlas_v0.1.md)
- [Stonegate city design — MAP-02A v0.1 (proposal)](docs/08_Wanderer_Stonegate_City_Design_MAP-02A_v0.1.md)
- [Stonegate MAP-02B — editable city layout SVG](docs/maps/stonegate_map02b_layout_v0.1.svg)
- [Stonegate MAP-02B — cartography brief](docs/09_Wanderer_Stonegate_MAP-02B_City_Cartography_v0.1.md)
- [MAP-03 — Regional civilizations, cultures and trade v0.1](docs/10_Wanderer_MAP-03_Regional_Civilizations_and_Trade_v0.1.md)
- [Delayed-world-reveal design policy (contains spoilers)](docs/11_Wanderer_Delayed_World_Reveal_and_Spoiler_Policy_v0.1.md)
- [Player-safe opening content and route UI copy (draft)](docs/12_Wanderer_Player_Safe_Opening_Content_v0.1.md)
- [Player-safe early route map concept (SVG)](docs/maps/stonegate_player_route_R0_v0.1.svg)
- [Documentation index and precedence](docs/README.md)

Development continues **learning-first** per v0.4; the next active milestone remains **1.5B combat staging** (v0.3). No new magic systems have been scheduled for immediate implementation.
