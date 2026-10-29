<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 1. Keep qua.world in one buck2 monorepo

## Status

Accepted

## Context

qua.world has a client in Haskell, this repository today, and a world-server in
another language that doesn't exist yet. They're distinct systems, and without
a recorded boundary server-shaped concerns accrete in client code: protocol
authoring, persistence, cell management.

A separate repository per side enforces that boundary by distance. The
protocol is the seam between the two, though, and it changes on both sides at
once. Separate repositories turn every protocol change into a coordinated
release across them.

## Decision

qua.world is one polyglot monorepo, this repository, with buck2 as the build
across languages. Client and server are separate build targets in it. Client
targets don't depend on server internals, and buck2 target visibility enforces
that boundary.

## Consequences

- A protocol change lands on both sides in one commit: `Partir.Net.*` (#12,
  #13, #14) changes with the server's protocol module.
- The boundary is a build-time constraint rather than a convention reviewers
  have to remember.
- buck2 has to replace the `cabal` build before the monorepo is real (#57,
  #58), and every contributor needs buck2 rather than per-language tools alone.
- The repository stops being only the client. README framing, naming, and CI
  follow as the server target lands.
