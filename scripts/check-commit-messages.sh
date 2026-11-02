#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail unless every non-merge commit in <base>..<head> passes the
# conventional-pre-commit hook.
#
# Git flow merges pull requests, so every commit lands on develop. Running the
# hook keeps the type list in .pre-commit-config.yaml alone.
#
# Usage: check-commit-messages.sh <base-commit> <head-commit>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <base-commit> <head-commit>" >&2
  exit 2
fi

message=$(mktemp)
trap 'rm -f "$message"' EXIT

status=0
for sha in $(git rev-list --no-merges "$1..$2"); do
  git log -1 --format=%B "$sha" > "$message"
  if ! pre-commit run conventional-pre-commit \
      --hook-stage commit-msg --commit-msg-filename "$message"; then
    # GitHub reads ::error workflow commands from stdout.
    echo "::error::commit $sha lacks a recognised type"
    status=1
  fi
done

exit "$status"
