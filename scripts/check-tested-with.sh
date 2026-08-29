#!/usr/bin/env bash
#
# Compare the GHC series declared in the cabal tested-with against the
# compiler actually in use.
#
# Renovate moves tested-with and the ci.yml ghc-version pin together. Either
# pattern could stop matching, after which a bump moves one file and nothing
# else notices.
#
# Usage: check-tested-with.sh <ghc-version>

set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: ${0##*/} <ghc-version>" >&2
  exit 2
fi

shopt -s nullglob
cabal_files=(*.cabal)
shopt -u nullglob

if [ "${#cabal_files[@]}" -ne 1 ]; then
  echo "expected one .cabal file in $PWD, found ${#cabal_files[@]}" >&2
  exit 2
fi

cabal_file="${cabal_files[0]}"

declared="$(sed -n 's/^tested-with: *GHC == \([0-9.]*\)\.\*$/\1/p' "$cabal_file")"
installed="$(printf '%s' "$1" | cut -d. -f1,2)"

# GitHub reads ::error workflow commands from stdout, so these stay off stderr.
if [ -z "$declared" ]; then
  echo "::error file=$cabal_file::no GHC series found in tested-with"
  exit 1
fi

if [ "$declared" != "$installed" ]; then
  echo "::error file=$cabal_file::tested-with declares GHC $declared but the compiler in use is $1"
  exit 1
fi
