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

### Branch prefixes

Name branches with a hyphen-delimited type prefix that mirrors the Conventional Commit type. The PR labeler workflow uses this prefix to apply the matching label automatically.

| Prefix                                                                                              | Label           |
| --------------------------------------------------------------------------------------------------- | --------------- |
| `feat-`, `feature-`                                                                                 | `enhancement`   |
| `fix-`, `bug-`, `bugfix-`                                                                           | `bug`           |
| `docs-`, `doc-`                                                                                     | `documentation` |
| `chore-`, `refactor-`, `test-`, `build-`, `ci-`, `perf-`, `style-`, `task-`, `maint-`, `maintenance-` | `task`        |

Example: `feature-add-search`, `fix-login-redirect`, `docs-readme-update`.

## Pull requests

This repo ships four PR templates aligned with the issue templates: `bug.md`, `enhancement.md`, `task.md`, `documentation.md` in `.github/PULL_REQUEST_TEMPLATE/`.

Pick one by appending `?template=<name>.md` to the compare URL, for example:

```
https://github.com/<owner>/<repo>/compare/main...<branch>?template=enhancement.md
```

Type labels (`bug`, `enhancement`, `task`, `documentation`) are applied automatically by the PR labeler workflow based on the branch prefix above. Apply `breaking-change` manually when a PR introduces a backwards-incompatible change.

## Required local checks

Before pushing, the workflows that gate merge are `lint`, `test`, and `analyze` (CodeQL). Repos generated from `repo-template-astro` have lint and test commands wired into `package.json`; reach for those first.

## Drift audit

Install the audit skill: `npx skills add richwklein/skills`

Run `/repo-template-audit richwklein/repo-template-base` to check that template-tracked files and GitHub repo settings still match the template.
