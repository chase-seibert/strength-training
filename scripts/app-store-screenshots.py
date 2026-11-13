#!/usr/bin/env python3
"""Give simulator screenshot attachments stable names in the site asset folder."""

import argparse
import json
import re
from pathlib import Path


def clean(directory: Path) -> None:
    manifest_path = directory / "manifest.json"
    if not manifest_path.exists():
        return
    manifest = json.loads(manifest_path.read_text())
    for result in manifest:
        for attachment in result.get("attachments", []):
            filename = Path(attachment["exportedFileName"]).name
            (directory / filename).unlink(missing_ok=True)
    manifest_path.unlink()


def normalize(directory: Path) -> None:
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for result in manifest:
        for attachment in result.get("attachments", []):
            suggested = Path(attachment["suggestedHumanReadableName"]).name
            match = re.fullmatch(r"(app-store-\d{2}-.+?)_\d+_[A-Fa-f0-9-]+\.png", suggested)
            if not match:
                raise ValueError(f"Unexpected screenshot attachment name: {suggested}")
            stable_name = f"{match.group(1)}.png"
            exported_name = Path(attachment["exportedFileName"]).name
            (directory / exported_name).replace(directory / stable_name)
            attachment["exportedFileName"] = stable_name
            attachment["suggestedHumanReadableName"] = stable_name
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("clean", "normalize"))
    parser.add_argument("directory", type=Path)
    arguments = parser.parse_args()
    if arguments.action == "clean":
        clean(arguments.directory)
    else:
        normalize(arguments.directory)


if __name__ == "__main__":
    main()
