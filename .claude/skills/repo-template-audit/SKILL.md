---
name: repo-template-audit
description: Compare the current repo against richwklein/repo-template-base (and repo-template-astro if applicable) plus the canonical GitHub repo settings manifest, then surface drift. Use when the user runs /repo-template-audit, asks to check template drift, or wants to verify GitHub repo settings against the canonical baseline.
---

# repo-template-audit

Audits a target repo against canonical sources:

1. **File drift**: tracked files (issue templates, workflows, configs, docs) compared against `richwklein/repo-template-base`. If the target has `astro.config.*`, files listed in the manifest's `astro` flavor are compared against `richwklein/repo-template-astro` instead (astro overrides base).
2. **Settings drift**: GitHub repo-level configuration (Actions permissions, advanced security, general settings) compared against the canonical values mirrored in `lib/audit.py` / `docs/REPO_SETTINGS.yaml`.

## Invocation

The user types `/repo-template-audit [path]`. When invoked:

1. Resolve the target path. Default to the current working directory if no path is given.
2. Run the audit script:

   ```bash
   python3 .claude/skills/repo-template-audit/lib/audit.py [path]
   ```

   The script must run from inside the target repo (it uses `git -C` to resolve the origin remote and detect flavor). For audits of other repos, pass an absolute path.

3. Read the script's markdown output. Present the findings to the user, grouped by section.

## Interpreting output

The script emits four kinds of findings:

- **Missing files**: present in the template manifest but absent in the target. Almost always real drift to fix.
- **Drifted files**: present locally but differ from canonical. Inspect each diff before proposing a fix — some drift is intentional and should become a `.github/repo-settings-override.yaml` entry (overrides feature: planned, not yet implemented).
- **Schema gaps**: required `package.json` scripts or other typed checks failed. Real drift.
- **Settings drift**: GitHub repo settings differ from canonical. The audit emits a table; remediation is via `gh api` calls.

## Remediating

After presenting findings, offer to fix items one section at a time. The user confirms each batch.

### File fixes

For drifted or missing files, use the `gh` CLI to fetch the canonical content and overwrite locally:

```bash
gh api repos/richwklein/repo-template-{base,astro}/contents/<path> \
  --jq '.content' | base64 -d > <path>
```

Then open a PR with the change. Commit message convention: `chore(audit): sync <files> with template`.

### Settings fixes

Each table row maps to a specific API endpoint. Common patches:

```bash
# Actions: workflow permissions
gh api --method PUT repos/<owner>/<repo>/actions/permissions/workflow \
  -F default_workflow_permissions=write -F can_approve_pull_request_reviews=true

# Actions: allowed_actions selection
gh api --method PUT repos/<owner>/<repo>/actions/permissions \
  -F enabled=true -F allowed_actions=selected

# Actions: selected-actions list
gh api --method PUT repos/<owner>/<repo>/actions/permissions/selected-actions \
  -F github_owned_allowed=true -F verified_allowed=true \
  -f 'patterns_allowed[]=googleapis/release-please-action@*' \
  -f 'patterns_allowed[]=github/codeql-action/*@*' \
  -f 'patterns_allowed[]=davelosert/vitest-coverage-report-action@*' \
  -f 'patterns_allowed[]=marocchino/sticky-pull-request-comment@*'

# Security toggles (live in repo PATCH body under security_and_analysis)
gh api --method PATCH repos/<owner>/<repo> \
  --raw-field 'security_and_analysis[secret_scanning][status]=enabled' \
  --raw-field 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
  --raw-field 'security_and_analysis[dependabot_security_updates][status]=enabled'

# Dependabot alerts (separate endpoint)
gh api --method PUT repos/<owner>/<repo>/vulnerability-alerts

# Private vulnerability reporting (separate endpoint)
gh api --method PUT repos/<owner>/<repo>/private-vulnerability-reporting

# General merge / web-commit settings (on the repo root)
gh api --method PATCH repos/<owner>/<repo> \
  -F allow_merge_commit=false -F allow_rebase_merge=false \
  -F allow_auto_merge=false -F allow_update_branch=false \
  -F web_commit_signoff_required=true
```

## Self-audit

The skill's own files (`SKILL.md`, `manifest.json`, `lib/audit.py`) are tracked in the manifest. Running the audit against a repo with an older copy of the skill flags it as drifted, so the skill keeps itself current across descendants.

## Implementation notes

- Canonical settings in `lib/audit.py` mirror `docs/REPO_SETTINGS.yaml`. Both files are tracked exactly in the manifest, so any drift between them surfaces in File drift on the next audit run. Update both files together.
- The script fetches the manifest from `richwklein/repo-template-base` on every run via `gh api`. No caching. Audits always reflect the _current_ canonical template.
- `code_scanning_default_setup` is read from `GET /repos/{o}/{r}/code-scanning/default-setup` (not the main repo endpoint). The script normalizes its `configured` / `not-configured` states to `enabled` / `disabled` for comparison.

## Flavor detection (`repo_flavor`)

Every descendant repo's local `manifest.json` carries a top-level `repo_flavor` field declaring its flavor (`"base"` or `"astro"`). The audit reads this field first and uses it as the authoritative flavor. If absent or invalid, the script falls back to detecting `astro.config.*` presence.

The `repo_flavor` field is the **only** key in `manifest.json` that's allowed to differ from canonical — every other key must match the base template byte-for-byte. The audit excludes `repo_flavor` from the manifest exact-match comparison.

When migrating an existing repo into the standardization (Phase 6 of the plan), copy the manifest from the appropriate template and set `repo_flavor` to match:

- Repos following `repo-template-base` only: `"repo_flavor": "base"`
- Repos following `repo-template-astro`: `"repo_flavor": "astro"`
