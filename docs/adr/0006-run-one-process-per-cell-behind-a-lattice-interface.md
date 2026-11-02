<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 6. Run one process per cell behind a lattice interface

## Status

Accepted

## Context

[Record 2](0002-run-an-authoritative-world-server-on-erlang.md) makes the
Erlang world-server authoritative and has it partition space dynamically, but
doesn't say which processes own what. The first server code (#194) and the
client's interest set (#16) need that answer.

The answer has to meet these requirements:

- The server starts on one BEAM node, runs on three or more local nodes in
  tests, and later runs on Kubernetes (#170). It adds and removes nodes as
  load changes (#197).
- The server doesn't drop a client's input when a process crashes or an entity
  changes cells.
- A player standing on a cell boundary stays in one cell.
- A client receives updates only from the cells within its render distance.
- Load tests (#195, #196) set the interest radius, the render distance, the
  entities per process, and the tick rate. #97 picks those numbers and the
  lattice.

A process per entity turns every interaction into a message. A process per cell
keeps interactions inside a cell as function calls.

OTP offers two ways to find a process on another node. `global` registers a
name on every node or on none, so every registration involves the whole
cluster. `pg` groups processes across nodes without locks, but its views of a
group can briefly differ between nodes. A caller can then reach a process that
no longer owns a cell.

An `ets` table lives on one node, so cells on different nodes can't share one.
A table survives its owner's crash if it names an heir, and the heir must run on
the same node.

## Decision

Each cell is one Erlang process. It owns the entities inside its region and
simulates them one tick at a time. Each client connects to its own session
process, never to a cell. The session forwards the client's inputs to the cell
that owns the client's entity.

### Lattice

The server uses the lattice through three functions:

- `locate` returns the cell containing a position.
- `neighbours` returns the cells adjacent to a cell.
- `within` returns the cells within a distance of a position.

The lattice issues cell identities. Splitting or merging cells creates new
identities and retires the old ones. An identity never names a second region.
Issue #97 decides how the lattice keeps that promise.

### Placement

Rendezvous hashing of a cell's identity over the current node list picks the
node the cell runs on. When a node joins or leaves, only the cells whose
top-scoring node changes move. Each cell joins a `pg` group named after its
identity, and callers find the cell through that group.

### Sharing state between cells

Every tick, each cell sends its neighbours the entities within the interest
radius of their shared boundary. A neighbour keeps them as a read-only halo, so
an interaction across a boundary runs inside one cell.

A session subscribes to every cell `within` its client's render distance, and
those cells send it entity updates every tick. The session updates its
subscriptions as its entity moves.

### Moving an entity

A cell hands an entity off once the entity is more than a hysteresis margin
outside the cell's region. The old cell sends the entity's state to the new
cell, which holds it without simulating it. The new cell then takes ownership
and acknowledges, and the old cell points the session at the new cell. Until
that acknowledgement, the old cell owns the entity.

Splitting or merging cells moves their entities as a batch of hand-offs. A node
joining or leaving moves its cells the same way.

### Inputs and crashes

The session keeps each input until a cell acknowledges the tick that applied
it. After a hand-off, a cell crash, or a lookup that reached a stale process,
the session sends its unacknowledged inputs again. Cells forward nothing. Each
input carries a sequence number, and a cell ignores a number it has already
applied.

Each node runs one table keeper and one cell supervisor with the `one_for_one`
strategy. Each cell keeps its entities in an `ets` table with the keeper as
heir. When a cell crashes, the keeper inherits the table and gives it to the
restarted cell, which resumes from its last tick.

## Consequences

- An interaction inside a cell costs a function call. Each cell sends one halo
  message to each neighbour per tick.
- Placement and lookup take no cluster-wide lock. When a lookup reaches a stale
  process, session replay recovers the inputs.
- Render distance sets how many cells a client subscribes to, and with it the
  client's bandwidth and drawing load. #196 measures where a client overloads.
- The protocol needs a sequence number on each input and an acknowledgement
  from the server (#13, #28).
- A cell crash loses nothing. A node crash loses every cell on that node,
  because their tables live there. Surviving node loss needs persistence or
  replication, which no record covers.
- In a dense hot spot the halo holds the whole crowd, so halos don't help. #97
  covers hot spots.
- No server code exists, so nothing in the build checks this record.
