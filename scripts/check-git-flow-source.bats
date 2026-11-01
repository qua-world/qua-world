#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

setup() {
    script="$BATS_TEST_DIRNAME/check-git-flow-source.sh"
}

@test "rejects a feature branch into master" {
    run "$script" master alunduil/worktree/inspired-kitten
    [ "$status" -eq 1 ]
    [[ "$output" == *"not alunduil/worktree/inspired-kitten"* ]]
}

@test "rejects a branch merely containing release into master" {
    run "$script" master feature/release/notes
    [ "$status" -eq 1 ]
}

@test "accepts a release branch into master" {
    run "$script" master release/1.0.0
    [ "$status" -eq 0 ]
}

@test "accepts a hotfix branch into master" {
    run "$script" master hotfix/1.0.1
    [ "$status" -eq 0 ]
}

@test "accepts a feature branch into develop" {
    run "$script" develop alunduil/worktree/inspired-kitten
    [ "$status" -eq 0 ]
}

@test "accepts a branch into a release branch" {
    run "$script" release/1.0.0 alunduil/worktree/inspired-kitten
    [ "$status" -eq 0 ]
}

@test "rejects a missing head branch" {
    run "$script" master
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
