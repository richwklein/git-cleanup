# git-cleanup

Script for cleanup of local git working directories.

## Description

The `git_cleanup.sh` script is designed to help you clean up your local Git repositories. It supports both regular repositories and bare repositories (used with the git worktree workflow). It performs the following tasks:

- Fetches updates from remote repositories and prunes any remote-tracking references that no longer exist on the remote.
- Fast-forwards the main branch to the latest remote commit without requiring a checkout. *(bare repos)*
- Optionally checks out the main branch before cleanup. [-m] *(regular repos only)*
- Removes linked worktrees whose checked-out branch has been deleted on the remote or merged into the main branch.
- Removes local branches that have been deleted on the remote.
- Removes local branches that have been merged into the main branch (checked against the remote-tracking ref when available, so a stale local main does not hide fresh merges).
- Skips branches that are currently checked out in any linked Git worktree.
- Prunes stale Git worktree metadata.
- Prunes orphaned objects from the local repository.
- Checks for old stashes and notifies if any are found.
- Optionally removes untracked branches — local branches that do not track any remote branch. [-u]

## Usage

You can run the script with the following options:

```sh
Usage: ./git_cleanup.sh [-d directory] [-u] [-m] [-q]
```

- -d directory: Specify the directory to clean up. Defaults to the current directory (.).
- -u: Removes local branches that do not track any remote branch. The main branch and the currently checked-out branch are never removed.
- -m: Checks out the main branch before cleanup when possible.
- -q: Quiet mode. Suppresses sub-operation progress messages; only top-level repository headers and errors are printed.

### Behavior

**Directory detection**

If the specified directory is a bare repository, the script cleans it directly. If the directory is inside a regular Git working tree (including a linked worktree), the script cleans that repository. Otherwise the script scans direct subdirectories: subdirectories containing a `.git` directory are treated as regular repositories; subdirectories that are bare repositories are cleaned as bare repos. Each repository is processed once regardless of how many linked worktrees it has.

**Bare repositories**

Bare repos have no working tree, so `checkout_main_branch` is skipped. Instead, the script fast-forwards the main branch directly using a fetch refspec (`git fetch origin main:main`), keeping it current without requiring a checkout; when the main branch is checked out in a linked worktree, the script pulls from that worktree instead. The `-m` flag is accepted but has no effect on bare repos.

A stock `git clone --bare` has no fetch refspec, so remote-tracking refs never exist and deleted remote branches cannot be detected. The script adds the standard refspec (`+refs/heads/*:refs/remotes/<remote>/*`) to any remote missing one before fetching.

**Worktree-aware branch deletion**

When a linked worktree has a checked-out branch whose remote tracking branch has been deleted, or that has been merged into the main branch, the script removes that worktree and deletes the local branch. Worktrees with uncommitted or untracked changes are left in place. If the affected branch is checked out in the current worktree, the script skips it because removing the directory it is running from is unsafe.

When deleting other branches, the script skips branches that are checked out by any worktree because Git does not allow those branches to be deleted. When `-m` is used from a worktree, the script also skips checking out the main branch if that branch is already checked out by another worktree.

### Examples

Using the current directory:

```sh
./git_cleanup.sh
```

Specifying a different directory (e.g., /path/to/dir)

```sh
./git_cleanup.sh -d /path/to/dir 
```

Cleaning untracked branches

```sh
./git_cleanup.sh -d /path/to/dir -u
```

Cleaning a bare repository

```sh
./git_cleanup.sh -d /path/to/bare-repo
```

Cleaning a projects directory containing a mix of regular and bare repositories

```sh
./git_cleanup.sh -d /path/to/projects
```

## Creating a Command Line Alias

If all your GitHub repositories are stored in a single directory, it can be helpful to create a command line alias to run this script easily. Here is an example of how to define an alias in your `.zshrc` file:

```sh
alias cleanup="sh $PROJECTS/git-cleanup/git_cleanup.sh -d $PROJECTS"
```

In this example, `$PROJECTS` is an environment variable that you have set to the directory containing all your projects. This alias will run the [git_cleanup.sh](git_cleanup.sh) script from its checked-out location against the directory specified by `$PROJECTS`.

### Setting the Environment Variable

To set the `$PROJECTS` environment variable, add the following line to your .zshrc file (or .bashrc if you are using Bash):

```sh
export PROJECTS="/path/to/your/projects"
```

Replace "/path/to/your/projects" with the actual path to your projects directory. After adding this line, reload your shell configuration by running:

```sh
source ~/.zshrc
```

Now, you can use the cleanup alias to run the script against all your projects:

```sh
cleanup
```

This will execute the [git_cleanup.sh](./git_cleanup.sh) script on the directory specified by the `$PROJECTS` environment variable.

## Release Versioning

When a pull request is opened or updated, the release version workflow determines the next GitHub release tag. When the pull request merges into the default branch, the workflow creates that GitHub release. Add one of these labels to the pull request to control the version bump:

- `semver:major`: Bumps `v1.2.3` to `v2.0.0`.
- `semver:minor`: Bumps `v1.2.3` to `v1.3.0`.
- `semver:patch`: Bumps `v1.2.3` to `v1.2.4`.

If no semver label is present, the workflow defaults to a patch release.

## Disclaimer

This script has been cleaned up and improved using Large Language Models (LLMs) to ensure better readability, maintainability, and functionality. Please review the code and test it in your environment before using it in production.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
