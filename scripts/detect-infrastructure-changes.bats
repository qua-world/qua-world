#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

setup() {
    script="$BATS_TEST_DIRNAME/detect-infrastructure-changes.sh"
    cd "$BATS_TEST_TMPDIR"
    git init -q
    git config user.email test@example.com
    git config user.name test
    mkdir -p .github/workflows terraform/infrastructure/modules/repository
    cat >.github/workflows/infrastructure.yml <<'EOF'
on:
  push:
    paths:
      - terraform/infrastructure/**
      - .github/workflows/infrastructure.yml
EOF
    touch terraform/infrastructure/main.tf README.md
    git add -A
    git commit -q -m base
}

commit_change() {
    mkdir -p "$(dirname "$1")"
    echo '# change' >>"$1"
    git add -A
    git commit -q -m change
}

@test "plans a change under the infrastructure layer" {
    commit_change terraform/infrastructure/main.tf
    run "$script" develop true
    [ "$status" -eq 0 ]
    [ "$output" = true ]
}

@test "plans a change in a nested module" {
    commit_change terraform/infrastructure/modules/repository/main.tf
    run "$script" develop true
    [ "$output" = true ]
}

@test "plans a change to the apply workflow" {
    commit_change .github/workflows/infrastructure.yml
    run "$script" develop true
    [ "$output" = true ]
}

@test "skips a change outside the apply's paths" {
    commit_change README.md
    run "$script" develop true
    [ "$status" -eq 0 ]
    [ "$output" = false ]
}

@test "skips a change to a sibling of the infrastructure layer" {
    commit_change terraform/bootstrap/main.tf
    run "$script" develop true
    [ "$output" = false ]
}

@test "skips a pull request into another branch" {
    commit_change terraform/infrastructure/main.tf
    run "$script" master true
    [ "$output" = false ]
}

@test "skips a pull request from a fork" {
    commit_change terraform/infrastructure/main.tf
    run "$script" develop false
    [ "$output" = false ]
}

@test "skips a push, which has no base branch" {
    commit_change terraform/infrastructure/main.tf
    run "$script" "" false
    [ "$output" = false ]
}

@test "fails when the apply trigger lists no paths" {
    printf 'on:\n  push:\n    paths: []\n' >.github/workflows/infrastructure.yml
    commit_change terraform/infrastructure/main.tf
    run "$script" develop true
    [ "$status" -eq 1 ]
}

@test "rejects a wrong argument count" {
    run "$script" develop
    [ "$status" -eq 2 ]
}
