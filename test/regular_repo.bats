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

@test "scans subdirectories when given a parent directory" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"

    run bash "$SCRIPT" -d "$BATS_TEST_TMPDIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}
