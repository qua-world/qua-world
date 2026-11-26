#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

setup() {
    script="$BATS_TEST_DIRNAME/check-dependency-plan.sh"
    pull_request="$BATS_TEST_TMPDIR/pull_request.json"
    plan="$BATS_TEST_TMPDIR/plan.json"
    enabled='🚦 **Automerge**: Enabled.'
    disabled='🚦 **Automerge**: Disabled by config. Please merge this manually once you are satisfied.'
    armed='{"enabled_by": {"login": "renovate[bot]"}}'
}

# write_pull_request <author> <body> [auto-merge-json]
write_pull_request() {
    jq -n --arg author "$1" --arg body "$2" --argjson auto_merge "${3:-null}" \
        '{user: {login: $author}, body: $body, auto_merge: $auto_merge}' >"$pull_request"
}

# write_plan <action>
write_plan() {
    jq -n --arg action "$1" '{resource_changes: [
        {mode: "data", change: {actions: ["read"]}},
        {mode: "managed", change: {actions: ["no-op"]}},
        {mode: "managed", change: {actions: [$action]}}
    ]}' >"$plan"
}

@test "accepts a held update that changes resources" {
    write_pull_request 'renovate[bot]' "$disabled"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 0 ]
    [[ "$output" == *"::notice::"* ]]
}

@test "rejects an automerging update that changes resources" {
    write_pull_request 'renovate[bot]' "$enabled" "$armed"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
    [[ "$output" == *"::error::This dependency update changes resources"* ]]
}

@test "rejects an automerging update before Renovate turns auto-merge on" {
    write_pull_request 'renovate[bot]' "$enabled"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
}

@test "rejects a held update that still has auto-merge on" {
    write_pull_request 'renovate[bot]' "$disabled" "$armed"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Disable auto-merge"* ]]
}

@test "rejects an automerging update whose release notes say Disabled" {
    write_pull_request 'renovate[bot]' "$disabled"$'\n'"$enabled"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
}

@test "rejects a Renovate body that states neither, whatever the plan" {
    write_pull_request 'renovate[bot]' 'This PR contains the following updates:'
    write_plan no-op
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
    [[ "$output" == *"neither"* ]]
}

@test "accepts an automerging update that changes nothing" {
    write_pull_request 'renovate[bot]' "$enabled" "$armed"
    write_plan no-op
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 0 ]
}

@test "rejects a labelled pull request from someone else that changes resources" {
    write_pull_request alunduil "$disabled"
    write_plan update
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 1 ]
}

@test "accepts a labelled pull request from someone else that changes nothing" {
    write_pull_request alunduil ''
    write_plan no-op
    run "$script" "$pull_request" "$plan"
    [ "$status" -eq 0 ]
}

@test "rejects a held update whose plan cannot be read" {
    write_pull_request 'renovate[bot]' "$disabled"
    echo 'Error: failed to read plan' >"$plan"
    run "$script" "$pull_request" "$plan"
    [ "$status" -ne 0 ]
}

@test "rejects a held update whose plan is empty" {
    write_pull_request 'renovate[bot]' "$disabled"
    : >"$plan"
    run "$script" "$pull_request" "$plan"
    [ "$status" -ne 0 ]
}
