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

# Print sub-operation messages suppressed by -q
verbose_echo() {
    if [ "$QUIET" = false ]; then
        echo "$1"
    fi
}

# Colorize git diagnostic lines from a command's combined output.
# error:/fatal: (incl. remote: variants) -> RED; warning: -> YELLOW.
highlight_stream() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^(remote:[[:space:]]*)?(error|fatal): ]]; then
            printf "%b%s%b\n" "$RED" "$line" "$NO_COLOR" >&2
        elif [[ "$line" =~ ^(remote:[[:space:]]*)?warning: ]]; then
            printf "%b%s%b\n" "$YELLOW" "$line" "$NO_COLOR" >&2
        else
            printf "%s\n" "$line"
        fi
    done
}

# Run a command, streaming its combined output through the error highlighter
# while preserving the command's own exit status.
run_highlighted() (
    set -o pipefail
    "$@" 2>&1 | highlight_stream
)

usage() {
    echo "Usage: $0 [-d directory] [-u] [-m] [-q]"
}

# Parse command-line arguments
while getopts "d:umq" opt; do
  case $opt in
    d) DIRECTORY="$OPTARG" ;;
    u) DELETE_UNTRACKED=true ;;
    m) CHECKOUT_MAIN=true ;;
    q) QUIET=true ;;
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
QUIET=${QUIET:-false}

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

find_git_repo_roots() {
    local base="$1"
    local subdir
    for subdir in "$base"/*/; do
        [ -d "$subdir" ] || continue
        subdir="${subdir%/}"
        if [ -e "$subdir/.git" ]; then
            echo "$subdir"
        else
            find_git_repo_roots "$subdir"
        fi
    done
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

    find_git_repo_roots "$DIRECTORY" | while read -r repo; do
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
    ensure_fetch_refspecs
    fetch_remotes
    fast_forward_main
    prune_worktrees
    remove_deleted_worktrees
    remove_deleted_branches
    remove_merged_branches
    remove_untracked
    prune_local_objects
    check_stashes
}

# Checkout the main branch if specified
checkout_main_branch() {
    if [ "$CHECKOUT_MAIN" = true ]; then
        local main_branch
        main_branch=$(detect_main_branch)
        verbose_echo "Checking out the main branch ($main_branch)..."

        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ "$current_branch" = "$main_branch" ]; then
            return
        fi

        if is_branch_checked_out_elsewhere "$main_branch"; then
            error_echo "Cannot checkout $main_branch because it is checked out in another worktree."
            return
        fi

        if ! run_highlighted git checkout "$main_branch"; then
            error_echo "Failed to checkout the main branch."
        fi
    fi
}

# Fetch remotes and prune branches
git_remotes() {
    git remote 2>/dev/null
}

# A stock 'git clone --bare' has no fetch refspec, so remote-tracking refs
# never exist and gone-upstream detection cannot find deleted branches.
ensure_fetch_refspecs() {
    local remote
    for remote in $(git_remotes); do
        if [ -z "$(git config --get-all "remote.$remote.fetch")" ]; then
            verbose_echo "Adding missing fetch refspec for remote $remote."
            git config "remote.$remote.fetch" "+refs/heads/*:refs/remotes/$remote/*"
        fi
    done
}

fetch_remotes() {
    verbose_echo "Fetching remote changes and pruning removed branches..."
    run_highlighted git fetch --all --prune
}

# Fast-forward main branch without checking it out (safe in bare repos and worktrees)
fast_forward_main() {
    local main_branch
    main_branch=$(detect_main_branch)
    verbose_echo "Fast-forwarding $main_branch..."

    # If main is checked out in a worktree, pull from there — git refuses
    # to update a branch via fetch refspec while it is checked out elsewhere.
    local main_worktree
    main_worktree=$(git worktree list --porcelain | awk \
        -v ref="refs/heads/$main_branch" \
        '/^worktree / { path = substr($0, 10) } $0 == "branch " ref { print path; exit }')

    if [ -n "$main_worktree" ]; then
        git -C "$main_worktree" pull --ff-only origin "$main_branch" 2>/dev/null \
            || error_echo "Could not fast-forward $main_branch (diverged or up to date)."
    else
        # A refspec without a leading + already refuses non-fast-forward updates.
        git fetch origin "$main_branch:$main_branch" 2>/dev/null \
            || error_echo "Could not fast-forward $main_branch (diverged or up to date)."
    fi
}

# Prune stale worktree metadata
prune_worktrees() {
    if git worktree list >/dev/null 2>&1; then
        verbose_echo "Pruning stale worktree metadata..."
        run_highlighted git worktree prune
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

# Remove worktrees whose branch is in the given list, deleting the branch after
remove_worktrees_for_branches() {
    local branches="$1"

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

        verbose_echo "Removing worktree $worktree for branch $branch..."
        if run_highlighted git worktree remove "$worktree"; then
            run_highlighted git branch -D "$branch"
        else
            error_echo "Failed to remove worktree $worktree for branch $branch."
        fi
    done
}

remove_deleted_worktrees() {
    verbose_echo "Removing worktrees with deleted remote tracking..."
    remove_worktrees_for_branches "$(gone_tracking_branches)"
}

# Function to delete branches
delete_branches() {
    local branches="$1"
    if [[ -n "$branches" ]]; then
        echo "$branches" | while read -r branch; do
            # Branch may already be gone if its worktree was removed
            if ! git show-ref --verify --quiet "refs/heads/$branch"; then
                continue
            fi

            if is_branch_checked_out "$branch"; then
                error_echo "Skipping $branch because it is checked out in a worktree."
                continue
            fi

            run_highlighted git branch -D "$branch"
        done
    fi
}

# Remove deleted branches
remove_deleted_branches() {
    verbose_echo "Removing local branches with deleted remote tracking..."
    local branches
    branches=$(gone_tracking_branches)
    delete_branches "$branches"
}

# Remove merged branches
remove_merged_branches() {
    verbose_echo "Removing merged local branches..."
    local main_branch
    main_branch=$(detect_main_branch)

    # Prefer the remote-tracking ref as the merge base — it is current right
    # after the fetch, while local main may be stale.
    local merge_base="$main_branch"
    if git show-ref --verify --quiet "refs/remotes/origin/$main_branch"; then
        merge_base="origin/$main_branch"
    fi

    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    local branches
    branches=$(git branch --format "%(refname:short)" --merged "$merge_base" | grep -Fvx -e "$main_branch" -e "$current_branch")
    remove_worktrees_for_branches "$branches"
    delete_branches "$branches"
}

# Prune orphaned objects
prune_local_objects() {
    verbose_echo "Removing orphaned objects..."
    run_highlighted git prune --progress
}

# Remove local branches that do not track any remote branch
remove_untracked() {
    if [ "$DELETE_UNTRACKED" = true ]; then
        verbose_echo "Removing untracked branches..."
        local main_branch
        main_branch=$(detect_main_branch)
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        local branches
        branches=$(git branch --format "%(refname:short) %(upstream)" \
            | awk 'NF == 1 {print $1}' \
            | grep -Fvx -e "$main_branch" -e "$current_branch")
        delete_branches "$branches"
    fi
}

# Check for stashes
check_stashes() {
    verbose_echo "Checking for old stashes..."
    local stash_context="."
    local is_bare
    is_bare=$(git rev-parse --is-bare-repository 2>/dev/null)
    if [ "$is_bare" = "true" ]; then
        stash_context=$(git worktree list --porcelain 2>/dev/null | awk '
            /^worktree / { path = substr($0, 10) }
            /^branch /   { print path; exit }
        ')
        [ -z "$stash_context" ] && return
    fi
    if git -C "$stash_context" stash list 2>/dev/null | grep -q 'stash@'; then
        error_echo "Stashes found. Consider cleaning them manually."
    fi
}

iterate_directories

info_echo "Cleanup complete."
