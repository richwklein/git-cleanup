#!/bin/bash

# Color definitions
NO_COLOR='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# Print informational messages
info_echo() {
    printf "%b%s%b\n" "$YELLOW" "$1" "$NO_COLOR"
}

# Print error messages
error_echo() {
    printf "%b%s%b\n" "$RED" "$1" "$NO_COLOR" >&2
}

usage() {
    echo "Usage: $0 [-d directory] [-u] [-m]"
}

# Parse command-line arguments
while getopts "d:u:m" opt; do
  case $opt in
    d) DIRECTORY="$OPTARG" ;;
    u) DELETE_UNTRACKED=true ;;
    m) CHECKOUT_MAIN=true ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# Default values
DIRECTORY=${DIRECTORY:-.}
DELETE_UNTRACKED=${DELETE_UNTRACKED:-false}
CHECKOUT_MAIN=${CHECKOUT_MAIN:-false}

# Determine the main branch dynamically
detect_main_branch() {
    local main_branch
    main_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    main_branch=${main_branch#origin/}

    if [ -n "$main_branch" ]; then
        echo "$main_branch"
    elif git show-ref --verify --quiet refs/heads/main; then
        echo "main"
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
    else
        echo "main"
    fi
}

# Function to iterate through directories and clean repositories
iterate_directories() {
    info_echo "Checking projects in $DIRECTORY..."

    local is_bare
    is_bare=$(git -C "$DIRECTORY" rev-parse --is-bare-repository 2>/dev/null)

    if [ "$is_bare" = "true" ]; then
        cd "$DIRECTORY" || exit 1
        info_echo "Processing bare repo $(pwd)."
        clean_bare_repository
        return
    fi

    if git -C "$DIRECTORY" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        cd "$DIRECTORY" || exit 1
        info_echo "Processing $(git rev-parse --show-toplevel)."
        clean_repository
        return
    fi

    # Process regular repos via their .git directory
    find "$DIRECTORY" -type d -name ".git" | while read -r gitdir; do
        local repo
        repo=$(dirname "$gitdir")
        cd "$repo" || continue
        info_echo "Processing $repo."
        clean_repository
        cd - >/dev/null || exit
    done

    # Process bare repos — check each direct subdirectory
    find "$DIRECTORY" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        local subdir_is_bare
        subdir_is_bare=$(git -C "$subdir" rev-parse --is-bare-repository 2>/dev/null)
        if [ "$subdir_is_bare" = "true" ]; then
            cd "$subdir" || continue
            info_echo "Processing bare repo $subdir."
            clean_bare_repository
            cd - >/dev/null || exit
        fi
    done
}

# Function to clean a regular repository
clean_repository() {
    checkout_main_branch
    fetch_remotes
    prune_worktrees
    remove_deleted_worktrees
    remove_deleted_branches
    remove_merged_branches
    remove_untracked
    prune_local_objects
    check_stashes
}

# Function to clean a bare repository
clean_bare_repository() {
    fetch_remotes
    fast_forward_main
    prune_worktrees
    remove_deleted_worktrees
    remove_deleted_branches
    remove_merged_branches
    prune_local_objects
    check_stashes
}

# Checkout the main branch if specified
checkout_main_branch() {
    if [ "$CHECKOUT_MAIN" = true ]; then
        local main_branch
        main_branch=$(detect_main_branch)
        echo "Checking out the main branch ($main_branch)..."

        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ "$current_branch" = "$main_branch" ]; then
            return
        fi

        if is_branch_checked_out_elsewhere "$main_branch"; then
            error_echo "Cannot checkout $main_branch because it is checked out in another worktree."
            return
        fi

        if ! git checkout "$main_branch"; then
            error_echo "Failed to checkout the main branch."
        fi
    fi
}   

# Fetch remotes and prune branches
git_remotes() {
    git remote 2>/dev/null
}

fetch_remotes() {
    echo "Fetching remote changes and pruning removed branches..."
    # shellcheck disable=SC2046 # intentional word-splitting on remote names
    git fetch --prune $(git_remotes)
}

# Fast-forward main branch without checking it out (safe in bare repos and worktrees)
fast_forward_main() {
    local main_branch
    main_branch=$(detect_main_branch)
    echo "Fast-forwarding $main_branch..."
    git fetch origin "$main_branch:$main_branch" --ff-only 2>/dev/null \
        || error_echo "Could not fast-forward $main_branch (diverged or up to date)."
}

# Prune stale worktree metadata
prune_worktrees() {
    if git worktree list >/dev/null 2>&1; then
        echo "Pruning stale worktree metadata..."
        git worktree prune
    fi
}

checked_out_worktree_branches() {
    git worktree list --porcelain 2>/dev/null | sed -n 's/^branch refs\/heads\///p'
}

is_branch_checked_out() {
    local branch="$1"
    checked_out_worktree_branches | grep -Fxq "$branch"
}

is_branch_checked_out_elsewhere() {
    local branch="$1"
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    if [ "$branch" = "$current_branch" ]; then
        return 1
    fi

    is_branch_checked_out "$branch"
}

gone_tracking_branches() {
    git branch --format "%(refname:short) %(upstream:track)" | awk '$2 == "[gone]" {print $1}'
}

worktree_branches() {
    git worktree list --porcelain 2>/dev/null | awk '
        /^worktree / { path = substr($0, 10) }
        /^branch refs\/heads\// {
            branch = substr($0, 19)
            print path "\t" branch
        }
    '
}

remove_deleted_worktrees() {
    echo "Removing worktrees with deleted remote tracking..."
    local branches
    branches=$(gone_tracking_branches)

    if [[ -z "$branches" ]]; then
        return
    fi

    local current_worktree
    current_worktree=$(git rev-parse --show-toplevel 2>/dev/null || git rev-parse --absolute-git-dir 2>/dev/null)

    worktree_branches | while IFS=$'\t' read -r worktree branch; do
        if ! echo "$branches" | grep -Fxq "$branch"; then
            continue
        fi

        if [ "$worktree" = "$current_worktree" ]; then
            error_echo "Skipping $branch because it is checked out in the current worktree."
            continue
        fi

        echo "Removing worktree $worktree for deleted branch $branch..."
        if git worktree remove "$worktree"; then
            git branch -D "$branch"
        else
            error_echo "Failed to remove worktree $worktree for branch $branch."
        fi
    done
}

# Function to delete branches
delete_branches() {
    local branches="$1"
    if [[ -n "$branches" ]]; then
        echo "$branches" | while read -r branch; do
            if is_branch_checked_out "$branch"; then
                error_echo "Skipping $branch because it is checked out in a worktree."
                continue
            fi

            git branch -D "$branch"
        done
    fi
}

# Remove deleted branches
remove_deleted_branches() {
    echo "Removing local branches with deleted remote tracking..."
    local branches
    branches=$(gone_tracking_branches)
    delete_branches "$branches"
}

# Remove merged branches
remove_merged_branches() {
    echo "Removing merged local branches..."
    local main_branch
    main_branch=$(detect_main_branch)
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    local branches
    branches=$(git branch --format "%(refname:short)" --merged "$main_branch" | grep -Fvx -e "$main_branch" -e "$current_branch")
    delete_branches "$branches"
}

# Prune orphaned objects
prune_local_objects() {
    echo "Removing orphaned objects..."
    git prune --progress
}

# Remove untracked branches
remove_untracked() {
    if [ "$DELETE_UNTRACKED" = true ]; then
        echo "Removing untracked branches..."
        local branches
        branches=$(git branch --format "%(refname:short)" --no-merged)
        delete_branches "$branches"
    fi
}

# Check for stashes
check_stashes() {
    echo "Checking for old stashes..."
    if git stash list | grep -q 'stash@'; then
        error_echo "Stashes found. Consider cleaning them manually."
    fi
}

iterate_directories
