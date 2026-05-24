"""Tests for memory-engine.py integrity checks (G1, G3).

Verifies the index schema contract documented in cmd_rebuild_index:
  G1 — Referential integrity: orphan mids are detected and repaired
  G3 — No orphan index keys: empty [] keys are pruned after build
"""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

# memory-engine.py has a dash — import via importlib
_hooks_dir = Path(__file__).resolve().parent.parent / "hooks"
_spec = importlib.util.spec_from_file_location(
    "memory_engine", _hooks_dir / "memory-engine.py"
)
memory_engine = importlib.util.module_from_spec(_spec)
sys.modules["memory_engine"] = memory_engine
_spec.loader.exec_module(memory_engine)


class Args:
    cwd = None


class RebuildIndexIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cwd = Path(self.tmp.name)
        self.mem_dir = self.cwd / ".ciel" / "memory"
        self.mem_dir.mkdir(parents=True)
        self.index_path = self.mem_dir / "index.json"

    def tearDown(self):
        self.tmp.cleanup()

    def _write_memory_file(self, mid, symbols=None, intents=None, path_patterns=None):
        """Write a minimal valid memory .md file."""
        fm = {"id": mid, "title": f"Test {mid}", "trigger_count": 0}
        if symbols:
            fm["symbols"] = symbols
        if intents:
            fm["intents"] = intents
        if path_patterns:
            fm["path_patterns"] = path_patterns

        yaml_lines = [f"{k}: {json.dumps(v) if isinstance(v, list) else v}" for k, v in fm.items()]
        content = "---\n" + "\n".join(yaml_lines) + "\n---\n\n# Test memory"
        episode_dir = self.mem_dir / "episodes"
        episode_dir.mkdir(parents=True, exist_ok=True)
        (episode_dir / f"{mid}.md").write_text(content)

    def _write_corrupt_index(self, memories, by_symbol=None, by_path=None,
                              by_intent=None, by_language=None):
        """Write an index.json with optional corruption for testing."""
        idx = {
            "version": 2,
            "memories": memories,
            "by_path": by_path or {},
            "by_symbol": by_symbol or {},
            "by_intent": by_intent or {},
            "by_language": by_language or {},
        }
        self.index_path.write_text(json.dumps(idx))

    # ── G1: Referential integrity ──────────────────────────────────────

    def test_g1_orphan_mid_removed_from_by_symbol(self):
        """Orphan mid in by_symbol is detected and removed during rebuild."""
        mid = "mem_test_0001"
        self._write_memory_file(mid, symbols=["auth"])
        # Corrupt index: by_symbol references a non-existent mid
        self._write_corrupt_index(
            memories={},
            by_symbol={"auth": [mid, "mem_orphan_9999"]},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        # Verify repair
        rebuilt = json.loads(self.index_path.read_text())
        self.assertIn(mid, rebuilt["memories"],
                      "Valid mid should be in memories after rebuild")
        self.assertNotIn("mem_orphan_9999", rebuilt["by_symbol"].get("auth", []),
                         "Orphan mid should be removed from by_symbol")

    def test_g1_orphan_mid_removed_from_by_intent(self):
        """Orphan mid in by_intent is repaired."""
        mid = "mem_test_0002"
        self._write_memory_file(mid, intents=["debug"])
        self._write_corrupt_index(
            memories={},
            by_intent={"debug": [mid, "mem_orphan_8888"]},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        self.assertNotIn("mem_orphan_8888", rebuilt["by_intent"].get("debug", []))

    def test_g1_orphan_mid_removed_from_by_language(self):
        """Orphan mid in by_language is repaired."""
        mid = "mem_test_0003"
        self._write_memory_file(mid)
        # The memory has no languages, so mid won't appear in by_language
        # but we plant an orphan there
        self._write_corrupt_index(
            memories={mid: {"id": mid, "title": "T", "file": "episodes/mem_test_0003.md"}},
            by_language={"python": ["mem_orphan_7777"]},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        self.assertNotIn("mem_orphan_7777", rebuilt["by_language"].get("python", []))

    # ── G3: Empty key pruning ──────────────────────────────────────────

    def test_g3_empty_keys_pruned_from_by_symbol(self):
        """Keys with empty lists are removed from by_symbol."""
        mid = "mem_test_0004"
        self._write_memory_file(mid, symbols=["auth"])
        # Plant an empty key
        self._write_corrupt_index(
            memories={},
            by_symbol={"auth": [mid], "stale_empty": []},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        self.assertNotIn("stale_empty", rebuilt["by_symbol"],
                         "Empty key should be pruned")

    def test_g3_empty_keys_pruned_from_by_intent(self):
        """Keys with empty lists are removed from by_intent."""
        mid = "mem_test_0005"
        self._write_memory_file(mid, intents=["refactor"])
        self._write_corrupt_index(
            memories={},
            by_intent={"refactor": [mid], "old_intent": []},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        self.assertNotIn("old_intent", rebuilt["by_intent"])

    # ── No false positives ─────────────────────────────────────────────

    def test_clean_index_survives_rebuild_unchanged(self):
        """A valid index with no orphans or empty keys remains intact."""
        mid = "mem_test_0006"
        self._write_memory_file(mid, symbols=["auth"], intents=["security"])
        self._write_corrupt_index(
            memories={mid: {"id": mid, "title": "T", "file": f"episodes/{mid}.md"}},
            by_symbol={"auth": [mid]},
            by_intent={"security": [mid]},
        )

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        self.assertIn(mid, rebuilt["memories"])
        self.assertEqual(rebuilt["by_symbol"]["auth"], [mid])
        self.assertEqual(rebuilt["by_intent"]["security"], [mid])

    # ── G2: Parse-time dedup ───────────────────────────────────────────

    def test_g2_duplicate_symbols_deduped_at_parse_time(self):
        """Duplicate entries in a single file's frontmatter are deduplicated."""
        mid = "mem_test_0007"
        self._write_memory_file(mid, symbols=["auth", "auth", "oauth"])
        # No pre-existing index

        args = Args()
        args.cwd = str(self.cwd)
        memory_engine.cmd_rebuild_index(args)

        rebuilt = json.loads(self.index_path.read_text())
        auth_mids = rebuilt["by_symbol"].get("auth", [])
        self.assertEqual(auth_mids.count(mid), 1,
                         f"mid should appear once under 'auth', got {auth_mids.count(mid)}")


if __name__ == "__main__":
    unittest.main()
