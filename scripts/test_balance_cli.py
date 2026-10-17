#!/usr/bin/env python3
"""Exercise the real Godot balance CLI, reports and scenario isolation."""
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")


def invoke(output, *arguments, expected=0):
    result = subprocess.run(
        [GODOT, "--headless", "--path", str(ROOT), "--script",
         "res://tools/bot_sim.gd", "--", "--bot=farmer", "--runs=2",
         "--candidates=1", f"--output={output}", *arguments],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        timeout=120,
    )
    assert result.returncode == expected, result.stdout
    assert "SCRIPT ERROR:" not in result.stdout and "\nERROR:" not in result.stdout, result.stdout
    return result


def report(directory):
    manifests = list(directory.glob("run_*/manifest.json"))
    assert len(manifests) == 1, manifests
    manifest = json.loads(manifests[0].read_text())
    assert manifest["status"] == "complete", manifest
    with manifests[0].with_name("summary.csv").open(newline="") as stream:
        summary = list(csv.DictReader(stream))
    assert len(summary) == len(manifest["results"])
    for row, result in zip(summary, manifest["results"]):
        assert int(row["completed"]) == result["completed"] == manifest["runs_per_policy"]
        with Path(result["csv"]).open(newline="") as stream:
            games = list(csv.DictReader(stream))
        assert len(games) == result["completed"]
        wins = sum(int(game["win"]) for game in games)
        assert wins == result["wins"] == int(row["wins"])
        assert abs(result["win_percent"] - 100 * wins / len(games)) < 1e-8
        assert abs(result["mean_year"] - sum(int(game["year"]) for game in games) / len(games)) < 1e-8
        assert abs(result["mean_population"] - sum(int(game["population"]) for game in games) / len(games)) < 1e-8
        assert abs(result["mean_score"] - sum(int(game["score"]) for game in games) / len(games)) < 1e-8
    return manifest


def games_without_time(result):
    with Path(result["csv"]).open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    return [{key: value for key, value in row.items() if key != "seconds"} for row in rows]


def write_scenarios(path, scenarios):
    path.write_text(json.dumps({"version": 1, "scenarios": scenarios}))
    return f"--scenarios={path}"


def main():
    original_hash = hashlib.sha256((ROOT / "data/balance.json").read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="monsoon-balance-") as temporary:
        work = Path(temporary)
        invoke(work / "legacy")
        baseline = report(work / "legacy")

        scenario_file = work / "scenarios.json"
        argument = write_scenarios(scenario_file, [
            {"id": "before", "mods": {}},
            {"id": "changed", "mods": {"start_food": 18, "paddy_labor": 3, "harvest_paddy_bonus": -2}},
            {"id": "after", "mods": {}},
        ])
        invoke(work / "isolated", argument, "--revision=cli-integration")
        experiment = report(work / "isolated")
        first, changed, last = experiment["results"]
        assert games_without_time(first) == games_without_time(last) == games_without_time(baseline["results"][0])
        assert first["effective_mods"] == last["effective_mods"]
        assert changed["effective_mods"]["harvest_paddy_bonus"] == -1  # farmer +1 after base overrides
        assert changed["effective_mods"]["start_food"] == 18
        assert experiment["source"]["label"] == "cli-integration"
        if (ROOT / ".git").exists():
            revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
            assert experiment["source"]["git_revision"] == revision
            assert isinstance(experiment["source"]["git_dirty"], bool)
        assert experiment["balance_sha256"] == original_hash
        assert experiment["seed_start"] == "1" and experiment["seed_end"] == "2"
        assert experiment["bot_configuration"]["candidate_count"] == 1
        assert experiment["generation_note"]
        assert experiment["scenario_sha256"] == hashlib.sha256(scenario_file.read_bytes()).hexdigest()

        # Difficulty is applied after scenario defaults and leader modifiers.
        argument = write_scenarios(scenario_file, [
            {"id": "difficulty", "mods": {"start_food": 20, "rain_inflow_multiplier": 2}},
        ])
        invoke(work / "difficulty", argument, "--difficulty=2", "--runs=1")
        effective = report(work / "difficulty")["results"][0]["effective_mods"]
        assert effective["start_food"] == 18
        assert abs(effective["rain_inflow_multiplier"] - 2.2) < 1e-8

        # A later invalid scenario must reject the entire invocation before output.
        argument = write_scenarios(scenario_file, [
            {"id": "valid", "mods": {}},
            {"id": "invalid", "mods": {"typo_modifier": 1}},
        ])
        invoke(work / "invalid", argument, expected=2)
        assert not (work / "invalid").exists()
        for arguments in [
            ["--seed-start=9223372036854775807", "--runs=2"],
            ["--seed-start=9223372036854775808"],
            ["--seed-start=-9223372036854775809"],
            ["--runs=0"], ["--difficulty=11"], ["--candidates=0"],
        ]:
            invoke(work / "invalid-cli", *arguments, expected=2)
            assert not (work / "invalid-cli").exists()

        # An actual filesystem failure must produce a nonzero exit.
        blocked = work / "blocked"
        blocked.write_text("a file cannot be an output directory")
        invoke(blocked, expected=1)
        assert blocked.read_text() == "a file cannot be an output directory"

        # Repeating an output destination creates a separate complete run.
        invoke(work / "legacy", "--runs=1")
        assert len(list((work / "legacy").glob("run_*/manifest.json"))) == 2

    assert hashlib.sha256((ROOT / "data/balance.json").read_bytes()).hexdigest() == original_hash
    print("PASS balance CLI: isolation, determinism, modifier order, reports, validation, write failure")


if __name__ == "__main__":
    main()
