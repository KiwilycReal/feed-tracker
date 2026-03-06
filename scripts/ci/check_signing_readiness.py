#!/usr/bin/env python3
import argparse
import json
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

IGNORED_ENTITLEMENT_KEYS = {
    "application-identifier",
    "com.apple.developer.team-identifier",
    "get-task-allow",
    "keychain-access-groups",
    "beta-reports-active",
}


def run(cmd: List[str], cwd: Optional[str] = None) -> str:
    completed = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{completed.stderr.strip()}")
    return completed.stdout


def parse_build_settings(text: str) -> Dict[str, str]:
    settings: Dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"\s*([A-Za-z0-9_]+)\s*=\s*(.*)$", line)
        if m:
            settings[m.group(1)] = m.group(2).strip()
    return settings


def discover_targets(project_path: str, configuration: str = "Release") -> List[dict]:
    payload = run(["xcodebuild", "-list", "-json", "-project", project_path])
    target_names = json.loads(payload)["project"]["targets"]

    discovered = []
    for target in target_names:
        out = run([
            "xcodebuild",
            "-showBuildSettings",
            "-project",
            project_path,
            "-target",
            target,
            "-configuration",
            configuration,
        ])
        s = parse_build_settings(out)
        bundle_id = s.get("PRODUCT_BUNDLE_IDENTIFIER", "").strip()
        wrapper = s.get("WRAPPER_EXTENSION", "").strip()
        supported = s.get("SUPPORTED_PLATFORMS", "")
        if not bundle_id:
            continue
        if "iphoneos" not in supported:
            continue
        if wrapper not in {"app", "appex"}:
            continue

        discovered.append(
            {
                "target": target,
                "bundle_id": bundle_id,
                "wrapper_extension": wrapper,
                "entitlements": s.get("CODE_SIGN_ENTITLEMENTS", "").strip(),
            }
        )

    return discovered


def load_profiles() -> Dict[str, dict]:
    profile_dirs = [
        Path.home() / "Library/MobileDevice/Provisioning Profiles",
        Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    ]

    found: Dict[str, dict] = {}
    for profiles_dir in profile_dirs:
        if not profiles_dir.exists():
            continue

        for profile in profiles_dir.glob("*.mobileprovision"):
            try:
                decoded = subprocess.run(
                    ["security", "cms", "-D", "-i", str(profile)],
                    capture_output=True,
                    check=True,
                ).stdout
                plist = plistlib.loads(decoded)
                ent = plist.get("Entitlements", {})
                app_identifier = ent.get("application-identifier", "")
                if "." not in app_identifier:
                    continue
                bundle_id = app_identifier.split(".", 1)[1]
                found[bundle_id] = {
                    "name": plist.get("Name", ""),
                    "path": str(profile),
                    "entitlements": ent,
                }
            except Exception:
                continue

    return found


def read_entitlements(path: str, repo_root: str) -> dict:
    if not path:
        return {}
    p = Path(repo_root) / path
    if not p.exists():
        return {}
    with p.open("rb") as f:
        return plistlib.load(f)


def actionable_error(msg: str, action: str) -> None:
    print(f"ERROR_ONE_LINE: {msg} | ACTION: {action}")
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="ci/signing-targets.json")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--mode", choices=["config", "profiles"], default="config")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo_root)
    config_path = Path(repo_root) / args.config
    if not config_path.exists():
        actionable_error(
            f"signing config missing: {args.config}",
            "create signing config and set CI_SIGNING_CONFIG_PATH correctly",
        )

    cfg = json.loads(config_path.read_text())
    project_path = cfg.get("project_path")
    if not project_path:
        actionable_error("config.project_path is empty", "set project_path in signing config")

    cfg_targets = cfg.get("targets", [])
    if not cfg_targets:
        actionable_error("config.targets is empty", "add at least one target/bundle mapping")

    cfg_by_bundle = {item["bundle_id"]: item for item in cfg_targets}
    discovered = discover_targets(str(Path(repo_root) / project_path))
    discovered_bundles = {x["bundle_id"] for x in discovered}

    missing_from_config = sorted(discovered_bundles - set(cfg_by_bundle.keys()))
    if missing_from_config:
        actionable_error(
            f"bundle IDs exist in project but missing in signing config: {', '.join(missing_from_config)}",
            "add missing bundle IDs to signing config, provision matching profiles/capabilities, then rerun release",
        )

    stale_in_config = sorted(set(cfg_by_bundle.keys()) - discovered_bundles)
    if stale_in_config:
        actionable_error(
            f"bundle IDs in signing config are not found in current project: {', '.join(stale_in_config)}",
            "update signing config to match current project targets",
        )

    if args.mode == "profiles":
        profiles = load_profiles()
        for bundle_id, target_cfg in cfg_by_bundle.items():
            if bundle_id not in profiles:
                actionable_error(
                    f"missing provisioning profile for bundle ID {bundle_id}",
                    "provision/update app identifiers and profiles outside CI, then rerun release",
                )

            expected_name = target_cfg.get("profile_name", "").strip()
            actual_name = profiles[bundle_id].get("name", "")
            if expected_name and expected_name != actual_name:
                actionable_error(
                    f"profile name mismatch for {bundle_id}: expected '{expected_name}', got '{actual_name}'",
                    "refresh match profiles outside CI, then rerun release",
                )

        discovered_by_bundle = {d["bundle_id"]: d for d in discovered}
        for bundle_id, profile in profiles.items():
            if bundle_id not in discovered_by_bundle:
                continue
            ent_path = discovered_by_bundle[bundle_id].get("entitlements", "")
            declared = read_entitlements(ent_path, repo_root)
            if not declared:
                continue
            profile_ent = profile.get("entitlements", {})
            for key in declared.keys():
                if key in IGNORED_ENTITLEMENT_KEYS:
                    continue
                if key not in profile_ent:
                    actionable_error(
                        f"entitlement '{key}' for {bundle_id} is not present in provisioning profile",
                        "regenerate provisioning profiles after capability changes, then rerun release",
                    )

    print(
        json.dumps(
            {
                "status": "ok",
                "mode": args.mode,
                "discovered_bundle_ids": sorted(discovered_bundles),
                "configured_bundle_ids": sorted(cfg_by_bundle.keys()),
            }
        )
    )


if __name__ == "__main__":
    main()
