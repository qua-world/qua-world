#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Fail a pull request into master unless it comes from a release or hotfix
# branch.
#
# Rulesets on GitHub Free cannot restrict a pull request's source branch, so
# the checks-release ruleset requires this check instead. A push has no base
# branch and passes.
#
# Usage: check-git-flow-source.sh <base-branch> <head-branch>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <base-branch> <head-branch>" >&2
  exit 2
fi

base="$1"
head="$2"

if [ "$base" != master ]; then
  exit 0
fi

case "$head" in
  release/* | hotfix/*) exit 0 ;;
esac

# GitHub reads ::error workflow commands from stdout, so this stays off stderr.
echo "::error::pull requests into master come from release/* or hotfix/*, not $head"
exit 1
