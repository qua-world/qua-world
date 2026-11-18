<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Agent instructions for qua-world

Rules a coding agent can't infer from the files. Build, test, and pull request
steps live in [`CONTRIBUTING.md`](CONTRIBUTING.md); decisions live in
[`docs/adr/`](docs/adr/). Claude Code reads [`CLAUDE.md`](CLAUDE.md), which
imports this file.

## Issues and decisions

- When a change depends on something the repository lacks, file the
  prerequisite as an issue, add a native blocked-by edge, and stop. Land the
  change once the prerequisite exists.
- Before documenting or enforcing a convention, grep for the code it governs.
  With no call sites yet, file an issue and wait.
- Ratify a convention in a linter where one can check it and in
  `CONTRIBUTING.md` where judgment decides. Record platform and release choices
  in the issues that implement them. An ADR is for a choice between shippable
  options that's costly to reverse.

## Documentation

- Put provenance for an opaque file in the code that depends on it. A directory
  gets a README only once an index helps.
- Attribution comes from git history and SPDX headers; the repository keeps no
  `AUTHORS` or `COPYRIGHT` roster.
- Leave compiler, dependency-bound, and build-environment changes out of
  `CHANGELOG.md`.

## Haskell

- Build and test with `-w ghc-<version>`, naming a compiler in the
  `tested-with` series of `partir-qua-world.cabal`, whenever the default `ghc`
  falls outside it.
- Before recommending a Hackage package, run `cabal update`, solve it against
  that compiler in a throwaway package with `cabal build --dry-run`, and judge
  the result by exit code. Then compile it with
  `cabal build --dependencies-only`. Check its last release date too.
- Each asset loader converts its upstream library's types into `Partir.Asset`
  inside its own `Partir.Asset.<Format>` module, so the library never reaches
  the public API. Decode failures return a typed per-loader error in `Left`;
  file I/O failures stay exceptions.
- Name the Fowler catalogue entry a refactoring applies in issues and commit
  messages. Before fixing a smell in passing, check whether an open issue
  already claims it.

## CI and coverage

- When code needs a device the test suite lacks, move its pure decisions into
  a tested module first. The `codecov.yml` ignore then names that one file and
  the issue that brings its real check.
- Push a new CI gate's wiring commit on its own so the pull request shows the
  gate failing on real findings, then push the fixes.
- When pinning a runner or image, read the `Image:` line in `develop`'s latest
  CI log and pin what `-latest` resolves to today.

## Pull requests

- A stale bot closes quiet pull requests. Read a closed pull request's comments
  before treating it as rejected, and check whether the issue it claimed is
  still open.
- Fetch `origin/develop` again before opening a pull request and before each
  push. When a sibling change touched the same module, read its merged code
  before resolving the conflict.
