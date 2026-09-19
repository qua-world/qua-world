<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Contributing to partir

Issues, questions, pull requests, and docs improvements are welcome. This file
covers what you need to build, test, and open a pull request.

## Your first contribution

Issues tagged [good first issue] stay small and assume no prior context on the
codebase. The [help wanted] label marks anything else open to a contributor.
Neither is a prerequisite: a pull request for something not yet filed is
equally welcome.

## Getting started

Prerequisites: `cabal-install` and the GHC version
[`tested-with`](partir-qua-world.cabal) declares, which CI builds and tests on
every pull request. The `partir-glut` executable links GLUT and OpenGL, so
install the freeglut and GLU development headers before building it
(`freeglut3-dev` and `libglu1-mesa-dev` on Debian and Ubuntu).

```sh
cabal update
cabal build all --enable-tests
cabal test all --enable-tests
```

Run `cabal update` on a first checkout and after any gap between
contributions. A stale Hackage index surfaces as a dependency resolution error
that reads like a broken build.

CI fails a pull request that leaves dead code behind: a definition or an export
nothing reaches from the executable or the test suite. Weeder reads the HIE
files a build writes, so run it from a built tree.

```sh
cabal install weeder
weeder
```

## Tests

Generators live in [test/Partir/Arbitrary.hs](test/Partir/Arbitrary.hs) rather
than in the spec that first needs one, and every instance there defines
`shrink`.

A property whose subject branches on its input carries a coverage assertion
naming those partitions, under `checkCoverage`. A stateful module gets a model
to compare against over a generated sequence. `prunePreserves` and `test_model`
show both shapes.

## Before you commit

[pre-commit] gates each commit on formatting, linting, and file hygiene, and
runs the same hooks again in CI:

```sh
pre-commit install
pre-commit run --all-files
```

The `fourmolu` and `hlint` hooks invoke those tools from `PATH`, so install
both alongside `cabal-install`. The versions CI pins are in
[.github/workflows/ci.yml](.github/workflows/ci.yml).

Haskell Language Server formats with ormolu unless told otherwise, and ormolu
takes no configuration, so it never reads [fourmolu.yaml](fourmolu.yaml) and
format-on-save can undo what the hooks produce. Point `formattingProvider` at
`fourmolu` in your editor. It has to go there rather than in this repository:
the language server reads plugin settings from the editor, and `hie.yaml`
covers only the build cradle.

## Pull requests

This project follows [git flow]. Fork the repository, branch from `develop`,
and target `develop` with the pull request.

Open it as a draft and mark it ready once CI is green and you want review.
Unrelated cleanup goes in a separate pull request. CI must pass before merge.

Leave `version:` in `partir-qua-world.cabal` alone. The maintainer cuts
releases. Record user-visible changes under `[Unreleased]` in
[CHANGELOG.md](CHANGELOG.md) instead.

### Commit messages

This project merges pull requests rather than squashing them, so every commit
on the branch lands on `develop` and stands on its own. Follow the [seven rules
of a great commit message][seven rules]: an imperative subject under 50
characters, a blank line, then a wrapped body. The body covers why the change
matters and anything a reader of the diff would find surprising.

## Filing an issue

File it on [GitHub]. For bugs, include your GHC and cabal versions, your
platform, and a minimal reproduction. For proposals, include the user-visible
outcome and the problem it solves. Questions about using partir are welcome as
issues too. Tag them [question].

[git flow]: http://nvie.com/posts/a-successful-git-branching-model/
[GitHub]: https://github.com/qua-world/partir.qua.world/issues
[good first issue]: https://github.com/qua-world/partir.qua.world/labels/good%20first%20issue
[help wanted]: https://github.com/qua-world/partir.qua.world/labels/help%20wanted
[pre-commit]: https://pre-commit.com/
[question]: https://github.com/qua-world/partir.qua.world/labels/question
[seven rules]: https://cbea.ms/git-commit/
