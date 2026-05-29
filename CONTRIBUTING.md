# Contributing

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/). The release workflow (release-please) parses commit messages to generate changelogs and version bumps.

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `style`.

Breaking changes: append `!` (e.g., `feat!: rename public API`) or include a `BREAKING CHANGE:` footer.

Examples:

```
feat(auth): add SSO sign-in
fix: stop crashing on empty search results
chore(deps): bump astro to 6.2.0
docs: clarify deployment steps
```

## Branching and PRs

- `main` is protected by a ruleset.
- Work happens on feature branches. PRs only — no direct pushes to `main`.
- Merges must be squash or rebase. No merge commits.
- Branch must be up to date with `main` before merging (strict status checks).
- Commits must be signed (SSH or GPG signing required by ruleset).

## Verify commits are signed

```
git log --show-signature -1
```

If the signature line is missing, the commit will be rejected at merge by the ruleset.
