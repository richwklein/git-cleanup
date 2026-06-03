# Changelog

## [2.2.2](https://github.com/richwklein/git-cleanup/compare/v2.2.1...v2.2.2) (2026-06-03)


### Bug Fixes

* **nested-repos:** do not process repos nested inside a working tree ([#34](https://github.com/richwklein/git-cleanup/issues/34)) ([f8f7727](https://github.com/richwklein/git-cleanup/commit/f8f77275aa72e4e09c7fea3c5264c9706c444346))

## [2.2.1](https://github.com/richwklein/git-cleanup/compare/v2.2.0...v2.2.1) (2026-06-02)


### Bug Fixes

* **bare-repo:** correct flag parsing, stash check, and untracked removal ([#32](https://github.com/richwklein/git-cleanup/issues/32)) ([c2b2d70](https://github.com/richwklein/git-cleanup/commit/c2b2d70089f170988f6eab5557b6fe7b8f8f6f7e))

## [2.2.0](https://github.com/richwklein/git-cleanup/compare/v2.1.0...v2.2.0) (2026-05-28)


### Features

* add bare git repository support ([#30](https://github.com/richwklein/git-cleanup/issues/30)) ([57f2e1f](https://github.com/richwklein/git-cleanup/commit/57f2e1fdba3958bcef4b419aab709382b8c0bf42))


### Bug Fixes

* **release:** explicitly disable component in tag name ([#28](https://github.com/richwklein/git-cleanup/issues/28)) ([0994671](https://github.com/richwklein/git-cleanup/commit/099467137b0be91e4e117f12491487f420b1e544))

## [2.1.0](https://github.com/richwklein/git-cleanup/compare/v2.0.1...v2.1.0) (2026-05-22)


### Features

* **release:** use GitHub App token so release PRs trigger checks ([#22](https://github.com/richwklein/git-cleanup/issues/22)) ([e2cadbe](https://github.com/richwklein/git-cleanup/commit/e2cadbecd4714297dfbab3cbe1af331cad480889))

## [2.0.1](https://github.com/richwklein/git-cleanup/compare/v2.0.0...v2.0.1) (2026-05-08)

### Miscellaneous Changes

- bump actions/checkout from 4 to 6 in the github-actions group ([#18](https://github.com/richwklein/git-cleanup/pull/18)) ([5274eef](https://github.com/richwklein/git-cleanup/commit/5274eef))

## [2.0.0](https://github.com/richwklein/git-cleanup/compare/v1.1.0...v2.0.0) (2026-05-04)

### ⚠ BREAKING CHANGES

- Stale worktrees for deleted branches are now removed automatically during cleanup.

### Features

- remove worktrees for deleted branches ([#17](https://github.com/richwklein/git-cleanup/pull/17)) ([53e3a27](https://github.com/richwklein/git-cleanup/commit/53e3a27))

## [1.1.0](https://github.com/richwklein/git-cleanup/compare/v1.0.0...v1.1.0) (2026-05-04)

### Features

- add git worktree cleanup support ([#15](https://github.com/richwklein/git-cleanup/pull/15)) ([f7b4dda](https://github.com/richwklein/git-cleanup/commit/f7b4dda))

## [1.0.0](https://github.com/richwklein/git-cleanup/commits/v1.0.0) (2026-05-04)

### Features

- add the cleanup script ([#1](https://github.com/richwklein/git-cleanup/pull/1)) ([9328f98](https://github.com/richwklein/git-cleanup/commit/9328f98))
- add option to check out the main branch ([#11](https://github.com/richwklein/git-cleanup/pull/11)) ([a32801b](https://github.com/richwklein/git-cleanup/commit/a32801b))

### Bug Fixes

- correct branch argument passing ([#10](https://github.com/richwklein/git-cleanup/pull/10)) ([1f3d825](https://github.com/richwklein/git-cleanup/commit/1f3d825))

### Miscellaneous Changes

- update repo config ([#2](https://github.com/richwklein/git-cleanup/pull/2)) ([1964973](https://github.com/richwklein/git-cleanup/commit/1964973))
- switch shell ([#3](https://github.com/richwklein/git-cleanup/pull/3)) ([e54f777](https://github.com/richwklein/git-cleanup/commit/e54f777))
- updated script ([#8](https://github.com/richwklein/git-cleanup/pull/8)) ([8ac98a1](https://github.com/richwklein/git-cleanup/commit/8ac98a1))
- improve logging around checking out the main branch ([#13](https://github.com/richwklein/git-cleanup/pull/13)) ([5116291](https://github.com/richwklein/git-cleanup/commit/5116291))
- change interval for dependabot PRs ([#14](https://github.com/richwklein/git-cleanup/pull/14)) ([88386fd](https://github.com/richwklein/git-cleanup/commit/88386fd))
- add release tagging workflow ([#16](https://github.com/richwklein/git-cleanup/pull/16)) ([2dd7ba0](https://github.com/richwklein/git-cleanup/commit/2dd7ba0))
