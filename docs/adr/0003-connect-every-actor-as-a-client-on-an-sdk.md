<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 3. Connect every actor as a client on an SDK

## Status

Accepted

## Context

qua.world aims to hold a large world with many actors in it: players,
non-player characters, bots, and agents driven by large language models. The
number of actors is the axis the system has to scale along, and the variety of
actors is the point of the world.

A conventional game server runs non-player characters inside its own
simulation. Every new kind of behaviour is then server code, written in the
server's language, and competes for the server's time. Actor authors want
whatever tools suit the actor, such as a Python library for a language model.

## Decision

Every actor is its own client process. Players, non-player characters, bots,
and agents connect through the same protocol, and the protocol makes no
distinction between them. The world-server
([record 2](0002-run-an-authoritative-world-server-on-erlang.md)) runs no actor
logic.

- **SDK.** The Haskell client library, built around `Partir.Agent.*`, is the
  first SDK. `partir-glut` is the official client for people, and `partir-bot`
  (#21) is the example actor.
- **Protocol schema.** The server defines the protocol in a language-neutral
  schema, and every SDK binds to it, so an author can write an actor in any
  language. The schema language and wire encoding are #28's decision.

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
- Non-player characters pay a network round trip for every action that an
  in-server implementation would make locally.
