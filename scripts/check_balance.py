#!/usr/bin/env python3
"""Check current bot_sim manifests against the implemented plains TS-06 targets.

Exit 0: pass; 1: measured failure; 2: insufficient or invalid evidence.
Reports are checked individually, never pooled into a larger sample.
"""
import argparse
import csv
import json
import math
from pathlib import Path
import re
import sys

REQUIRED = {("farmer", 0), ("greedy", 0), ("greedy", 10)}
COLUMNS = "bot map difficulty seed win outcome year population score turns actions seconds".split()
OUTCOMES = {"win": "wins", "lose_hall": "hall_losses", "lose_population": "population_losses"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "expected finite number")
    return value


def integer(value, minimum=None, maximum=None):
    number(value)
    require(value == int(value), "expected integer")
    value = int(value)
    require(minimum is None or value >= minimum, f"integer must be >= {minimum}")
    require(maximum is None or value <= maximum, f"integer must be <= {maximum}")
    return value


def decimal(value):
    require(isinstance(value, str) and re.fullmatch(r"[+-]?[0-9]+", value), "expected decimal integer string")
    return int(value)


def numeric_map(value):
    require(isinstance(value, dict), "expected numeric object")
    for item in value.values():
        number(item)
    return value


def finite_tree(value):
    if isinstance(value, dict):
        for item in value.values():
            finite_tree(item)
    elif isinstance(value, list):
        for item in value:
            finite_tree(item)
    elif type(value) in (int, float):
        number(value)


def check_csv(path, manifest, result):
    original = Path(result["csv"])
    basename = str(original).replace("\\", "/").rsplit("/", 1)[-1]
    archived = path.parent / result["scenario"] / basename
    report = archived if archived.is_file() else original if original.is_absolute() else archived
    counts = dict.fromkeys(OUTCOMES.values(), 0)
    totals = dict.fromkeys(("year", "population", "score"), 0)
    seeds, elapsed = set(), 0.0
    start, end = decimal(manifest["seed_start"]), decimal(manifest["seed_end"])
    with report.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        require(reader.fieldnames == COLUMNS, f"{report}: unexpected CSV header")
        for line, row in enumerate(reader, 2):
            require(None not in row and None not in row.values(), f"{report}:{line}: malformed CSV row")
            require(row["bot"] == result["bot"] and row["map"] == result["map"] and decimal(row["difficulty"]) == result["difficulty"], f"{report}:{line}: wrong bot/map/difficulty")
            seed = decimal(row["seed"])
            require(start <= seed <= end and seed not in seeds, f"{report}:{line}: duplicate or out-of-range seed")
            seeds.add(seed)
            outcome = row["outcome"]
            require(outcome in OUTCOMES and decimal(row["win"]) == int(outcome == "win"), f"{report}:{line}: inconsistent outcome/win")
            counts[OUTCOMES[outcome]] += 1
            for key in totals:
                value = decimal(row[key])
                require(key == "score" or value >= (1 if key == "year" else 0), f"{report}:{line}: invalid {key}")
                require(key != "year" or value <= 5, f"{report}:{line}: year exceeds game limit")
                totals[key] += value
            turns, year, population = decimal(row["turns"]), decimal(row["year"]), decimal(row["population"])
            require((year - 1) * 6 < turns <= year * 6 and decimal(row["actions"]) >= 0, f"{report}:{line}: invalid turns/actions")
            require(outcome != "win" or (year == 5 and turns == 30 and population > 0), f"{report}:{line}: inconsistent winning year/turns/population")
            require(outcome != "lose_population" or (population == 0 and turns == year * 6), f"{report}:{line}: inconsistent population-loss turns/population")
            seconds = number(float(row["seconds"]))
            require(seconds >= 0, f"{report}:{line}: negative seconds")
            elapsed += seconds
    runs = integer(result["runs"], 1)
    require(len(seeds) == runs == integer(result["completed"], 1) == manifest["runs_per_policy"], f"{report}: row count/completed/runs mismatch")
    require(end - start + 1 == runs, f"{report}: seed range does not match runs")
    for key, value in counts.items():
        require(integer(result[key], 0) == value, f"{report}: stale {key}")
    metrics = {"win_percent": 100.0 * counts["wins"] / runs}
    metrics.update({"mean_" + key: total / runs for key, total in totals.items()})
    for key, value in metrics.items():
        require(math.isclose(number(result[key]), value, rel_tol=1e-9, abs_tol=1e-8), f"{report}: stale {key}")
    seconds = number(result["seconds"])
    require(seconds >= 0 and seconds + runs * 0.000001 >= elapsed, f"{report}: batch seconds below summed game seconds")
    return {**result, **metrics}


def load_report(path):
    with path.open(encoding="utf-8") as stream:
        data = json.load(stream)
    require(isinstance(data, dict), "manifest must be an object")
    finite_tree(data)
    require(integer(data["version"]) == 1, "unsupported manifest version")
    require(data["status"] == "complete" and data["error"] == "", "manifest is incomplete or contains an error")
    require(data["map"] == "plains", "only plains is implemented; valley/estuary cannot be assessed")
    require(data["leader"] == "farmer", "only farmer leader is implemented")
    require(isinstance(data["engine"], dict) and isinstance(data["engine"].get("string"), str) and data["engine"]["string"], "engine version must be recorded")
    require(isinstance(data["source"], dict) and data["source"]["git_dirty"] is False, "source must record git_dirty=false; rerun from a clean commit")
    require(re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", data["source"]["git_revision"]) is not None, "source must record a full Git revision")
    require(re.fullmatch(r"[0-9a-fA-F]{64}", data["balance_sha256"]) is not None, "invalid balance_sha256")
    require(numeric_map(data["base_mods"]), "base_mods must not be empty")
    config = data["bot_configuration"]
    integer(config["candidate_count"], 1)
    integer(config["max_actions_per_turn"], 1)
    require(numeric_map(config["weights"]), "bot weights must not be empty")
    require({"loss", "capacity", "destroyed", "paddies_died", "paddy_yield", "food", "wood"} <= config["weights"].keys(), "bot configuration is missing score weights")
    difficulty = integer(data["difficulty"], 0, 10)
    runs = integer(data["runs_per_policy"], 1)
    start, end = decimal(data["seed_start"]), decimal(data["seed_end"])
    require(-(2**63) <= start <= end < 2**63 and end - start + 1 == runs, "invalid signed-int64 seed range")
    policies = data["policies"]
    require(isinstance(policies, list) and policies and all(p in ("farmer", "greedy", "random") for p in policies) and len(set(policies)) == len(policies), "invalid/duplicate policies")
    scenarios = {}
    require(isinstance(data["scenarios"], list) and data["scenarios"], "scenarios must be a nonempty array")
    for scenario in data["scenarios"]:
        name = scenario["id"]
        require(isinstance(name, str) and re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}", name), "invalid scenario id")
        require(name.lower() not in {s.lower() for s in scenarios}, "duplicate scenario id")
        scenarios[name] = numeric_map(scenario["mods"])
        require(scenarios[name].keys() <= data["base_mods"].keys(), "unknown scenario modifier")
    require(isinstance(data["results"], list), "results must be an array")
    seen, reports = set(), []
    for result in data["results"]:
        group = (result["scenario"], result["bot"])
        require(group not in seen and group[0] in scenarios and group[1] in policies, "duplicate or unexpected result")
        seen.add(group)
        require(result["error"] == "" and result["map"] == data["map"] and integer(result["difficulty"]) == difficulty, "result has an error or mismatched map/difficulty")
        require(numeric_map(result["effective_mods"]).keys() == data["base_mods"].keys(), "effective_mods do not match base modifier keys")
        reports.append(check_csv(path, data, result))
    require(seen == {(name, policy) for name in scenarios for policy in policies}, "missing scenario/policy results")
    return data, scenarios, reports


def assess(paths, selected=None):
    reports, scenario_mods, effective_mods, reference = [], {}, {}, None
    for path in paths:
        try:
            data, scenarios, batches = load_report(path)
            fingerprint = {key: data[key] for key in ("balance_sha256", "base_mods", "bot_configuration", "leader", "map", "engine")}
            fingerprint["git_revision"] = data["source"]["git_revision"]
            fingerprint.update({key: decimal(data[key]) for key in ("seed_start", "seed_end")})
            require(reference is None or fingerprint == reference, "mismatched source/engine/balance/mods/leader/map/bot configuration/seed range across manifests")
            reference = fingerprint
            for name, mods in scenarios.items():
                require(name not in scenario_mods or scenario_mods[name] == mods, f"mismatched scenario mods for {name}")
                scenario_mods[name] = mods
            for result in batches:
                key = (result["scenario"], result["difficulty"])
                require(key not in effective_mods or effective_mods[key] == result["effective_mods"], f"mismatched effective mods for {key}")
                effective_mods[key] = result["effective_mods"]
            reports.extend(batches)
        except (OSError, ValueError, KeyError, TypeError, OverflowError, csv.Error) as error:
            raise ValueError(f"{path}: {error}") from error
    require(selected is None or selected in scenario_mods, f"unknown scenario: {selected}")
    names = [selected] if selected else sorted(scenario_mods)
    missing, failed = [], False
    print("scenario | bot/difficulty | runs (>=200) | win% (target) | mean year (target) | batch seconds | seconds/200 games (<=300) | status")
    for name in names:
        found = set()
        for result in reports:
            if result["scenario"] != name:
                continue
            bot, difficulty = result["bot"], result["difficulty"]
            key = (bot, difficulty)
            found.add(key)
            win, year, seconds = result["win_percent"], result["mean_year"], result["seconds"]
            per_200 = seconds * 200 / result["runs"]
            win_target, year_target, good = "-", "-", per_200 <= 300
            if key == ("farmer", 0):
                win_target, year_target = "<=5", ">=3"
                good = good and win <= 5 and year >= 3
            elif key == ("greedy", 0):
                win_target = "20..60"
                good = good and 20 <= win <= 60
            elif key == ("greedy", 10):
                win_target = "<=10"
                good = good and win <= 10
            short = result["runs"] < 200
            if short:
                missing.append(f"{name}/{bot}/d{difficulty}: {result['runs']} runs, need >=200")
            failed = failed or (not short and not good)
            status = "NOT ENOUGH DATA" if short else ("PASS" if good else "FAIL")
            print(f"{name} | {bot}/d{difficulty} | {result['runs']} | {win:.3f} ({win_target}) | {year:.3f} ({year_target}) | {seconds:.6f} | {per_200:.6f} | {status}")
        for bot, difficulty in sorted(REQUIRED - found):
            missing.append(f"{name}/{bot}/d{difficulty}: missing required case")
    if missing:
        print("NOT ENOUGH DATA: " + "; ".join(missing))
        return 2
    print("FAIL: measured TS-06 target failure" if failed else "PASS: all implemented plains TS-06 targets met")
    return int(failed)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifests", nargs="+", type=Path)
    parser.add_argument("--scenario", help="assess one scenario id; default: assess every scenario")
    args = parser.parse_args(argv)
    try:
        return assess(args.manifests, args.scenario)
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
