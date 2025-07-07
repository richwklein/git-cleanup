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

# Parse command-line arguments
while getopts "d:u:m" opt; do
  case $opt in
    d) DIRECTORY="$OPTARG" ;;
    u) DELETE_UNTRACKED=true ;;
    m) CHECKOUT_MAIN=true ;;
    *)
      echo "Usage: $0 [-d directory] [-u]"
      exit 1
      ;;
  esac
done

# Default values
DIRECTORY=${DIRECTORY:-.}
DELETE_UNTRACKED=${DELETE_UNTRACKED:false}
CHECKOUT_MAIN=${CHECKOUT_MAIN:false}

# Determine the main branch dynamically
detect_main_branch() {
    git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# Function to iterate through directories and clean repositories
iterate_directories() {
    info_echo "Checking projects in $DIRECTORY..."
    cd "$DIRECTORY" || exit 1

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        info_echo "Processing $DIRECTORY."
        clean_repository
    else
        find "$DIRECTORY" -type d -name ".git" | while read -r gitdir; do
            repo=$(dirname "$gitdir")
            cd "$repo" || continue
            info_echo "Processing $repo."
            clean_repository
            cd - || exit
        done
    fi
}

# Function to clean a repository
clean_repository() {
    checkout_main_branch
    fetch_remotes
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
        echo "Checking out the main branch ($main_branch)..."

        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ "$current_branch" = "$main_branch" ]; then
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
    git fetch --prune $(git_remotes)
}

# Function to delete branches
delete_branches() {
    local branches="$1"
    if [[ -n "$branches" ]]; then
        echo "$branches" | while read -r branch; do
            git branch -D "$branch"
        done
    fi
}

# Remove deleted branches
remove_deleted_branches() {
    echo "Removing local branches with deleted remote tracking..."
    local branches
    branches=$(git branch --format "%(refname:short) %(upstream:track)" | awk '$2 == "[gone]" {print $1}')
    delete_branches "$branches"
}

# Remove merged branches
remove_merged_branches() {
    echo "Removing merged local branches..."
    local main_branch
    main_branch=$(detect_main_branch)
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD)
    local branches
    branches=$(git branch --merged "$main_branch" | sed 's/^ *//g' | grep -v -e "$main_branch" -e "$current_branch")
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
        branches=$(git branch --no-merged)
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
