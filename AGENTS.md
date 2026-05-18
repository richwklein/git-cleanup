# Repository Instructions

These instructions apply to any agent (Claude Code, Copilot, etc.) working in repositories generated from this template.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. The release workflow (release-please) parses these to generate changelogs and version bumps.

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `style`.

Breaking changes: append `!` after the type (e.g., `feat!: rename public API`) or add a `BREAKING CHANGE:` footer.

## Branching

- `main` is the default branch and is protected by a ruleset.
- All work happens in feature branches merged via pull request.
- Squash or rebase merges only — no merge commits.
- Branches must be up to date with `main` before merging (`strict_required_status_checks_policy`).

## Required local checks

Before pushing, the workflows that gate merge are `lint`, `test`, and `analyze` (CodeQL). Repos generated from `repo-template-astro` have lint and test commands wired into `package.json`; reach for those first.

## Drift audit

Run `/repo-template-audit` from this repo's directory to check that template-tracked files and GitHub repo settings still match the canonical sources in `richwklein/repo-template-base`.
