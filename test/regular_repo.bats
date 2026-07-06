#!/usr/bin/env bats
# Tests for regular (non-bare) repository cleanup

setup() {
    load helpers
    setup_regular_repo
}

@test "removes a branch deleted on the remote" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "keeps a branch still on the remote" {
    create_remote_branch "feature/active"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/active"
    [ -n "$output" ]
}

@test "removes a merged branch" {
    git -C "$REPO_DIR" checkout -b "feature/merged"
    git -C "$REPO_DIR" commit --allow-empty -m "merged work"
    git -C "$REPO_DIR" push origin "feature/merged"
    git -C "$REPO_DIR" checkout main
    git -C "$REPO_DIR" merge "feature/merged"
    git -C "$REPO_DIR" push origin main

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/merged"
    [ -z "$output" ]
}

@test "removes a branch merged on the remote when local main is stale" {
    create_remote_branch "feature/merged"

    # Merge the branch into main on the remote from a separate clone,
    # leaving local main behind and the remote branch in place
    local pusher="$BATS_TEST_TMPDIR/pusher"
    git clone "$REMOTE_DIR" "$pusher"
    git -C "$pusher" config user.email "test@test.com"
    git -C "$pusher" config user.name "Test"
    git -C "$pusher" config commit.gpgsign false
    git -C "$pusher" merge "origin/feature/merged"
    git -C "$pusher" push origin main

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/merged"
    [ -z "$output" ]
}

@test "scans subdirectories when given a parent directory" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"

    run bash "$SCRIPT" -d "$BATS_TEST_TMPDIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "does not process a repo nested inside another repo's working tree" {
    create_remote_branch "feature/outer"
    delete_remote_branch "feature/outer"

    # Simulate a tool that creates a git repo inside the outer repo's working tree,
    # e.g. <repo>/<worktree>/parsimony/.git
    local nested_repo="$REPO_DIR/parsimony"
    git init "$nested_repo"
    git -C "$nested_repo" config user.email "test@test.com"
    git -C "$nested_repo" config user.name "Test"
    git -C "$nested_repo" config commit.gpgsign false
    git -C "$nested_repo" commit --allow-empty -m "init"
    git -C "$nested_repo" checkout -b "feature/nested-branch"

    run bash "$SCRIPT" -d "$BATS_TEST_TMPDIR"

    [ "$status" -eq 0 ]
    # Outer repo was cleaned
    run git -C "$REPO_DIR" branch --list "feature/outer"
    [ -z "$output" ]
    # Nested repo was not processed — its branch is intact
    run git -C "$nested_repo" branch --list "feature/nested-branch"
    [ -n "$output" ]
}
