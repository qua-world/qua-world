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
seam between the two systems, and a change to it touches the server, the SDK,
and the compatibility check between them. Separate repositories split that
change across pull requests that nobody reviews together.

## Decision

qua.world lives in this repository as one polyglot monorepo, built across
languages by buck2. Client and server are separate build targets in it. Client
targets don't depend on server internals, and buck2 target visibility enforces
that boundary.

## Consequences

- A reviewer sees a protocol change, both of its sides, and its compatibility
  check in one pull request.
- One commit doesn't mean one deployment. Actors built on older SDK releases
  stay connected after the server upgrades, so the server keeps reading every
  supported protocol version. Forward and backward compatibility needs a
  release practice and a schema check in CI (#28), whatever the repository
  layout.
- The boundary is a build-time constraint rather than a convention reviewers
  have to remember.
- buck2 has to replace the `cabal` build before the monorepo is real (#57,
  #58), and every contributor needs buck2 rather than per-language tools alone.
- The repository stops being only the client. README framing, naming, and CI
  follow as the server target lands.
