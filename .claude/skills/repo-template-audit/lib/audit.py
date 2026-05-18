#!/usr/bin/env python3
"""repo-template-audit — drift detection against richwklein/repo-template-{base,astro}.

Usage:
    audit.py [target-path]

target-path defaults to current working directory. It must be a git repository
with an origin remote on github.com.

Outputs a markdown report on stdout. The skill's Claude instructions interpret
the report and propose remediation interactively.

IMPORTANT: the CANONICAL_SETTINGS dict below mirrors docs/REPO_SETTINGS.yaml.
Both files are tracked in manifest.json, so drift between them surfaces in the
audit's File drift section.
"""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import sys
from difflib import unified_diff
from pathlib import Path

BASE_REPO = "richwklein/repo-template-base"
ASTRO_REPO = "richwklein/repo-template-astro"

# Mirror of docs/REPO_SETTINGS.yaml. Update both files together; any drift is
# surfaced by the File drift section (REPO_SETTINGS.yaml is tracked exactly).
CANONICAL_SETTINGS = {
    "actions": {
        "default_workflow_permissions": "write",
        "can_approve_pull_request_reviews": True,
        "allowed_actions": "selected",
        "github_owned_allowed": True,
        "verified_allowed": True,
        "patterns_allowed": sorted([
            "googleapis/release-please-action@*",
            "github/codeql-action/*@*",
            "davelosert/vitest-coverage-report-action@*",
            "marocchino/sticky-pull-request-comment@*",
        ]),
    },
    "security": {
        "secret_scanning": "enabled",
        "secret_scanning_push_protection": "enabled",
        "secret_scanning_non_provider_patterns": "disabled",
        "secret_scanning_validity_checks": "disabled",
        "dependabot_security_updates": "enabled",
        "private_vulnerability_reporting": "enabled",
        "code_scanning_default_setup": "disabled",
    },
    "general": {
        "allow_merge_commit": False,
        "allow_squash_merge": True,
        "allow_rebase_merge": False,
        "delete_branch_on_merge": True,
        "allow_auto_merge": False,
        "allow_update_branch": False,
        "squash_merge_commit_title": "PR_TITLE",
        "squash_merge_commit_message": "PR_BODY",
        "web_commit_signoff_required": True,
    },
}


# ---- gh CLI helpers ---------------------------------------------------------

def gh_api(path: str) -> dict | None:
    """GET an API path via `gh api`. Returns parsed JSON, or None on error."""
    try:
        out = subprocess.run(
            ["gh", "api", path],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        return json.loads(out) if out.strip() else None
    except subprocess.CalledProcessError:
        return None
    except json.JSONDecodeError:
        return None


def fetch_canonical(repo: str, path: str) -> bytes | None:
    """Fetch a file's raw bytes from a GitHub repo via the contents API."""
    data = gh_api(f"repos/{repo}/contents/{path}")
    if not data or "content" not in data:
        return None
    try:
        return base64.b64decode(data["content"])
    except (ValueError, TypeError):
        return None


# ---- Target detection -------------------------------------------------------

LOCAL_MANIFEST_PATH = ".claude/skills/repo-template-audit/manifest.json"


def detect_target(target: Path) -> tuple[str, str]:
    """Return (owner/repo, flavor) for the target directory.

    Flavor is resolved in order of precedence:
      1. `repo_flavor` field in the local manifest.json (if present)
      2. `astro.config.*` file presence -> "astro"
      3. default "base"
    """
    if not (target / ".git").is_dir():
        sys.exit(f"error: {target} is not a git repo")
    try:
        remote = subprocess.run(
            ["git", "-C", str(target), "remote", "get-url", "origin"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit(f"error: no origin remote configured in {target}")

    # Normalize git@github.com[-alias]:owner/repo.git or https://github.com/owner/repo.git
    m = re.search(r"github\.com[^:/]*[:/]([^/]+/[^/]+?)(?:\.git)?$", remote)
    if not m:
        sys.exit(f"error: could not parse owner/repo from remote: {remote}")
    repo = m.group(1)

    flavor = None
    local_manifest = target / LOCAL_MANIFEST_PATH
    if local_manifest.is_file():
        try:
            declared = json.loads(local_manifest.read_text()).get("repo_flavor")
            if declared in ("base", "astro"):
                flavor = declared
        except json.JSONDecodeError:
            pass

    if flavor is None:
        flavor = "base"
        for ext in ("ts", "mjs", "js", "mts"):
            if (target / f"astro.config.{ext}").is_file():
                flavor = "astro"
                break

    return repo, flavor


# ---- File drift -------------------------------------------------------------

def files_equivalent(path: str, canonical: bytes, local: bytes) -> bool:
    """Byte-equal — except manifest.json, where the per-repo `repo_flavor`
    key is allowed to differ. Everything else in the manifest must match."""
    if canonical == local:
        return True
    if path == LOCAL_MANIFEST_PATH:
        try:
            c = json.loads(canonical)
            l = json.loads(local)
            c.pop("repo_flavor", None)
            l.pop("repo_flavor", None)
            return c == l
        except json.JSONDecodeError:
            return False
    return False


def diff_snippet(canonical: bytes, local: bytes, path: str) -> str:
    try:
        c_lines = canonical.decode("utf-8", errors="replace").splitlines(keepends=True)
        l_lines = local.decode("utf-8", errors="replace").splitlines(keepends=True)
    except Exception:
        return "(binary file; cannot diff)"
    diff = unified_diff(
        c_lines, l_lines,
        fromfile=f"canonical/{path}", tofile=f"local/{path}",
        n=2,
    )
    return "".join(list(diff)[:40])


def audit_files(target: Path, flavor: str, manifest: dict) -> list[str]:
    """Return markdown lines for the File drift section."""
    base = manifest["flavors"]["base"]
    astro = manifest["flavors"]["astro"]

    if flavor == "astro":
        # Astro overrides base: a file in astro.exact_match is checked against
        # repo-template-astro instead of repo-template-base.
        astro_paths = set(astro["exact_match"])
        exact = [(p, BASE_REPO) for p in base["exact_match"] if p not in astro_paths] + \
                [(p, ASTRO_REPO) for p in astro["exact_match"]]
        presence = base["presence_only"] + astro["presence_only"]
    else:
        exact = [(p, BASE_REPO) for p in base["exact_match"]]
        presence = base["presence_only"]

    missing, drifted, canonical_missing = [], [], []
    for path, repo in exact:
        local_path = target / path
        if not local_path.is_file():
            missing.append((path, "exact_match"))
            continue
        canonical = fetch_canonical(repo, path)
        if canonical is None:
            canonical_missing.append(path)
            continue
        local_bytes = local_path.read_bytes()
        if files_equivalent(path, canonical, local_bytes):
            continue
        drifted.append((path, diff_snippet(canonical, local_bytes, path)))

    presence_missing = [(p, "presence_only") for p in presence if not (target / p).is_file()]

    out: list[str] = ["## File drift", ""]

    out.append(f"### Missing ({len(missing) + len(presence_missing)})")
    out.append("")
    if not missing and not presence_missing:
        out.append("_None._")
    else:
        for p, kind in missing + presence_missing:
            out.append(f"- `{p}` ({kind})")
    out.append("")

    out.append(f"### Drifted ({len(drifted)})")
    out.append("")
    if not drifted:
        out.append("_None._")
    else:
        for path, snippet in drifted:
            out.append(f"- `{path}`")
            out.append("")
            out.append("  ```diff")
            for line in snippet.splitlines():
                out.append(f"  {line}")
            out.append("  ```")
            out.append("")

    out.append("### Schema gaps")
    out.append("")
    if flavor == "astro":
        out.extend(check_package_scripts(target, manifest))
    else:
        out.append("_No schema-match entries for base flavor._")
    out.append("")

    if canonical_missing:
        out.append("### Canonical lookups that failed")
        out.append("")
        out.append("_Could not fetch these from the template repo (transient or missing):_")
        for p in canonical_missing:
            out.append(f"- `{p}`")
        out.append("")

    return out


def check_package_scripts(target: Path, manifest: dict) -> list[str]:
    pkg = target / "package.json"
    if not pkg.is_file():
        return ["- `package.json`: file missing"]
    try:
        data = json.loads(pkg.read_text())
    except json.JSONDecodeError as e:
        return [f"- `package.json`: parse error ({e})"]

    required = []
    for entry in manifest["flavors"]["astro"]["schema_match"]:
        if entry.get("path") == "package.json":
            required = entry.get("required_scripts", [])
            break

    scripts = data.get("scripts", {})
    missing = [s for s in required if s not in scripts]
    if not missing:
        return ["_None._"]
    return [f"- `package.json`: missing scripts `{', '.join(missing)}`"]


# ---- Settings drift ---------------------------------------------------------

def fmt(v) -> str:
    if isinstance(v, list):
        return ", ".join(v) if v else "[]"
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def diff_row(rows: list[str], key: str, expected, actual) -> int:
    """Append a row if expected != actual. Return 1 if drift, else 0."""
    # Normalize: lists compared sorted; bool actual may come as bool or string.
    if isinstance(expected, list):
        actual_norm = sorted(actual) if isinstance(actual, list) else actual
        if expected == actual_norm:
            return 0
    elif expected == actual:
        return 0
    rows.append(f"| {key} | `{fmt(expected)}` | `{fmt(actual)}` |")
    return 1


def audit_settings(target_repo: str) -> list[str]:
    out: list[str] = ["## Settings drift", ""]

    actions_perms = gh_api(f"repos/{target_repo}/actions/permissions") or {}
    selected = gh_api(f"repos/{target_repo}/actions/permissions/selected-actions") or {}
    workflow_perms = gh_api(f"repos/{target_repo}/actions/permissions/workflow") or {}
    repo_root = gh_api(f"repos/{target_repo}") or {}
    vuln = gh_api(f"repos/{target_repo}/private-vulnerability-reporting") or {}
    css = gh_api(f"repos/{target_repo}/code-scanning/default-setup") or {}

    # actions section
    rows: list[str] = []
    canon = CANONICAL_SETTINGS["actions"]
    drift = 0
    drift += diff_row(rows, "default_workflow_permissions",
                      canon["default_workflow_permissions"],
                      workflow_perms.get("default_workflow_permissions", "unknown"))
    drift += diff_row(rows, "can_approve_pull_request_reviews",
                      canon["can_approve_pull_request_reviews"],
                      workflow_perms.get("can_approve_pull_request_reviews", "unknown"))
    drift += diff_row(rows, "allowed_actions",
                      canon["allowed_actions"],
                      actions_perms.get("allowed_actions", "unknown"))
    drift += diff_row(rows, "github_owned_allowed",
                      canon["github_owned_allowed"],
                      selected.get("github_owned_allowed", "unknown"))
    drift += diff_row(rows, "verified_allowed",
                      canon["verified_allowed"],
                      selected.get("verified_allowed", "unknown"))
    drift += diff_row(rows, "patterns_allowed",
                      canon["patterns_allowed"],
                      selected.get("patterns_allowed", []))
    out.append("### actions")
    out.append("")
    out.append("| key | canonical | actual |")
    out.append("|---|---|---|")
    out.extend(rows or ["| _no drift_ | | |"])
    out.append("")

    # security section
    rows = []
    canon = CANONICAL_SETTINGS["security"]
    ssa = repo_root.get("security_and_analysis", {}) or {}
    drift = 0
    for key in ("secret_scanning", "secret_scanning_push_protection",
                "secret_scanning_non_provider_patterns",
                "secret_scanning_validity_checks",
                "dependabot_security_updates"):
        actual = (ssa.get(key) or {}).get("status", "unknown")
        drift += diff_row(rows, key, canon[key], actual)
    vuln_state = "enabled" if vuln.get("enabled") is True else (
        "disabled" if vuln.get("enabled") is False else "unknown")
    drift += diff_row(rows, "private_vulnerability_reporting",
                      canon["private_vulnerability_reporting"], vuln_state)
    state = css.get("state", "unknown")
    css_actual = {"configured": "enabled", "not-configured": "disabled"}.get(state, state)
    drift += diff_row(rows, "code_scanning_default_setup",
                      canon["code_scanning_default_setup"], css_actual)
    out.append("### security")
    out.append("")
    out.append("| key | canonical | actual |")
    out.append("|---|---|---|")
    out.extend(rows or ["| _no drift_ | | |"])
    out.append("")

    # general section
    rows = []
    canon = CANONICAL_SETTINGS["general"]
    drift = 0
    for key, expected in canon.items():
        drift += diff_row(rows, key, expected, repo_root.get(key, "unknown"))
    out.append("### general")
    out.append("")
    out.append("| key | canonical | actual |")
    out.append("|---|---|---|")
    out.extend(rows or ["| _no drift_ | | |"])
    out.append("")

    return out


# ---- Main -------------------------------------------------------------------

def main() -> int:
    target = Path(sys.argv[1] if len(sys.argv) > 1 else os.getcwd()).resolve()
    target_repo, flavor = detect_target(target)

    manifest = gh_api(f"repos/{BASE_REPO}/contents/.claude/skills/repo-template-audit/manifest.json")
    if not manifest or "content" not in manifest:
        sys.exit("error: could not fetch canonical manifest from base template")
    manifest = json.loads(base64.b64decode(manifest["content"]))

    print(f"# Audit report: `{target_repo}` (flavor: {flavor})")
    print()
    print(f"_Local path: `{target}`_")
    print(f"_Canonical sources: `{BASE_REPO}` + `{ASTRO_REPO}`_")
    print()
    print("\n".join(audit_files(target, flavor, manifest)))
    print("\n".join(audit_settings(target_repo)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
