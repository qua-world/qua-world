#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Print true when a pull request needs the infrastructure plan, false
# otherwise.
#
# A pull request needs it when it targets develop, comes from this repository,
# and changes a path that infrastructure.yml's push trigger applies on. Reading
# that trigger plans a pull request exactly when its merge would apply. Forks
# get no OIDC token, so they never plan.
#
# HEAD must be the pull request's merge commit, so HEAD^1 is the base tip.
#
# Usage: detect-infrastructure-changes.sh <base-branch> <same-repository>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <base-branch> <same-repository>" >&2
  exit 2
fi

base="$1"
same_repository="$2"
workflow=.github/workflows/infrastructure.yml

if [ "$base" != develop ] || [ "$same_repository" != true ]; then
  echo false
  exit 0
fi

mapfile -t paths < <(yq '.on.push.paths[] | ":(glob)" + .' "$workflow")
if [ "${#paths[@]}" -eq 0 ]; then
  echo "${workflow}'s push trigger lists no paths" >&2
  exit 1
fi

if git diff --quiet HEAD^1 HEAD -- "${paths[@]}"; then
  echo false
else
  echo true
fi
