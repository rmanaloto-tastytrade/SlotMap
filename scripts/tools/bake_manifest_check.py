#!/usr/bin/env python3
"""
Validate a buildx bake manifest JSON produced by `docker buildx bake --print`.
Usage:
  python scripts/tools/bake_manifest_check.py --manifest /path/to/manifest.json \
      --expect-clang-variant p2996 --expect-gcc-version 14 --require-tool clang++-p2996
The script exits nonzero if expectations are not met.
"""
import argparse
import json
import sys
from typing import List, Dict, Any


def load_manifest(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def check_target(manifest: Dict[str, Any], expect_clang: str, expect_gcc: str, require_tools: List[str]) -> List[str]:
    errors: List[str] = []
    target = manifest.get("target", {}).get("devcontainer") or manifest.get("target", {}).get("base")
    if not target:
        errors.append("Manifest missing devcontainer/base target")
        return errors
    args = target.get("args", {})
    clang_variant = args.get("CLANG_VARIANT")
    gcc_version = args.get("GCC_VERSION")
    if expect_clang and clang_variant != expect_clang:
        errors.append(f"CLANG_VARIANT mismatch: got {clang_variant}, expected {expect_clang}")
    if expect_gcc and gcc_version != expect_gcc:
        errors.append(f"GCC_VERSION mismatch: got {gcc_version}, expected {expect_gcc}")
    # Optional: ensure required tools were intended (presence in args is best-effort).
    for tool in require_tools:
        if "p2996" in tool and args.get("ENABLE_CLANG_P2996") != "1":
            errors.append("ENABLE_CLANG_P2996 is not set to 1 but p2996 tool was required")
    return errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, help="Path to bake manifest JSON (--print output)")
    ap.add_argument("--expect-clang-variant", default="", help="Expected CLANG_VARIANT (e.g., 21, 22, p2996)")
    ap.add_argument("--expect-gcc-version", default="", help="Expected GCC_VERSION (e.g., 14, 15)")
    ap.add_argument("--require-tool", action="append", default=[], help="Tools that must be intended (e.g., clang++-p2996)")
    args = ap.parse_args()

    manifest = load_manifest(args.manifest)
    errors = check_target(manifest, args.expect_clang_variant, args.expect_gcc_version, args.require_tool)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print("Manifest validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
