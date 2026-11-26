#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail a dependency update whose plan changes resources, unless Renovate holds
# the update for the admin to merge.
#
# Nobody can bypass the ruleset that requires this check, so a held update
# failing here would be unmergeable.
#
# Usage: check-dependency-plan.sh <pull-request-json> <plan-json>
#
# <pull-request-json> is the response to GET /repos/{owner}/{repo}/pulls/{number}.
# <plan-json> is the output of terraform show -json.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <pull-request-json> <plan-json>" >&2
  exit 2
fi

pull_request="$1"
plan="$2"

# Calling input makes jq fail on an empty file instead of printing nothing
# and succeeding.
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

# Terraform plans a read for each data source inside a check block, and a
# read changes nothing.
count=$(jq -n 'input | [.resource_changes[]
  | select(.mode != "data" and .change.actions != ["no-op"])]
  | length' "$plan")

if [ "$count" = 0 ]; then
  exit 0
fi

if [ "$held" != true ]; then
  echo "::error::This dependency update changes resources; see the plan comment."
  exit 1
fi

# Renovate leaves auto-merge on when it starts holding an update, so GitHub
# would merge the update as soon as this check passed.
if [ "$auto_merge" = true ]; then
  echo "::error::This held update changes resources and auto-merge is on. Disable auto-merge, then re-run this job."
  exit 1
fi

echo "::notice::This held update changes resources; read the plan comment before merging."
