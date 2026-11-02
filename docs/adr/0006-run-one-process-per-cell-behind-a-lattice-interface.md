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
nor area-of-interest filtering (#16) can start.

The process structure has to meet these requirements:

- The server runs on one BEAM node at first, on three or more local nodes in
  tests, and on Kubernetes later (#170). It adds and removes nodes as load
  changes (#197).
- The server doesn't lose a client's intent when a process crashes or an
  entity changes cells.
- An entity standing on a cell boundary stays owned by one cell.
- A client's render distance, how far away it draws entities, sets its area of
  interest. The client receives updates only from cells inside that area.
- The structure works with any way of dividing space into cells. It also works
  with any interaction range (how far one entity can affect another), render
  distance, entity count per process, and tick rate. Issue #97 chooses how to
  divide space and sets each value from the load tests in #195 and #196.

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
process, never to a cell. The session forwards the client's intents to the
cell that owns the client's entity.

### Lattice

The lattice is the scheme that divides space into cells, such as an octree.
The server uses it through two functions:

- `locate` returns the cell containing a position.
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

Every tick, each cell sends a copy of each of its entities to the other cells
that `within` returns for the entity's position and the interaction range. A
receiving cell simulates against those copies but never changes them, so an
interaction across a boundary runs inside one cell.

A session subscribes to the cells that `within` returns for the position of
the client's entity and the client's render distance. Those cells form the
client's area of interest. Every tick, they send the session updates for their
entities. The session renews its subscriptions as the client's entity moves.

### Moving an entity

Every tick, a cell calls `within` for each of its entities, with the entity's
position and a set distance. When the result no longer includes the owning cell,
the owning cell hands the entity off to the cell that `locate` returns. The set
distance keeps an entity on a boundary from being handed back and forth between
two cells. The old cell sends the entity's state to the new cell, which holds it
without simulating it. The new cell then takes ownership and acknowledges. On
that acknowledgement, the old cell points the session at the new cell. Until
then, the old cell owns the entity.

Splitting or merging cells, or a node joining or leaving, moves the affected
entities as a batch of hand-offs to the new cell processes.

### Intents and crashes

The session keeps each intent until a cell acknowledges the tick that applied
it. The session sends its unacknowledged intents again after a hand-off, after
a cell crash, and after a lookup reaches a process that no longer owns the
cell. A cell never forwards an intent to another cell. Each intent carries a
sequence number, and a cell ignores a number it has already applied.

Each node runs one cell supervisor with the `one_for_one` strategy. Each node
also runs a table keeper, a process that holds the tables of crashed cells.
Each cell keeps its entities in an `ets` table with the table keeper as heir.
When a cell crashes, the table keeper inherits the table and gives it to the
restarted cell, which resumes from its last tick.

## Consequences

- An interaction inside a cell costs a function call. Each cell sends one
  message per tick to each cell that receives copies of its entities.
- Placement and lookup take no cluster-wide lock, so a lookup can briefly
  reach a process that no longer owns the cell.
- A larger render distance means a larger area of interest, more bandwidth,
  and more rendering for the client. #196 measures the render distance at
  which a client overloads.
- The protocol needs a sequence number on each intent and an acknowledgement
  from the server (#13, #28).
- A cell crash loses nothing. A node crash loses every cell on that node,
  because their tables live there. Surviving node loss needs persistence or
  replication, which no record covers.
- When many entities crowd one place, the copies each cell receives include
  most of the crowd, and splitting cells stops helping. #97 covers crowds.
- No server code exists, so nothing in the build checks this record.
