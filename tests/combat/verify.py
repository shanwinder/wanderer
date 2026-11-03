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
    parser.add_argument("--npc-proof", action="store_true", help="Also verify the isolated M2A-02 proof")
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
        if name in ("gameplay", "invalid-actions", "npc-proof"):
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
        run("gameplay", [*timing, "--script", "res://tests/combat/queue_regression.gd"])
        run("invalid-actions", [*timing, "--script", "res://tests/combat/queue_regression.gd",
                                "--", "--invalid-actions"], [
            "Combat Turn Flow: ไม่มี Action ถัดไปหลัง NPC",
            "Combat Turn Flow: ลำดับ Action ไม่ถูกต้อง",
            *(["Combat Turn Flow: ยังไม่พร้อมเปลี่ยน Action"] * 3),
        ])
        if args.npc_proof:
            for script in ["scripts/npc/npc_decision_resolver.gd",
                           "scripts/npc/npc_proof_encounter.gd", "tests/npc/decision_effect_proof.gd"]:
                run("parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("npc-proof", [*timing, "--script", "res://tests/npc/decision_effect_proof.gd"])
    return 0 if all(result["status"] == "PASS" for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
