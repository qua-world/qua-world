<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 1. Keep qua.world in one monorepo

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

qua.world lives in this repository as one polyglot monorepo. Client and server
are separate build targets in it, and client targets don't depend on server
internals. The build tool is #60's decision.

## Consequences

- A reviewer sees a protocol change, both of its sides, and its compatibility
  check in one pull request.
- One commit doesn't mean one deployment. Actors built on older SDK releases
  stay connected after the server upgrades, so the server keeps reading every
  supported protocol version. Forward and backward compatibility needs a
  release practice and a schema check in CI (#28), whatever the repository
  layout.
- The boundary is a build-time constraint only if the build tool enforces
  target visibility. Otherwise reviewers have to hold it.
- The build has to span both languages once the server target lands, so the
  `cabal` build gets replaced or wrapped (#60).
- The repository stops being only the client. README framing, naming, and CI
  follow as the server target lands.
