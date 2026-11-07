#!/usr/bin/env python3
"""Godot 4.7.2 verification in a fresh source snapshot (Python standard library)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def validate_m403a_report(path, log):
    """Strict optional-hook report validation; no change to inherited gates."""
    def unique_object(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate JSON key")
            value[key] = item
        return value

    def invalid_constant(value):
        raise ValueError("nonfinite JSON number: " + value)

    try:
        report = json.loads(path.read_text(), object_pairs_hook=unique_object, parse_constant=invalid_constant)
        if type(report) is not dict or set(report) != {"suite", "independent_cases", "assertion_checks",
                                                      "failures", "per_frame_checks", "cases", "deferred"}:
            return False
        if report["suite"] != "M4-03A queue foundation" or type(report["cases"]) is not list \
                or type(report["deferred"]) is not list or not all(type(x) is str for x in report["deferred"]):
            return False
        for key in ("independent_cases", "assertion_checks", "failures", "per_frame_checks"):
            if type(report[key]) is not int:
                return False
        cases = report["cases"]
        if not cases or report["independent_cases"] != len(cases) or report["failures"] != 0 \
                or report["per_frame_checks"] != 0:
            return False
        for index, case in enumerate(cases, 1):
            if type(case) is not dict or set(case) != {"id", "expected", "steps", "assertions",
                                                        "assertion_count", "failure_count", "actual"}:
                return False
            if case["id"] != f"M403A-{index:02d}" or type(case["expected"]) is not str \
                    or type(case["steps"]) is not list or type(case["assertions"]) is not list \
                    or type(case["assertion_count"]) is not int or case["assertion_count"] <= 0 \
                    or type(case["failure_count"]) is not int or case["failure_count"] != 0 \
                    or case["actual"] != "PASS" or len(case["assertions"]) != case["assertion_count"]:
                return False
            for assertion in case["assertions"]:
                if type(assertion) is not dict or set(assertion) != {"description", "passed"} \
                        or type(assertion["description"]) is not str or assertion["passed"] is not True:
                    return False
        return sum(c["assertion_count"] for c in cases) == report["assertion_checks"] \
            and re.findall(r"^RESULT: (\d+) checks, 0 failures$", log, re.MULTILINE) == [str(report["assertion_checks"])] \
            and re.findall(r"^CASE (M403A-\d+): PASS$", log, re.MULTILINE) == [c["id"] for c in cases]
    except (OSError, ValueError, KeyError, TypeError):
        return False


def validate_m403b_report(path, log):
    """Strict optional-hook report validation; no change to inherited gates."""
    def unique_object(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate JSON key")
            value[key] = item
        return value

    def invalid_constant(value):
        raise ValueError("nonfinite JSON number: " + value)

    try:
        report = json.loads(path.read_text(), object_pairs_hook=unique_object, parse_constant=invalid_constant)
        if type(report) is not dict or set(report) != {"suite", "independent_cases", "assertion_checks",
                                                      "failures", "per_frame_checks", "cases", "deferred"}:
            return False
        if report["suite"] != "M4-03B retreat transaction" or type(report["cases"]) is not list \
                or type(report["deferred"]) is not list or not all(type(x) is str for x in report["deferred"]):
            return False
        for key in ("independent_cases", "assertion_checks", "failures", "per_frame_checks"):
            if type(report[key]) is not int:
                return False
        cases = report["cases"]
        if not cases or report["independent_cases"] != len(cases) or report["failures"] != 0 \
                or report["per_frame_checks"] != 0:
            return False
        for index, case in enumerate(cases, 1):
            if type(case) is not dict or set(case) != {"id", "expected", "steps", "assertions",
                                                        "assertion_count", "failure_count", "actual"}:
                return False
            if case["id"] != f"M403B-{index:02d}" or type(case["expected"]) is not str \
                    or type(case["steps"]) is not list or type(case["assertions"]) is not list \
                    or type(case["assertion_count"]) is not int or case["assertion_count"] <= 0 \
                    or type(case["failure_count"]) is not int or case["failure_count"] != 0 \
                    or case["actual"] != "PASS" or len(case["assertions"]) != case["assertion_count"]:
                return False
            for assertion in case["assertions"]:
                if type(assertion) is not dict or set(assertion) != {"description", "passed"} \
                        or type(assertion["description"]) is not str or assertion["passed"] is not True:
                    return False
        return sum(c["assertion_count"] for c in cases) == report["assertion_checks"] \
            and re.findall(r"^RESULT: (\d+) checks, 0 failures$", log, re.MULTILINE) == [str(report["assertion_checks"])] \
            and re.findall(r"^CASE (M403B-\d+): PASS$", log, re.MULTILINE) == [c["id"] for c in cases]
    except (OSError, ValueError, KeyError, TypeError):
        return False


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
    parser.add_argument("--main-cutover-proof", action="store_true", help="Verify configured Main entry, native startup, Legacy rollback and release gates")
    parser.add_argument("--guidance-data-proof", action="store_true", help="Also verify M3A-02 data-only Guidance contracts and lifecycle")
    parser.add_argument("--guidance-decision-proof", action="store_true", help="Verify M3A-03 isolated Guidance decision layer and current Main boundary (does not toggle policy)")
    parser.add_argument("--guidance-main-proof", action="store_true", help="Verify M3A-04 production Guidance in real Main scene and R1 revision")
    parser.add_argument("--m4-data-proof", action="store_true", help="Verify isolated M4-01 Party lifecycle data, authorization, copies and generation safety")
    parser.add_argument("--m4-atomic-clock-proof", action="store_true", help="Verify isolated M4-02 atomic rescue, finite witnessed clock, death and strict seal")
    parser.add_argument("--m4-queue-foundation-proof", action="store_true", help="Verify isolated M4-03A queue identity, eligibility, cursor and atomic Restart only")
    parser.add_argument("--m4-retreat-transaction-proof", action="store_true", help="Verify isolated M4-03B owned self-retreat transactions")
    parser.add_argument("--cutover-baseline", type=Path, help="Passing merged-base output directory for trace/count comparison")
    args = parser.parse_args()
    if args.main_cutover_proof:
        required = (args.npc_proof, args.actor_proof, args.ownership_proof, args.party_foundation_proof,
                    args.party_turn_proof, args.party_playable_proof, args.presentation_proof, args.autonomous_main_proof)
        if not all(required) or not args.cutover_baseline:
            parser.error("--main-cutover-proof requires every existing proof flag and --cutover-baseline")
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

    def run(name, options, expected_errors=(), project=None):
        command = [args.godot, "--headless", "--path", str(project or snapshot),
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
        if name in ("gameplay", "invalid-actions", "npc-proof", "npc-playable", "actor-proof", "ownership-proof", "party-foundation-proof", "party-turn-proof", "party-playable-proof", "presentation-proof", "autonomous-main-proof", "main-cutover-proof", "main-cutover-f5-startup", "rollback-f5-startup", "rollback-gameplay", "guidance-data-proof", "guidance-decision-proof", "guidance-main-proof", "m4-data-proof", "m4-atomic-clock-proof"):
            passed = passed and re.search(r"RESULT: \d+ checks, 0 failures", log) is not None
        if name == "m4-atomic-clock-proof":
            try:
                report = json.loads((output / "m4-02-scenarios.json").read_text())
                passed = passed and report["failures"] == 0 and report["independent_cases"] == len(report["cases"]) \
                    and len({case["id"] for case in report["cases"]}) == len(report["cases"]) \
                    and sum(case["assertion_count"] for case in report["cases"]) == report["assertion_checks"] \
                    and all(case["actual"] == "PASS" for case in report["cases"])
            except (OSError, ValueError, KeyError, TypeError):
                passed = False
        if name == "m4-queue-foundation-proof":
            passed = passed and validate_m403a_report(output / "m4-03a-scenarios.json", log)
        if name == "m4-retreat-transaction-proof":
            passed = passed and validate_m403b_report(output / "m4-03b-scenarios.json", log)
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
                                         "--", "--report=" + str(output / "autonomous-main-scenarios.json"),
                                         *(["--expect-autonomous-default"] if args.main_cutover_proof else [])])
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
        if args.guidance_data_proof:
            for script in ["scripts/npc/guidance_data_contract.gd", "scripts/combat/full_party_encounter.gd",
                           "tests/npc/guidance_data_proof.gd"]:
                run("guidance-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("guidance-data-proof", [*timing, "--script", "res://tests/npc/guidance_data_proof.gd", "--",
                                        "--report=" + str(output / "guidance-data-scenarios.json")])
        if args.guidance_decision_proof:
            for script in ["scripts/npc/guidance_decision_layer.gd", "scripts/npc/guided_decision_proof_encounter.gd",
                           "tests/npc/guidance_decision_proof.gd"]:
                run("guided-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("guidance-decision-proof", [*timing, "--script", "res://tests/npc/guidance_decision_proof.gd", "--",
                                            "--report=" + str(output / "guidance-decision-scenarios.json")])
        if args.guidance_main_proof:
            for script in ["scripts/combat/guided_encounter.gd", "scripts/combat/guidance_messages.gd",
                           "tests/combat/guidance_main_integration.gd"]:
                run("guidance-main-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("guidance-main-proof", [*timing, "--script", "res://tests/combat/guidance_main_integration.gd", "--",
                                        "--report=" + str(output / "guidance-main-scenarios.json")])
        if args.m4_data_proof:
            for script in ["scripts/m4/isolated_actor_state.gd", "scripts/m4/isolated_registry.gd",
                           "scripts/m4/isolated_encounter.gd", "tests/actors/m4_data_state_proof.gd"]:
                run("m4-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("m4-data-proof", [*timing, "--script", "res://tests/actors/m4_data_state_proof.gd", "--",
                                  "--report=" + str(output / "m4-data-scenarios.json")])
        if args.m4_atomic_clock_proof:
            for script in ["scripts/m4/isolated_rescue_clock_encounter.gd", "tests/actors/m4_02_diagnostic_encounter.gd",
                           "tests/actors/m4_02_atomic_effect_clock_proof.gd"]:
                run("m402-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("m4-atomic-clock-proof", [*timing, "--script", "res://tests/actors/m4_02_atomic_effect_clock_proof.gd", "--",
                                          "--report=" + str(output / "m4-02-scenarios.json")])
        if args.m4_queue_foundation_proof:
            for script in ["scripts/m4/m403_queue_adapter.gd", "scripts/m4/isolated_queue_outcome_encounter.gd",
                           "tests/actors/m4_03_queue_foundation_proof.gd"]:
                run("m403a-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("m4-queue-foundation-proof", [*timing, "--script", "res://tests/actors/m4_03_queue_foundation_proof.gd", "--",
                                              "--report=" + str(output / "m4-03a-scenarios.json")])
        if args.m4_retreat_transaction_proof:
            for script in ["scripts/m4/m403_effect_candidates.gd", "scripts/m4/m403_queue_adapter.gd", "scripts/m4/isolated_queue_outcome_encounter.gd",
                           "tests/actors/m4_03_retreat_proof.gd"]:
                run("m403b-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("m4-retreat-transaction-proof", [*timing, "--script", "res://tests/actors/m4_03_retreat_proof.gd", "--",
                                               "--report=" + str(output / "m4-03b-scenarios.json")])
        if args.main_cutover_proof:
            for script in ["tests/combat/main_cutover_proof.gd", "tests/combat/main_cutover_startup_probe.gd"]:
                run("cutover-parse-" + Path(script).stem, ["--script", "res://" + script, "--check-only"])
            run("main-cutover-proof", [*timing, "--script", "res://tests/combat/main_cutover_proof.gd", "--",
                                       "--expect-autonomous-default", "--report=" + str(output / "main-cutover-scenarios.json")])
            verify_cutover(args, output, snapshot, results, run)
    return 0 if all(result["status"] == "PASS" for result in results) else 1


def verify_cutover(args, output, snapshot, results, run):
    """All mutations below are confined to disposable snapshots, never the source tree."""
    config = snapshot / "project.godot"
    candidate_config = config.read_text()
    source_hashes = {str(p.relative_to(snapshot)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted(snapshot.rglob("*")) if p.is_file() and ".godot" not in p.relative_to(snapshot).parts
                     and (p.suffix in (".gd", ".tscn", ".uid", ".png", ".svg") or p.name == "project.godot"
                          or p.relative_to(snapshot).parts[0] == "tests" and p.suffix == ".py")}
    (output / "source-sha256.json").write_text(json.dumps(source_hashes, indent=2) + "\n")

    def native_startup(project, name, legacy=False):
        # A read-only observer is autoloaded in this snapshot. There is NO --script
        # and NO explicit scene override: Godot must resolve application/run/main_scene.
        path = project / "project.godot"
        before = path.read_text()
        observer_config = before + '\n[autoload]\n\nMainCutoverProbe="*res://tests/combat/main_cutover_startup_probe.gd"\n'
        (output / (name + "-project.godot.txt")).write_text(observer_config)
        try:
            path.write_text(observer_config)
            return run(name, ["--fixed-fps", "60", "--quit-after", "120", "--",
                              "--report=" + str(output / (name + ".json")),
                              *(["--expect-legacy"] if legacy else [])], project=project)
        finally:
            path.write_text(before)

    native_startup(snapshot, "main-cutover-f5-startup")
    rollback = output / "rollback-snapshot"
    shutil.copytree(snapshot, rollback, ignore=shutil.ignore_patterns(".godot"))
    legacy_config, replacements = re.subn(r'^run/main_scene=.*$',
        'run/main_scene="res://scenes/combat/combat_prototype.tscn"', candidate_config, flags=re.MULTILINE)
    if replacements != 1:
        raise ValueError("Expected exactly one main entry for rollback")
    (rollback / "project.godot").write_text(legacy_config)
    rollback_import = run("rollback-import", ["--editor", "--import"], project=rollback)
    if rollback_import:
        native_startup(rollback, "rollback-f5-startup", legacy=True)
        timing = [] if args.real_time else ["--fixed-fps", "60"]
        run("rollback-gameplay", [*timing, "--script", "res://tests/combat/queue_regression.gd"], project=rollback)
    rollback_record = {"expected": "Fresh process and Legacy config restore HP/Guard/queue without session conversion",
                       "candidate_config": candidate_config, "rollback_config": legacy_config,
                       "candidate_config_restored": config.read_text() == candidate_config,
                       "steps": [r for r in results if r["step"].startswith("rollback-")]}
    rollback_record["actual"] = "PASS" if rollback_record["candidate_config_restored"] and len(rollback_record["steps"]) == 3 and all(
        r["status"] == "PASS" for r in rollback_record["steps"]) else "FAIL"
    (output / "rollback.json").write_text(json.dumps(rollback_record, indent=2) + "\n")

    # Release gates compare independent baseline output, not newly lowered constants.
    baseline = args.cutover_baseline.resolve()
    base_results = json.loads((baseline / "results.json").read_text())
    counts = []
    for name in ["gameplay", "invalid-actions", "npc-proof", "npc-playable", "actor-proof", "ownership-proof",
                 "party-foundation-proof", "party-turn-proof", "party-playable-proof", "presentation-proof", "autonomous-main-proof"]:
        before = re.search(r"RESULT: (\d+) checks, 0 failures", (baseline / (name + ".log")).read_text())
        after = re.search(r"RESULT: (\d+) checks, 0 failures", (output / (name + ".log")).read_text())
        counts.append({"suite": name, "expected_minimum": int(before[1]) if before else None,
                       "actual": int(after[1]) if after else None,
                       "status": "PASS" if before and after and int(after[1]) >= int(before[1]) else "FAIL"})
    before_traces = json.loads((baseline / "presentation-traces.json").read_text())["traces"]
    after_traces = json.loads((output / "presentation-traces.json").read_text())["traces"]
    comparison = {"expected": "Exact Legacy trace equality to pre-cutover merged base", "cases": len(before_traces),
                  "frames": sum(len(c["frames"]) for c in before_traces),
                  "actual": "PASS" if before_traces == after_traces else "FAIL"}
    (output / "trace-comparison.json").write_text(json.dumps(comparison, indent=2) + "\n")
    coverage = json.loads((output / "main-cutover-scenarios.json").read_text())["coverage"]
    coverage.extend([
        {"id": "C20", "expected": rollback_record["expected"], "actual": rollback_record["actual"], "evidence": "rollback.json"},
        {"id": "C21", "expected": "Every stage PASS, no timeout/unexpected errors; negative exactly five expected",
         "actual": "PASS" if all(r["status"] == "PASS" and not r["timed_out"] for r in results) else "FAIL", "evidence": "results.json"},
        {"id": "C22", "expected": "All 11 inherited suite counts retained; 6 cases/5892 Legacy frames identical",
         "actual": "PASS" if len(base_results) == 44 and all(r["status"] == "PASS" for r in base_results)
         and all(c["status"] == "PASS" for c in counts) and comparison["actual"] == "PASS"
         and comparison["cases"] == 6 and comparison["frames"] == 5892 else "FAIL", "evidence": "trace-comparison.json / counts"}])
    report = {"coverage": coverage, "counts": counts, "trace_comparison": comparison,
              "baseline": str(baseline), "manual_owner_f5_f6": "PENDING", "merge_authorized": False}
    passed = len(coverage) == 22 and all(c["actual"] == "PASS" for c in coverage)
    (output / "cutover-release-gates.json").write_text(json.dumps(report, indent=2) + "\n")
    log = "RESULT: 22 release gates, " + ("0 failures" if passed else "FAIL") + "\n"
    (output / "cutover-release-gates.log").write_text(log)
    (output / "cutover-release-gates.exit").write_text("0\n" if passed else "1\n")
    results.append({"step": "cutover-release-gates", "status": "PASS" if passed else "FAIL",
                    "exit_code": 0 if passed else 1, "timed_out": False, "errors": [],
                    "command": ["python:verify_cutover", str(baseline), str(output)], "log": "cutover-release-gates.log"})
    (output / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(("PASS" if passed else "FAIL") + ": cutover-release-gates", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
