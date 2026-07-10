# 1. Structure qua.world as a polyglot monorepo: Haskell client, Erlang world-server

## Status

Proposed

## Context

`partir.qua.world` is described as "a GUI client … and client interfaces for
creating bots, automation, and other actors in the game world." What that
description leaves unsaid is that the *world-server* — the authoritative
simulation every client connects to — is a distinct system, in a different
language, that does not yet exist.

Two questions follow from that: how are client and server *bounded*, and where
do they *live*.

They are conceptually distinct and must stay so. Without a recorded boundary,
contributors will accrete server-shaped concerns into client code: protocol
authoring, world persistence, cell management. The networking issues (#12
`Partir.Net.Protocol`, #13 `Partir.Net.Session`, #14 `Partir.Net.Proxy`) and the
area-of-interest issue (#16 `Partir.World.Interest`) already pull that way.

But a conceptual boundary need not be a repository boundary. The protocol is the
seam between client and server, and it changes on both sides at once — a
separate-repository layout forces every protocol change into a cross-repo
coordination dance, exactly the kind of friction that lets client and server
drift out of sync. A single monorepo lets a protocol change touch both sides in
one atomic commit, with the boundary enforced by build-target visibility and
directory layout instead of repo walls. The cost is a polyglot build: Haskell
today, Erlang later. `cabal` and `rebar3` are per-language; buck2 builds a
single graph across both (and whatever presentations follow), which is what
makes the monorepo tractable.

The server's technical direction is worth recording alongside the layout:

- Erlang/OTP is a known-good substrate for massive multi-user game servers.
  Lopes's *Architectures for Massively Multi-User Environments* surveys the
  space; Armstrong's *Programming Erlang* catalogues the client-server pattern
  at process granularity, which maps onto per-entity server processes.
- [EtaMOO](https://read.readwise.io/read/01jrq89rsjkj3pv996nxdns57t) is a Haskell
  MOO-server point of comparison — server-in-Haskell is viable, so choosing
  Erlang for the server is a deliberate call, not a default.
- Octree-with-auto-density rebalancing is the dynamic space-partitioning
  approach Lopes catalogues under "Load Partitioning → Space partitioning
  (dynamic)," with Voronoi/microcell variants as alternatives.

## Decision

We will develop qua.world as a single **polyglot monorepo** — this repository,
`partir.qua.world`, evolving into it — built with **buck2**.

- **One repository, buck2 build.** Client and server are separate build targets
  within one monorepo, not separate repositories. buck2 owns the polyglot build
  graph (Haskell now, Erlang later, further presentations as they appear).
- **Client — Haskell.** The client is a buck2 target — currently the whole
  repo. It presents the world through interchangeable front-ends: the GLUT
  client (#9's LambdaHack scaffold and beyond) for humans, a headless bot
  executable (#21) for automation, possibly more. All front-ends — human and bot
  alike — speak the same `Partir.Agent.*` vocabulary (#11), so a bot and a
  player are indistinguishable to the rest of the client.
- **Server — Erlang/OTP.** The world-server is a sibling buck2 target, added
  when it exists (it does not yet). It owns the canonical simulation. The client
  still simulates locally — prediction, interpolation, reconciliation — for
  smoothness, but the server is authoritative.
- **Boundary by build target, not repo.** The client target must not depend on
  server internals; buck2 target visibility enforces the boundary that a
  separate repository would otherwise have enforced by distance.
- **Spatial partitioning — octree with auto-density rebalancing** (Lopes's
  dynamic space partitioning), a server-side concern. The client sees only the
  slice the server sends it.
- **Protocol — defined by the server, mirrored by the client.** The server owns
  the wire types (#12); the client tracks them. Co-located in one monorepo, a
  protocol change lands on both sides in a single commit.

## Consequences

- Server-side concerns — persistence, canonical world state, cell ownership,
  load rebalancing — live in the server target, not the client target. buck2
  visibility rules turn "must not accrue here" from a convention into a
  build-time constraint.
- Protocol changes are atomic across the seam: `Partir.Net.*` (#12, #13, #14)
  and the server's protocol module change together in one commit, rather than
  coordinating across repositories.
- buck2 must be bootstrapped over the existing `cabal` build before any of this
  is real; that migration is its own work, tracked separately.
- The Erlang world-server target does not yet exist. Its buck2 rules land with
  it; until then the server side of these decisions is a commitment, not code.
- The repository outgrows "the client": it is becoming the qua.world monorepo.
  README framing, naming, and CI (currently a single `cabal` job) will need to
  follow.
- Cell hand-off remains a real *client-side* concern even though partitioning is
  server-side: as an agent crosses a cell boundary the client must follow the
  hand-off (#27 `Partir.Net.Cell`).
- Because human and bot front-ends share `Partir.Agent.*` (#11), work on agent
  vocabulary benefits every presentation at once; conversely, presentation-
  specific logic must not leak into that shared layer.
