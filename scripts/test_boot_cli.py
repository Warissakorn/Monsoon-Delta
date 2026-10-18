#!/usr/bin/env python3
"""Exercise difficulty through the real Godot boot scene and isolated saves."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")


class BootDifficultyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="monsoon-boot-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.directory = Path(cls.temporary.name)
        cls.checkpoint = cls.directory / "checkpoint.json"
        cls.environment = {
            **os.environ,
            "XDG_DATA_HOME": str(cls.directory / "data"),
            "XDG_CONFIG_HOME": str(cls.directory / "config"),
        }

    def invoke(self, *arguments, scene="game", expected=0):
        result = subprocess.run(
            [GODOT, "--headless", "--path", str(ROOT), "--quit-after", "5", "--",
             f"--scene={scene}", "--lang=en",
             f"--save-path={self.checkpoint}", *arguments],
            cwd=ROOT, env=self.environment, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30,
        )
        self.assertEqual(result.returncode, expected, result.stdout)
        self.assertNotIn("SCRIPT ERROR:", result.stdout)
        self.assertIsNone(re.search(r"^ERROR:", result.stdout, re.MULTILINE), result.stdout)
        return result

    def read_checkpoint(self, expected_seed="42"):
        envelope = json.loads(self.checkpoint.read_text())
        self.assertEqual(envelope["format"], "monsoon_save")
        self.assertEqual(envelope["state"]["seed"], expected_seed)
        return envelope

    def test_default_still_starts_classic_difficulty_zero(self):
        self.invoke()
        envelope = self.read_checkpoint()
        self.assertEqual(envelope["version"], 1)
        self.assertEqual(envelope["state"]["difficulty"], 0)
        self.assertNotIn("run_mode", envelope["state"])
        self.assertNotIn("village_goal", envelope["state"])

    def test_all_existing_levels_reach_the_checkpoint(self):
        for difficulty in range(11):
            with self.subTest(difficulty=difficulty):
                self.invoke(f"--difficulty={difficulty}")
                envelope = self.read_checkpoint()
                self.assertEqual(envelope["version"], 1)
                self.assertEqual(envelope["state"]["difficulty"], difficulty)

    def test_boundary_levels_combine_with_long_runs_and_goals(self):
        for difficulty, goal in [(0, "forest"), (10, "rice")]:
            with self.subTest(difficulty=difficulty, goal=goal):
                self.invoke(f"--difficulty={difficulty}", "--run-mode=long", f"--goal={goal}")
                envelope = self.read_checkpoint()
                self.assertEqual(envelope["version"], 2)
                self.assertEqual(envelope["state"]["difficulty"], difficulty)
                self.assertEqual(envelope["state"]["run_mode"], "long")
                self.assertEqual(envelope["state"]["village_goal"], goal)

    def test_decimal_leading_zeros_do_not_overflow(self):
        self.invoke("--difficulty=00000000000000000000000010")
        self.assertEqual(self.read_checkpoint()["state"]["difficulty"], 10)

    def test_explicit_seed_still_reaches_the_game(self):
        self.invoke("--seed=812", "--difficulty=10")
        self.assertEqual(self.read_checkpoint(expected_seed="812")["state"]["difficulty"], 10)

    def test_valid_menu_preset_leaves_the_existing_run_unchanged(self):
        self.invoke("--difficulty=3")
        original = self.checkpoint.read_bytes()
        for difficulty in [0, 10]:
            with self.subTest(difficulty=difficulty):
                self.invoke(f"--difficulty={difficulty}", scene="menu")
                self.assertEqual(self.checkpoint.read_bytes(), original)

    def test_invalid_values_exit_before_touching_any_scene_checkpoint(self):
        self.invoke("--difficulty=3", "--run-mode=long", "--goal=forest")
        original = self.checkpoint.read_bytes()
        invalid = [
            "", "word", "-1", "11", "+1", "1.5", "1e0", " 1", "1 0",
            "1=2", "١", "９", "9" * 100,
        ]
        for scene in ["game", "menu", "sandbox"]:
            for value in invalid:
                with self.subTest(scene=scene, value=value):
                    self.checkpoint.write_bytes(original)
                    result = self.invoke(f"--difficulty={value}", scene=scene, expected=2)
                    self.assertIn("--difficulty", result.stdout)
                    self.assertIn("integer from 0 to 10", result.stdout)
                    self.assertEqual(self.checkpoint.read_bytes(), original)
                    self.assertFalse(self.checkpoint.with_suffix(".json.tmp").exists())

    def test_missing_value_and_later_flags_cannot_hide_invalid_difficulty(self):
        self.invoke("--difficulty=3")
        original = self.checkpoint.read_bytes()
        for arguments in [
            ["--difficulty"], ["--difficulty", "10"],
            ["--difficulty=bad", "--difficulty=10"],
            ["--difficulty", "--difficulty=10"],
        ]:
            with self.subTest(arguments=arguments):
                result = self.invoke(*arguments, expected=2)
                self.assertIn("integer from 0 to 10", result.stdout)
                self.assertEqual(self.checkpoint.read_bytes(), original)

    def test_invalid_difficulty_does_not_create_a_checkpoint(self):
        self.checkpoint.unlink(missing_ok=True)
        self.invoke("--difficulty=11", expected=2)
        self.assertFalse(self.checkpoint.exists())
        self.assertFalse(self.checkpoint.with_suffix(".json.tmp").exists())

    def test_rejection_precedes_menu_checkpoint_validation(self):
        # Opening MainMenu normally deletes a corrupt checkpoint. Rejection
        # must happen before that read/validation path, as well as before writes.
        original = b"existing checkpoint bytes that are not valid JSON\n"
        self.checkpoint.write_bytes(original)
        self.invoke("--difficulty=bad", scene="menu", expected=2)
        self.assertEqual(self.checkpoint.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
