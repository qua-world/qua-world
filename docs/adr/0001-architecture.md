<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 1. Build qua.world as one monorepo of a world-server and actor clients

## Status

Accepted

## Context

qua.world aims to hold a large world with many actors in it: players,
non-player characters, bots, and agents driven by large language models. The
number of actors is the axis the system has to scale along, and the variety of
actors is the point of the world.

Three forces follow from that.

Where actor logic runs. A conventional game server runs non-player characters
inside its own simulation, so every new kind of behaviour is server code and
competes for the server's time. The alternative is to run each actor as its own
process that connects the way a player does. The server then owns only the
world, and anyone can populate it with a small program.

How clients and server share the simulation. Rollback networking, as in
`alpaca-netcode`, keeps the server as a relay of inputs and has every client
simulate the whole world deterministically. That rules out small actor
processes, and it contradicts area-of-interest filtering (#16), where a client
sees only its slice of the world by design. An authoritative server with
clients that predict and reconcile locally fits both.

Where the code lives. Client and server are distinct systems in different
languages, and without a recorded boundary server-shaped concerns accrete in
client code: protocol authoring, persistence, cell management. A separate
repository per side enforces that boundary by distance, but the protocol is
the seam between them and changes on both sides at once. Separate repositories
turn every protocol change into a coordinated release across them.

The server's technical direction:

- Erlang/OTP is a known-good substrate for massively multi-user servers.
  Lopes's *Architectures for Massively Multi-User Environments* surveys the
  space. Armstrong's *Programming Erlang* describes the client-server pattern
  at process granularity, which maps onto a process per entity or cell.
- EtaMOO shows a world-server in Haskell is viable, so Erlang for the server is
  a choice rather than a default.
- Lopes catalogues dynamic space partitioning, such as an octree that
  rebalances by density, with Voronoi diagrams and fixed micro-cells as
  alternatives.

## Decision

qua.world is one polyglot monorepo, this repository, with buck2 as the build
across languages.

- **World-server: Erlang/OTP, authoritative.** A sibling build target, added
  when it exists. It owns the canonical simulation, persistence, and dynamic
  space partitioning, starting from an octree that rebalances by density. It runs no actor logic.
- **Every actor is a client.** Players, non-player characters, bots, and agents
  each run as their own process and connect through the same protocol. The
  protocol makes no distinction between them.
- **Haskell client: the first SDK and the official client.** The library,
  built around `Partir.Agent.*`, is the SDK for writing actors in Haskell.
  `partir-glut` is the official client for people, and `partir-bot` (#21) is
  the example actor. Clients predict, interpolate, and reconcile locally, but
  the server's state wins.
- **Protocol: owned by the server, defined in a language-neutral schema.** The
  schema is the contract every SDK binds to, so an author can write an actor in
  whichever language suits it. The schema language and wire encoding are #28's
  decision. Its research so far leans toward JSON Schema so a compatibility
  checker can gate schema changes in CI.
- **Boundary by build target.** Client targets don't depend on server internals,
  and buck2 target visibility enforces it.

## Consequences

- The world scales by adding actor processes. The server's load becomes
  connection count and area-of-interest fan-out (#16) rather than behaviour
  code, and partitioning has to keep both bounded as actors cluster.
- An actor's latency, crashes, and resource use stay in its own process. A
  slow agent driven by a language model slows only itself.
- Actor behaviour is never authoritative. Anything an actor does arrives as
  input the server validates, the same as a player's.
- The SDK's API and the protocol schema are public interfaces. Changes to
  either break actor authors, so both need compatibility rules (#28) before the
  first outside actor exists.
- SDKs beyond Haskell are possible but aren't built here. Each one binds to the
  schema, not to the Haskell library.
- Protocol changes land on both sides of the seam in one commit:
  `Partir.Net.*` (#12, #13, #14) changes with the server's protocol module.
- buck2 has to replace the `cabal` build before the monorepo is real (#57, #58).
  Until the server target exists, its side of this record is a commitment, not
  code.
- Cell hand-off stays a client concern though partitioning is the server's: an
  actor crossing a cell boundary has to follow the hand-off (#27).
- The repository stops being only the client. README framing, naming, and CI
  follow as the server target lands.
