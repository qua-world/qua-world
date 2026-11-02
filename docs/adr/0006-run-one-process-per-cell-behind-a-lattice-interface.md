<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 6. Run one process per cell behind a lattice interface

## Status

Accepted

## Context

[Record 2](0002-run-an-authoritative-world-server-on-erlang.md) makes the
Erlang world-server authoritative and partitions space dynamically. It doesn't
say which processes own what. The first server code, the client's interest set
(#16), and the client's cell hand-off (#27) all depend on that structure.

The structure has to meet these requirements:

- **Multiple nodes.** The server runs on one BEAM node at first, runs on three
  or more local nodes in tests, and later runs on Kubernetes (#170). Nodes are
  added and removed as load changes (#197).
- **No lost input.** The server shouldn't drop a client's input if the protocol
  can prevent it, including when a process crashes or an entity changes cells.
- **Stable boundaries.** A player standing on a cell boundary doesn't bounce
  between cells.
- **Cell visibility.** What a client renders maps onto a set of cells, so the
  server sends a client only the cells it can see.
- **Measured numbers.** The interest radius, the render distance, the entity
  budget per process, and the tick rate come from load tests (#195, #196).
  #97 chooses them, and it also chooses the lattice: octree or body-centred
  cubic.

Each part has alternatives:

- **Process unit.** One process per cell, one per entity, or one per entity
  supervised by its cell. A process per entity turns every interaction into a
  message between processes. A process per cell keeps the interactions inside
  a cell local.
- **Finding a cell.** The OTP module `global` registers a name on every node
  or on none, and every change reaches every node. The OTP module `pg` keeps
  groups with members on any node, and its views "may temporarily diverge"
  between nodes.
  A static table can't follow nodes joining and leaving.
- **Neighbour awareness.** Cells push the entities near their edges to their
  neighbours. The alternatives are neighbours polling each other, or a shared
  table, which `ets` can't provide across nodes.
- **Messages in flight.** These can be dropped, forwarded, or replayed. Only
  replay from the sender survives a process that crashes before it forwards
  anything.
- **Recovering a crashed cell.** A cell can restart empty or recover its
  state. An `ets` table outlives its owner if it names an heir, and the OTP
  documentation requires that the heir is a local process.

## Decision

Each cell is one Erlang process. It owns the authoritative state of the
entities inside its region, and it runs their simulation one tick at a time.
Each session is a separate process that forwards inputs for its entity to the
cell that owns that entity. A client connects to its session and never to a
cell, so moving an entity between cells leaves the client's connection alone.

### Lattice interface

The server reaches the geometry only through three functions, so #97's choice
of lattice plugs in without changing the cell mechanism:

- **Locate:** from a position to the cell that contains it.
- **Neighbours:** from a cell to the cells adjacent to it.
- **Within:** from a position and a distance to every cell within that
  distance.

Cell identities come from the lattice. Splitting or merging cells retires the
old identities and creates new ones; the lattice never reuses an identity for a
different region. Placement and lookup key on identity, so they stay correct
across rebalancing. How the lattice keeps that promise is #97's decision.

### Placement and lookup

A cell runs on the node chosen by rendezvous hashing of the cell's identity
over the current node list. A node joining or leaving moves only the cells
whose highest-scoring node changes. Each cell joins a `pg` group named for its
identity, and callers find a cell through that group.

### Awareness

Simulation and visibility are separate mechanisms:

- **Simulation.** Each tick, a cell pushes the entities within the interest
  radius of its boundary to the neighbouring cells. A neighbour holds them as a
  read-only halo, so interactions across a boundary run in one cell. The
  number of messages per tick is bounded by the number of neighbours.
- **Visibility.** A session subscribes to every cell within its client's
  render distance (the Within function). Those cells push entity updates to the
  subscribed sessions every tick. The session updates its subscriptions when
  its entity moves.

### Hand-off

The cell that owns an entity starts a hand-off when the entity leaves the
cell's region by more than a hysteresis margin:

1. **Prepare.** The old cell sends the entity's state to the new cell, which
   holds it without simulating it.
2. **Commit.** The new cell takes ownership and acknowledges. The old cell
   points the session at the new cell.

Between prepare and commit the entity's owner is still the old cell.

### Inputs in flight

A session keeps each input until a cell acknowledges the tick that applied it.
Whenever its entity's owner changes, whether by hand-off, crash, or a lookup
that reached a stale process, the session sends the unacknowledged inputs again.
This is the only way an input reaches a new owner; old owners forward nothing. Cells apply each input at
most once, by its sequence number within the session.

### Supervision

Each node runs one cell supervisor, with the `one_for_one` restart strategy.
Each node also runs a table keeper. A cell keeps its entities in an `ets` table
whose heir is the keeper. When a cell crashes, the keeper inherits the table
and gives it to the restarted cell, which resumes from its last tick.

### Splitting and merging

When the lattice splits or merges cells to follow density, the affected cells
move their entities as a batch of hand-offs. A node joining or leaving moves
cells the same way.

## Consequences

- Interactions inside a cell are function calls, and interactions across a
  boundary cost one halo message per neighbour per tick.
- Changing the lattice means implementing the three interface functions. The
  mechanism doesn't change.
- Neither placement nor lookup takes a cluster-wide lock. The cost is that a
  lookup can briefly reach a stale process, and replay from the session covers
  that.
- A client's render distance sets how many cells it subscribes to, so it also
  sets the client's bandwidth and drawing load. #196 measures where that
  overloads a client.
- Sessions hold their unacknowledged inputs and send them again, so the protocol
  needs sequence numbers and acknowledgements (#13, #28).
- A cell crash loses nothing. A node crash loses that node's cells, because
  their tables live only on that node. Surviving node loss needs persistence or
  replication, which no record covers yet.
- Halo pushes don't help in a dense hot spot, because the halo becomes the
  whole population. #97 owns that case.
- The server code doesn't exist yet, so nothing in the build checks this
  record.
