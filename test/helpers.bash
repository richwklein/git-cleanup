#!/usr/bin/env bash
# Shared test helpers

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/git_cleanup.sh"

# Create a bare remote repo and a local bare clone with a main worktree.
# Sets: REMOTE_DIR, REPO_DIR, WORKTREE_DIR
setup_bare_repo() {
    local name="${1:-repo}"

    REMOTE_DIR="$BATS_TEST_TMPDIR/remote-$name"
    git init --bare "$REMOTE_DIR"

    # Seed the remote with an initial commit so HEAD resolves
    local seed="$BATS_TEST_TMPDIR/seed-$name"
    git clone "$REMOTE_DIR" "$seed"
    git -C "$seed" config user.email "test@test.com"
    git -C "$seed" config user.name "Test"
    git -C "$seed" config commit.gpgsign false
    git -C "$seed" commit --allow-empty -m "init"
    git -C "$seed" push origin main
    rm -rf "$seed"

    REPO_DIR="$BATS_TEST_TMPDIR/$name"
    git clone --bare "$REMOTE_DIR" "$REPO_DIR"
    git -C "$REPO_DIR" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git -C "$REPO_DIR" fetch origin

    WORKTREE_DIR="$REPO_DIR/main"
    git -C "$REPO_DIR" worktree add "$WORKTREE_DIR"
    git -C "$WORKTREE_DIR" config user.email "test@test.com"
    git -C "$WORKTREE_DIR" config user.name "Test"
    git -C "$WORKTREE_DIR" config commit.gpgsign false
}

# Create a regular (non-bare) local repo cloned from a bare remote.
# Sets: REMOTE_DIR, REPO_DIR
setup_regular_repo() {
    local name="${1:-repo}"

    REMOTE_DIR="$BATS_TEST_TMPDIR/remote-$name"
    git init --bare "$REMOTE_DIR"

    local seed="$BATS_TEST_TMPDIR/seed-$name"
    git clone "$REMOTE_DIR" "$seed"
    git -C "$seed" config user.email "test@test.com"
    git -C "$seed" config user.name "Test"
    git -C "$seed" config commit.gpgsign false
    git -C "$seed" commit --allow-empty -m "init"
    git -C "$seed" push origin main
    rm -rf "$seed"

    REPO_DIR="$BATS_TEST_TMPDIR/$name"
    git clone "$REMOTE_DIR" "$REPO_DIR"
    git -C "$REPO_DIR" config user.email "test@test.com"
    git -C "$REPO_DIR" config user.name "Test"
    git -C "$REPO_DIR" config commit.gpgsign false
}

# Push a new branch to REMOTE_DIR and create it locally in REPO_DIR.
create_remote_branch() {
    local branch="$1"
    local base_dir="${2:-${WORKTREE_DIR:-$REPO_DIR}}"
    git -C "$base_dir" config commit.gpgsign false
    git -C "$base_dir" checkout -b "$branch"
    git -C "$base_dir" commit --allow-empty -m "work on $branch"
    git -C "$base_dir" push -u origin "$branch"
    git -C "$base_dir" checkout main 2>/dev/null || git -C "$base_dir" checkout -
}

# Delete a branch from REMOTE_DIR (simulates a merged/closed PR).
delete_remote_branch() {
    local branch="$1"
    git -C "$REMOTE_DIR" branch -D "$branch"
}
