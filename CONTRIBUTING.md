# Contributing to partir

Issues, questions, pull requests, and docs improvements are welcome.  This file
covers what you need to build, test, and open a pull request: commands, branch
policy, and the conventions a review expects.

# Your first contribution

Issues tagged [good first issue][gfi] are scoped small and don't assume prior
context on the codebase; [help wanted][hw] marks anything else open to a
contributor.  Neither is a prerequisite: an unlabelled issue, or a pull request
for something not yet filed, is equally welcome.

# Getting started

Prerequisites: GHC 9.10 and `cabal-install`.  The `partir-glut` executable
links GLUT and OpenGL, so the freeglut and GLU development headers must be
installed before it builds — `freeglut3-dev` and `libglu1-mesa-dev` on Debian
and Ubuntu.

```sh
cabal update
cabal build all --enable-tests
cabal test all --enable-tests
```

Run `cabal update` on a first checkout and after any gap between
contributions.  A stale Hackage index surfaces as a dependency resolution
failure that reads like a broken build.

# Branch policy

This project follows [git flow].  `develop` is the merge target for every pull
request, and topic branches are deleted on merge.

# Pull requests

Fork the repository, branch from `develop`, and open the pull request against
`develop`.

Open it as a draft and mark it ready once CI is green and you want review.
Keep each pull request focused; unrelated cleanup goes in a separate one.  CI
builds and tests the package on GHC 9.10 and must pass before merge.

Leave `version:` in `partir-qua-world.cabal` alone — releases are cut by the
maintainer.  Record user-visible changes under `[Unreleased]` in
[CHANGELOG.md](CHANGELOG.md) instead.

## Commit messages

Pull requests are merged rather than squashed, so every commit on the branch
lands on `develop` and is read on its own.  Follow the [seven rules of a great
commit message][seven rules]: an imperative subject under 50 characters, a
blank line, then a wrapped body covering why the change is needed and anything
a reader of the diff would find surprising.

# Reporting bugs, asking questions, proposing changes

File an issue on [Github].  For bugs, include your GHC version, cabal version,
and platform, along with a minimal reproduction.  For proposals, describe the
user-visible outcome and the problem it solves.  Questions about using partir
are welcome as issues too; tag them [question][question label].

# Attribution

Contributors are listed in [COPYRIGHT](COPYRIGHT).  Add yourself in the same
pull request as your first contribution if you want attribution.

[gfi]: https://github.com/qua-world/partir.qua.world/labels/good%20first%20issue
[git flow]: http://nvie.com/posts/a-successful-git-branching-model/
[Github]: https://github.com/qua-world/partir.qua.world/issues
[help wanted]: https://github.com/qua-world/partir.qua.world/labels/help%20wanted
[question label]: https://github.com/qua-world/partir.qua.world/labels/question
[seven rules]: https://cbea.ms/git-commit/
