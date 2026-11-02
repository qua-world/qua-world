<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 6. Run one process per cell behind a lattice interface

## Status

Accepted

## Context

[Record 2](0002-run-an-authoritative-world-server-on-erlang.md) chose an
authoritative Erlang world-server that partitions space dynamically. Until a
record decides which process owns each entity, neither the server code (#194)
nor the client's interest set (#16) can start.

The process structure has to meet these requirements:

- The server runs on one BEAM node at first, on three or more local nodes in
  tests, and on Kubernetes later (#170). It adds and removes nodes as load
  changes (#197).
- The server doesn't drop a client's input when a process crashes or an entity
  changes cells.
- A player standing on a cell boundary stays in one cell.
- A client receives updates only from the cells within its render distance.
- The structure works with any lattice, interest radius, render distance,
  entity count per process, and tick rate. Issue #97 chooses those from the
  load tests in #195 and #196.

With a process per entity, every interaction between entities is a message.
With a process per cell, entities in the same cell interact through function
calls.

OTP offers two ways to find a process on another node. `global` registers a
name on every node or on none, so every registration involves the whole
cluster. `pg` groups processes across nodes without locks, but nodes can
briefly disagree about a group's members. While they disagree, a caller can
reach a process that no longer owns the cell it asked for.

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
Issue #97 decides how the lattice avoids reusing identities.

### Placement

The server places each cell on a node with rendezvous hashing over the cell's
identity and the current node list. When a node joins or leaves, only the cells
that hash to a different node move. Each cell joins a `pg` group named after its
identity, and callers find the cell through that group.

### Sharing state between cells

Every tick, each cell sends its neighbours the entities within the interest
radius of their shared boundary. A neighbour keeps them as a read-only halo, so
an interaction across a boundary runs inside one cell.

A session subscribes to the cells that `within` returns for its entity's
position and its client's render distance. Those cells send it entity updates
every tick. The session updates its
subscriptions as its entity moves.

### Moving an entity

A cell hands an entity off once the entity is more than a hysteresis margin
outside the cell's region. The old cell sends the entity's state to the new
cell, which holds it without simulating it. The new cell then takes ownership
and acknowledges. On that acknowledgement, the old cell points the session at
the new cell. Until then, the old cell owns the entity.

Splitting or merging cells moves their entities as a batch of hand-offs. When a
node joins or leaves, each cell that moves hands its entities to a new process
on its new node.

### Inputs and crashes

The session keeps each input until a cell acknowledges the tick that applied
it. After a hand-off, a cell crash, or a lookup that reached a stale process,
the session sends its unacknowledged inputs again. A cell never forwards an
input to another cell. Each
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
- A larger render distance means more subscribed cells, more bandwidth, and
  more drawing for the client. #196 measures the render distance at which a
  client overloads.
- The protocol needs a sequence number on each input and an acknowledgement
  from the server (#13, #28).
- A cell crash loses nothing. A node crash loses every cell on that node,
  because their tables live there. Surviving node loss needs persistence or
  replication, which no record covers.
- In a dense hot spot the halo holds the whole crowd, so halos don't help. #97
  covers hot spots.
- No server code exists, so nothing in the build checks this record.
