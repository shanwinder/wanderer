#!/usr/bin/env python3
"""Godot 4.7.2 verification in a fresh source snapshot (Python standard library)."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--real-time", action="store_true", help="Use wall-clock Tween timing")
    parser.add_argument("--npc-proof", action="store_true", help="Also verify M2A-02 proof and M2A-03 playable scene")
    parser.add_argument("--actor-proof", action="store_true", help="Also verify M2B-01 actor data foundation")
    parser.add_argument("--ownership-proof", action="store_true", help="Also verify M2B-02 Encounter HP ownership")
    parser.add_argument("--party-foundation-proof", action="store_true", help="Also verify M2C-02 registry and encounter data foundation")
    parser.add_argument("--party-turn-proof", action="store_true", help="Also verify M2C-03 multi-NPC decisions and full party turn resolution")
    parser.add_argument("--party-playable-proof", action="store_true", help="Also verify M2C-04 real scene/Tween integration")
    parser.add_argument("--presentation-proof", action="store_true", help="Also verify M2D-02 Legacy presentation boundaries and traces")
    parser.add_argument("--autonomous-main-proof", action="store_true", help="Also verify M2D-03 opt-in Main Combat integration")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2]
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="wanderer-queue-"))
    output.mkdir(parents=True, exist_ok=True)
    snapshot = output / "snapshot"
    # Never reuse .godot imports or remove an existing directory.
    snapshot.mkdir()
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=source
    ).split(b"\0")
    for raw in paths:
        if not raw:
            continue
        relative = Path(os.fsdecode(raw))
        if ".godot" in relative.parts or ".git" in relative.parts:
            continue
        original = source / relative
        if original.is_file():
            destination = snapshot / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, destination)

    results = []

    def run(name, options, expected_errors=()):
        command = [args.godot, "--headless", "--path", str(snapshot),
                   "--log-file", str(output / (name + ".engine.log")), *options]
        timed_out = False
        try:
            proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, timeout=300)
            log, code = proc.stdout, proc.returncode
        except subprocess.TimeoutExpired as error:
            log = error.stdout or b""
            if isinstance(log, bytes):
                log = log.decode("utf-8", errors="replace")
            code, timed_out = 124, True
        (output / (name + ".log")).write_text(log)
        (output / (name + ".exit")).write_text(str(code) + "\n")
        errors = re.findall(r"^(?:SCRIPT ERROR|ERROR): (.*)$", log, re.MULTILINE)
        passed = code == 0 and sorted(errors) == sorted(expected_errors)
        if name == "version":
            passed = passed and "4.7.2.stable" in log
        if name in ("gameplay", "invalid-actions", "npc-proof", "npc-playable", "actor-proof", "ownership-proof", "party-foundation-proof", "party-turn-proof", "party-playable-proof", "presentation-proof", "autonomous-main-proof"):
            passed = passed and re.search(r"RESULT: \d+ checks, 0 failures", log) is not None
        result = {"step": name, "status": "PASS" if passed else "FAIL",
                  "exit_code": code, "timed_out": timed_out, "command": command,
                  "errors": errors, "log": name + ".log"}
        results.append(result)
        (output / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
        print(f"{result['status']}: {name} (exit {code})", flush=True)
        if not passed:
            print(log, flush=True)
        return passed

    print(f"Evidence: {output}", flush=True)
    run("version", ["--version"])
    imported = run("import", ["--editor", "--import"])
    if imported:
        for script in ["scripts/combat/combat_prototype.gd", "scripts/combat/combat_turn_flow.gd",
                       "scripts/combat/combat_targets.gd", "tests/combat/queue_regression.gd"]:
            run("parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
        run("startup", ["--quit-after", "120"])
        timing = [] if args.real_time else ["--fixed-fps", "60"]
        if args.autonomous_main_proof:
            for script in ["scripts/combat/combat_presentation_adapter.gd", "tests/combat/autonomous_main_integration.gd"]:
                run("autonomous-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("autonomous-main-startup", ["res://scenes/combat/combat_autonomous_optin.tscn", "--quit-after", "120"])
            run("autonomous-main-proof", [*timing, "--script", "res://tests/combat/autonomous_main_integration.gd",
                                         "--", "--report=" + str(output / "autonomous-main-scenarios.json")])
        run("gameplay", [*timing, "--script", "res://tests/combat/queue_regression.gd"])
        run("invalid-actions", [*timing, "--script", "res://tests/combat/queue_regression.gd",
                                "--", "--invalid-actions"], [
            "Combat Turn Flow: ไม่มี Action ถัดไปหลัง NPC",
            "Combat Turn Flow: ลำดับ Action ไม่ถูกต้อง",
            *(["Combat Turn Flow: ยังไม่พร้อมเปลี่ยน Action"] * 3),
        ])
        if args.presentation_proof:
            for script in ["scripts/combat/combat_presentation_adapter.gd", "tests/combat/presentation_boundary.gd"]:
                run("presentation-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("presentation-proof", [*timing, "--script", "res://tests/combat/presentation_boundary.gd",
                                       "--", "--report=" + str(output / "presentation-traces.json")])
        if args.npc_proof:
            for script in ["scripts/npc/npc_decision_resolver.gd",
                           "scripts/npc/npc_proof_encounter.gd", "tests/npc/decision_effect_proof.gd",
                           "scripts/npc/npc_autonomy_proof.gd", "tests/npc/playable_integration.gd"]:
                run("parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("npc-proof", [*timing, "--script", "res://tests/npc/decision_effect_proof.gd"])
            run("npc-playable-startup", ["res://scenes/npc/npc_autonomy_proof.tscn", "--quit-after", "120"])
            run("npc-playable", [*timing, "--script", "res://tests/npc/playable_integration.gd"])
        if args.actor_proof:
            for script in ["scripts/actors/actor_definition.gd",
                           "scripts/actors/actor_runtime_state.gd", "tests/actors/actor_data_proof.gd"]:
                run("parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("actor-proof", [*timing, "--script", "res://tests/actors/actor_data_proof.gd"])
        if args.ownership_proof:
            run("parse-actor_ownership_proof", ["--script", "res://tests/actors/actor_ownership_proof.gd", "--check-only"])
            run("ownership-proof", [*timing, "--script", "res://tests/actors/actor_ownership_proof.gd"])
        if args.party_foundation_proof:
            for script in ["scripts/actors/actor_definition.gd", "scripts/actors/actor_runtime_state.gd",
                           "scripts/actors/actor_registry.gd", "scripts/combat/full_party_encounter.gd",
                           "tests/actors/party_foundation_proof.gd"]:
                run("party-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("party-foundation-proof", [*timing, "--script", "res://tests/actors/party_foundation_proof.gd"])
        if args.party_turn_proof:
            for script in ["scripts/npc/npc_decision_resolver.gd", "scripts/combat/full_party_encounter.gd",
                           "tests/actors/party_turn_proof.gd"]:
                run("turn-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("party-turn-proof", [*timing, "--script", "res://tests/actors/party_turn_proof.gd"])
        if args.party_playable_proof:
            for script in ["scripts/combat/full_party_proof.gd", "tests/combat/party_playable_integration.gd"]:
                run("playable-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("party-playable-startup", ["res://scenes/combat/full_party_proof.tscn", "--quit-after", "120"])
            run("party-playable-proof", [*timing, "--script", "res://tests/combat/party_playable_integration.gd",
                                         "--", "--report=" + str(output / "party-playable-scenarios.json")])
    return 0 if all(result["status"] == "PASS" for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
