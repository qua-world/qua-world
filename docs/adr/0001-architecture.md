# 1. Split qua.world into a Haskell client and an Erlang world-server

## Status

Proposed

## Context

`partir.qua.world` is described as "a GUI client … and client interfaces for
creating bots, automation, and other actors in the game world." What that
description leaves unsaid is that the *world-server* — the authoritative
simulation every client connects to — is a peer project, in a different
repository and a different language, that does not yet exist.

Without recording the boundary, contributors will accrete server-shaped concerns
inside this repository: protocol authoring, world persistence, cell management.
The networking issues (#12 `Partir.Net.Protocol`, #13 `Partir.Net.Session`,
#14 `Partir.Net.Proxy`) and the area-of-interest filtering issue (#16
`Partir.World.Interest`) already pull in that direction. They need a North Star
to point at so the split stays clean rather than drifting organically.

The technical direction is worth recording alongside the boundary:

- Erlang/OTP is a known-good substrate for massive multi-user game servers.
  Lopes's *Architectures for Massively Multi-User Environments* surveys the
  space; Armstrong's *Programming Erlang* catalogues the client-server pattern
  at process granularity, which maps naturally onto per-entity server processes.
- [EtaMOO](https://read.readwise.io/read/01jrq89rsjkj3pv996nxdns57t) is a Haskell
  MOO-server point of comparison — server-in-Haskell is viable, so choosing
  Erlang for the server is a deliberate call, not a default.
- Octree-with-auto-density rebalancing is the dynamic space-partitioning
  approach Lopes catalogues under "Load Partitioning → Space partitioning
  (dynamic)," with Voronoi/microcell variants as alternatives.

## Decision

We will treat qua.world as two conceptually distinct systems and keep them in
separate repositories.

- **Client — Haskell (this repository).** Presents the world through
  interchangeable front-ends: the GLUT client (#9's LambdaHack scaffold and
  beyond) for humans, a headless bot executable (#21) for automation, and
  possibly more. All front-ends — human and bot alike — speak the same
  `Partir.Agent.*` vocabulary (#11), so a bot and a player are indistinguishable
  to the rest of the client.
- **Server — Erlang/OTP, separate repository (to be created).** Owns the
  canonical simulation. The client still simulates locally — prediction,
  interpolation, reconciliation — for smoothness, but the server is
  authoritative.
- **Spatial partitioning — octree with auto-density rebalancing** (Lopes's
  dynamic space partitioning), a server-side concern. The client sees only the
  slice the server sends it.
- **Protocol — defined by the server.** This repository provides the client
  mirror of the wire types (#12), not their canonical definition. Protocol
  changes flow server → client.

## Consequences

- Server-side concerns — persistence, canonical world state, cell ownership,
  load rebalancing — must not accrue in this repository. When an issue reaches
  for one, that is the signal it belongs to the world-server project instead.
- The protocol is authored server-side; this repository tracks it. `Partir.Net.*`
  (#12, #13, #14) implements the client half of a contract owned elsewhere.
- Cell hand-off is a real *client-side* concern even though partitioning is
  server-side: as an agent crosses a cell boundary the client must follow the
  hand-off (#27 `Partir.Net.Cell`).
- Because human and bot front-ends share `Partir.Agent.*` (#11), work on agent
  vocabulary benefits every presentation at once; conversely, presentation-
  specific logic must not leak into that shared layer.
- The Erlang world-server repository does not yet exist. Cross-repository links
  will be added once it does; until then the server side of these decisions is a
  commitment, not a codebase.
