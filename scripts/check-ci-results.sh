#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail Check CI results unless every job it needs succeeded.
#
# Only the infrastructure plan may skip, and only when the change detection
# said not to plan.
#
# Usage: check-ci-results.sh <needs-json>

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: ${0##*/} <needs-json>" >&2
  exit 2
fi

failed=$(jq -r '
  .["infrastructure-changes"].outputs.plan as $plan
  | def unplanned_skip:
      .key == "terraform-plan" and .value.result == "skipped" and $plan != "true";
  to_entries[]
  | select(.value.result != "success")
  | select(unplanned_skip | not)
  | "\(.key): \(.value.result)"
' <<<"$1")

if [ -n "$failed" ]; then
  while IFS= read -r job; do
    echo "::error::${job}"
  done <<<"$failed"
  exit 1
fi
