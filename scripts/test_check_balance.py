#!/usr/bin/env python3
"""Exercise TS-06 evidence checks without running simulations."""
import contextlib
import copy
import csv
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest

import check_balance


class BalanceCheckerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self, name, difficulty, policies, runs=200, scenarios=None):
        directory = self.root / name
        directory.mkdir()
        scenarios = scenarios or [{"id": "baseline", "mods": {}}]
        data = {
            "version": 1, "status": "complete", "error": "",
            "engine": {"string": "4.6.3.stable.official", "hash": "recorded-build"},
            "source": {"git_revision": "a" * 40, "git_dirty": False, "label": "fixture"},
            "balance_sha256": "b" * 64,
            "base_mods": {"start_food": 6.0, "paddy_labor": 1.0},
            "leader": "farmer", "map": "plains", "difficulty": difficulty,
            "runs_per_policy": runs, "seed_start": "1", "seed_end": str(runs),
            "bot_configuration": {"candidate_count": 8, "max_actions_per_turn": 200.0,
                                  "weights": {"loss": -1000.0, "capacity": 3.0,
                                              "destroyed": -8.0, "paddies_died": -3.0,
                                              "paddy_yield": 2.0, "food": 1.0, "wood": 0.5}},
            "policies": list(policies), "scenarios": scenarios, "results": [],
        }
        for scenario in scenarios:
            folder = directory / scenario["id"]
            folder.mkdir()
            for policy, wins in policies.items():
                path = folder / f"{policy}_plains_d{difficulty}.csv"
                rows = []
                for seed in range(1, runs + 1):
                    won = seed <= wins
                    # Both loss types occur, exercising all aggregate counts.
                    outcome = "win" if won else ("lose_hall" if seed % 2 else "lose_population")
                    rows.append([policy, "plains", difficulty, seed, int(won), outcome,
                                 5 if won else 3, 6 if won else (3 if outcome == "lose_hall" else 0), 138 if won else 0,
                                 30 if won else 18, 40, "0.010000"])
                self.write_rows(path, rows)
                result = {
                    "scenario": scenario["id"], "bot": policy, "map": "plains",
                    "difficulty": difficulty, "runs": runs, "completed": runs,
                    "wins": wins, "hall_losses": sum(row[5] == "lose_hall" for row in rows),
                    "population_losses": sum(row[5] == "lose_population" for row in rows),
                    "win_percent": 100.0 * wins / runs,
                    "mean_year": sum(row[6] for row in rows) / runs,
                    "mean_population": sum(row[7] for row in rows) / runs, "mean_score": 138.0 * wins / runs,
                    "seconds": 10.0, "csv": str(path), "error": "",
                    "effective_mods": {**data["base_mods"], **scenario["mods"]},
                }
                data["results"].append(result)
        manifest = directory / "manifest.json"
        self.write_manifest(manifest, data)
        return manifest

    @staticmethod
    def write_manifest(path, data):
        path.write_text(json.dumps(data), encoding="utf-8")

    @staticmethod
    def write_rows(path, rows):
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.writer(stream)
            writer.writerow(check_balance.COLUMNS)
            writer.writerows(rows)

    @staticmethod
    def data(path):
        return json.loads(path.read_text())

    def mutate(self, path, change):
        data = self.data(path)
        change(data)
        self.write_manifest(path, data)

    def run_check(self, *paths, scenario=None):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            arguments = [str(path) for path in paths]
            if scenario:
                arguments.append("--scenario=" + scenario)
            code = check_balance.main(arguments)
        return code, stdout.getvalue() + stderr.getvalue()

    def complete(self, greedy_wins=40, farmer_wins=10, d10_wins=20, scenarios=None, runs=200):
        return (self.fixture("d0", 0, {"farmer": farmer_wins, "greedy": greedy_wins}, scenarios=scenarios, runs=runs),
                self.fixture("d10", 10, {"greedy": d10_wins}, scenarios=scenarios, runs=runs))

    def test_inclusive_win_boundaries_and_runtime(self):
        paths = self.complete()
        self.mutate(paths[1], lambda data: data["results"][0].update(seconds=300.0))
        code, output = self.run_check(*paths)
        self.assertEqual(code, 0, output)
        self.assertIn("20.000 (20..60)", output)
        self.assertIn("10.000 (<=10)", output)
        self.assertIn("300.000000", output)

    def test_greedy_upper_bound(self):
        code, output = self.run_check(*self.complete(greedy_wins=120))
        self.assertEqual(code, 0, output)

    def test_measured_win_failures(self):
        fixture_root = self.root
        for index, arguments in enumerate(({"farmer_wins": 11}, {"greedy_wins": 39},
                                           {"greedy_wins": 121}, {"d10_wins": 21})):
            with self.subTest(arguments=arguments):
                # Separate directories keep each case independent.
                self.root = fixture_root / str(index)
                self.root.mkdir()
                code, output = self.run_check(*self.complete(**arguments))
                self.assertEqual(code, 1, output)
                self.assertIn("FAIL: measured", output)

    def test_farmer_year_boundary_and_failure(self):
        paths = self.complete()
        data = self.data(paths[0])
        result = data["results"][0]
        csv_path = Path(result["csv"])
        with csv_path.open(newline="") as stream:
            rows = list(csv.reader(stream))[1:]
        # Ten wins at year five + ten early losses at year one gives mean 3.
        for row in rows[10:20]:
            row[6] = "1"
            row[9] = "6"
        self.write_rows(csv_path, rows)
        result["mean_year"] = 3.0
        self.write_manifest(paths[0], data)
        self.assertEqual(self.run_check(*paths)[0], 0)
        rows[20][6] = "2"
        rows[20][9] = "12"
        self.write_rows(csv_path, rows)
        result["mean_year"] = 2.995
        self.write_manifest(paths[0], data)
        self.assertEqual(self.run_check(*paths)[0], 1)

    def test_runtime_failure(self):
        paths = self.complete()
        self.mutate(paths[1], lambda data: data["results"][0].update(seconds=300.000001))
        self.assertEqual(self.run_check(*paths)[0], 1)

    def test_runtime_is_normalized_to_200_games_for_larger_batches(self):
        paths = self.complete(greedy_wins=80, farmer_wins=20, d10_wins=40, runs=400)
        for path in paths:
            self.mutate(path, lambda data: [result.update(seconds=600.0) for result in data["results"]])
        code, output = self.run_check(*paths)
        self.assertEqual(code, 0, output)
        self.assertIn("600.000000 | 300.000000", output)
        self.mutate(paths[1], lambda data: data["results"][0].update(seconds=600.000001))
        self.assertEqual(self.run_check(*paths)[0], 1)

    def test_screen_and_missing_d10_are_insufficient(self):
        screen = self.fixture("screen", 0, {"farmer": 1, "greedy": 10}, runs=50)
        code, output = self.run_check(screen)
        self.assertEqual(code, 2, output)
        self.assertIn("50 runs, need >=200", output)
        self.assertIn("greedy/d10: missing required case", output)
        full_d0 = self.fixture("full_d0", 0, {"farmer": 10, "greedy": 40})
        self.assertEqual(self.run_check(full_d0)[0], 2)

    def test_mismatched_provenance_configuration_and_modifiers(self):
        paths = self.complete()
        original = self.data(paths[1])
        changes = [
            lambda data: data["source"].update(git_revision="c" * 40),
            lambda data: data.update(balance_sha256="c" * 64),
            lambda data: data["bot_configuration"].update(candidate_count=9),
            lambda data: data["bot_configuration"]["weights"].update(food=2),
            lambda data: data["scenarios"][0]["mods"].update(start_food=10),
            lambda data: data["base_mods"].update(start_food=10),
        ]
        for change in changes:
            with self.subTest(change=change):
                altered = copy.deepcopy(original)
                change(altered)
                self.write_manifest(paths[1], altered)
                code, output = self.run_check(*paths)
                self.assertEqual(code, 2, output)
                self.assertIn("mismatched", output)

    def test_compared_batches_require_the_same_seed_range(self):
        paths = self.complete()
        data = self.data(paths[1])
        csv_path = Path(data["results"][0]["csv"])
        with csv_path.open(newline="") as stream:
            rows = list(csv.reader(stream))[1:]
        for row in rows:
            row[3] = int(row[3]) + 200
        self.write_rows(csv_path, rows)
        data.update(seed_start="201", seed_end="400")
        self.write_manifest(paths[1], data)
        code, output = self.run_check(*paths)
        self.assertEqual(code, 2, output)
        self.assertIn("seed range", output)

    def test_dirty_unknown_revision_and_unimplemented_map_rejected(self):
        path = self.fixture("invalid_source", 0, {"farmer": 10})
        original = self.data(path)
        changes = [
            lambda data: data["source"].update(git_dirty=True),
            lambda data: data["source"].update(git_dirty=None),
            lambda data: data["source"].update(git_revision=""),
            lambda data: data.update(map="valley"),
        ]
        for change in changes:
            altered = copy.deepcopy(original)
            change(altered)
            self.write_manifest(path, altered)
            code, output = self.run_check(path)
            self.assertEqual(code, 2, output)
            self.assertIn("ERROR:", output)

    def test_nonfinite_manifest_metrics_and_csv_times_rejected(self):
        paths = self.complete()
        original = self.data(paths[1])
        for value in (float("nan"), float("inf"), float("-inf")):
            for key in ("win_percent", "mean_year", "mean_population", "mean_score", "seconds"):
                altered = copy.deepcopy(original)
                altered["results"][0][key] = value
                self.write_manifest(paths[1], altered)
                code, output = self.run_check(*paths)
                self.assertEqual(code, 2, output)
                self.assertIn("finite", output)
        self.write_manifest(paths[1], original)
        csv_path = Path(original["results"][0]["csv"])
        with csv_path.open(newline="") as stream:
            rows = list(csv.reader(stream))[1:]
        rows[0][-1] = "NaN"
        self.write_rows(csv_path, rows)
        self.assertEqual(self.run_check(*paths)[0], 2)

    def test_stale_summary_counts_means_and_time_rejected(self):
        paths = self.complete()
        original = self.data(paths[1])
        for key in ("wins", "hall_losses", "population_losses", "win_percent", "mean_year", "mean_population", "mean_score"):
            altered = copy.deepcopy(original)
            altered["results"][0][key] += 1
            self.write_manifest(paths[1], altered)
            code, output = self.run_check(*paths)
            self.assertEqual(code, 2, output)
            self.assertIn("stale", output)
        altered = copy.deepcopy(original)
        altered["results"][0]["seconds"] = 1
        self.write_manifest(paths[1], altered)
        self.assertIn("below summed", self.run_check(*paths)[1])

    def test_duplicate_seed_outcome_identity_and_truncated_csv_rejected(self):
        paths = self.complete()
        csv_path = Path(self.data(paths[1])["results"][0]["csv"])
        with csv_path.open(newline="") as stream:
            original = list(csv.reader(stream))[1:]
        changes = [lambda rows: rows[1].__setitem__(3, rows[0][3]),
                   lambda rows: rows[0].__setitem__(3, "201"),
                   lambda rows: rows[0].__setitem__(5, "lose_hall"),
                   lambda rows: rows[0].__setitem__(6, "3"),
                   lambda rows: rows[0].__setitem__(7, "0"),
                   lambda rows: rows[0].__setitem__(9, "29"),
                   lambda rows: rows[21].__setitem__(7, "1"),
                   lambda rows: rows[21].__setitem__(9, "17"),
                   lambda rows: rows[0].__setitem__(0, "farmer"),
                   lambda rows: rows.pop()]
        for change in changes:
            rows = copy.deepcopy(original)
            change(rows)
            self.write_rows(csv_path, rows)
            code, output = self.run_check(*paths)
            self.assertEqual(code, 2, output)
            self.assertIn("ERROR:", output)

    def test_incomplete_duplicate_results_and_bool_number_rejected(self):
        paths = self.complete()
        original = self.data(paths[0])
        changes = [lambda data: data.update(status="running"),
                   lambda data: data["results"][0].update(error="simulation failed"),
                   lambda data: data["results"].pop(),
                   lambda data: data["results"].append(data["results"][0]),
                   lambda data: data["bot_configuration"]["weights"].pop("wood"),
                   lambda data: data["bot_configuration"].update(candidate_count=True)]
        for change in changes:
            altered = copy.deepcopy(original)
            change(altered)
            self.write_manifest(paths[0], altered)
            code, output = self.run_check(*paths)
            self.assertEqual(code, 2, output)
            self.assertIn("ERROR:", output)

    def test_select_scenario_and_default_evaluates_all(self):
        scenarios = [{"id": "baseline", "mods": {}}, {"id": "candidate", "mods": {"start_food": 10}}]
        paths = self.complete(scenarios=scenarios)
        code, output = self.run_check(*paths)
        self.assertEqual(code, 0, output)
        self.assertIn("candidate |", output)
        code, output = self.run_check(*paths, scenario="candidate")
        self.assertEqual(code, 0, output)
        self.assertNotIn("baseline |", output)
        self.assertEqual(self.run_check(*paths, scenario="absent")[0], 2)

    def test_archived_absolute_paths_resolve_next_to_manifest(self):
        paths = self.complete()
        for path in paths:
            data = self.data(path)
            for result in data["results"]:
                result["csv"] = "/missing/original/run/" + Path(result["csv"]).name
            self.write_manifest(path, data)
        self.assertEqual(self.run_check(*paths)[0], 0)

    def test_archive_csv_has_priority_when_original_files_still_exist(self):
        paths = self.complete()
        archive = self.root / "archived_d0"
        shutil.copytree(paths[0].parent, archive)
        archived_manifest = archive / "manifest.json"
        result = self.data(archived_manifest)["results"][0]
        archived_csv = archive / "baseline" / Path(result["csv"]).name
        self.assertTrue(Path(result["csv"]).is_file())
        self.assertEqual(self.run_check(archived_manifest, paths[1])[0], 0)
        with archived_csv.open(newline="") as stream:
            rows = list(csv.reader(stream))[1:]
        rows[0][8] = int(rows[0][8]) + 1
        self.write_rows(archived_csv, rows)
        code, output = self.run_check(archived_manifest, paths[1])
        self.assertEqual(code, 2, output)
        self.assertIn("stale mean_score", output)

    def test_zero_population_hall_loss_is_a_valid_terminal_state(self):
        paths = self.complete()
        # Difficulty can reduce a small starting population to zero before the
        # hall is lost; population losses are otherwise decided at harvest.
        data = self.data(paths[1])
        result = data["results"][0]
        csv_path = Path(result["csv"])
        with csv_path.open(newline="") as stream:
            rows = list(csv.reader(stream))[1:]
        hall = next(row for row in rows if row[5] == "lose_hall")
        previous = int(hall[7])
        hall[7] = "0"
        result["mean_population"] -= previous / result["runs"]
        self.write_rows(csv_path, rows)
        self.write_manifest(paths[1], data)
        self.assertEqual(self.run_check(*paths)[0], 0)

    def test_mismatched_engine_version_cannot_approve_combined_reports(self):
        paths = self.complete()
        self.mutate(paths[1], lambda data: data["engine"].update(string="4.5.stable.official"))
        code, output = self.run_check(*paths)
        self.assertEqual(code, 2, output)
        self.assertIn("mismatched", output)

    def test_committed_600_game_probe_is_not_approved_from_d0_results_alone(self):
        archive = Path(__file__).resolve().parents[1] / "docs/reports/m3_followup_20261017"
        paths = [archive / name / "manifest.json" for name in ("farmer_d0", "greedy_d0", "greedy_d10")]
        code, output = self.run_check(*paths, scenario="h5_g3")
        self.assertEqual(code, 1, output)
        self.assertNotIn("ERROR:", output)
        self.assertNotIn("NOT ENOUGH DATA", output)
        for case, status in [("farmer/d0", "PASS"), ("greedy/d0", "PASS"), ("greedy/d10", "FAIL")]:
            line = next(line for line in output.splitlines() if f"| {case} |" in line)
            self.assertTrue(line.endswith("| " + status), line)

    def test_actual_godot_csv_schema_and_summary_consistency(self):
        # Recorded rows from the M3 farmer screen, preserving exporter spelling,
        # decimal precision, both outcomes, and terminal year/turn conventions.
        path = self.fixture("recorded", 0, {"farmer": 3}, runs=5)
        data = self.data(path)
        result = data["results"][0]
        rows = [
            ["farmer", "plains", 0, 1, 1, "win", 5, 6, 138, 30, 41, "0.120284"],
            ["farmer", "plains", 0, 2, 0, "lose_hall", 4, 6, 67, 24, 43, "0.093941"],
            ["farmer", "plains", 0, 3, 1, "win", 5, 6, 148, 30, 39, "0.109070"],
            ["farmer", "plains", 0, 4, 1, "win", 5, 6, 157, 30, 41, "0.130650"],
            ["farmer", "plains", 0, 5, 0, "lose_hall", 5, 6, 76, 30, 43, "0.090279"],
        ]
        self.write_rows(Path(result["csv"]), rows)
        result.update(wins=3, hall_losses=2, population_losses=0,
                      win_percent=60.0, mean_year=4.8, mean_population=6.0,
                      mean_score=117.2, seconds=0.55)
        self.write_manifest(path, data)
        code, output = self.run_check(path)
        self.assertEqual(code, 2, output)
        self.assertIn("NOT ENOUGH DATA", output)
        self.assertNotIn("ERROR:", output)
        result["mean_score"] = 117.3
        self.write_manifest(path, data)
        self.assertIn("stale mean_score", self.run_check(path)[1])


if __name__ == "__main__":
    unittest.main()
