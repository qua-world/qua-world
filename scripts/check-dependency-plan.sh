#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail a dependency update whose plan changes resources, unless Renovate holds
# the update for the admin to merge.
#
# The ruleset that requires this check has no bypass actors, so a held update
# that failed here could not be merged by anyone.
#
# Usage: check-dependency-plan.sh <pull-request-json> <plan-json>
#
# <pull-request-json> is GET /repos/{owner}/{repo}/pulls/{number}.
# <plan-json> is the output of terraform show -json.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <pull-request-json> <plan-json>" >&2
  exit 2
fi

pull_request="$1"
plan="$2"

# jq exits 0 without output on an empty file unless the filter calls input.
author=$(jq -nr 'input | .user.login' "$pull_request")
body=$(jq -nr 'input | .body // ""' "$pull_request")
auto_merge=$(jq -nr 'input | .auto_merge != null' "$pull_request")

held=false
if [ "$author" = 'renovate[bot]' ]; then
  # The body quotes upstream release notes, so a release could include the
  # Disabled text. Testing Enabled first keeps that from opening the gate.
  case "$body" in
    *'**Automerge**: Enabled'*) ;;
    *'**Automerge**: Disabled'*) held=true ;;
    *)
      echo "::error::The pull request body states neither automerge Enabled nor Disabled."
      exit 1
      ;;
  esac
fi

# Terraform rereads data sources inside check blocks at apply, and
# -detailed-exitcode counts each reread as a change.
count=$(jq -n 'input | [.resource_changes[]
  | select(.mode != "data" and .change.actions != ["no-op"])]
  | length' "$plan")

if [ "$count" = 0 ]; then
  exit 0
fi

# Renovate leaves auto-merge on when it starts holding an update, so GitHub
# would merge the update as soon as this check passed.
if [ "$held" = true ] && [ "$auto_merge" = true ]; then
  echo "::error::This held update changes resources and auto-merge is on. Disable auto-merge, then re-run this job."
  exit 1
fi

if [ "$held" = true ]; then
  echo "::notice::This held update changes resources; read the plan comment before merging."
  exit 0
fi

echo "::error::This dependency update changes resources; see the plan comment."
exit 1
