<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 2. Run an authoritative world-server on Erlang

## Status

Accepted

## Context

qua.world needs one canonical copy of the world that every client agrees on.
The world is also too large for one process to simulate.

Rollback networking, as in `alpaca-netcode`, keeps the server as a relay of
inputs and has every client simulate the whole world deterministically. That
contradicts area-of-interest filtering (#16), where a client sees only its
slice of the world by design. It also makes every client, however small, carry
the full simulation.

Erlang/OTP is a known-good substrate for massively multi-user servers. Lopes's
*Architectures for Massively Multi-User Environments* surveys the space.
Armstrong's *Programming Erlang* describes the client-server pattern at process
granularity, which maps onto a process per entity or cell. EtaMOO shows a
world-server in Haskell is viable, so the client's language would also work.

Lopes also catalogues dynamic space partitioning, which splits the world into
cells that follow where entities gather, with fixed-cell schemes as the static
alternative.

## Decision

The world-server is an Erlang/OTP build target in the monorepo. It's
authoritative: it owns the canonical simulation, persistence, and
the protocol. It partitions space dynamically, starting from an octree that
rebalances by density.

Clients predict, interpolate, and reconcile locally for smoothness, but the
server's state wins.

## Consequences

- Each client receives only its slice of the world (#16), so bandwidth scales
  with what a client can perceive rather than with the world's size.
- A client tracking an entity across a cell boundary has to follow the
  server's cell hand-off (#27).
- Client and server share no code. Types that cross the wire need a definition
  both languages can read (#28).
- The project maintains two languages, each with its own build tools and runtime.
- The server target doesn't exist yet, so nothing in the build checks this
  record.
