#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# Branch protection requires only Check CI results, so a job missing from its
# needs: can fail without blocking a merge.
@test "Check CI results needs every other CI job" {
    workflow="$BATS_TEST_DIRNAME/../.github/workflows/ci.yml"
    jobs=$(yq '.jobs | keys | .[] | select(. != "results")' "$workflow" | sort)
    needs=$(yq '.jobs.results.needs[]' "$workflow" | sort)
    diff <(echo "$jobs") <(echo "$needs")
}
