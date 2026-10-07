#!/usr/bin/env python3
"""Print store/brand.yml as JSON for the Node renderer and capture scripts."""

import json
import sys
from pathlib import Path

import yaml


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: load_brand.py store/brand.yml", file=sys.stderr)
        sys.exit(2)
    document = yaml.safe_load(Path(sys.argv[1]).read_text())
    json.dump(document, sys.stdout)


if __name__ == "__main__":
    main()
