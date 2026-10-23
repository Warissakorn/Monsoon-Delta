#!/usr/bin/env python3
"""Exercise River School through boot without touching a normal checkpoint."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")
LESSONS = ("river_school_01", "river_school_03")


class RiverSchoolBootTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        scratch = ROOT / "work" / "school-cli"
        scratch.mkdir(parents=True, exist_ok=True)
        cls.temporary = tempfile.TemporaryDirectory(prefix="attempt-", dir=scratch)
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.directory = Path(cls.temporary.name)
        cls.checkpoint = cls.directory / "checkpoint.json"
        cls.environment = {
            **os.environ,
            "XDG_DATA_HOME": str(cls.directory / "data"),
            "XDG_CONFIG_HOME": str(cls.directory / "config"),
            "XDG_CACHE_HOME": str(cls.directory / "cache"),
        }

    def setUp(self):
        self.checkpoint.unlink(missing_ok=True)
        self.checkpoint.with_suffix(".json.tmp").unlink(missing_ok=True)

    def invoke(self, *arguments, scene="school", language="en", expected=0):
        result = subprocess.run(
            [GODOT, "--headless", "--path", str(ROOT), "--quit-after", "5", "--",
             f"--scene={scene}", f"--lang={language}",
             f"--save-path={self.checkpoint}", *arguments],
            cwd=ROOT, env=self.environment, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30,
        )
        self.assertEqual(result.returncode, expected, result.stdout)
        self.assertNotIn("SCRIPT ERROR:", result.stdout)
        self.assertIsNone(re.search(r"^ERROR:", result.stdout, re.MULTILINE), result.stdout)
        return result

    def assert_no_lesson_checkpoint(self):
        self.assertFalse(self.checkpoint.with_suffix(".json.tmp").exists())
        self.assertEqual(list(self.directory.rglob("river-school-unused.json*")), [])

    def test_selector_and_both_lessons_start_without_creating_a_checkpoint(self):
        for language in ("en", "th"):
            for lesson in (None, *LESSONS):
                with self.subTest(language=language, lesson=lesson):
                    arguments = [] if lesson is None else [f"--lesson={lesson}"]
                    self.invoke(*arguments, language=language)
                    self.assertFalse(self.checkpoint.exists())
                    self.assert_no_lesson_checkpoint()

    def test_existing_v3_v4_v5_runs_remain_byte_exact_through_practice(self):
        for ruleset, version in (("legacy", 3), ("bracing_v1", 4), ("bracing_moisture_v1", 5)):
            with self.subTest(ruleset=ruleset):
                self.invoke(f"--ruleset={ruleset}", "--seed=812", scene="game")
                saved = self.checkpoint.read_bytes()
                self.assertEqual(json.loads(saved)["version"], version)
                for lesson in (None, *LESSONS):
                    arguments = [] if lesson is None else [f"--lesson={lesson}"]
                    self.invoke(*arguments)
                    self.assertEqual(self.checkpoint.read_bytes(), saved)
                    self.assert_no_lesson_checkpoint()
                self.invoke(scene="menu")
                self.assertEqual(self.checkpoint.read_bytes(), saved)

    def test_school_entries_do_not_validate_or_delete_an_unrelated_checkpoint(self):
        saved = b"A normal checkpoint is not lesson input. Do not validate this sentinel.\n"
        for lesson in (None, *LESSONS):
            with self.subTest(lesson=lesson):
                self.checkpoint.write_bytes(saved)
                arguments = [] if lesson is None else [f"--lesson={lesson}"]
                self.invoke(*arguments)
                self.assertEqual(self.checkpoint.read_bytes(), saved)
                self.assert_no_lesson_checkpoint()

    def test_invalid_lesson_ids_are_rejected_before_checkpoint_validation(self):
        saved = b"invalid JSON sentinel: reject arguments before opening MainMenu\n"
        invalid_arguments = [
            ["--lesson"], ["--lesson", "river_school_01"], ["--lesson="],
            ["--lesson=river_school_02"], ["--lesson=unknown"],
            ["--lesson=RIVER_SCHOOL_01"], ["--lesson= river_school_01"],
            ["--lesson=river_school_01=extra"],
            ["--lesson=bad", "--lesson=river_school_01"],
        ]
        for scene in ("school", "menu"):
            for arguments in invalid_arguments:
                with self.subTest(scene=scene, arguments=arguments):
                    self.checkpoint.write_bytes(saved)
                    result = self.invoke(*arguments, scene=scene, expected=2)
                    self.assertIn("--lesson=", result.stdout)
                    self.assertIn("river_school_01", result.stdout)
                    self.assertIn("river_school_03", result.stdout)
                    self.assertEqual(self.checkpoint.read_bytes(), saved)
                    self.assert_no_lesson_checkpoint()

    def test_invalid_lesson_flags_cannot_create_a_checkpoint_in_other_scenes(self):
        for scene in ("game", "sandbox"):
            with self.subTest(scene=scene):
                self.invoke("--lesson=river_school_02", scene=scene, expected=2)
                self.assertFalse(self.checkpoint.exists())
                self.assert_no_lesson_checkpoint()


if __name__ == "__main__":
    unittest.main()
