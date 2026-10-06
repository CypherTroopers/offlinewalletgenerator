#!/usr/bin/env python3
"""Validate same-run native artifacts before copying distribution binaries.

This is build tooling only. It neither runs the generator nor handles wallet keys.
"""
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

TARGETS = (
    "linux-amd64", "linux-arm64", "windows-amd64", "windows-arm64",
    "darwin-amd64", "darwin-arm64",
)


def collect(artifacts: Path, output: Path, commit: str, go_version: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected a full source commit SHA")
    expected = {"native-" + target for target in TARGETS}
    if artifacts.is_symlink() or {p.name for p in artifacts.iterdir()} != expected:
        raise ValueError("Exactly six native artifacts are required")
    if output.is_symlink() or (output.exists() and not output.is_dir()):
        raise ValueError("Output must be a real directory")
    validated = []
    for target in TARGETS:
        directory = artifacts / ("native-" + target)
        executable = "coldwalletgenerator" + (".exe" if target.startswith("windows-") else "")
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError("Invalid artifact directory: " + target)
        if {p.name for p in directory.iterdir()} != {executable, "build-info.json"}:
            raise ValueError("Unexpected or missing artifact files: " + target)
        binary, info_file = directory / executable, directory / "build-info.json"
        if any(p.is_symlink() or not p.is_file() for p in (binary, info_file)):
            raise ValueError("Artifact files must be regular files: " + target)
        info = json.loads(info_file.read_text(encoding="utf-8"))
        if not isinstance(info, dict) or set(info) != {"source_commit", "target", "go_version", "sha256"}:
            raise ValueError("Invalid build metadata: " + target)
        if (info["source_commit"], info["target"], info["go_version"]) != (commit, target, go_version):
            raise ValueError("Source, target, or toolchain mismatch: " + target)
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        if binary.stat().st_size == 0 or info["sha256"] != digest:
            raise ValueError("Binary digest mismatch: " + target)
        destination = output / target
        if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
            raise ValueError("Invalid output directory: " + target)
        if any((destination / name).is_symlink() for name in (executable, "build-info.json")):
            raise ValueError("Output files must not be symlinks: " + target)
        validated.append((target, executable, binary, info_file, digest))
    if (output / "SHA256SUMS").is_symlink():
        raise ValueError("Checksum output must not be a symlink")

    # Validate every target before touching an existing distribution.
    output.mkdir(parents=True, exist_ok=True)
    checksums = []
    for target, executable, binary, info_file, digest in validated:
        destination = output / target
        destination.mkdir(exist_ok=True)
        shutil.copyfile(binary, destination / executable)
        (destination / executable).chmod(0o755)
        shutil.copyfile(info_file, destination / "build-info.json")
        checksums.append(f"{digest}  {target}/{executable}\n")
    (output / "SHA256SUMS").write_text("".join(checksums), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: collect_binaries.py ARTIFACTS OUTPUT SOURCE_COMMIT", file=sys.stderr)
        return 1
    try:
        module = Path(__file__).resolve().parents[1] / "go.mod"
        match = re.search(r"^go ([0-9]+\.[0-9]+(?:\.[0-9]+)?)$", module.read_text(), re.MULTILINE)
        if not match:
            raise ValueError("go.mod must specify the toolchain version")
        collect(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], "go" + match.group(1))
    except (OSError, ValueError) as error:
        print("Artifact validation failed: " + str(error), file=sys.stderr)
        return 1
    print("Validated and collected all six native binaries; no recompilation performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
