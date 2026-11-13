# Hybrid AI Skills Usage Audit

Discovery was via the host skill catalog and repository-local `.agents/skills` at `/Applications/wanderer`. All four `SKILL.md` files below were opened with shell `cat`. The evidence classification is **READ AS REFERENCE / APPLIED**. Router was unnecessary because the task identifies the engine and relevant workflow. The committed Wanderer contracts and approved evidence rules governed the run.

| Skill file | Application | Verification |
|---|---|---|
| `.agents/skills/godot-ui-control/SKILL.md` | Inspect stretch, Control focus, OptionButton and focus restoration. Use the actual battle window to observe traversal and the read-only log | Five Guidance types, both target pickers, next-round focus, repeat Enter, Tab/Shift+Tab after scrolling. [GUI record](GUI.md) |
| `.agents/skills/godot-nodes-scenes/SKILL.md` | Follow configured startup, inherited Autonomous scene, direct Legacy and opt-in B5 paths to their source controllers | Actual startup and battle on each path, unchanged committed scene/resources in the source manifest. [Comparison](GUI.md#scene-comparison) |
| `.agents/skills/godot-gdscript/SKILL.md` | Review callback lifetime, Tween phase, successful Restart epoch and rejected Restart preserving work | Cross-check controller, projection and authentic focused trace results. [Event and Restart evidence](TRACES.md) |
| `.agents/skills/godot-gdscript-headless-testing/SKILL.md` | Verify binary, fresh import, then run the repository's existing SceneTree proof and scan log errors in addition to process exit | Actual Godot 4.7.2, 1,521 passing checks, zero unexpected errors, 18 preserved traces. [Results](run.json) |

No native skill invocation or third-party helper execution is claimed. Skill file digests are in [run manifest](run.json). The B5 harness was read before use and remains unchanged. It exercises catalog, real scene callbacks and authorized fault methods inside its own controlled sessions.
