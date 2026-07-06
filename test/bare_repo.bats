#!/usr/bin/env bats
# Tests for bare repository cleanup

setup() {
    load helpers
    setup_bare_repo
}

@test "fast-forwards main when remote is ahead" {
    # Push a new commit to remote from a separate clone
    local pusher="$BATS_TEST_TMPDIR/pusher"
    git clone "$REMOTE_DIR" "$pusher"
    git -C "$pusher" config user.email "test@test.com"
    git -C "$pusher" config user.name "Test"
    git -C "$pusher" config commit.gpgsign false
    git -C "$pusher" commit --allow-empty -m "remote advance"
    git -C "$pusher" push origin main
    local remote_sha
    remote_sha=$(git -C "$pusher" rev-parse HEAD)

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    local local_sha
    local_sha=$(git -C "$REPO_DIR" rev-parse main)
    [ "$local_sha" = "$remote_sha" ]
}

@test "fast-forwards main when it has no worktree" {
    git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR"

    # Push a new commit to remote from a separate clone
    local pusher="$BATS_TEST_TMPDIR/pusher"
    git clone "$REMOTE_DIR" "$pusher"
    git -C "$pusher" config user.email "test@test.com"
    git -C "$pusher" config user.name "Test"
    git -C "$pusher" config commit.gpgsign false
    git -C "$pusher" commit --allow-empty -m "remote advance"
    git -C "$pusher" push origin main
    local remote_sha
    remote_sha=$(git -C "$pusher" rev-parse HEAD)

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    local local_sha
    local_sha=$(git -C "$REPO_DIR" rev-parse main)
    [ "$local_sha" = "$remote_sha" ]
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

@test "removes worktree for a branch deleted on the remote" {
    create_remote_branch "feature/gone"
    local wt_path="$REPO_DIR/feature-gone"
    git -C "$REPO_DIR" worktree add "$wt_path" "feature/gone"
    delete_remote_branch "feature/gone"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    [ ! -d "$wt_path" ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "removes worktree for a merged branch still on the remote" {
    create_remote_branch "feature/merged"
    git -C "$WORKTREE_DIR" merge "feature/merged"
    git -C "$WORKTREE_DIR" push origin main
    local wt_path="$REPO_DIR/feature-merged"
    git -C "$REPO_DIR" worktree add "$wt_path" "feature/merged"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    [ ! -d "$wt_path" ]
    run git -C "$REPO_DIR" branch --list "feature/merged"
    [ -z "$output" ]
}

@test "keeps a dirty worktree for a merged branch" {
    create_remote_branch "feature/merged"
    git -C "$WORKTREE_DIR" merge "feature/merged"
    git -C "$WORKTREE_DIR" push origin main
    local wt_path="$REPO_DIR/feature-merged"
    git -C "$REPO_DIR" worktree add "$wt_path" "feature/merged"
    echo "uncommitted" > "$wt_path/leftover"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
    run git -C "$REPO_DIR" branch --list "feature/merged"
    [ -n "$output" ]
}

@test "adds fetch refspec to a stock bare clone so gone branches are cleaned" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"

    # Simulate a stock 'git clone --bare': no fetch refspec, no remote-tracking refs
    git -C "$REPO_DIR" config --unset-all remote.origin.fetch
    git -C "$REPO_DIR" symbolic-ref --delete refs/remotes/origin/HEAD 2>/dev/null || true
    git -C "$REPO_DIR" for-each-ref 'refs/remotes' --format='%(refname)' | while read -r ref; do
        git -C "$REPO_DIR" update-ref -d "$ref"
    done

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" config --get remote.origin.fetch
    [ -n "$output" ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "prunes gone branches when multiple remotes exist" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"
    git -C "$REPO_DIR" remote add backup "$REMOTE_DIR"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "skips worktree removal for currently checked-out branch" {
    create_remote_branch "feature/current"
    local wt_path="$REPO_DIR/feature-current"
    git -C "$REPO_DIR" worktree add "$wt_path" "feature/current"
    delete_remote_branch "feature/current"

    # Run the script from inside the worktree being deleted
    run bash "$SCRIPT" -d "$wt_path"

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "scans subdirectories and finds bare repo" {
    create_remote_branch "feature/gone"
    delete_remote_branch "feature/gone"

    run bash "$SCRIPT" -d "$BATS_TEST_TMPDIR"

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "feature/gone"
    [ -z "$output" ]
}

@test "-m flag is accepted and has no effect on bare repo" {
    run bash "$SCRIPT" -d "$REPO_DIR" -m

    [ "$status" -eq 0 ]
}

@test "warns about stashes in a worktree" {
    echo "dirty" > "$WORKTREE_DIR/dirty-file"
    git -C "$WORKTREE_DIR" add dirty-file
    git -C "$WORKTREE_DIR" stash push -m "test stash"

    run bash "$SCRIPT" -d "$REPO_DIR"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Stashes found"* ]]
}

@test "-u flag removes untracked local branches" {
    git -C "$WORKTREE_DIR" checkout -b local-only
    git -C "$WORKTREE_DIR" commit --allow-empty -m "local work"
    git -C "$WORKTREE_DIR" checkout main

    run bash "$SCRIPT" -d "$REPO_DIR" -u

    [ "$status" -eq 0 ]
    run git -C "$REPO_DIR" branch --list "local-only"
    [ -z "$output" ]
}
