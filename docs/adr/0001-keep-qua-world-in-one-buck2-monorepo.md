<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 1. Keep qua.world in one buck2 monorepo

## Status

Accepted

## Context

qua.world has two systems in different languages: the Haskell client in this
repository and a world-server not yet written. Without a recorded boundary
between them, server concerns such as protocol authoring, persistence, and cell
management accrete in client code.

Separate repositories enforce that boundary by distance. The protocol is the
seam between the two systems and changes on both sides at once, so separate
repositories make every protocol change a coordinated release.

## Decision

qua.world lives in this repository as one polyglot monorepo, built across
languages by buck2. Client and server are separate build targets in it. Client
targets don't depend on server internals, and buck2 target visibility enforces
that boundary.

## Consequences

- A protocol change lands on both sides in one commit.
- The boundary is a build-time constraint rather than a convention reviewers
  have to remember.
- buck2 has to replace the `cabal` build before the monorepo is real (#57,
  #58), and every contributor needs buck2 rather than per-language tools alone.
- The repository stops being only the client. README framing, naming, and CI
  follow as the server target lands.
