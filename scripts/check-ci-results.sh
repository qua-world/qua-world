#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail Check CI results unless every job it needs succeeded.
#
# Two jobs may skip. The infrastructure change detection runs on pull requests
# alone, and the infrastructure plan runs only when that detection says to.
# A plan skipped for any other reason fails.
#
# Usage: check-ci-results.sh <needs-json>

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: ${0##*/} <needs-json>" >&2
  exit 2
fi

failed=$(jq -r '
  (.["infrastructure-changes"].outputs.plan // "false") as $plan
  | to_entries[]
  | select(.value.result != "success")
  | select(
      .value.result != "skipped"
      or (.key != "infrastructure-changes"
        and (.key != "terraform-plan" or $plan == "true"))
    )
  | "\(.key): \(.value.result)"
' <<<"$1")

if [ -n "$failed" ]; then
  while IFS= read -r job; do
    echo "::error::${job}"
  done <<<"$failed"
  exit 1
fi
