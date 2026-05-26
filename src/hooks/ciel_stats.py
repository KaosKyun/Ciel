#!/usr/bin/env python3
"""ciel-stats — Read .ciel/tracked-files.json and display session edit count.

Usage:
  python3 ciel-stats.py                        # uses CWD
  python3 ciel-stats.py --file /path/to/.ciel/tracked-files.json
"""

import sys
import json
import argparse
from pathlib import Path


def resolve_tracked_file(file_path=None):
    """Resolve the path to tracked-files.json. Uses CWD by default."""
    if file_path:
        return Path(file_path)
    return Path.cwd() / ".ciel" / "tracked-files.json"


def count_tracked_files(path: Path) -> int:
    """Return the number of entries in tracked-files.json. 0 on any error."""
    try:
        if not path.is_file():
            return 0
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            return 0
        return len(data)
    except (json.JSONDecodeError, OSError, ValueError):
        return 0


def main():
    p = argparse.ArgumentParser(
        description="Read .ciel/tracked-files.json and display session edit count"
    )
    p.add_argument("--file", default=None, help="Path to tracked-files.json")
    args = p.parse_args()

    path = resolve_tracked_file(args.file)
    count = count_tracked_files(path)
    print(count)
    sys.exit(0)


if __name__ == "__main__":
    main()
