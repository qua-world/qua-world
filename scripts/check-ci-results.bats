#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

setup() {
    script="$BATS_TEST_DIRNAME/check-ci-results.sh"
}

@test "passes when every job succeeds" {
    run "$script" '{
        "build": {"result": "success"},
        "infrastructure-changes": {"result": "success", "outputs": {"plan": "true"}},
        "terraform-plan": {"result": "success"}
    }'
    [ "$status" -eq 0 ]
}

@test "fails when a job fails" {
    run "$script" '{"build": {"result": "failure"}}'
    [ "$status" -eq 1 ]
    [[ "$output" == *"build: failure"* ]]
}

@test "fails when a job is cancelled" {
    run "$script" '{"build": {"result": "cancelled"}}'
    [ "$status" -eq 1 ]
}

@test "fails when an always-on job skips" {
    run "$script" '{"build": {"result": "skipped"}}'
    [ "$status" -eq 1 ]
    [[ "$output" == *"build: skipped"* ]]
}

@test "passes when the plan skips because nothing needs planning" {
    run "$script" '{
        "build": {"result": "success"},
        "infrastructure-changes": {"result": "success", "outputs": {"plan": "false"}},
        "terraform-plan": {"result": "skipped"}
    }'
    [ "$status" -eq 0 ]
}

@test "fails when detection skips" {
    run "$script" '{
        "infrastructure-changes": {"result": "skipped", "outputs": {}},
        "terraform-plan": {"result": "skipped"}
    }'
    [ "$status" -eq 1 ]
    [[ "$output" == *"infrastructure-changes: skipped"* ]]
}

@test "fails when the plan skips although detection asked for it" {
    run "$script" '{
        "infrastructure-changes": {"result": "success", "outputs": {"plan": "true"}},
        "terraform-plan": {"result": "skipped"}
    }'
    [ "$status" -eq 1 ]
    [[ "$output" == *"terraform-plan: skipped"* ]]
}

@test "fails when detection fails" {
    run "$script" '{
        "infrastructure-changes": {"result": "failure", "outputs": {}},
        "terraform-plan": {"result": "skipped"}
    }'
    [ "$status" -eq 1 ]
    [[ "$output" == *"infrastructure-changes: failure"* ]]
}
