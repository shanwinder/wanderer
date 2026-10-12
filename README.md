# WANDERER

Solo-developed Godot pixel-art RPG prototype. The player controls one adventurer; NPC companions make their own decisions. Side-view combat, meaningful injuries/permadeath, and a world formed long after a forgotten civilization.

**Current playable work:** `res://scenes/combat/combat_prototype.tscn` (Player + 3 NPC visuals + Enemy; current basic logic still limited).  
**Next milestone:** **M1.5B Combat Staging** — formation, battlefield depth and UI readability. The approved design now has four pillars: **Combat, NPC Autonomy, Management & Survival, Character Progression**. After combat readability, prove NPC decision-making in a small scenario before building shared Actor/Inventory foundations and integrating economy, journey and the personal rest base. Future worldbuilding and item-mediated low-magic mechanics are **not implemented**.

## Read only what you need

- [Game design and core rules](docs/GAME.md)
- [World bible, city and spoiler policy — development spoilers](docs/WORLD.md)
- [Current roadmap, Godot learning and sprite notes](docs/WORKFLOW.md)
- [Documentation guide](docs/README.md)
- [Portable GDScript self-study plan (23 modules) and AI tutor handoff](learning/GDSCRIPT_WANDERER_SELF_STUDY.md)

## Layout

`scenes/` Godot scenes · `scripts/` GDScript · `assets/sprites/` runtime PNGs · `art/source/` editable artwork · `art/references/` concepts/screenshots · `docs/` three canonical plans and optional map sketches.

Asset naming: lowercase `snake_case`, reusable NPC/enemy IDs `npc_01`/`enemy_01`; don't put source artwork or training screenshots under `assets/` or repository root.

**Spoiler note:** Wanderer's setting contains a delayed world-identity discovery. Developer documents may contain geographic spoilers; don't copy them into early game text, screenshots, store descriptions or public-facing announcements.
