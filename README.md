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
