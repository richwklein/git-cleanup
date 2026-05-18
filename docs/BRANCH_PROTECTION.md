# Branch protection

Repos generated from this template protect `main` with a [repository ruleset](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets), not classic branch protection. Apply it after the first PR has run so the status check contexts (`lint`, `test`, `analyze`) are registered.

## Canonical ruleset

```json
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "required_signatures" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "lint" },
          { "context": "test" },
          { "context": "analyze" }
        ]
      }
    }
  ],
  "bypass_actors": []
}
```

## Apply

1. Save the ruleset JSON above to `ruleset.json` and adjust `required_status_checks` to match what this repo actually runs.

   **Matrix jobs register one check per variant.** `code-codeql.yaml` uses a matrix, so the check appears as `analyze (<language>)` — not `analyze`. List the variants your matrix actually produces:
   - Repo with `language: ['actions']` → `analyze (actions)`
   - Repo with `language: ['actions', 'javascript-typescript']` → both `analyze (actions)` and `analyze (javascript-typescript)`

   Drop `test`/`lint` contexts for repos without those workflows (e.g., `git-cleanup`, the base template repo).

2. Apply via `gh`:

   ```bash
   gh api --method POST repos/<owner>/<repo>/rulesets --input ruleset.json
   ```

3. Verify:

   ```bash
   gh api repos/<owner>/<repo>/rulesets
   ```

## Update an existing ruleset

```bash
# Find the ruleset id
gh api repos/<owner>/<repo>/rulesets

# Update by id
gh api --method PUT repos/<owner>/<repo>/rulesets/<id> --input ruleset.json
```

## Migrating from classic branch protection

1. Confirm the new ruleset is active and the required check contexts match what workflows emit.
2. Delete the classic protection rule from **Settings → Branches** in the GitHub UI, or via:

   ```bash
   gh api --method DELETE repos/<owner>/<repo>/branches/main/protection
   ```

3. Push a no-op PR to confirm the ruleset blocks the same things classic protection used to (direct pushes, missing checks, missing signatures).

## Per-repo overrides

Some repos legitimately need different checks (e.g., `git-cleanup` has no `test` or `analyze`). Adjust the `required_status_checks` array per repo; the audit skill respects an optional `.github/repo-settings-override.yaml` for intentional drift.
