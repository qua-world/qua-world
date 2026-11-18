<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Agent instructions for qua-world

Add a rule here only when no file in the repository states it. Build, test, and
pull request steps are in [`CONTRIBUTING.md`](CONTRIBUTING.md); decisions are in
[`docs/adr/`](docs/adr/).

## Issues and decisions

- When a change depends on something the repository lacks, file that
  prerequisite as an issue, mark the change blocked by it, and stop.
- Before documenting or enforcing a convention, grep for the code it governs.
  If nothing follows the convention yet, file an issue and wait.
- Enforce a convention with a linter when a linter can check it; otherwise,
  state it in `CONTRIBUTING.md`.
- Record platform and release choices in the issues that implement them.
- Reserve an ADR for a hard-to-reverse choice between shippable options.

## Documentation

- Record where a binary file came from in the code that loads it.
- Add a directory README only when the directory holds enough to need an index.
- Carry attribution in SPDX headers and git history alone, without an `AUTHORS`
  or `COPYRIGHT` file.
- Leave compiler, dependency-bound, and build-environment changes out of
  `CHANGELOG.md`.

## Haskell

- When the default `ghc` falls outside the `tested-with` series in
  `partir-qua-world.cabal`, pass `-w ghc-<version>` with a compiler from that
  series.
- Before recommending a Hackage package, prove it builds and is maintained:
  1. Run `cabal update`.
  2. In a throwaway package, run `cabal build --dry-run -w ghc-<version>` and
     read the exit code.
  3. Compile it with `cabal build --dependencies-only`.
  4. Check the date of its latest release.
- Put a new asset loader in `Partir.Asset.<Format>` and convert its library's
  types to `Partir.Asset` there, keeping the library out of the public API.
  Return decode failures as a typed per-loader error in `Left`; let file I/O
  failures throw.
- In issues and commit messages, name the Fowler catalogue entry each
  refactoring applies.
- Before fixing a smell in passing, check whether an open issue claims it.

## CI and coverage

- When code needs a device the test suite lacks, such as an OpenGL context,
  move its pure logic into a tested module. Ignore only the remaining file in
  `codecov.yml`, with a comment naming the issue that will test it.
- When adding a CI gate, push the commit that enables it alone, let CI fail on
  the existing findings, then push the fixes.
- To replace a `-latest` runner label, pin the image on the `Image:` line of
  `develop`'s most recent CI log.

## Pull requests

- Before treating a pull request closed without merging as rejected, read its
  comments. A stale bot closes inactive pull requests and leaves their issues
  open.
- Fetch `origin/develop` before opening a pull request and before each push.
  If a merged change touched the same module, read its code before resolving
  conflicts.
